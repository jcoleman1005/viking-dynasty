class_name BottomBar
extends VBoxContainer

## Component: BottomBar
## Manages Player Agency Tabs.
## Modular architecture: Instances child scenes for Build, Alloc, and Raid menus.
## acts as a persistent State Manager for refunds and navigation.

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
var pending_cost: Dictionary = {}

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
		# Refund Logic: Listen for cancellations and success
		if EventBus.has_signal("building_placement_cancelled"):
			EventBus.building_placement_cancelled.connect(_on_placement_cancelled)
		
		if EventBus.has_signal("building_placed"):
			EventBus.building_placed.connect(_on_placement_completed)
			
		# Cost Tracking: Capture cost when placement starts (initiated by BuildMenu)
		if EventBus.has_signal("building_ready_for_placement"):
			EventBus.building_ready_for_placement.connect(_on_building_placement_initiated)
	else:
		Loggie.msg("EventBus missing in BottomBar").domain(Loggie.LogDomains.UI).error()

# ------------------------------------------------------------------------------
# PUBLIC INTERFACE (Controller Access)
# ------------------------------------------------------------------------------

## Receives data from the Controller (MainGameUI)
func setup(buildings: Array[Resource], _units: Array[Resource] = []) -> void:
	cached_buildings = buildings
	# Removed .context() to fix runtime error
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

# ------------------------------------------------------------------------------
# CONTENT SWITCHING
# ------------------------------------------------------------------------------

func _on_tab_clicked(category: String) -> void:
	if not is_agency_active: return
	_load_menu(category)

func _load_menu(category: String) -> void:
	_clear_content()
	
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
				var instance: AllocationMenu = allocation_menu_scene.instantiate()
				seasonal_actions_panel.add_child(instance)
				instance.setup() # AllocationMenu.setup() takes optional args
				Loggie.msg("Menu Loaded: AllocationMenu").info()
			else:
				_log_missing_scene("AllocationMenu")
				
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
# REFUND & TRANSACTION LOGIC
# ------------------------------------------------------------------------------

func _on_building_placement_initiated(building_data: Resource) -> void:
	# Capture the cost so we can refund it if cancelled.
	# The purchase was already made by BuildMenu at this point.
	if "build_cost" in building_data and building_data.build_cost is Dictionary:
		pending_cost = building_data.build_cost.duplicate()

func _on_placement_cancelled() -> void:
	if not pending_cost.is_empty():
		if EconomyManager:
			EconomyManager.add_resources(pending_cost)
			Loggie.msg("Placement cancelled, refunded").domain(Loggie.LogDomains.ECONOMY).info()
			
			if EventBus.has_signal("purchase_successful"):
				EventBus.purchase_successful.emit("Refunded")
		
		pending_cost.clear()

func _on_placement_completed(_data = null) -> void:
	# Placement successful, resources consumed. Clear pending state.
	pending_cost.clear()
