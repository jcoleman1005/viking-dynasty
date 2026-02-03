extends Control
class_name MainGameUI

## The persistent frame for the game. 
## Manages the Top Bar, Bottom Action Bar, and Seasonal Transitions.
## Replaces StorefrontUI.

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Building Data Paths
const BUILDING_PATHS = [
	"res://data/buildings/",
	"res://data/buildings/generated/"
]

# ------------------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------------------

@export_group("Top Bar")
@export var jarl_label: Label
# Replaces individual resource labels. Ensure TreasuryHUD.tscn is instanced here.
@export var treasury_hud: TreasuryHUD 
@export var authority_label: Label # Populated from JarlData
@export var renown_label: Label    # Populated from JarlData (Optional)

@export_group("Bottom Action Bar")
@export var bottom_bar_root: Control
@export var seasonal_actions_panel: PanelContainer
@export var btn_construct: Button
@export var btn_raids: Button
@export var btn_farming: Button

@export_group("Navigation")
@export var season_advance_btn: Button
@export var dynasty_button: Button

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------

# [REFACTORED] State duplication removed. 
# We now access DynastyManager.current_season directly as the Source of Truth.
var cached_buildings: Array[Resource] = []

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------

func _ready() -> void:
	_connect_signals()
	_load_available_buildings()
	_setup_initial_state()
	
	_update_jarl_stats()
	
	Loggie.msg("MainGameUI initialized").domain(Loggie.LogDomains.UI).info()

func _connect_signals() -> void:
	if EventBus:
		# TreasuryHUD handles treasury_updated internally. 
		# MainGameUI only cares about Season changes.
		EventBus.season_changed.connect(_on_season_changed_signal)
	else:
		Loggie.msg("EventBus not found").domain(Loggie.LogDomains.UI).error()

	season_advance_btn.pressed.connect(_on_advance_season_clicked)
	dynasty_button.pressed.connect(_on_dynasty_clicked)
	
	btn_construct.pressed.connect(_on_tab_clicked.bind("construction"))
	btn_raids.pressed.connect(_on_tab_clicked.bind("raids"))
	btn_farming.pressed.connect(_on_tab_clicked.bind("farming"))

func _setup_initial_state() -> void:
	# Rely on DynastyManager as source of truth
	_update_season_state()

# ------------------------------------------------------------------------------
# DATA LOADING (Building Scanner)
# ------------------------------------------------------------------------------

func _load_available_buildings() -> void:
	cached_buildings.clear()
	for folder_path in BUILDING_PATHS:
		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var full_path = folder_path + "/" + file_name
					var res = load(full_path)
					# Check for 'is_player_buildable' property safely
					if res and "is_player_buildable" in res and res.is_player_buildable:
						cached_buildings.append(res)
				file_name = dir.get_next()
	
	Loggie.msg("Loaded buildable structures").domain(Loggie.LogDomains.UI).context(str(cached_buildings.size())).info()

# ------------------------------------------------------------------------------
# EVENT HANDLERS
# ------------------------------------------------------------------------------

func _on_season_changed_signal(_season_name: String) -> void:
	# Ignore string payload, trust the Manager state
	_update_season_state()

func _update_season_state() -> void:
	if not DynastyManager: return
	
	var current_season = DynastyManager.current_season
	var is_summer = (current_season == DynastyManager.Season.SUMMER)
	
	# Determine Agency (Summer = Active, Others = Restricted)
	if is_summer:
		_set_action_bar_state(true)
		season_advance_btn.text = "End Summer"
	else:
		_set_action_bar_state(false)
		
		match current_season:
			DynastyManager.Season.SPRING: season_advance_btn.text = "Start Summer"
			DynastyManager.Season.AUTUMN: season_advance_btn.text = "End Harvest"
			DynastyManager.Season.WINTER: season_advance_btn.text = "End Year"

	Loggie.msg("UI Season State Updated").domain(Loggie.LogDomains.UI).context(str(current_season)).info()

func _on_advance_season_clicked() -> void:
	# DynastyManager handles season advancement logic
	if DynastyManager:
		DynastyManager.advance_season()
	else:
		Loggie.msg("DynastyManager missing").domain(Loggie.LogDomains.UI).error()

func _on_dynasty_clicked() -> void:
	Loggie.msg("Dynasty Panel Requested").domain(Loggie.LogDomains.UI).info()
	# Placeholder: Open Dynasty View

func _on_tab_clicked(category: String) -> void:
	# Direct check against Source of Truth
	if DynastyManager.current_season != DynastyManager.Season.SUMMER:
		return # Mute clicks out of season
		
	_populate_action_strip(category)

# ------------------------------------------------------------------------------
# UI UPDATES
# ------------------------------------------------------------------------------

func _update_jarl_stats() -> void:
	if not DynastyManager: return
	
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		jarl_label.text = jarl.display_name
		if authority_label:
			authority_label.text = "Auth: %d" % jarl.current_authority
		if renown_label:
			renown_label.text = "Renown: %d" % jarl.renown

func _set_action_bar_state(enabled: bool) -> void:
	var opacity = 1.0 if enabled else 0.5
	bottom_bar_root.modulate.a = opacity
	
	btn_construct.disabled = not enabled
	btn_raids.disabled = not enabled
	btn_farming.disabled = not enabled
	
	if not enabled:
		_clear_action_strip()

func _populate_action_strip(category: String) -> void:
	_clear_action_strip()
	
	match category:
		"construction":
			_render_construction_strip()
		"raids":
			_render_raids_strip()
		"farming":
			_render_farming_strip()

func _clear_action_strip() -> void:
	for child in seasonal_actions_panel.get_children():
		child.queue_free()

# ------------------------------------------------------------------------------
# STRIP RENDERERS
# ------------------------------------------------------------------------------

func _render_construction_strip() -> void:
	var container = HBoxContainer.new()
	container.set("theme_override_constants/separation", 10)
	seasonal_actions_panel.add_child(container)
	
	for building_data in cached_buildings:
		var btn = Button.new()
		# Use display_name if available, else resource name
		var btn_text = building_data.display_name if "display_name" in building_data else building_data.resource_name
		btn.text = btn_text
		
		# Format cost using Dictionary helper
		var tooltip_cost = "Unknown Cost"
		if "build_cost" in building_data and building_data.build_cost is Dictionary:
			tooltip_cost = _format_cost(building_data.build_cost)
			
		btn.tooltip_text = "Cost: " + tooltip_cost
		container.add_child(btn)
		
		# Connect to actual build logic via EventBus
		btn.pressed.connect(func(): 
			Loggie.msg("Building selected for placement").context(btn_text).info()
			if EventBus.has_signal("building_ready_for_placement"):
				EventBus.building_ready_for_placement.emit(building_data)
			else:
				Loggie.msg("Signal 'building_ready_for_placement' missing on EventBus").domain(Loggie.LogDomains.UI).error()
		)

func _render_raids_strip() -> void:
	var container = HBoxContainer.new()
	container.set("theme_override_constants/separation", 10)
	seasonal_actions_panel.add_child(container)
	
	# Action: Go to World Map
	var btn_map = Button.new()
	btn_map.text = "Open World Map"
	btn_map.tooltip_text = "Travel to the Macro Map to identify raid targets."
	container.add_child(btn_map)
	
	btn_map.pressed.connect(func():
		Loggie.msg("Requesting World Map Navigation").domain(Loggie.LogDomains.UI).info()
		
		# Request Scene Change via EventBus
		if EventBus.has_signal("scene_change_requested"):
			# Assuming GameScenes is a global class containing the path
			EventBus.scene_change_requested.emit(GameScenes.WORLD_MAP)
		else:
			Loggie.msg("Signal 'scene_change_requested' missing on EventBus").domain(Loggie.LogDomains.UI).error()
	)
	
	# Optional: Contextual info if we knew a target was selected
	var info_label = Label.new()
	info_label.text = "  (Select a region on map to raid)"
	container.add_child(info_label)

func _render_farming_strip() -> void:
	var label = Label.new()
	label.text = "Assign Peasants / Thralls."
	seasonal_actions_panel.add_child(label)

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------

# Relaxed typing to accept untyped Dictionaries from Resources
func _format_cost(cost: Dictionary) -> String:
	var s: PackedStringArray = []
	for k in cost:
		# Use GameResources to get friendly name if available
		var display_name = GameResources.get_display_name(k)
		s.append("%d %s" % [cost[k], display_name])
	return ", ".join(s)
