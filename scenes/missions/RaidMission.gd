# res://scenes/missions/RaidMission.gd
# Raid Mission Controller for Phase 3
# GDD Ref: Phase 3 Task 7
#
# --- REFACTORED (The "God Object" Fix) ---
# This script is now just a "level loader."
# It loads the map, spawns buildings/units, and then
# passes control to the RaidObjectiveManager node.

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

# --- REMOVED: These vars were moved to RaidObjectiveManager ---
# @export var settlement_bridge_scene_path: String
# @export var is_defensive_mission: bool
# @export var victory_bonus_loot: Dictionary

# --- Node References ---
@onready var player_spawn_pos: Marker2D = $PlayerStartPosition
@onready var rts_controller: RTSController = $RTSController
@onready var grid_manager: Node = $GridManager
@onready var building_container: Node2D = $BuildingContainer
@onready var objective_manager: Node = $RaidObjectiveManager # New reference

# --- State Variables ---
var enemy_hall: BaseBuilding = null
# --- REMOVED: var raid_loot: RaidLootData = null ---


func _ready() -> void:
	EventBus.settlement_loaded.connect(_on_settlement_ready_for_mission)
	
	if not SettlementManager.has_current_settlement():
		print("RaidMission: No current settlement - loading test settlement for standalone mode")
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
	"""Load a test settlement with garrison units for standalone testing"""
	var test_settlement_path = "res://data/settlements/home_base_fixed.tres"
	var test_settlement = load(test_settlement_path) as SettlementData
	
	if test_settlement:
		print("RaidMission: Loading test settlement: %s" % test_settlement_path)
		SettlementManager.load_settlement(test_settlement)
	else:
		push_error("RaidMission: Failed to load test settlement from %s" % test_settlement_path)

func _on_settlement_ready_for_mission(_settlement_data: SettlementData) -> void:
	"""Called when settlement is loaded - only initialize if we haven't already"""
	# Check if objective_manager has been initialized (as a proxy for mission start)
	if not is_instance_valid(objective_manager.rts_controller): 
		print("RaidMission: Settlement loaded - initializing mission")
		initialize_mission()


func initialize_mission() -> void:
	print("RaidMission starting...")
	
	if rts_controller == null or objective_manager == null:
		push_error("RaidMission: Critical error! RTSController or RaidObjectiveManager node not found.")
		get_tree().quit()
		return
	
	if not enemy_base_data:
		enemy_base_data = load(default_enemy_base_path)
		if not enemy_base_data:
			push_error("Could not load enemy base data from default path.")
			return
	
	# 1. Register local grid
	if not is_instance_valid(grid_manager) or not "astar_grid" in grid_manager:
		push_error("RaidMission: GridManager node is missing or invalid!")
		return
	var local_astar_grid = grid_manager.astar_grid
	SettlementManager.register_active_scene_nodes(local_astar_grid, building_container)
	
	# 2. Load buildings and grid
	_load_enemy_base()
	_update_astar_grid_for_enemy_base()
	
	# 3. Spawn units
	_spawn_player_garrison()
	
	# 4. Hand off to Objective Manager
	if is_instance_valid(enemy_hall):
		objective_manager.initialize(rts_controller, enemy_hall, building_container)
	else:
		push_error("RaidMission: Could not find Enemy Hall! Objectives will not function.")

func _load_enemy_base() -> void:
	print("Loading enemy base...")
	
	if not enemy_base_data:
		push_error("No enemy base data provided")
		return
	
	for building_entry in enemy_base_data.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if not building_data:
			push_error("Failed to load building resource as BuildingData: %s" % building_res_path)
			continue
		
		if not building_data.scene_to_spawn:
			push_error("Failed to load building: %s" % building_res_path)
			continue
		
		var building_instance: BaseBuilding = building_data.scene_to_spawn.instantiate()
		building_instance.name = building_data.display_name + "_Enemy"
		
		if "data" in building_instance:
			building_instance.data = building_data
		
		var world_pos: Vector2 = Vector2(grid_pos) * grid_manager.cell_size + (Vector2.ONE * grid_manager.cell_size / 2.0)
		building_instance.global_position = world_pos
		
		building_instance.add_to_group("enemy_buildings")
		
		if building_instance.has_method("set_collision_layer"):
			building_instance.set_collision_layer(4)
			building_instance.set_collision_mask(0)
		
		building_instance.set_meta("building_data", building_data)
		building_instance.set_meta("is_enemy_building", true)
		
		# Find the hall
		if building_data.display_name.to_lower().contains("hall"):
			enemy_hall = building_instance
			print("Found enemy hall: %s" % building_data.display_name)
		
		# Connect signal for GRID CLEARING (loot is handled by objective manager)
		if building_instance.has_signal("building_destroyed"):
			building_instance.building_destroyed.connect(_on_enemy_building_destroyed_grid_clear)
		
		building_container.add_child(building_instance)

func _update_astar_grid_for_enemy_base() -> void:
	print("Updating A* grid for enemy base...")
	
	if not enemy_base_data:
		return
	
	for building_entry in enemy_base_data.placed_buildings:
		var building_data: BuildingData = load(building_entry["resource_path"])
		if not building_data:
			continue
		
		if building_data.blocks_pathfinding:
			var grid_size: Vector2i = building_data.grid_size
			var grid_pos: Vector2i = building_entry["grid_position"]
			
			for x in range(grid_size.x):
				for y in range(grid_size.y):
					var cell_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
					SettlementManager.set_astar_point_solid(cell_pos, true)
	
	if is_instance_valid(grid_manager) and is_instance_valid(grid_manager.astar_grid):
		grid_manager.astar_grid.update()
		print("A* grid updated for enemy base with %d buildings" % enemy_base_data.placed_buildings.size())

func _spawn_player_garrison() -> void:
	print("=== SPAWNING PLAYER GARRISON ===")
	
	if not SettlementManager.current_settlement:
		print("No current settlement found - spawning test units for demo")
		_spawn_test_units() 
		return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	if garrison.is_empty():
		print("No units in garrison to spawn")
		# We must still check for a loss condition
		if not objective_manager.is_defensive_mission:
			# Defer the call to the objective manager
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
			push_error("Failed to load unit data: %s" % unit_path)
			continue
		
		for i in range(unit_count):
			var unit_instance: Node2D = unit_data.scene_to_spawn.instantiate()
			
			if not unit_instance is BaseUnit:
				push_error("Unit scene %s does not extend BaseUnit!" % unit_data.scene_to_spawn.get_path())
				continue
				
			unit_instance.name = unit_data.display_name + "_" + str(i)
			if "data" in unit_instance:
				unit_instance.data = unit_data
			
			var spawn_pos: Vector2 = player_spawn_pos.global_position
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


func _spawn_test_units() -> void:
	# This function is for debug only and does not need refactoring
	print("Spawning test units for box selection demo...")
	var units_per_row: int = 3
	var current_row: int = 0
	var current_col: int = 0
	
	for i in range(6):
		var test_unit = CharacterBody2D.new()
		var script_source = """
extends CharacterBody2D
var is_selected: bool = false; var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 100.0; var is_moving: bool = false
func set_selected(selected: bool) -> void: is_selected = selected; queue_redraw()
func _draw() -> void:
	if is_selected: draw_circle(Vector2.ZERO, 15.0, Color(1,1,0,0.8), false, 2.0)
func command_move_to(target_pos: Vector2) -> void: target_position = target_pos; is_moving = true
func command_attack(target: Node2D) -> void: print('%s attacking %s' % [name, target.name])
func set_target_position(pos: Vector2) -> void: target_position = pos; is_moving = true
func _physics_process(delta: float) -> void:
	if is_moving and target_position != Vector2.ZERO:
		var dir = (target_position - global_position).normalized()
		if global_position.distance_to(target_position) < 5.0:
			is_moving = false; velocity = Vector2.ZERO
		else: velocity = dir * move_speed
		move_and_slide()
"""
		var temp_script = GDScript.new(); temp_script.source_code = script_source
		temp_script.reload(); test_unit.set_script(temp_script)
		
		var spawn_pos: Vector2 = player_spawn_pos.global_position
		spawn_pos.x += current_col * 60
		spawn_pos.y += current_row * 60
		test_unit.global_position = spawn_pos
		test_unit.add_to_group("player_units")
		add_child(test_unit)

		if test_unit is BaseUnit:
			rts_controller.add_unit_to_group(test_unit)
		else:
			push_warning("Test unit '%s' is not a BaseUnit. Skipping add to RTSController." % test_unit.name)
		
		current_col += 1
		if current_col >= units_per_row:
			current_col = 0
			current_row += 1


func _on_enemy_building_destroyed_grid_clear(building: BaseBuilding) -> void:
	"""
	Called when any enemy building is destroyed.
	This function's ONLY job is to clear the pathfinding grid.
	Loot is handled by RaidObjectiveManager.
	"""
	_clear_building_from_pathfinding_grid(building)

func _clear_building_from_pathfinding_grid(building: BaseBuilding) -> void:
	"""Remove building's collision from pathfinding grid"""
	if not building.data or not is_instance_valid(grid_manager):
		return
		
	var cell_size = grid_manager.cell_size
	var half_cell = Vector2.ONE * cell_size / 2.0
	
	var world_pos = building.global_position
	var grid_pos = Vector2i((world_pos - half_cell) / cell_size) 
	var grid_size = building.data.grid_size
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			SettlementManager.set_astar_point_solid(cell_pos, false)
	
	if is_instance_valid(grid_manager.astar_grid):
		grid_manager.astar_grid.update()
		print("RaidMission: Cleared pathfinding for destroyed building at %s (size: %s)" % [grid_pos, grid_size])

# --- ALL WIN/LOSS FUNCTIONS REMOVED ---
# _setup_win_loss_conditions()
# _check_loss_condition()
# _on_mission_failed()
# _show_failure_message()
# _on_enemy_hall_destroyed()
