# res://scripts/buildings/SettlementBridge.gd
extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var end_of_year_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/MacroMap.tscn"

# --- REACTIVE DEBUG SETTINGS ---
@export_group("Loggie Debug Settings")
@export var show_ui_logs: bool = false:
	set(value):
		show_ui_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("UI", value)
@export var show_settlement_logs: bool = false:
	set(value):
		show_settlement_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("SETTLEMENT", value)
@export var show_building_logs: bool = false:
	set(value):
		show_building_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("BUILDING", value)
@export var show_debug_logs: bool = true:
	set(value):
		show_debug_logs = value
		if is_inside_tree(): Loggie.set_domain_enabled("DEBUG", value)
@export var show_raid_logs: bool = true: # Set default to true if you want it on now
	set(value):
		show_raid_logs = value
		# LogDomains.RAID is defined as "RAID" in your autoload
		if is_inside_tree(): Loggie.set_domain_enabled(LogDomains.RAID, value)
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
@onready var unit_spawner: UnitSpawner = $UnitSpawner

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
	Loggie.set_domain_enabled("UI", show_ui_logs)
	Loggie.set_domain_enabled("SETTLEMENT", show_settlement_logs)
	Loggie.set_domain_enabled("BUILDING", show_building_logs)
	Loggie.set_domain_enabled("DEBUG", show_debug_logs)
	
	_setup_default_resources()
	_initialize_settlement() 
	_setup_ui()
	_connect_signals()
	
	if unit_spawner:
		unit_spawner.unit_container = unit_container
		unit_spawner.rts_controller = rts_controller
	
	# --- FIX: Set default UI state BEFORE checking for raid results ---
	if storefront_ui: storefront_ui.show()
	if end_of_year_popup: end_of_year_popup.hide()
	# -----------------------------------------------------------------

	# --- TEST DATA INJECTION ---
	if not DynastyManager.current_jarl:
		var test_jarl = DynastyTestDataGenerator.generate_test_dynasty()
		DynastyManager.current_jarl = test_jarl
		DynastyManager.jarl_stats_updated.emit(test_jarl)
	
	# Check for Raid Return (This opens the popup, so it must happen last)
	if not DynastyManager.pending_raid_result.is_empty():
		_process_raid_return()

	# --- DEBUG CHECK ---
	if rts_controller and not EventBus.select_command.is_connected(rts_controller._on_select_command):
		print("DIAGNOSTIC: Forcing RTSController connections.")
		EventBus.select_command.connect(rts_controller._on_select_command)
		EventBus.move_command.connect(rts_controller._on_move_command)
		EventBus.attack_command.connect(rts_controller._on_attack_command)
		EventBus.interact_command.connect(rts_controller._on_interact_command)
		
func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()

func _connect_signals() -> void:
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	EventBus.settlement_loaded.connect(_sync_villagers)
	
	EventBus.building_ready_for_placement.connect(_on_building_ready_for_placement)
	EventBus.building_placement_cancelled.connect(_on_building_placement_cancelled)
	EventBus.building_right_clicked.connect(_on_building_right_clicked)
	EventBus.dynasty_view_requested.connect(_toggle_dynasty_view)
	EventBus.end_year_requested.connect(_on_end_year_pressed)
	
	EventBus.request_worker_assignment.connect(_on_worker_requested)
	EventBus.request_worker_removal.connect(_on_worker_removal_requested)
	
	if building_cursor:
		building_cursor.placement_completed.connect(_on_building_placement_completed)
		building_cursor.placement_cancelled.connect(_on_building_placement_cancelled_by_cursor)

# --- RESOURCE LOADING (The missing function!) ---
func _setup_default_resources() -> void:
	if not test_building_data: test_building_data = default_test_building
	if not raider_scene: raider_scene = load("res://scenes/units/VikingRaider.tscn")
	if not end_of_year_popup_scene: end_of_year_popup_scene = default_end_of_year_popup

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
	
	idle_warning_dialog.canceled.connect(func():
		EventBus.worker_management_toggled.emit()
	)
	
	add_child(idle_warning_dialog)

# --- WORKER ASSIGNMENT LOGIC ---
func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
	Loggie.msg("SettlementBridge: Work assignments saved.").domain("BUILDING").info()
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.worker_assignments = assignments
		SettlementManager.save_settlement()

func _on_worker_requested(target: BaseBuilding) -> void:
	var civilians = get_tree().get_nodes_in_group("civilians")
	var nearest_civ: CivilianUnit = null
	var min_dist = INF
	
	for civ in civilians:
		if not civ is CivilianUnit: continue
		if civ.is_in_group("busy"): continue
		
		var dist = civ.global_position.distance_to(target.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_civ = civ
			
	if nearest_civ:
		nearest_civ.add_to_group("busy")
		var success = SettlementManager.assign_worker_from_unit(target, "peasant")
		
		if success:
			Loggie.msg("Immediate assignment success. Dispatching visual unit.").domain("RTS").info()
			nearest_civ.interaction_target = target # Set target directly
			nearest_civ.command_interact(target)
		else:
			nearest_civ.remove_from_group("busy")
			Loggie.msg("Assignment rejected by Manager.").domain("RTS").warn()
			EventBus.purchase_failed.emit("Building is full.")
	else:
		Loggie.msg("No available idle workers found!").domain("RTS").warn()
		EventBus.purchase_failed.emit("No idle workers found nearby.")

func _on_worker_removal_requested(building: BaseBuilding) -> void:
	if unit_spawner:
		var spawn_pos = building.global_position + Vector2(0, 40)
		unit_spawner.spawn_worker_at(spawn_pos)
	
	var success = SettlementManager.unassign_worker_from_building(building, "peasant")
	if not success:
		Loggie.msg("Worker removal data failed! Sync might be off.").domain("RTS").warn()

# --- END YEAR LOGIC CHAIN ---

func _on_end_year_pressed() -> void:
	Loggie.msg("SettlementBridge: End Year requested.").domain("BUILDING").info()
	
	var idle_p = SettlementManager.get_idle_peasants()
	var idle_t = SettlementManager.get_idle_thralls()
	var total_idle = idle_p + idle_t
	
	if total_idle > 0:
		idle_warning_dialog.dialog_text = "You have %d idle workers.\nUnassigned workers produce nothing.\n\nEnd year anyway?" % total_idle
		idle_warning_dialog.popup_centered()
	else:
		_start_end_year_sequence()

func _start_end_year_sequence() -> void:
	_close_all_popups()
	Loggie.msg("SettlementBridge: Handing off to DynastyManager for Winter Phase.").domain("SETTLEMENT").info()
	DynastyManager.start_winter_phase()

func _on_payout_collected(payout: Dictionary) -> void:
	# --- NEW: Handle Renown from Loot Distribution ---
	if payout.has("renown"):
		var amount = payout["renown"]
		if amount != 0:
			DynastyManager.award_renown(amount)
			var msg = "Renown %s %d (Loot Distribution)" % ["gained" if amount > 0 else "lost", abs(amount)]
			Loggie.msg(msg).domain(LogDomains.DYNASTY).info()
		
		# Remove it so it doesn't try to go into the Resource Treasury
		payout.erase("renown")
	# -------------------------------------------------
	
	SettlementManager.deposit_resources(payout)
	
	# Clear the pending result so it doesn't show up again on reload
	DynastyManager.pending_raid_result.clear()
	
	if storefront_ui: storefront_ui.show()

func _close_all_popups() -> void:
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
	if dynasty_ui: dynasty_ui.hide()
	if work_assignment_ui: work_assignment_ui.hide()
	if end_of_year_popup: end_of_year_popup.hide()

# --- SETTLEMENT LOGIC ---

func _clear_all_buildings() -> void:
	if is_instance_valid(building_container):
		for child in building_container.get_children(): child.queue_free()
		await get_tree().process_frame
	
	if is_instance_valid(unit_container):
		for child in unit_container.get_children(): child.queue_free()
		await get_tree().process_frame
	
	if is_instance_valid(grid_manager) and "astar_grid" in grid_manager:
		var grid = grid_manager.astar_grid
		var region = grid.region
		for x in range(region.size.x):
			for y in range(region.size.y):
				var pos = Vector2i(x + region.position.x, y + region.position.y)
				grid.set_point_solid(pos, false)
		grid.update()
	
	great_hall_instance = null
	game_is_over = false
	awaiting_placement = null

func _initialize_settlement() -> void:
	home_base_data = _create_default_settlement()
	await _clear_all_buildings()
	
	# 1. Load Data
	SettlementManager.load_settlement(home_base_data)
	
	if is_instance_valid(grid_manager) and "astar_grid" in grid_manager:
		SettlementManager.register_active_scene_nodes(grid_manager.astar_grid, building_container, grid_manager)
	
	# 2. Spawn Buildings
	_spawn_placed_buildings()

func _spawn_placed_buildings() -> void:
	if not SettlementManager.current_settlement: return
	
	# Clear existing
	for child in building_container.get_children(): child.queue_free()
	
	# Spawn Placed
	for building_entry in SettlementManager.current_settlement.placed_buildings:
		_spawn_single_building(building_entry, false) 
		
	# Spawn Construction Sites
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
		
	if unit_spawner: unit_spawner.clear_units()
	
	# Trigger Unit Spawn
	_sync_villagers()
	_spawn_player_garrison()
	
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
	pass # Handled by _sync_villagers

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

# --- RAID RETURN LOGIC ---
func _process_raid_return() -> void:
	var result = DynastyManager.pending_raid_result
	var outcome = result.get("outcome")
	
	# --- NEW: Update Hamingja History ---
	if outcome == "victory":
		DynastyManager.last_raid_outcome = "victory"
	elif outcome == "retreat":
		DynastyManager.last_raid_outcome = "defeat"
	else:
		DynastyManager.last_raid_outcome = "neutral"
		
	# --- Process Returning Bondi ---
	if SettlementManager.current_settlement:
		var warbands_to_disband: Array[WarbandData] = []
		
		for warband in SettlementManager.current_settlement.warbands:
			# Disband Bondi (Farmers) AND Seasonal Drengir (Raiders)
			if warband.is_bondi or warband.is_seasonal:
				
				# Bondi go back to work (Refund Pop)
				if warband.is_bondi and warband.current_manpower > 0:
					SettlementManager.current_settlement.population_peasants += warband.current_manpower
					Loggie.msg("Bondi returned to fields.").domain("SETTLEMENT").info()
				
				# Drengir just leave with their loot (No Pop Refund)
				if warband.is_seasonal:
					Loggie.msg("Seasonal Drengir have departed for the winter.").domain("SETTLEMENT").info()
				
				warbands_to_disband.append(warband)
		
		# Cleanup Data
		for wb in warbands_to_disband:
			SettlementManager.current_settlement.warbands.erase(wb)
			
		# Cleanup Physical SquadLeaders (IMPORTANT: Delete them so they don't persist)
		if is_instance_valid(unit_container):
			for child in unit_container.get_children():
				if child is SquadLeader and child.warband_ref in warbands_to_disband:
					if rts_controller: rts_controller.remove_unit(child)
					child.queue_free()
			
			# Now sync villagers to make them appear
			_sync_villagers()

	var grade = result.get("victory_grade", "Standard")
	var loot_summary = {}
	
	var xp_gain = 0
	if outcome == "victory": 
		xp_gain = 50
		if grade == "Decisive": xp_gain = 75
		elif grade == "Pyrrhic": xp_gain = 25
	elif outcome == "retreat": 
		xp_gain = 20
	
	# Odin Modifier
	if xp_gain > 0 and DynastyManager.active_year_modifiers.has("BLOT_ODIN"):
		xp_gain = int(xp_gain * 1.5)
		Loggie.msg("Odin's Wisdom: XP gain increased to %d." % xp_gain).domain("SETTLEMENT").info()
		
	if SettlementManager.current_settlement and xp_gain > 0:
		for warband in SettlementManager.current_settlement.warbands:
			if not warband.is_wounded:
				warband.experience += xp_gain

	if outcome == "victory":
		var gold = result.get("gold_looted", 0)
		var difficulty = DynastyManager.current_raid_difficulty
		var bonus = 200 + (difficulty * 50)
		
		if grade == "Decisive": bonus += 100
			
		loot_summary["gold"] = gold + bonus
		loot_summary["population"] = randi_range(2, 4) * difficulty
		
		# Warlord Progression
		var jarl = DynastyManager.get_current_jarl()
		if jarl:
			jarl.offensive_wins += 1
			jarl.battles_won += 1
			jarl.successful_raids += 1
			
			if jarl.has_trait("Warlord") and grade == "Decisive":
				var refund = 1 
				DynastyManager.current_jarl.current_authority = min(
					DynastyManager.current_jarl.current_authority + refund, 
					DynastyManager.current_jarl.max_authority
				)
			DynastyManager.jarl_stats_updated.emit(jarl)
		
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Victory! (%s)" % grade)
			
	elif outcome == "retreat":
		var gold = result.get("gold_looted", 0)
		loot_summary["gold"] = gold
		if is_instance_valid(end_of_year_popup):
			end_of_year_popup.display_payout(loot_summary, "Raid Retreat\n(Loot Secured)")
			
	if not loot_summary.is_empty():
		# We don't deposit yet if we are showing the popup (wait for Collect)
		# But if no popup exists, deposit now
		if not is_instance_valid(end_of_year_popup):
			SettlementManager.deposit_resources(loot_summary)

# --- PHYSICAL VILLAGER SYNC ---
func _sync_villagers(_data: SettlementData = null) -> void:
	if not SettlementManager.has_current_settlement(): return
	if not is_instance_valid(great_hall_instance): return
	if not unit_spawner: return
	
	var idle_count = SettlementManager.get_idle_peasants()
	var origin = great_hall_instance.global_position
	
	unit_spawner.sync_civilians(idle_count, origin)

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

func _spawn_player_garrison() -> void:
	if not SettlementManager.has_current_settlement(): return
	if not is_instance_valid(great_hall_instance): return
	if not unit_spawner: return
	
	var warbands = SettlementManager.current_settlement.warbands
	var origin = great_hall_instance.global_position
	
	unit_spawner.spawn_garrison(warbands, origin)
