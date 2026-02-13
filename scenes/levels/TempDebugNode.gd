extends Node

func _ready():
	await get_tree().process_frame
	_test_economy_preservation()
	queue_free()

func _test_economy_preservation():
	Loggie.msg("=== QA-001: Economy Preservation Test ===").domain(LogDomains.SETTLEMENT).info()
	
	if not SettlementManager.current_settlement:
		Loggie.msg("FAIL: No settlement loaded.").domain(LogDomains.SETTLEMENT).error()
		return

	# 1. Baseline: Yield from raw worker count (The "Old Way")
	var baseline_workers = {"food": 50, "wood": 0}
	var baseline_yield = EconomyManager.calculate_hypothetical_yields(baseline_workers)
	
	# 2. Refactor: Yield from Households (The "New Way")
	SettlementManager.current_settlement.households.clear()
	
	# Create 5 households of 10, all on HARVEST
	for i in range(5):
		var house = HouseholdData.new()
		house.member_count = 10
		house.current_oath = HouseholdData.SeasonalOath.HARVEST
		house.labor_efficiency = 1.0
		SettlementManager.current_settlement.households.append(house)
	
	var menu_script = load("res://ui/settlement/ClanAllocationMenu.gd").new()
	var payload = menu_script._calculate_totals_from_oaths()
	var refactor_yield = EconomyManager.calculate_hypothetical_yields(payload)
	
	# 3. Assertions
	if payload.food != 50:
		Loggie.msg("FAIL: Aggregator payload mismatch. Expected 50, Got %d" % payload.food).domain(LogDomains.SETTLEMENT).error()
		return

	if refactor_yield.food == baseline_yield.food:
		Loggie.msg("PASS: Economic output remains identical after refactor.").domain(LogDomains.SETTLEMENT).info()
		Loggie.msg("      Yield: %d food" % refactor_yield.food).domain(LogDomains.SETTLEMENT).info()
	else:
		Loggie.msg("FAIL: Yield discrepancy! Baseline: %d, Refactor: %d" % [baseline_yield.food, refactor_yield.food]).domain(LogDomains.SETTLEMENT).error()
