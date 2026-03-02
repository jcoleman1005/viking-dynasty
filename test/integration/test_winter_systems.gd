#res://test/integration/test_winter_systems.gd
extends GutTest

# --- SETUP & TEARDOWN ---
var _mock_ui  # EventUI double

func before_each():
	# 1. Reset Managers
	SettlementManager.reset_manager_state()
	WinterManager.winter_crisis_active = false
	WinterManager.winter_consumption_report.clear()

	# 2. FORCE NORMAL WINTER (Disable RNG for logic tests)
	WinterManager.harsh_chance = 0.0
	WinterManager.mild_chance = 0.0
	WinterManager.current_severity = WinterManager.WinterSeverity.NORMAL

	# 3. Mock Jarl
	var jarl = JarlData.new()
	jarl.display_name = "Test Jarl"
	jarl.current_hall_actions = 3
	DynastyManager.current_jarl = jarl

	# 4. Reset Season
	DynastyManager.current_season = DynastyManager.Season.SPRING

	# 5. Stub EventUI so winter crisis trigger_event_by_id doesn't push_error
	_mock_ui = double(EventUI).new()
	add_child_autofree(_mock_ui)
	EventManager.event_ui = _mock_ui

func after_each():
	EventManager.event_ui = null

func after_all():
	# Restore RNG defaults
	WinterManager.harsh_chance = 0.2
	WinterManager.mild_chance = 0.05

# --- TESTS ---

func test_winter_crisis_detection_starvation():
	# 1. Setup: 50 Pop vs 0 Food
	var settlement = SettlementData.new()
	settlement.population_peasants = 50
	settlement.treasury = { "food": 0, "wood": 100, "gold": 0 }
	SettlementManager.current_settlement = settlement
	
	# Force Winter season so _calculate_winter_needs doesn't early return
	DynastyManager.current_season = DynastyManager.Season.WINTER

	# 2. Execute
	WinterManager._calculate_winter_needs()

	# 3. Assert
	assert_true(WinterManager.winter_crisis_active, "Crisis should be active.")

	var report = WinterManager.winter_consumption_report
	# With Normal Winter forced, 50 pop = 50 food needed
	assert_eq(report["food_deficit"], 50, "Deficit should be exactly 50 (Normal Winter).")

func test_winter_crisis_resolution_via_gold():
	# 1. Setup
	var settlement = SettlementData.new()
	settlement.population_peasants = 10
	settlement.treasury = { "food": 0, "wood": 100, "gold": 1000 }
	SettlementManager.current_settlement = settlement

	DynastyManager.current_season = DynastyManager.Season.WINTER
	WinterManager._calculate_winter_needs()

	# 2. Execute
	var result = WinterManager.resolve_crisis_with_gold()

	# 3. Assert
	assert_true(result["success"])
	assert_false(WinterManager.winter_crisis_active)
