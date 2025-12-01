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
# --- NEW: Map Loader ---
var map_loader: RaidMapLoader

var objective_building: BaseBuilding = null

func _ready() -> void:
	print("[DIAGNOSTIC] RaidMission: _ready() called.")
	
	# Initialize Loader
	map_loader = RaidMapLoader.new()
	add_child(map_loader)
	
	# Check Context (Defensive vs Offensive)
	if DynastyManager.is_defensive_raid:
		self.is_defensive_mission = true
		objective_manager.is_defensive_mission = true
		DynastyManager.is_defensive_raid = false
		print("[DIAGNOSTIC] RaidMission: Mode set to DEFENSIVE.")
	else:
		print("[DIAGNOSTIC] RaidMission: Mode set to OFFENSIVE (Raid).")
	
	EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission)
	
	# Safe Initialization
	if not SettlementManager.has_current_settlement():
		print("[DIAGNOSTIC] RaidMission: No current settlement found. Loading test data.")
		_load_test_settlement()
		call_deferred("initialize_mission")
	else:
		call_deferred("initialize_mission")

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
	# Load Player Base
	var settlement = SettlementManager.current_settlement
	if settlement:
		objective_building = map_loader.load_base(settlement, true)
	
	_spawn_player_garrison()
	_spawn_enemy_wave()

func _setup_offensive_mode() -> void:
	# Load Enemy Base
	if not enemy_base_data:
		if ResourceLoader.exists(default_enemy_base_path):
			enemy_base_data = load(default_enemy_base_path)
		else:
			Loggie.msg("RaidMission: Default enemy base path not found: %s" % default_enemy_base_path).domain(LogDomains.RAID).error()
			return
	
	objective_building = map_loader.load_base(enemy_base_data, false)
	
	# Wire up destruction signals for pathfinding updates
	for child in building_container.get_children():
		if child is BaseBuilding:
			child.building_destroyed.connect(_on_building_destroyed_grid_update)
			
	_spawn_player_garrison()
	_spawn_retreat_zone()

func _on_building_destroyed_grid_update(building: BaseBuilding) -> void:
	if not building.data or not is_instance_valid(grid_manager): return
	# Grid updates handled by BaseBuilding/SettlementManager logic usually, but kept here for safety hook
	pass

# --- SPAWNING LOGIC ---

func _spawn_player_garrison() -> void:
	# 1. Get Data
	var warbands: Array[WarbandData] = []
	
	if SettlementManager.has_current_settlement():
		warbands = SettlementManager.current_settlement.warbands
	else:
		# Fallback for testing without a save file
		Loggie.msg("RaidMission: No settlement data found. Spawning test garrison.").domain("RAID").warn()
		# Create a dummy warband if needed, or just return
		return

	if warbands.is_empty():
	print("[DIAGNOSTIC] RaidMission: Spawning Player Garrison...")
	
	# 1. Determine Source of Troops
	var warbands_to_spawn: Array[WarbandData] = []
	var health_modifier: float = 1.0
	
	if is_defensive_mission:
		if SettlementManager.current_settlement:
			warbands_to_spawn = SettlementManager.current_settlement.warbands
		print("[DIAGNOSTIC] Mode Defensive. Warbands found in settlement: ", warbands_to_spawn.size())
	else:
		# OFFENSIVE MODE
		# Check DynastyManager Staging
		if not DynastyManager.outbound_raid_force.is_empty():
			warbands_to_spawn = DynastyManager.outbound_raid_force
			health_modifier = DynastyManager.raid_health_modifier
			print("[DIAGNOSTIC] Mode Offensive. Found staged force: ", warbands_to_spawn.size(), " warbands. HP Mod: ", health_modifier)
		else:
			# Fallback for testing scenes directly
			print("[DIAGNOSTIC] Mode Offensive. NO STAGED FORCE FOUND in DynastyManager.")
			if SettlementManager.current_settlement:
				print("[DIAGNOSTIC] Falling back to SettlementManager garrison.")
				warbands_to_spawn = SettlementManager.current_settlement.warbands
			else:
				print("[DIAGNOSTIC] No SettlementManager data found either. Trying test spawn.")
				_spawn_test_units()
				return

	# 2. Validation
	if warbands_to_spawn.is_empty():
		print("[DIAGNOSTIC] CRITICAL: warbands_to_spawn is EMPTY. Nothing to spawn.")
		Loggie.msg("RaidMission: No warbands to spawn! Mission may be unwinnable.").domain(LogDomains.RAID).warn()
		if not is_defensive_mission:
			objective_manager.call_deferred("_check_loss_condition")
		return
	
	# 2. Determine Spawn Point
	var spawn_origin = player_spawn_pos.global_position
	
	if is_defensive_mission and is_instance_valid(objective_building):
		spawn_origin = objective_building.global_position + Vector2(100, 100)
	elif not is_defensive_mission:
		# Offset slightly for landing look
		spawn_origin += landing_direction * 200.0
		
	# 3. Delegate to Spawner (This handles Squad Leaders vs Soldiers)
	if unit_spawner:
		unit_spawner.spawn_garrison(warbands, spawn_origin)
	else:
		Loggie.msg("CRITICAL: UnitSpawner missing in RaidMission!").domain("RAID").error()

func _spawn_enemy_wave() -> void:
	var spawner = get_node_or_null(enemy_spawn_position)
	if not spawner: 
		Loggie.msg("RaidMission: Enemy spawn position not found!").domain(LogDomains.RAID).error()
		return
		
	if enemy_wave_units.is_empty():
		Loggie.msg("RaidMission: No enemy units assigned in Inspector!").domain(LogDomains.RAID).warn()
		return
		
	for i in range(enemy_wave_count):
		var random_data = enemy_wave_units.pick_random()
		var scene_ref = random_data.load_scene()
		if not scene_ref: continue
		
		var unit = scene_ref.instantiate()
		unit.data = random_data 
		unit.collision_layer = 1 << 2 # Layer 3 (Enemy Units)
		unit.add_to_group("enemy_units")
		
		unit.global_position = spawner.global_position + Vector2(i * 40, 0)
		add_child(unit)
		
		if objective_building:
			unit.fsm_ready.connect(func(u): 
				if u.fsm: u.fsm.command_attack(objective_building)
			)

func _spawn_fyrd_response() -> void:
	pass

func _on_fyrd_arrived() -> void:
	var spawner = get_node_or_null(enemy_spawn_position)
	var origin = spawner.global_position if spawner else Vector2(1000,0)
	
	var enemy_data_path = "res://data/units/EnemyVikingRaider_Data.tres"
	if not ResourceLoader.exists(enemy_data_path):
		Loggie.msg("RaidMission: Fyrd unit data missing at %s" % enemy_data_path).domain(LogDomains.RAID).error()
		return
		
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
	if not ResourceLoader.exists(zone_script_path):
		Loggie.msg("RaidMission: RetreatZone script missing!").domain(LogDomains.RAID).error()
		return

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
	else:
		Loggie.msg("RaidMission: Test settlement data missing at %s" % data_path).domain(LogDomains.RAID).warn()

func _on_settlement_ready_for_mission(_d):
	if not is_instance_valid(objective_manager.rts_controller):
		initialize_mission()

func _validate_nodes() -> bool:
	if not rts_controller:
		print("[DIAGNOSTIC] Missing RTSController node.")
		return false
	if not objective_manager:
		print("[DIAGNOSTIC] Missing RaidObjectiveManager node.")
		return false
	if not grid_manager:
		print("[DIAGNOSTIC] Missing GridManager node.")
		return false
	return true

func _spawn_test_units() -> void:
	# Fallback only used if everything else fails
	print("[DIAGNOSTIC] Spawning Dummy Units (Fallback)")
	
	# Create a dummy unit on the fly if needed, or just load raider
	var unit_scene = load("res://scenes/units/PlayerVikingRaider.tscn")
	if not unit_scene:
		print("[DIAGNOSTIC] Even fallback scene is missing!")
		return
		
	for i in range(5):
		var u = unit_scene.instantiate()
		u.global_position = player_spawn_pos.global_position + Vector2(i*30, 0)
		add_child(u)
