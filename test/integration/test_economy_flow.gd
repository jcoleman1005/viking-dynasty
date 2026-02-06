#res://test/integration/test_economy_flow.gd
# res://test/integration/test_economy_flow.gd
extends GutTestBase

func test_population_growth_with_surplus():
	# 1. Setup (Using Helper!)
	var s = create_mock_settlement(10, 500) # 10 Pop, 500 Food (Abundance)
	create_mock_jarl()
	
	# 2. Execute Year End
	var payout = EconomyManager.calculate_payout()
	
	# 3. Assert
	# 10 people * 10 food = 100 demand. 500 available. Surplus!
	# Base growth 2% + 1% bonus = 3%. 10 * 0.03 = 0.3 -> Min 1 growth.
	
	# Parse the output string or check data directly?
	# Best to check the simulation result returned in payout
	var growth_str = payout.get("population_growth", "")
	
	assert_string_contains(growth_str, "+1", "Should grow by at least 1 peasant in abundance.")

func test_construction_labor_deduction():
	# 1. Setup
	var s = create_mock_settlement(10, 100)
	
	# Add a pending building
	var blueprint = {
		"resource_path": "res://data/buildings/Bldg_Wall.tres",
		"grid_position": Vector2i(0,0),
		"progress": 0,
		"peasant_count": 2, # 2 Workers assigned
		"thrall_count": 0
	}
	s.pending_construction_buildings.append(blueprint)
	
	# 2. Execute
	EconomyManager.calculate_payout()
	
	# 3. Assert
	# 2 Peasants * 25 Efficiency = 50 Progress
	var updated_bp = s.pending_construction_buildings[0]
	assert_eq(updated_bp["progress"], 50, "Construction progress should increase based on labor.")
