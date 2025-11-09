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
var target_unit: Node2D = null
var move_command_position: Vector2 = Vector2.ZERO

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
		
		# --- NEW: Handle entering ATTACKING state ---
		State.ATTACKING:
			unit.velocity = Vector2.ZERO
			if attack_ai and is_instance_valid(target_unit):
				attack_ai.force_target(target_unit)
		# ------------------------------------------

func _exit_state(state: State) -> void:
	match state:
		State.MOVING:
			path.clear()
		State.FORMATION_MOVING:
			path.clear()
		
		# --- NEW: Handle exiting ATTACKING state ---
		State.ATTACKING:
			if attack_ai:
				attack_ai.stop_attacking()
		# -----------------------------------------

func _recalculate_path() -> void:
	# --- MODIFICATION ---
	# Determine if we should allow a partial path.
	# We allow it if we have an attack target (target_unit).
	var allow_partial = is_instance_valid(target_unit)
	
	path = SettlementManager.get_astar_path(unit.global_position, target_position, allow_partial)
	# --- END MODIFICATION ---
	
	if path.is_empty():
		print("Unit at %s failed to find a path to %s." % [unit.global_position, target_position])
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()
		
		# If we can't find a path but have a target, just attack
		if is_instance_valid(target_unit):
			change_state(State.ATTACKING)
		else:
			change_state(State.IDLE)
	else:
		pass

# --- RTS Command Functions ---

func command_move_to_formation_pos(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	target_unit = null # Clear any attack target
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	path.clear()
	path.append(target_pos)
	
	change_state(State.FORMATION_MOVING)

func command_move_to(target_pos: Vector2) -> void:
	target_position = target_pos
	move_command_position = target_pos
	target_unit = null # Clear any attack target
	
	if attack_ai:
		attack_ai.stop_attacking()
	
	change_state(State.MOVING)

func command_attack(target: Node2D) -> void:
	if not is_instance_valid(target):
		print("Cannot attack invalid target")
		if unit and unit.has_method("flash_error_color"):
			unit.flash_error_color()
		return
		
	target_unit = target
	
	# --- THIS IS THE FIX ---
	# Target the building's actual center.
	# _recalculate_path will handle finding the closest spot.
	target_position = target.global_position
	# --- END FIX ---
	
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
	# Check if we have an attack target and are now in range
	if is_instance_valid(target_unit):
		var distance_to_target: float = unit.global_position.distance_to(target_unit.global_position)
		
		if distance_to_target <= unit.data.attack_range:
			change_state(State.ATTACKING)
			return
		else:
			# --- MODIFIED: Target the actual center ---
			# The pathfinder will get as close as possible.
			target_position = target_unit.global_position
	
	if stance == Stance.DEFENSIVE:
		_check_defensive_response()
	
	if path.is_empty():
		if is_instance_valid(target_unit):
			_recalculate_path()
			return
		else:
			print("Unit reached destination.")
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
			if is_instance_valid(target_unit):
				var distance_to_target: float = unit.global_position.distance_to(target_unit.global_position)
				if distance_to_target <= unit.data.attack_range:
					change_state(State.ATTACKING)
				else:
					_recalculate_path()
			else:
				change_state(State.IDLE)

func _attack_state(_delta: float) -> void:
	# This state just monitors the target.
	# The AttackAI component handles the actual firing.
	if not is_instance_valid(target_unit):
		# Target is dead or gone
		change_state(State.IDLE)
		return
	
	var distance_to_target: float = unit.global_position.distance_to(target_unit.global_position)
	if distance_to_target > unit.data.attack_range + 10: # +10 pixel buffer
		# Target moved out of range
		change_state(State.MOVING)
		return
	
	# Otherwise, stay in ATTACKING state
	unit.velocity = Vector2.ZERO

func _check_defensive_response() -> void:
	pass

# --- AI Signal Callbacks ---
func _on_ai_attack_started(_target: Node2D) -> void:
	pass

func _on_ai_attack_stopped() -> void:
	# If our AI stops for any reason, go back to IDLE
	if current_state == State.ATTACKING:
		change_state(State.IDLE)
