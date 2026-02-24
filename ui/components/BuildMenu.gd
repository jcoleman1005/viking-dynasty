#res://ui/components/BuildMenu.gd
class_name BuildMenu
extends MarginContainer

## Component: BuildMenu
## Displays available buildings and handles the financial transaction for construction.
## Instantiated by BottomBar.

# ------------------------------------------------------------------------------
# UI REFERENCES
# ------------------------------------------------------------------------------

@onready var grid_container: GridContainer = %GridContainer
@onready var feedback_label: Label = %FeedbackLabel

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------

var available_buildings: Array[Resource] = []

# ------------------------------------------------------------------------------
# PUBLIC INTERFACE
# ------------------------------------------------------------------------------

func setup(buildings: Array[Resource]) -> void:
	available_buildings = buildings
	_render_grid()

# ------------------------------------------------------------------------------
# INTERNAL LOGIC
# ------------------------------------------------------------------------------

func _render_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	
	if available_buildings.is_empty():
		feedback_label.text = "No buildings available."
		return
	
	feedback_label.text = ""
	
	for b_data in available_buildings:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.clip_text = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.expand_icon = true
		
		# Display Setup
		if "icon" in b_data and b_data.icon:
			btn.icon = b_data.icon
			btn.text = b_data.display_name # Text below icon
		else:
			btn.text = b_data.display_name if "display_name" in b_data else b_data.resource_name
		
		# Tooltip
		var cost_str = "Unknown"
		var has_cost = "build_cost" in b_data
		if has_cost:
			cost_str = _format_cost(b_data.build_cost)
		btn.tooltip_text = "%s\nCost: %s" % [b_data.display_name, cost_str]
		
		# Interaction
		btn.pressed.connect(_on_building_clicked.bind(b_data))
		
		# Affordability Visualization
		if has_cost and not EconomyManager.can_afford(b_data.build_cost):
			btn.modulate = Color(1, 1, 1, 0.5)
			btn.tooltip_text += "\n[CANNOT AFFORD]"
		
		grid_container.add_child(btn)

func _on_building_clicked(b_data: Resource) -> void:
	if b_data is EconomicBuildingData:
		# Economic buildings go through the Decree flow
		EventBus.decree_selection_mode_started.emit(b_data)
		Loggie.msg("Economic Building selected - Entering Decree Selection Mode").domain(LogDomains.UI).info()
		return

	# NBLM Trap 2 Fix: Validate purchase here
	if EconomyManager.attempt_purchase(b_data.build_cost):
		Loggie.msg("Building Purchased" + (b_data.display_name) ).info()
		EventBus.building_ready_for_placement.emit(b_data)
	else:
		# Provide visual feedback for failed purchase
		var msg = "Cannot afford %s!" % b_data.display_name
		feedback_label.text = msg
		Loggie.msg("Insufficient Funds" + (b_data.display_name)).warn()
		
		# Clear message after a delay if it hasn't been changed by another action
		get_tree().create_timer(3.0).timeout.connect(func():
			if feedback_label.text == msg:
				feedback_label.text = ""
		)

func _format_cost(cost: Dictionary) -> String:
	var s: PackedStringArray = []
	for k in cost:
		var name = GameResources.get_display_name(k) if GameResources else str(k)
		s.append("%d %s" % [cost[k], name])
	return ", ".join(s)
