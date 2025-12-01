# res://test/unit/test_winter_math.gd
extends GutTest

var _default_harsh: float
var _default_mild: float

func before_all():
	# Save original defaults so we don't break other tests later
	_default_harsh = WinterManager.harsh_chance
	_default_mild = WinterManager.mild_chance

func after_each():
	# Reset to defaults after every test
	WinterManager.harsh_chance = _default_harsh
	WinterManager.mild_chance = _default_mild
	WinterManager.current_severity = WinterManager.WinterSeverity.NORMAL

func test_demand_calculation_normal():
	# 1. Setup
	var settlement = SettlementData.new()
	settlement.population_peasants = 100
	settlement.warbands.clear()
	
	# 2. FORCE NORMAL WINTER (0% chance of extreme weather)
	WinterManager.harsh_chance = 0.0
	WinterManager.mild_chance = 0.0
	
	# 3. Execute
	var report = WinterManager.calculate_winter_demand(settlement)
	
	# 4. Assert (100 pop * 1 = 100)
	assert_eq(report["food_demand"], 100, "Normal winter food should be 1:1.")
	assert_eq(report["wood_demand"], 20, "Base wood cost should be 20.")

func test_demand_calculation_harsh():
	# 1. Setup
	var settlement = SettlementData.new()
	settlement.population_peasants = 100
	settlement.warbands.clear()
	
	# 2. FORCE HARSH WINTER (100% chance)
	WinterManager.harsh_chance = 1.0
	WinterManager.mild_chance = 0.0
	
	# 3. Execute
	var report = WinterManager.calculate_winter_demand(settlement)
	
	# 4. Assert (100 * 1.5 = 150)
	assert_eq(report["food_demand"], 150, "Harsh winter should increase cost by 50%.")
