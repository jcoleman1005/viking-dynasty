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

@export var floating_text_scene: PackedScene

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
		# Sync references to spawner for centralized spawning
		unit_spawner.building_container = building_container
		unit_spawner.map_loader = map_loader
		unit_spawner.objective_manager = objective_manager
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
	EventBus.floating_text_requested.connect(_on_floating_text_requested)

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
	
	# 1. Resolve Data & Dependencies
	if not enemy_test_data:
		enemy_test_data = load("res://data/units/Test_EnemyDefender.tres")
	if not villager_test_data:
		villager_test_data = load("res://data/units/Test_Villager.tres")
	
	# Sync civilian data to spawner
	if unit_spawner:
		unit_spawner.civilian_data = villager_test_data
	
	enemy_base_data = RaidDataResolver.resolve(force_enemy_settlement, default_enemy_base_path)
	
	if not enemy_base_data:
		Loggie.msg("Critical: No enemy_base_data assigned!").domain(LogDomains.RAID).error()
		return

	Loggie.msg("Setup 1/6 — Data resolved. seed=%d warbands=%d peasants=%d" % [
		enemy_base_data.map_seed,
		enemy_base_data.warbands.size(),
		enemy_base_data.population_peasants]
	).domain("RAID").info()

	if not _validate_nodes(): return
	
	# 2. Register Scene Nodes & Map Generation
	SettlementManager.register_active_scene_nodes(unit_container)
	
	if enemy_base_data.map_seed == 0:
		Loggie.msg("WARNING: Map Seed is 0. RaidMapLoader will randomize terrain!").domain(LogDomains.RAID).warn()
		
	map_loader.setup(building_container, enemy_base_data) 
	objective_manager._connect_to_building_signals()
	
	Loggie.msg("Setup 2/6 — Map generated. buildings=%d has_extraction=%s" % [
		map_loader.last_map_data.get("buildings", []).size(),
		str(map_loader.last_map_data.has("extraction_zone"))]
	).domain("RAID").info()
	
	# 3. Configure Map Features
	map_loader.configure_extraction_zone(extraction_zone)
	
	if objective_manager and extraction_zone:
		objective_manager.setup_extraction(extraction_zone)
	
	# 4. Initialize Navigation & Wait for Ready
	Loggie.msg("Tactical Navigation Initializing (Raid)...").domain(LogDomains.RAID).info()
	await _initialize_navigation()
	
	Loggie.msg("Setup 4/6 — Navigation ready. is_raid_active=%s bounds=%s" % [
		str(RaidNavigationManager.is_raid_active),
		str(RaidNavigationManager.map_bounds)]
	).domain("RAID").info()
	
	# 5. Execute Spawning
	if RaidNavigationManager.is_raid_active:
		_spawn_all_units()
	else:
		RaidNavigationManager.navigation_ready.connect(_spawn_all_units, CONNECT_ONE_SHOT)

func _finalize_objective_setup() -> void:
	if is_instance_valid(objective_building):
		if objective_manager:
			objective_manager.initialize(rts_controller, objective_building, building_container)
			
			Loggie.msg("Setup 6/6 — Mission live.").domain("RAID").info()
			
			if not objective_manager.wave1_fyrd_arrived.is_connected(_on_wave1_fyrd):
				objective_manager.wave1_fyrd_arrived.connect(_on_wave1_fyrd)
			if not objective_manager.wave2_fyrd_arrived.is_connected(_on_wave2_fyrd):
				objective_manager.wave2_fyrd_arrived.connect(_on_wave2_fyrd)
			
			Loggie.msg("Fyrd wave signals connected to RaidMission").domain("RAID").info()
	else:
		Loggie.msg("Critical: No Objective Building found!").domain(LogDomains.RAID).error()

func _spawn_all_units() -> void:
	objective_building = unit_spawner.spawn_for_mission(enemy_base_data, map_loader.last_map_data)
	_finalize_objective_setup()

func _on_wave1_fyrd() -> void:
	var count = randi_range(8, 10)
	Loggie.msg("WAVE 1: Spawning %d Fyrd at boundary" % count).domain("RAID").warn()
	_spawn_fyrd_at_boundary(count)

func _on_wave2_fyrd() -> void:
	var count = randi_range(5, 8)
	Loggie.msg("WAVE 2: Spawning %d Fyrd targeting extraction" % count).domain("RAID").warn()
	_spawn_fyrd_at_boundary(count, extraction_zone)

func _spawn_fyrd_at_boundary(count: int, target_override: Node = null) -> void:
	if not fyrd_unit_scene:
		Loggie.msg("No fyrd_unit_scene assigned!").domain("RAID").error()
		return
	var boundary_points = map_loader.last_map_data.get("fyrd_boundary", [])
	if boundary_points.is_empty():
		for i in range(count):
			boundary_points.append(Vector2(randf_range(200, 3600), 50))
	for i in range(count):
		var unit_inst = fyrd_unit_scene.instantiate()
		unit_inst.collision_layer = 4
		unit_inst.add_to_group("enemy_units")
		var base_pos = boundary_points[i % boundary_points.size()]
		var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var spawn_pos = base_pos + offset
		var valid_pos = RaidNavigationManager.request_valid_spawn_point(spawn_pos, 4)
		if valid_pos != Vector2.INF:
			unit_inst.global_position = valid_pos
		else:
			unit_inst.global_position = spawn_pos
		if "skip_unaware" in unit_inst:
			unit_inst.skip_unaware = true
		unit_container.add_child(unit_inst)
		var flash = ColorRect.new()
		flash.size = Vector2(32, 32)
		flash.color = Color(1.0, 0.6, 0.0, 0.8)
		flash.global_position = valid_pos - flash.size / 2
		unit_container.add_child(flash)
		var tween = create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.4)
		tween.finished.connect(flash.queue_free)
		var _building = objective_building
		unit_inst.fsm_ready.connect(func(_u):
			var target_node = target_override if (target_override != null and is_instance_valid(target_override)) else _building
			if target_node is Area2D:
				if _u.has_method("command_move_to"):
					_u.command_move_to(target_node.global_position)
			else:
				if _u.has_method("set_attack_target") and is_instance_valid(target_node):
					_u.set_attack_target(target_node)
		, CONNECT_ONE_SHOT)

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
	if rts_controller and rts_controller.has_method("clear_selection"):
		rts_controller.clear_selection()
	
	var controllable_units = get_tree().get_nodes_in_group("player_units")
	Loggie.msg("Scramble command issued to %d units" % controllable_units.size()).domain(LogDomains.RAID).info()

	for unit in controllable_units:
		if not is_instance_valid(unit): continue
		var panic_offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var unique_dest = target_position + panic_offset
		if unit.get("fsm") and unit.fsm.has_method("command_retreat"):
			unit.fsm.command_retreat(unique_dest)
		elif unit.has_method("command_move_to"):
			unit.command_move_to(unique_dest)

func _exit_tree() -> void:
	if SettlementManager.active_building_container == $BuildingContainer:
		SettlementManager.unregister_active_scene_nodes()
	RaidNavigationManager.cleanup_raid_map()

func _on_floating_text_requested(text, pos, color):
	var ft = floating_text_scene.instantiate()
	ft.global_position = pos
	ft.setup(text, color)
	unit_container.add_child(ft)
