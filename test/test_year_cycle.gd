extends Node

# Year Cycle Test Script
# Add this to a scene and run to test year cycle mechanics

func _ready():
	print("=== YEAR CYCLE TESTS ===")
	
	# Wait a frame for autoloads to initialize
	await get_tree().process_frame
	
	# Test 1: Starvation Test
	print("\n🔥 TEST 1: STARVATION")
	test_starvation()
	
	# Test 2: Overpopulation Test
	print("\n👥 TEST 2: OVERPOPULATION") 
	test_overpopulation()
	
	# Test 3: Solution Test
	print("\n⚔️ TEST 3: DRAFT & RAID SOLUTION")
	test_draft_and_raid_solution()
	
	print("\n=== ALL TESTS COMPLETE ===")

func test_starvation():
	print("Setting up: Food = 0, Population = 20")
	
	# Create settlement with no food
	var settlement = SettlementData.new()
	settlement.population_peasants = 20
	settlement.population_thralls = 5
	settlement.treasury = {
		"gold": 100,
		"wood": 50,
		"food": 0  # ZERO FOOD - This should cause starvation
	}
	settlement.placed_buildings = []
	settlement.unrest = 0
	
	# Set up autoloads
	SettlementManager.current_settlement = settlement
	
	# Create mock jarl
	var jarl = JarlData.new()
	jarl.age = 35
	DynastyManager.current_jarl = jarl
	
	print("Before: Population = %d, Food = %d" % [settlement.population_peasants, settlement.treasury.get("food", 0)])
	
	# Run year cycle logic
	var payout = EconomyManager.calculate_payout()
	DynastyManager.end_year()
	
	print("After: Population = %d, Food = %d" % [settlement.population_peasants, settlement.treasury.get("food", 0)])
	print("Payout messages: %s" % payout.get("_messages", []))
	print("Population growth: %s" % payout.get("population_growth", "N/A"))
	
	if settlement.population_peasants < 20:
		print("✅ STARVATION TEST PASSED - Population decreased from 20 to %d!" % settlement.population_peasants)
	else:
		print("❌ STARVATION TEST FAILED - Population unchanged at %d" % settlement.population_peasants)

func test_overpopulation():
	print("Setting up: Population = 50, Limited buildings (no land capacity)")
	
	var settlement = SettlementData.new()
	settlement.population_peasants = 50  # HIGH POPULATION
	settlement.population_thralls = 5
	settlement.treasury = {
		"gold": 200,
		"wood": 100,
		"food": 500  # Plenty of food
	}
	settlement.placed_buildings = []  # NO BUILDINGS = only base 5 land capacity
	settlement.unrest = 0
	
	SettlementManager.current_settlement = settlement
	
	var jarl = JarlData.new()
	jarl.age = 35
	DynastyManager.current_jarl = jarl
	
	print("Before: Population = %d, Unrest = %d" % [settlement.population_peasants, settlement.unrest])
	
	var payout = EconomyManager.calculate_payout()
	DynastyManager.end_year()
	
	print("After: Population = %d, Unrest = %d" % [settlement.population_peasants, settlement.unrest])
	print("Payout messages: %s" % payout.get("_messages", []))
	print("Population growth: %s" % payout.get("population_growth", "N/A"))
	
	# 50 peasants with only 5 base land capacity = 45 landless = 90 unrest
	if settlement.unrest > 0:
		print("✅ OVERPOPULATION TEST PASSED - Unrest increased to %d!" % settlement.unrest)
	else:
		print("❌ OVERPOPULATION TEST FAILED - No unrest generated")

func test_draft_and_raid_solution():
	print("Setting up: Draft Bondi to reduce population and ease land pressure")
	
	var settlement = SettlementData.new()
	settlement.population_peasants = 50
	settlement.population_thralls = 5
	settlement.treasury = {
		"gold": 500,
		"wood": 200, 
		"food": 600
	}
	settlement.placed_buildings = []  # Only base 5 land capacity
	settlement.unrest = 40  # Starting with some unrest
	settlement.warbands = []
	
	SettlementManager.current_settlement = settlement
	
	var jarl = JarlData.new()
	jarl.age = 35
	DynastyManager.current_jarl = jarl
	
	# Try to load actual Bondi unit data if it exists
	var bondi_data
	if ResourceLoader.exists("res://data/units/Bondi.tres"):
		bondi_data = load("res://data/units/Bondi.tres")
		print("Loaded actual Bondi unit data")
	else:
		# Create mock unit data
		bondi_data = UnitData.new()
		bondi_data.display_name = "Bondi"
		bondi_data.manpower = 20
		print("Created mock Bondi unit data")
	
	print("Before drafting: Population = %d, Warbands = %d, Unrest = %d" % [settlement.population_peasants, settlement.warbands.size(), settlement.unrest])
	
	# Draft units to reduce population (each recruit costs 10 population according to SettlementManager)
	SettlementManager.recruit_unit(bondi_data)  # -10 pop
	SettlementManager.recruit_unit(bondi_data)  # -10 pop  
	
	print("After drafting: Population = %d, Warbands = %d" % [settlement.population_peasants, settlement.warbands.size()])
	
	# Simulate successful raid return with loot
	var raid_loot = {
		"gold": 150,
		"food": 100,
		"population": 10  # Captured thralls
	}
	
	print("Simulating raid return with loot: %s" % raid_loot)
	SettlementManager.deposit_resources(raid_loot)
	
	# End year to see unrest calculation with reduced population
	var payout = EconomyManager.calculate_payout()
	DynastyManager.end_year()
	
	print("After year end: Population = %d, Unrest = %d, Thralls = %d" % [settlement.population_peasants, settlement.unrest, settlement.population_thralls])
	print("Payout messages: %s" % payout.get("_messages", []))
	print("Population growth: %s" % payout.get("population_growth", "N/A"))
	
	# With 30 population and 5 land capacity, we should have 25 landless = 50 unrest
	# But this is less than the starting 40, so unrest should be manageable
	if settlement.unrest < 80:  # Should be much lower than without drafting
		print("✅ DRAFT & RAID TEST PASSED - Unrest managed at %d (vs would be ~90 without drafting)!" % settlement.unrest)
	else:
		print("❌ DRAFT & RAID TEST FAILED - Unrest still high at %d" % settlement.unrest)
