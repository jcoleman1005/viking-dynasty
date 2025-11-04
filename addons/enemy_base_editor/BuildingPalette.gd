@tool
extends VBoxContainer
class_name BuildingPalette

signal building_selected(building_data: BuildingData)

# UI Elements
var search_line_edit: LineEdit
var category_option: OptionButton
var buildings_scroll: ScrollContainer
var buildings_container: VBoxContainer

# Data
var all_buildings: Array[BuildingData] = []
var filtered_buildings: Array[BuildingData] = []
var selected_building_button: Button = null

# Categories
enum BuildingCategory {
	ALL,
	DEFENSIVE,
	ECONOMIC,
	RESIDENTIAL,
	RELIGIOUS,
	UTILITY
}

var category_names = {
	BuildingCategory.ALL: "All Buildings",
	BuildingCategory.DEFENSIVE: "Defensive",
	BuildingCategory.ECONOMIC: "Economic", 
	BuildingCategory.RESIDENTIAL: "Residential",
	BuildingCategory.RELIGIOUS: "Religious",
	BuildingCategory.UTILITY: "Utility"
}

func _ready():
	name = "BuildingPalette"
	setup_ui()

func setup_ui():
	# Header
	var header = Label.new()
	header.text = "Building Palette"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)
	
	# Search
	var search_container = HBoxContainer.new()
	add_child(search_container)
	
	var search_label = Label.new()
	search_label.text = "Search:"
	search_container.add_child(search_label)
	
	search_line_edit = LineEdit.new()
	search_line_edit.placeholder_text = "Filter buildings..."
	search_line_edit.text_changed.connect(_on_search_changed)
	search_container.add_child(search_line_edit)
	
	# Category filter
	var category_container = HBoxContainer.new()
	add_child(category_container)
	
	var category_label = Label.new()
	category_label.text = "Category:"
	category_container.add_child(category_label)
	
	category_option = OptionButton.new()
	for category in category_names:
		category_option.add_item(category_names[category])
	category_option.selected = BuildingCategory.ALL
	category_option.item_selected.connect(_on_category_changed)
	category_container.add_child(category_option)
	
	# Separator
	var separator = HSeparator.new()
	add_child(separator)
	
	# Buildings list
	buildings_scroll = ScrollContainer.new()
	buildings_scroll.custom_minimum_size = Vector2(0, 300)
	add_child(buildings_scroll)
	
	buildings_container = VBoxContainer.new()
	buildings_scroll.add_child(buildings_container)

func set_buildings(buildings: Array[BuildingData]):
	all_buildings = buildings
	_update_building_list()

func _update_building_list():
	# Clear existing buttons
	for child in buildings_container.get_children():
		child.queue_free()
	
	# Filter buildings
	_filter_buildings()
	
	# Create buttons for filtered buildings
	for building_data in filtered_buildings:
		_create_building_button(building_data)

func _filter_buildings():
	filtered_buildings.clear()
	
	var search_text = search_line_edit.text.to_lower() if search_line_edit else ""
	var selected_category = category_option.selected if category_option else BuildingCategory.ALL
	
	for building_data in all_buildings:
		# Apply search filter
		if search_text != "" and not building_data.display_name.to_lower().contains(search_text):
			continue
		
		# Apply category filter
		if selected_category != BuildingCategory.ALL:
			var building_category = _get_building_category(building_data)
			if building_category != selected_category:
				continue
		
		filtered_buildings.append(building_data)

func _get_building_category(building_data: BuildingData) -> BuildingCategory:
	var name = building_data.display_name.to_lower()
	
	if building_data.is_defensive_structure or "wall" in name or "tower" in name or "watchtower" in name:
		return BuildingCategory.DEFENSIVE
	elif building_data is EconomicBuildingData or "lumber" in name or "yard" in name or "mine" in name:
		return BuildingCategory.ECONOMIC
	elif "chapel" in name or "library" in name or "scriptorium" in name or "monastery" in name:
		return BuildingCategory.RELIGIOUS
	elif "hall" in name or "house" in name or "quarters" in name:
		return BuildingCategory.RESIDENTIAL
	else:
		return BuildingCategory.UTILITY

func _create_building_button(building_data: BuildingData):
	var button_container = HBoxContainer.new()
	buildings_container.add_child(button_container)
	
	# Building button
	var button = Button.new()
	button.custom_minimum_size = Vector2(200, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button_container.add_child(button)
	
	# Icon (if available)
	if building_data.icon:
		button.icon = building_data.icon
	
	# Building info
	var info_text = building_data.display_name
	if building_data.build_cost and not building_data.build_cost.is_empty():
		info_text += "\n"
		var cost_parts: Array[String] = []
		for resource in building_data.build_cost:
			cost_parts.append("%s: %d" % [resource.capitalize(), building_data.build_cost[resource]])
		info_text += "Cost: " + ", ".join(cost_parts)
	
	button.text = info_text
	button.pressed.connect(_on_building_button_pressed.bind(building_data, button))
	
	# Health/stats info
	var stats_label = Label.new()
	var stats_text = "HP: %d" % building_data.max_health
	if building_data.is_defensive_structure:
		stats_text += " | DMG: %d | Range: %.0f" % [building_data.attack_damage, building_data.attack_range]
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 10)
	button_container.add_child(stats_label)

func _on_building_button_pressed(building_data: BuildingData, button: Button):
	# Update selection visual
	if selected_building_button:
		selected_building_button.modulate = Color.WHITE
	
	selected_building_button = button
	button.modulate = Color(1.2, 1.2, 0.8)  # Highlight selected
	
	# Emit signal
	building_selected.emit(building_data)

func _on_search_changed(new_text: String):
	_update_building_list()

func _on_category_changed(index: int):
	_update_building_list()

func clear_selection():
	if selected_building_button:
		selected_building_button.modulate = Color.WHITE
		selected_building_button = null

# Utility function to get building info for tooltips
func get_building_tooltip(building_data: BuildingData) -> String:
	var tooltip = building_data.display_name + "\n\n"
	
	# Health
	tooltip += "Health: %d HP\n" % building_data.max_health
	
	# Cost
	if building_data.build_cost and not building_data.build_cost.is_empty():
		tooltip += "Cost: "
		var cost_parts: Array[String] = []
		for resource in building_data.build_cost:
			cost_parts.append("%s %d" % [resource.capitalize(), building_data.build_cost[resource]])
		tooltip += ", ".join(cost_parts) + "\n"
	
	# Defensive stats
	if building_data.is_defensive_structure:
		tooltip += "Damage: %d\n" % building_data.attack_damage
		tooltip += "Range: %.0f\n" % building_data.attack_range
		tooltip += "Attack Speed: %.1f/sec\n" % building_data.attack_speed
	
	# Economic info
	if building_data is EconomicBuildingData:
		var eco_data = building_data as EconomicBuildingData
		tooltip += "Produces: %s (%d per cycle)\n" % [eco_data.resource_type.capitalize(), eco_data.fixed_payout_amount]
	
	# Grid size
	tooltip += "Size: %dx%d" % [building_data.grid_size.x, building_data.grid_size.y]
	
	return tooltip
