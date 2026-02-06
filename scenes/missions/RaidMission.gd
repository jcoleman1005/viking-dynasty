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
@export var fyrd_unit_scene: PackedScene

# --- Internal ---
var map_loader: RaidMapLoader
var objective_building: BaseBuilding = null
var unit_container: Node2D

func _ready() -> void:
	Loggie.set_domain_enabled("UI", true)
	Loggie.set_domain_enabled("RTS", true)
	Loggie.set_domain_enabled("RAID", true)
	Loggie.set_domain_enabled("MAP", true)
	
	_setup_unit_container()
	
	if unit_spawner:
		unit_spawner.unit_container = unit_container
		unit_spawner.rts_controller = rts_controller
	else:
		printerr("CRITICAL: UnitSpawner node is missing in RaidMission!")
	
	map_loader = RaidMapLoader.new()
	add_child(map_loader)
	
	if RaidManager.is_defensive_raid:
		self.is_defensive_mission = true
		objective_manager.is_defensive_mission = true
		RaidManager.is_defensive_raid = false
	
	EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission)
	
	if not SettlementManager.has_current_settlement():
		_load_test_settlement()
		call_deferred("initialize_mission")
	else:
		call_deferred("initialize_mission")
		
	get_tree().node_added.connect(_on_node_added)

func _setup_unit_container() -> void:
	if has_node("UnitContainer"):
		unit_container = get_node("UnitContainer")
	else:
		unit_container = Node2D.new()
		unit_container.name = "UnitContainer"
		add_child(unit_container)

func initialize_mission() -> void:
	Loggie.msg("RaidMission: Initializing...").domain(LogDomains.RAID).info()
	
	enemy_base_data = null
	
	# 1. PRIORITY 1: CAMPAIGN FLOW
	# We check if RaidManager has a target.
	if RaidManager.current_raid_target:
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

	if not _validate_nodes(): return
	
	# 4. Register & Setup
	SettlementManager.register_active_scene_nodes(unit_container)
	
	if not map_loader:
		map_loader = RaidMapLoader.new()
		add_child(map_loader)
	
	# [DIAGNOSTIC] Final check before generation
	if enemy_base_data.map_seed == 0:
		Loggie.msg("WARNING: Map Seed is 0. RaidMapLoader will randomize terrain!").domain(LogDomains.RAID).warn()
		
	map_loader.setup(unit_container, enemy_base_data) 
	
	# 3. Generate Map Visuals and refresh manager
	objective_building = map_loader.load_base(enemy_base_data, false)
	Loggie.msg("Force Refreshing Grid (Raid)...").domain(LogDomains.RAID).info()
	SettlementManager._refresh_grid_state()
	
	# 4. Spawn Civilians
	if enemy_base_data and enemy_base_data.population_peasants > 0:
		if unit_spawner:
			unit_spawner.unit_container = unit_container
			
			# Find a safe spot near the main building, or default to offset
			var spawn_origin = Vector2(200, 300)
			if is_instance_valid(objective_building):
				spawn_origin = objective_building.global_position + Vector2(0, 100)
			
			# Ensure it's valid
			spawn_origin = SettlementManager.request_valid_spawn_point(spawn_origin, 5)
			
			unit_spawner.sync_civilians(enemy_base_data.population_peasants, spawn_origin, true)
			
	# 5. Spawn Units
	if is_defensive_mission:
		_setup_defensive_mode()
	else:
		_setup_offensive_mode()
	
	# 6. Finalize Objective
	if is_instance_valid(objective_building):
		if objective_manager:
			objective_manager.initialize(rts_controller, objective_building, unit_container)
			if not objective_manager.fyrd_arrived.is_connected(_on_fyrd_arrived):
				objective_manager.fyrd_arrived.connect(_on_fyrd_arrived)
	else:
		Loggie.msg("Critical: No Objective Building found!").domain(LogDomains.RAID).error()

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
		else: return
	
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
	spawn_origin = SettlementManager.request_valid_spawn_point(spawn_origin, 4)
	
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
		unit.global_position = SettlementManager.request_valid_spawn_point(target_pos, 3)
		if unit.global_position == Vector2.INF:
			unit.global_position = target_pos # Fallback if grid is totally full
		# --------------------------
		
		unit_container.add_child(unit)
		
		if objective_building:
			unit.fsm_ready.connect(func(u): 
				if u.fsm: u.fsm.command_attack(objective_building)
			)

func _on_fyrd_arrived() -> void:
	Loggie.msg("--- FYRD SPAWN START ---").domain(LogDomains.RAID).info()
	
	if fyrd_unit_scene == null:
		var fallback = "res://scenes/units/EnemyUnit_Template.tscn" 
		if ResourceLoader.exists(fallback): fyrd_unit_scene = load(fallback)
	
	if fyrd_unit_scene == null: return

	var spawner = get_node_or_null(enemy_spawn_position)
	var origin = spawner.global_position if spawner else Vector2(1000, 0)
	
	for i in range(5):
		var unit = fyrd_unit_scene.instantiate()
		
		# --- FIX: Randomized but Validated ---
		var random_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		var try_pos = origin + random_offset
		var valid_pos = SettlementManager.request_valid_spawn_point(try_pos, 3)
		
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
	if not is_instance_valid(objective_manager.rts_controller):
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
		var safe_pos = SettlementManager.request_valid_spawn_point(pos, 2)
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
