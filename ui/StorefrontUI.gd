# res://ui/StorefrontUI.gd
extends Control

# --- Node References ---
@onready var gold_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/GoldLabel
@onready var wood_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/WoodLabel
@onready var food_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/FoodLabel
@onready var stone_label: Label = $PanelContainer/MarginContainer/TabContainer/BuildTab/TreasuryDisplay/StoneLabel
@onready var buy_wall_button: Button = $PanelContainer/MarginContainer/TabContainer/BuildTab/BuildButtons/BuyWallButton
@onready var buy_lumber_yard_button: Button = $PanelContainer/MarginContainer/TabContainer/BuildTab/BuildButtons/BuyLumberYardButton
@onready var recruit_buttons_container: VBoxContainer = $PanelContainer/MarginContainer/TabContainer/RecruitTab/RecruitButtons
@onready var garrison_list_container: VBoxContainer = $PanelContainer/MarginContainer/TabContainer/RecruitTab/GarrisonList

# --- Exported Data ---
@export var available_buildings: Array[BuildingData] = []
@export var available_units: Array[UnitData] = []
@export var default_treasury_display: Dictionary = {"gold": 0, "wood": 0, "food": 0, "stone": 0}
@export var auto_load_units_from_directory: bool = true

# Legacy data (kept for fallback)
var wall_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var lumber_yard_data: BuildingData = preload("res://data/buildings/LumberYard.tres")

func _ready() -> void:
	EventBus.treasury_updated.connect(_update_treasury_display)
	EventBus.purchase_successful.connect(_on_purchase_successful)
	
	if SettlementManager.current_settlement:
		_update_treasury_display(SettlementManager.current_settlement.treasury)
	else:
		_update_treasury_display(default_treasury_display)

	buy_wall_button.pressed.connect(_on_buy_button_pressed.bind(wall_data))
	buy_lumber_yard_button.pressed.connect(_on_buy_button_pressed.bind(lumber_yard_data))
	
	# Load and setup recruit buttons
	_load_unit_data()
	_setup_recruit_buttons()
	_update_garrison_display()

func _load_unit_data() -> void:
	"""Scan res://data/units/ directory for .tres files and load them as UnitData"""
	var dir = DirAccess.open("res://data/units/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var unit_path = "res://data/units/" + file_name
				var unit_data = load(unit_path) as UnitData
				if unit_data:
					# Only load player-appropriate units (exclude enemy-only units)
					# Player units should have "Player" in their display name or specific naming convention
					if _is_player_unit(unit_data):
						available_units.append(unit_data)
						print("Loaded player unit data: %s" % unit_data.display_name)
					else:
						print("Skipped enemy unit data: %s" % unit_data.display_name)
			file_name = dir.get_next()
		print("Total player units loaded: %d" % available_units.size())

func _setup_recruit_buttons() -> void:
	"""Create recruit buttons for each available unit"""
	for unit_data in available_units:
		var button = Button.new()
		button.text = "%s (Cost: %s)" % [unit_data.display_name, _format_cost(unit_data.spawn_cost)]
		button.pressed.connect(_on_recruit_button_pressed.bind(unit_data))
		recruit_buttons_container.add_child(button)

func _is_player_unit(unit_data: UnitData) -> bool:
	"""Check if a unit is appropriate for player recruitment"""
	if not unit_data:
		return false
	
	# Check if the unit has "Player" in its display name
	if "Player" in unit_data.display_name:
		return true
	
	# Check if the unit data resource path contains "Player" 
	if "Player" in unit_data.resource_path:
		return true
	
	# Check if the scene points to a PlayerVikingRaider or other player unit
	if unit_data.scene_to_spawn:
		var scene_path = unit_data.scene_to_spawn.resource_path
		if "Player" in scene_path:
			return true
	
	# Fallback: exclude known enemy units by name
	var enemy_unit_names = ["Viking Raider"] # This is the enemy version
	if unit_data.display_name in enemy_unit_names:
		return false
	
	# Default to true for backwards compatibility with existing units
	return true

func _format_cost(cost: Dictionary) -> String:
	"""Format cost dictionary as readable string"""
	var cost_parts: Array[String] = []
	for resource in cost:
		cost_parts.append("%d %s" % [cost[resource], resource])
	return ", ".join(cost_parts)

func _get_safe_placement_position() -> Vector2i:
	"""Find a safe position to place a building, avoiding overlaps"""
	if not SettlementManager.current_settlement:
		return Vector2i(10, 15) # Fallback position
	
	# Get grid bounds from SettlementManager
	var grid_width = SettlementManager.grid_width
	var grid_height = SettlementManager.grid_height
	
	# Create a set of occupied positions for quick lookup
	var occupied_positions: Array[Vector2i] = []
	for building_entry in SettlementManager.current_settlement.placed_buildings:
		occupied_positions.append(building_entry["grid_position"])
	
	# Find the first available position using a spiral search pattern
	var center_x = grid_width / 2
	var center_y = grid_height / 2
	var max_radius = min(grid_width, grid_height) / 2
	
	# Start from center and spiral outward
	for radius in range(1, max_radius + 1):
		for angle_step in range(8 * radius): # More points for larger radii
			var angle = (angle_step * 2.0 * PI) / (8 * radius)
			var test_x = center_x + int(radius * cos(angle))
			var test_y = center_y + int(radius * sin(angle))
			var test_pos = Vector2i(test_x, test_y)
			
			# Check bounds
			if test_pos.x < 0 or test_pos.x >= grid_width or test_pos.y < 0 or test_pos.y >= grid_height:
				continue
			
			# Check if position is free
			if not test_pos in occupied_positions:
				print("Found safe placement position: %s" % test_pos)
				return test_pos
	
	# If no free position found, use a fallback with warning
	push_warning("No free placement position found, using fallback")
	return Vector2i(10, 15)

func _update_treasury_display(new_treasury: Dictionary) -> void:
	gold_label.text = "Gold: %d" % new_treasury.get("gold", 0)
	wood_label.text = "Wood: %d" % new_treasury.get("wood", 0)
	food_label.text = "Food: %d" % new_treasury.get("food", 0)
	stone_label.text = "Stone: %d" % new_treasury.get("stone", 0)

func _on_buy_button_pressed(item_data: BuildingData) -> void:
	if not item_data:
		return
	
	print("UI attempting to purchase '%s'." % item_data.display_name)
	var purchase_successful: bool = SettlementManager.attempt_purchase(item_data.build_cost)
	
	if purchase_successful:
		print("UI received purchase confirmation for '%s'." % item_data.display_name)
		var placement_pos = _get_safe_placement_position()
		var new_building = SettlementManager.place_building(item_data, placement_pos)
		
		if new_building and SettlementManager.current_settlement:
			var building_entry = {
				"resource_path": item_data.resource_path,
				"grid_position": placement_pos
			}
			SettlementManager.current_settlement.placed_buildings.append(building_entry)
			print("Added %s to persistent settlement data at %s." % [item_data.display_name, placement_pos])
			SettlementManager.save_settlement()
	else:
		print("UI received purchase failure for '%s'." % item_data.display_name)

func _on_recruit_button_pressed(unit_data: UnitData) -> void:
	"""Handle recruit button press"""
	if not unit_data:
		return
	
	print("UI attempting to recruit '%s'." % unit_data.display_name)
	var purchase_successful: bool = SettlementManager.attempt_purchase(unit_data.spawn_cost)
	
	if purchase_successful:
		print("UI received purchase confirmation for '%s'." % unit_data.display_name)
		SettlementManager.recruit_unit(unit_data)
	else:
		print("UI received purchase failure for '%s'." % unit_data.display_name)

func _on_purchase_successful(item_name: String) -> void:
	"""Handle purchase success event - refresh garrison display"""
	_update_garrison_display()

func _update_garrison_display() -> void:
	"""Update the garrison list display with current garrisoned units"""
	if not garrison_list_container:
		return
	
	# Clear existing display
	for child in garrison_list_container.get_children():
		child.queue_free()
	
	if not SettlementManager.current_settlement:
		var no_settlement_label = Label.new()
		no_settlement_label.text = "No settlement loaded"
		garrison_list_container.add_child(no_settlement_label)
		return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	
	if garrison.is_empty():
		var empty_garrison_label = Label.new()
		empty_garrison_label.text = "No units in garrison"
		garrison_list_container.add_child(empty_garrison_label)
		return
	
	# Add header
	var header_label = Label.new()
	header_label.text = "Current Garrison:"
	header_label.add_theme_font_size_override("font_size", 16)
	garrison_list_container.add_child(header_label)
	
	# Display each unit type and count
	for unit_path in garrison:
		var unit_count: int = garrison[unit_path]
		var unit_data: UnitData = load(unit_path)
		
		if unit_data:
			var unit_label = Label.new()
			unit_label.text = "• %s x%d" % [unit_data.display_name, unit_count]
			garrison_list_container.add_child(unit_label)
		else:
			var error_label = Label.new()
			error_label.text = "• Unknown unit x%d" % unit_count
			garrison_list_container.add_child(error_label)
	
	# Add total count
	var total_units = 0
	for unit_path in garrison:
		total_units += garrison[unit_path]
	
	var total_label = Label.new()
	total_label.text = "Total units: %d" % total_units
	total_label.add_theme_font_size_override("font_size", 12)
	garrison_list_container.add_child(total_label)
