# res://ui/components/DateAndControls.gd
class_name DateAndControls
extends PanelContainer

@export var label_date: Label
@export var btn_end_year: Button

func _ready() -> void:
	if btn_end_year:
		btn_end_year.pressed.connect(_on_end_year_pressed)
		
	DynastyManager.year_ended.connect(_update_date)
	DynastyManager.jarl_stats_updated.connect(func(_j): _update_date())
	EventBus.treasury_updated.connect(_on_treasury_updated)
	
	# Listen for the settlement loading so we don't miss the data
	EventBus.settlement_loaded.connect(func(_data): 
		_update_winter_tooltip() 
	)
	
	_update_date()
	
	# Try immediately, but if data isn't ready, wait a frame
	if SettlementManager.current_settlement:
		_update_winter_tooltip()
	else:
		# Safety fallback: Wait for the next frame and try again
		await get_tree().process_frame
		_update_winter_tooltip()

func _update_date() -> void:
	if not label_date: return
	var jarl = DynastyManager.current_jarl
	if jarl:
		label_date.text = "Year %d" % (jarl.years_since_action + 1)
	else:
		label_date.text = "Year 1"

func _on_end_year_pressed() -> void:
	EventBus.end_year_requested.emit()

func _on_treasury_updated(_treasury: Dictionary) -> void:
	_update_winter_tooltip()

func _update_winter_tooltip() -> void:
	if not btn_end_year: return
	
	# DEBUG: Print to confirm this function is actually running
	# print("DEBUG: Updating Winter Tooltip...") 
	
	if not SettlementManager.current_settlement: 
		# print("DEBUG: No Settlement Data found yet.")
		return
	
	# 1. Gather Data
	var current_food = SettlementManager.current_settlement.treasury.get("food", 0)
	var report = WinterManager.calculate_winter_demand(SettlementManager.current_settlement)
	var demand = report.get("food_demand", 0)
	
	# 2. Analyze Risk
	var status = "Safe"
	if current_food < demand:
		status = "CRITICAL: STARVATION RISK"
	elif current_food < (demand * 1.5):
		status = "Supplies Tight"
		
	# 3. Build Tooltip
	var text = "End the Year\n"
	text += "Advance time and enter the Winter Court.\n\n"
	text += "--- Winter Forecast ---\n"
	text += "Current Food: %d\n" % current_food
	text += "Projected Demand: ~%d\n" % demand
	text += "(%d Peasants + %d Warbands)\n" % [
		SettlementManager.current_settlement.population_peasants,
		SettlementManager.current_settlement.warbands.size()
	]
	text += "\nSTATUS: %s" % status
	
	btn_end_year.tooltip_text = text
	print("DEBUG: Tooltip text set successfully.")
