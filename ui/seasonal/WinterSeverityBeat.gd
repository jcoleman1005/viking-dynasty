# res://ui/seasonal/WinterSeverityBeat.gd
extends Control

signal severity_resolved(choice: String)

@onready var verdict_label := %VerdictLabel
@onready var bill_table := %BillTable
@onready var crisis_options := %CrisisOptions
@onready var emergency_purchase_btn := %EmergencyPurchaseBtn
@onready var ration_hard_btn := %RationHardBtn
@onready var family_shares_btn := %FamilySharesBtn
@onready var confirm_btn := %ConfirmBtn

var _is_crisis := false
var _food_deficit := 0
var _wood_deficit := 0

func _ready() -> void:
	emergency_purchase_btn.pressed.connect(_on_crisis_choice.bind("gold"))
	ration_hard_btn.pressed.connect(_on_crisis_choice.bind("ration"))
	family_shares_btn.pressed.connect(_on_crisis_choice.bind("family"))
	confirm_btn.pressed.connect(_on_confirm_pressed)

func _on_season_changed(season_name: String, context: Dictionary) -> void:
	if season_name == "Winter":
		_setup(context)

func _setup(context: Dictionary) -> void:
	var forecast = context.get("forecast", {})
	var treasury = context.get("treasury", {})
	
	var food_stored = int(treasury.get("food", 0))
	var wood_stored = int(treasury.get("wood", 0))
	var food_demand = int(forecast.get("food", 0))
	var wood_demand = int(forecast.get("wood", 0))
	
	_food_deficit = max(0, food_demand - food_stored)
	_wood_deficit = max(0, wood_demand - wood_stored)
	_is_crisis = (_food_deficit > 0 or _wood_deficit > 0)
	
	_populate_table("Food", food_stored, food_demand)
	_populate_table("Wood", wood_stored, wood_demand)
	
	if _is_crisis:
		verdict_label.text = "You cannot cover the demand."
		verdict_label.add_theme_color_override("font_color", Color("#c84040"))
		crisis_options.show()
		confirm_btn.hide()
		
		# Check gold for emergency purchase
		var gold_cost = (_food_deficit + _wood_deficit) * 2 # Example cost
		var gold_stored = int(treasury.get("gold", 0))
		emergency_purchase_btn.text = "Emergency Purchase (%d Gold)" % gold_cost
		emergency_purchase_btn.disabled = (gold_stored < gold_cost)
	else:
		verdict_label.text = "The stores will hold."
		verdict_label.add_theme_color_override("font_color", Color("#7ab648"))
		crisis_options.hide()
		confirm_btn.show()

func _populate_table(res_name: String, stored: int, demand: int) -> void:
	var name_lbl = Label.new()
	name_lbl.text = res_name
	bill_table.add_child(name_lbl)
	
	var stored_lbl = Label.new()
	stored_lbl.text = str(stored)
	bill_table.add_child(stored_lbl)
	
	var demand_lbl = Label.new()
	demand_lbl.text = str(demand)
	bill_table.add_child(demand_lbl)
	
	var net = stored - demand
	var net_lbl = Label.new()
	net_lbl.text = str(net)
	if net < 0:
		net_lbl.add_theme_color_override("font_color", Color("#c84040"))
	else:
		net_lbl.add_theme_color_override("font_color", Color("#7ab648"))
	bill_table.add_child(net_lbl)

func _on_crisis_choice(choice: String) -> void:
	# Apply logic via WinterManager or DynastyManager
	match choice:
		"gold":
			WinterManager.resolve_crisis_with_gold()
		"ration":
			# Handled in DynastyManager or SettlementManager
			pass
		"family":
			WinterManager.resolve_crisis_with_family_sacrifice()
			
	severity_resolved.emit(choice)
	queue_free()

func _on_confirm_pressed() -> void:
	# Normal consumption
	EconomyManager.apply_winter_consumption(WinterManager.winter_consumption_report)
	severity_resolved.emit("secure")
	queue_free()
