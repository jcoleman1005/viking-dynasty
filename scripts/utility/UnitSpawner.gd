#res://scripts/utility/UnitSpawner.gd
class_name UnitSpawner
extends Node

# --- Configuration ---
@export_group("References")
@export var unit_container: Node2D
@export var rts_controller: RTSController

@export_group("Mission References")
@export var building_container: Node2D
@export var map_loader: RaidMapLoader
@export var objective_manager: RaidObjectiveManager

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

# --- MISSION SPAWN API ---

## High-level entry point for setting up all units in a Raid Mission. Returns the resolved objective building.
func spawn_for_mission(enemy_data: SettlementData, map_data: Dictionary) -> BaseBuilding:
	if not _validate_spawn_setup(): return null
	
	# 1. Resolve Objective Building (needed for fallback spawn points)
	var obj_building: BaseBuilding = null
	var buildings_list = map_data.get("buildings", [])
	for entry in buildings_list:
		if entry.get("type", "") == "Hall" and entry.get("node", null) != null:
			obj_building = entry["node"]
			break
	
	Loggie.msg("Setup 3/6 — Objective building resolved: %s" % str(is_instance_valid(obj_building))).domain("RAID").info()
	
	Loggie.msg("Setup 5/6 — Spawning units. warbands=%d peasants=%d" % [
		enemy_data.warbands.size() if enemy_data else -1,
		enemy_data.population_peasants if enemy_data else -1]
	).domain("RAID").info()

	# 2. Spawn Civilians
	if enemy_data and enemy_data.population_peasants > 0:
		# Resolve Origin: map_data -> objective -> fallback
		var villager_spawns = map_data.get("villager_spawns", [])
		var spawn_origin = Vector2(200, 300)
		if villager_spawns.size() > 0:
			spawn_origin = villager_spawns[0]
		elif is_instance_valid(obj_building):
			spawn_origin = obj_building.global_position + Vector2(0, 100)
		
		# Validate against RaidNavigationManager
		var valid_origin = RaidNavigationManager.request_valid_spawn_point(spawn_origin, 5)
		
		sync_civilians(enemy_data.population_peasants, valid_origin, true)
		Loggie.msg("Civilians spawned around: %s" % str(valid_origin)).domain("RAID").info()

	# 3. Mission-Specific Spawning (Player & Enemy Force)
	var mission = get_parent()
	var is_defensive = mission.get("is_defensive_mission") if mission else false
	
	if is_defensive:
		_setup_defensive_mode(mission, obj_building)
	else:
		_setup_offensive_mode(mission, buildings_list, enemy_data, obj_building)

	if enemy_data:
		Loggie.msg("Enemy warbands spawned: %d" % enemy_data.warbands.size()).domain("RAID").info()
		
	return obj_building

func _setup_defensive_mode(mission: Node, obj_building: BaseBuilding) -> void:
	var settlement = SettlementManager.current_settlement
	if settlement and map_loader:
		# This updates the objective_building if load_base finds the hub
		var hub = map_loader.load_base(settlement, true)
		if hub: 
			obj_building = hub
			if "objective_building" in mission:
				mission.objective_building = hub
			
	_spawn_player_garrison(mission, obj_building)
	_spawn_enemy_wave(mission, obj_building)

func _setup_offensive_mode(mission: Node, buildings_data: Array, enemy_data: SettlementData, obj_building: BaseBuilding) -> void:
	_spawn_player_garrison(mission)
	_spawn_retreat_zone(mission)
	
	# Spawn Enemy Garrison
	if enemy_data:
		# Fail-Safe Generation
		if enemy_data.warbands.is_empty():
			MapDataGenerator._scale_garrison(enemy_data, 1.0)
			
		var guard_buildings = []
		for entry in buildings_data:
			if entry.get("node") is BaseBuilding:
				guard_buildings.append(entry["node"])
		
		spawn_enemy_garrison(enemy_data.warbands, guard_buildings)

func _spawn_player_garrison(mission: Node, obj_building: BaseBuilding = null) -> void:
	var warbands_to_spawn: Array[WarbandData] = []
	var force_warbands = mission.get("force_warbands") if mission else []
	var is_defensive = mission.get("is_defensive_mission") if mission else false
	var player_spawn_pos = mission.get("player_spawn_pos") if mission else null
	var landing_direction = mission.get("landing_direction") if mission else Vector2.RIGHT
	
	if force_warbands and not force_warbands.is_empty():
		warbands_to_spawn = force_warbands
	elif is_defensive:
		if SettlementManager.current_settlement:
			warbands_to_spawn = SettlementManager.current_settlement.warbands
	else:
		if not RaidManager.outbound_raid_force.is_empty():
			warbands_to_spawn = RaidManager.outbound_raid_force
		else:
			if SettlementManager.current_settlement:
				warbands_to_spawn = SettlementManager.current_settlement.warbands
			else:
				_spawn_test_units(player_spawn_pos)
				return

	if warbands_to_spawn.is_empty():
		if not is_defensive and objective_manager:
			objective_manager.call_deferred("_check_loss_condition")
		return
	
	var spawn_origin = player_spawn_pos.global_position if player_spawn_pos else Vector2.ZERO
	
	if is_defensive and is_instance_valid(obj_building):
		spawn_origin = obj_building.global_position + Vector2(100, 100)
	elif not is_defensive:
		spawn_origin += landing_direction * 200.0
		
	# Safety Check for Player Spawn
	spawn_origin = NavigationManager.request_valid_spawn_point(spawn_origin, 4)
	
	spawn_garrison(warbands_to_spawn, spawn_origin)

func _spawn_enemy_wave(mission: Node, obj_building: BaseBuilding) -> void:
	var enemy_spawn_path = mission.get("enemy_spawn_position") if mission else null
	var enemy_wave_units = mission.get("enemy_wave_units") if mission else []
	var enemy_wave_count = mission.get("enemy_wave_count") if mission else 0
	
	if not enemy_spawn_path: return
	var spawner = mission.get_node_or_null(enemy_spawn_path)
	if not spawner: return
	if enemy_wave_units.is_empty(): return
	
	var origin = spawner.global_position
		
	for i in range(enemy_wave_count):
		var random_data = enemy_wave_units.pick_random()
		var scene_ref = random_data.load_scene()
		if not scene_ref: continue
		
		var unit = scene_ref.instantiate()
		unit.data = random_data 
		unit.collision_layer = LAYER_ENEMY
		unit.add_to_group("enemy_units")
		
		var offset = Vector2(i * 40, 0)
		var target_pos = origin + offset
		
		unit.global_position = NavigationManager.request_valid_spawn_point(target_pos, 3)
		if unit.global_position == Vector2.INF:
			unit.global_position = target_pos
		
		unit_container.add_child(unit)
		
		if obj_building:
			unit.fsm_ready.connect(func(u): 
				if u.fsm: u.fsm.command_attack(obj_building)
			)

func _spawn_retreat_zone(mission: Node) -> void:
	var zone_script_path = "res://scenes/missions/RetreatZone.gd"
	if not ResourceLoader.exists(zone_script_path): return
	var player_spawn_pos = mission.get("player_spawn_pos") if mission else null
	if not player_spawn_pos: return
	
	var zone = Area2D.new()
	zone.set_script(load(zone_script_path))
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-100,-100), Vector2(100,-100), Vector2(100,100), Vector2(-100,100)
	])
	zone.add_child(poly)
	zone.global_position = player_spawn_pos.global_position
	zone.add_to_group("retreat_zone")
	mission.add_child(zone)
	
	if objective_manager:
		zone.unit_evacuated.connect(objective_manager.on_unit_evacuated)

func _spawn_test_units(player_spawn_pos: Marker2D) -> void:
	var unit_scene = load("res://scenes/units/Bondi.tscn")
	if not unit_scene or not player_spawn_pos: return
	for i in range(5):
		var u = unit_scene.instantiate()
		var offset = Vector2(i*30, 0)
		var pos = player_spawn_pos.global_position + offset
		
		var safe_pos = NavigationManager.request_valid_spawn_point(pos, 2)
		if safe_pos != Vector2.INF: u.global_position = safe_pos
		else: u.global_position = pos
		
		unit_container.add_child(u)

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
	
	var final_pos = target_pos
	
	if RaidNavigationManager.is_raid_active:
		final_pos = RaidNavigationManager.request_valid_spawn_point(target_pos, 4)
	elif NavigationManager:
		final_pos = NavigationManager.request_valid_spawn_point(target_pos, 4)
		
	if final_pos == Vector2.INF:
		Loggie.msg("Spawn blocked at %s for %s" % [target_pos, unit_data.display_name]).domain(LogDomains.NAVIGATION).warn()
		return null
	
	var unit = scene_ref.instantiate() as BaseUnit
	unit.warband_ref = warband
	unit.data = unit_data
	
	if is_player:
		unit.collision_layer = LAYER_PLAYER
		unit.add_to_group("player_units")
	else:
		unit.collision_layer = LAYER_ENEMY
		unit.add_to_group("enemy_units")
	
	unit.global_position = final_pos
	unit_container.add_child(unit)
	
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
		Loggie.msg("UnitSpawner: No civilian_data assigned!").domain("RAID").error()
		return
		
	var scene_ref = civilian_data.load_scene()
	if not scene_ref: return
	
	Loggie.msg("[UnitSpawner] Spawning %d civilians around %s" % [count, origin]).domain("RAID").info()
	
	for i in range(count):
		var civ = scene_ref.instantiate()
		
		if is_enemy:
			civ.collision_layer = LAYER_ENEMY
			civ.add_to_group("enemy_units")
			if civ.is_in_group("player_units"): civ.remove_from_group("player_units")
		else:
			civ.collision_layer = LAYER_PLAYER
			civ.add_to_group("player_units")
			
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var tentative_pos = origin + (Vector2(cos(angle), sin(angle)) * distance)
		
		var final_pos = tentative_pos
		
		if RaidNavigationManager.is_raid_active:
			var closest = RaidNavigationManager.request_valid_spawn_point(tentative_pos, 5)
			if closest != Vector2.INF:
				final_pos = closest
			else:
				final_pos = origin
		elif NavigationManager:
			var grid_check = NavigationManager._world_to_grid(tentative_pos)
			var is_water = NavigationManager.is_point_solid(grid_check)
			
			if is_water:
				var safe_pos = NavigationManager.request_valid_spawn_point(tentative_pos, 5)
				if safe_pos != Vector2.INF:
					final_pos = safe_pos
				else:
					final_pos = origin 
		
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
