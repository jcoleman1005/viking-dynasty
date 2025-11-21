# res://scripts/buildings/SettlementBridge.gd
extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var end_of_year_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/MacroMap.tscn"

# --- New Game Configuration ---
@export_group("New Game Settings")
@export var start_gold: int = 1000
@export var start_wood: int = 500
@export var start_food: int = 100
@export var start_stone: int = 200
@export var start_population: int = 10

# --- Default Assets ---
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var default_end_of_year_popup: PackedScene = preload("res://ui/EndOfYear_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var storefront_ui: Control = $UI/Storefront_UI
@onready var building_cursor: Node2D = $BuildingCursor

# --- Local Node References ---
@onready var building_container: Node2D = $BuildingContainer
@onready var grid_manager: Node = $GridManager

# --- Worker & End Year UI ---
const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer
var end_of_year_popup: PanelContainer
var thrall_tags: Array[Control] = []
var is_managing_thralls: bool = false

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null

func _ready() -> void:
	Loggie.set_domain_enabled("UI", true)
	Loggie.set_domain_enabled("SETTLEMENT", true)
	Loggie.set_domain_enabled("BUILDING", true)
	Loggie.set_domain_enabled("DEBUG", true)
	
	_setup_default_resources()
	_initialize_settlement() 
	_setup_ui()
	_connect_signals()
	
	# --- TEST DATA INJECTION ---
	if not DynastyManager.current_jarl:
		var test_jarl = DynastyTestDataGenerator.generate_test_dynasty()
		DynastyManager.current_jarl = test_jarl
		DynastyManager.jarl_stats_updated.emit(test_jarl)
	
	if not DynastyManager.pending_raid_result.is_empty():
		_process_raid_return()
		
	if storefront_ui: storefront_ui.show()
	if end_of_year_popup: end_of_year_popup.hide()

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()

func _connect_signals() -> void:
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	EventBus.building_ready_for_placement.connect(_on_building_ready_for_placement)
	EventBus.building_placement_cancelled.connect(_on_building_placement_cancelled)
	EventBus.building_right_clicked.connect(_on_building_right_clicked)
	EventBus.worker_management_toggled.connect(_toggle_thrall_management)
	EventBus.dynasty_view_requested.connect(_toggle_dynasty_view)
	# --- NEW: Listen for End Year Request ---
	EventBus.end_year_requested.connect(_on_end_year_pressed)
	# ----------------------------------------
	
	if building_cursor:
		building_cursor.placement_completed.connect(_on_building_placement_completed)
		building_cursor.placement_cancelled.connect(_on_building_placement_cancelled_by_cursor)

# --- UI SETUP (Cleaned Up) ---
func _setup_ui() -> void:
	# End Year Popup
	end_of_year_popup = end_of_year_popup_scene.instantiate()
	ui_layer.add_child(end_of_year_popup)
	end_of_year_popup.collect_button_pressed.connect(_on_payout_collected)
	
	# Worker UI
	if ResourceLoader.exists(WORK_ASSIGNMENT_SCENE_PATH):
		var scene = load(WORK_ASSIGNMENT_SCENE_PATH)
		if scene:
			work_assignment_ui = scene.instantiate()
			add_child(work_assignment_ui)
			if work_assignment_ui.has_signal("assignments_confirmed"):
				work_assignment_ui.assignments_confirmed.connect(_on_worker_assignments_confirmed)
	
	# REMOVED: Old dynamic button creation code

# --- WORKER ASSIGNMENT LOGIC ---
# Note: Since we removed the dedicated "Manage Workers" button, 
# you might want to add a button for this in the Storefront later.
# For now, we can auto-trigger it on End Year if needed, or let the Storefront handle it.
func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
	Loggie.msg("SettlementBridge: Work assignments saved.").domain("BUILDING").info()
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.worker_assignments = assignments
		SettlementManager.save_settlement()

# --- END YEAR LOGIC CHAIN ---

func _on_end_year_pressed() -> void:
	Loggie.msg("SettlementBridge: End Year requested.").domain("BUILDING").info()
	_start_end_year_sequence()

func _start_end_year_sequence() -> void:
	_close_all_popups()
	
	if not is_instance_valid(end_of_year_popup):
		_finalize_end_year({})
		return
		
	# 1. Calculate Income
	var payout = SettlementManager.calculate_payout()
	
	# 2. Show Popup
	end_of_year_popup.display_payout(payout, "Year End Report")

func _on_payout_collected(payout: Dictionary) -> void:
	# 3. Deposit Resources
	SettlementManager.deposit_resources(payout)
	# 4. Finalize Logic
	_finalize_end_year(payout)
	# 5. Restore UI
	if storefront_ui: storefront_ui.show()

func _finalize_end_year(_payout: Dictionary) -> void:
	DynastyManager.end_year()

func _close_all_popups() -> void:
	# Hide other UI if open
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui: dynasty_ui.hide()
	if work_assignment_ui: work_assignment_ui.hide()

# --- SETTLEMENT LOGIC (Unchanged) ---

func _setup_default_resources() -> void:
	if not test_building_data: test_building_data = default_test_building
	if not raider_scene: raider_scene = load("res://scenes/units/EnemyVikingRaider.tscn")
	if not end_of_year_popup_scene: end_of_year_popup_scene = default_end_of_year_popup

func _clear_all_buildings() -> void:
	if is_instance_valid(building_container):
		for child in building_container.get_children(): child.queue_free()
		await get_tree().process_frame
	
	if is_instance_valid(unit_container):
		for child in unit_container.get_children(): child.queue_free()
		await get_tree().process_frame
	
	if is_instance_valid(grid_manager):
		if "astar_grid" in grid_manager and grid_manager.astar_grid:
			var grid = grid_manager.astar_grid
			var region = grid.region
			for x in range(region.size.x):
				for y in range(region.size.y):
					var pos = Vector2i(x + region.position.x, y + region.position.y)
					grid.set_point_solid(pos, false)
			grid.update()
		if "buildable_cells" in grid_manager: grid_manager.buildable_cells.clear()
		if grid_manager.has_method("queue_redraw_visualizer"): grid_manager.queue_redraw_visualizer()
	
	great_hall_instance = null
	game_is_over = false
	awaiting_placement = null

func _initialize_settlement() -> void:
	home_base_data = _create_default_settlement()
	await _clear_all_buildings()
	SettlementManager.load_settlement(home_base_data)
	if is_instance_valid(grid_manager) and "astar_grid" in grid_manager:
		SettlementManager.register_active_scene_nodes(grid_manager.astar_grid, building_container, grid_manager)
	_spawn_placed_buildings()

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
	settlement.treasury = { "gold": start_gold, "wood": start_wood, "food": start_food, "stone": start_stone }
	settlement.population_peasants = start_population
	settlement.resource_path = "res://data/settlements/home_base_fixed.tres"
	var great_hall_entry = { "resource_path": "res://data/buildings/GreatHall.tres", "grid_position": Vector2i(28, 18) }
	settlement.placed_buildings.append(great_hall_entry)
	return settlement

func _on_settlement_loaded(_settlement_data: SettlementData) -> void:
	# If we are currently in "Management Mode", we must refresh the tags
	# to show the new worker counts immediately.
	if is_managing_thralls:
		_spawn_thrall_tags()

func _setup_great_hall(hall_instance: BaseBuilding) -> void:
	if not is_instance_valid(hall_instance): return
	great_hall_instance = hall_instance
	great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)

func _on_great_hall_destroyed(_building: BaseBuilding) -> void:
	game_is_over = true
	# You can trigger a game over screen here
	if is_instance_valid(unit_container):
		for enemy in unit_container.get_children(): enemy.queue_free()

# --- BUILDING CURSOR LOGIC ---
func _on_building_ready_for_placement(building_data: BuildingData) -> void:
	awaiting_placement = building_data
	building_cursor.cell_size = grid_manager.cell_size
	building_cursor.set_building_preview(building_data)

func _on_building_placement_cancelled(_building_data: BuildingData) -> void: pass

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
	
	var xp_gain = 0
	if outcome == "victory": xp_gain = 50
	elif outcome == "retreat": xp_gain = 20
	
	if SettlementManager.current_settlement and xp_gain > 0:
		for warband in SettlementManager.current_settlement.warbands:
			if not warband.is_wounded:
				warband.experience += xp_gain

	if outcome == "victory":
		var gold = result.get("gold_looted", 0)
		var difficulty = DynastyManager.current_raid_difficulty
		var bonus = 200 + (difficulty * 50)
		loot_summary["gold"] = gold + bonus
		loot_summary["population"] = randi_range(2, 4) * difficulty
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Victory!")
			
	elif outcome == "retreat":
		var gold = result.get("gold_looted", 0)
		loot_summary["gold"] = gold
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Retreat\n(Loot Secured)")
			
	if not loot_summary.is_empty():
		SettlementManager.deposit_resources(loot_summary)
			
	DynastyManager.pending_raid_result.clear()
# --- THRALL MANAGEMENT UI ---

func _input(event: InputEvent) -> void:
	# 1. Existing Hotkey (Toggle Management)
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_toggle_thrall_management()

	# 2. Debug Clicker (Find Invisible Walls)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hovered_control = get_viewport().gui_get_hovered_control()
		
		if hovered_control:
			Loggie.msg("🛑 CLICK BLOCKED BY: %s" % hovered_control.name).domain("DEBUG").warn()
			Loggie.msg("   Path: %s" % hovered_control.get_path()).domain("DEBUG").warn()
			
			# Check Filter (0 = Stop, 1 = Pass, 2 = Ignore)
			var filter_name = "STOP"
			if hovered_control.mouse_filter == Control.MOUSE_FILTER_PASS: filter_name = "PASS"
			elif hovered_control.mouse_filter == Control.MOUSE_FILTER_IGNORE: filter_name = "IGNORE"
			
			Loggie.msg("   Mouse Filter: %s (%d)" % [filter_name, hovered_control.mouse_filter]).domain("DEBUG").warn()
		else:
			Loggie.msg("✅ UI is clean. Click passed to World.").domain("DEBUG").info()

func _toggle_thrall_management() -> void:
	is_managing_thralls = !is_managing_thralls
	
	if is_managing_thralls:
		_spawn_thrall_tags()
		Loggie.msg("Thrall Management: ON").domain("UI").info()
	else:
		_clear_thrall_tags()
		Loggie.msg("Thrall Management: OFF").domain("UI").info()

func _spawn_thrall_tags() -> void:
	_clear_thrall_tags()
	
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	# 1. ACTIVE BUILDINGS (Existing Loop)
	for i in range(settlement.placed_buildings.size()):
		var entry = settlement.placed_buildings[i]
		var data = load(entry["resource_path"])
		
		if data is EconomicBuildingData:
			_create_tag(i, entry, data, false)

	# 2. PENDING BUILDINGS (New Loop)
	for i in range(settlement.pending_construction_buildings.size()):
		var entry = settlement.pending_construction_buildings[i]
		var data = load(entry["resource_path"])
		
		# All buildings need construction workers, not just Economic ones.
		if data: 
			_create_tag(i, entry, data, true)

# Helper to avoid duplicate code
func _create_tag(index: int, entry: Dictionary, data: BuildingData, is_pending: bool) -> void:
	var tag = preload("res://ui/components/WorkerTag.tscn").instantiate()
	building_container.add_child(tag)
	tag.z_index = 100
	
	var world_building = _find_building_instance_by_entry(entry) # Helper update needed
	if world_building:
		tag.global_position = world_building.global_position + Vector2(-60, -100)
		
		# Determine caps
		var p_cap = 0
		var t_cap = 0
		
		if is_pending:
			# Construction Capacity (e.g. 5 builders max)
			p_cap = data.base_labor_capacity
			t_cap = data.base_labor_capacity
		elif data is EconomicBuildingData:
			# Production Capacity
			p_cap = data.peasant_capacity
			t_cap = data.thrall_capacity
			
		tag.setup(
			index, 
			entry.get("peasant_count", 0), p_cap,
			entry.get("thrall_count", 0), t_cap,
			is_pending
		)
		thrall_tags.append(tag)

func _clear_thrall_tags() -> void:
	for tag in thrall_tags:
		tag.queue_free()
	thrall_tags.clear()

# --- THE HELPER YOU NEEDED ---
func _find_building_instance_by_index(index: int) -> BaseBuilding:
	if not SettlementManager.current_settlement: return null
	var entry = SettlementManager.current_settlement.placed_buildings[index]
	
	# entry["grid_position"] might be Vector2 or Vector2i depending on save version
	var target_grid_pos = Vector2i(entry["grid_position"])
	
	for child in building_container.get_children():
		if child is BaseBuilding and child.data:
			var cell_size = grid_manager.cell_size
			# Calculate grid pos of this child
			var size_offset = Vector2(child.data.grid_size) * cell_size / 2.0
			var top_left = child.global_position - size_offset
			# Add small epsilon to avoid float errors
			var child_grid_pos = Vector2i(round((top_left.x + 1) / cell_size), round((top_left.y + 1) / cell_size))
			
			if child_grid_pos == target_grid_pos:
				return child
	return null
func _toggle_dynasty_view() -> void:
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui:
		if dynasty_ui.visible:
			dynasty_ui.hide()
		else:
			# Close other windows to prevent clutter
			if storefront_ui: storefront_ui.call("_close_all_windows") 
			_clear_thrall_tags()
			is_managing_thralls = false
			
			dynasty_ui.show()
			Loggie.msg("Opening Dynasty View").domain("UI").info()
	else:
		Loggie.msg("Error: Dynasty_UI node not found in SettlementBridge/UI").domain("UI").error()
func _find_building_instance_by_entry(entry: Dictionary) -> BaseBuilding:
	var target_pos = Vector2i(entry["grid_position"])
	
	for child in building_container.get_children():
		if child is BaseBuilding and child.data:
			var cell_size = grid_manager.cell_size
			var size_pixels = Vector2(child.data.grid_size) * cell_size
			var top_left = child.global_position - (size_pixels / 2.0)
			
			var child_grid_pos = Vector2i(
				round(top_left.x / cell_size),
				round(top_left.y / cell_size)
			)
			
			if child_grid_pos == target_pos:
				return child
	return null
