# res://scripts/ai/UnitFSM.gd
# Refactored UnitFSM for Phase 3 RTS commands
# Now uses modular AttackAI component for attacking behavior
# GDD Ref: Phase 3 Task 4

class_name UnitFSM

# --- MODIFIED: Added ATTACKING state back ---
enum State { IDLE, MOVING, FORMATION_MOVING, ATTACKING }
enum Stance { DEFENSIVE, HOLD_POSITION }

# Unit References
var unit: BaseUnit
var attack_ai: AttackAI  # Reference to the AttackAI component

# State Data
var current_state: State = State.IDLE
var stance: Stance = Stance.DEFENSIVE
var path: Array = []

# Target Data
var target_position: Vector2 = Vector2.ZERO
var move_command_position: Vector2 = Vector2.ZERO

# --- MODIFIED: Split target into "objective" and "current" ---
var objective_target: Node2D = null # The long-term goal (e.g., Great Hall)
var current_target: Node2D = null # The immediate threat (e.g., nearby unit)
# --- END MODIFIED ---

func _init(p_unit: BaseUnit, p_attack_ai: AttackAI) -> void:
	unit = p_unit
	attack_ai = p_attack_ai
	
	if attack_ai:
		attack_ai.attack_started.connect(_on_ai_attack_started)
		attack_ai.attack_stopped.connect(_on_ai_attack_stopped)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
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
			# Let the AttackAI component handle the forced attack
			if attack_ai and is_instance_valid(current_target):
				attack_ai.force_target(current_target)

func _exit_state(state: State) -> void:
	match state:
		State.MOVING:
			path.clear()
		State.FORMATION_MOVING:
			path.clear()
		
		State.ATTACKING:
			# If we were attacking, stop the AI component
			if attack_ai:
				attack_ai.stop_attacking()
			# Clear the *current* target, but not the objective
			current_target = null

func _recalculate_path() -> void:
	# --- MODIFIED: Pathfind to the correct target ---
	# If we have an immediate target, path to it.
	# Otherwise, path to our long-term objective.
	var target_node = current_target if is_instance_valid(current_target) else objective_target
	
	if not is_instance_valid(target_node):
		change_state(State.IDLE)
		return
		
	target_position = target_node.global_position
	# --- END MODIFIED ---
	
	# Determine if we should allow a partial path.
	# We allow it if we are pathing to any attack target.
	var allow_partial = is_instance_valid(target_node)
	
	path = SettlementManager.get_astar_path(unit.global_position, target_position, allow_partial)
	
	if path.is_empty():
		print("Unit at %s failed to find a path to %s." % [unit.global_position, target_position])
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()
		
		# If we can't find a path but have a target, just attack
		if is_instance_valid(target_node):
			change_state(State.ATTACKING)
		else:
			change_state(State.IDLE)

# --- RTS Command Functions ---

func command_move_to_formation_pos(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	
	# Clear both targets
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

	# Clear both targets
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
	
	# Set both targets. The objective is the commanded target.
	# The current target is also the commanded target, until interrupted.
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
	# Note: The AttackAI is still scanning.
	# If it finds a target, _on_ai_attack_started will fire
	# and pull the unit out of IDLE.

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
	# The AttackAI is scanning automatically.
	# If it finds a target, it will interrupt this state
	# via the _on_ai_attack_started signal.
	
	var target_node = current_target if is_instance_valid(current_target) else objective_target

	if not is_instance_valid(target_node):
		# Our objective was destroyed or we had no objective
		change_state(State.IDLE)
		return
	
	# Check if we are in range of our *current* target
	if is_instance_valid(current_target):
		var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
		if distance_to_target <= unit.data.attack_range:
			change_state(State.ATTACKING)
			return
	
	if path.is_empty():
		# Path is empty, but we're not in range.
		# This means we've arrived at the closest point.
		if is_instance_valid(target_node):
			change_state(State.ATTACKING)
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
			# We've reached the end of the path
			if is_instance_valid(target_node):
				change_state(State.ATTACKING)
			else:
				change_state(State.IDLE)

func _attack_state(_delta: float) -> void:
	# This state just monitors the target.
	# The AttackAI component handles the actual firing.
	if not is_instance_valid(current_target):
		# Target is dead or gone
		# _on_ai_attack_stopped will handle resuming the objective
		change_state(State.IDLE) # Go to idle temporarily
		return
	
	var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
	if distance_to_target > unit.data.attack_range + 10: # +10 pixel buffer
		# Target moved out of range
		current_target = null # Lose the target
		
		# Resume objective
		if is_instance_valid(objective_target):
			change_state(State.MOVING)
		else:
			change_state(State.IDLE)
		return
	
	# Otherwise, stay in ATTACKING state
	unit.velocity = Vector2.ZERO

func _check_defensive_response() -> void:
	pass

# --- AI Signal Callbacks ---
func _on_ai_attack_started(target: Node2D) -> void:
	# The AttackAI found a target of opportunity!
	# Interrupt whatever we're doing.
	
	# Don't switch if we are already attacking this target
	if current_state == State.ATTACKING and target == current_target:
		return
		
	print("UnitFSM: Interrupted! AttackAI found new target: %s" % target.name)
	current_target = target # Set as our immediate target
	change_state(State.ATTACKING)

func _on_ai_attack_stopped() -> void:
	# The AttackAI has stopped (e.g., target died, or moved out of range)
	if current_state == State.ATTACKING:
		print("UnitFSM: Attack finished.")
		current_target = null
		
		# Check if we have a long-term objective to resume
		if is_instance_valid(objective_target):
			print("UnitFSM: Resuming objective: %s" % objective_target.name)
			current_target = objective_target # Set our current target back to the objective
			change_state(State.MOVING) # Go back to moving
		else:
			# No objective, just go idle
			print("UnitFSM: No objective. Going IDLE.")
			change_state(State.IDLE)
