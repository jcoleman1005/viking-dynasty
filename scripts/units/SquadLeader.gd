# res://scripts/units/SquadLeader.gd
class_name SquadLeader
extends BaseUnit

# --- Internal State ---
var squad_soldiers: Array[SquadSoldier] = []
var formation: SquadFormation
var last_facing_direction: Vector2 = Vector2.DOWN
var attached_thralls: Array[ThrallUnit] = []
# Debug
var debug_formation_points: Array[Vector2] = []

func _ready() -> void:
	super._ready()
	add_to_group("squad_leaders")
	add_to_group("player_units")
	
	formation = SquadFormation.new()
	formation.unit_spacing = 65.0 
	formation.formation_type = SquadFormation.FormationType.BOX
	
	call_deferred("_initialize_squad")

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
	
	for i in range(soldiers_needed):
		var soldier_instance = base_scene.instantiate()
		
		var soldier_script = load("res://scripts/units/SquadSoldier.gd")
		soldier_instance.set_script(soldier_script)
		
		soldier_instance.data = data
		soldier_instance.warband_ref = warband_ref
		soldier_instance.leader = self
		soldier_instance.position = position 
		
		get_parent().add_child(soldier_instance)
		squad_soldiers.append(soldier_instance)

	_refresh_formation_registry()
	_update_formation_targets(true)

func attach_thrall(thrall: ThrallUnit) -> void:
	if not thrall in attached_thralls:
		attached_thralls.append(thrall)
		thrall.assigned_leader = self
		# Assign a random offset "behind" the leader (assuming Down is default, we adjust dynamically)
		# For simplicity, we assign a random circle offset around the "rear" area
		var angle = randf_range(PI/4, 3*PI/4) # Behind (90 to 270 degrees roughly)
		var dist = randf_range(40.0, 80.0)
		thrall.follow_offset = Vector2(cos(angle), sin(angle)) * dist
		
		# Log it or Juice it
		EventBus.floating_text_requested.emit("Thrall Captured!", thrall.global_position, Color.CYAN)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if velocity.length_squared() > 10.0:
		last_facing_direction = velocity.normalized()
	_update_formation_targets()
	queue_redraw()

func _update_formation_targets(snap_to_position: bool = false) -> void:
	if squad_soldiers.is_empty(): return
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

func _draw() -> void:
	if is_selected:
		for i in range(debug_formation_points.size()):
			var point = to_local(debug_formation_points[i])
			if i == 0:
				draw_circle(point, 5.0, Color.GREEN)
			else:
				draw_circle(point, 3.0, Color.CYAN)
				draw_line(Vector2.ZERO, point, Color(0, 1, 1, 0.2), 1.0)

func remove_soldier(soldier: SquadSoldier) -> void:
	if soldier in squad_soldiers:
		squad_soldiers.erase(soldier)
		_refresh_formation_registry()

func absorb_existing_soldiers(list: Array[SquadSoldier]) -> void:
	squad_soldiers = list
	for s in squad_soldiers:
		s.leader = self
	_refresh_formation_registry()

func _refresh_formation_registry() -> void:
	formation.units.clear()
	formation.add_unit(self)
	for s in squad_soldiers:
		formation.add_unit(s)

func set_selected(val: bool) -> void:
	super.set_selected(val)
	for s in squad_soldiers:
		if is_instance_valid(s):
			s.set_selected(val)

func die() -> void:
	if warband_ref and warband_ref.assigned_heir_name != "":
		DynastyManager.kill_heir_by_name(warband_ref.assigned_heir_name, "Killed in battle")
		warband_ref.assigned_heir_name = "" 
	
	var living_soldiers: Array[SquadSoldier] = []
	for s in squad_soldiers:
		if is_instance_valid(s) and s.current_health > 0:
			living_soldiers.append(s)
			
	if not living_soldiers.is_empty():
		var new_leader_host = living_soldiers.pop_front()
		
		var new_leader = duplicate()
		new_leader.set_script(load("res://scripts/units/SquadLeader.gd"))
		new_leader.position = new_leader_host.position
		new_leader.current_health = new_leader_host.current_health
		new_leader.warband_ref = warband_ref
		
		get_parent().add_child(new_leader)
		new_leader.absorb_existing_soldiers(living_soldiers)
		
		# --- FIX: Notify RTS Controller of Promotion ---
		EventBus.player_unit_spawned.emit(new_leader)
		# -----------------------------------------------
		
		new_leader_host.queue_free()
	else:
		if warband_ref:
			EventBus.player_unit_died.emit(self)
	
	super.die()

func on_state_changed(new_state: int) -> void:
	super.on_state_changed(new_state)
	
	if new_state == UnitAIConstants.State.ATTACKING:
		print("DEBUG LEADER: I am attacking! Ordering %d soldiers to charge." % squad_soldiers.size())
		_order_squad_attack()
	elif new_state == UnitAIConstants.State.IDLE or new_state == UnitAIConstants.State.MOVING:
		_order_squad_regroup()

func _order_squad_attack() -> void:
	if not fsm or not is_instance_valid(fsm.current_target): 
		print("DEBUG LEADER: Cannot order attack - No target in FSM.")
		return
	
	var target = fsm.current_target
	print("DEBUG LEADER: Ordering charge against %s" % target.name)
	
	for soldier in squad_soldiers:
		if is_instance_valid(soldier):
			if soldier.attack_ai:
				soldier.attack_ai.force_target(target)
			else:
				push_error("DEBUG LEADER: Soldier %s has no AttackAI!" % soldier.name)

func _order_squad_regroup() -> void:
	for soldier in squad_soldiers:
		if is_instance_valid(soldier) and soldier.attack_ai:
			# Clear the forced target so they return to formation
			soldier.attack_ai.stop_attacking()
