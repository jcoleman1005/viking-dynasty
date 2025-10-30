# res://ui/StorefrontUI.gd
extends Control

# --- Node References ---
@onready var gold_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/GoldLabel
@onready var wood_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/WoodLabel
@onready var food_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/FoodLabel
@onready var stone_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/StoneLabel
@onready var buy_wall_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BuildButtons/BuyWallButton
@onready var buy_lumber_yard_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BuildButtons/BuyLumberYardButton

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
