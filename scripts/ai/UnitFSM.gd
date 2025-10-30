# res://scripts/ai/UnitFSM.gd
#
# --- MODIFIED: Added a dedicated recalculate_path() function ---

class_name UnitFSM

enum State { IDLE, MOVE, ATTACK }

var unit: BaseUnit
var current_state: State = State.IDLE
var target_position: Vector2 = Vector2.ZERO
var path: Array = []

func _init(p_unit: BaseUnit) -> void:
	unit = p_unit

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	_exit_state(current_state)
	current_state = new_state
	_enter_state(current_state)

func _enter_state(state: State) -> void:
	match state:
		State.MOVE:
			# --- MODIFIED ---
			# Call the new, dedicated re-pathing function
			recalculate_path()
		State.ATTACK:
			print("Raider entering ATTACK state.")
		_:
			pass

func _exit_state(state: State) -> void:
	match state:
		State.MOVE:
			path.clear()
		_:
			pass

# --- ADDED ---
func recalculate_path() -> void:
	"""
	Requests a new A* path from the SettlementManager.
	This is called when first entering the MOVE state
	or when the grid is updated by a new wall.
	"""
	# This is the logic we moved from _enter_state
	path = SettlementManager.get_astar_path(unit.global_position, target_position)
	if path.is_empty():
		print("Raider at %s failed to find a path to %s." % [unit.global_position, target_position])
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
	pass

func _move_state(delta: float) -> void:
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
		
func _attack_state(_delta: float) -> void:
	pass
