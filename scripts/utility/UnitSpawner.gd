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
		EventBus.player_unit_spawned.emit(leader)
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

func sync_civilians(target_count: int, spawn_origin: Vector2, is_enemy: bool = false) -> void:
	# Calculate how many we have vs how many we need
	# We filter children to find existing civilians
	var current_civs = []
	if unit_container:
		for child in unit_container.get_children():
			if child is CivilianUnit:
				current_civs.append(child)
	
	var current_count = current_civs.size()
	var diff = target_count - current_count
	
	if diff > 0:
		_spawn_civilians(diff, spawn_origin, is_enemy)
	elif diff < 0:
		_despawn_civilians(abs(diff), current_civs)

func _spawn_civilians(count: int, origin: Vector2, is_enemy: bool) -> void:
	if not civilian_data: return
	
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	
	for i in range(count):
		var civ = scene_ref.instantiate()
		
		# Team Identity
		if is_enemy:
			civ.collision_layer = 4 
			civ.add_to_group("enemy_units")
			if civ.is_in_group("player_units"):
				civ.remove_from_group("player_units")
		else:
			civ.collision_layer = 2
			civ.add_to_group("player_units")
			
		# Position
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var pos = origin + offset
		civ.global_position = pos
		
		if unit_container:
			unit_container.add_child(civ)
			
		# [FIX] Announce to RTS Controller
		if not is_enemy:
			EventBus.player_unit_spawned.emit(civ)

func _despawn_civilians(count: int, list: Array) -> void:
	for i in range(count):
		if i < list.size():
			var civ = list[i]
			if is_instance_valid(civ):
				if rts_controller: rts_controller.remove_unit(civ)
				civ.queue_free()

func spawn_worker_at(location: Vector2) -> void:
	if not civilian_data: return
	
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	
	var civ = scene_ref.instantiate()
	civ.global_position = location
	
	# Set properties for "Home" mode
	civ.collision_layer = 2 # Player layer
	civ.add_to_group("player_units")
	civ.add_to_group("civilians") # Important for the "Available" check
	
	if unit_container:
		unit_container.add_child(civ)
		EventBus.player_unit_spawned.emit(civ)

func spawn_enemy_garrison(warbands: Array[WarbandData], buildings: Array) -> void:
	print("DEBUG: Spawner received %d warbands to spawn." % warbands.size())
	
	for i in range(warbands.size()):
		var wb = warbands[i]
		if not wb or not wb.unit_type: continue
			
		var u_data = wb.unit_type
		var scene = u_data.load_scene()
		if not scene: continue
		
		var unit = scene.instantiate() as BaseUnit
		unit.data = u_data
		unit.add_to_group("enemy_units")
		unit.collision_layer = 4 # Enemy Layer
		
		# Pick Guard Post
		var guard_pos = Vector2.ZERO
		if not buildings.is_empty():
			var b_index = i % buildings.size()
			var b = buildings[b_index]
			if is_instance_valid(b):
				guard_pos = b.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		
		unit.global_position = _clamp_to_grid(guard_pos)
		
		# --- FIX: Wait for Unit to Initialize ---
		# We connect to fsm_ready, which BaseUnit emits after creating the AI
		unit.fsm_ready.connect(_on_enemy_unit_ready.bind(guard_pos))
		# ----------------------------------------
		
		unit_container.add_child(unit)

	Loggie.msg("Spawned %d enemy defenders." % warbands.size()).domain("RAID").info()

# --- NEW: Callback to Configure AI ---
func _on_enemy_unit_ready(unit: BaseUnit, guard_pos: Vector2) -> void:
	# Now we know attack_ai exists!
	
	if unit.fsm:
		unit.fsm.change_state(0) # IDLE
		
	if unit.attack_ai:
		unit.attack_ai.set_process(true)
		unit.attack_ai.set_physics_process(true)
		
		# Set Vision (Layer 1 + 2)
		if unit.attack_ai.has_method("set_target_mask"):
			unit.attack_ai.set_target_mask(3) 
			
		# Set Guard Post
		if unit.attack_ai is DefenderAI:
			(unit.attack_ai as DefenderAI).configure_guard_post(guard_pos)
			
	# print("DEBUG: Enemy %s fully configured at %s" % [unit.name, guard_pos])
