# res://ui/StorefrontUI.gd
extends Control

# --- Constants ---
const UNIT_DATA_PATH = "res://data/units"

# --- Node References ---
@onready var gold_label: Label = $PanelContainer/MarginContainer/TabContainer/Build/TreasuryDisplay/GoldLabel
@onready var wood_label: Label = $PanelContainer/MarginContainer/TabContainer/Build/TreasuryDisplay/WoodLabel
@onready var food_label: Label = $PanelContainer/MarginContainer/TabContainer/Build/TreasuryDisplay/FoodLabel
@onready var stone_label: Label = $PanelContainer/MarginContainer/TabContainer/Build/TreasuryDisplay/StoneLabel
@onready var buy_wall_button: Button = $PanelContainer/MarginContainer/TabContainer/Build/BuildButtons/BuyWallButton
@onready var buy_lumber_yard_button: Button = $PanelContainer/MarginContainer/TabContainer/Build/BuildButtons/BuyLumberYardButton
@onready var recruit_tab: VBoxContainer = $PanelContainer/MarginContainer/TabContainer/Recruit

# --- Data ---
var wall_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var lumber_yard_data: BuildingData = preload("res://data/buildings/LumberYard.tres")


func _ready() -> void:
	EventBus.treasury_updated.connect(_update_treasury_display)
	
	if SettlementManager.current_settlement:
		_update_treasury_display(SettlementManager.current_settlement.treasury)
	else:
		_update_treasury_display({"gold": 0, "wood": 0, "food": 0, "stone": 0})

	buy_wall_button.pressed.connect(_on_buy_button_pressed.bind(wall_data))
	buy_lumber_yard_button.pressed.connect(_on_buy_button_pressed.bind(lumber_yard_data))
	
	_create_recruit_buttons()


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

func _create_recruit_buttons() -> void:
	var dir = DirAccess.open(UNIT_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var unit_data: UnitData = load(UNIT_DATA_PATH.path_join(file_name))
				if unit_data:
					var button := Button.new()
					var cost_string : String
					for key in unit_data.spawn_cost:
						cost_string += "%s: %s " % [key, unit_data.spawn_cost[key]]
					button.text = "%s (%s)" % [unit_data.display_name, cost_string]
					button.pressed.connect(_on_recruit_button_pressed.bind(unit_data))
					recruit_tab.add_child(button)
			file_name = dir.get_next()
	else:
		printerr("Could not open directory: " + UNIT_DATA_PATH)

func _on_recruit_button_pressed(unit_data: UnitData) -> void:
	if not unit_data:
		return

	print("UI attempting to recruit '%s'." % unit_data.display_name)
	var purchase_successful: bool = SettlementManager.attempt_purchase(unit_data.spawn_cost)
	
	if purchase_successful:
		print("UI received purchase confirmation for '%s'." % unit_data.display_name)
		SettlementManager.recruit_unit(unit_data)
	else:
		print("UI received purchase failure for '%s'." % unit_data.display_name)
