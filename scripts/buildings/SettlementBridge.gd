# res://scripts/buildings/SettlementBridge.gd
# --- MODIFIED: Added Work Assignment UI & Button ---

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
var end_of_year_popup: PanelContainer

# --- Debug Button ---
@onready var debug_raid_button: Button = $UI/Storefront_UI/DebugRaidButton

# --- Local Node References ---
@onready var building_container: Node2D = $BuildingContainer
@onready var grid_manager: Node = $GridManager

# --- NEW: Worker Management UI ---
const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer
var manage_workers_button: Button
# -------------------------------

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null


func _ready() -> void:
	_setup_default_resources()
	_initialize_settlement() 
	_setup_ui()
	_connect_signals()
	
	# --- NEW: Setup Worker UI ---
	_setup_worker_ui()
	# ----------------------------
	if not DynastyManager.pending_raid_result.is_empty():
		_process_raid_return()
		
	storefront_ui.show()
	if end_of_year_popup:
		end_of_year_popup.hide()

func _exit_tree() -> void:
	SettlementManager.unregister_active_scene_nodes()

# --- NEW: Worker UI Setup Function ---
func _setup_worker_ui() -> void:
	# 1. Load the UI Scene
	if ResourceLoader.exists(WORK_ASSIGNMENT_SCENE_PATH):
		var scene = load(WORK_ASSIGNMENT_SCENE_PATH)
		if scene:
			work_assignment_ui = scene.instantiate()
			add_child(work_assignment_ui)
			if work_assignment_ui.has_signal("assignments_confirmed"):
				work_assignment_ui.assignments_confirmed.connect(_on_worker_assignments_confirmed)
	else:
		push_error("SettlementBridge: WorkAssignment_UI scene missing.")

	# 2. Create the Button
	manage_workers_button = Button.new()
	manage_workers_button.text = "Manage Workers"
	manage_workers_button.pressed.connect(_on_manage_workers_pressed)
	
	# Position it Top-Right (below the Start Raid button logic usually, or Top-Left)
	# Let's put it Top-Left for visibility in the settlement view
	ui_layer.add_child(manage_workers_button)
	manage_workers_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	manage_workers_button.position.y += 60 # Offset down a bit if needed

func _on_manage_workers_pressed() -> void:
	if not SettlementManager.has_current_settlement():
		return
	
	if work_assignment_ui:
		work_assignment_ui.setup(SettlementManager.current_settlement)

func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
	print("SettlementBridge: Work assignments saved.")
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.worker_assignments = assignments
		SettlementManager.save_settlement()
# ----------------------------------------

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
	
	# Pass GridManager for Phase 3
	SettlementManager.register_active_scene_nodes(local_astar_grid, building_container, grid_manager)
	
	_spawn_placed_buildings()
	
	EventBus.settlement_loaded.emit(home_base_data)


func _spawn_placed_buildings() -> void:
	if not SettlementManager.current_settlement:
		return
	
	for child in building_container.get_children():
		child.queue_free()

	# 1. Spawn Active Buildings
	for building_entry in SettlementManager.current_settlement.placed_buildings:
		_spawn_single_building(building_entry, false) 

	# 2. Spawn Pending Blueprints (Phase 4 Update)
	for building_entry in SettlementManager.current_settlement.pending_construction_buildings:
		var b = _spawn_single_building(building_entry, false)
		if b:
			var progress = building_entry.get("progress", 0)
			if progress > 0:
				b.construction_progress = progress
				b.set_state(BaseBuilding.BuildingState.UNDER_CONSTRUCTION)
				# Force visual update for health bar
				if b.has_method("add_construction_progress"):
					b.add_construction_progress(0) 
			else:
				b.set_state(BaseBuilding.BuildingState.BLUEPRINT)
	
	if is_instance_valid(SettlementManager.active_astar_grid):
		SettlementManager.active_astar_grid.update()
	
	print("SettlementBridge: Settlement restored.")

func _spawn_single_building(entry: Dictionary, is_new: bool) -> BaseBuilding:
	var building_res_path: String = entry["resource_path"]
	var grid_pos: Vector2i = entry["grid_position"]
	
	var building_data: BuildingData = load(building_res_path)
	if building_data:
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
	settlement.pending_construction_buildings = [] 
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

# --- Building Cursor System Functions ---

func _on_building_ready_for_placement(building_data: BuildingData) -> void:
	awaiting_placement = building_data
	building_cursor.cell_size = grid_manager.cell_size
	building_cursor.set_building_preview(building_data)

func _on_building_placement_cancelled(building_data: BuildingData) -> void:
	print("Building placement cancelled: %s" % building_data.display_name)

func _on_building_placement_completed() -> void:
	if awaiting_placement and SettlementManager.current_settlement:
		var snapped_grid_pos = Vector2i(building_cursor.global_position / grid_manager.cell_size)
		
		print("SettlementBridge: Placing NEW blueprint for %s at %s" % [awaiting_placement.display_name, snapped_grid_pos])
		SettlementManager.place_building(awaiting_placement, snapped_grid_pos, true)
	
	awaiting_placement = null

func _on_building_placement_cancelled_by_cursor() -> void:
	if awaiting_placement:
		SettlementManager.deposit_resources(awaiting_placement.build_cost)
		awaiting_placement = null

func _on_building_right_clicked(building: BaseBuilding) -> void:
	# Move/Sell logic
	if building_cursor.is_active:
		return
	
	# --- REVERTED: Lock Removed ---
	# We now allow deleting the Hub because the Cursor logic 
	# permits placing it back down on empty land.
	# ------------------------------
		
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

func _process_raid_return() -> void:
	print("SettlementBridge: Processing return from raid...")
	var result = DynastyManager.pending_raid_result
	var difficulty = DynastyManager.current_raid_difficulty
	var loot_summary = {}
	
	if result.get("outcome") == "victory":
		# 1. Retrieve Looted Gold
		var gold = result.get("gold_looted", 0)
		
		# 2. Calculate Bonus Gold (Victory Bonus)
		# Base 200 + (50 per difficulty star)
		var bonus_gold = 200 + (difficulty * 50)
		var total_gold = gold + bonus_gold
		
		loot_summary["gold"] = total_gold
		
		# 3. Calculate Thralls (The Scarcity Engine)
		# Formula: Random(2 to 4) * Difficulty
		var base_thralls = randi_range(2, 4)
		var total_thralls = base_thralls * difficulty
		
		loot_summary["population"] = total_thralls
		
		# 4. Deposit
		SettlementManager.deposit_resources(loot_summary)
		
		# 5. Show the Report
		if is_instance_valid(end_of_year_popup):
			# We reuse the EndOfYear popup but with a custom title
			end_of_year_popup.display_payout(loot_summary, "Raid Successful!")
			
	# Clear the result so it doesn't trigger again on reload
	DynastyManager.pending_raid_result.clear()
