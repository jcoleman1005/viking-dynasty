#res://test/integration/test_fleet_mechanics.gd
# res://test/integration/test_fleet_mechanics.gd
extends GutTestBase

const NAUST_PATH = "res://data/buildings/generated/Bldg_Naust.tres"

func before_each():
	super.before_each()
	# Ensure we have a clean settlement
	create_mock_settlement()

func test_base_fleet_capacity():
	# 1. Assert Base State (No buildings)
	var cap = SettlementManager.get_total_ship_capacity_squads()
	assert_eq(cap, 3, "Base capacity should be 3 Squads (1 Ship) with no buildings.")

func test_naust_increases_capacity():
	# 1. Check if the AI Importer worked
	if not FileAccess.file_exists(NAUST_PATH):
		fail_test("Could not find Naust data at %s. Did you run the Importer?" % NAUST_PATH)
		return
		
	# 2. Add a Naust to the settlement
	var entry = {
		"resource_path": NAUST_PATH,
		"grid_position": Vector2i(0,0)
	}
	SettlementManager.current_settlement.placed_buildings.append(entry)
	
	# 3. Assert Capacity Increase
	var cap = SettlementManager.get_total_ship_capacity_squads()
	
	# Expected: 3 (Base) + 3 (Naust) = 6
	assert_eq(cap, 6, "Building a Naust should increase capacity by 3 squads.")

func test_overflow_logic():
	# 1. Setup: Base Capacity (3)
	# Fill the spots with 3 existing squads
	var s = SettlementManager.current_settlement
	s.warbands.append(create_mock_warband())
	s.warbands.append(create_mock_warband())
	s.warbands.append(create_mock_warband())
	
	# 2. Simulate "The Call": 5 new squads arrive
	var arriving_squads = 5
	var capacity = SettlementManager.get_total_ship_capacity_squads() # Should be 3
	var current_filled = s.warbands.size() # 3
	
	var open_slots = max(0, capacity - current_filled)
	var accepted = min(arriving_squads, open_slots)
	var rejected = arriving_squads - accepted
	
	# 3. Assert
	assert_eq(open_slots, 0, "Should have 0 open slots.")
	assert_eq(accepted, 0, "Should accept 0 new squads.")
	assert_eq(rejected, 5, "Should turn away all 5 squads.")

func test_naust_solves_overflow():
	# 1. Setup: Base Capacity (3) but FULL
	var s = SettlementManager.current_settlement
	s.warbands.append(create_mock_warband())
	s.warbands.append(create_mock_warband())
	s.warbands.append(create_mock_warband())
	
	# 2. Build a Naust!
	if FileAccess.file_exists(NAUST_PATH):
		s.placed_buildings.append({ "resource_path": NAUST_PATH, "grid_position": Vector2i(0,0) })
	
	# 3. Recalculate Capacity
	var capacity = SettlementManager.get_total_ship_capacity_squads() # Should be 6 now
	
	# 4. Simulate "The Call": 2 new squads arrive
	var arriving_squads = 2
	var current_filled = s.warbands.size() # 3
	
	var open_slots = max(0, capacity - current_filled) # 6 - 3 = 3 slots
	var accepted = min(arriving_squads, open_slots)
	var rejected = arriving_squads - accepted
	
	# 5. Assert
	assert_eq(capacity, 6, "Capacity should be 6.")
	assert_eq(open_slots, 3, "Should have 3 open slots.")
	assert_eq(accepted, 2, "Should accept both squads.")
	assert_eq(rejected, 0, "No one should be turned away.")
