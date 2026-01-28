extends Node

const TEMP_BUILDING_PATH = "user://temp_test_house.tres"

func _ready() -> void:
	print("--- STARTING FINAL CONSTRUCTION TEST ---")
	_create_mock_building()
	
	# 1. Setup Mock Settlement with a pending building
	var mock_settlement = SettlementData.new()
	
	var pending_entry = {
		"resource_path": TEMP_BUILDING_PATH,
		"peasant_count": 5, # 5 workers
		"progress": 0
	}
	
	# FIX: Use append to modify the typed array
	mock_settlement.pending_construction_buildings.append(pending_entry)
	
	SettlementManager.current_settlement = mock_settlement
	
	# 2. Test Step 1: Partial Progress
	# 5 workers * 6 efficiency = 30 progress. Goal is 50.
	var finished = EconomyManager.advance_construction_progress()
	
	assert(finished.is_empty(), "Building should NOT be finished yet")
	var current_prog = mock_settlement.pending_construction_buildings[0]["progress"]
	assert(current_prog == 30, "Progress should be 30. Got %d" % current_prog)
	print("✔ Partial Progress Applied (0 -> 30)")
	
	# 3. Test Step 2: Completion
	# Next tick: 30 + 30 = 60. Goal is 50. Should finish.
	finished = EconomyManager.advance_construction_progress()
	
	assert(finished.size() == 1, "Building SHOULD be finished now")
	assert(mock_settlement.pending_construction_buildings.is_empty(), "Pending list should be empty")
	print("✔ Completion Logic Verified")
	
	_cleanup()
	print("--- FINAL REFACOR COMPLETE ---")

func _create_mock_building() -> void:
	var b = BuildingData.new() # Or EconomicBuildingData
	b.construction_effort_required = 50
	ResourceSaver.save(b, TEMP_BUILDING_PATH)

func _cleanup() -> void:
	DirAccess.remove_absolute(TEMP_BUILDING_PATH)
