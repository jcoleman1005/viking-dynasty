# res://scripts/units/CivilianUnit.gd
class_name CivilianUnit
extends BaseUnit

# --- State ---
var interaction_target: BaseBuilding = null

func _ready() -> void:
	super._ready()
	add_to_group("civilians")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Check arrival
	if is_instance_valid(interaction_target):
		_check_arrival_via_geometry()

func command_interact(target: Node2D) -> void:
	if target is BaseBuilding:
		interaction_target = target
		
		# Use the SAFE approach command (no attack logic)
		if fsm and fsm.has_method("command_interact_move"):
			fsm.command_interact_move(target)
		else:
			command_move_to(target.global_position)

func _check_arrival_via_geometry() -> void:
	if not interaction_target.data: return
	
	# 1. Get Dimensions (Assume 32x32 standard)
	var cell_size = Vector2(32, 32) 
	var b_grid_size = Vector2(interaction_target.data.grid_size)
	var b_size_px = b_grid_size * cell_size
	
	# 2. Define Geometry
	var top_left = interaction_target.global_position - (b_size_px / 2.0)
	var building_rect = Rect2(top_left, b_size_px)
	var interaction_zone = building_rect.grow(15.0) # 15px Buffer
	
	# 3. Check
	if interaction_zone.has_point(global_position):
		_perform_assignment(interaction_target)
		interaction_target = null

func _perform_assignment(building: BaseBuilding) -> void:
	Loggie.msg("Civilian attempting to enter %s..." % building.data.display_name).domain("UNIT").info()
	
	# 1. Attempt Assignment (Check Return Value)
	var success = SettlementManager.assign_worker_from_unit(building, "peasant")
	
	if success:
		# 2a. Success: Delete Self
		Loggie.msg("Assignment Success. Despawning.").domain("UNIT").debug()
		die_without_event()
	else:
		# 2b. Failure (Full): Cancel interaction and Idle
		Loggie.msg("Assignment Failed (Building Full). Stopping.").domain("UNIT").warn()
		interaction_target = null
		
		# Stop moving physically
		velocity = Vector2.ZERO
		
		# Reset FSM to Idle so we don't keep walking into the wall
		if fsm:
			fsm.change_state(UnitAIConstants.State.IDLE)

func die_without_event() -> void:
	queue_free()
