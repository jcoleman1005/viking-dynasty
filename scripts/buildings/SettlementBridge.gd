# res://scripts/buildings/SettlementBridge.gd
extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var end_of_year_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/WorldMap_Stub.tscn"

# --- New Game Configuration (Used when no save file exists) ---
@export_group("New Game Settings")
@export var start_gold: int = 1000
@export var start_wood: int = 500
@export var start_food: int = 100
@export var start_stone: int = 200
@export var start_population: int = 10
# -----------------------------------

# --- Default Assets (fallback) ---
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var default_end_of_year_popup: PackedScene = preload("res://ui/EndOfYear_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var restart_button: Button = $UI/RestartButton
@onready var start_raid_button: Button = $UI/StartRaidButton
@onready var storefront_ui: Control = $UI/Storefront_UI
@onready var building_cursor: Node2D = $BuildingCursor
@onready var debug_raid_button: Button = $UI/Storefront_UI/DebugRaidButton

# --- Local Node References ---
@onready var building_container: Node2D = $BuildingContainer
@onready var grid_manager: Node = $GridManager

# --- Worker & End Year UI ---
const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer
var end_of_year_popup: PanelContainer

# Buttons created in code
var manage_workers_button: Button
var end_year_button: Button 

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null


func _ready() -> void:
	_setup_default_resources()
	_initialize_settlement() 
	_setup_ui()
	_connect_signals()
	_setup_dynamic_ui() # Creates the buttons
	
	# --- TEST DATA INJECTION ---
	if not DynastyManager.current_jarl:
		Loggie.msg("--- INJECTING TEST DYNASTY DATA ---").domain("BUILDING").info()
		var test_jarl = DynastyTestDataGenerator.generate_test_dynasty()
		DynastyManager.current_jarl = test_jarl
		DynastyManager.jarl_stats_updated.emit(test_jarl)
	# ---------------------------
	
	if not DynastyManager.pending_raid_result.is_empty():
		_process_raid_return()
		
	storefront_ui.show()
	if end_of_year_popup:
		end_of_year_popup.hide()

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()

# --- DYNAMIC UI SETUP (Worker & End Year Buttons) ---
func _setup_dynamic_ui() -> void:
	# 1. Load the Worker UI Scene
	if ResourceLoader.exists(WORK_ASSIGNMENT_SCENE_PATH):
		var scene = load(WORK_ASSIGNMENT_SCENE_PATH)
		if scene:
			work_assignment_ui = scene.instantiate()
			add_child(work_assignment_ui)
			if work_assignment_ui.has_signal("assignments_confirmed"):
				work_assignment_ui.assignments_confirmed.connect(_on_worker_assignments_confirmed)
	
	# 2. Create "Manage Workers" Button (Top Left)
	manage_workers_button = Button.new()
	manage_workers_button.text = "Manage Workers"
	manage_workers_button.pressed.connect(_on_manage_workers_pressed)
	ui_layer.add_child(manage_workers_button)
	manage_workers_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	manage_workers_button.position.y += 60
	
	# 3. Create "End Year" Button (Bottom Right, above World Map)
	end_year_button = Button.new()
	end_year_button.text = "End Year"
	end_year_button.modulate = Color(1, 0.8, 0.8) # Light red tint to distinguish it
	end_year_button.pressed.connect(_on_end_year_pressed)
	ui_layer.add_child(end_year_button)
	
	# Anchor to Bottom Right
	end_year_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	# Offset it slightly so it doesn't overlap the "World Map" button
	end_year_button.position.y -= 60 
	end_year_button.position.x -= 20

func _on_manage_workers_pressed() -> void:
	if SettlementManager.has_current_settlement() and work_assignment_ui:
		work_assignment_ui.setup(SettlementManager.current_settlement)

func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
	Loggie.msg("SettlementBridge: Work assignments saved.").domain("BUILDING").info()
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.worker_assignments = assignments
		SettlementManager.save_settlement()

# --- UI MANAGEMENT ---

func close_all_ui() -> void:
	"""Closes all open UI windows for clean year transition."""
	var ui_closed = false
	
	# Close Dynasty UI (dynamically find it)
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui and dynasty_ui.visible:
		dynasty_ui.hide()
		ui_closed = true
		
	# Close Storefront UI
	if storefront_ui and storefront_ui.visible:
		storefront_ui.hide()
		ui_closed = true
		
	# Close Work Assignment UI
	if work_assignment_ui and work_assignment_ui.visible:
		work_assignment_ui.hide()
		ui_closed = true
	
	if ui_closed:
		Loggie.msg("SettlementBridge: All UI closed for year transition").domain("BUILDING").info()

# --- END YEAR LOGIC CHAIN ---

func _on_end_year_pressed() -> void:
	Loggie.msg("SettlementBridge: End Year button pressed.").domain("BUILDING").info()
	_start_end_year_sequence()

func _start_end_year_sequence() -> void:
	# Close all UI before starting year transition
	close_all_ui()
	
	if not is_instance_valid(end_of_year_popup):
		# Fallback if popup is missing
		Loggie.msg("SettlementBridge: Popup missing, triggering logic directly.").domain("BUILDING").info()
		_finalize_end_year({})
		return
		
	# 1. Calculate Income
	var payout = SettlementManager.calculate_payout()
	
	# 2. Show Popup (This pauses the flow until player clicks Collect)
	end_of_year_popup.display_payout(payout, "Year End Report")

func _on_payout_collected(payout: Dictionary) -> void:
	# 3. Deposit Resources
	SettlementManager.deposit_resources(payout)
	
	# 4. Finalize Logic
	_finalize_end_year(payout)
	
	# 5. Restore UI
	storefront_ui.show()

func _finalize_end_year(_payout: Dictionary) -> void:
	# 5. Trigger Dynasty Aging/Events
	Loggie.msg("SettlementBridge: Triggering DynastyManager.end_year()...").domain("BUILDING").info()
	DynastyManager.end_year()
	Loggie.msg("SettlementBridge: Year ended processing complete.").domain("BUILDING").info()

# ---------------------------------------------------

func _setup_default_resources() -> void:
	if not test_building_data: test_building_data = default_test_building
	if not raider_scene: raider_scene = load("res://scenes/units/EnemyVikingRaider.tscn")
	if not end_of_year_popup_scene: end_of_year_popup_scene = default_end_of_year_popup

func _clear_all_buildings() -> void:
	"""Completely clears all buildings from scene tree and resets grid state."""
	# 1. Clear all building instances from scene
	if is_instance_valid(building_container):
		for child in building_container.get_children():
			child.queue_free()
		# Wait a frame for queue_free() to complete
		await get_tree().process_frame
	
	# 2. Clear all units from scene
	if is_instance_valid(unit_container):
		for child in unit_container.get_children():
			child.queue_free()
		await get_tree().process_frame
	
	# 3. Reset grid state if available
	if is_instance_valid(grid_manager):
		# Reset AStarGrid2D to clear all solid points
		if "astar_grid" in grid_manager and grid_manager.astar_grid:
			var grid = grid_manager.astar_grid
			var region = grid.region
			# Clear all solid points
			for x in range(region.size.x):
				for y in range(region.size.y):
					var pos = Vector2i(x + region.position.x, y + region.position.y)
					grid.set_point_solid(pos, false)
			grid.update()
		
		# Reset territory tracking
		if "buildable_cells" in grid_manager:
			grid_manager.buildable_cells.clear()
		
		# Force visualizer redraw
		if grid_manager.has_method("queue_redraw_visualizer"):
			grid_manager.queue_redraw_visualizer()
	
	# 4. Reset state variables
	great_hall_instance = null
	game_is_over = false
	awaiting_placement = null
	
	Loggie.msg("SettlementBridge: All buildings and units cleared, grid reset for new game").domain("BUILDING").info()

func _initialize_settlement() -> void:
	# --- MODIFIED: Always create from Inspector Settings ---
	# This ensures that when a new game starts (no save file found),
	# we use the configured Start Gold/Wood and place the Great Hall.
	# Any pre-assigned resource in 'home_base_data' is ignored in favor of these settings.
	home_base_data = _create_default_settlement()
	
	# CRITICAL: Clear any existing buildings from the scene tree first
	await _clear_all_buildings()
	
	# Load (Will ignore this object if save file exists)
	SettlementManager.load_settlement(home_base_data)
	
	if is_instance_valid(grid_manager) and "astar_grid" in grid_manager:
		SettlementManager.register_active_scene_nodes(grid_manager.astar_grid, building_container, grid_manager)
	
	_spawn_placed_buildings()
	# Remove redundant emit - SettlementManager.load_settlement() already emits settlement_loaded

func _spawn_placed_buildings() -> void:
	if not SettlementManager.current_settlement: return
	for child in building_container.get_children(): child.queue_free()

	for building_entry in SettlementManager.current_settlement.placed_buildings:
		_spawn_single_building(building_entry, false) 

	for building_entry in SettlementManager.current_settlement.pending_construction_buildings:
		var b = _spawn_single_building(building_entry, false)
		if b:
			var progress = building_entry.get("progress", 0)
			if progress > 0:
				b.construction_progress = progress
				b.set_state(BaseBuilding.BuildingState.UNDER_CONSTRUCTION)
				if b.has_method("add_construction_progress"): b.add_construction_progress(0) 
			else:
				b.set_state(BaseBuilding.BuildingState.BLUEPRINT)
	
	if is_instance_valid(SettlementManager.active_astar_grid):
		SettlementManager.active_astar_grid.update()

func _spawn_single_building(entry: Dictionary, is_new: bool) -> BaseBuilding:
	var building_data: BuildingData = load(entry["resource_path"])
	if building_data:
		var new_building = SettlementManager.place_building(building_data, entry["grid_position"], is_new)
		if new_building and new_building.data.display_name == "Great Hall":
			_setup_great_hall(new_building)
		return new_building
	return null

func _create_default_settlement() -> SettlementData:
	var settlement = SettlementData.new()
	# Use exported values
	settlement.treasury = {
		"gold": start_gold, 
		"wood": start_wood, 
		"food": start_food, 
		"stone": start_stone
	}
	settlement.population_total = start_population
	settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
	
	# --- NEW: Auto-place Great Hall ---
	# Centered on 60x40 grid (approx 28,18 for 4x4 building)
	var great_hall_entry = {
		"resource_path": "res://data/buildings/GreatHall.tres",
		"grid_position": Vector2i(28, 18)
	}
	settlement.placed_buildings.append(great_hall_entry)
	# ----------------------------------
	
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

func _on_settlement_loaded(_settlement_data: SettlementData) -> void: pass
func _on_debug_raid_pressed() -> void:
	DynastyManager.is_defensive_raid = true
	EventBus.scene_change_requested.emit("raid_mission")

func _setup_great_hall(hall_instance: BaseBuilding) -> void:
	if not is_instance_valid(hall_instance): return
	great_hall_instance = hall_instance
	great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)

func _on_great_hall_destroyed(_building: BaseBuilding) -> void:
	game_is_over = true
	var label : Label = $UI/Label
	label.text = "YOU HAVE BEEN SACKED."
	restart_button.show()
	for enemy in unit_container.get_children(): enemy.queue_free()

func _on_restart_pressed() -> void: get_tree().reload_current_scene()

func _on_start_raid_pressed() -> void:
	if not SettlementManager.current_settlement: return
	
	# --- FIX: Check 'warbands', not 'garrisoned_units' ---
	if SettlementManager.current_settlement.warbands.is_empty():
		# Auto-recruit a fallback warband if the player has no army
		var default_unit_path = "res://data/units/Unit_PlayerRaider.tres"
		if ResourceLoader.exists(default_unit_path):
			var unit_data = load(default_unit_path) as UnitData
			if unit_data:
				SettlementManager.recruit_unit(unit_data)
				Loggie.msg("Debug: Auto-recruited fallback warband for raid.").domain("BUILDING").info()
	# -----------------------------------------------------

	if not world_map_scene_path.is_empty(): 
		EventBus.scene_change_requested.emit("world_map")
# --- Building Cursor Logic ---
func _on_building_ready_for_placement(building_data: BuildingData) -> void:
	awaiting_placement = building_data
	building_cursor.cell_size = grid_manager.cell_size
	building_cursor.set_building_preview(building_data)

func _on_building_placement_cancelled(building_data: BuildingData) -> void: pass

func _on_building_placement_completed() -> void:
	if awaiting_placement and SettlementManager.current_settlement:
		var snapped_grid_pos = Vector2i(building_cursor.global_position / grid_manager.cell_size)
		SettlementManager.place_building(awaiting_placement, snapped_grid_pos, true)
	awaiting_placement = null

func _on_building_placement_cancelled_by_cursor() -> void:
	if awaiting_placement:
		SettlementManager.deposit_resources(awaiting_placement.build_cost)
		awaiting_placement = null

func _on_building_right_clicked(building: BaseBuilding) -> void:
	if building_cursor.is_active: return
	var data = building.data
	var cost = data.build_cost
	SettlementManager.deposit_resources(cost)
	SettlementManager.remove_building(building)
	if SettlementManager.attempt_purchase(cost):
		EventBus.building_ready_for_placement.emit(data)

func _process_raid_return() -> void:
	var result = DynastyManager.pending_raid_result
	var outcome = result.get("outcome")
	var loot_summary = {}
	
	if outcome == "victory":
		var gold = result.get("gold_looted", 0)
		var bonus = 200 # Victory Bonus
		loot_summary["gold"] = gold + bonus
		loot_summary["population"] = randi_range(2, 4)
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Victory!")
			
	elif outcome == "retreat":
		var gold = result.get("gold_looted", 0)
		# No bonus, no population
		loot_summary["gold"] = gold
		
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Retreat\n(Loot Secured)")
			
	if not loot_summary.is_empty():
		SettlementManager.deposit_resources(loot_summary)
			
	DynastyManager.pending_raid_result.clear()
