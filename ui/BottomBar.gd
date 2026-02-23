#res://ui/BottomBar.gd
class_name BottomBar
extends VBoxContainer

## Component: BottomBar
## Manages Player Agency Tabs.
## Modular architecture: Instances child scenes for Build, Alloc, and Raid menus.
## Acts as a persistent State Manager for navigation and UI restoration.

# ------------------------------------------------------------------------------
# SIGNALS
# ------------------------------------------------------------------------------

signal scene_navigation_requested(scene_path: String)

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

@export_group("Sub-Components")
# Note: Must act as PackedScene to accept .tscn files in Inspector
@export var build_menu_scene: PackedScene
@export var allocation_menu_scene: PackedScene
@export var raid_menu_scene: PackedScene

# ------------------------------------------------------------------------------
# UI REFERENCES
# ------------------------------------------------------------------------------

@onready var seasonal_actions_panel: PanelContainer = %SeasonalActionsPanel
@onready var btn_construct: Button = %BtnConstruct
@onready var btn_raids: Button = %BtnRaids
@onready var btn_farming: Button = %BtnFarming

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------

var cached_buildings: Array[Resource] = []
var is_agency_active: bool = false
var last_active_category: String = "" # [NEW] Tracks the open tab to restore it later

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------

func _ready() -> void:
	_connect_tabs()
	_connect_signals()
	
	# Default to inactive until Parent initializes us
	set_agency_state(false)

func _connect_tabs() -> void:
	btn_construct.pressed.connect(_on_tab_clicked.bind("construction"))
	btn_raids.pressed.connect(_on_tab_clicked.bind("raids"))
	btn_farming.pressed.connect(_on_tab_clicked.bind("farming"))

func _connect_signals() -> void:
	if EventBus:
		# Refund Logic: Listen for global signals
		if EventBus.has_signal("building_placement_cancelled"):
			EventBus.building_placement_cancelled.connect(_on_placement_cancelled)
		
		if EventBus.has_signal("building_placed"):
			EventBus.building_placed.connect(_on_placement_completed)
			
		# Cost Tracking: Capture cost when placement starts (initiated by BuildMenu)
		if EventBus.has_signal("building_ready_for_placement"):
			EventBus.building_ready_for_placement.connect(_on_building_placement_initiated)
	else:
		Loggie.msg("EventBus missing in BottomBar").domain(LogDomains.UI).error()

# ------------------------------------------------------------------------------
# PUBLIC INTERFACE (Controller Access)
# ------------------------------------------------------------------------------

## Receives data from the Controller (MainGameUI)
func setup(buildings: Array[Resource], _units: Array[Resource] = []) -> void:
	cached_buildings = buildings
	Loggie.msg("BottomBar configured: Modular Mode").info()

## Enables or disables interaction based on the Season (Summer = Active)
func set_agency_state(active: bool) -> void:
	is_agency_active = active
	
	# Visual Feedback
	var opacity = 1.0 if active else 0.5
	modulate.a = opacity
	
	# Interaction locking
	btn_construct.disabled = not active
	btn_raids.disabled = not active
	btn_farming.disabled = not active
	
	if not active:
		_clear_content()
		last_active_category = "" # Reset history when season ends

# ------------------------------------------------------------------------------
# CONTENT SWITCHING
# ------------------------------------------------------------------------------

func _on_tab_clicked(category: String) -> void:
	if not is_agency_active: return
	_load_menu(category)

func _load_menu(category: String) -> void:
	_clear_content()
	last_active_category = category # [NEW] Remember what we opened
	
	# [STRICT TYPING IMPLEMENTATION]
	match category:
		"construction":
			if build_menu_scene:
				var instance: BuildMenu = build_menu_scene.instantiate()
				seasonal_actions_panel.add_child(instance)
				instance.setup(cached_buildings)
				Loggie.msg("Menu Loaded: BuildMenu").info()
			else:
				_log_missing_scene("BuildMenu")

		"raids":
			if raid_menu_scene:
				var instance: RaidMenu = raid_menu_scene.instantiate()
				seasonal_actions_panel.add_child(instance)
				instance.setup() # RaidMenu.setup() takes optional args
				Loggie.msg("Menu Loaded: RaidMenu").info()
			else:
				_log_missing_scene("RaidMenu")

		"farming":
			if allocation_menu_scene:
				var instance: ClanAllocationMenu = allocation_menu_scene.instantiate()
				# Add to the root or a dedicated UI layer to ensure it's an overlay
				get_tree().root.add_child(instance)
				# Reset BottomBar selection so it doesn't look like a sub-tab
				_clear_content()
				last_active_category = ""
				Loggie.msg("Menu Loaded: ClanAllocationMenu (Overlay)").info()
			else:
				_log_missing_scene("ClanAllocationMenu")
				
		_:
			Loggie.msg("Unknown category: " + str(category)).warn()

func _clear_content() -> void:
	for child in seasonal_actions_panel.get_children():
		child.queue_free()

func _log_missing_scene(menu_name: String) -> void:
	Loggie.msg("Scene not assigned: " + menu_name).warn()
	var label = Label.new()
	label.text = menu_name + " Scene Missing"
	seasonal_actions_panel.add_child(label)

# ------------------------------------------------------------------------------
# UI RESPONSE TO PLACEMENT
# ------------------------------------------------------------------------------

func _on_building_placement_initiated(building_data: Resource) -> void:
	# User Request: Close the UI bar to increase screen real estate for this action.
	# We DO NOT clear 'last_active_category' here, so we can restore it later.
	_clear_content()

func _on_placement_cancelled(_data = null) -> void:
	# Note: SettlementManager handles the actual refund logic now.
	# We just handle UI restoration.
	
	if last_active_category != "":
		Loggie.msg("Restoring menu after cancel").info()
		_load_menu(last_active_category)

func _on_placement_completed(_data = null) -> void:
	# Placement success. Restore UI so player can build again if desired.
	
	if last_active_category != "":
		Loggie.msg("Restoring menu after placement").info()
		_load_menu(last_active_category)
