class_name UnitSpawner
extends Node

# --- Configuration ---
@export_group("References")
@export var unit_container: Node2D
@export var rts_controller: RTSController

@export_group("Defaults")
@export var civilian_data: UnitData
@export var spawn_radius_min: float = 100.0
@export var spawn_radius_max: float = 250.0

# --- Constants ---
const LAYER_PLAYER = 2
const LAYER_ENEMY = 4
const SQUAD_SPACING = 150.0
const UNITS_PER_ROW = 5

func _ready() -> void:
	if not unit_container:
		unit_container = get_parent().get_node_or_null("UnitContainer")
	if not unit_container:
		Loggie.msg("UnitSpawner: CRITICAL - No UnitContainer found!").domain(LogDomains.SYSTEM).error()

func clear_units() -> void:
	if not unit_container: return
	for child in unit_container.get_children():
		child.queue_free()

# --- PUBLIC SPAWN API ---

func spawn_garrison(warbands: Array[WarbandData], spawn_origin: Vector2) -> void:
	Loggie.msg("UnitSpawner: Requesting deployment for %d Player Warbands." % warbands.size()).domain(LogDomains.RTS).info()

	if not _validate_spawn_setup(): return
	
	var current_index = 0
	
	for warband in warbands:
		if warband.is_wounded: 
			Loggie.msg("Skipping %s (Wounded)" % warband.custom_name).domain(LogDomains.RTS).debug()
			continue
			
		var ideal_pos = _calculate_formation_pos(spawn_origin, current_index)
		
		# Spawn the Squad Leader
		var unit_instance = _spawn_unit_core(warband, ideal_pos, true)
		if unit_instance:
			if rts_controller:
				rts_controller.add_unit_to_group(unit_instance)
			current_index += 1
		
	Loggie.msg("UnitSpawner: Deployment Complete. %d Squads active." % current_index).domain(LogDomains.RTS).info()

func spawn_enemy_garrison(warbands: Array[WarbandData], buildings: Array) -> void:
	Loggie.msg("UnitSpawner: Spawning %d Enemy Warbands." % warbands.size()).domain(LogDomains.RAID).info()
	
	if not _validate_spawn_setup(): return

	for i in range(warbands.size()):
		var warband = warbands[i]
		var guard_pos = Vector2.ZERO
		if not buildings.is_empty():
			var b = buildings[i % buildings.size()]
			if is_instance_valid(b):
				guard_pos = b.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		
		var unit_instance = _spawn_unit_core(warband, guard_pos, false)
		
		if unit_instance:
			unit_instance.fsm_ready.connect(_on_enemy_unit_ready.bind(guard_pos))

# --- CORE LOGIC ---

func _spawn_unit_core(warband: WarbandData, target_pos: Vector2, is_player: bool) -> BaseUnit:
	if not warband or not warband.unit_type: return null
	
	var unit_data = warband.unit_type
	var scene_ref = unit_data.load_scene()
	if not scene_ref:
		Loggie.msg("Failed to load scene for %s" % unit_data.display_name).domain(LogDomains.SYSTEM).error()
		return null
	
	# 1. Coordinate Safety Check
	var final_pos = target_pos
	if SettlementManager:
		final_pos = SettlementManager.request_valid_spawn_point(target_pos, 4)
		if final_pos == Vector2.INF:
			Loggie.msg("Spawn blocked at %s for %s" % [target_pos, unit_data.display_name]).domain(LogDomains.NAVIGATION).warn()
			return null
	
	# 2. Instantiate
	var unit = scene_ref.instantiate() as BaseUnit
	
	# 3. Inject Dependencies
	unit.warband_ref = warband
	unit.data = unit_data
	
	if is_player:
		unit.collision_layer = LAYER_PLAYER
		unit.add_to_group("player_units")
		
		# --- FIX: ALWAYS APPLY SQUAD LEADER SCRIPT ---
		# We don't check 'if not unit.get_script()'. We enforce the upgrade.
		var leader_script = load("res://scripts/units/SquadLeader.gd")
		if unit.get_script() != leader_script:
			unit.set_script(leader_script)
			# Note: set_script resets properties not marked @export or saved.
			# Re-inject dependencies just in case the script swap wiped them.
			unit.warband_ref = warband
			unit.data = unit_data
		# ---------------------------------------------
	else:
		unit.collision_layer = LAYER_ENEMY
		unit.add_to_group("enemy_units")
	
	# 4. Position & Parent
	unit.global_position = final_pos
	unit_container.add_child(unit)
	
	# 5. Global Event
	if is_player:
		EventBus.player_unit_spawned.emit(unit)
		
	return unit

# --- HELPER LOGIC ---

func _calculate_formation_pos(origin: Vector2, index: int) -> Vector2:
	var row = index / UNITS_PER_ROW
	var col = index % UNITS_PER_ROW
	var offset = Vector2(
		(col - (UNITS_PER_ROW / 2.0)) * SQUAD_SPACING,
		row * SQUAD_SPACING + 200.0
	)
	return origin + offset

func _validate_spawn_setup() -> bool:
	if not unit_container:
		Loggie.msg("Cannot spawn: UnitContainer missing.").domain(LogDomains.SYSTEM).error()
		return false
	return true

func _on_enemy_unit_ready(unit: BaseUnit, guard_pos: Vector2) -> void:
	if not is_instance_valid(unit): return
	if unit.fsm: unit.fsm.change_state(0) # IDLE
	if unit.attack_ai:
		unit.attack_ai.set_process(true)
		unit.attack_ai.set_physics_process(true)
		if unit.attack_ai.has_method("set_target_mask"):
			unit.attack_ai.set_target_mask(LAYER_PLAYER + 1) 
		if unit.attack_ai is DefenderAI:
			(unit.attack_ai as DefenderAI).configure_guard_post(guard_pos)

func sync_civilians(target_count: int, spawn_origin: Vector2, is_enemy: bool = false) -> void:
	var current_civs = []
	if unit_container:
		for child in unit_container.get_children():
			if child is CivilianUnit:
				current_civs.append(child)
	var diff = target_count - current_civs.size()
	if diff > 0:
		_spawn_civilians(diff, spawn_origin, is_enemy)
	elif diff < 0:
		_despawn_civilians(abs(diff), current_civs)


func _spawn_civilians(count: int, origin: Vector2, is_enemy: bool) -> void:
	if not civilian_data: 
		printerr("UnitSpawner: No civilian_data assigned!")
		return
		
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	
	print("[UnitSpawner] Spawning %d civilians around %s" % [count, origin])
	
	for i in range(count):
		var civ = scene_ref.instantiate()
		
		# 1. Set Groups/Layers
		if is_enemy:
			civ.collision_layer = LAYER_ENEMY
			civ.add_to_group("enemy_units")
			if civ.is_in_group("player_units"): civ.remove_from_group("player_units")
		else:
			civ.collision_layer = LAYER_PLAYER
			civ.add_to_group("player_units")
			
		# 2. Generate Random Position
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var tentative_pos = origin + (Vector2(cos(angle), sin(angle)) * distance)
		
		var final_pos = tentative_pos
		
		# 3. --- SAFETY CHECK ---
		if SettlementManager:
			# Debug: What is the random spot?
			var grid_check = SettlementManager.world_to_grid(tentative_pos)
			var is_water = SettlementManager.active_astar_grid.is_point_solid(grid_check)
			
			if is_water:
				# It landed in water. Request nearest land (Radius 5 tiles).
				var safe_pos = SettlementManager.request_valid_spawn_point(tentative_pos, 5)
				
				if safe_pos != Vector2.INF:
					final_pos = safe_pos
					# print("  > Civ %d rescued from Water. Moved to Beach." % i)
				else:
					# Deep water / No land found. Fallback to Origin (The Building).
					final_pos = origin 
					# print("  > Civ %d rescued from Deep Ocean. Moved to Origin." % i)
		# -----------------------
		
		civ.global_position = final_pos
		unit_container.add_child(civ)
		
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
	civ.collision_layer = LAYER_PLAYER
	civ.add_to_group("player_units")
	civ.add_to_group("civilians")
	if unit_container:
		unit_container.add_child(civ)
		EventBus.player_unit_spawned.emit(civ)
