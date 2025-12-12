extends GutTest

var winter_manager
var mock_settlement
var mock_jarl

func before_each():
	winter_manager = WinterManager
	
	# Mock Settlement Data
	mock_settlement = SettlementData.new()
	mock_settlement.population_peasants = 10
	mock_settlement.treasury = {"food": 100, "wood": 100, "gold": 1000}
	
	# Inject into Singleton
	SettlementManager.current_settlement = mock_settlement
	
	# Mock Jarl for Actions
	mock_jarl = JarlData.new()
	mock_jarl.current_hall_actions = 5
	DynastyManager.current_jarl = mock_jarl

func after_each():
	SettlementManager.current_settlement = null
	DynastyManager.current_jarl = null
	winter_manager.winter_crisis_active = false
	winter_manager.winter_consumption_report.clear()

func test_calculate_demand_normal():
	# Force normal via probability manipulation or just check math logic
	winter_manager.current_severity = winter_manager.WinterSeverity.NORMAL
	
	var report = winter_manager.calculate_winter_demand(mock_settlement)
	
	# 10 peasants * 1 + 0 warbands * 5 = 10 food
	# Base wood = 20
	assert_eq(report["food_demand"], 10)
	assert_eq(report["wood_demand"], 20)

func test_consumption_applied_when_affordable():
	# Ensure calculated needs are applied if treasury has enough
	winter_manager._calculate_winter_needs()
	
	assert_false(winter_manager.winter_crisis_active, "Should not be a crisis")
	
	# Check if treasury was deducted
	# Normal demand is ~10 food, ~20 wood
	assert_lt(mock_settlement.treasury["food"], 100)
	assert_lt(mock_settlement.treasury["wood"], 100)

func test_crisis_trigger():
	# Bankrupt the settlement
	mock_settlement.treasury["food"] = 0
	
	winter_manager._calculate_winter_needs()
	
	assert_true(winter_manager.winter_crisis_active, "Crisis should trigger on deficit")
	assert_gt(winter_manager.winter_consumption_report["food_deficit"], 0)

func test_resolve_crisis_with_gold():
	# Setup Crisis
	mock_settlement.treasury["food"] = 0
	winter_manager._calculate_winter_needs()
	
	# Resolve
	var success = winter_manager.resolve_crisis_with_gold()
	
	assert_true(success)
	assert_false(winter_manager.winter_crisis_active)
	# Gold should be reduced (Cost is Deficit * 5)
	assert_lt(mock_settlement.treasury["gold"], 1000)

func test_resolve_sacrifice_burn_ships():
	# Setup Crisis (Wood deficit)
	mock_settlement.treasury["wood"] = 0
	mock_settlement.fleet_readiness = 1.0
	winter_manager._calculate_winter_needs()
	
	# Resolve
	var success = winter_manager.resolve_crisis_with_sacrifice("burn_ships")
	
	assert_true(success)
	assert_eq(mock_settlement.fleet_readiness, 0.0)
	assert_eq(mock_jarl.current_hall_actions, 4, "Should spend 1 action")
