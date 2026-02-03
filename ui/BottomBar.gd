class_name BottomBar
extends PanelContainer

## Component: BottomBar
## Manages Player Agency Tabs (Construction, Raids, Farming).
## Acts as a passive component controlled by MainGameUI (The Controller).

# ------------------------------------------------------------------------------
# SIGNALS
# ------------------------------------------------------------------------------

signal scene_navigation_requested(scene_path: String)

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
var pending_cost: Dictionary = {} # Stores resources for potential refund

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
		# Refund Logic: Listen for placement cancellation
		if EventBus.has_signal("building_placement_cancelled"):
			EventBus.building_placement_cancelled.connect(_on_placement_cancelled)
		
		# Completion Logic: Clear pending cost on success
		# Using common naming convention; verify if signal is named 'building_placed' or 'placement_completed'
		if EventBus.has_signal("building_placed"):
			EventBus.building_placed.connect(_on_placement_completed)
		elif EventBus.has_signal("placement_completed"):
			EventBus.placement_completed.connect(_on_placement_completed)
	else:
		Loggie.msg("EventBus missing in BottomBar").domain(Loggie.LogDomains.UI).error()

# ------------------------------------------------------------------------------
# PUBLIC METHODS (Controller Interface)
# ------------------------------------------------------------------------------

## Receives data from the Controller (MainGameUI)
func setup(buildings: Array[Resource], _units: Array[Resource] = []) -> void:
	cached_buildings = buildings
	Loggie.msg("BottomBar configured").context(str(cached_buildings.size()) + " buildings").info()

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
		clear_selection()

## Clears the dynamic action strip
func clear_selection() -> void:
	for child in seasonal_actions_panel.get_children():
		child.queue_free()

# ------------------------------------------------------------------------------
# REFUND LOGIC
# ------------------------------------------------------------------------------

func _on_placement_cancelled() -> void:
	if not pending_cost.is_empty():
		if EconomyManager:
			EconomyManager.add_resources(pending_cost)
			Loggie.msg("Placement cancelled, refunded").domain(Loggie.LogDomains.ECONOMY).info()
			
			# Optional: Feedback via EventBus if the system uses it for toasts
			if EventBus.has_signal("purchase_successful"):
				EventBus.purchase_successful.emit("Refunded")
		
		pending_cost.clear()

func _on_placement_completed(_data = null) -> void:
	# Placement successful, cost is consumed. Clear pending state.
	pending_cost.clear()

# ------------------------------------------------------------------------------
# INTERNAL LOGIC
# ------------------------------------------------------------------------------

func _on_tab_clicked(category: String) -> void:
	if not is_agency_active: return
	_populate_action_strip(category)

func _populate_action_strip(category: String) -> void:
	clear_selection()
	
	match category:
		"construction":
			_render_construction_strip()
		"raids":
			_render_raids_strip()
		"farming":
			_render_farming_strip()

# ------------------------------------------------------------------------------
# RENDERERS
# ------------------------------------------------------------------------------

func _render_construction_strip() -> void:
	var container = HBoxContainer.new()
	container.set("theme_override_constants/separation", 10)
	seasonal_actions_panel.add_child(container)
	
	for building_data in cached_buildings:
		var btn = Button.new()
		# Display Name Fallback
		var btn_text = building_data.display_name if "display_name" in building_data else building_data.resource_name
		btn.text = btn_text
		
		# Tooltip Cost Formatting
		var tooltip_cost = "Unknown Cost"
		if "build_cost" in building_data and building_data.build_cost is Dictionary:
			tooltip_cost = _format_cost(building_data.build_cost)
		btn.tooltip_text = "Cost: " + tooltip_cost
		
		container.add_child(btn)
		
		# Placement Logic with Purchase Check
		btn.pressed.connect(func(): 
			if EconomyManager and EconomyManager.attempt_purchase(building_data.build_cost):
				# Purchase Successful: Commit to pending state
				pending_cost = building_data.build_cost.duplicate()
				Loggie.msg("Purchased building").context(btn_text).info()
				
				# Hand off to placement system
				if EventBus.has_signal("building_ready_for_placement"):
					EventBus.building_ready_for_placement.emit(building_data)
				else:
					Loggie.msg("Missing signal: building_ready_for_placement").domain(Loggie.LogDomains.UI).error()
					# Critical Error: Refund immediately if we can't emit
					EconomyManager.add_resources(pending_cost)
					pending_cost.clear()
			else:
				# Purchase Failed
				Loggie.msg("Insufficient funds for building").context(btn_text).warn()
				# Future: Visual Shake/Audio Cue
		)

func _render_raids_strip() -> void:
	var container = HBoxContainer.new()
	container.set("theme_override_constants/separation", 10)
	seasonal_actions_panel.add_child(container)
	
	var btn_map = Button.new()
	btn_map.text = "Open World Map"
	btn_map.tooltip_text = "Travel to the Macro Map to identify raid targets."
	container.add_child(btn_map)
	
	btn_map.pressed.connect(func():
		if GameScenes and "WORLD_MAP" in GameScenes:
			scene_navigation_requested.emit(GameScenes.WORLD_MAP)
		else:
			Loggie.msg("GameScenes.WORLD_MAP not defined").domain(Loggie.LogDomains.UI).error()
	)
	
	var info = Label.new()
	info.text = " (Select region to raid)"
	container.add_child(info)

func _render_farming_strip() -> void:
	var label = Label.new()
	label.text = "Assign Peasants / Thralls (Coming Soon)"
	seasonal_actions_panel.add_child(label)

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------

func _format_cost(cost: Dictionary) -> String:
	var s: PackedStringArray = []
	for k in cost:
		var display_name = GameResources.get_display_name(k)
		s.append("%d %s" % [cost[k], display_name])
	return ", ".join(s)
