# res://scripts/units/SquadSoldier.gd
class_name SquadSoldier
extends BaseUnit

var leader: SquadLeader
var formation_target: Vector2 = Vector2.ZERO
var brawl_target: Node2D = null
var is_rubber_banding: bool = false

const MAX_DIST_FROM_LEADER = 300.0
const CATCHUP_DIST = 80.0
const SPRINT_SPEED_MULT = 2.5

var pending_prisoners: Array[Node2D] = [] 
var escorted_prisoners: Array[Node2D] = []
var retreat_zone_cache: Node2D = null

func _ready() -> void:
	separation_force = 80.0 
	separation_radius = 25.0
	separation_enabled = true
	super._ready()

	if attack_ai:
		attack_ai.attack_started.connect(func(t): if not is_rubber_banding: brawl_target = t)
		attack_ai.attack_stopped.connect(func(): brawl_target = null)
		if attack_ai.detection_area:
			for c in attack_ai.detection_area.get_children():
				if c is CollisionShape2D and c.shape is CircleShape2D: c.shape.radius = 120.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(leader):
		velocity = Vector2.ZERO
		return
		
	var speed = data.move_speed
	var dist_leader = global_position.distance_to(leader.global_position)
	
	if not is_rubber_banding and dist_leader > MAX_DIST_FROM_LEADER:
		is_rubber_banding = true
		collision_mask = 1
		modulate.a = 0.5
	elif is_rubber_banding and dist_leader < CATCHUP_DIST:
		is_rubber_banding = false
		_setup_collision_logic()
		modulate.a = 1.0
		
	if is_rubber_banding:
		brawl_target = null
		speed *= SPRINT_SPEED_MULT
	
	var final_dest = formation_target
	var stop_dist = 5.0
	
	if is_instance_valid(brawl_target) and not is_rubber_banding:
		final_dest = brawl_target.global_position
		
		# --- RESTORED: Smart Stop Distance ---
		var range_limit = data.attack_range
		if brawl_target is BaseBuilding or (brawl_target.name == "Hitbox" and brawl_target.get_parent() is BaseBuilding):
			range_limit = data.building_attack_range
			
		var r_target = _get_radius(brawl_target)
		stop_dist = r_target + range_limit - 5.0
		if stop_dist < 5.0: stop_dist = 5.0
		
		if attack_ai: attack_ai.force_target(brawl_target)
		# -------------------------------------
	
	if final_dest != Vector2.ZERO:
		var dist = global_position.distance_to(final_dest)
		if dist > stop_dist:
			var dir = (final_dest - global_position).normalized()
			var push = Vector2.ZERO
			if separation_enabled and not is_rubber_banding: push = _calculate_separation_push(delta)
			velocity = (dir * speed) + push
			move_and_slide()
		else:
			velocity = Vector2.ZERO

func _get_radius(node: Node2D) -> float:
	if node.name == "Hitbox" and node.get_parent() is BaseBuilding:
		var b = node.get_parent()
		if b.data: return (min(b.data.grid_size.x, b.data.grid_size.y) * 32.0) / 2.0
	return 15.0

func assign_escort_task(prisoner: Node2D) -> void:
	if not prisoner: return
	
	if not retreat_zone_cache:
		retreat_zone_cache = get_tree().get_first_node_in_group("retreat_zone")
	
	# Add to queue
	if not prisoner in pending_prisoners and not prisoner in escorted_prisoners:
		pending_prisoners.append(prisoner)
	
	# Trigger FSM update if idle or already collecting
	if fsm:
		# If we were doing something else, start collecting
		if fsm.current_state != UnitAIConstants.State.COLLECTING and fsm.current_state != UnitAIConstants.State.ESCORTING:
			_set_next_collection_target()

func _set_next_collection_target() -> void:
	if pending_prisoners.size() > 0:
		var next = pending_prisoners[0]
		fsm.objective_target = next
		fsm.change_state(UnitAIConstants.State.COLLECTING)
		EventBus.floating_text_requested.emit("Got it!", global_position, Color.WHITE)
	else:
		# No more to collect? Go to boat.
		_switch_to_escorting()

# Called by UnitFSM
func process_collecting_logic(_delta: float) -> void:
	# Validation check
	if not is_instance_valid(fsm.objective_target):
		pending_prisoners.erase(fsm.objective_target)
		_set_next_collection_target()
		return

	var dist = global_position.distance_to(fsm.objective_target.global_position)
	if dist < 50.0:
		_collect_prisoner(fsm.objective_target)

func _collect_prisoner(prisoner: Node2D) -> void:
	# Move from Pending -> Escorted
	pending_prisoners.erase(prisoner)
	
	if not prisoner in escorted_prisoners:
		escorted_prisoners.append(prisoner)
		if prisoner.has_method("attach_to_escort"):
			prisoner.attach_to_escort(self)
	
	# [HOTFIX #1] Do we have more to pick up?
	if pending_prisoners.size() > 0:
		_set_next_collection_target() # Keep collecting
	else:
		_switch_to_escorting() # Done, go to boat

func _switch_to_escorting() -> void:
	if escorted_prisoners.is_empty():
		fsm.change_state(UnitAIConstants.State.REGROUPING)
		return
		
	fsm.objective_target = retreat_zone_cache
	fsm.change_state(UnitAIConstants.State.ESCORTING)

func process_escort_logic(_delta: float) -> void:
	# Passive logic - handled by FSM movement
	pass
	
func complete_escort() -> void:
	for p in escorted_prisoners:
		if is_instance_valid(p):
			p.queue_free() # In Phase 3 this becomes "Bank Loot"
	
	escorted_prisoners.clear()
	EventBus.floating_text_requested.emit("Prisoners Secured", global_position, Color.GREEN)
	fsm.change_state(UnitAIConstants.State.REGROUPING)

func process_regroup_logic(_delta: float) -> void:
	# [HOTFIX #3] Handle Dead Leader
	if is_instance_valid(leader):
		fsm.move_command_position = leader.global_position
		if global_position.distance_to(leader.global_position) < 100.0:
			fsm.change_state(UnitAIConstants.State.MOVING)
	else:
		# Fallback if leader died
		fsm.change_state(UnitAIConstants.State.IDLE)
