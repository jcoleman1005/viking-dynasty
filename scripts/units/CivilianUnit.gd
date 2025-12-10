# res://scripts/units/CivilianUnit.gd
class_name CivilianUnit
extends BaseUnit

# --- Mob Settings ---
@export_group("Mob AI")
@export var mob_separation_force: float = 100.0 
@export var mob_separation_radius: float = 45.0 

@export var thrall_unit_scene: PackedScene 
@export var surrender_hp_threshold: int = 0

signal surrender_requested(civilian_node: Node2D)

# --- State ---
var interaction_target: BaseBuilding = null
var skip_assignment_logic: bool = false # NEW FLAG
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

func take_damage(amount: int, attacker: Node2D = null) -> void:
	if _is_surrendered: return
	current_health -= amount
	if current_health <= surrender_hp_threshold:
		current_health = 1 
		_trigger_surrender()

func _trigger_surrender() -> void:
	_is_surrendered = true
	if fsm: fsm.change_state(UnitAIConstants.State.IDLE)
	modulate = Color(0.7, 0.7, 0.7, 1.0) 
	EventBus.floating_text_requested.emit("Surrendered!", global_position, Color.WHITE)
	surrender_requested.emit(self)

func attach_to_escort(soldier: Node2D) -> void:
	escort_target = soldier
	EventBus.floating_text_requested.emit("Captured", global_position, Color.CYAN)

func _process_surrender_behavior(delta: float) -> void:
	if is_instance_valid(escort_target):
		var dist = global_position.distance_to(escort_target.global_position)
		if dist > 60.0:
			var dir = (escort_target.global_position - global_position).normalized()
			velocity = dir * (data.move_speed * 0.9)
			move_and_slide()
		else:
			velocity = Vector2.ZERO

func command_interact(target: Node2D) -> void:
	if target is BaseBuilding:
		interaction_target = target
		# Mark as busy so they aren't picked again while walking
		add_to_group("busy") 
		
		if fsm and fsm.has_method("command_interact_move"):
			fsm.command_interact_move(target)
		else:
			command_move_to(target.global_position)

func _check_arrival_via_geometry() -> void:
	if not interaction_target.data: return
	
	var cell_size = Vector2(32, 32) 
	var b_grid_size = Vector2(interaction_target.data.grid_size)
	var b_size_px = b_grid_size * cell_size
	var top_left = interaction_target.global_position - (b_size_px / 2.0)
	var building_rect = Rect2(top_left, b_size_px)
	var interaction_zone = building_rect.grow(15.0)
	
	if interaction_zone.has_point(global_position):
		_finalize_interaction(interaction_target)
		interaction_target = null

func _finalize_interaction(building: BaseBuilding) -> void:
	# If we already updated the data (skip_assignment_logic is true), 
	# we just despawn. Otherwise, we try to assign now (legacy behavior).
	
	if skip_assignment_logic:
		Loggie.msg("Civilian arrived at %s (Pre-assigned)." % building.data.display_name).domain(LogDomains.UNIT).debug()
		die_without_event()
	else:
		_perform_assignment(building)

func _perform_assignment(building: BaseBuilding) -> void:
	Loggie.msg("Civilian attempting to enter %s..." % building.data.display_name).domain(LogDomains.UNIT).info()
	var success = SettlementManager.assign_worker_from_unit(building, "peasant")
	
	if success:
		Loggie.msg("Assignment Success. Despawning.").domain(LogDomains.UNIT).debug()
		die_without_event()
	else:
		Loggie.msg("Assignment Failed (Building Full). Stopping.").domain(LogDomains.UNIT).warn()
		interaction_target = null
		remove_from_group("busy")
		velocity = Vector2.ZERO
		if fsm: fsm.change_state(UnitAIConstants.State.IDLE)

func die_without_event() -> void:
	queue_free()
