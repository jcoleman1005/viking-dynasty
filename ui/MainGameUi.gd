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
@export var council_panel_scene: PackedScene # Unified scene for Spring & Winter
@export var summer_panel_scene: PackedScene  # New: Clan Allocation Menu
@export var autumn_panel_scene: PackedScene

# ------------------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------------------

@onready var center_view: Control = %CenterView

# Sidebar References
@export var sidebar_panel: Control
@export var sidebar_content: Control

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
	idle_worker_warning.confirmed.connect(func(): 
		if DynastyManager: DynastyManager.advance_season()
	)
	
	add_child(idle_worker_warning)

func _connect_signals() -> void:
	if EventBus:
		EventBus.season_changed.connect(_on_season_changed_signal)
		
		if not EventBus.has_signal("sidebar_close_requested"):
			Loggie.msg("EventBus missing 'sidebar_close_requested' signal").domain(LogDomains.UI).error()
		else:
			EventBus.sidebar_close_requested.connect(_close_sidebar)
		
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
		Loggie.msg("Instantiating Module: " + module_name).info()
		
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
		Loggie.msg("Sidebar scene is null for: " + module_name).error()
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

func _on_season_changed_signal(_season_name: String, context: Dictionary) -> void:
	_update_season_state(context)

func _update_season_state(context: Dictionary = {}) -> void:
	if not DynastyManager: return
	var current_season = DynastyManager.current_season
	var is_summer = (current_season == DynastyManager.Season.SUMMER)
	
	if bottom_bar: bottom_bar.set_agency_state(is_summer)
	
	if season_advance_btn:
		# HIDE in Spring: The player MUST pick a council card to advance.
		season_advance_btn.visible = (current_season != DynastyManager.Season.SPRING)
		
		match current_season:
			DynastyManager.Season.SPRING: season_advance_btn.text = "Start Summer"
			DynastyManager.Season.SUMMER: season_advance_btn.text = "End Summer"
			DynastyManager.Season.AUTUMN: season_advance_btn.text = "Sign and Seal Ledger"
			DynastyManager.Season.WINTER: season_advance_btn.text = "End Year"

	_update_center_view(current_season, context)
	Loggie.msg("UI Season State Updated: " + str(current_season)).info()

# MODIFIED: Intercepts the click to check for idle workers in Summer
func _on_advance_season_clicked() -> void:
	if not DynastyManager: return

	# 1. Harvest Safety Check (Only in Summer)
	if DynastyManager.current_season == DynastyManager.Season.SUMMER:
		var census = EconomyManager.get_population_census()
		
		var idle_peasants = census["peasants"]["idle"]
		var idle_thralls = census["thralls"]["idle"]
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
		DynastyManager.Season.SPRING, DynastyManager.Season.WINTER:
			scene_to_load = council_panel_scene
			season_string_name = "Spring" if season_enum == DynastyManager.Season.SPRING else "Winter"
		DynastyManager.Season.SUMMER:
			# Summer uses the RTS view + Overlay menus. No center panel needed.
			return
		DynastyManager.Season.AUTUMN: 
			scene_to_load = autumn_panel_scene
			season_string_name = "Autumn"
			
	if scene_to_load:
		var instance = scene_to_load.instantiate()
		center_view.add_child(instance)
		if instance is Control: instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# MANUAL HANDSHAKE:
		# Since the instance was just created, it missed the signal emission.
		# We manually force-feed it the context so it can initialize.
		if instance.has_method("_on_season_changed"):
			instance._on_season_changed(season_string_name, context)
