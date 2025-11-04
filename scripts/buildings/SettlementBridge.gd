# res://scripts/buildings/SettlementBridge.gd

extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var welcome_popup_scene: PackedScene

## The scene for the world map (e.g., WorldMap_Stub.tscn)
@export var world_map_scene: PackedScene

##Size of the cell for the grid helper
@export var cell_size: int = 32
# --- Default Assets (fallback) ---
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
# --- FIX: Removed preload() to break circular dependency ---
var default_raider_scene: PackedScene 
var default_welcome_popup: PackedScene = preload("res://ui/WelcomeHome_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var restart_button: Button = $UI/RestartButton
@onready var start_attack_button: Button = $UI/StartAttackButton
@onready var start_raid_button: Button = $UI/StartRaidButton
@onready var storefront_ui: Control = $UI/Storefront_UI
@onready var building_cursor: Node2D = $BuildingCursor
var welcome_popup: PanelContainer

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null
const RAIDER_SPAWN_POS: Vector2 = Vector2(50, 50)


func _ready() -> void:
	_setup_default_resources()
	_initialize_settlement()
	_setup_ui()
	_connect_signals()
	_handle_welcome_payout()

func _setup_default_resources() -> void:
	"""Initialize default resources and handle missing inspector assignments"""
	# Setup fallback resources if not set in inspector
	if not test_building_data:
		test_building_data = default_test_building
	
	# Load the default raider scene at runtime to avoid circular dependencies
	if not raider_scene:
		raider_scene = load("res://scenes/units/VikingRaider.tscn")
		
	if not welcome_popup_scene:
		welcome_popup_scene = default_welcome_popup

func _initialize_settlement() -> void:
	"""Initialize or load settlement data"""
	# Use inspector data if available, otherwise create default
	if not home_base_data:
		home_base_data = _create_default_settlement()
		print("SettlementBridge: Created default settlement data")
	else:
		# Verify inspector data is valid
		if not home_base_data is SettlementData:
			push_warning("SettlementBridge: Inspector data is not SettlementData, creating default")
			home_base_data = _create_default_settlement()
		else:
			print("SettlementBridge: Using inspector settlement data")
	
	# Ensure resource path is set for saving
	if home_base_data and (not home_base_data.resource_path or home_base_data.resource_path.is_empty()):
		# Set the resource path based on the expected file name
		home_base_data.resource_path = "res://data/settlements/home_base_fixed.tres"
		print("SettlementBridge: Set resource_path to: %s" % home_base_data.resource_path)
	
	# Load the settlement into the manager
	SettlementManager.load_settlement(home_base_data)
	
	# Let child nodes handle their own initialization via signals
	EventBus.settlement_loaded.emit(home_base_data)

func _create_default_settlement() -> SettlementData:
	"""Create a default settlement with basic resources"""
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 1000, "wood": 500, "food": 100, "stone": 200}
	var empty_buildings: Array[Dictionary] = []
	settlement.placed_buildings = empty_buildings
	settlement.garrisoned_units = {}
	
	# Set resource path for saving
	settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
	
	return settlement

func _setup_ui() -> void:
	"""Initialize UI components"""
	welcome_popup = welcome_popup_scene.instantiate()
	ui_layer.add_child(welcome_popup)
	welcome_popup.collect_button_pressed.connect(_on_payout_collected)

func _connect_signals() -> void:
	"""Connect button signals"""
	restart_button.pressed.connect(_on_restart_pressed)
	start_attack_button.pressed.connect(_on_start_attack_pressed)
	start_raid_button.pressed.connect(_on_start_raid_pressed)
	
	# Connect to EventBus for loose coupling
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	EventBus.building_ready_for_placement.connect(_on_building_ready_for_placement)
	EventBus.building_placement_cancelled.connect(_on_building_placement_cancelled)
	
	# Connect BuildingPreviewCursor signals
	if building_cursor:
		building_cursor.placement_completed.connect(_on_building_placement_completed)
		building_cursor.placement_cancelled.connect(_on_building_placement_cancelled_by_cursor)

func _handle_welcome_payout() -> void:
	"""Handle any pending payout when returning to settlement"""
	var payout = SettlementManager.calculate_payout()
	if not payout.is_empty():
		welcome_popup.display_payout(payout)
		start_attack_button.disabled = true # Disable combat until payout is collected
		storefront_ui.hide()

func _on_settlement_loaded(_settlement_data: SettlementData) -> void:
	"""Called when settlement is fully loaded - find and setup buildings"""
	call_deferred("_find_and_setup_great_hall")


func _input(event: InputEvent) -> void:
	# This runs BEFORE GUI input, so we can consume it.
	if event.is_action_pressed("ui_accept"):
		if game_is_over or welcome_popup.visible:
			return # Don't grant loot if game over screen or popup is visible
		
		print("DEBUG: SettlementManager.current_settlement before deposit: ", SettlementManager.current_settlement)
		var sample_loot = {"gold": 100, "wood": 50, "food": 25, "stone": 75}
		print("DEBUG: Granting sample loot via key press.")
		SettlementManager.deposit_resources(sample_loot)
		
		# DEBUG: Ensure storefront UI is visible to see the update
		if not storefront_ui.visible:
			storefront_ui.show()
			print("DEBUG: Showed storefront UI to display updated treasury")
		
		get_viewport().set_input_as_handled() # CRITICAL: Stop event from reaching buttons


func _unhandled_input(event: InputEvent) -> void:
	# This runs AFTER GUI input, so it's safe for non-UI actions like placing buildings.
	if game_is_over or (welcome_popup and welcome_popup.visible):
		return
	
	# --- COORDINATE FINDER LOGIC (for debugging) ---
	# Use a keyboard shortcut (e.g., Spacebar/ui_accept) to print coordinates
	if event.is_action_pressed("ui_accept") and not awaiting_placement:
		if SettlementManager.astar_grid:
			var mouse_pos = get_viewport().get_mouse_position()
			var grid_coord = Vector2i(int(mouse_pos.x / cell_size), int(mouse_pos.y / cell_size)) 
			print("CLICKED GRID COORDINATE: ", grid_coord)
			get_viewport().set_input_as_handled()
		else:
			print("Cannot find coordinate: AStarGrid not initialized")

func _on_payout_collected(payout: Dictionary) -> void:
	SettlementManager.deposit_resources(payout)
	start_attack_button.disabled = false # Re-enable combat
	storefront_ui.show()

func _find_and_setup_great_hall() -> void:
	for building in SettlementManager.building_container.get_children():
		if building is BaseBuilding and building.data.display_name == "Great Hall":
			great_hall_instance = building
			great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)
			print("Great Hall found and connected.")
			return
	push_error("SettlementBridge: Could not find Great Hall instance after loading settlement.")


func _spawn_raider_for_test() -> void:
	if not great_hall_instance:
		push_error("Cannot spawn raider: Great Hall does not exist.")
		return
		
	var raider_instance: BaseUnit = raider_scene.instantiate()
	unit_container.add_child(raider_instance)
	raider_instance.global_position = RAIDER_SPAWN_POS
	raider_instance.set_attack_target(great_hall_instance)


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

func _on_start_attack_pressed() -> void:
	print("Start Attack button pressed. Spawning raider.")
	# Timestamps are no longer needed for a fixed-payout system.
	_spawn_raider_for_test()
	start_attack_button.hide()
	storefront_ui.hide()

func _on_start_raid_pressed() -> void:
	"""Navigate to the world map to select targets"""
	print("Opening world map...")
	
	# Validate that we have a settlement loaded
	if not SettlementManager.current_settlement:
		push_error("Cannot open world map: No settlement loaded")
		return
	
	
	# Ensure we have some units in the garrison for raiding
	if SettlementManager.current_settlement.garrisoned_units.is_empty():
		print("Warning: No units in garrison. Adding test unit.")
		# Add a test unit so raids can proceed
		var test_unit_path = "res://data/units/Unit_Raider.tres"
		SettlementManager.current_settlement.garrisoned_units[test_unit_path] = 2
		SettlementManager.save_settlement()
	
	print("Settlement loaded with garrison: %s" % SettlementManager.current_settlement.garrisoned_units)
	
	# Navigate to world map instead of direct raid
	if world_map_scene:
		get_tree().change_scene_to_packed(world_map_scene)
	else:
		# Fallback: load world map directly if not set in inspector
		print("world_map_scene not set, loading WorldMap_Stub directly")
		get_tree().change_scene_to_file("res://scenes/world_map/WorldMap_Stub.tscn")

# --- NEW BUILDING CURSOR SYSTEM FUNCTIONS ---

func _on_building_ready_for_placement(building_data: BuildingData) -> void:
	"""Handle when a building is purchased and ready for cursor placement"""
	awaiting_placement = building_data
	building_cursor.set_building_preview(building_data)
	print("Building ready for placement: %s" % building_data.display_name)

func _on_building_placement_cancelled(building_data: BuildingData) -> void:
	"""Handle when building placement is cancelled - for future use"""
	print("Building placement cancelled: %s" % building_data.display_name)

func _handle_building_placement() -> void:
	"""Place building at cursor position and complete the placement"""
	if not awaiting_placement:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var grid_pos: Vector2i
	
	if SettlementManager.astar_grid and SettlementManager.astar_grid.cell_size != Vector2.ZERO:
		grid_pos = Vector2i(mouse_pos / SettlementManager.astar_grid.cell_size)
	else:
		grid_pos = Vector2i(mouse_pos / cell_size)
	
	# Check if placement is valid
	if SettlementManager.astar_grid and SettlementManager.astar_grid.is_point_solid(grid_pos):
		print("Cannot place building: Position occupied")
		return
	
	# Place the building
	var new_building = SettlementManager.place_building(awaiting_placement, grid_pos)
	
	if new_building and SettlementManager.current_settlement:
		var building_entry = {
			"resource_path": awaiting_placement.resource_path,
			"grid_position": grid_pos
		}
		SettlementManager.current_settlement.placed_buildings.append(building_entry)
		print("Placed %s at %s via cursor system." % [awaiting_placement.display_name, grid_pos])
		SettlementManager.save_settlement()
		
		# Complete the placement
		_complete_building_placement()
	else:
		print("Failed to place building")

func _cancel_building_placement() -> void:
	"""Cancel building placement and refund the cost"""
	if not awaiting_placement:
		return
	
	# Refund the cost
	SettlementManager.deposit_resources(awaiting_placement.build_cost)
	print("Cancelled placement of %s and refunded cost" % awaiting_placement.display_name)
	
	# Complete the cancellation
	_complete_building_placement()

func _complete_building_placement() -> void:
	"""Clean up after building placement (successful or cancelled)"""
	building_cursor.cancel_preview()
	awaiting_placement = null

func _on_building_placement_completed() -> void:
	"""Handle successful building placement"""
	print("Building placement completed successfully")
	
	# Save the settlement with the new building
	if SettlementManager.current_settlement:
		SettlementManager.save_settlement()
	
	# Clean up placement state
	awaiting_placement = null

func _on_building_placement_cancelled_by_cursor() -> void:
	"""Handle building placement cancellation from cursor (right-click)"""
	if awaiting_placement:
		# Refund the cost
		SettlementManager.deposit_resources(awaiting_placement.build_cost)
		print("Building placement cancelled by cursor, refunded: %s" % awaiting_placement.build_cost)
		
		# Clean up placement state
		awaiting_placement = null
