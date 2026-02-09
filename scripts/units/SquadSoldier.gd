#res://scripts/units/SquadSoldier.gd
## SquadSoldier handles specialized formation movement while delegating 
## core physics and avoidance to BaseUnit.
class_name SquadSoldier
extends BaseUnit

@export_group("Squad Settings")
## Distance at which the soldier stops trying to reach the formation slot.
@export var stop_dist: float = 5.0

# --- State Variables ---
var leader: Node2D = null
## The calculated global position this unit should occupy in formation.
var formation_target: Vector2 = Vector2.ZERO
var brawl_target: Node2D = null
var is_rubber_banding: bool = false
var stuck_detector: Node

# --- Constants ---
const MAX_DIST_FROM_LEADER = 300.0
const CATCHUP_DIST = 80.0
const SPRINT_SPEED_MULT = 2.5

# --- Prisoner Logic ---
var pending_prisoners: Array[Node2D] = [] 
var escorted_prisoners: Array[Node2D] = []
var retreat_zone_cache: Node2D = null

func _ready() -> void:
	# Initialize BaseUnit first
	super._ready()
	
	# Squad specific init
	separation_force = 80.0 
	separation_radius = 25.0
	separation_enabled = true
	avoidance_priority = 1 # Lower priority than heavy units?
	
	if attack_ai:
		attack_ai.attack_started.connect(func(t): if not is_rubber_banding: brawl_target = t)
		attack_ai.attack_stopped.connect(func(): brawl_target = null)
		# Expand detection for squad behavior if needed
		if attack_ai.detection_area:
			for c in attack_ai.detection_area.get_children():
				if c is CollisionShape2D and c.shape is CircleShape2D: c.shape.radius = 120.0

	stuck_detector = get_node_or_null("StuckDetector")
	if not stuck_detector:
		stuck_detector = get_node_or_null("DEBUG_StuckReporter")

	Loggie.msg("SquadSoldier initialized").domain("GAMEPLAY").info()

func _physics_process(delta: float) -> void:
	# 1. FSM High Priority (Tasks like Collecting/Escorting take precedence)
	# These states use standard NavAgent logic via BaseUnit's FSM.
	if fsm.current_state in [
		UnitAIConstants.State.COLLECTING, 
		UnitAIConstants.State.ESCORTING, 
		UnitAIConstants.State.REGROUPING, 
		UnitAIConstants.State.RETREATING
	]:
		uses_external_steering = false
		super._physics_process(delta)
		return

	# 2. Safety Check
	if not is_instance_valid(leader):
		velocity = velocity.lerp(Vector2.ZERO, data.linear_damping * delta)
		super._physics_process(delta)
		return

	# 3. Enable External Steering Mode
	uses_external_steering = true

	# 4. Rubber Banding Logic
	# Calculate speed modifier based on distance to leader
	var current_speed = data.move_speed
	var dist_leader = global_position.distance_to(leader.global_position)
	
	var is_phasing = false
	if stuck_detector and "is_phasing" in stuck_detector:
		is_phasing = stuck_detector.is_phasing
	
	# Logic: If we are far behind, disable collision logic (phasing) and sprint
	if not is_phasing:
		if not is_rubber_banding and dist_leader > MAX_DIST_FROM_LEADER:
			is_rubber_banding = true
			collision_mask = LAYER_ENV # Environment only, ignore units
			modulate.a = 0.5
			separation_enabled = false # BaseUnit checks this flag
		elif is_rubber_banding and dist_leader < CATCHUP_DIST:
			is_rubber_banding = false
			_restore_collision_logic()
			modulate.a = 1.0
			separation_enabled = true
		
	if is_rubber_banding:
		brawl_target = null # Ignore combat when catching up
		current_speed *= SPRINT_SPEED_MULT
	
	# 5. Determine Target (Combat vs Formation)
	var final_dest = formation_target
	var final_stop_dist = stop_dist
	
	if is_instance_valid(brawl_target) and not is_rubber_banding:
		final_dest = brawl_target.global_position
		
		# Calculate dynamic attack range
		var range_limit = data.attack_range
		if brawl_target is BaseBuilding or (brawl_target.name == "Hitbox" and brawl_target.get_parent() is BaseBuilding):
			range_limit = data.building_attack_range
			
		var r_target = _get_radius(brawl_target)
		final_stop_dist = r_target + range_limit - 5.0
		if final_stop_dist < 5.0: final_stop_dist = 5.0
		
		if attack_ai: 
			attack_ai.force_target(brawl_target)
	
	# 6. Apply Velocity (Direct Set for BaseUnit Smoothing)
	if final_dest != Vector2.ZERO:
		var dist = global_position.distance_to(final_dest)
		
		if dist > final_stop_dist:
			# Direct assignment: BaseUnit will handle the acceleration/lerp
			velocity = (final_dest - global_position).normalized() * current_speed
		else:
			# Arrived: Let BaseUnit damp to zero
			velocity = Vector2.ZERO

	# 7. Hand-off to BaseUnit
	# BaseUnit will handle move_and_slide, separation (if enabled), and avoidance whiskers
	super._physics_process(delta)

func _restore_collision_logic() -> void:
	# Use inherited constants from BaseUnit to prevent magic number rot
	collision_mask = LAYER_ENV | LAYER_PLAYER_UNIT | LAYER_ENEMY_UNIT

## Custom log for squad assignment
func set_squad_leader(new_leader: Node2D) -> void:
	leader = new_leader
	Loggie.msg("Soldier joined squad").domain("GAMEPLAY").context({"leader": leader.name}).info()

# --- Utility & Prisoner Logic (Ported from Legacy) ---

func _get_radius(node: Node2D) -> float:
	if node.name == "Hitbox" and node.get_parent() is BaseBuilding:
		var b = node.get_parent()
		if b.data: return (min(b.data.grid_size.x, b.data.grid_size.y) * 32.0) / 2.0
	return 15.0

func assign_escort_task(prisoner: Node2D) -> void:
	if not is_inside_tree() or not prisoner: return
	if not retreat_zone_cache: retreat_zone_cache = get_tree().get_first_node_in_group("retreat_zone")
	
	if not prisoner in pending_prisoners and not prisoner in escorted_prisoners:
		pending_prisoners.append(prisoner)
	
	if fsm:
		fsm.objective_target = prisoner
		fsm.change_state(UnitAIConstants.State.COLLECTING)

func _set_next_collection_target() -> void:
	if pending_prisoners.size() > 0:
		var next = pending_prisoners[0]
		fsm.objective_target = next
		fsm.change_state(UnitAIConstants.State.COLLECTING)
		EventBus.floating_text_requested.emit("Got it!", global_position, Color.WHITE)
	else:
		_switch_to_escorting()

func process_collecting_logic(_delta: float) -> void:
	if not is_instance_valid(fsm.objective_target):
		pending_prisoners.erase(fsm.objective_target)
		_set_next_collection_target()
		return

	var dist = global_position.distance_to(fsm.objective_target.global_position)
	if dist < 50.0:
		_collect_prisoner(fsm.objective_target)

func _collect_prisoner(prisoner: Node2D) -> void:
	pending_prisoners.erase(prisoner)
	if not prisoner in escorted_prisoners:
		escorted_prisoners.append(prisoner)
		if prisoner.has_method("attach_to_escort"):
			prisoner.attach_to_escort(self)
	
	if pending_prisoners.size() > 0:
		_set_next_collection_target()
	else:
		_switch_to_escorting()

func _switch_to_escorting() -> void:
	if escorted_prisoners.is_empty():
		fsm.change_state(UnitAIConstants.State.REGROUPING)
		return
	fsm.objective_target = retreat_zone_cache
	fsm.change_state(UnitAIConstants.State.ESCORTING)

func process_escort_logic(_delta: float) -> void:
	pass
	
func complete_escort() -> void:
	if escorted_prisoners.is_empty():
		fsm.change_state(UnitAIConstants.State.REGROUPING)
		return

	var count = 0
	for prisoner in escorted_prisoners:
		if is_instance_valid(prisoner):
			EventBus.raid_loot_secured.emit("thrall", 1) 
			EventBus.floating_text_requested.emit("+1 Thrall", prisoner.global_position, Color.CYAN)
			prisoner.queue_free()
			count += 1
	
	escorted_prisoners.clear()
	EventBus.floating_text_requested.emit("Prisoners Secured", global_position, Color.GREEN)
	fsm.change_state(UnitAIConstants.State.REGROUPING)

func process_regroup_logic(_delta: float) -> void:
	if is_instance_valid(leader):
		fsm.move_command_position = leader.global_position
		if global_position.distance_to(leader.global_position) < 100.0:
			fsm.change_state(UnitAIConstants.State.MOVING)
	else:
		fsm.change_state(UnitAIConstants.State.IDLE)
