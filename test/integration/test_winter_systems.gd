# res://test/integration/test_winter_systems.gd
extends GutTest

# --- SETUP & TEARDOWN ---
func before_each():
	# 1. Reset Managers
	SettlementManager.reset_manager_state()
	DynastyManager.winter_crisis_active = false
	DynastyManager.winter_consumption_report.clear()
	
	# 2. FORCE NORMAL WINTER (Disable RNG for logic tests)
	WinterManager.harsh_chance = 0.0
	WinterManager.mild_chance = 0.0
	WinterManager.current_severity = WinterManager.WinterSeverity.NORMAL
	
	# 3. Mock Jarl
	var jarl = JarlData.new()
	jarl.display_name = "Test Jarl"
	jarl.current_hall_actions = 3
	DynastyManager.current_jarl = jarl

func after_all():
	# Restore RNG defaults (Optional, good practice)
	WinterManager.harsh_chance = 0.2
	WinterManager.mild_chance = 0.05

# --- TESTS ---

func test_winter_crisis_detection_starvation():
	# 1. Setup: 50 Pop vs 0 Food
	var settlement = SettlementData.new()
	settlement.population_peasants = 50
	settlement.treasury = { "food": 0, "wood": 100, "gold": 0 }
	SettlementManager.current_settlement = settlement
	
	# 2. Execute
	DynastyManager._calculate_winter_needs()
	
	# 3. Assert
	assert_true(DynastyManager.winter_crisis_active, "Crisis should be active.")
	
	var report = DynastyManager.winter_consumption_report
	# With Normal Winter forced, 50 pop = 50 food needed
	assert_eq(report["food_deficit"], 50, "Deficit should be exactly 50 (Normal Winter).")

func test_winter_crisis_resolution_via_gold():
	# 1. Setup
	var settlement = SettlementData.new()
	settlement.population_peasants = 10 
	settlement.treasury = { "food": 0, "wood": 100, "gold": 1000 }
	SettlementManager.current_settlement = settlement
	
	DynastyManager._calculate_winter_needs()
	
	# 2. Execute
	var success = DynastyManager.resolve_crisis_with_gold()
	
	# 3. Assert
	assert_true(success)
	assert_false(DynastyManager.winter_crisis_active)
	# 10 Food * 5 Gold = 50 Gold Cost
	assert_eq(settlement.treasury["gold"], 950, "Gold should decrease by 50.")

func test_ui_locking_during_crisis():
	# 1. Setup
	var settlement = SettlementData.new()
	settlement.population_peasants = 50
	settlement.treasury = { "food": 0, "wood": 0, "gold": 0 }
	SettlementManager.current_settlement = settlement
	DynastyManager._calculate_winter_needs()
	
	# 2. Load UI
	var ui = autoqfree(load("res://ui/WinterCourt_UI.tscn").instantiate())
	add_child(ui)
	
	# --- FIX: Use new wait method ---
	await wait_physics_frames(1) 
	# --------------------------------
	
	# 3. Assert
	var btn_end = ui.find_child("Btn_EndWinter", true, false)
	assert_true(btn_end.disabled, "End Winter button should be locked.")
