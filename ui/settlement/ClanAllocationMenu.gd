extends CanvasLayer
class_name ClanAllocationMenu

## ClanAllocationMenu - The new labor assignment interface.
## Converts social 'Oaths' into mechanical 'Labor Payloads'.

signal close_requested

# --- AGGREGATOR LAYER (Task 1.3) ---

func _calculate_totals_from_oaths() -> Dictionary:
	var totals = {
		"food": 0,
		"wood": 0,
		"construction": 0
	}

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return totals

	for house in settlement.households:
		if not house: continue
		
		# Calculate effective labor based on size and efficiency
		var labor = int(house.member_count * house.labor_efficiency)

		match house.current_oath:
			HouseholdData.SeasonalOath.HARVEST:
				totals["food"] += labor
			HouseholdData.SeasonalOath.TIMBER:
				totals["wood"] += labor
			HouseholdData.SeasonalOath.BUILD:
				totals["construction"] += labor
			HouseholdData.SeasonalOath.RAID:
				# Intentionally excluded from economic labor payload.
				pass 
			HouseholdData.SeasonalOath.IDLE:
				pass  # No contribution

	return totals

func apply_oaths() -> void:
	var payload = _calculate_totals_from_oaths()
	
	# Scaffolding for Task 1.3.2 verification
	Loggie.msg("Clan Council: Labor payload calculated: %s" % str(payload)).domain(LogDomains.ECONOMY).info()
	
	SettlementManager.batch_update_labor(payload)

# --- UI LOGIC (Task 2.0) ---

@onready var household_list: VBoxContainer = %HouseholdList
@onready var apply_button: Button = %ApplyOathsButton
@onready var close_button: Button = %CloseButton 

@onready var food_summary: Label = %FoodSummaryLabel
@onready var wood_summary: Label = %WoodSummaryLabel
@onready var build_summary: Label = %BuildSummaryLabel
@onready var raid_summary: Label = %RaidSummaryLabel

const HouseholdOathRow = preload("res://ui/settlement/HouseholdOathRow.tscn")

func _ready() -> void:
	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Initial populate
	_populate_households()

func _populate_households() -> void:
	if not household_list: return
	
	# Clear existing rows
	for child in household_list.get_children():
		child.queue_free()

	var settlement = SettlementManager.current_settlement
	if not settlement: return

	# Ensure households are reconciled before showing
	SettlementManager.reconcile_households()

	for house in settlement.households:
		var row = HouseholdOathRow.instantiate()
		household_list.add_child(row)
		row.setup(house)

	_update_summary()

func _update_summary() -> void:
	var totals = _calculate_totals_from_oaths()
	var warband = _calculate_warband_from_oaths()
	
	if food_summary: food_summary.text = "Food Workers: %d" % totals.food
	if wood_summary: wood_summary.text = "Wood Workers: %d" % totals.wood
	if build_summary: build_summary.text = "Builders: %d" % totals.construction
	if raid_summary: raid_summary.text = "Raiders: %d" % warband.raiders

func _on_apply_pressed() -> void:
	apply_oaths()
	_update_summary()
	Loggie.msg("Seasonal Oaths Pledged.").domain(LogDomains.UI).info()
	close_requested.emit()
	queue_free() # Close overlay on success
	queue_free() # Close overlay on apply
func _on_close_pressed() -> void:
	close_requested.emit()
	queue_free() # Clean up when closed as an overlay


# --- MILITARY SEPARATION (Task 1.4) ---

func _calculate_warband_from_oaths() -> Dictionary:
	var warband = {
		"raiders": 0,
		"households": []  # Track which households are raiding
	}

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return warband

	for house in settlement.households:
		if house.current_oath == HouseholdData.SeasonalOath.RAID:
			warband["raiders"] += house.member_count
			warband["households"].append(house)

	return warband

func apply_raid_casualties(casualties: int) -> void:
	var raiding_households = []

	var settlement = SettlementManager.current_settlement
	if not settlement: return

	for house in settlement.households:
		if house.current_oath == HouseholdData.SeasonalOath.RAID:
			raiding_households.append(house)

	if raiding_households.is_empty():
		return

	# Distribute casualties proportionally
	var per_house = casualties / raiding_households.size()
	var remainder = casualties % raiding_households.size()

	for i in range(raiding_households.size()):
		var house = raiding_households[i]
		var loss = per_house
		if i < remainder:
			loss += 1
			
		house.member_count = max(0, house.member_count - loss)

	# Reconcile population after casualties to keep sync with peasant_count
	# Note: We need to ensure SettlementManager has updated the total peasant count
	# based on the casualties before calling reconcile_households().
	SettlementManager.reconcile_households()
