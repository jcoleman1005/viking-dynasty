# res://scripts/ai/UnitFSM.gd
# Refactored UnitFSM for Phase 3 RTS commands
# Now uses modular AttackAI component for attacking behavior
# GDD Ref: Phase 3 Task 4

class_name UnitFSM

# Enums are now defined in UnitAIConstants.gd to break circular dependency

# Unit References
# Removed the : BaseUnit type hint to break the circular dependency.
var unit
var attack_ai: AttackAI  # Reference to the AttackAI component

# State Data
var current_state: UnitAIConstants.State = UnitAIConstants.State.IDLE
var stance: UnitAIConstants.Stance = UnitAIConstants.Stance.DEFENSIVE
var path: Array = []
var stuck_timer: float = 0.0

var los_range: float = 450.0 # Player unit "Line of Sight"

# Target Data
var target_position: Vector2 = Vector2.ZERO
var move_command_position: Vector2 = Vector2.ZERO

var objective_target: Node2D = null # The long-term goal (e.g., Great Hall)
var current_target: Node2D = null # The immediate threat (e.g., nearby unit)

# Removed the : BaseUnit type hint from p_unit.
func _init(p_unit, p_attack_ai: AttackAI) -> void:
	unit = p_unit
	attack_ai = p_attack_ai
	
	if attack_ai:
		attack_ai.attack_started.connect(_on_ai_attack_started)
		attack_ai.attack_stopped.connect(_on_ai_attack_stopped)

func change_state(new_state: UnitAIConstants.State) -> void:
	if current_state == new_state:
		return
	
	# print_debug("UnitFSM (%s): State change %s -> %s" % [unit.name, State.keys()[current_state], State.keys()[new_state]])
	
	_exit_state(current_state)
	current_state = new_state
	
	# Use call() to avoid circular dependency error
	if is_instance_valid(unit):
		unit.call("on_state_changed", current_state)
	
	_enter_state(current_state)

func _enter_state(state: UnitAIConstants.State) -> void:
	match state:
		UnitAIConstants.State.IDLE:
			unit.velocity = Vector2.ZERO
			
		UnitAIConstants.State.MOVING:
			_recalculate_path() 
		
		UnitAIConstants.State.FORMATION_MOVING:
			pass
		
		UnitAIConstants.State.ATTACKING:
			unit.velocity = Vector2.ZERO
			if attack_ai and is_instance_valid(current_target):
				attack_ai.force_target(current_target)

func _exit_state(state: UnitAIConstants.State) -> void:
	match state:
		UnitAIConstants.State.MOVING:
			path.clear()
			stuck_timer = 0.0
		UnitAIConstants.State.FORMATION_MOVING:
			path.clear()
		
		UnitAIConstants.State.ATTACKING:
			if attack_ai:
				attack_ai.stop_attacking()
			# Clear the *current* target, but not the objective
			current_target = null

func _recalculate_path() -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target
	
	if not is_instance_valid(target_node):
		change_state(UnitAIConstants.State.IDLE)
		return
		
	target_position = target_node.global_position
	
	var allow_partial = is_instance_valid(target_node)
	
	# print_debug("UnitFSM (%s): Recalculating path to %s" % [unit.name, target_node.name])
	path = SettlementManager.get_astar_path(unit.global_position, target_position, allow_partial)
	
	if path.is_empty():
		# This warning is fine, it only happens once when A* fails
		push_warning("Unit at %s failed to find a path to %s." % [unit.global_position, target_position])
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()

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
		# print_debug("UnitFSM (%s): Cannot find obstruction, no objective_target." % unit.name)
		return null

	var unit_pos = unit.global_position
	# print_debug("UnitFSM (%s): Scanning for closest obstruction to %s" % [unit.name, unit_pos])

	for building in buildings:
		if not building is BaseBuilding:
			continue
			
		var dist_sq = unit_pos.distance_squared_to(building.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_building = building
				
	if is_instance_valid(closest_building):
		# print_debug("UnitFSM (%s): Found closest obstruction: %s" % [unit.name, closest_building.name])
		pass
	else:
		# print_debug("UnitFSM (%s): No valid obstructions found." % unit.name)
		pass
				
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
	
	if current_state == UnitAIConstants.State.ATTACKING and current_target == attacker:
		return
	
	# print_debug("UnitFSM (%s): Retaliating against %s" % [unit.name, attacker.name])
	current_target = attacker 
	change_state(UnitAIConstants.State.ATTACKING)

func command_attack_obstruction(target: Node2D) -> void:
	"""
	Attack a target (like a wall) without losing the main objective_target.
	"""
	if not is_instance_valid(target):
		return
		
	# print_debug("UnitFSM (%s): Attacking obstruction %s" % [unit.name, target.name])
	current_target = target
	target_position = target.global_position
	
	var distance: float = unit.global_position.distance_to(target.global_position)
	
	if distance <= unit.data.attack_range:
		change_state(UnitAIConstants.State.ATTACKING)
	else:
		change_state(UnitAIConstants.State.MOVING) # Move to the obstruction

func command_move_to_formation_pos(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	
	current_target = null 
	objective_target = null
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	path.clear()
	path.append(target_pos)
	
	change_state(UnitAIConstants.State.FORMATION_MOVING)

func command_move_to(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos

	current_target = null
	objective_target = null
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	change_state(UnitAIConstants.State.MOVING)

func command_attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		print("Cannot attack invalid target")
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()
		return
	
	# print_debug("UnitFSM (%s): Commanded to attack %s" % [unit.name, target.name])
	objective_target = target
	current_target = target
	target_position = target.global_position
	
	var distance: float = unit.global_position.distance_to(target.global_position)
	
	if distance <= unit.data.attack_range:
		change_state(UnitAIConstants.State.ATTACKING)
	else:
		change_state(UnitAIConstants.State.MOVING)

# --- State Machine Update ---

func update(delta: float) -> void:
	match current_state:
		UnitAIConstants.State.IDLE:
			_idle_state(delta)
		UnitAIConstants.State.MOVING:
			_move_state(delta)
		UnitAIConstants.State.FORMATION_MOVING:
			_formation_move_state(delta)
		UnitAIConstants.State.ATTACKING:
			_attack_state(delta)

# --- State Logic Functions ---

func _idle_state(_delta: float) -> void:
	unit.velocity = Vector2.ZERO

func _formation_move_state(delta: float) -> void:
	if path.is_empty():
		change_state(UnitAIConstants.State.IDLE)
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
			change_state(UnitAIConstants.State.IDLE)

func _move_state(delta: float) -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target

	if not is_instance_valid(target_node):
		change_state(UnitAIConstants.State.IDLE)
		return
	
	# Check if we are in range to attack our current target
	var distance_to_target: float = unit.global_position.distance_to(target_node.global_position)
	if distance_to_target <= unit.data.attack_range:
		change_state(UnitAIConstants.State.ATTACKING)
		return
	
	# If we have a path, follow it
	if not path.is_empty():
		var next_waypoint: Vector2 = path[0]
		var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
		var velocity: Vector2 = direction * unit.data.move_speed
		
		unit.velocity = velocity
		unit.move_and_slide()
		
		var arrival_radius: float = 8.0 
		if unit.global_position.distance_to(next_waypoint) < arrival_radius:
			path.pop_front()
		
		# Stuck Timer Logic (for when path is valid but blocked by units)
		if unit.velocity.length_squared() < 1.0:
			stuck_timer += delta
			if stuck_timer > 1.5: # Stuck for 1.5 seconds
				var blocking_building = _find_closest_blocking_building()
				if is_instance_valid(blocking_building):
					push_warning("Unit is stuck. Attacking obstruction: %s" % blocking_building.name)
					command_attack_obstruction(blocking_building)
				else:
					change_state(UnitAIConstants.State.IDLE) # Give up
				stuck_timer = 0.0 # Reset timer
		else:
			stuck_timer = 0.0 # Not stuck, reset timer
			
		return # We are pathfollowing, logic is done for this frame
	
	# --- Path is Empty Logic ---
	# If we are here, path is empty AND we are not in attack range.
	# This means A* failed or the path ended prematurely.
	
	# Check if our target is the main objective (e.g. Great Hall)
	if target_node == objective_target and is_instance_valid(objective_target):
		# Yes. This means we are stuck. Find an obstruction.
		var blocking_building = _find_closest_blocking_building()
		if is_instance_valid(blocking_building):
			
			# --- THIS IS THE FIX ---
			# We remove the noisy warning. The logic is working,
			# but we don't need to be told about it every frame.
			# The "Unit is stuck" warning above is more useful.
			# push_warning("Path to %s blocked. Attacking obstruction: %s" % [objective_target.name, blocking_building.name])
			# --- END FIX ---
			
			command_attack_obstruction(blocking_building)
		else:
			# Truly stuck, no obstructions found
			change_state(UnitAIConstants.State.IDLE)
	else:
		# No. This means our target IS the obstruction (e.g. the Wall).
		# A* pathfinding failed, so we must move in a straight line.
		var direction: Vector2 = (target_node.global_position - unit.global_position).normalized()
		var velocity: Vector2 = direction * unit.data.move_speed
		unit.velocity = velocity
		unit.move_and_slide()
		
		# We are now B-lining the target. If we get stuck...
		if unit.velocity.length_squared() < 1.0:
			stuck_timer += delta
			if stuck_timer > 0.5: # Shorter timer for B-line stuck
				# We are probably stuck on another unit
				change_state(UnitAIConstants.State.IDLE) # Give up
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0

func _attack_state(_delta: float) -> void:
	if not is_instance_valid(current_target):
		# Target is dead or gone
		_resume_objective()
		return
	
	var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
	if distance_to_target > unit.data.attack_range + 10: # +10 pixel buffer
		# Target moved out of range
		# print_debug("UnitFSM (%s): Target %s moved out of range." % [unit.name, current_target.name])
		_resume_objective()
		return
	
	# Otherwise, stay in ATTACKING state
	unit.velocity = Vector2.ZERO

func _resume_objective() -> void:
	"""
	Called when an attack is finished.
	Forces the FSM to re-evaluate its main objective OR find a new one.
	"""
	# print_debug("UnitFSM (%s): Resuming main objective." % unit.name)
	current_target = null
		
	if is_instance_valid(objective_target):
		# print_debug("UnitFSM (%s): Objective %s is valid. Recalculating path." % [unit.name, objective_target.name])
		current_target = objective_target
		change_state(UnitAIConstants.State.MOVING)
	else:
		# --- MODIFIED PLAYER AI LOGIC ---
		# If we are a player unit (DEFAULT AI), find a new target.
		if attack_ai and attack_ai.ai_mode == AttackAI.AI_Mode.DEFAULT:
			var new_target = _find_closest_enemy_in_los()
			if is_instance_valid(new_target):
				print_debug("UnitFSM (%s): Player unit auto-acquiring new target: %s" % [unit.name, new_target.name])
				command_attack(new_target) # This sets both objective and current target
			else:
				# print_debug("UnitFSM (%s): No valid objective or new targets. Idling." % unit.name)
				change_state(UnitAIConstants.State.IDLE)
		else:
			# If we are an enemy AI, just idle.
			# print_debug("UnitFSM (%s): No valid objective. Idling." % unit.name)
			change_state(UnitAIConstants.State.IDLE)
# --- END MODIFIED LOGIC ---

# --- MODIFIED: Find Target in LOS (Units + Buildings) ---
func _find_closest_enemy_in_los() -> Node2D:
	var mission_node = unit.get_parent()
	if not is_instance_valid(mission_node):
		push_error("UnitFSM: Cannot find mission node to check for targets.")
		return null

	var closest_target: Node2D = null
	var min_dist_sq = los_range * los_range # Max range
	var unit_pos = unit.global_position

	# 1. Check Enemy Buildings (Layer 4)
	var building_container = mission_node.get_node_or_null("BuildingContainer")
	if is_instance_valid(building_container):
		for building in building_container.get_children():
			# Must be a building and must be an enemy (Layer 4)
			if not building is BaseBuilding or not (building.collision_layer & (1 << 3)):
				continue
				
			var dist_sq = unit_pos.distance_squared_to(building.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_target = building
	else:
		push_warning("UnitFSM: Could not find BuildingContainer to check for building targets.")

	# 2. Check Enemy Units (Layer 3)
	# We use get_tree() for groups, as units might not be under a single container
	var enemy_units = unit.get_tree().get_nodes_in_group("enemy_units")
	for enemy_unit in enemy_units:
		if not is_instance_valid(enemy_unit) or not enemy_unit is Node2D:
			continue

		var dist_sq = unit_pos.distance_squared_to(enemy_unit.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_target = enemy_unit
			
	return closest_target
# --- END MODIFIED ---

func _check_defensive_response() -> void:
	pass

# --- AI Signal Callbacks ---
func _on_ai_attack_started(target: Node2D) -> void:
	
	# If the FSM is not IDLE, it means it's busy with a player
	# command (MOVING or ATTACKING). In this case, we must
	# ignore the AttackAI's auto-target suggestions.
	if current_state != UnitAIConstants.State.IDLE:
		return
		
	# If we ARE idle, an enemy wandered into range.
	# This is a valid "attack of opportunity."
	
	if current_state == UnitAIConstants.State.ATTACKING and target == current_target:
		return
		
	if attack_ai.ai_mode == AttackAI.AI_Mode.DEFENSIVE_SIEGE:
		return
		
	# print_debug("UnitFSM (%s): AI auto-attack started on %s" % [unit.name, target.name])
	current_target = target
	change_state(UnitAIConstants.State.ATTACKING)

func _on_ai_attack_stopped() -> void:
	# The AttackAI has stopped (e.g., target out of range)
	if current_state == UnitAIConstants.State.ATTACKING:
		# print_debug("UnitFSM (%s): AI attack on %s stopped." % [unit.name, current_target.name if is_instance_valid(current_target) else "null"])
		_resume_objective()
