# res://scripts/ai/UnitFSM.gd
#
# --- MODIFIED: Implemented full ATTACK state logic ---

class_name UnitFSM

enum State { IDLE, MOVE, ATTACK }

# Unit References
var unit: BaseUnit
var attack_timer: Timer

# State Data
var current_state: State = State.IDLE
var path: Array = []

# Target Data
var target_position: Vector2 = Vector2.ZERO
var target_node: BaseBuilding = null # The building we want to attack

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
		State.MOVE:
			recalculate_path()
		
		State.ATTACK:
			print("%s entering ATTACK state." % unit.data.display_name)
			# Set timer wait time based on unit's attack speed
			attack_timer.wait_time = 1.0 / unit.data.attack_speed
			attack_timer.start()
			# Attack immediately on entering state
			_on_attack_timer_timeout()

func _exit_state(state: State) -> void:
	match state:
		State.MOVE:
			path.clear()
		State.ATTACK:
			attack_timer.stop()

func recalculate_path() -> void:
	path = SettlementManager.get_astar_path(unit.global_position, target_position)
	if path.is_empty():
		print("Raider at %s failed to find a path to %s." % [unit.global_position, target_position])
		# If we can't find a path, check if we're already at the target
		if unit.global_position.distance_to(target_position) < (unit.data.attack_range + 16):
			change_state(State.ATTACK)
		else:
			change_state(State.IDLE)
	else:
		print("Raider found new path. Waypoints: %d" % path.size())

func update(delta: float) -> void:
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.MOVE:
			_move_state(delta)
		State.ATTACK:
			_attack_state(delta)

# --- State Logic Functions ---

func _idle_state(_delta: float) -> void:
	# In a full game, would look for a new target
	pass

func _move_state(delta: float) -> void:
	if path.is_empty():
		# Path is done, check if we're at the target
		if target_node and is_instance_valid(target_node):
			change_state(State.ATTACK)
		else:
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
		
	# Check if we've arrived at the final target
	if path.is_empty():
		if target_node:
			change_state(State.ATTACK)
		else:
			change_state(State.IDLE)
		
func _attack_state(_delta: float) -> void:
	# Check if target is still valid
	if not is_instance_valid(target_node):
		print("%s target destroyed. Returning to IDLE." % unit.data.display_name)
		change_state(State.IDLE)
		return
	
	# Check if target moved out of range (e.g., for moving targets)
	# For a building, this is less important, but good practice.
	if unit.global_position.distance_to(target_node.global_position) > unit.data.attack_range + 16:
		print("%s target moved out of range. Re-engaging." % unit.data.display_name)
		target_position = target_node.global_position
		change_state(State.MOVE)

# --- Signal Callback ---

func _on_attack_timer_timeout() -> void:
	"""
	This is called every time the AttackTimer finishes.
	"""
	if is_instance_valid(target_node):
		print("%s attacks %s!" % [unit.data.display_name, target_node.data.display_name])
		target_node.take_damage(unit.data.attack_damage)
	else:
		# Target was destroyed by something else
		change_state(State.IDLE)
