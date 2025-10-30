# res://ui/StorefrontUI.gd
extends Control

# --- Node References ---
@onready var gold_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/GoldLabel
@onready var wood_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/WoodLabel
@onready var food_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/FoodLabel
@onready var stone_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TreasuryDisplay/StoneLabel

# --- Test Data ---
# In a real implementation, this would be populated by reading from a directory of .tres files
var wall_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")

func _ready() -> void:
	EventBus.treasury_updated.connect(_update_treasury_display)
	
	# Set initial state from the manager's loaded data
	if SettlementManager.current_settlement:
		_update_treasury_display(SettlementManager.current_settlement.treasury)
	else:
		# Fallback if UI loads before manager is ready
		_update_treasury_display({"gold": 0, "wood": 0, "food": 0, "stone": 0})

	# --- Connect Test Button ---
	# This connects the "Buy Wall" button's pressed signal to our purchase function
	# We pass the wall_data resource as an argument when connecting.
	$PanelContainer/MarginContainer/VBoxContainer/BuildButtons/BuyWallButton.pressed.connect(
		_on_buy_button_pressed.bind(wall_data)
	)

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
		# In a real game, this would now enter a "placement mode"
	else:
		print("UI received purchase failure for '%s'." % item_data.display_name)
