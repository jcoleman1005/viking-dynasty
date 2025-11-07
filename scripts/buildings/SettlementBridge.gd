# res://scripts/buildings/SettlementBridge.gd
#
# --- REFACTORED (The "Proper Fix" + GridManager) ---
# This scene now instances a GridManager node for all grid logic.
# It gets the grid from that child and registers it with the SettlementManager.

extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var welcome_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/WorldMap_Stub.tscn"

# --- DEPRECATED: Grid config is now on the GridManager node ---
# @export var cell_size: int = 32
# @export var grid_width: int = 60
# @export var grid_height: int = 40

# --- Default Assets (fallback) ---
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var default_raider_scene: PackedScene 
var default_welcome_popup: PackedScene = preload("res://ui/WelcomeHome_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var restart_button: Button = $UI/RestartButton
@onready var start_raid_button: Button = $UI/StartRaidButton
@onready var storefront_ui: Control = $UI/Storefront_UI
@onready var building_cursor: Node2D = $BuildingCursor
var welcome_popup: PanelContainer

# --- Local Node References ---
@onready var building_container: Node2D = $BuildingContainer
@onready var grid_manager: Node = $GridManager # Reference to our new scene

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null


func _ready() -> void:
	_setup_default_resources()
	_initialize_settlement() 
	_setup_ui()
	_connect_signals()
	_handle_welcome_payout()

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()

func _setup_default_resources() -> void:
	if not test_building_data:
		test_building_data = default_test_building
	if not raider_scene:
		raider_scene = load("res://scenes/units/VikingRaider.tscn")
	if not welcome_popup_scene: 
		welcome_popup_scene = default_welcome_popup

func _initialize_settlement() -> void:
	"""Initialize data, then grid, then spawn buildings."""
	if not home_base_data:
		home_base_data = _create_default_settlement()
		print("SettlementBridge: Created default settlement data")
	else:
		if not home_base_data is SettlementData:
			push_warning("SettlementBridge: Inspector data is not SettlementData, creating default")
			home_base_data = _create_default_settlement()
		else:
			print("SettlementBridge: Using inspector settlement data")
	
	if home_base_data and (not home_base_data.resource_path or home_base_data.resource_path.is_empty()):
		home_base_data.resource_path = "res://data/settlements/home_base_fixed.tres"
		print("SettlementBridge: Set resource_path to: %s" % home_base_data.resource_path)
	
	# 1. Load data into the manager
	SettlementManager.load_settlement(home_base_data)
	
	# 2. Get the grid from our new GridManager child
	if not is_instance_valid(grid_manager) or not "astar_grid" in grid_manager:
		push_error("SettlementBridge: GridManager node is missing or invalid!")
		return
	var local_astar_grid = grid_manager.astar_grid
	
	# 3. Register our local nodes with the manager
	SettlementManager.register_active_scene_nodes(local_astar_grid, building_container)
	
	# 4. Spawn buildings into our local container
	_spawn_placed_buildings()
	
	# 5. Emit signal for other nodes (like StorefrontUI)
	EventBus.settlement_loaded.emit(home_base_data)

# --- REMOVED _initialize_local_grid() ---
# This logic is now inside GridManager.gd

func _spawn_placed_buildings() -> void:
	"""
	Instantiates buildings from the loaded settlement data
	using the (now delegated) SettlementManager.place_building function.
	"""
	if not SettlementManager.current_settlement:
		push_error("SettlementBridge: Cannot spawn buildings, no settlement data loaded.")
		return
	
	for child in building_container.get_children():
		child.queue_free()

	for building_entry in SettlementManager.current_settlement.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if building_data:
			var new_building = SettlementManager.place_building(building_data, grid_pos)
			if new_building and new_building.data.display_name == "Great Hall":
				_setup_great_hall(new_building)
		else:
			push_error("Failed to load building resource from path: %s" % building_res_path)
	
	# Update grid once after all buildings are placed
	if is_instance_valid(SettlementManager.active_astar_grid):
		SettlementManager.active_astar_grid.update()
	
	print("SettlementBridge: Spawned %d buildings." % building_container.get_child_count())


func _create_default_settlement() -> SettlementData:
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 1000, "wood": 500, "food": 100, "stone": 200}
	var empty_buildings: Array[Dictionary] = []
	settlement.placed_buildings = empty_buildings
	settlement.garrisoned_units = {}
	settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
	return settlement

func _setup_ui() -> void:
	welcome_popup = welcome_popup_scene.instantiate()
	ui_layer.add_child(welcome_popup)
	welcome_popup.collect_button_pressed.connect(_on_payout_collected)

func _connect_signals() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	start_raid_button.pressed.connect(_on_start_raid_pressed)
	
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	EventBus.building_ready_for_placement.connect(_on_building_ready_for_placement)
	EventBus.building_placement_cancelled.connect(_on_building_placement_cancelled)
	
	if building_cursor:
		building_cursor.placement_completed.connect(_on_building_placement_completed)
		building_cursor.placement_cancelled.connect(_on_building_placement_cancelled_by_cursor)

func _handle_welcome_payout() -> void:
	var payout = SettlementManager.calculate_payout()
	if not payout.is_empty():
		welcome_popup.display_payout(payout)
		storefront_ui.hide()

func _on_settlement_loaded(_settlement_data: SettlementData) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if game_is_over or (welcome_popup and welcome_popup.visible):
		return
	
	if event.is_action_pressed("ui_accept") and not awaiting_placement:
		if is_instance_valid(grid_manager) and "astar_grid" in grid_manager:
			var mouse_pos = get_viewport().get_mouse_position()
			var cell_size = grid_manager.cell_size
			var grid_coord = Vector2i(int(mouse_pos.x / cell_size), int(mouse_pos.y / cell_size)) 
			print("CLICKED GRID COORDINATE: ", grid_coord)
			get_viewport().set_input_as_handled()
		else:
			print("Cannot find coordinate: GridManager not initialized")

func _on_payout_collected(payout: Dictionary) -> void:
	SettlementManager.deposit_resources(payout)
	storefront_ui.show()

func _setup_great_hall(hall_instance: BaseBuilding) -> void:
	if not is_instance_valid(hall_instance):
		push_error("SettlementBridge: Invalid Great Hall instance provided.")
		return
	
	great_hall_instance = hall_instance
	great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)
	print("Great Hall found and connected.")

func _on_great_hall_destroyed(_building: BaseBuilding) -> void:
	print("GAME OVER: The Great Hall has been destroyed!")
	game_is_over = true
	var label : Label = $UI/Label
	label.text = "YOU HAVE BEEN SACKED."
	restart_button.show()
	_destroy_all_enemies()

func _destroy_all_enemies() -> void:
	for enemy in unit_container.get_children():
		enemy.queue_free()
	print("All surviving enemies have been removed.")

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_start_raid_pressed() -> void:
	print("Opening world map...")
	
	if not SettlementManager.current_settlement:
		push_error("Cannot open world map: No settlement loaded")
		return
	
	if SettlementManager.current_settlement.garrisoned_units.is_empty():
		print("Warning: No units in garrison. Adding test unit.")
		var test_unit_path = "res://data/units/Unit_Raider.tres"
		SettlementManager.current_settlement.garrisoned_units[test_unit_path] = 2
		SettlementManager.save_settlement()
	
	print("Settlement loaded with garrison: %s" % SettlementManager.current_settlement.garrisoned_units)
	
	if not world_map_scene_path.is_empty():
		EventBus.scene_change_requested.emit(world_map_scene_path)
	else:
		push_error("world_map_scene_path is not set! Cannot change scene.")

# --- Building Cursor System Functions ---

func _on_building_ready_for_placement(building_data: BuildingData) -> void:
	awaiting_placement = building_data
	# Pass the cell_size from our GridManager to the cursor
	building_cursor.cell_size = grid_manager.cell_size
	building_cursor.set_building_preview(building_data)
	print("Building ready for placement: %s" % building_data.display_name)

func _on_building_placement_cancelled(building_data: BuildingData) -> void:
	print("Building placement cancelled: %s" % building_data.display_name)

func _on_building_placement_completed() -> void:
	print("Building placement completed successfully. Saving settlement.")
	
	if awaiting_placement and SettlementManager.current_settlement:
		var snapped_grid_pos = Vector2i(building_cursor.global_position / grid_manager.cell_size)
		
		var building_entry = {
			"resource_path": awaiting_placement.resource_path,
			"grid_position": snapped_grid_pos
		}
		SettlementManager.current_settlement.placed_buildings.append(building_entry)
		SettlementManager.save_settlement()
		print("Added %s to settlement data at %s" % [awaiting_placement.display_name, snapped_grid_pos])
	
	awaiting_placement = null

func _on_building_placement_cancelled_by_cursor() -> void:
	if awaiting_placement:
		SettlementManager.deposit_resources(awaiting_placement.build_cost)
		print("Building placement cancelled by cursor, refunded: %s" % awaiting_placement.build_cost)
		
		awaiting_placement = null
