extends Node

## DIAGNOSTIC TOOL: Economy Logic Probe (V2 - Harvest Edition)
## AUDIT GOAL: Verify why Harvest Yield (Food) is incorrect or missing.
## Attach this to the "Debugger" node inside AutumnLedgerUI.

func _ready() -> void:
	# Wait for the Ledger to fully initialize data
	await get_tree().process_frame
	await get_tree().process_frame
	
	_perform_harvest_audit()

func _perform_harvest_audit() -> void:
	Loggie.msg("--- HARVEST YIELD AUDIT ---").domain(LogDomains.ECONOMY).info()
	
	# 1. Calculate Theoretical Yield (What SHOULD happen)
	# This runs the math fresh, right now.
	var projection = EconomyManager.get_projected_income()
	var yearly_food = projection.get("food", 0)
	
	# In this logic, Autumn Harvest = 100% of yearly food projection
	var theoretical_harvest = yearly_food 
	
	Loggie.msg("1. THEORETICAL CALCULATION").domain(LogDomains.ECONOMY).info()
	Loggie.msg("   > EconomyManager Projection (Food): %d" % yearly_food).domain(LogDomains.ECONOMY).info()
	
	# Deep Dive: Break it down by buildings to find where the zero is coming from
	var settlement = SettlementManager.current_settlement
	var found_farms = 0
	if settlement:
		Loggie.msg("   > Building Breakdown (Food Sources):").domain(LogDomains.ECONOMY).info()
		for entry in settlement.placed_buildings:
			# Safety check for missing resource paths
			if not entry.get("resource_path"): continue
			
			var b_data = load(entry["resource_path"])
			# Check if it's an economic building that produces food
			if b_data is EconomicBuildingData and b_data.resource_type.to_lower() == "food":
				found_farms += 1
				var p_count = entry.get("peasant_count", 0)
				var passive = b_data.base_passive_output
				var output = p_count * passive
				
				Loggie.msg("     - [%s] Workers: %d | Base Output: %d | Total: %d" % [b_data.display_name, p_count, passive, output]).domain(LogDomains.ECONOMY).info()
	
	if found_farms == 0:
		Loggie.msg("     [!] No food-producing buildings found in settlement.").domain(LogDomains.ECONOMY).warn()

	# 2. Check UI State (What DID happen)
	var parent = get_parent() # AutumnLedgerUI
	if not parent:
		Loggie.msg("CRITICAL: No Parent Found.").domain(LogDomains.ECONOMY).error()
		return
		
	if not "current_report" in parent or not parent.current_report:
		Loggie.msg("CRITICAL: parent.current_report is null. Initialization failed.").domain(LogDomains.ECONOMY).error()
		return
		
	# Check the actual value stored in the report object
	var report_yield = 0
	if "harvest_yield" in parent.current_report:
		report_yield = parent.current_report.harvest_yield
	else:
		Loggie.msg("CRITICAL: 'harvest_yield' property missing from AutumnReport class.").domain(LogDomains.ECONOMY).error()
	
	Loggie.msg("2. UI REPORT STATE").domain(LogDomains.ECONOMY).info()
	Loggie.msg("   > AutumnReport.harvest_yield: %d" % report_yield).domain(LogDomains.ECONOMY).info()
	
	# 3. Compare & Diagnose
	if report_yield != theoretical_harvest:
		Loggie.msg("MISMATCH DETECTED: Theoretical (%d) != Report (%d)" % [theoretical_harvest, report_yield]).domain(LogDomains.ECONOMY).error()
		
		if report_yield == 0 and theoretical_harvest > 0:
			Loggie.msg("DIAGNOSIS: The signal payload (context_data) likely lacked the 'food' key.").domain(LogDomains.ECONOMY).warn()
			Loggie.msg("Action: Check 'DynastyManager._advance_season' to ensure 'payout' is added to context.").domain(LogDomains.ECONOMY).warn()
		elif report_yield < theoretical_harvest:
			Loggie.msg("DIAGNOSIS: The report was generated using OLD data.").domain(LogDomains.ECONOMY).warn()
			Loggie.msg("Action: Workers might have been assigned AFTER the payout was calculated.").domain(LogDomains.ECONOMY).warn()
	else:
		Loggie.msg("MATCH: Calculation aligns with UI Report. (If both are 0, assign workers!)").domain(LogDomains.ECONOMY).info()
