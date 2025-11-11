# res://scripts/buildings/SettlementBridge.gd
#
# --- MODIFIED: Phase 1.3 Integration ---
# Now delegates save logic to SettlementManager.place_building

extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var end_of_year_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/WorldMap_Stub.tscn"

# --- Default Assets (fallback) ---
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var default_raider_scene: PackedScene 
var default_end_of_year_popup: PackedScene = preload("res://ui/EndOfYear_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var restart_button: Button = $UI/RestartButton
@onready var start_raid_button: Button = $UI/StartRaidButton
@onready var storefront_ui: Control = $UI/Storefront_UI
@onready var building_cursor: Node2D = $BuildingCursor
@onready var instruction_label: Label = $UI/Label
var end_of_year_popup: PanelContainer

# --- Debug Button ---
@onready var debug_raid_button: Button = $UI/Storefront_UI/DebugRaidButton

# --- Local Node References ---
@onready var building_container: Node2D = $BuildingContainer
@onready var grid_manager: Node = $GridManager

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null


func _ready() -> void:
	_setup_default_resources()
	_initialize_settlement() 
	_setup_ui()
	_connect_signals()
	
	storefront_ui.show()
	if end_of_year_popup:
		end_of_year_popup.hide()
	
	# Show instruction popup on scene load
	_show_instruction_popup()

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()

func _setup_default_resources() -> void:
	if not test_building_data:
		test_building_data = default_test_building
	if not raider_scene:
		raider_scene = load("res://scenes/units/EnemyVikingRaider.tscn")
	if not end_of_year_popup_scene: 
		end_of_year_popup_scene = default_end_of_year_popup

func _initialize_settlement() -> void:
	"""Initialize data, then grid, then spawn buildings."""
	if not home_base_data:
		home_base_data = _create_default_settlement()
		print("SettlementBridge: Created default settlement data")
	else:
		if not home_base_data is SettlementData:
			push_warning("SettlementBridge: Inspector data is not SettlementData, creating default")
			home_base_data = _create_default_settlement()
	
	if home_base_data and (not home_base_data.resource_path or home_base_data.resource_path.is_empty()):
		home_base_data.resource_path = "res://data/settlements/home_base_fixed.tres"
	
	SettlementManager.load_settlement(home_base_data)
	
	if not is_instance_valid(grid_manager) or not "astar_grid" in grid_manager:
		push_error("SettlementBridge: GridManager node is missing or invalid!")
		return
	var local_astar_grid = grid_manager.astar_grid
	
	SettlementManager.register_active_scene_nodes(local_astar_grid, building_container, grid_manager)
	
	_spawn_placed_buildings()
	
	EventBus.settlement_loaded.emit(home_base_data)


func _spawn_placed_buildings() -> void:
	"""
	Instantiates ACTIVE buildings from the loaded settlement data.
	Also instantiates PENDING buildings (Blueprints).
	"""
	if not SettlementManager.current_settlement:
		return
	
	for child in building_container.get_children():
		child.queue_free()

	# 1. Spawn Active Buildings
	for building_entry in SettlementManager.current_settlement.placed_buildings:
		_spawn_single_building(building_entry, false) # False = Not new, Active

	# 2. Spawn Pending Blueprints (New for Phase 1.3)
	for building_entry in SettlementManager.current_settlement.pending_construction_buildings:
		var b = _spawn_single_building(building_entry, false)
		if b:
			b.set_state(BaseBuilding.BuildingState.BLUEPRINT)
			# Restore progress if we tracked it
			if "progress" in building_entry:
				b.construction_progress = building_entry["progress"]
	
	# Update grid
	if is_instance_valid(SettlementManager.active_astar_grid):
		SettlementManager.active_astar_grid.update()
	
	print("SettlementBridge: Settlement restored.")

func _spawn_single_building(entry: Dictionary, is_new: bool) -> BaseBuilding:
	var building_res_path: String = entry["resource_path"]
	var grid_pos: Vector2i = entry["grid_position"]
	
	var building_data: BuildingData = load(building_res_path)
	if building_data:
		# We use is_new_construction = false here because we are loading data,
		# not creating *new* data entries.
		var new_building = SettlementManager.place_building(building_data, grid_pos, is_new)
		
		if new_building and new_building.data.display_name == "Great Hall":
			_setup_great_hall(new_building)
		
		return new_building
	else:
		push_error("Failed to load building resource from path: %s" % building_res_path)
		return null


func _create_default_settlement() -> SettlementData:
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 1000, "wood": 500, "food": 100, "stone": 200}
	settlement.placed_buildings = []
	settlement.pending_construction_buildings = [] # Initialize new list
	settlement.garrisoned_units = {}
	settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
	return settlement

func _setup_ui() -> void:
	end_of_year_popup = end_of_year_popup_scene.instantiate()
	ui_layer.add_child(end_of_year_popup)
	end_of_year_popup.collect_button_pressed.connect(_on_payout_collected)
	storefront_ui.hide()

func _connect_signals() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	start_raid_button.pressed.connect(_on_start_raid_pressed)
	
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	EventBus.building_ready_for_placement.connect(_on_building_ready_for_placement)
	EventBus.building_placement_cancelled.connect(_on_building_placement_cancelled)
	EventBus.building_right_clicked.connect(_on_building_right_clicked)
	
	if building_cursor:
		building_cursor.placement_completed.connect(_on_building_placement_completed)
		building_cursor.placement_cancelled.connect(_on_building_placement_cancelled_by_cursor)

	if is_instance_valid(debug_raid_button):
		debug_raid_button.pressed.connect(_on_debug_raid_pressed)

func _on_settlement_loaded(_settlement_data: SettlementData) -> void:
	pass

func _on_debug_raid_pressed() -> void:
	print("DEBUG: Forcing defensive raid mission!")
	DynastyManager.is_defensive_raid = true
	EventBus.scene_change_requested.emit("raid_mission")

func _on_payout_collected(payout: Dictionary) -> void:
	SettlementManager.deposit_resources(payout)
	storefront_ui.show()

func _setup_great_hall(hall_instance: BaseBuilding) -> void:
	if not is_instance_valid(hall_instance):
		return
	great_hall_instance = hall_instance
	great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)

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

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_start_raid_pressed() -> void:
	if not SettlementManager.current_settlement:
		return
	
	if SettlementManager.current_settlement.garrisoned_units.is_empty():
		var test_unit_path = "res://data/units/EnemyVikingRaider_Data.tres"
		SettlementManager.current_settlement.garrisoned_units[test_unit_path] = 2
		SettlementManager.save_settlement()
	
	if not world_map_scene_path.is_empty():
		EventBus.scene_change_requested.emit("world_map")

# --- Instruction Popup Animation ---

func _show_instruction_popup() -> void:
	"""Create a smooth popup animation for the instruction label."""
	if not instruction_label:
		return
	
	# Create background panel for the popup
	_create_popup_background()
	
	# Set initial styling and position
	instruction_label.modulate = Color(1.0, 1.0, 1.0, 0.0)  # Start transparent
	instruction_label.scale = Vector2(0.9, 0.9)  # Start slightly smaller
	instruction_label.z_index = 101  # Ensure it's on top of background
	
	# Create a single tween chain for the entire animation sequence
	var tween: Tween = create_tween()
	
	# Phase 1: Fade in and scale up (0.6 seconds)
	tween.parallel().tween_property(instruction_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)
	tween.parallel().tween_property(instruction_label, "scale", Vector2(1.0, 1.0), 0.6)
	
	# Phase 2: Wait/display time (3.0 seconds)
	tween.tween_interval(3.0)
	
	# Phase 3: Fade out (0.8 seconds)
	tween.parallel().tween_property(instruction_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.8)
	
	# Phase 4: Reset properties when done
	tween.tween_callback(_reset_instruction_label)

var popup_background: Panel = null

func _create_popup_background() -> void:
	"""Create a background panel behind the instruction label."""
	if popup_background:
		popup_background.queue_free()
	
	popup_background = Panel.new()
	popup_background.name = "InstructionPopupBackground"
	
	# Position it behind the label with some padding
	var label_rect: Rect2 = instruction_label.get_rect()
	var padding: float = 20.0
	
	popup_background.position = Vector2(
		instruction_label.position.x - padding,
		instruction_label.position.y - padding
	)
	popup_background.size = Vector2(
		label_rect.size.x + padding * 2,
		label_rect.size.y + padding * 2
	)
	
	# Set z-index to be behind the label but above other UI
	popup_background.z_index = 100
	
	# Style the background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.9)  # Dark semi-transparent background
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_color = Color(0.6, 0.8, 1.0, 0.8)  # Light blue border
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	
	popup_background.add_theme_stylebox_override("panel", style_box)
	
	# Start invisible for animation
	popup_background.modulate = Color(1.0, 1.0, 1.0, 0.0)
	
	# Add to UI layer
	ui_layer.add_child(popup_background)
	
	# Animate the background alongside the label
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(popup_background, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)
	bg_tween.tween_interval(3.0)
	bg_tween.tween_property(popup_background, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.8)
	bg_tween.tween_callback(_cleanup_popup_background)

func _cleanup_popup_background() -> void:
	"""Remove the popup background after animation."""
	if popup_background:
		popup_background.queue_free()
		popup_background = null

func _reset_instruction_label() -> void:
	"""Reset the instruction label to its default state."""
	if instruction_label:
		instruction_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		instruction_label.scale = Vector2(1.0, 1.0)
		instruction_label.z_index = 0

# --- Building Cursor System Functions ---

func _on_building_ready_for_placement(building_data: BuildingData) -> void:
	awaiting_placement = building_data
	building_cursor.cell_size = grid_manager.cell_size
	building_cursor.set_building_preview(building_data)

func _on_building_placement_cancelled(building_data: BuildingData) -> void:
	print("Building placement cancelled: %s" % building_data.display_name)

func _on_building_placement_completed() -> void:
	"""
	Updated for Phase 1.3: Calls place_building with is_new_construction=true.
	"""
	if awaiting_placement and SettlementManager.current_settlement:
		var snapped_grid_pos = Vector2i(building_cursor.global_position / grid_manager.cell_size)
		
		print("SettlementBridge: Placing NEW blueprint for %s at %s" % [awaiting_placement.display_name, snapped_grid_pos])
		
		# --- CRITICAL FIX IS HERE ---
		# We MUST pass 'true' as the 3rd argument. 
		# true = New Construction (Blueprint)
		# false (default) = Existing Building (Active)
		SettlementManager.place_building(awaiting_placement, snapped_grid_pos, true)
		# ----------------------------
	
	awaiting_placement = null

func _on_building_placement_cancelled_by_cursor() -> void:
	if awaiting_placement:
		SettlementManager.deposit_resources(awaiting_placement.build_cost)
		awaiting_placement = null

func _on_building_right_clicked(building: BaseBuilding) -> void:
	# Move/Sell logic
	if building_cursor.is_active:
		return
		
	print("SettlementBridge: Move requested for %s" % building.data.display_name)
	
	var data = building.data
	var cost = data.build_cost
	
	# Refund
	SettlementManager.deposit_resources(cost)
	
	# Remove (Manager handles data removal)
	SettlementManager.remove_building(building)
	
	# Re-buy
	if SettlementManager.attempt_purchase(cost):
		EventBus.building_ready_for_placement.emit(data)
