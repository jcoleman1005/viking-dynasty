extends Control
class_name MainGameUI

## The persistent frame for the game. 
## Manages the Top Bar, Bottom Action Bar, and Seasonal Transitions.
## Acts as the CONTROLLER for the UI sub-components.

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Building Data Paths
const BUILDING_PATHS = [
	"res://data/buildings/",
	"res://data/buildings/generated/"
]

@export_group("Seasonal Panels")
@export var spring_panel_scene: PackedScene
@export var autumn_panel_scene: PackedScene
@export var winter_panel_scene: PackedScene

# ------------------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------------------

@export_group("Components")
@export var top_bar: PanelContainer
@export var bottom_bar: BottomBar 
@export var season_advance_btn: Button

# Internal References
@onready var center_view: Control = %CenterView

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------

func _ready() -> void:
	# 1. Gather Data
	var available_buildings = _scan_for_buildings()
	
	# 2. Initialize Components
	if bottom_bar:
		bottom_bar.setup(available_buildings)
	
	_connect_signals()
	_setup_initial_state()
	
	Loggie.msg("MainGameUI initialized").domain(LogDomains.UI).info()

func _connect_signals() -> void:
	if EventBus:
		EventBus.season_changed.connect(_on_season_changed_signal)
		
		# Optional: Listen for scene change requests from BottomBar
		if bottom_bar:
			bottom_bar.scene_navigation_requested.connect(func(path):
				EventBus.scene_change_requested.emit(path)
			)
	else:
		Loggie.msg("EventBus not found").domain(LogDomains.UI).error()

	if season_advance_btn:
		season_advance_btn.pressed.connect(_on_advance_season_clicked)

func _setup_initial_state() -> void:
	# Sync UI with current game state
	_update_season_state()
	
	# Sync TopBar
	if top_bar:
		top_bar.refresh_all()

# ------------------------------------------------------------------------------
# DATA LOADING
# ------------------------------------------------------------------------------

## Scans project directories for valid BuildingData resources
func _scan_for_buildings() -> Array[Resource]:
	var buildings: Array[Resource] = []
	
	for folder_path in BUILDING_PATHS:
		if not DirAccess.dir_exists_absolute(folder_path):
			continue
			
		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var full_path = folder_path + "/" + file_name
					var res = load(full_path)
					
					# Validation check: is it a building and is it buildable?
					if res and "is_player_buildable" in res and res.is_player_buildable:
						buildings.append(res)
						
				file_name = dir.get_next()
	
	return buildings

# ------------------------------------------------------------------------------
# EVENT HANDLERS
# ------------------------------------------------------------------------------

func _on_season_changed_signal(_season_name: String) -> void:
	# Ignore string payload, trust the Manager state for logic
	_update_season_state()

func _update_season_state() -> void:
	if not DynastyManager: return
	
	var current_season = DynastyManager.current_season
	var is_summer = (current_season == DynastyManager.Season.SUMMER)
	
	# 1. Update BottomBar Agency
	if bottom_bar:
		bottom_bar.set_agency_state(is_summer)
	
	# 2. Update Season Advance Button
	if season_advance_btn:
		match current_season:
			DynastyManager.Season.SPRING: season_advance_btn.text = "Start Summer"
			DynastyManager.Season.SUMMER: season_advance_btn.text = "End Summer"
			DynastyManager.Season.AUTUMN: season_advance_btn.text = "End Harvest"
			DynastyManager.Season.WINTER: season_advance_btn.text = "End Year"

	# 3. Update Center View Content (The Routing Logic)
	_update_center_view(current_season)

	Loggie.msg("UI Season State Updated"+ (str(current_season))).domain(LogDomains.UI).info()

func _on_advance_season_clicked() -> void:
	if DynastyManager:
		DynastyManager.advance_season()

# ------------------------------------------------------------------------------
# CENTER VIEW ROUTING
# ------------------------------------------------------------------------------

func _update_center_view(season_enum: int) -> void:
	if not center_view: return
	
	# 1. Clear existing content (e.g., remove Spring panel when moving to Summer)
	for child in center_view.get_children():
		child.queue_free()
	
	var scene_to_load: PackedScene
	
	match season_enum:
		DynastyManager.Season.SPRING:
			scene_to_load = spring_panel_scene
		DynastyManager.Season.AUTUMN:
			scene_to_load = autumn_panel_scene
		DynastyManager.Season.WINTER:
			scene_to_load = winter_panel_scene
		DynastyManager.Season.SUMMER:
			# Summer is gameplay time. We leave the center view empty.
			# This allows clicks to pass through to the game world via mouse_filter=2.
			pass
			
	if scene_to_load:
		var instance = scene_to_load.instantiate()
		center_view.add_child(instance)
		
		# Ensure the panel fills the center view area
		if instance is Control:
			instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		Loggie.msg("Loaded Seasonal Panel"+ str(season_enum)).info()
