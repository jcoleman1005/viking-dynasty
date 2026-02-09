#res://scripts/units/SquadLeader.gd
class_name SquadLeader
extends BaseUnit

# --- Squad Management ---
var squad_soldiers: Array[SquadSoldier] = []
## Helper class that handles the geometry math (Line, Wedge, Circle)
var formation: SquadFormation

# --- Gameplay State ---
var attached_thralls: Array[Node2D] = [] # Typed as Node2D for flexibility, legacy used ThrallUnit

# --- Formation State ---
var last_facing_direction: Vector2 = Vector2.DOWN
var debug_formation_points: Array[Vector2] = []

# --- OPTIMIZATION FLAGS ---
# Track the last state where we calculated positions to avoid per-frame math.
var _last_update_pos: Vector2 = Vector2.INF
var _last_update_facing: Vector2 = Vector2.ZERO

const UPDATE_DIST_THRESHOLD_SQ: float = 100.0 # ~10 pixels
const UPDATE_ANGLE_THRESHOLD: float = 0.05    # ~2.8 degrees

func _ready() -> void:
	super._ready()
	
	# Legacy Group Registration
	add_to_group("squad_leaders")
	add_to_group("player_units")
	avoidance_priority = 10 # Leaders push harder than soldiers

	# Initialize Formation Helper
	formation = SquadFormation.new()
	# Default formation settings (can be exposed as exports later)
	formation.unit_spacing = 65.0 
	formation.formation_type = SquadFormation.FormationType.BOX
	
	_refresh_formation_registry()
	
	# Deferred squad initialization to ensure WarbandRef is ready
	call_deferred("_initialize_squad")
	
	Loggie.msg("SquadLeader initialized").domain("GAMEPLAY").info()

func _initialize_squad() -> void:
	if not warband_ref or not data: return
	
	if squad_soldiers.is_empty():
		_recruit_fresh_squad()
	
	_refresh_formation_registry()

func _recruit_fresh_squad() -> void:
	var soldiers_needed = max(0, warband_ref.current_manpower - 1)
	if soldiers_needed == 0: return
	
	var base_scene = data.load_scene()
	if not base_scene: 
		base_scene = data.scene_to_spawn
	
	if not base_scene: 
		printerr("SquadLeader: Could not load scene for soldier spawn!")
		return
	
	Loggie.msg("Recruiting fresh squad: %d soldiers" % soldiers_needed).domain("GAMEPLAY").info()
	
	for i in range(soldiers_needed):
		var soldier_instance = base_scene.instantiate()
		
		# Critical: Inject the SquadSoldier logic
		var soldier_script = load("res://scripts/units/SquadSoldier.gd")
		soldier_instance.set_script(soldier_script)
		
		soldier_instance.data = data
		soldier_instance.warband_ref = warband_ref
		soldier_instance.leader = self
		soldier_instance.position = position 
		
		get_parent().add_child(soldier_instance)
		squad_soldiers.append(soldier_instance)

	_refresh_formation_registry()
	# Force an immediate update so they don't start at (0,0) targets
	force_formation_update()
	# Snap them to position initially so they don't slide in from world origin
	_update_formation_targets(true)

func _physics_process(delta: float) -> void:
	# 1. Base Physics (Movement, Inertia, Avoidance)
	super._physics_process(delta)

	# 2. Stabilized Rotation Logic
	var is_voluntarily_moving = false
	if fsm:
		is_voluntarily_moving = fsm.current_state == UnitAIConstants.State.MOVING or \
		fsm.current_state == UnitAIConstants.State.FORMATION_MOVING

	if is_voluntarily_moving and velocity.length_squared() > 50.0:
		last_facing_direction = velocity.normalized()

	# 3. OPTIMIZATION: Conditional Update
	if _should_update_formation():
		_update_formation_targets()
	
	queue_redraw()

## Check if spatial changes justify a recalculation
func _should_update_formation() -> bool:
	if global_position.distance_squared_to(_last_update_pos) > UPDATE_DIST_THRESHOLD_SQ:
		return true
	if last_facing_direction.dot(_last_update_facing) < (1.0 - UPDATE_ANGLE_THRESHOLD):
		return true
	return false

func _update_formation_targets(snap_to_position: bool = false) -> void:
	if squad_soldiers.is_empty(): return
	
	# Update Cache
	_last_update_pos = global_position
	_last_update_facing = last_facing_direction

	var slots = formation._calculate_formation_positions(global_position, last_facing_direction)
	debug_formation_points = slots

	for i in range(min(squad_soldiers.size(), slots.size() - 1)):
		var soldier = squad_soldiers[i]
		if is_instance_valid(soldier):
			var target = slots[i+1]
			soldier.formation_target = target
			if snap_to_position:
				soldier.global_position = target
				soldier.velocity = Vector2.ZERO

func force_formation_update() -> void:
	_update_formation_targets(false)

func _refresh_formation_registry() -> void:
	if not formation: return
	formation.units.clear()
	formation.add_unit(self)
	for s in squad_soldiers:
		formation.add_unit(s)
	# Force update ensures formation object has correct unit count
	if _should_update_formation() or squad_soldiers.size() > 0:
		force_formation_update()

# --- Gameplay Logic (Restored) ---

func on_state_changed(new_state: int) -> void:
	super.on_state_changed(new_state)
	
	# Command & Control: Propagate state to squad
	if new_state == UnitAIConstants.State.ATTACKING:
		_order_squad_attack()
	elif new_state == UnitAIConstants.State.IDLE or new_state == UnitAIConstants.State.MOVING:
		_order_squad_regroup()

func _order_squad_attack() -> void:
	if not fsm or not is_instance_valid(fsm.current_target): 
		return
	
	var target = fsm.current_target
	
	for soldier in squad_soldiers:
		if is_instance_valid(soldier):
			if soldier.attack_ai:
				soldier.attack_ai.force_target(target)

func _order_squad_regroup() -> void:
	for soldier in squad_soldiers:
		if is_instance_valid(soldier) and soldier.attack_ai:
			soldier.attack_ai.stop_attacking()

func die() -> void:
	# 1. Handle Dynasty Consequences
	if warband_ref and warband_ref.assigned_heir_name != "":
		DynastyManager.kill_heir_by_name(warband_ref.assigned_heir_name, "Killed in battle")
		warband_ref.assigned_heir_name = "" 
	
	# 2. Find a Successor
	var living_soldiers: Array[SquadSoldier] = []
	for s in squad_soldiers:
		if is_instance_valid(s) and s.current_health > 0:
			living_soldiers.append(s)
			
	if not living_soldiers.is_empty():
		# Promote the first living soldier
		var new_leader_host = living_soldiers.pop_front()
		
		# --- FIX: Clean Instantiation instead of Duplicate ---
		var base_scene = data.load_scene()
		if not base_scene: base_scene = data.scene_to_spawn
		
		var new_leader = base_scene.instantiate()
		
		# Inject Leader Brain
		new_leader.set_script(load("res://scripts/units/SquadLeader.gd"))
		
		# Transfer State
		new_leader.position = new_leader_host.position
		new_leader.current_health = new_leader_host.current_health
		new_leader.warband_ref = warband_ref
		new_leader.data = data
		
		get_parent().add_child(new_leader)
		
		# Transfer remaining soldiers to new leader
		new_leader.absorb_existing_soldiers(living_soldiers)
		
		EventBus.player_unit_spawned.emit(new_leader)
		EventBus.floating_text_requested.emit("Promotion!", new_leader.global_position, Color.GOLD)
		
		new_leader_host.queue_free()
	else:
		# Squad Wiped Out
		if warband_ref:
			EventBus.player_unit_died.emit(self)
	
	super.die()

func absorb_existing_soldiers(list: Array[SquadSoldier]) -> void:
	squad_soldiers = list
	for s in squad_soldiers:
		s.leader = self
		# Re-inject correct script if needed, or assume they are already soldiers
	_refresh_formation_registry()

func remove_soldier(soldier: SquadSoldier) -> void:
	if soldier in squad_soldiers:
		squad_soldiers.erase(soldier)
		_refresh_formation_registry()

# --- Prisoner / Escort Logic (Restored) ---

func request_escort_for(civilian: Node2D) -> void:
	var best_candidate: SquadSoldier = null
	var max_batch_dist = 300.0
	var max_prisoners = 3
	
	# Priority 1: Find someone already collecting who isn't full
	for soldier in squad_soldiers:
		if not is_instance_valid(soldier) or not soldier.is_inside_tree(): continue
		
		if soldier.fsm.current_state in [UnitAIConstants.State.COLLECTING, UnitAIConstants.State.ESCORTING]:
			var total_load = soldier.escorted_prisoners.size() + soldier.pending_prisoners.size()
			if total_load < max_prisoners:
				var dist = soldier.global_position.distance_to(civilian.global_position)
				if dist < max_batch_dist:
					best_candidate = soldier
					break 
	
	# Priority 2: Pull an available combatant
	if not best_candidate:
		var closest_combatant = null
		var closest_d = INF
		
		for soldier in squad_soldiers:
			if not is_instance_valid(soldier): continue
			
			var state = soldier.fsm.current_state
			if state in [UnitAIConstants.State.IDLE, UnitAIConstants.State.ATTACKING, UnitAIConstants.State.MOVING, UnitAIConstants.State.FORMATION_MOVING]:
				var dist = soldier.global_position.distance_to(civilian.global_position)
				if dist < closest_d:
					closest_d = dist
					closest_combatant = soldier
		
		best_candidate = closest_combatant

	if best_candidate:
		best_candidate.assign_escort_task(civilian)

func attach_thrall(thrall: Node2D) -> void:
	if not thrall in attached_thralls:
		attached_thralls.append(thrall)
		if "assigned_leader" in thrall:
			thrall.assigned_leader = self
		
		# Assign a random offset "behind" the leader
		var angle = randf_range(PI/4, 3*PI/4) # Behind (90 to 270 degrees roughly)
		var dist = randf_range(40.0, 80.0)
		if "follow_offset" in thrall:
			thrall.follow_offset = Vector2(cos(angle), sin(angle)) * dist
		
		EventBus.floating_text_requested.emit("Thrall Captured!", thrall.global_position, Color.CYAN)

func _draw() -> void:
	if not debug_formation_points.is_empty() and OS.is_debug_build():
		for i in range(debug_formation_points.size()):
			var p = to_local(debug_formation_points[i])
			if i == 0:
				draw_circle(p, 5.0, Color.GREEN)
			else:
				draw_circle(p, 3.0, Color(0, 1, 0, 0.3))
