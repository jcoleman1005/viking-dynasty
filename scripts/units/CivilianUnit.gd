#res://scripts/units/CivilianUnit.gd
class_name CivilianUnit
extends BaseUnit

# --- Mob Settings ---
@export_group("Mob AI")
@export var mob_separation_force: float = 100.0 
@export var mob_separation_radius: float = 45.0 

@export var thrall_unit_scene: PackedScene 
@export var surrender_hp_threshold: int = 10 # Triggers when HP <= 10

# Signal for the Manager to hear
signal surrender_requested(civilian_node: Node2D)

# --- State ---
var interaction_target: BaseBuilding = null
var skip_assignment_logic: bool = false
var _is_surrendered: bool = false
var escort_target: Node2D = null

func _ready() -> void:
	separation_force = mob_separation_force
	separation_radius = mob_separation_radius
	separation_enabled = true
	super._ready()
	add_to_group("civilians")

func _physics_process(delta: float) -> void:
	if _is_surrendered:
		_process_surrender_behavior(delta)
	else:
		super._physics_process(delta)

# [CRITICAL RESTORATION] Override Take Damage
func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_surrendered: return
	
	current_health -= amount
	print("Civilian hit! HP: ", current_health) # Debug Logic
	
	if current_health <= surrender_hp_threshold:
		current_health = 1 # Keep alive for escort
		_trigger_surrender()

func _trigger_surrender() -> void:
	if _is_surrendered: return
	_is_surrendered = true
	
	print("Civilian Surrendered!") # Debug Logic
	
	# Visual Feedback
	modulate = Color(0.5, 0.5, 0.5, 1.0) # Turn Grey
	EventBus.floating_text_requested.emit("Surrendered!", global_position, Color.WHITE)
	
	# Stop Moving
	if fsm: 
		fsm.change_state(UnitAIConstants.State.IDLE)
		velocity = Vector2.ZERO
	
	# Emit Signal for SquadLeader to hear
	surrender_requested.emit(self)

# Logic to follow the soldier
func attach_to_escort(soldier: Node2D) -> void:
	escort_target = soldier
	EventBus.floating_text_requested.emit("Captured", global_position, Color.CYAN)

func _process_surrender_behavior(_delta: float) -> void:
	if is_instance_valid(escort_target):
		var dist = global_position.distance_to(escort_target.global_position)
		if dist > 60.0:
			var dir = (escort_target.global_position - global_position).normalized()
			# Dragged slower than normal speed
			velocity = dir * (data.move_speed * 0.9)
			move_and_slide()
		else:
			velocity = Vector2.ZERO

# ... (Keep existing interaction/assignment functions if you use them for home base) ...
func command_interact(target: Node2D) -> void:
	if target is BaseBuilding:
		interaction_target = target
		if fsm and fsm.has_method("command_interact_move"):
			fsm.command_interact_move(target)
