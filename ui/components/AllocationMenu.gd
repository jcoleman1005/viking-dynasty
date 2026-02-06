#res://ui/components/AllocationMenu.gd
class_name AllocationMenu
extends MarginContainer

## Component: AllocationMenu
## Handles Peasant assignment for Farming vs Woodcutting vs Construction.
## Replicates logic from SummerAllocation_UI with added Woodcutting logic.

# ------------------------------------------------------------------------------
# UI REFERENCES
# ------------------------------------------------------------------------------

@onready var farmers_slider: HSlider = %FarmersSlider
@onready var farmers_label: Label = %FarmersLabel
@onready var wood_slider: HSlider = %WoodSlider
@onready var wood_label: Label = %WoodLabel
@onready var yield_label: Label = %YieldLabel
@onready var commit_btn: Button = %CommitBtn

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
	
	# Yield Prediction
	if EconomyManager:
		# Pass dictionary for multi-resource prediction
		var projected = EconomyManager.calculate_hypothetical_yields({"food": farmers, "wood": woodcutters})
		
		var food_gain = 0
		var wood_gain = 0
		
		if projected is Dictionary:
			food_gain = projected.get("food", 0)
			wood_gain = projected.get("wood", 0)
			
		yield_label.text = "Est: +%d Food, +%d Wood | %d Builders" % [food_gain, wood_gain, builders]

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
		Loggie.msg("Allocation Committed" + ("F:%d W:%d B:%d" % [farmers, woodcutters, builders])).info()
	else:
		Loggie.msg("SettlementManager missing 'batch_update_labor'").domain(LogDomains.UI).error()
