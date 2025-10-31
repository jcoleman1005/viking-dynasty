# res://scripts/ai/UnitFSM.gd
class_name UnitFSM
extends Node

# States for the Finite State Machine
enum State { IDLE, MOVING, ATTACKING }

# --- References ---
var unit: CharacterBody2D
@onready var navigation_agent: NavigationAgent2D = get_parent().get_node("NavigationAgent2D")
@onready var attack_cooldown: Timer = get_parent().get_node("AttackTimer")

# --- State ---
var current_state: State = State.IDLE
var target_unit: Node2D = null

func _ready() -> void:
	
	# Ensure the parent is a CharacterBody2D and has the required nodes
	if not get_parent() is CharacterBody2D:
		push_error("UnitFSM must be a child of a CharacterBody2D.")
		queue_free()
		return
	unit = get_parent()
	attack_cooldown.timeout.connect(_on_attack_cooldown_timeout)


# --- Public Command API ---

func command_move_to(target_position: Vector2) -> void:
	
	"""Public function to issue a move command."""
	target_unit = null # Clear any attack target
	navigation_agent.target_position = target_position
	_change_state(State.MOVING)

func command_attack(p_target_unit: Node2D) -> void:
	
	"""Public function to issue an attack command."""
	if not is_instance_valid(p_target_unit):
		return
	target_unit = p_target_unit
	# Move towards the target, the FSM will handle transitioning to ATTACKING when in range.
	navigation_agent.target_position = target_unit.global_position
	_change_state(State.MOVING)


# --- State Machine Logic ---

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.MOVING:
			_moving_state(delta)
		State.ATTACKING:
			_attacking_state(delta)

func _change_state(new_state: State) -> void:
	
	if current_state == new_state:
		return

	# Exit current state
	match current_state:
		State.ATTACKING:
			attack_cooldown.stop()

	current_state = new_state

	# Enter new state
	match new_state:
		State.IDLE:
			unit.velocity = Vector2.ZERO
			navigation_agent.target_position = unit.global_position
		State.MOVING:
			pass # Target is already set by the command function
		State.ATTACKING:
			unit.velocity = Vector2.ZERO
			attack_cooldown.start()
			_perform_attack() # Attack immediately upon entering state


# --- State Implementations ---

func _idle_state(_delta: float) -> void:
	unit.velocity = Vector2.ZERO
	unit.move_and_slide()

func _moving_state(_delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		_change_state(State.IDLE)
		return

	# If we have an attack target, check if we are in range
	if is_instance_valid(target_unit):
		if unit.global_position.distance_to(target_unit.global_position) <= unit.data.attack_range:
			_change_state(State.ATTACKING)
			return
		else:
			# Update target position in case it moved
			navigation_agent.target_position = target_unit.global_position

	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var new_velocity: Vector2 = (next_path_position - unit.global_position).normalized() * unit.data.move_speed
	unit.velocity = new_velocity
	unit.move_and_slide()

func _attacking_state(_delta: float) -> void:
	unit.velocity = Vector2.ZERO
	unit.move_and_slide()
	# Check if target is still valid and in range
	if not is_instance_valid(target_unit):
		_change_state(State.IDLE)
		return
	
	if unit.global_position.distance_to(target_unit.global_position) > unit.data.attack_range:
		# Target moved out of range, chase it
		command_attack(target_unit) 
		return

# --- Helper Functions ---

func _perform_attack() -> void:
	if not is_instance_valid(target_unit):
		_change_state(State.IDLE)
		return

	if "take_damage" in target_unit:
		print("%s attacks %s!" % [unit.data.display_name, target_unit.data.display_name])
		target_unit.take_damage(unit.data.attack_damage)

func _on_attack_cooldown_timeout() -> void:
	"""Called by the Timer to perform an attack."""
	if current_state == State.ATTACKING:
		_perform_attack()

# --- Defensive Stance Logic ---
# This requires the unit to have an Area2D node named "AggroArea"
# with a signal "body_entered" connected to this function.
func _on_aggro_area_body_entered(body: Node2D) -> void:
	# Only react if currently moving and not already targeting something
	if current_state == State.MOVING and not is_instance_valid(target_unit):
		# TODO: Add faction check to ensure it's an enemy
		if body != unit and "data" in body: # A simple check for something attackable
			print("%s is attacked while moving, retaliating against %s" % [unit.data.display_name, body.data.display_name])
			command_attack(body)
