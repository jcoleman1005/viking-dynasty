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

# --- Data ---
var wall_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var lumber_yard_data: BuildingData = preload("res://data/buildings/LumberYard.tres")

# Array to store all available unit data
var available_units: Array[UnitData] = []

func _ready() -> void:
	EventBus.treasury_updated.connect(_update_treasury_display)
	EventBus.purchase_successful.connect(_on_purchase_successful)
	
	if SettlementManager.current_settlement:
		_update_treasury_display(SettlementManager.current_settlement.treasury)
	else:
		_update_treasury_display({"gold": 0, "wood": 0, "food": 0, "stone": 0})

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
					available_units.append(unit_data)
					print("Loaded unit data: %s" % unit_data.display_name)
			file_name = dir.get_next()
		print("Total units loaded: %d" % available_units.size())

func _setup_recruit_buttons() -> void:
	"""Create recruit buttons for each available unit"""
	for unit_data in available_units:
		var button = Button.new()
		button.text = "%s (Cost: %s)" % [unit_data.display_name, _format_cost(unit_data.spawn_cost)]
		button.pressed.connect(_on_recruit_button_pressed.bind(unit_data))
		recruit_buttons_container.add_child(button)

func _format_cost(cost: Dictionary) -> String:
	"""Format cost dictionary as readable string"""
	var cost_parts: Array[String] = []
	for resource in cost:
		cost_parts.append("%d %s" % [cost[resource], resource])
	return ", ".join(cost_parts)

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
		var test_grid_pos = Vector2i(10, 15) # TODO: Replace with player input
		var new_building = SettlementManager.place_building(item_data, test_grid_pos)
		
		if new_building and SettlementManager.current_settlement:
			var building_entry = {
				"resource_path": item_data.resource_path,
				"grid_position": test_grid_pos
			}
			SettlementManager.current_settlement.placed_buildings.append(building_entry)
			print("Added %s to persistent settlement data." % item_data.display_name)
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
