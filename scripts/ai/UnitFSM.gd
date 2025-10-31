# res://scripts/ai/UnitFSM.gd
# Refactored UnitFSM for Phase 3 RTS commands
# GDD Ref: Phase 3 Task 4

class_name UnitFSM

enum State { IDLE, MOVING, ATTACKING }
enum Stance { DEFENSIVE, HOLD_POSITION } # Future-proofed for other stances

# Unit References
var unit: BaseUnit
var attack_timer: Timer

# State Data
var current_state: State = State.IDLE
var stance: Stance = Stance.DEFENSIVE
var path: Array = []

# Target Data
var target_position: Vector2 = Vector2.ZERO
var target_unit: Node2D = null # Can be BaseBuilding or BaseUnit
var move_command_position: Vector2 = Vector2.ZERO

func _init(p_unit: BaseUnit, p_timer: Timer) -> void:
	unit = p_unit
	attack_timer = p_timer
	
	# Connect the timer's timeout signal to our attack function
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	_exit_state(current_state)
	current_state = new_state
	_enter_state(current_state)

func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			print("%s entering IDLE state." % unit.data.display_name)
			unit.velocity = Vector2.ZERO
			
		State.MOVING:
			print("%s entering MOVING state to %s." % [unit.data.display_name, target_position])
			_recalculate_path()
			
		State.ATTACKING:
			print("%s entering ATTACKING state." % unit.data.display_name)
			unit.velocity = Vector2.ZERO
			# Set timer wait time based on unit's attack speed
			attack_timer.wait_time = 1.0 / unit.data.attack_speed
			attack_timer.start()
			# Attack immediately on entering state
			_on_attack_timer_timeout()

func _exit_state(state: State) -> void:
	match state:
		State.MOVING:
			path.clear()
		State.ATTACKING:
			attack_timer.stop()

func _recalculate_path() -> void:
	path = SettlementManager.get_astar_path(unit.global_position, target_position)
	if path.is_empty():
		print("Unit at %s failed to find a path to %s." % [unit.global_position, target_position])
		# If we can't find a path, check if we're already close to the target
		if unit.global_position.distance_to(target_position) < (unit.data.attack_range + 16):
			if target_unit:
				change_state(State.ATTACKING)
			else:
				change_state(State.IDLE)
		else:
			change_state(State.IDLE)
	else:
		print("Unit found new path. Waypoints: %d" % path.size())

# --- RTS Command Functions ---

func command_move_to(target_pos: Vector2) -> void:
	"""Command the unit to move to a specific position"""
	target_position = target_pos
	move_command_position = target_pos
	target_unit = null # Clear any attack target
	change_state(State.MOVING)

func command_attack(target: Node2D) -> void:
	"""Command the unit to attack a specific target"""
	if not is_instance_valid(target):
		print("Cannot attack invalid target")
		return
		
	target_unit = target
	target_position = target.global_position
	
	# Check if we're already in range
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
		State.ATTACKING:
			_attack_state(delta)

# --- State Logic Functions ---

func _idle_state(_delta: float) -> void:
	# In idle state, unit stands still
	unit.velocity = Vector2.ZERO

func _move_state(delta: float) -> void:
	# First priority: Check if we have a valid attack target and are in range
	if is_instance_valid(target_unit):
		var distance_to_target: float = unit.global_position.distance_to(target_unit.global_position)
		if distance_to_target <= unit.data.attack_range:
			print("Unit in attack range, switching to ATTACKING.")
			change_state(State.ATTACKING)
			return
		else:
			# Update target position if target moved
			target_position = target_unit.global_position
	
	# Handle defensive stance: Check for nearby enemies if being attacked
	if stance == Stance.DEFENSIVE:
		_check_defensive_response()
	
	# If we're not in range, check if our path is empty
	if path.is_empty():
		# If we have an attack target but no path, try to recalculate
		if is_instance_valid(target_unit):
			_recalculate_path()
			return
		else:
			# No target and no path, we've reached our destination
			print("Unit reached destination.")
			change_state(State.IDLE)
			return
	
	# Move along the path
	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var velocity: Vector2 = direction * unit.data.move_speed
	
	unit.velocity = velocity
	unit.move_and_slide()
	
	# Check if we've reached the current waypoint
	var arrival_radius: float = 8.0 
	if unit.global_position.distance_to(next_waypoint) < arrival_radius:
		path.pop_front()
		
		# If that was the last waypoint, check what to do next
		if path.is_empty():
			if is_instance_valid(target_unit):
				var distance_to_target: float = unit.global_position.distance_to(target_unit.global_position)
				if distance_to_target <= unit.data.attack_range:
					change_state(State.ATTACKING)
				else:
					# Target moved, recalculate path
					_recalculate_path()
			else:
				# Just a move command, we're done
				change_state(State.IDLE)

func _attack_state(_delta: float) -> void:
	# Check if target is still valid
	if not is_instance_valid(target_unit):
		print("%s target destroyed or invalid. Returning to IDLE." % unit.data.display_name)
		change_state(State.IDLE)
		return
	
	# Check if target moved out of range
	var distance_to_target: float = unit.global_position.distance_to(target_unit.global_position)
	if distance_to_target > unit.data.attack_range + 16: # Small buffer to avoid oscillation
		print("%s target moved out of range. Re-engaging." % unit.data.display_name)
		target_position = target_unit.global_position
		change_state(State.MOVING)

func _check_defensive_response() -> void:
	"""Check if unit should respond defensively to being attacked"""
	# This is a placeholder for future implementation
	# In a real implementation, this might check for nearby enemies
	# or respond to damage events
	pass

# --- Signal Callback ---

func _on_attack_timer_timeout() -> void:
	"""Called every time the AttackTimer finishes"""
	if current_state != State.ATTACKING:
		return
		
	if is_instance_valid(target_unit):
		print("%s attacks %s!" % [unit.data.display_name, target_unit.name])
		
		# Check if target has a take_damage method
		if target_unit.has_method("take_damage"):
			target_unit.take_damage(unit.data.attack_damage)
		else:
			print("Target %s does not have take_damage method" % target_unit.name)
	else:
		print("Attack timer fired but no valid target")
		change_state(State.IDLE)
