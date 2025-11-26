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

# --- NEW: Map Loader ---
var map_loader: RaidMapLoader
# -----------------------

var objective_building: BaseBuilding = null

func _ready() -> void:
	# Initialize Loader
	map_loader = RaidMapLoader.new()
	add_child(map_loader)
	
	if DynastyManager.is_defensive_raid:
		self.is_defensive_mission = true
		objective_manager.is_defensive_mission = true
		DynastyManager.is_defensive_raid = false
	
	EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission)
	
	if not SettlementManager.has_current_settlement():
		_load_test_settlement()
		call_deferred("initialize_mission")
	else:
		call_deferred("initialize_mission")

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()
	if EventBus.is_connected("settlement_loaded", _on_settlement_ready_for_mission):
		EventBus.settlement_loaded.disconnect(_on_settlement_ready_for_mission)

func initialize_mission() -> void:
	if not _validate_nodes(): return
	
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
		Loggie.msg("RaidMission: Critical - No Objective Building found!").domain("RAID").error()

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
		enemy_base_data = load(default_enemy_base_path)
	
	objective_building = map_loader.load_base(enemy_base_data, false)
	
	# Wire up destruction signals for pathfinding updates
	for child in building_container.get_children():
		if child is BaseBuilding:
			child.building_destroyed.connect(_on_building_destroyed_grid_update)
			
	_spawn_player_garrison()
	_spawn_retreat_zone()

func _on_building_destroyed_grid_update(building: BaseBuilding) -> void:
	# Simple grid clearing logic when stuff blows up
	if not building.data or not is_instance_valid(grid_manager): return
	var grid_pos = Vector2i(building.global_position / grid_manager.cell_size) # Approx center
	# (For robust clearing, re-use the logic from previous RaidMission script or move it to Loader)
	# For now, we can just let the building die.
	pass

# --- SPAWNING LOGIC (Kept here as it is Game Rule logic, not Map Gen) ---

func _spawn_player_garrison() -> void:
	if not SettlementManager.current_settlement:
		_spawn_test_units() 
		return
	
	var warbands = SettlementManager.current_settlement.warbands
	if warbands.is_empty():
		if not is_defensive_mission:
			objective_manager.call_deferred("_check_loss_condition")
		return
	
	var units_per_row = player_spawn_formation.get("units_per_row", 5)
	var spacing = player_spawn_formation.get("spacing", 40.0)
	var current_squad_index = 0
	
	for warband in warbands:
		if warband.is_wounded: continue
		if warband.loyalty < 100:
			warband.modify_loyalty(50)
			warband.turns_idle = 0
		
		var unit_data = warband.unit_type
		if not unit_data: continue
		
		for i in range(warband.current_manpower):
			var unit = unit_data.scene_to_spawn.instantiate()
			unit.warband_ref = warband
			unit.data = unit_data
			unit.collision_layer = 2
			
			# Naming
			if i == 0: unit.name = warband.custom_name + "_Thegn"
			elif i == 1: unit.name = warband.custom_name + "_Banner"
			else: unit.name = warband.custom_name + "_Huscarl_" + str(i)

			# Positioning
			var base_pos = player_spawn_pos.global_position
			if is_defensive_mission and is_instance_valid(objective_building):
				base_pos = objective_building.global_position + Vector2(100, 100)
			else:
				base_pos += landing_direction * 200.0
			
			var row = current_squad_index / units_per_row
			var col = current_squad_index % units_per_row
			
			base_pos.x += col * (spacing * 4)
			base_pos.y += row * (spacing * 3)
			
			var unit_x = (i % 5) * 25
			var unit_y = (i / 5) * 25
			
			unit.global_position = base_pos + Vector2(unit_x, unit_y)
			
			unit.add_to_group("player_units")
			rts_controller.add_unit_to_group(unit)
			add_child(unit)
			
		current_squad_index += 1

func _spawn_enemy_wave() -> void:
	var spawner = get_node_or_null(enemy_spawn_position)
	if not spawner: return
	# 1. Validation: Do we have enemies to spawn?
	if enemy_wave_units.is_empty():
		Loggie.msg("RaidMission: No enemy units assigned in Inspector!").domain("RAID").warn()
		return
	for i in range(enemy_wave_count):
		# 2. Pick a random enemy data from the list
		var random_data = enemy_wave_units.pick_random()
		# 3. Load the scene using the new safe loader
		var scene_ref = random_data.load_scene()
		if not scene_ref: continue
		# 4. Instantiate
		var unit = scene_ref.instantiate()
		unit.data = random_data # Inject Data back into the unit
		# 5. Setup Layers & Groups
		unit.collision_layer = 1 << 2 # Layer 3 (Enemy Units)
		unit.add_to_group("enemy_units")
		# 6. Position
		unit.global_position = spawner.global_position + Vector2(i * 40, 0)
		add_child(unit)
		# 7. Give Orders
		if objective_building:
			unit.fsm_ready.connect(func(u): 
				if u.fsm: u.fsm.command_attack(objective_building)
			)

func _spawn_fyrd_response() -> void:
	# (Same Fyrd logic as before, triggered by signal)
	pass

func _on_fyrd_arrived() -> void:
	# Reuse existing Fyrd logic
	var spawner = get_node_or_null(enemy_spawn_position)
	var origin = spawner.global_position if spawner else Vector2(1000,0)
	var enemy_data = load("res://data/units/EnemyVikingRaider_Data.tres")
	
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
	var zone = Area2D.new()
	zone.set_script(load("res://scenes/missions/RetreatZone.gd"))
	var poly = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-100,-100), Vector2(100,-100), Vector2(100,100), Vector2(-100,100)])
	zone.add_child(poly)
	zone.global_position = player_spawn_pos.global_position
	add_child(zone)
	zone.unit_evacuated.connect(objective_manager.on_unit_evacuated)

func _load_test_settlement() -> void:
	var data = load("res://data/settlements/home_base_fixed.tres")
	if data: SettlementManager.load_settlement(data)

func _on_settlement_ready_for_mission(_d):
	if not is_instance_valid(objective_manager.rts_controller):
		initialize_mission()

func _validate_nodes() -> bool:
	if not rts_controller or not objective_manager or not grid_manager:
		Loggie.msg("Missing nodes in RaidMission").domain("RAID").error()
		return false
	return true

func _spawn_test_units() -> void:
	pass # Keep placeholder if needed
