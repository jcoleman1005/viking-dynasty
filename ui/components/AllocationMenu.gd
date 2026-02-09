class_name AllocationMenu
extends MarginContainer

## Component: AllocationMenu
## Handles Peasant assignment for Farming vs Woodcutting vs Construction.
## Replicates logic from SummerAllocation_UI with added Woodcutting logic.
## Integrated with WinterManager for seasonal forecasting.

# ------------------------------------------------------------------------------
# CONSTANTS
# ------------------------------------------------------------------------------

const WINTER_FOOD_PER_PEASANT: int = 1

# ------------------------------------------------------------------------------
# UI REFERENCES
# ------------------------------------------------------------------------------

@onready var farmers_slider: HSlider = %FarmersSlider
@onready var farmers_label: Label = %FarmersLabel
@onready var wood_slider: HSlider = %WoodSlider
@onready var wood_label: Label = %WoodLabel
@onready var yield_label: Label = %YieldLabel
@onready var commit_btn: Button = %CommitBtn

# New UI References for Winter Forecast
@onready var winter_demand_label: Label = %WinterDemandLabel
@onready var winter_status_label: Label = %WinterStatusLabel

# ------------------------------------------------------------------------------
# STATE
# ------------------------------------------------------------------------------

var total_peasants: int = 0

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------

func _ready() -> void:
	_fetch_population_data()
	
	# Bind category to identify source of change for clamping logic
	farmers_slider.value_changed.connect(func(v): _on_allocation_changed(v, "food"))
	wood_slider.value_changed.connect(func(v): _on_allocation_changed(v, "wood"))
	
	commit_btn.pressed.connect(_on_commit_pressed)
	
	# Connect to season changes to keep population data fresh if menu is open
	if EventBus:
		EventBus.season_changed.connect(func(_n, _d): _fetch_population_data())
	
	# Initial calculation (simulating a change from farmers to trigger updates)
	_on_allocation_changed(farmers_slider.value, "food")

func setup(_args = null) -> void:
	_fetch_population_data()

# ------------------------------------------------------------------------------
# LOGIC
# ------------------------------------------------------------------------------

func _fetch_population_data() -> void:
	if SettlementManager and SettlementManager.current_settlement:
		total_peasants = SettlementManager.current_settlement.population_peasants
		
		# Configure Sliders
		farmers_slider.max_value = total_peasants
		wood_slider.max_value = total_peasants
		
		# Fetch existing assignments using specific keys
		var assigns = SettlementManager.current_settlement.worker_assignments
		farmers_slider.value = assigns.get("food", 0)
		wood_slider.value = assigns.get("wood", 0)
		
		# Trigger update to refresh labels and forecast
		_on_allocation_changed(farmers_slider.value, "food")
		
	else:
		commit_btn.disabled = true
		yield_label.text = "No Settlement Data"

func _on_allocation_changed(val: float, source: String) -> void:
	var farmers = int(farmers_slider.value)
	var woodcutters = int(wood_slider.value)
	
	# 1. Clamp logic: Ensure Farmers + Wood <= Total
	# We adjust the *other* slider if the current one pushes the sum over the limit.
	if farmers + woodcutters > total_peasants:
		if source == "food":
			# User increased farmers, so reduce wood
			woodcutters = max(0, total_peasants - farmers)
			wood_slider.set_value_no_signal(woodcutters)
		elif source == "wood":
			# User increased wood, so reduce farmers
			farmers = max(0, total_peasants - woodcutters)
			farmers_slider.set_value_no_signal(farmers)
	
	# 2. Calculate Builders (The Remainder)
	var used_pop = farmers + woodcutters
	var builders = max(0, total_peasants - used_pop)
	
	# 3. Update Labels
	farmers_label.text = "Farmers: %d" % farmers
	wood_label.text = "Woodcutters: %d" % woodcutters
	
	# 4. Yield Prediction
	var projected_yields = {}
	if EconomyManager:
		# Pass dictionary for multi-resource prediction
		projected_yields = EconomyManager.calculate_hypothetical_yields({"food": farmers, "wood": woodcutters})
		
		var food_gain = projected_yields.get("food", 0)
		var wood_gain = projected_yields.get("wood", 0)
			
		yield_label.text = "Est: +%d Food, +%d Wood | %d Builders" % [food_gain, wood_gain, builders]
	
	# 5. Update Winter Forecast
	_update_winter_forecast(farmers, woodcutters, projected_yields)

func _update_winter_forecast(farmers: int, woodcutters: int, projected_yields: Dictionary) -> void:
	if not SettlementManager.current_settlement: return
	if not WinterManager or not EconomyManager: return
	
	# 1. Fetch the deterministic forecast from WinterManager
	var forecast = WinterManager.get_forecast_details()
	var forecast_label = "Forecast: %s (%d%% Demand)" % [forecast.label, forecast.percent]
	
	# 2. Get Base Demand from EconomyManager 
	# (This uses WinterManager's upcoming multiplier internally if set up correctly, 
	# or we rely on the forecast multiplier for manual calc if needed)
	var forecast_data = EconomyManager.get_winter_forecast()
	var base_food_demand = forecast_data.get("food", 0)
	var wood_demand = forecast_data.get("wood", 0)
	
	# 3. Adjust for Allocated Raiders (Not applicable in this menu, assumed 0 for safety)
	# If this menu eventually supports raiding, we would subtract (raiders * WINTER_FOOD_PER_PEASANT)
	var adjusted_food_demand = base_food_demand 
	
	# 4. Resources and Yields
	var treasury = SettlementManager.current_settlement.treasury
	var total_food_available = treasury.get("food", 0) + projected_yields.get("food", 0)
	var total_wood_available = treasury.get("wood", 0) + projected_yields.get("wood", 0)
	
	# 5. UI Updates
	if winter_demand_label:
		winter_demand_label.text = "%s\nProj. Winter Demand: %d Food, %d Wood" % [forecast_label, adjusted_food_demand, wood_demand]
	
	# 6. Net Calculation
	var food_net = total_food_available - adjusted_food_demand
	var wood_net = total_wood_available - wood_demand
	
	var status_text = ""
	var color = Color.LIGHT_GREEN
	
	if food_net < 0 or wood_net < 0:
		color = Color.RED
		status_text = "WARNING: Deficit Predicted ("
		if food_net < 0: status_text += "%d Food " % food_net
		if wood_net < 0: status_text += "%d Wood" % wood_net
		status_text += ")"
	else:
		status_text = "Winter Secure (Surplus: +%d Food)" % food_net
		
	if winter_status_label:
		winter_status_label.text = status_text
		winter_status_label.add_theme_color_override("font_color", color)

func _on_commit_pressed() -> void:
	var farmers = int(farmers_slider.value)
	var woodcutters = int(wood_slider.value)
	var builders = max(0, total_peasants - (farmers + woodcutters))
	
	if not SettlementManager or not SettlementManager.current_settlement:
		return

	# Send specific keys to the Manager
	if SettlementManager.has_method("batch_update_labor"):
		SettlementManager.batch_update_labor({
			"food": farmers,
			"wood": woodcutters,
			"construction": builders
		})
		Loggie.msg("Allocation Committed" + ("F:%d W:%d B:%d" % [farmers, woodcutters, builders])).domain(LogDomains.GAMEPLAY).info()
	else:
		Loggie.msg("SettlementManager missing 'batch_update_labor'").domain(LogDomains.UI).error()
