# res://scripts/utility/UnitSpawner.gd
class_name UnitSpawner
extends Node

@export var unit_container: Node2D
@export var rts_controller: RTSController
@export var civilian_data: UnitData

@export var spawn_radius_min: float = 100.0
@export var spawn_radius_max: float = 250.0

func _ready() -> void:
	if not unit_container:
		unit_container = get_parent().get_node_or_null("UnitContainer")
		if not unit_container:
			Loggie.msg("UnitSpawner: CRITICAL - No UnitContainer found!").domain(LogDomains.SYSTEM).error()

func clear_units() -> void:
	if not unit_container: return
	for child in unit_container.get_children():
		child.queue_free()

func spawn_garrison(warbands: Array[WarbandData], spawn_origin: Vector2) -> void:
	print("[DIAGNOSTIC] UnitSpawner: Received request for %d warbands." % warbands.size())

	if not unit_container: 
		print("[DIAGNOSTIC] FAIL: UnitContainer is null!")
		return
	
	var current_squad_index = 0
	var units_per_row = 5
	var squad_spacing = 150.0
	
	for warband in warbands:
		if warband.is_wounded: 
			print("[DIAGNOSTIC] Skipping %s: Wounded" % warband.custom_name)
			continue
			
		var unit_data = warband.unit_type
		if not unit_data: 
			print("[DIAGNOSTIC] Skipping %s: Missing UnitData" % warband.custom_name)
			continue
		
		var scene_ref = unit_data.load_scene()
		if not scene_ref: 
			print("[DIAGNOSTIC] Skipping %s: Scene load failed" % warband.custom_name)
			continue
		
		var leader = scene_ref.instantiate()
		var leader_script = load("res://scripts/units/SquadLeader.gd")
		leader.set_script(leader_script)
		
		leader.warband_ref = warband
		leader.data = unit_data
		leader.collision_layer = 2 
		
		# --- POSITIONING & CLAMPING ---
		var row = current_squad_index / units_per_row
		var col = current_squad_index % units_per_row
		
		var formation_offset = Vector2(
			(col - (units_per_row / 2.0)) * squad_spacing,
			row * squad_spacing + 200.0
		)
		
		var final_pos = spawn_origin + formation_offset
		
		# Apply Safety Clamp
		final_pos = _clamp_to_grid(final_pos)
		leader.global_position = final_pos
		# ------------------------------
		
		unit_container.add_child(leader)
		print("[DIAGNOSTIC] Spawning %s at %s" % [leader.name, leader.global_position])
		
		if rts_controller:
			rts_controller.add_unit_to_group(leader)
			
		current_squad_index += 1
		
	Loggie.msg("UnitSpawner: Deployed %d squads." % current_squad_index).domain(LogDomains.RTS).info()

# --- NEW HELPER: Grid Clamping ---
func _clamp_to_grid(target_pos: Vector2) -> Vector2:
	# We check if SettlementManager has an active grid.
	# If not, we return the raw position (fallback).
	if not SettlementManager or not is_instance_valid(SettlementManager.active_astar_grid):
		return target_pos
		
	var grid = SettlementManager.active_astar_grid
	var region = grid.region
	var cell_size = grid.cell_size
	
	# Calculate World Bounds (Pixels)
	var min_x = region.position.x * cell_size.x
	var min_y = region.position.y * cell_size.y
	var max_x = region.end.x * cell_size.x
	var max_y = region.end.y * cell_size.y
	
	# Apply Margin (keep units 1 cell away from the absolute edge)
	var margin = 32.0 
	
	var clamped = Vector2(
		clampf(target_pos.x, min_x + margin, max_x - margin),
		clampf(target_pos.y, min_y + margin, max_y - margin)
	)
	
	if clamped != target_pos:
		# Log specific adjustments so you know if your level design is tight
		# print("[DIAGNOSTIC] Clamped unit from %s to %s" % [target_pos, clamped])
		pass
		
	return clamped

# ... (Keep sync_civilians, _spawn_civilians, _despawn_civilians unchanged) ...

func sync_civilians(idle_count: int, spawn_origin: Vector2) -> void:
	if not unit_container or not civilian_data: return
	var active_idle_civilians = []
	for child in unit_container.get_children():
		if child.is_in_group("civilians") and not child.is_in_group("busy"):
			active_idle_civilians.append(child)
	var current_count = active_idle_civilians.size()
	var diff = idle_count - current_count
	if diff > 0:
		_spawn_civilians(diff, spawn_origin)
	elif diff < 0:
		_despawn_civilians(abs(diff), active_idle_civilians)

func _spawn_civilians(count: int, origin: Vector2) -> void:
	if not civilian_data: return
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	for i in range(count):
		var civ = scene_ref.instantiate()
		if not civ.get_script() or civ.get_script().resource_path != "res://scripts/units/CivilianUnit.gd":
			civ.set_script(load("res://scripts/units/CivilianUnit.gd"))
		civ.data = civilian_data
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		
		# --- FIX: Clamp Civilians too ---
		var pos = origin + offset
		civ.position = _clamp_to_grid(pos)
		# --------------------------------
		
		unit_container.add_child(civ)
		if rts_controller: rts_controller.add_unit_to_group(civ)
		if civ.has_method("command_move_to"):
			var wander = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			# Clamp wander target
			civ.command_move_to(_clamp_to_grid(civ.position + wander))

func _despawn_civilians(count: int, list: Array) -> void:
	for i in range(count):
		if i < list.size():
			var civ = list[i]
			if is_instance_valid(civ):
				if rts_controller: rts_controller.remove_unit(civ)
				civ.queue_free()

func spawn_worker_at(location: Vector2) -> void:
	if not civilian_data: return
	_spawn_civilians(1, location)
	Loggie.msg("UnitSpawner: Worker spawned at %s" % location).domain(LogDomains.UNIT).debug()
