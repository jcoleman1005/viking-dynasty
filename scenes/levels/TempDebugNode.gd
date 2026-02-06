class_name AutumnDebugger
extends Node

## Debugging Tool for the Autumn Ledger.
## Checks if data exists to populate the Autumn UI.

func _ready() -> void:
	await get_tree().process_frame
	run_diagnostics()

func run_diagnostics() -> void:
	print("\n=== 🕵️ AUTUMN DIAGNOSTICS REPORT ===")

	# 1. Check if Settlement Exists
	var settlement = SettlementManager.current_settlement
	if not settlement:
		print("❌ CRITICAL: No Settlement Loaded via SettlementManager.")
		return
	else:
		print("✅ Settlement Loaded: ", settlement.resource_path)
		print("   Treasury: ", settlement.treasury)

	# 2. Check Forecast (Demand)
	if EconomyManager.has_method("get_winter_forecast"):
		var forecast = EconomyManager.get_winter_forecast()
		print("✅ Winter Forecast (Demand): ", forecast)
		if forecast.is_empty():
			print("⚠️ WARNING: Forecast is empty. Labels will read 0.")
	else:
		print("❌ EconomyManager missing 'get_winter_forecast()'")

	# 3. Simulate Report Generation
	# This mimics exactly what the UI does.
	print("\n--- 📜 Test Report Generation ---")
	var mock_context = _build_mock_context()
	var report = AutumnReport.new()
	report.init_from_context(mock_context)
	
	print("   Harvest Yield: ", report.harvest_yield)
	print("   Winter Demand: ", report.winter_demand)
	print("   Net Outcome: ", report.net_outcome)
	
	if report.harvest_yield == 0 and report.winter_demand == 0:
		print("⚠️ ALARM: Both Yield and Demand are 0. The UI has nothing to show.")
	
	print("========================================\n")

func _build_mock_context() -> Dictionary:
	var ctx = {}
	if SettlementManager.current_settlement:
		ctx["treasury"] = SettlementManager.current_settlement.treasury.duplicate()
	else:
		ctx["treasury"] = {}
	
	if EconomyManager.has_method("get_winter_forecast"):
		ctx["forecast"] = EconomyManager.get_winter_forecast()
	else:
		ctx["forecast"] = {}
		
	# Assume a fake harvest just to see if logic works
	ctx["payout"] = {GameResources.FOOD: 100} 
	return ctx
