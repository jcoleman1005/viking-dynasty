extends Control
class_name SummerWorkspace_UI

## The Unified Dashboard for Summer Operations.
## Acts as a read-only summary and launcher for the embedded Allocation UI.

# --- Configuration ---
const SEASONS_PER_YEAR: int = 4
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]

# --- UI References ---
@export_group("HUD Components")
@export var label_silver: Label
@export var label_food: Label
@export var label_wood: Label
@export var label_pop_total: Label
@export var label_pop_idle: Label
@export var texture_winter_warning: TextureRect
@export var btn_hide_ui: Button 

@export_group("Labor Summary")
@export var lbl_summary_farmers: Label
@export var lbl_summary_builders: Label
@export var lbl_summary_raiders: Label
@export var btn_manage_allocation: Button
@export var job_row_container: VBoxContainer ## container where the allocation panel will be injected
@export var allocation_view_scene: PackedScene ## Assign 'SummerAllocation_UI.tscn' here

@export_group("War Council")
@export var container_raid_command: Control 
@export var btn_collapse_toggle: Button
@export var label_authority: Label
@export var label_bondi_count: Label
@export var container_warbands: VBoxContainer
@export var btn_world_map: Button
@export var btn_proceed: Button

@export_group("Project Management")
@export var btn_tab_construction: Button
@export var btn_tab_completed: Button
@export var grid_active_projects: GridContainer
@export var grid_completed_buildings: GridContainer

# --- Internal References ---
@onready var background_layer: TextureRect = $BackgroundLayer
@onready var layout_root: VBoxContainer = $LayoutRoot

# Runtime generated nodes
var btn_restore_ui: Button 
var allocation_instance: Control

# --- State ---
var is_raid_panel_open: bool = true
var _has_activated: bool = false

func _ready() -> void:
	visible = false
	
	_setup_mouse_filters()
	_setup_signals()
	_connect_buttons()
	_create_restore_button()
	
	if DynastyManager.current_season == DynastyManager.Season.SUMMER:
		_activate_summer_ui()
	
	_set_project_view(true)

func _create_restore_button() -> void:
	btn_restore_ui = Button.new()
	btn_restore_ui.text = "Open Summer Council"
	btn_restore_ui.visible = false
	btn_restore_ui.top_level = true
	btn_restore_ui.anchor_left = 1.0
	btn_restore_ui.anchor_top = 1.0
	btn_restore_ui.anchor_right = 1.0
	btn_restore_ui.anchor_bottom = 1.0
	btn_restore_ui.offset_left = -220
	btn_restore_ui.offset_top = -60
	btn_restore_ui.offset_right = -20
	btn_restore_ui.offset_bottom = -20
	btn_restore_ui.pressed.connect(_on_restore_ui_pressed)
	add_child(btn_restore_ui)

func _connect_buttons() -> void:
	if btn_collapse_toggle: btn_collapse_toggle.pressed.connect(_toggle_raid_panel)
	if btn_world_map: btn_world_map.pressed.connect(func(): EventBus.scene_change_requested.emit(GameScenes.WORLD_MAP)) 
	if btn_proceed: btn_proceed.pressed.connect(_on_proceed_pressed)
	if btn_tab_construction: btn_tab_construction.pressed.connect(func(): _set_project_view(true))
	if btn_tab_completed: btn_tab_completed.pressed.connect(func(): _set_project_view(false))
	if btn_hide_ui: btn_hide_ui.pressed.connect(_on_hide_ui_pressed)
	if btn_manage_allocation: btn_manage_allocation.pressed.connect(_on_manage_allocation_pressed)

func _activate_summer_ui() -> void:
	visible = true
	_initial_refresh() 
	_has_activated = true
	Loggie.msg("Summer UI Activated").domain(LogDomains.UI).info()

func _setup_mouse_filters() -> void:
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if layout_root:
		layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in layout_root.get_children():
			if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if background_layer:
		background_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_signals() -> void:
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	EventBus.treasury_updated.connect(_on_treasury_updated)
	EventBus.population_changed.connect(_on_population_changed)
	EventBus.season_changed.connect(_on_season_changed)

# --- Visibility Toggles ---

func _on_hide_ui_pressed() -> void:
	if layout_root: layout_root.visible = false
	if background_layer: background_layer.visible = false
	if btn_restore_ui: btn_restore_ui.visible = true

func _on_restore_ui_pressed() -> void:
	if layout_root: layout_root.visible = true
	if background_layer: background_layer.visible = true
	if btn_restore_ui: btn_restore_ui.visible = false

# --- Data & Logic Initialization ---

func _initial_refresh() -> void:
	if not EconomyManager or not SettlementManager or not DynastyManager: return
	if not SettlementManager.current_settlement: return

	_update_resources(EconomyManager.get_projected_income()) 
	_update_authority_display()
	_update_forecast_warning()
	
	_refresh_labor_summary()
	_update_population_display()
	_refresh_building_grids()

func _refresh_labor_summary() -> void:
	if not SettlementManager.current_settlement: return
	
	var placed = SettlementManager.current_settlement.placed_buildings
	var pending = SettlementManager.current_settlement.pending_construction_buildings
	
	var current_farmers = 0
	for b in placed: current_farmers += b.get("assigned_workers", 0)
	
	var current_builders = 0
	for b in pending: current_builders += b.get("peasant_count", 0)
	
	# Raiders are tracked by EconomyManager/RaidManager usually, assuming 0 for now if not tracked in a var
	# If you have a variable for this, replace 0 below.
	var current_raiders = 0 
	
	if lbl_summary_farmers: lbl_summary_farmers.text = "Farming: %d" % current_farmers
	if lbl_summary_builders: lbl_summary_builders.text = "Construction: %d" % current_builders
	if lbl_summary_raiders: lbl_summary_raiders.text = "Raiders: %d" % current_raiders
	
	if label_bondi_count: label_bondi_count.text = str(current_raiders)

func _update_population_display() -> void:
	if not SettlementManager.current_settlement: return
	
	var total = SettlementManager.current_settlement.population_peasants
	var idle = SettlementManager.get_idle_peasants()
	
	if label_pop_total: label_pop_total.text = "Pop: %d" % total
	if label_pop_idle: label_pop_idle.text = "(%d Idle)" % idle
	
	var no_labor = idle <= 0
	label_pop_idle.modulate = Color.RED if no_labor else Color.WHITE

# --- External Allocation UI (Embedded) ---

func _on_manage_allocation_pressed() -> void:
	if not allocation_view_scene:
		Loggie.msg("Allocation Scene not assigned in SummerWorkspace_UI!").domain(LogDomains.UI).error()
		return
	
	# If panel exists, just toggle it
	if allocation_instance:
		allocation_instance.visible = not allocation_instance.visible
		return

	# Otherwise, instantiate it embedded in the column
	if not job_row_container:
		Loggie.msg("JobRowContainer not assigned! Cannot embed Allocation UI.").domain(LogDomains.UI).error()
		return
		
	allocation_instance = allocation_view_scene.instantiate()
	allocation_instance.name = "AllocationPanel"
	
	# Add to the VBox (JobRow_Container) so it sits below the button
	job_row_container.add_child(allocation_instance)
	
	# Configure layout to fit nicely in the column
	allocation_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allocation_instance.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	# Connect refresh signal
	if allocation_instance.has_signal("allocation_committed"):
		allocation_instance.allocation_committed.connect(_on_allocation_committed)

func _on_allocation_committed() -> void:
	Loggie.msg("Allocation Committed - Refreshing Dashboard").domain(LogDomains.UI).info()
	_initial_refresh()
	# Optional: Hide panel on commit?
	# if allocation_instance: allocation_instance.visible = false

# --- Projections & Forecasts ---

func _update_resources(treasury: Dictionary) -> void:
	if label_silver: label_silver.text = str(treasury.get("gold", 0))
	if label_food: label_food.text = str(treasury.get("food", 0))
	if label_wood: label_wood.text = str(treasury.get("wood", 0))

func _update_authority_display() -> void:
	if not DynastyManager.current_jarl: return
	var auth = DynastyManager.current_jarl.current_authority
	if label_authority: label_authority.text = "Authority: %d" % auth

func _update_forecast_warning() -> void:
	if not SettlementManager.current_settlement: return
	
	var forecast = EconomyManager.get_winter_forecast()
	var base_food_demand = forecast.get("food", 0)
	var current_food = SettlementManager.current_settlement.treasury.get("food", 0)
	
	if current_food < base_food_demand:
		texture_winter_warning.modulate = Color.RED
		texture_winter_warning.tooltip_text = "Deficit Predicted! Demand: %d" % base_food_demand
	else:
		texture_winter_warning.modulate = Color.GREEN
		texture_winter_warning.tooltip_text = "Winter Secure."

func _refresh_building_grids() -> void:
	if not grid_active_projects or not grid_completed_buildings: return
	
	for child in grid_active_projects.get_children(): child.queue_free()
	for child in grid_completed_buildings.get_children(): child.queue_free()
	
	# Completed
	for b in SettlementManager.current_settlement.placed_buildings:
		var lbl = Label.new()
		var b_name = "Building"
		if "resource_path" in b:
			var b_data = load(b["resource_path"])
			if b_data:
				b_name = b_data.display_name if "display_name" in b_data else b_data.resource_name
		
		lbl.text = str(b_name).capitalize() + " (Complete)"
		grid_completed_buildings.add_child(lbl)
		
	# Construction
	var pending = SettlementManager.current_settlement.get("pending_construction_buildings")
	if pending and pending is Array:
		for i in range(pending.size()):
			var b = pending[i]
			var lbl = Label.new()
			var b_name = "Site"
			if "resource_path" in b:
				var b_data = load(b["resource_path"])
				if b_data:
					b_name = b_data.display_name if "display_name" in b_data else b_data.resource_name
			
			var assigned = b.get("peasant_count", 0)
			var status_str = "(Paused)" if assigned == 0 else "(Active: %d)" % assigned
			if assigned == 0: lbl.modulate = Color.GRAY
			
			lbl.text = "%s %s" % [str(b_name).capitalize(), status_str]
			grid_active_projects.add_child(lbl)

# --- Commit / Phase Logic ---

func _on_proceed_pressed() -> void:
	SettlementManager._validate_employment_levels()
	Loggie.msg("Summer Ended. Proceeding to Autumn.").domain(LogDomains.GAMEPLAY).info()
	queue_free()

# --- Standard Handlers ---

func _on_settlement_loaded(_data) -> void:
	if visible: _initial_refresh()

func _on_treasury_updated(new_treasury: Dictionary) -> void:
	if visible: _update_resources(new_treasury); _update_forecast_warning()

func _on_population_changed() -> void:
	if visible: _initial_refresh()

func _on_season_changed(new_season: String) -> void:
	if new_season == "Summer": _activate_summer_ui()
	else: visible = false

func _toggle_raid_panel() -> void:
	is_raid_panel_open = !is_raid_panel_open
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_parallel(true)
	if is_raid_panel_open:
		container_raid_command.show()
		tween.tween_property(container_raid_command, "modulate:a", 1.0, 0.15)
		btn_collapse_toggle.text = "▼ War Council"
	else:
		tween.tween_property(container_raid_command, "modulate:a", 0.0, 0.1)
		tween.chain().tween_callback(container_raid_command.hide)
		btn_collapse_toggle.text = "▲ War Council"

func _set_project_view(show_construction: bool) -> void:
	if grid_active_projects: grid_active_projects.visible = show_construction
	if grid_completed_buildings: grid_completed_buildings.visible = !show_construction
	if btn_tab_construction: btn_tab_construction.set_pressed_no_signal(show_construction)
	if btn_tab_completed: btn_tab_completed.set_pressed_no_signal(!show_construction)
