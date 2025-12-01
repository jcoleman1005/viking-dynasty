# res://scripts/units/SquadLeader.gd
class_name SquadLeader
extends BaseUnit

# --- Internal State ---
var squad_soldiers: Array[SquadSoldier] = []
var formation: SquadFormation
var last_facing_direction: Vector2 = Vector2.DOWN # Default to facing down

# Debug
var debug_formation_points: Array[Vector2] = []

func _ready() -> void:
	# 1. Base Init
	super._ready()
	add_to_group("squad_leaders")
	
	# 2. Setup Formation Manager
	formation = SquadFormation.new()
	# Spacing: 65px (Soldier width 50px + 15px gap)
	formation.unit_spacing = 65.0 
	formation.formation_type = SquadFormation.FormationType.BOX
	
	# 3. Spawn the Boys
	call_deferred("_initialize_squad")

func _initialize_squad() -> void:
	if not warband_ref or not data: return
	
	if squad_soldiers.is_empty():
		_recruit_fresh_squad()
	
	_refresh_formation_registry()

func _recruit_fresh_squad() -> void:
	var soldiers_needed = max(0, warband_ref.current_manpower - 1)
	if soldiers_needed == 0: return
	
	var base_scene = data.scene_to_spawn
	if not base_scene: return
	
	for i in range(soldiers_needed):
		var soldier_instance = base_scene.instantiate()
		
		# Swap Script
		var soldier_script = load("res://scripts/units/SquadSoldier.gd")
		soldier_instance.set_script(soldier_script)
		
		# Configure
		soldier_instance.data = data
		soldier_instance.warband_ref = warband_ref
		soldier_instance.leader = self
		# Spawn at leader pos to avoid "flying in"
		soldier_instance.position = position 
		
		get_parent().add_child(soldier_instance)
		squad_soldiers.append(soldier_instance)

	_refresh_formation_registry()
	
	# Snap to initial positions
	_update_formation_targets(true)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# --- FIX: Update Facing only when moving ---
	if velocity.length_squared() > 10.0:
		last_facing_direction = velocity.normalized()
	# -------------------------------------------
	
	_update_formation_targets()
	queue_redraw() # Update debug graphics

func _update_formation_targets(snap_to_position: bool = false) -> void:
	if squad_soldiers.is_empty(): return
	
	# Use the persistent facing direction instead of current velocity
	# This prevents the formation from snapping to DOWN when stopping
	var slots = formation._calculate_formation_positions(global_position, last_facing_direction)
	
	# Store for Debug Drawing
	debug_formation_points = slots
	
	# Assign points 1..N to Soldiers 0..N (Slot 0 is Leader)
	for i in range(min(squad_soldiers.size(), slots.size() - 1)):
		var soldier = squad_soldiers[i]
		if is_instance_valid(soldier):
			var target = slots[i+1]
			soldier.formation_target = target
			
			if snap_to_position:
				soldier.global_position = target
				soldier.velocity = Vector2.ZERO

# --- DEBUG VISUALIZATION ---
func _draw() -> void:
	# Only draw if selected to reduce clutter
	if is_selected:
		for i in range(debug_formation_points.size()):
			var point = to_local(debug_formation_points[i])
			if i == 0:
				# Leader Slot (Green)
				draw_circle(point, 5.0, Color.GREEN)
			else:
				# Soldier Slot (Cyan)
				draw_circle(point, 3.0, Color.CYAN)
				# Draw line to it
				draw_line(Vector2.ZERO, point, Color(0, 1, 1, 0.2), 1.0)

# --- STANDARD LOGIC ---

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
		new_leader_host.queue_free()
	else:
		if warband_ref:
			EventBus.player_unit_died.emit(self)
	
	super.die()
