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
@onready var grid_manager: Node = $GridManager
@onready var building_container: Node2D = $BuildingContainer
@onready var objective_manager: RaidObjectiveManager = $RaidObjectiveManager
@onready var unit_spawner: UnitSpawner = $UnitSpawner

# --- Internal ---
var map_loader: RaidMapLoader
var objective_building: BaseBuilding = null
var unit_container: Node2D # Reference to the container we will create/find

func _ready() -> void:
	print("[DIAGNOSTIC] RaidMission: _ready() called.")
	Loggie.set_domain_enabled("UI", true)
	Loggie.set_domain_enabled("RTS", true)
	Loggie.set_domain_enabled("RAID", true)
	Loggie.set_domain_enabled("MAP", true)
	# 1. Setup Unit Container (CRITICAL FIX)
	_setup_unit_container()
	
	# 2. Inject Dependencies into Spawner
	if unit_spawner:
		unit_spawner.unit_container = unit_container
		unit_spawner.rts_controller = rts_controller
	else:
		printerr("CRITICAL: UnitSpawner node is missing in RaidMission!")
	
	# Initialize Loader
	map_loader = RaidMapLoader.new()
	add_child(map_loader)
	
	# Check Context
	if DynastyManager.is_defensive_raid:
		self.is_defensive_mission = true
		objective_manager.is_defensive_mission = true
		DynastyManager.is_defensive_raid = false
		print("[DIAGNOSTIC] RaidMission: Mode set to DEFENSIVE.")
	else:
		print("[DIAGNOSTIC] RaidMission: Mode set to OFFENSIVE (Raid).")
	
	EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission)
	
	if not SettlementManager.has_current_settlement():
		print("[DIAGNOSTIC] RaidMission: No current settlement found. Loading test data.")
		_load_test_settlement()
		call_deferred("initialize_mission")
	else:
		call_deferred("initialize_mission")
	Loggie.set_domain_enabled(LogDomains.RAID, true)

func _setup_unit_container() -> void:
	# Try to find existing container
	if has_node("UnitContainer"):
		unit_container = get_node("UnitContainer")
	else:
		# Create it dynamically if missing
		print("[DIAGNOSTIC] RaidMission: 'UnitContainer' missing. Creating dynamically.")
		unit_container = Node2D.new()
		unit_container.name = "UnitContainer"
		# Add it early in the tree (before spawner logic runs)
		add_child(unit_container)

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()
	if EventBus.is_connected("settlement_loaded", _on_settlement_ready_for_mission):
		EventBus.settlement_loaded.disconnect(_on_settlement_ready_for_mission)

func initialize_mission() -> void:
	print("[DIAGNOSTIC] RaidMission: Initializing...")
	
	if not _validate_nodes(): 
		print("[DIAGNOSTIC] RaidMission: Node validation FAILED.")
		return
	
	# 1. Setup Grid
	var local_astar_grid = grid_manager.astar_grid
	# Note: We pass unit_container here if needed, but mostly it uses building_container
	SettlementManager.register_active_scene_nodes(local_astar_grid, building_container)
	
	# 2. Configure Map Loader
	map_loader.setup(building_container, grid_manager)
	
	# 3. Generate Map
	if is_defensive_mission:
		_setup_defensive_mode()
	else:
		_setup_offensive_mode()
	
	# 4. Finalize Objective
	if is_instance_valid(objective_building):
		objective_manager.initialize(rts_controller, objective_building, building_container)
		if not objective_manager.fyrd_arrived.is_connected(_on_fyrd_arrived):
			objective_manager.fyrd_arrived.connect(_on_fyrd_arrived)
	else:
		Loggie.msg("RaidMission: Critical - No Objective Building found!").domain(LogDomains.RAID).error()

func _setup_defensive_mode() -> void:
	var settlement = SettlementManager.current_settlement
	if settlement:
		objective_building = map_loader.load_base(settlement, true)
	
	_spawn_player_garrison()
	_spawn_enemy_wave()

func _setup_offensive_mode() -> void:
	if not enemy_base_data:
		if ResourceLoader.exists(default_enemy_base_path):
			enemy_base_data = load(default_enemy_base_path)
		else:
			Loggie.msg("RaidMission: Default enemy base path not found: %s" % default_enemy_base_path).domain(LogDomains.RAID).error()
			return
	
	objective_building = map_loader.load_base(enemy_base_data, false)
	
	for child in building_container.get_children():
		if child is BaseBuilding:
			child.building_destroyed.connect(_on_building_destroyed_grid_update)
			
	_spawn_player_garrison()
	_spawn_retreat_zone()
	_spawn_enemy_garrison()
	
func _on_building_destroyed_grid_update(building: BaseBuilding) -> void:
	pass

func _spawn_player_garrison() -> void:
	var warbands_to_spawn: Array[WarbandData] = []
	
	if is_defensive_mission:
		if SettlementManager.current_settlement:
			warbands_to_spawn = SettlementManager.current_settlement.warbands
	else:
		if not DynastyManager.outbound_raid_force.is_empty():
			warbands_to_spawn = DynastyManager.outbound_raid_force
		else:
			if SettlementManager.current_settlement:
				warbands_to_spawn = SettlementManager.current_settlement.warbands
			else:
				_spawn_test_units()
				return

	if warbands_to_spawn.is_empty():
		Loggie.msg("RaidMission: No warbands to spawn!").domain(LogDomains.RAID).warn()
		if not is_defensive_mission:
			objective_manager.call_deferred("_check_loss_condition")
		return
	
	var spawn_origin = player_spawn_pos.global_position
	
	if is_defensive_mission and is_instance_valid(objective_building):
		spawn_origin = objective_building.global_position + Vector2(100, 100)
	elif not is_defensive_mission:
		spawn_origin += landing_direction * 200.0
		
	if unit_spawner:
		unit_spawner.spawn_garrison(warbands_to_spawn, spawn_origin)
	else:
		Loggie.msg("CRITICAL: UnitSpawner missing in RaidMission!").domain("RAID").error()

func _spawn_enemy_wave() -> void:
	var spawner = get_node_or_null(enemy_spawn_position)
	if not spawner: return
		
	if enemy_wave_units.is_empty(): return
		
	for i in range(enemy_wave_count):
		var random_data = enemy_wave_units.pick_random()
		var scene_ref = random_data.load_scene()
		if not scene_ref: continue
		
		var unit = scene_ref.instantiate()
		unit.data = random_data 
		unit.collision_layer = 1 << 2 
		unit.add_to_group("enemy_units")
		
		unit.global_position = spawner.global_position + Vector2(i * 40, 0)
		add_child(unit)
		
		if objective_building:
			unit.fsm_ready.connect(func(u): 
				if u.fsm: u.fsm.command_attack(objective_building)
			)

func _on_fyrd_arrived() -> void:
	var spawner = get_node_or_null(enemy_spawn_position)
	var origin = spawner.global_position if spawner else Vector2(1000,0)
	var enemy_data_path = "res://data/units/EnemyVikingRaider_Data.tres"
	if not ResourceLoader.exists(enemy_data_path): return
	var enemy_data = load(enemy_data_path)
	
	for i in range(20):
		var unit = enemy_data.scene_to_spawn.instantiate()
		unit.data = enemy_data
		unit.current_health = 100
		unit.collision_layer = 1 << 2
		unit.global_position = origin + Vector2(randf_range(-200,200), randf_range(-200,200))
		add_child(unit)
		unit.fsm_ready.connect(func(u): 
			if u.fsm: u.fsm.command_move_to(player_spawn_pos.global_position)
		)

func _spawn_retreat_zone() -> void:
	var zone_script_path = "res://scenes/missions/RetreatZone.gd"
	if not ResourceLoader.exists(zone_script_path): return
	var zone = Area2D.new()
	zone.set_script(load(zone_script_path))
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-100,-100), Vector2(100,-100), Vector2(100,100), Vector2(-100,100)])
	zone.add_child(poly)
	zone.global_position = player_spawn_pos.global_position
	add_child(zone)
	zone.unit_evacuated.connect(objective_manager.on_unit_evacuated)

func _load_test_settlement() -> void:
	var data_path = "res://data/settlements/home_base_fixed.tres"
	if ResourceLoader.exists(data_path):
		var data = load(data_path)
		if data: SettlementManager.load_settlement(data)

func _on_settlement_ready_for_mission(_d):
	if not is_instance_valid(objective_manager.rts_controller):
		initialize_mission()

func _validate_nodes() -> bool:
	if not rts_controller: return false
	if not objective_manager: return false
	if not grid_manager: return false
	return true

func _spawn_test_units() -> void:
	var unit_scene = load("res://scenes/units/PlayerVikingRaider.tscn")
	if not unit_scene: return
	for i in range(5):
		var u = unit_scene.instantiate()
		u.global_position = player_spawn_pos.global_position + Vector2(i*30, 0)
		# Ensure test units are added to the container too
		unit_container.add_child(u)

func _spawn_enemy_garrison() -> void:
	print("DEBUG: _spawn_enemy_garrison called.")
	
	if not enemy_base_data:
		print("DEBUG: FAILURE - enemy_base_data is NULL!")
		return
		
	# --- FAIL-SAFE: Inject Defenders if Missing ---
	if enemy_base_data.warbands.is_empty():
		print("DEBUG: Data is empty (Stale File). Generating emergency garrison...")
		
		# Call the generator to fill the array in memory
		# We assume Tier 1 difficulty (1.0)
		MapDataGenerator._scale_garrison(enemy_base_data, 1.0)
		
		# Check if it worked
		if enemy_base_data.warbands.is_empty():
			print("DEBUG: CRITICAL - Emergency generation failed. Check MapDataGenerator script.")
			return
		else:
			print("DEBUG: Emergency generation successful. Created %d warbands." % enemy_base_data.warbands.size())
	# ----------------------------------------------
	
	if not unit_spawner:
		print("DEBUG: FAILURE - unit_spawner node is NULL!")
		return
		
	# 1. Collect Valid Guard Posts
	var guard_buildings = []
	for child in building_container.get_children():
		if child is BaseBuilding:
			guard_buildings.append(child)
	
	print("DEBUG: Found %d guard buildings." % guard_buildings.size())
			
	# 2. Call Spawner
	unit_spawner.spawn_enemy_garrison(enemy_base_data.warbands, guard_buildings)
