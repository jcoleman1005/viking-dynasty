# res://scenes/missions/RaidMission.gd
# Raid Mission Controller for Phase 3
#
# --- REFACTORED ---
# Fixed initialization order: 'data' is now assigned BEFORE add_child().
# This ensures BaseUnit._ready() has the data needed to create the FSM.
# Fixed race condition in enemy spawning by using fsm_ready signal.
# ------------------
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

# --- NEW: Defensive Mission ---
@export var is_defensive_mission: bool = false
@export var enemy_spawn_position: NodePath
# -----------------------------

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
		print("RaidMission: No current settlement - loading test settlement")
		_load_test_settlement()
		call_deferred("initialize_mission")
	else:
		print("RaidMission: Settlement already loaded - initializing mission")
		call_deferred("initialize_mission")

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()
	
	if EventBus.is_connected("settlement_loaded", _on_settlement_ready_for_mission):
		EventBus.settlement_loaded.disconnect(_on_settlement_ready_for_mission)


func _load_test_settlement() -> void:
	var test_settlement_path = "res://data/settlements/home_base_fixed.tres"
	var test_settlement = load(test_settlement_path) as SettlementData
	
	if test_settlement:
		print("RaidMission: Loading test settlement: %s" % test_settlement_path)
		SettlementManager.load_settlement(test_settlement)
	else:
		push_error("RaidMission: Failed to load test settlement from %s" % test_settlement_path)

func _on_settlement_ready_for_mission(_settlement_data: SettlementData) -> void:
	if not is_instance_valid(objective_manager.rts_controller): 
		print("RaidMission: Settlement loaded - initializing mission")
		initialize_mission()


func initialize_mission() -> void:
	print("RaidMission starting...")
	
	if rts_controller == null or objective_manager == null:
		push_error("RaidMission: Critical error! Nodes missing.")
		get_tree().quit()
		return
	
	if not is_instance_valid(grid_manager) or not "astar_grid" in grid_manager:
		push_error("RaidMission: GridManager node is missing or invalid!")
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
			if not enemy_base_data:
				push_error("Could not load enemy base data.")
				return
		_load_enemy_base()
		_spawn_player_garrison()
	
	if is_instance_valid(objective_building):
		objective_manager.initialize(rts_controller, objective_building, building_container, enemy_units)
	else:
		push_error("RaidMission: Could not find Objective Building (Great Hall)!")


func _load_player_base_for_defense() -> void:
	print("Loading PLAYER base for defense...")
	var settlement = SettlementManager.current_settlement
	if not settlement:
		push_error("Defensive Mission: Cannot load player base.")
		return
		
	for building_entry in settlement.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if not building_data or not building_data.scene_to_spawn:
			continue
		
		var building_instance: BaseBuilding = building_data.scene_to_spawn.instantiate()
		building_instance.name = building_data.display_name + "_Player"
		building_instance.data = building_data
		
		var world_pos_top_left: Vector2 = Vector2(grid_pos) * grid_manager.cell_size
		var building_footprint_size: Vector2 = Vector2(building_data.grid_size) * grid_manager.cell_size
		var building_center_offset: Vector2 = building_footprint_size / 2.0
		building_instance.global_position = world_pos_top_left + building_center_offset
		
		# CLEANED: Whitespace removed
		building_instance.set_collision_layer(1) # Player Buildings (Layer 1)
		building_instance.set_collision_mask(0) 
		
		if building_data.display_name.to_lower().contains("hall"):
			objective_building = building_instance
			
		if building_instance.has_signal("building_destroyed"):
			building_instance.building_destroyed.connect(_on_enemy_building_destroyed_grid_clear)
		
		building_container.add_child(building_instance)
	
	_update_astar_grid_for_base(settlement.placed_buildings)


func _load_enemy_base() -> void:
	print("Loading ENEMY base for offense...")
	if not enemy_base_data:
		return
	
	for building_entry in enemy_base_data.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if not building_data or not building_data.scene_to_spawn:
			continue
		
		var building_instance: BaseBuilding = building_data.scene_to_spawn.instantiate()
		building_instance.name = building_data.display_name + "_Enemy"
		
		if "data" in building_instance:
			building_instance.data = building_data
		
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


func _spawn_player_garrison() -> void:
	if not SettlementManager.current_settlement:
		_spawn_test_units() 
		return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	if garrison.is_empty():
		if not is_defensive_mission:
			objective_manager.call_deferred("_check_loss_condition")
		return
	
	var units_per_row: int = player_spawn_formation.get("units_per_row", 5)
	var spacing: float = player_spawn_formation.get("spacing", 40.0)
	var current_row: int = 0
	var current_col: int = 0
	
	for unit_path in garrison:
		var unit_count: int = garrison[unit_path]
		var unit_data: UnitData = load(unit_path)
		
		if not unit_data or not unit_data.scene_to_spawn:
			continue
		
		for i in range(unit_count):
			var unit_instance: Node2D = unit_data.scene_to_spawn.instantiate()
			
			if not unit_instance is BaseUnit:
				continue
				
			unit_instance.name = unit_data.display_name + "_" + str(i)
			if "data" in unit_instance:
				unit_instance.data = unit_data
			
			var spawn_pos: Vector2 = player_spawn_pos.global_position
			
			if is_defensive_mission and is_instance_valid(objective_building):
				spawn_pos = objective_building.global_position + Vector2(100, 100)
			
			spawn_pos.x += current_col * spacing
			spawn_pos.y += current_row * spacing
			unit_instance.global_position = spawn_pos
			
			unit_instance.add_to_group("player_units")
			rts_controller.add_unit_to_group(unit_instance)
			add_child(unit_instance)
			
			current_col += 1
			if current_col >= units_per_row:
				current_col = 0
				current_row += 1


func _spawn_enemy_wave() -> void:
	print("=== SPAWNING ENEMY WAVE ===")
	var enemy_spawner = get_node_or_null(enemy_spawn_position)
	if not is_instance_valid(enemy_spawner):
		push_error("Defensive Mission: Invalid or missing 'Enemy Spawn Position' node!")
		return
		
	var enemy_data_path = "res://data/units/EnemyVikingRaider_Data.tres"
	var enemy_data: UnitData = load(enemy_data_path)
	if not enemy_data or not enemy_data.scene_to_spawn:
		push_error("Failed to load enemy unit data: %s" % enemy_data_path)
		return

	var enemy_count = 5
	for i in range(enemy_count):
		
		# 1. Instantiate
		var enemy_node = enemy_data.scene_to_spawn.instantiate()
		
		# 2. Cast to BaseUnit and Set Data BEFORE add_child
		var enemy_unit = enemy_node as BaseUnit
		if not enemy_unit:
			push_error("Spawned enemy node is not a BaseUnit!")
			enemy_node.queue_free()
			continue
		
		# Assign data before adding to tree
		enemy_unit.data = enemy_data
		enemy_unit.name = enemy_data.display_name + "_Enemy_" + str(i)
		# Use bit-shift for clarity (Layer 3 = 1 << 2, value 4)
		enemy_unit.collision_layer = 1 << 2 
		
		# 3. Add to Tree (Triggers _ready(), which now finds 'data')
		add_child(enemy_node) 
		
		var spawn_pos = enemy_spawner.global_position + Vector2(i * 40, 0)
		enemy_unit.global_position = spawn_pos
		
		enemy_unit.add_to_group("enemy_units")
		enemy_units.append(enemy_unit)
		
		# 4. Connect to the FSM ready signal
		# We DO NOT access FSM or AttackAI here. We wait for the signal.
		if is_instance_valid(objective_building):
			enemy_unit.fsm_ready.connect(_on_enemy_fsm_ready.bind(objective_building))
	
	print("Spawned %d enemy raiders." % enemy_count)

# --- UPDATED SIGNAL HANDLER: Handles ALL post-spawn configuration ---
func _on_enemy_fsm_ready(enemy_unit: BaseUnit, target: BaseBuilding) -> void:
	"""
	Called by the enemy unit when its FSM is fully set up via _deferred_setup.
	This ensures we only issue the command when the unit is ready to receive it.
	"""
	if not is_instance_valid(target) or not is_instance_valid(enemy_unit):
		return

	# 1. Configure the AttackAI mode (NOW SAFE)
	if enemy_unit.attack_ai:
		enemy_unit.attack_ai.ai_mode = AttackAI.AI_Mode.DEFENSIVE_SIEGE
		
	# 2. Command Attack (NOW SAFE)
	if enemy_unit.fsm:
		enemy_unit.fsm.command_attack(target)
	else:
		push_error("Enemy unit %s FSM is still null after signal! FSM setup failed." % enemy_unit.name)

func _spawn_test_units() -> void:
	# (Test unit spawning code omitted for brevity - unchanged)
	pass

func _on_enemy_building_destroyed_grid_clear(building: BaseBuilding) -> void:
	_clear_building_from_pathfinding_grid(building)

func _clear_building_from_pathfinding_grid(building: BaseBuilding) -> void:
	if not building.data or not is_instance_valid(grid_manager):
		return
		
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
