extends Control
class_name MainGameUI

## The persistent frame for the game. 
## Manages Top Bar, Bottom Bar, Center Routing, and the Left Sidebar.
## Acts as the CONTROLLER for the UI sub-components.

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

const BUILDING_PATHS = [
	"res://data/buildings/",
	"res://data/buildings/generated/"
]

@export_group("Components")
@export var top_bar: Control
@export var bottom_bar: Control 
@export var season_advance_btn: Button

@export_group("Sidebar Modules")
@export var dynasty_ui_scene: PackedScene

@export_group("Seasonal Panels")
@export var spring_screen_scene: PackedScene
@export var summer_panel_scene: PackedScene
@export var autumn_panel_scene: PackedScene
@export var winter_severity_scene: PackedScene
@export var winter_screen_scene: PackedScene

@export var decree_popup_scene: PackedScene

@export_group("Sidebar Configuration")
@export var sidebar_panel: Control
@export var sidebar_content: Control

@onready var center_view: Control = %CenterView

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------

var is_sidebar_open: bool = false
var sidebar_tween: Tween
var idle_worker_warning: ConfirmationDialog # NEW: Runtime generated dialog

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------

func _ready() -> void:
	Loggie.msg("MainGameUI: decree_popup_scene state: " + str(decree_popup_scene)).domain(LogDomains.UI).info()
	var available_buildings = _scan_for_buildings()
	
	if bottom_bar and bottom_bar.has_method("setup"):
		bottom_bar.setup(available_buildings)
	
	_connect_signals()
	_setup_initial_state()
	_setup_warning_dialog() # NEW
	
	Loggie.msg("MainGameUI initialized").domain(LogDomains.UI).info()

func _setup_warning_dialog() -> void:
	# Programmatically create the dialog so we don't depend on scene edits
	idle_worker_warning = ConfirmationDialog.new()
	idle_worker_warning.title = "Unassigned Workers"
	idle_worker_warning.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	idle_worker_warning.size = Vector2(400, 150)
	
	# Connect the "OK" button to the actual advancement
	idle_worker_warning.confirmed.connect(_on_idle_warning_confirmed)
	
	add_child(idle_worker_warning)

func _on_idle_warning_confirmed() -> void:
	if DynastyManager:
		DynastyManager.advance_season()

func _connect_signals() -> void:
	if EventBus:
		EventBus.season_changed.connect(_on_season_changed_signal)
		
		if not EventBus.has_signal("sidebar_close_requested"):
			Loggie.msg("EventBus missing 'sidebar_close_requested' signal").domain(LogDomains.UI).error()
		else:
			EventBus.sidebar_close_requested.connect(_close_sidebar)
		
		EventBus.construction_decree_issued.connect(_on_construction_decree_issued)
		EventBus.summer_day_changed.connect(_update_advance_button)
		
		if bottom_bar:
			bottom_bar.scene_navigation_requested.connect(func(path):
				EventBus.scene_change_requested.emit(path)
			)
	else:
		Loggie.msg("EventBus not found").domain(LogDomains.UI).error()

	if season_advance_btn:
		season_advance_btn.pressed.connect(_on_advance_season_clicked)
	
	# Connect TopBar Signals (e.g. Dynasty Button)
	if top_bar and top_bar.has_signal("dynasty_view_requested"):
		top_bar.dynasty_view_requested.connect(_on_dynasty_view_requested)

func _setup_initial_state() -> void:
	# Initial setup usually lacks context data (game load), pass empty dict
	_update_season_state({})
	if top_bar and top_bar.has_method("refresh_all"):
		top_bar.refresh_all()
	
	# Ensure Sidebar is hidden initially
	if sidebar_panel:
		sidebar_panel.position.x = -sidebar_panel.size.x

# ------------------------------------------------------------------------------
# SIDEBAR LOGIC
# ------------------------------------------------------------------------------

func _on_dynasty_view_requested() -> void:
	_toggle_sidebar(dynasty_ui_scene, "DynastyUI")

func _toggle_sidebar(scene: PackedScene, module_name: String) -> void:
	if not sidebar_panel or not sidebar_content: return
	
	# If asking for the same module and it's open, close it.
	var current_child = sidebar_content.get_child(0) if sidebar_content.get_child_count() > 0 else null
	var is_same_module = current_child and current_child.name == module_name
	
	if is_sidebar_open and is_same_module:
		_close_sidebar()
	else:
		_open_sidebar(scene, module_name)

func _open_sidebar(scene: PackedScene, module_name: String) -> void:
	# 1. Clean up existing content
	for child in sidebar_content.get_children():
		child.queue_free()
	
	# 2. Instance new module
	if scene:
		Loggie.msg("Instantiating Module: " + module_name).domain(LogDomains.UI).info()
		
		var instance = scene.instantiate()
		instance.name = module_name
		sidebar_content.add_child(instance)
		
		# Layout Safety
		if instance is Control:
			instance.visible = true
			instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Context Injection
		if instance.has_method("setup"):
			instance.setup()
			
	else:
		Loggie.msg("Sidebar scene is null for: " + module_name).domain(LogDomains.UI).error()
		return

	# 3. Animate Open
	if sidebar_tween: sidebar_tween.kill()
	sidebar_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sidebar_tween.tween_property(sidebar_panel, "position:x", 0.0, 0.3)
	is_sidebar_open = true

func _close_sidebar() -> void:
	if not sidebar_panel: return
	
	# Animate Close
	var target_x = -sidebar_panel.size.x
	
	if sidebar_tween: sidebar_tween.kill()
	sidebar_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	sidebar_tween.tween_property(sidebar_panel, "position:x", target_x, 0.3)
	
	is_sidebar_open = false

func _on_construction_decree_issued(decree: ConstructionDecree) -> void:
	if decree_popup_scene:
		var popup = decree_popup_scene.instantiate()
		add_child(popup)
		if popup.has_method("setup"):
			popup.setup(decree)
		Loggie.msg("Decree Popup Opened via MainGameUI").domain(LogDomains.UI).info()
	else:
		Loggie.msg("decree_popup_scene not assigned in MainGameUI").domain(LogDomains.UI).error()

# ------------------------------------------------------------------------------
# DATA LOADING
# ------------------------------------------------------------------------------

func _scan_for_buildings() -> Array[Resource]:
	var buildings: Array[Resource] = []
	for folder_path in BUILDING_PATHS:
		if not DirAccess.dir_exists_absolute(folder_path): continue
		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var full_path = folder_path + "/" + file_name
					var res = load(full_path)
					if res and "is_player_buildable" in res and res.is_player_buildable:
						buildings.append(res)
				file_name = dir.get_next()
	return buildings

# ------------------------------------------------------------------------------
# EVENT HANDLERS (Season)
# ------------------------------------------------------------------------------

func _on_season_changed_signal(season_name: String, context: Dictionary) -> void:
	Loggie.msg("MainGameUI: _on_season_changed_signal(%s)" % season_name).domain(LogDomains.UI).info()
	_update_season_state(context)

func _update_season_state(context: Dictionary = {}) -> void:
	if not DynastyManager: 
		Loggie.msg("MainGameUI: DynastyManager missing in _update_season_state").error()
		return
	var current_season = DynastyManager.current_season
	var is_summer = (current_season == DynastyManager.Season.SUMMER)
	
	Loggie.msg("MainGameUI: Updating Season State. Season: %d IsSummer: %s" % [current_season, str(is_summer)]).domain(LogDomains.UI).info()
	
	if bottom_bar: bottom_bar.set_agency_state(is_summer)
	
	if season_advance_btn:
		# Spring advances via oath card confirm only — hide the button
		season_advance_btn.visible = (current_season != DynastyManager.Season.SPRING)

		match current_season:
			DynastyManager.Season.SUMMER: season_advance_btn.text = "End Summer"
			DynastyManager.Season.AUTUMN: season_advance_btn.text = "Sign and Seal Ledger"
			DynastyManager.Season.WINTER: season_advance_btn.text = "End Year"

	_update_center_view(current_season, context)
	Loggie.msg("UI Season State Updated: " + str(current_season)).domain(LogDomains.UI).info()

func _update_advance_button(current_day: int, max_days: int) -> void:
	if DynastyManager.current_season == DynastyManager.Season.SUMMER:
		season_advance_btn.text = "Next Day (%d/%d)" % [current_day, max_days]
	else:
		season_advance_btn.text = "End Season"

# MODIFIED: Intercepts the click to check for idle workers in Summer
func _on_advance_season_clicked() -> void:
	if not DynastyManager: return
	
	if DynastyManager.current_season == DynastyManager.Season.SUMMER \
	and DynastyManager.current_day <= DynastyManager.SUMMER_DAYS:
		# If we are on the LAST day, advance_day() will internally call advance_season()
		DynastyManager.advance_day()
		return

	# 1. Harvest Safety Check (Only when transition to Autumn is about to happen)
	if DynastyManager.current_season == DynastyManager.Season.SUMMER:
		var idle_peasants = SettlementManager.get_idle_peasants()
		var idle_thralls = SettlementManager.get_idle_thralls()
		var total_idle = idle_peasants + idle_thralls
		
		if total_idle > 0:
			var msg = "You have %d idle workers (%d Peasants, %d Thralls).\n\n" % [total_idle, idle_peasants, idle_thralls]
			msg += "Workers not assigned to buildings will produce NOTHING during the Autumn Harvest.\n\n"
			msg += "Are you sure you want to end the Summer?"
			
			idle_worker_warning.dialog_text = msg
			idle_worker_warning.popup_centered()
			return # STOP execution here; wait for dialog confirmation

	# 2. Proceed normally for other seasons or if no idles
	DynastyManager.advance_season()

func _update_center_view(season_enum: int, context: Dictionary) -> void:
	if not center_view: return
	for child in center_view.get_children(): child.queue_free()
	
	var scene_to_load: PackedScene
	var season_string_name = ""
	
	match season_enum:
		DynastyManager.Season.SPRING:
			scene_to_load = spring_screen_scene
			season_string_name = "Spring"
		DynastyManager.Season.SUMMER:
			return
		DynastyManager.Season.AUTUMN: 
			scene_to_load = autumn_panel_scene
			season_string_name = "Autumn"
		DynastyManager.Season.WINTER:
			scene_to_load = winter_severity_scene
			season_string_name = "Winter"
			
	if scene_to_load:
		var instance = scene_to_load.instantiate()
		center_view.add_child(instance)
		if instance is Control: instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# If it's WinterSeverityBeat, connect its signal to load WinterScreen
		if season_enum == DynastyManager.Season.WINTER and instance.has_signal("severity_resolved"):
			instance.severity_resolved.connect(_on_winter_severity_resolved.bind(context))
		
		if instance.has_method("_on_season_changed"):
			instance._on_season_changed(season_string_name, context)

func _on_winter_severity_resolved(choice: String, context: Dictionary) -> void:
	# Now load the WinterHallUI (WinterScreen)
	if winter_screen_scene:
		for child in center_view.get_children(): child.queue_free()
		var instance = winter_screen_scene.instantiate()
		center_view.add_child(instance)
		if instance is Control: instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		if instance.has_method("_on_season_changed"):
			instance._on_season_changed("Winter", context)


