# res://scripts/ai/UnitFSM.gd
# Refactored UnitFSM for Phase 3 RTS commands
# Now uses modular AttackAI component for attacking behavior
# GDD Ref: Phase 3 Task 4

class_name UnitFSM

enum State { IDLE, MOVING, FORMATION_MOVING, ATTACKING }
enum Stance { DEFENSIVE, HOLD_POSITION }

# Unit References
var unit: BaseUnit
var attack_ai: AttackAI  # Reference to the AttackAI component

# State Data
var current_state: State = State.IDLE
var stance: Stance = Stance.DEFENSIVE
var path: Array = []
var stuck_timer: float = 0.0 # --- NEW: Stuck Timer ---

# Target Data
var target_position: Vector2 = Vector2.ZERO
var move_command_position: Vector2 = Vector2.ZERO

var objective_target: Node2D = null # The long-term goal (e.g., Great Hall)
var current_target: Node2D = null # The immediate threat (e.g., nearby unit)

func _init(p_unit: BaseUnit, p_attack_ai: AttackAI) -> void:
	unit = p_unit
	attack_ai = p_attack_ai
	
	if attack_ai:
		attack_ai.attack_started.connect(_on_ai_attack_started)
		attack_ai.attack_stopped.connect(_on_ai_attack_stopped)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	print_debug("UnitFSM (%s): State change %s -> %s" % [unit.name, State.keys()[current_state], State.keys()[new_state]])
	
	_exit_state(current_state)
	current_state = new_state
	
	if unit and unit.has_method("on_state_changed"):
		unit.on_state_changed(current_state)
	_enter_state(current_state)

func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			unit.velocity = Vector2.ZERO
			
		State.MOVING:
			_recalculate_path() 
		
		State.FORMATION_MOVING:
			pass
		
		State.ATTACKING:
			unit.velocity = Vector2.ZERO
			if attack_ai and is_instance_valid(current_target):
				attack_ai.force_target(current_target)

func _exit_state(state: State) -> void:
	match state:
		State.MOVING:
			path.clear()
			stuck_timer = 0.0 # --- NEW: Reset timer ---
		State.FORMATION_MOVING:
			path.clear()
		
		State.ATTACKING:
			if attack_ai:
				attack_ai.stop_attacking()
			# Clear the *current* target, but not the objective
			current_target = null

func _recalculate_path() -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target
	
	if not is_instance_valid(target_node):
		change_state(State.IDLE)
		return
		
	target_position = target_node.global_position
	
	var allow_partial = is_instance_valid(target_node)
	
	print_debug("UnitFSM (%s): Recalculating path to %s" % [unit.name, target_node.name])
	path = SettlementManager.get_astar_path(unit.global_position, target_position, allow_partial)
	
	if path.is_empty():
		push_warning("Unit at %s failed to find a path to %s." % [unit.global_position, target_position])
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()
		
		# --- OBSTRUCTION LOGIC (CASE 1: A* fails) ---
		if is_instance_valid(target_node):
			print_debug("UnitFSM (%s): Path empty (A* fail). Finding obstruction." % unit.name)
			# We have a target but can't reach it. Find what's blocking us.
			var blocking_building = _find_closest_blocking_building()
			if is_instance_valid(blocking_building):
				push_warning("Path blocked. Attacking obstruction: %s" % blocking_building.name)
				command_attack_obstruction(blocking_building)
			else:
				print_debug("UnitFSM (%s): No obstruction found. Idling." % unit.name)
				change_state(State.IDLE)
		# --- END LOGIC ---
		else:
			change_state(State.IDLE)

# --- Find Obstruction ---
func _find_closest_blocking_building() -> Node2D:
	var mission_node = unit.get_parent()
	if not is_instance_valid(mission_node) or not mission_node.has_node("BuildingContainer"):
		push_error("UnitFSM: Cannot find BuildingContainer to check for obstructions.")
		return null

	var building_container = mission_node.get_node("BuildingContainer")
	var buildings = building_container.get_children()
	
	var closest_building: Node2D = null
	var min_dist_sq = INF
	
	if not is_instance_valid(objective_target):
		print_debug("UnitFSM (%s): Cannot find obstruction, no objective_target." % unit.name)
		return null

	var unit_pos = unit.global_position
	var target_pos = objective_target.global_position
	var unit_to_target_dir = (target_pos - unit_pos).normalized()
	
	print_debug("UnitFSM (%s): Scanning for obstruction between %s and %s" % [unit.name, unit_pos, target_pos])

	for building in buildings:
		if not building is BaseBuilding:
			continue
			
		# --- THIS IS THE FIX ---
		# We REMOVE the check that ignores the objective. If the
		# objective is the closest thing, attack it.
		# if building == objective_target:
		# 	continue
		# --- END FIX ---
			
		var unit_to_building_dir = (building.global_position - unit_pos).normalized()
		var dot = unit_to_target_dir.dot(unit_to_building_dir)
		
		if dot > 0.5: # Is it "in front" of us?
			var dist_sq = unit_pos.distance_squared_to(building.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_building = building
				
	if is_instance_valid(closest_building):
		print_debug("UnitFSM (%s): Found closest obstruction: %s" % [unit.name, closest_building.name])
	else:
		print_debug("UnitFSM (%s): No valid obstructions found." % unit.name)
				
	return closest_building
# --- END NEW ---


# --- RTS Command Functions ---

func command_defensive_attack(attacker: Node2D) -> void:
	"""
	Called by BaseUnit.take_damage().
	This is an individual-only response and does not change the objective_target.
	"""
	if not is_instance_valid(attacker):
		return
	
	if current_state == State.ATTACKING and current_target == attacker:
		return
	
	print_debug("UnitFSM (%s): Retaliating against %s" % [unit.name, attacker.name])
	current_target = attacker 
	change_state(State.ATTACKING)

func command_attack_obstruction(target: Node2D) -> void:
	"""
	Attack a target (like a wall) without losing the main objective_target.
	"""
	if not is_instance_valid(target):
		return
		
	print_debug("UnitFSM (%s): Attacking obstruction %s" % [unit.name, target.name])
	current_target = target
	target_position = target.global_position
	
	var distance: float = unit.global_position.distance_to(target.global_position)
	
	if distance <= unit.data.attack_range:
		change_state(State.ATTACKING)
	else:
		change_state(State.MOVING) # Move to the obstruction

func command_move_to_formation_pos(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	
	current_target = null 
	objective_target = null
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	path.clear()
	path.append(target_pos)
	
	change_state(State.FORMATION_MOVING)

func command_move_to(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos

	current_target = null
	objective_target = null
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	change_state(State.MOVING)

func command_attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		print("Cannot attack invalid target")
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()
		return
	
	print_debug("UnitFSM (%s): Commanded to attack %s" % [unit.name, target.name])
	objective_target = target
	current_target = target
	target_position = target.global_position
	
	var distance: float = unit.global_position.distance_to(target.global_position)
	
	if distance <= unit.data.attack_range:
		change_state(State.ATTACKING)
	else:
		change_state(State.MOVING)

# --- State Machine Update ---

func update(delta: float) -> void:
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.MOVING:
			_move_state(delta)
		State.FORMATION_MOVING:
			_formation_move_state(delta)
		State.ATTACKING:
			_attack_state(delta)

# --- State Logic Functions ---

func _idle_state(_delta: float) -> void:
	unit.velocity = Vector2.ZERO

func _formation_move_state(delta: float) -> void:
	if path.is_empty():
		change_state(State.IDLE)
		return

	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var velocity: Vector2 = direction * unit.data.move_speed
	
	unit.velocity = velocity
	unit.move_and_slide()
	
	var arrival_radius: float = 8.0 
	if unit.global_position.distance_to(next_waypoint) < arrival_radius:
		path.pop_front()
		
		if path.is_empty():
			change_state(State.IDLE)

func _move_state(delta: float) -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target

	if not is_instance_valid(target_node):
		change_state(State.IDLE)
		return
	
	if is_instance_valid(current_target):
		var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
		if distance_to_target <= unit.data.attack_range:
			change_state(State.ATTACKING)
			return
	
	if path.is_empty():
		print_debug("UnitFSM (%s): Path is empty." % unit.name)
		# Path is empty, check if we're at our destination or stuck.
		if is_instance_valid(target_node):
			var distance_to_target: float = unit.global_position.distance_to(target_node.global_position)
			if distance_to_target <= unit.data.attack_range + 10: # +10 buffer
				print_debug("UnitFSM (%s): Path empty, in range. Attacking." % unit.name)
				change_state(State.ATTACKING)
			else:
				# --- OBSTRUCTION LOGIC (CASE 2: Path ends) ---
				print_debug("UnitFSM (%s): Path empty, NOT in range. Stuck. Finding obstruction." % unit.name)
				var blocking_building = _find_closest_blocking_building()
				if is_instance_valid(blocking_building):
					push_warning("Path ended, but not in range. Attacking obstruction: %s" % blocking_building.name)
					command_attack_obstruction(blocking_building)
				else:
					print_debug("UnitFSM (%s): Path empty, stuck, but no obstruction found. Idling." % unit.name)
					change_state(State.IDLE)
		else:
			change_state(State.IDLE)
		return
	
	# Standard path following
	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var velocity: Vector2 = direction * unit.data.move_speed
	
	unit.velocity = velocity
	unit.move_and_slide()
	
	var arrival_radius: float = 8.0 
	if unit.global_position.distance_to(next_waypoint) < arrival_radius:
		path.pop_front()
		
		if path.is_empty():
			print_debug("UnitFSM (%s): Reached end of path." % unit.name)
			pass
	
	# --- NEW: Stuck Timer Logic ---
	# Check the *actual* velocity after moving.
	if unit.velocity.length_squared() < 1.0: # 1.0 is a good "stuck" threshold
		stuck_timer += delta
		if stuck_timer > 1.5: # Stuck for 1.5 seconds
			print_debug("UnitFSM (%s): STUCK (velocity is zero). Finding obstruction." % unit.name)
			var blocking_building = _find_closest_blocking_building()
			if is_instance_valid(blocking_building):
				command_attack_obstruction(blocking_building)
			else:
				change_state(State.IDLE) # Give up
			stuck_timer = 0.0 # Reset timer
	else:
		stuck_timer = 0.0 # Not stuck, reset timer
	# --- END NEW ---

func _attack_state(_delta: float) -> void:
	if not is_instance_valid(current_target):
		# Target is dead or gone
		_resume_objective()
		return
	
	var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
	if distance_to_target > unit.data.attack_range + 10: # +10 pixel buffer
		# Target moved out of range
		print_debug("UnitFSM (%s): Target %s moved out of range." % [unit.name, current_target.name])
		_resume_objective()
		return
	
	# Otherwise, stay in ATTACKING state
	unit.velocity = Vector2.ZERO

# --- NEW: Centralized Objective Resumer ---
func _resume_objective() -> void:
	"""
	Called when an attack is finished.
	Forces the FSM to re-evaluate its main objective.
	"""
	print_debug("UnitFSM (%s): Resuming main objective." % unit.name)
	current_target = null
		
	if is_instance_valid(objective_target):
		print_debug("UnitFSM (%s): Objective %s is valid. Recalculating path." % [unit.name, objective_target.name])
		current_target = objective_target # Set our current target back to the objective
		change_state(State.MOVING) # Go back to moving (will trigger _recalculate_path)
	else:
		print_debug("UnitFSM (%s): No valid objective. Idling." % unit.name)
		change_state(State.IDLE)
# --- END NEW ---

func _check_defensive_response() -> void:
	pass

# --- AI Signal Callbacks ---
func _on_ai_attack_started(target: Node2D) -> void:
	if current_state == State.ATTACKING and target == current_target:
		return
		
	if attack_ai.ai_mode == AttackAI.AI_Mode.DEFENSIVE_SIEGE:
		return
		
	print_debug("UnitFSM (%s): AI auto-attack started on %s" % [unit.name, target.name])
	current_target = target
	change_state(State.ATTACKING)

func _on_ai_attack_stopped() -> void:
	# The AttackAI has stopped (e.g., target out of range)
	if current_state == State.ATTACKING:
		print_debug("UnitFSM (%s): AI attack on %s stopped." % [unit.name, current_target.name if is_instance_valid(current_target) else "null"])
		_resume_objective()
