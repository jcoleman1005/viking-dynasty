extends CanvasLayer

## Director's Lens - Live Economy Inspector
## Displays raw, unformatted data from the EconomyManager for debugging.

@onready var main_panel: Panel = %MainPanel
@onready var heating_label: Label = %HeatingLabel
@onready var verdict_label: Label = %VerdictLabel
@onready var food_demand_label: Label = %FoodDemandLabel
@onready var wood_demand_label: Label = %WoodDemandLabel

func _ready() -> void:
	# Start hidden
	hide()
	
	# Apply styling in code to avoid .tscn parsing errors
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.75)
	main_panel.add_theme_stylebox_override("panel", style_box)


func _process(_delta: float) -> void:
	# Only update data when visible to save performance
	if not visible:
		return
	
	_update_display()

func toggle() -> void:
	visible = not visible
	if visible:
		Loggie.msg("Director's Lens Activated").domain(LogDomains.UI).debug()
	else:
		Loggie.msg("Director's Lens Deactivated").domain(LogDomains.UI).debug()

func _update_display() -> void:
	# --- Heating Breakdown ---
	var heating_breakdown = EconomyManager.get_heating_demand_breakdown()
	heating_label.text = "Heating Breakdown: %s" % heating_breakdown.debug_string

	# --- Survival Verdict ---
	var settlement = SettlementManager.current_settlement
	if settlement:
		var stockpile = settlement.treasury
		var verdict_enum = EconomyManager.get_survival_verdict(stockpile)
		var verdict_str = EconomyManager.SurvivalVerdict.keys()[verdict_enum]
		verdict_label.text = "Survival Verdict: %s (%d)" % [verdict_str, verdict_enum]
	else:
		verdict_label.text = "Survival Verdict: N/A (No Settlement)"
		
	# --- Raw Winter Demand ---
	var forecast = EconomyManager.get_winter_forecast()
	food_demand_label.text = "Forecast Food Demand: %d" % forecast.get(GameResources.FOOD, 0)
	wood_demand_label.text = "Forecast Wood Demand: %d" % forecast.get(GameResources.WOOD, 0)
