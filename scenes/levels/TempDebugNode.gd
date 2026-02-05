extends Node

## Assign your TreasuryHUD node here in the Inspector!
@export var hud_node: TreasuryHUD

# Internal tracking
var _previous_treasury: Dictionary = {}

func _ready() -> void:
	print("--- TREASURY WATCHDOG STARTED ---")
	
	if not hud_node:
		Loggie.msg("DebugTracker: HUD Node not assigned! Cannot verify UI text.").domain(LogDomains.SYSTEM).error()
		return

	# Listen to key events
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.treasury_updated.connect(_on_treasury_updated)
	
	# Snapshot initial state
	if SettlementManager.current_settlement:
		_previous_treasury = SettlementManager.current_settlement.treasury.duplicate()

func _on_treasury_updated(_new_treasury: Dictionary) -> void:
	# Wait one frame to let the UI update itself first
	await get_tree().process_frame
	_verify_ui_integrity()

func _on_season_changed(new_season: String) -> void:
	print("\n=== SEASON CHANGE DETECTED: %s ===" % new_season)
	
	if not SettlementManager.current_settlement: return
	
	var current = SettlementManager.current_settlement.treasury
	
	# 1. Calculate Delta (What actually changed?)
	var delta_report = ""
	for res in GameResources.ALL_CURRENCIES:
		var old_val = _previous_treasury.get(res, 0)
		var new_val = current.get(res, 0)
		var diff = new_val - old_val
		
		if diff != 0:
			delta_report += "%s: %+d  " % [res.capitalize(), diff]
			
	if delta_report == "":
		print(">> Zero Economic Activity this season.")
	else:
		print(">> ACTUAL CHANGE: ", delta_report)
	
	# 2. Compare against Expected Forecast (Optional, creates deep insight)
	# You can uncomment this if you suspect the Forecast is lying
	# var forecast = EconomyManager.get_projected_income()
	# print(">> FORECAST WAS: ", forecast)

	# 3. Snapshot for next season
	_previous_treasury = current.duplicate()
	
	# 4. Final UI Check
	await get_tree().process_frame
	_verify_ui_integrity()

func _verify_ui_integrity() -> void:
	if not hud_node or not SettlementManager.current_settlement: return
	
	var data = SettlementManager.current_settlement.treasury
	var discrepancies = 0
	
	# Helper to clean label text (remove commas, currency symbols if you add them later)
	var check_res = func(res_key: String, label: Label) -> void:
		if not label: return
		var ui_val = int(label.text.replace(",", ""))
		var data_val = data.get(res_key, 0)
		
		if ui_val != data_val:
			printerr("!! MISMATCH %s !! Data: %d vs UI: %d" % [res_key.to_upper(), data_val, ui_val])
			discrepancies += 1
		else:
			# Uncomment for verbose confirmation
			# print("OK: %s (%d)" % [res_key, data_val])
			pass

	check_res.call(GameResources.GOLD, hud_node.gold_label)
	check_res.call(GameResources.WOOD, hud_node.wood_label)
	check_res.call(GameResources.FOOD, hud_node.food_label)
	check_res.call(GameResources.STONE, hud_node.stone_label)
	
	if discrepancies == 0:
		print(">> UI Integrity Check: PASSED (Synced)")
