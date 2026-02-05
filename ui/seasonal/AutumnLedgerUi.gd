## AutumnLedgerUI.gd
## Handles the end-of-season accounting logic and display.
## Automatically opens when Autumn begins via EventBus.
class_name AutumnLedgerUI
extends Control

# Nodes (using unique names for stability)
@onready var settlement_name_label: Label = %SettlementName
@onready var food_stock_label: Label = %FoodStock
@onready var food_status_label: Label = %FoodStatus
@onready var wood_stock_label: Label = %WoodStock
@onready var wood_status_label: Label = %WoodStatus
@onready var outlook_label: Label = %WinterOutlookLabel
@onready var sign_button: Button = %SignButton

# Color Constants for Status
const COLOR_OK = Color.DARK_GREEN
const COLOR_FAIL = Color.FIREBRICK

func _ready() -> void:
	_setup_connections()
	# UI is hidden by default until the season change or manual toggle
	visible = false

## Connects buttons and global signals via code.
func _setup_connections() -> void:
	if not sign_button.pressed.is_connected(_on_sign_pressed):
		sign_button.pressed.connect(_on_sign_pressed)
	
	if EventBus.has_signal("season_changed"):
		EventBus.season_changed.connect(_on_season_changed)
	else:
		Loggie.msg("EventBus missing season_changed signal").domain(LogDomains.SYSTEM).error()

## Triggered automatically by the DynastyManager via EventBus.
func _on_season_changed(new_season_name: String) -> void:
	if new_season_name == "Autumn":
		_show_ledger()

## Standard bridge toggle for manual opening (e.g., from a HUD button).
func toggle_interface(interface_name: String = "") -> void:
	if interface_name != "" and interface_name != "autumn_ledger": 
		return
	
	if visible:
		visible = false
	else:
		_show_ledger()

## Logic for displaying the ledger with fresh data.
func _show_ledger() -> void:
	# Guard: Only allow display if we are actually in Autumn
	if DynastyManager.get_current_season_name() != "Autumn":
		visible = false
		return
		
	visible = true
	_initialize_data()
	move_to_front()

## Aggregates data from Managers and updates UI elements.
func _initialize_data() -> void:
	var forecast: Dictionary = EconomyManager.get_winter_forecast()
	var settlement = SettlementManager.current_settlement
	
	if not settlement:
		Loggie.msg("No current settlement for ledger").domain(LogDomains.UI).error()
		return

	# IDENTITY: Derive settlement name from resource filename.
	var raw_name: String = settlement.resource_path.get_file().get_basename()
	if raw_name.is_empty():
		raw_name = "Home Base"
	
	var display_name: String = raw_name.replace("_", " ").capitalize()
	var current_year: int = DynastyManager.get_current_year()
	
	settlement_name_label.text = "%s - Year %d" % [display_name, current_year]

	var treasury: Dictionary = settlement.treasury
	
	# Food Calculation (Expected keys from EconomyManager)
	var food_req: int = forecast.get("food", 0)
	var food_held: int = treasury.get("food", 0)
	_update_row(food_stock_label, food_status_label, food_held, food_req)

	# Wood Calculation (Expected keys from EconomyManager)
	var wood_req: int = forecast.get("wood", 0)
	var wood_held: int = treasury.get("wood", 0)
	_update_row(wood_stock_label, wood_status_label, wood_held, wood_req)

	# Status Outlook: Determines the overall survival probability.
	var is_ready: bool = (food_held >= food_req) and (wood_held >= wood_req)
	outlook_label.text = "WINTER OUTLOOK: " + ("SECURE" if is_ready else "DANGEROUS")
	outlook_label.modulate = COLOR_OK if is_ready else COLOR_FAIL

	# LOGGING: Using the verified .add() method for fluent data attachment.
	Loggie.msg("Autumn ledger initialized for " + display_name)\
		.domain(LogDomains.UI)\
		.add(forecast)\
		.info()

## Helper to set text and colors for resource rows.
func _update_row(val_label: Label, status_label: Label, held: int, req: int) -> void:
	val_label.text = str(held) + " / " + str(req)
	status_label.text = "[ OK ]" if held >= req else "[ DEFICIT ]"
	status_label.modulate = COLOR_OK if held >= req else COLOR_FAIL

## Finalizes the phase and notifies the game loop.
func _on_sign_pressed() -> void:
	Loggie.msg("Ledger signed and sealed").domain(LogDomains.ECONOMY).info()
	
	# Emit to EventBus for WinterManager/SeasonManager to process phase end.
	EventBus.autumn_resolved.emit()
	
	visible = false
