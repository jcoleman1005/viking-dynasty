# res://scripts/buildings/SettlementBridge.gd
extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var end_of_year_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/MacroMap.tscn"

# --- REACTIVE DEBUG SETTINGS ---
# Using setters allows you to toggle these in the Remote Scene Tree at runtime!
@export_group("Loggie Debug Settings")
@export var show_ui_logs: bool = false:
	set(value):
		show_ui_logs = value
		if is_inside_tree(): # Prevent errors during initialization
			Loggie.set_domain_enabled("UI", value)
@export var show_settlement_logs: bool = false:
	set(value):
		show_settlement_logs = value
		if is_inside_tree():
			Loggie.set_domain_enabled("SETTLEMENT", value)
@export var show_building_logs: bool = false:
	set(value):
		show_building_logs = value
		if is_inside_tree():
			Loggie.set_domain_enabled("BUILDING", value)
@export var show_debug_logs: bool = true: ## General debug messages
	set(value):
		show_debug_logs = value
		if is_inside_tree():
			Loggie.set_domain_enabled("DEBUG", value)

# --- NEW: Civ Unit Data ---
@export var civilian_data: UnitData 

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
@onready var rts_controller: RTSController = $RTSController
# --- Worker & End Year UI ---
const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer
var end_of_year_popup: PanelContainer
var idle_warning_dialog: ConfirmationDialog

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null

func _ready() -> void:
	Loggie.set_domain_enabled("UI", false)
	Loggie.set_domain_enabled("SETTLEMENT", false)
	Loggie.set_domain_enabled("BUILDING", false)
	Loggie.set_domain_enabled("DEBUG", false)
	
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
	# --- DEBUG CHECK ---
	var controller = get_node_or_null("RTSController")
	if controller:
		print("DIAGNOSTIC: Checking RTSController connections...")
		
		# Check if the controller is actually listening
		if not EventBus.select_command.is_connected(controller._on_select_command):
			print("DIAGNOSTIC: RTSController was asleep! Forcing connections now.")
			
			# Manually wire up the brain
			EventBus.select_command.connect(controller._on_select_command)
			EventBus.move_command.connect(controller._on_move_command)
			EventBus.attack_command.connect(controller._on_attack_command)
			EventBus.interact_command.connect(controller._on_interact_command)
			
			# Inject dependencies manually just in case
			controller.control_groups = { 1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: [], 8: [], 9: [], 0: [] }
			
			print("DIAGNOSTIC: RTSController manually jump-started.")
		else:
			print("DIAGNOSTIC: RTSController is already connected.")
			
func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()

func _connect_signals() -> void:
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	# --- NEW: Sync physical units to data ---
	EventBus.settlement_loaded.connect(_sync_villagers)
	
	EventBus.building_ready_for_placement.connect(_on_building_ready_for_placement)
	EventBus.building_placement_cancelled.connect(_on_building_placement_cancelled)
	EventBus.building_right_clicked.connect(_on_building_right_clicked)
	EventBus.dynasty_view_requested.connect(_toggle_dynasty_view)
	EventBus.end_year_requested.connect(_on_end_year_pressed)
	
	if building_cursor:
		building_cursor.placement_completed.connect(_on_building_placement_completed)
		building_cursor.placement_cancelled.connect(_on_building_placement_cancelled_by_cursor)

# --- UI SETUP ---
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
	
	# Idle Warning Dialog
	idle_warning_dialog = ConfirmationDialog.new()
	idle_warning_dialog.title = "Idle Villagers"
	idle_warning_dialog.ok_button_text = "End Year Anyway"
	idle_warning_dialog.cancel_button_text = "Select Idle Worker"
	
	idle_warning_dialog.confirmed.connect(_start_end_year_sequence)
	
	# Map the cancel button to finding an idle worker
	idle_warning_dialog.canceled.connect(func():
		if storefront_ui and storefront_ui.has_method("_select_idle_worker"):
			storefront_ui._select_idle_worker()
	)
	
	add_child(idle_warning_dialog)

# --- WORKER ASSIGNMENT LOGIC ---
func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
	Loggie.msg("SettlementBridge: Work assignments saved.").domain("BUILDING").info()
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.worker_assignments = assignments
		SettlementManager.save_settlement()

# --- END YEAR LOGIC CHAIN ---

func _on_end_year_pressed() -> void:
	Loggie.msg("SettlementBridge: End Year requested.").domain("BUILDING").info()
	
	# Check for Idles
	var idle_p = SettlementManager.get_idle_peasants()
	var idle_t = SettlementManager.get_idle_thralls()
	var total_idle = idle_p + idle_t
	
	if total_idle > 0:
		idle_warning_dialog.dialog_text = "You have %d idle workers (Citizens/Thralls).\nUnassigned workers produce nothing.\n\nEnd year anyway?" % total_idle
		idle_warning_dialog.popup_centered()
	else:
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
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui: dynasty_ui.hide()
	if work_assignment_ui: work_assignment_ui.hide()

# --- SETTLEMENT LOGIC ---

func _setup_default_resources() -> void:
	if not test_building_data: test_building_data = default_test_building
	if not raider_scene: raider_scene = load("res://scenes/units/VikingRaider.tscn")
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
	# Handled by _sync_villagers
	pass

func _setup_great_hall(hall_instance: BaseBuilding) -> void:
	if not is_instance_valid(hall_instance): return
	great_hall_instance = hall_instance
	great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)

func _on_great_hall_destroyed(_building: BaseBuilding) -> void:
	game_is_over = true
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
	
	# --- NEW: Process Returning Bondi ---
	if SettlementManager.current_settlement:
		var warbands_to_disband: Array[WarbandData] = []
		
		for warband in SettlementManager.current_settlement.warbands:
			if warband.is_bondi:
				# Refund Survivors
				if warband.current_manpower > 0:
					SettlementManager.current_settlement.population_peasants += warband.current_manpower
					Loggie.msg("Bondi disbanded. %d returned to work." % warband.current_manpower).domain(LogDomains.SETTLEMENT).info()
				
				warbands_to_disband.append(warband)
		
		# Cleanup
		for wb in warbands_to_disband:
			SettlementManager.current_settlement.warbands.erase(wb)
	# -------------------------------------

	var grade = result.get("victory_grade", "Standard")
	var loot_summary = {}
	
	var xp_gain = 0
	if outcome == "victory": 
		xp_gain = 50
		if grade == "Decisive": xp_gain = 75
		elif grade == "Pyrrhic": xp_gain = 25
	elif outcome == "retreat": 
		xp_gain = 20
	
	if SettlementManager.current_settlement and xp_gain > 0:
		for warband in SettlementManager.current_settlement.warbands:
			if not warband.is_wounded:
				warband.experience += xp_gain

	if outcome == "victory":
		var gold = result.get("gold_looted", 0)
		var difficulty = DynastyManager.current_raid_difficulty
		var bonus = 200 + (difficulty * 50)
		
		# Decisive Bonus
		if grade == "Decisive":
			bonus += 100
			
		loot_summary["gold"] = gold + bonus
		loot_summary["population"] = randi_range(2, 4) * difficulty
		
		# --- GDD: Warlord Progression ---
		var jarl = DynastyManager.get_current_jarl()
		if jarl:
			jarl.offensive_wins += 1
			jarl.battles_won += 1
			jarl.successful_raids += 1
			
			# Check Warlord Trait
			if jarl.has_trait("Warlord") and grade == "Decisive":
				var refund = 1 # +1 per Unifier level (simplified to 1 for now)
				DynastyManager.current_jarl.current_authority = min(
					DynastyManager.current_jarl.current_authority + refund, 
					DynastyManager.current_jarl.max_authority
				)
				Loggie.msg("Warlord Momentum: Authority Refunded!").domain(LogDomains.DYNASTY).info()
				
			# Check Warlord Acquisition
			if jarl.offensive_wins >= 5 and not jarl.has_trait("Warlord"):
				# In a real impl, we'd load the trait resource. For now, string check logic is fine.
				# We can emit an event or just log it.
				Loggie.msg("Jarl has proven themselves a Warlord! (Trait pending impl)").domain(LogDomains.DYNASTY).warn()
			
			DynastyManager.jarl_stats_updated.emit(jarl)
		# --------------------------------
		
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Victory! (%s)" % grade)
			
	elif outcome == "retreat":
		var gold = result.get("gold_looted", 0)
		loot_summary["gold"] = gold
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Retreat\n(Loot Secured)")
			
	if not loot_summary.is_empty():
		SettlementManager.deposit_resources(loot_summary)
			
	DynastyManager.pending_raid_result.clear()
# --- PHYSICAL VILLAGER SYNC ---

func _sync_villagers(_data: SettlementData = null) -> void:
	if not SettlementManager.has_current_settlement(): return
	
	var idle_count = SettlementManager.get_idle_peasants()
	# Count existing civilian units
	var active_civilians = []
	if unit_container:
		for child in unit_container.get_children():
			if child.is_in_group("civilians"):
				active_civilians.append(child)
	
	var current_count = active_civilians.size()
	var diff = idle_count - current_count
	
	if diff > 0:
		_spawn_civilians(diff)
	elif diff < 0:
		_despawn_civilians(abs(diff), active_civilians)

func _spawn_civilians(count: int) -> void:
	Loggie.msg("Attempting to spawn %d civilians..." % count).domain("SETTLEMENT").info()
	
	# 1. Validate Data exists
	if not civilian_data:
		Loggie.msg("FAILED: No 'civilian_data' assigned in Inspector!").domain("SETTLEMENT").error()
		return

	var spawn_origin = Vector2.ZERO
	if great_hall_instance:
		spawn_origin = great_hall_instance.global_position
	
	# 2. Load the Scene safely using the new helper
	var scene_ref = civilian_data.load_scene()
	if not scene_ref:
		# The error is already logged inside load_scene(), but we log here to confirm flow stop
		Loggie.msg("FAILED: load_scene() returned null.").domain("SETTLEMENT").error()
		return
	
	Loggie.msg("Scene loaded successfully. Instantiating %d units..." % count).domain("SETTLEMENT").info()
	
	for i in range(count):
		var civ = scene_ref.instantiate()
		
		# 3. Inject Data (This re-establishes the link)
		civ.data = civilian_data
		
		civ.position = spawn_origin + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		unit_container.add_child(civ)
		# Register the new unit with the RTS Controller so it can be selected!
		if is_instance_valid(rts_controller):
			rts_controller.add_unit_to_group(civ)
		if civ.has_method("command_move_to"):
			civ.command_move_to(civ.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))

func _despawn_civilians(count: int, current_list: Array) -> void:
	for i in range(count):
		if i < current_list.size():
			var civ = current_list[i]
			if is_instance_valid(civ):
				if civ.has_method("die_without_event"):
					civ.die_without_event()
				else:
					civ.queue_free()

func _toggle_dynasty_view() -> void:
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui:
		if dynasty_ui.visible:
			dynasty_ui.hide()
		else:
			if storefront_ui: storefront_ui.call("_close_all_windows") 
			dynasty_ui.show()
			Loggie.msg("Opening Dynasty View").domain("UI").info()
	else:
		Loggie.msg("Error: Dynasty_UI node not found in SettlementBridge/UI").domain("UI").error()
