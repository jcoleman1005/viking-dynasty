#res://scenes/missions/RaidMission.gd
# res://scenes/missions/RaidMission.gd
extends Node2D

# --- Configuration ---
@export var enemy_wave_units: Array[UnitData] = []
@export var enemy_wave_count: int = 5
@export var enemy_base_data: SettlementData
@export var default_enemy_base_path: String = "res://data/settlements/monastery_base.tres"
@export var player_spawn_formation: Dictionary = {"units_per_row": 5, "spacing": 40}
@export var is_defensive_mission: bool = false
@export var enemy_spawn_position: NodePath
@export var landing_direction: Vector2 = Vector2.RIGHT

# --- References ---
@onready var player_spawn_pos: Marker2D = $PlayerStartPosition
@onready var rts_controller: RTSController = $RTSController
@onready var building_container: Node2D = $BuildingContainer
@onready var objective_manager: RaidObjectiveManager = $RaidObjectiveManager
@onready var unit_spawner: UnitSpawner = $UnitSpawner
@onready var raid_nav_region: NavigationRegion2D = $RaidNavRegion
var extraction_zone: Area2D
@export var fyrd_unit_scene: PackedScene

@export_group("Fyrd")
@export var fyrd_spawn_count: int = 5

@export_group("Test Data")
@export var enemy_test_data: UnitData
@export var villager_test_data: UnitData
@export var suppress_auto_init: bool = false

# --- Internal ---
@onready var map_loader: RaidMapLoader = $RaidMapLoader
var objective_building: BaseBuilding = null
var unit_container: Node2D
var _mission_initialized: bool = false
@export var force_warbands: Array[WarbandData] = []
@export var force_enemy_settlement: SettlementData = null

func _enter_tree() -> void:
	_setup_unit_container()

func _initialize_navigation() -> void:
	# Isometric diamond bounds with padding
	var nav_poly = NavigationPolygon.new()
	var outline = PackedVector2Array([
		Vector2(0, -50),           # Top + padding
		Vector2(1970, 960),        # Right + padding
		Vector2(0, 1970),          # Bottom + padding
		Vector2(-1970, 960)        # Left + padding
	])
	nav_poly.add_outline(outline)
	raid_nav_region.navigation_polygon = nav_poly
	
	raid_nav_region.bake_navigation_polygon()
	await raid_nav_region.bake_finished
	
	# Poll until NavServer confirms geometry exists
	var map_rid = raid_nav_region.get_navigation_map()
	var attempts = 0
	var test_point = Vector2(0.0, 960.0) # Center of diamond
	while attempts < 30:
		var result = NavigationServer2D.map_get_closest_point(map_rid, test_point)
		if result != Vector2.ZERO:
			Loggie.msg("NavMesh ready after %d frames" % attempts).domain("NAVIGATION").info()
			break
		await get_tree().physics_frame
		attempts += 1
	
	if attempts >= 30:
		Loggie.msg("WARNING: NavMesh not ready after 30 frames").domain("NAVIGATION").warn()
		
	RaidNavigationManager.initialize_raid_map(raid_nav_region)

func _ready() -> void:
	Loggie.set_domain_enabled("UI", true)
	Loggie.set_domain_enabled("RTS", true)
	Loggie.set_domain_enabled("RAID", true)
	Loggie.set_domain_enabled("MAP", true)
	
	extraction_zone = get_node_or_null("ExtractionZone")
	if not extraction_zone:
		Loggie.msg("ExtractionZone not found in scene tree.").domain("RAID").warn()
	
	if unit_spawner:
		unit_spawner.unit_container = unit_container
		unit_spawner.rts_controller = rts_controller
	else:
		printerr("CRITICAL: UnitSpawner node is missing in RaidMission!")
	
	if RaidManager.is_defensive_raid:
		self.is_defensive_mission = true
		objective_manager.is_defensive_mission = true
		RaidManager.is_defensive_raid = false
	
	if suppress_auto_init:
		pass
	elif SettlementManager.has_current_settlement() or force_enemy_settlement:
		call_deferred("initialize_mission")
	else:
		EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission, CONNECT_ONE_SHOT)
		_load_test_settlement()
		
	get_tree().node_added.connect(_on_node_added)

func _setup_unit_container() -> void:
	if has_node("UnitContainer"):
		unit_container = get_node("UnitContainer")
	else:
		unit_container = Node2D.new()
		unit_container.name = "UnitContainer"
		add_child(unit_container)

func initialize_mission() -> void:
	if _mission_initialized:
		Loggie.msg("initialize_mission called twice — ignoring.").domain("RAID").warn()
		return
	_mission_initialized = true
	
	Loggie.msg("RaidMission: Initializing...").domain(LogDomains.RAID).info()
	
	# Load default test data if missing
	if not enemy_test_data:
		enemy_test_data = load("res://data/units/Test_EnemyDefender.tres")
	if not villager_test_data:
		villager_test_data = load("res://data/units/Test_Villager.tres")
	
	enemy_base_data = null
	
	# 0. PRIORITY 0: INJECTED DATA (Encapsulation)
	if force_enemy_settlement:
		enemy_base_data = force_enemy_settlement
		Loggie.msg("Using Injected SettlementData. Seed: %d" % enemy_base_data.map_seed).domain(LogDomains.RAID).info()

	# 1. PRIORITY 1: CAMPAIGN FLOW
	# We check if RaidManager has a target.
	elif RaidManager.current_raid_target:
		# [FIX] Unwrap the data! 
		# RaidManager.current_raid_target is usually 'RaidTargetData' (The Wrapper).
		# We need the 'SettlementData' inside it.
		var target_wrapper = RaidManager.current_raid_target
		if "settlement_data" in target_wrapper and target_wrapper.settlement_data:
			enemy_base_data = target_wrapper.settlement_data
			Loggie.msg("Loaded SettlementData from RaidManager. Seed: %d" % enemy_base_data.map_seed).domain(LogDomains.RAID).info()
		elif target_wrapper is SettlementData:
			# Handle case where Manager passed raw data
			enemy_base_data = target_wrapper
	
	# 2. PRIORITY 2: DEBUG FLOW (Fresh Generation)
	# If F6 (Scene Run), generate a new procedural base.
	elif enemy_base_data == null and OS.is_debug_build():
		Loggie.msg("Debug Mode: Generating fresh procedural base...").domain(LogDomains.RAID).info()
		enemy_base_data = MapDataGenerator._generate_procedural_settlement("Monastery", 1.0)
		# Ensure the generator gave us a seed!
		if enemy_base_data.map_seed == 0:
			enemy_base_data.map_seed = randi()
	
	# 3. SAFETY FALLBACK (Static File)
	# If all else fails, load the .tres file
	if not enemy_base_data:
		if default_enemy_base_path != "":
			Loggie.msg("Loading Default File: %s" % default_enemy_base_path).domain(LogDomains.RAID).warn()
			enemy_base_data = load(default_enemy_base_path) as SettlementData
	
	if not enemy_base_data:
		Loggie.msg("Critical: No enemy_base_data assigned!").domain(LogDomains.RAID).error()
		return

	Loggie.msg("Setup 1/6 — Data resolved. seed=%d warbands=%d peasants=%d" % [
		enemy_base_data.map_seed,
		enemy_base_data.warbands.size(),
		enemy_base_data.population_peasants]
	).domain("RAID").info()

	if not _validate_nodes(): return
	
	# 4. Register & Setup
	SettlementManager.register_active_scene_nodes(unit_container)
	
	# [DIAGNOSTIC] Final check before generation
	if enemy_base_data.map_seed == 0:
		Loggie.msg("WARNING: Map Seed is 0. RaidMapLoader will randomize terrain!").domain(LogDomains.RAID).warn()
		
	map_loader.setup(building_container, enemy_base_data) 
	
	Loggie.msg("Setup 2/6 — Map generated. buildings=%d has_extraction=%s" % [
		map_loader.last_map_data.get("buildings", []).size(),
		str(map_loader.last_map_data.has("extraction_zone"))]
	).domain("RAID").info()
	
	# Setup Extraction Zone
	if extraction_zone and map_loader.last_map_data.has("extraction_zone"):
		var rect = map_loader.last_map_data["extraction_zone"]
		extraction_zone.global_position = rect.position + rect.size / 2.0
		var shape = extraction_zone.get_node("ExtractionShape")
		if shape and shape.shape is RectangleShape2D:
			shape.shape.size = rect.size
		var visual = extraction_zone.get_node("ExtractionVisual")
		if visual is ColorRect:
			visual.size = rect.size
			visual.position = -rect.size / 2.0
	
	if objective_manager and extraction_zone:
		objective_manager.setup_extraction(extraction_zone)
	
	Loggie.msg("Tactical Navigation Initializing (Raid)...").domain(LogDomains.RAID).info()
	
	# Initialize Tactical Navigation
	await _initialize_navigation()
	
	Loggie.msg("Setup 4/6 — Navigation ready. is_raid_active=%s bounds=%s" % [
		str(RaidNavigationManager.is_raid_active),
		str(RaidNavigationManager.map_bounds)]
	).domain("RAID").info()
	
	if RaidNavigationManager.is_raid_active:
		_spawn_all_units()
	else:
		RaidNavigationManager.navigation_ready.connect(_spawn_all_units, CONNECT_ONE_SHOT)
	
	# 6. Finalize Objective
	if is_instance_valid(objective_building):
		if objective_manager:
			objective_manager.initialize(rts_controller, objective_building, unit_container)
			
			Loggie.msg("Setup 6/6 — Mission live.").domain("RAID").info()
			
			if not objective_manager.wave1_fyrd_arrived.is_connected(_on_wave1_fyrd):
				objective_manager.wave1_fyrd_arrived.connect(_on_wave1_fyrd)
			if not objective_manager.wave2_fyrd_arrived.is_connected(_on_wave2_fyrd):
				objective_manager.wave2_fyrd_arrived.connect(_on_wave2_fyrd)
			
			Loggie.msg("Fyrd wave signals connected to RaidMission").domain("RAID").info()
	else:
		Loggie.msg("Critical: No Objective Building found!").domain(LogDomains.RAID).error()

func _spawn_all_units() -> void:
	# Find objective building if not already set
	if not is_instance_valid(objective_building):
		for entry in map_loader.last_map_data.get("buildings", []):
			Loggie.msg("Checking: type='%s' node=%s" % [
				str(entry.get("type", "MISSING")),
				str(entry.get("node", null))]
			).domain("RAID").info()
			
			if entry.get("type", "") == "Hall" and entry.get("node", null) != null:
				objective_building = entry["node"]
				Loggie.msg("Objective building found: %s" % str(objective_building.name)).domain("RAID").info()
				break
	
	Loggie.msg("Setup 3/6 — Objective building: %s" % str(is_instance_valid(objective_building))).domain("RAID").info()
	
	Loggie.msg("Setup 5/6 — Spawning units. warbands=%d peasants=%d" % [
		enemy_base_data.warbands.size() if enemy_base_data else -1,
		enemy_base_data.population_peasants if enemy_base_data else -1]
	).domain("RAID").info()
	
	# 4. Spawn Civilians
	if enemy_base_data and enemy_base_data.population_peasants > 0:
		if unit_spawner:
			unit_spawner.unit_container = unit_container
			
			# Find a safe spot from procedural data or fallback
			var villager_spawns = map_loader.last_map_data.get("villager_spawns", [])
			var spawn_origin = Vector2(200, 300)
			if villager_spawns.size() > 0:
				spawn_origin = villager_spawns[0]
			elif is_instance_valid(objective_building):
				spawn_origin = objective_building.global_position + Vector2(0, 100)
			
			# Ensure it's valid
			spawn_origin = RaidNavigationManager.request_valid_spawn_point(spawn_origin, 5)
			
			unit_spawner.sync_civilians(enemy_base_data.population_peasants, spawn_origin, true)
			
			Loggie.msg("Civilians spawned around: %s" % str(spawn_origin)).domain("RAID").info()
			
	# 5. Spawn Units
	if is_defensive_mission:
		_setup_defensive_mode()
	else:
		_setup_offensive_mode()
		
	if enemy_base_data:
		Loggie.msg("Enemy warbands spawned: %d" % enemy_base_data.warbands.size()).domain("RAID").info()

func _setup_defensive_mode() -> void:
	var settlement = SettlementManager.current_settlement
	if settlement:
		objective_building = map_loader.load_base(settlement, true)
	_spawn_player_garrison()
	_spawn_enemy_wave()

func _setup_offensive_mode() -> void:
	for child in building_container.get_children():
		if child is BaseBuilding:
			if not child.building_destroyed.is_connected(_on_building_destroyed_grid_update):
				child.building_destroyed.connect(_on_building_destroyed_grid_update)
			
	_spawn_player_garrison()
	_spawn_retreat_zone()
	_spawn_enemy_garrison()
	
func _on_building_destroyed_grid_update(building: BaseBuilding) -> void:
	pass

func _spawn_player_garrison() -> void:
	var warbands_to_spawn: Array[WarbandData] = []
	
	if not force_warbands.is_empty():
		warbands_to_spawn = force_warbands
	elif is_defensive_mission:
		if SettlementManager.current_settlement:
			warbands_to_spawn = SettlementManager.current_settlement.warbands
	else:
		if not RaidManager.outbound_raid_force.is_empty():
			warbands_to_spawn = RaidManager.outbound_raid_force
		else:
			if SettlementManager.current_settlement:
				warbands_to_spawn = SettlementManager.current_settlement.warbands
			else:
				_spawn_test_units()
				return

	if warbands_to_spawn.is_empty():
		if not is_defensive_mission:
			objective_manager.call_deferred("_check_loss_condition")
		return
	
	var spawn_origin = player_spawn_pos.global_position
	
	if is_defensive_mission and is_instance_valid(objective_building):
		spawn_origin = objective_building.global_position + Vector2(100, 100)
	elif not is_defensive_mission:
		spawn_origin += landing_direction * 200.0
		
	# Safety Check for Player Spawn
	spawn_origin = NavigationManager.request_valid_spawn_point(spawn_origin, 4)
	
	if unit_spawner:
		unit_spawner.spawn_garrison(warbands_to_spawn, spawn_origin)

func _spawn_enemy_wave() -> void:
	var spawner = get_node_or_null(enemy_spawn_position)
	if not spawner: return
	if enemy_wave_units.is_empty(): return
	
	var origin = spawner.global_position
		
	for i in range(enemy_wave_count):
		var random_data = enemy_wave_units.pick_random()
		var scene_ref = random_data.load_scene()
		if not scene_ref: continue
		
		var unit = scene_ref.instantiate()
		unit.data = random_data 
		unit.collision_layer = 4 # Enemy Layer
		unit.add_to_group("enemy_units")
		
		# --- FIX: Safe Spawning ---
		var offset = Vector2(i * 40, 0) # Basic formation
		var target_pos = origin + offset
		
		# Validate against Grid
		unit.global_position = NavigationManager.request_valid_spawn_point(target_pos, 3)
		if unit.global_position == Vector2.INF:
			unit.global_position = target_pos # Fallback if grid is totally full
		# --------------------------
		
		unit_container.add_child(unit)
		
		if objective_building:
			unit.fsm_ready.connect(func(u): 
				if u.fsm: u.fsm.command_attack(objective_building)
			)

func _on_wave1_fyrd() -> void:
	var count = randi_range(8, 10)
	Loggie.msg("WAVE 1: Spawning %d Fyrd at boundary" % count).domain("RAID").warn()
	_spawn_fyrd_at_boundary(count)

func _on_wave2_fyrd() -> void:
	var count = randi_range(5, 8)
	Loggie.msg("WAVE 2: Spawning %d Fyrd targeting extraction" % count).domain("RAID").warn()
	_spawn_fyrd_at_boundary(count)

func _spawn_fyrd_at_boundary(count: int) -> void:
	if not fyrd_unit_scene:
		Loggie.msg("No fyrd_unit_scene assigned!").domain("RAID").error()
		return

	# Get boundary positions from map data
	var boundary_points = map_loader.last_map_data.get("fyrd_boundary", [])
	if boundary_points.is_empty():
		# Fallback: top edge of map
		for i in range(count):
			boundary_points.append(Vector2(randf_range(200, 3600), 50))

	Loggie.msg("FYRD BOUNDARY POINTS: %s" % str(boundary_points)).domain("RAID").warn()

	for i in range(count):
		var unit_inst = fyrd_unit_scene.instantiate()
		unit_inst.collision_layer = 4
		unit_inst.add_to_group("enemy_units")

		# Pick a boundary point, add some randomness
		var base_pos = boundary_points[i % boundary_points.size()]
		var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var spawn_pos = base_pos + offset

		# Validate against raid navmesh (NOT NavigationManager)
		var valid_pos = RaidNavigationManager.request_valid_spawn_point(spawn_pos, 4)
		if valid_pos != Vector2.INF:
			unit_inst.global_position = valid_pos
		else:
			unit_inst.global_position = spawn_pos

		Loggie.msg("FYRD SPAWN: pos=%s valid=%s boundary=%s" % [
			str(unit_inst.global_position), 
			str(valid_pos), 
			str(base_pos)]
		).domain("RAID").warn()

		if "skip_unaware" in unit_inst:
			unit_inst.skip_unaware = true

		unit_container.add_child(unit_inst)

		Loggie.msg("FYRD POST-SPAWN: name=%s skip_unaware=%s fsm=%s state=%s" % [
			unit_inst.name,
			str(unit_inst.skip_unaware),
			str(unit_inst.fsm),
			str(unit_inst.fsm.current_state if unit_inst.fsm else "NO FSM")]
		).domain("RAID").warn()

		# Wait for FSM to be fully ready before assigning target
		if is_instance_valid(objective_building):
			var _building = objective_building
			unit_inst.fsm_ready.connect(func(_u):
				if _u.has_method("set_attack_target") and is_instance_valid(_building):
					_u.set_attack_target(_building)
			, CONNECT_ONE_SHOT)

func _on_fyrd_arrived() -> void:
	Loggie.msg("--- FYRD SPAWN START ---").domain(LogDomains.RAID).info()
	
	if fyrd_unit_scene == null:
		var fallback = "res://scenes/units/EnemyUnit_Template.tscn" 
		if ResourceLoader.exists(fallback): fyrd_unit_scene = load(fallback)
	
	if fyrd_unit_scene == null: return

	var spawner = get_node_or_null(enemy_spawn_position)
	var origin = spawner.global_position if spawner else Vector2(1000, 0)
	
	for i in range(fyrd_spawn_count):
		var unit = fyrd_unit_scene.instantiate()
		
		# --- FIX: Randomized but Validated ---
		var random_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		var try_pos = origin + random_offset
		var valid_pos = NavigationManager.request_valid_spawn_point(try_pos, 3)
		
		if valid_pos != Vector2.INF:
			unit.global_position = valid_pos
		else:
			unit.global_position = try_pos
		# -------------------------------------
		
		unit.collision_layer = 4
		unit.add_to_group("enemy_units")
		unit_container.add_child(unit)
		
		if unit.has_method("get_fsm"):
			unit.call_deferred("command_attack_move", player_spawn_pos.global_position if player_spawn_pos else Vector2.ZERO)
		elif unit.get("fsm"):
			unit.fsm.command_attack_move(player_spawn_pos.global_position if player_spawn_pos else Vector2.ZERO)

func _spawn_retreat_zone() -> void:
	var zone_script_path = "res://scenes/missions/RetreatZone.gd"
	if not ResourceLoader.exists(zone_script_path): return
	var zone = Area2D.new()
	zone.set_script(load(zone_script_path))
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-100,-100), Vector2(100,-100), Vector2(100,100), Vector2(-100,100)])
	zone.add_child(poly)
	zone.global_position = player_spawn_pos.global_position
	zone.add_to_group("retreat_zone")
	add_child(zone)
	zone.unit_evacuated.connect(objective_manager.on_unit_evacuated)

func _load_test_settlement() -> void:
	var data_path = "res://data/settlements/home_base_fixed.tres"
	if ResourceLoader.exists(data_path):
		var data = load(data_path)
		if data: SettlementManager.load_settlement(data)

func _on_settlement_ready_for_mission(_d):
	initialize_mission()

func _validate_nodes() -> bool:
	if not rts_controller: return false
	if not objective_manager: return false
	return true

func _spawn_test_units() -> void:
	var unit_scene = load("res://scenes/units/PlayerVikingRaider.tscn")
	if not unit_scene: return
	for i in range(5):
		var u = unit_scene.instantiate()
		var offset = Vector2(i*30, 0)
		var pos = player_spawn_pos.global_position + offset
		
		# Safe Spawn
		var safe_pos = NavigationManager.request_valid_spawn_point(pos, 2)
		if safe_pos != Vector2.INF: u.global_position = safe_pos
		else: u.global_position = pos
		
		unit_container.add_child(u)

func _spawn_enemy_garrison() -> void:
	if not enemy_base_data: return
		
	# Fail-Safe Generation
	if enemy_base_data.warbands.is_empty():
		MapDataGenerator._scale_garrison(enemy_base_data, 1.0)
	
	if not unit_spawner: return
		
	var guard_buildings = []
	for child in building_container.get_children():
		if child is BaseBuilding:
			guard_buildings.append(child)
	
	# Leverages the already fixed UnitSpawner logic
	unit_spawner.spawn_enemy_garrison(enemy_base_data.warbands, guard_buildings)

func _on_node_added(node: Node) -> void:
	if node is CivilianUnit:
		if not node.surrender_requested.is_connected(_on_civilian_surrender):
			node.surrender_requested.connect(_on_civilian_surrender)

func _on_civilian_surrender(civilian: Node2D) -> void:
	var best_leader = null
	var min_dist = INF
	
	for leader in get_tree().get_nodes_in_group("squad_leaders"):
		var dist = leader.global_position.distance_to(civilian.global_position)
		if dist < min_dist:
			min_dist = dist
			best_leader = leader
			
	if best_leader:
		best_leader.request_escort_for(civilian)

func command_scramble(target_position: Vector2) -> void:
	# FIX: Delegate selection clearing to the RTS controller directly
	if rts_controller and rts_controller.has_method("clear_selection"):
		rts_controller.clear_selection()
	
	# FIX: "controllable_units" was not defined. Using the global group.
	var controllable_units = get_tree().get_nodes_in_group("player_units")
	
	Loggie.msg("Scramble command issued to %d units" % controllable_units.size()).domain(LogDomains.RAID).info()

	for unit in controllable_units:
		if not is_instance_valid(unit): continue
		
		# Panic logic: Pick a random spot near the target
		var panic_offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var unique_dest = target_position + panic_offset
		
		# Use FSM retreat if available, otherwise force move
		if unit.get("fsm") and unit.fsm.has_method("command_retreat"):
			unit.fsm.command_retreat(unique_dest)
		elif unit.has_method("command_move_to"):
			unit.command_move_to(unique_dest)

func _exit_tree() -> void:
	# CRITICAL: When this node leaves the scene tree (scene change/quit),
	# we MUST release the Singleton's grip on our nodes.
	# Even with WeakRefs, this prevents logical state errors.
	if SettlementManager.active_building_container == $BuildingContainer:
		SettlementManager.unregister_active_scene_nodes()
	
	RaidNavigationManager.cleanup_raid_map()
