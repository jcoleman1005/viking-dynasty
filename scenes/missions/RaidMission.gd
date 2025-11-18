# res://scenes/missions/RaidMission.gd
extends Node2D

# --- Exported Mission Configuration ---
@export var enemy_base_data: SettlementData
@export var default_enemy_base_path: String = "res://data/settlements/monastery_base.tres"
@export_group("Enemy Base Presets")
@export var available_enemy_bases: Array[String] = [
	"res://data/settlements/monastery_base.tres",
	"res://data/settlements/fortress_base.tres"
]
@export var player_spawn_formation: Dictionary = {"units_per_row": 5, "spacing": 40}
@export var mission_difficulty: float = 1.0
@export var allow_retreat: bool = true

# --- Defensive Mission Settings ---
@export var is_defensive_mission: bool = false
@export var enemy_spawn_position: NodePath
# --- NEW: RAID DIRECTION SETTING ---
## The direction units should step towards when disembarking.
## (1, 0) = Right, (-1, 0) = Left, (0, 1) = Down, etc.
## This allows future maps to rotate the beach landing.
@export var landing_direction: Vector2 = Vector2.RIGHT

# --- Node References ---
@onready var player_spawn_pos: Marker2D = $PlayerStartPosition
@onready var rts_controller: RTSController = $RTSController
@onready var grid_manager: Node = $GridManager
@onready var building_container: Node2D = $BuildingContainer
@onready var objective_manager: RaidObjectiveManager = $RaidObjectiveManager

# --- State Variables ---
var objective_building: BaseBuilding = null
var enemy_units: Array[BaseUnit] = []

func _ready() -> void:
	if DynastyManager.is_defensive_raid:
		self.is_defensive_mission = true
		objective_manager.is_defensive_mission = true
		DynastyManager.is_defensive_raid = false
	
	EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission)
	
	if not SettlementManager.has_current_settlement():
		Loggie.msg("RaidMission: No current settlement - loading test settlement").domain("RAIDMISSION").info()
		_load_test_settlement()
		call_deferred("initialize_mission")
	else:
		Loggie.msg("RaidMission: Settlement already loaded - initializing mission").domain("RAIDMISSION").info()
		call_deferred("initialize_mission")

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()
	if EventBus.is_connected("settlement_loaded", _on_settlement_ready_for_mission):
		EventBus.settlement_loaded.disconnect(_on_settlement_ready_for_mission)

func _load_test_settlement() -> void:
	var test_settlement_path = "res://data/settlements/home_base_fixed.tres"
	var test_settlement = load(test_settlement_path) as SettlementData
	if test_settlement:
		SettlementManager.load_settlement(test_settlement)

func _on_settlement_ready_for_mission(_settlement_data: SettlementData) -> void:
	if not is_instance_valid(objective_manager.rts_controller): 
		initialize_mission()

func initialize_mission() -> void:
	if rts_controller == null or objective_manager == null:
		Loggie.msg("RaidMission: Critical error! Nodes missing.").domain("RAIDMISSION").error()
		get_tree().quit()
		return
	
	if not is_instance_valid(grid_manager) or not "astar_grid" in grid_manager:
		Loggie.msg("RaidMission: GridManager node is missing or invalid!").domain("RAIDMISSION").error()
		return
		
	var local_astar_grid = grid_manager.astar_grid
	SettlementManager.register_active_scene_nodes(local_astar_grid, building_container)
	
	if is_defensive_mission:
		_load_player_base_for_defense()
		_spawn_player_garrison()
		_spawn_enemy_wave()
	else:
		if not enemy_base_data:
			enemy_base_data = load(default_enemy_base_path)
		_load_enemy_base()
		_spawn_player_garrison()
	if not is_defensive_mission:
		_spawn_retreat_zone()
		
	if is_instance_valid(objective_building):
		objective_manager.initialize(rts_controller, objective_building, building_container, enemy_units)
		
		# Connect Fyrd Signal
		if not objective_manager.fyrd_arrived.is_connected(_on_fyrd_arrived):
			objective_manager.fyrd_arrived.connect(_on_fyrd_arrived)
	else:
		Loggie.msg("RaidMission: Could not find Objective Building (Great Hall)!").domain("RAIDMISSION").error()

func _load_player_base_for_defense() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	_spawn_building_list(settlement.placed_buildings, false)
	_spawn_building_list(settlement.pending_construction_buildings, true)
	
	_update_astar_grid_for_base(settlement.placed_buildings)

func _spawn_building_list(list: Array, is_blueprint: bool) -> void:
	for building_entry in list:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if not building_data or not building_data.scene_to_spawn: continue
		
		var building_instance: BaseBuilding = building_data.scene_to_spawn.instantiate()
		building_instance.name = building_data.display_name + "_Player"
		building_instance.data = building_data
		
		var world_pos_top_left: Vector2 = Vector2(grid_pos) * grid_manager.cell_size
		var building_footprint_size: Vector2 = Vector2(building_data.grid_size) * grid_manager.cell_size
		var building_center_offset: Vector2 = building_footprint_size / 2.0
		building_instance.global_position = world_pos_top_left + building_center_offset
		
		building_instance.set_collision_layer(1)
		building_instance.set_collision_mask(0) 
		
		if building_data.display_name.to_lower().contains("hall"):
			objective_building = building_instance
			
		building_container.add_child(building_instance)
		
		if is_blueprint:
			building_instance.set_state(BaseBuilding.BuildingState.BLUEPRINT)

func _load_enemy_base() -> void:
	if not enemy_base_data: return
	
	for building_entry in enemy_base_data.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if not building_data or not building_data.scene_to_spawn: continue
		
		var building_instance: BaseBuilding = building_data.scene_to_spawn.instantiate()
		building_instance.name = building_data.display_name + "_Enemy"
		if "data" in building_instance: building_instance.data = building_data
		
		var world_pos_top_left: Vector2 = Vector2(grid_pos) * grid_manager.cell_size
		var building_footprint_size: Vector2 = Vector2(building_data.grid_size) * grid_manager.cell_size
		var building_center_offset: Vector2 = building_footprint_size / 2.0
		building_instance.global_position = world_pos_top_left + building_center_offset
		
		building_instance.add_to_group("enemy_buildings")
		building_instance.set_collision_layer(1 << 3) # Layer 4
		building_instance.set_collision_mask(0)
		
		if building_data.display_name.to_lower().contains("hall"):
			objective_building = building_instance
		
		if building_instance.has_signal("building_destroyed"):
			building_instance.building_destroyed.connect(_on_enemy_building_destroyed_grid_clear)
		
		building_container.add_child(building_instance)
	
	_update_astar_grid_for_base(enemy_base_data.placed_buildings)

func _update_astar_grid_for_base(placed_buildings: Array) -> void:
	for building_entry in placed_buildings:
		var building_data: BuildingData = load(building_entry["resource_path"])
		if not building_data: continue
		
		if building_data.blocks_pathfinding:
			var grid_size: Vector2i = building_data.grid_size
			var grid_pos: Vector2i = building_entry["grid_position"]
			
			for x in range(grid_size.x):
				for y in range(grid_size.y):
					var cell_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
					SettlementManager.set_astar_point_solid(cell_pos, true)
	
	if is_instance_valid(grid_manager) and is_instance_valid(grid_manager.astar_grid):
		grid_manager.astar_grid.update()

# --- FIXED: SPAWN PLAYER SQUADS (10 Men per Warband) ---
func _spawn_player_garrison() -> void:
	if not SettlementManager.current_settlement:
		_spawn_test_units() 
		return
	
	var warbands = SettlementManager.current_settlement.warbands
	
	if warbands.is_empty():
		if not is_defensive_mission:
			objective_manager.call_deferred("_check_loss_condition")
		return
	
	var units_per_row: int = player_spawn_formation.get("units_per_row", 5)
	var spacing: float = player_spawn_formation.get("spacing", 40.0)
	
	var current_squad_index: int = 0
	
	for warband in warbands:
		if warband.is_wounded: continue
		
		# --- NEW: Restore Loyalty on Deploy ---
		if warband.loyalty < 100:
			warband.modify_loyalty(50)
			warband.turns_idle = 0
			Loggie.msg("Warband %s: Loyalty restored by battle!" % warband.custom_name).domain("RAIDMISSION").info()
		# --------------------------------------
		
		var unit_data = warband.unit_type
		if not unit_data or not unit_data.scene_to_spawn: continue
		
		# --- SQUAD LOGIC: 10 MEN ---
		for i in range(warband.current_manpower):
			var unit_instance: Node2D = unit_data.scene_to_spawn.instantiate()
			if not unit_instance is BaseUnit: continue
				
			# Identity
			unit_instance.warband_ref = warband
			unit_instance.data = unit_data
			
			# Naming
			if i == 0: unit_instance.name = warband.custom_name + "_Thegn"
			elif i == 1: unit_instance.name = warband.custom_name + "_Banner"
			else: unit_instance.name = warband.custom_name + "_Huscarl_" + str(i)
			
			# Force Controllable
			unit_instance.collision_layer = 2 

			# --- FIX: DYNAMIC SPAWN OFFSET ---
			var base_pos = player_spawn_pos.global_position
			
			if is_defensive_mission and is_instance_valid(objective_building):
				base_pos = objective_building.global_position + Vector2(100, 100)
			else:
				# Offensive: Use the exported landing_direction
				# Multiply by 200 pixels to clear the Retreat Zone
				base_pos += landing_direction * 200.0
			# ---------------------------------
			
			# Squad Positioning
			var row = current_squad_index / units_per_row
			var col = current_squad_index % units_per_row
			
			base_pos.x += col * (spacing * 4)
			base_pos.y += row * (spacing * 3)
			
			# Individual Unit Positioning
			var unit_x = (i % 5) * 25
			var unit_y = (i / 5) * 25
			
			unit_instance.global_position = base_pos + Vector2(unit_x, unit_y)
			
			# Registration
			unit_instance.add_to_group("player_units")
			rts_controller.add_unit_to_group(unit_instance)
			add_child(unit_instance)
			
		current_squad_index += 1


func _spawn_enemy_wave() -> void:
	var enemy_spawner = get_node_or_null(enemy_spawn_position)
	if not is_instance_valid(enemy_spawner): return
		
	var enemy_data_path = "res://data/units/EnemyVikingRaider_Data.tres"
	var enemy_data: UnitData = load(enemy_data_path)
	if not enemy_data or not enemy_data.scene_to_spawn: return

	var enemy_count = 5
	for i in range(enemy_count):
		var enemy_node = enemy_data.scene_to_spawn.instantiate()
		var enemy_unit = enemy_node as BaseUnit
		if not enemy_unit: continue
		
		enemy_unit.data = enemy_data
		enemy_unit.name = enemy_data.display_name + "_Enemy_" + str(i)
		enemy_unit.collision_layer = 1 << 2 
		
		add_child(enemy_node) 
		
		var spawn_pos = enemy_spawner.global_position + Vector2(i * 40, 0)
		enemy_unit.global_position = spawn_pos
		
		enemy_unit.add_to_group("enemy_units")
		enemy_units.append(enemy_unit)
		
		if is_instance_valid(objective_building):
			enemy_unit.fsm_ready.connect(_on_enemy_fsm_ready.bind(objective_building))

func _on_enemy_fsm_ready(enemy_unit: BaseUnit, target: BaseBuilding) -> void:
	if not is_instance_valid(target) or not is_instance_valid(enemy_unit): return

	if enemy_unit.attack_ai:
		enemy_unit.attack_ai.ai_mode = AttackAI.AI_Mode.DEFENSIVE_SIEGE
		
	if enemy_unit.fsm:
		enemy_unit.fsm.command_attack(target)

func _spawn_test_units() -> void:
	var player_data_path = "res://data/units/Unit_PlayerRaider.tres"
	var player_data: UnitData = load(player_data_path)
	if not player_data: return

	var count = 5
	var spacing = 40
	for i in range(count):
		var unit_instance = player_data.scene_to_spawn.instantiate() as BaseUnit
		if not unit_instance: continue
		
		unit_instance.name = "Test_Player_" + str(i)
		unit_instance.data = player_data
		unit_instance.collision_layer = 2 
		
		var spawn_pos = player_spawn_pos.global_position
		spawn_pos.x += i * spacing
		unit_instance.global_position = spawn_pos
		
		unit_instance.add_to_group("player_units")
		rts_controller.add_unit_to_group(unit_instance)
		add_child(unit_instance)

func _on_enemy_building_destroyed_grid_clear(building: BaseBuilding) -> void:
	_clear_building_from_pathfinding_grid(building)

func _clear_building_from_pathfinding_grid(building: BaseBuilding) -> void:
	if not building.data or not is_instance_valid(grid_manager): return
		
	var cell_size = grid_manager.cell_size
	var size_in_pixels = Vector2(building.data.grid_size) * cell_size
	var top_left_pos = building.global_position - (size_in_pixels / 2.0)
	var grid_pos = Vector2i(top_left_pos / cell_size)
	var grid_size = building.data.grid_size
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			SettlementManager.set_astar_point_solid(cell_pos, false)
	
	if is_instance_valid(grid_manager.astar_grid):
		grid_manager.astar_grid.update()

# --- FYRD RESPONSE (ANTI-GRIND) ---

func _on_fyrd_arrived() -> void:
	# Spawn 20 units at the enemy spawn point (or edges)
	var fyrd_count = 20
	var spawn_origin = Vector2(1000, 0) # Default if marker missing
	
	var spawner = get_node_or_null(enemy_spawn_position)
	if spawner:
		spawn_origin = spawner.global_position
	
	Loggie.msg("Spawning Fyrd Wave: %d units" % fyrd_count).domain("RAIDMISSION").warn()
	
	# Load template
	var enemy_data = load("res://data/units/EnemyVikingRaider_Data.tres") as UnitData
	if not enemy_data: return
	
	for i in range(fyrd_count):
		var unit = enemy_data.scene_to_spawn.instantiate() as BaseUnit
		if not unit: continue
		
		unit.data = enemy_data
		unit.name = "Fyrd_Warrior_%d" % i
		
		# Fyrd Buffs: Faster and Stronger
		unit.current_health = 100 # Double HP
		unit.collision_layer = 1 << 2 # Layer 3 (Enemy)
		
		# Random offset spawn
		var offset = Vector2(randf_range(-200, 200), randf_range(-200, 200))
		unit.global_position = spawn_origin + offset
		
		add_child(unit)
		
		# Command them to attack player units immediately
		if unit.attack_ai:
			unit.attack_ai.ai_mode = AttackAI.AI_Mode.DEFAULT # Aggressive
func _spawn_retreat_zone() -> void:
	var zone = Area2D.new()
	zone.name = "RetreatZone"
	zone.set_script(load("res://scenes/missions/RetreatZone.gd"))
	
	# Visual Debug
	var poly = Polygon2D.new()
	poly.color = Color(0.2, 0.8, 1.0, 0.3) # Blue extraction zone
	var points = PackedVector2Array([Vector2(-100,-100), Vector2(100,-100), Vector2(100,100), Vector2(-100,100)])
	poly.polygon = points
	zone.add_child(poly)
	
	# Collision
	var coll = CollisionPolygon2D.new()
	coll.polygon = points
	zone.add_child(coll)
	
	# Position at Spawn
	zone.global_position = player_spawn_pos.global_position
	
	add_child(zone)
	
	# Connect Signal
	if zone.has_signal("unit_evacuated"):
		zone.unit_evacuated.connect(objective_manager.on_unit_evacuated)
