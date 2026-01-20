extends GutTest

const TEMP_BUILDING_PATH = "user://temp_test_eco_building.tres"

var _mock_settlement: SettlementData
var _mock_jarl: JarlData

func before_all():
	# Create a temporary building resource for testing
	var b_data = EconomicBuildingData.new()
	b_data.resource_type = "gold"
	b_data.base_passive_output = 100 # Easy math: 100/yr -> 25/season
	b_data.storage_capacity_bonus = 1000 # huge cap
	ResourceSaver.save(b_data, TEMP_BUILDING_PATH)

func after_all():
	# Cleanup
	if FileAccess.file_exists(TEMP_BUILDING_PATH):
		DirAccess.remove_absolute(TEMP_BUILDING_PATH)

func before_each():
	# 1. Mock Settlement
	_mock_settlement = SettlementData.new()
	_mock_settlement.treasury = {"gold": 0, "wood": 0, "food": 0}
	_mock_settlement.placed_buildings = []
	_mock_settlement.population_peasants = 10
	SettlementManager.current_settlement = _mock_settlement
	
	# 2. Mock Jarl (Neutral Stats)
	_mock_jarl = JarlData.new()
	_mock_jarl.stewardship = 10 # Multiplier = 1.0
	DynastyManager.current_jarl = _mock_jarl

func after_each():
	SettlementManager.current_settlement = null
	DynastyManager.current_jarl = null

# --- TESTS ---

func test_projected_income_calculation():
	# Setup: Add the temp building
	_add_building_to_settlement(TEMP_BUILDING_PATH)
	
	var projection = EconomyManager.get_projected_income()
	
	assert_has(projection, "gold", "Projection should contain gold")
	assert_eq(projection["gold"], 100, "Base output should be 100 (100 base * 1 worker * 1.0 stew)")

func test_seasonal_payout_spring():
	# Gold should pay 25% in Spring
	_add_building_to_settlement(TEMP_BUILDING_PATH)
	
	EconomyManager.calculate_seasonal_payout("Spring")
	
	assert_eq(_mock_settlement.treasury["gold"], 25, "Spring should pay 25% of annual gold (100 -> 25)")

func test_seasonal_payout_autumn_food():
	# Setup Food Building (Farm)
	var farm_data = EconomicBuildingData.new()
	farm_data.resource_type = "food"
	farm_data.base_passive_output = 200
	var farm_path = "user://temp_test_farm.tres"
	ResourceSaver.save(farm_data, farm_path)
	
	_add_building_to_settlement(farm_path)
	
	# TEST 1: Summer (No Harvest)
	EconomyManager.calculate_seasonal_payout("Summer")
	assert_eq(_mock_settlement.treasury["food"], 0, "Summer should yield 0 Food")
	
	# TEST 2: Autumn (Harvest)
	EconomyManager.calculate_seasonal_payout("Autumn")
	# Treasury accumulates, so if Summer added 0, Autumn adds 200 -> Total 200
	assert_eq(_mock_settlement.treasury["food"], 200, "Autumn should yield 100% of annual Food")
	
	# Cleanup
	DirAccess.remove_absolute(farm_path)

func test_storage_caps():
	# Cap is 500 (Base Gold) + 1000 (Building) = 1500
	# Updated to match EconomyManager.BASE_GOLD_CAPACITY
	_add_building_to_settlement(TEMP_BUILDING_PATH)
	
	# Fill treasury to near cap (1500 - 10)
	_mock_settlement.treasury["gold"] = 1490
	
	# Payout tries to add 25
	EconomyManager.calculate_seasonal_payout("Spring")
	
	# Should be clamped at 1500
	assert_eq(_mock_settlement.treasury["gold"], 1500, "Treasury should not exceed calculated cap (1500)")

func test_stewardship_bonus():
	# Increase Jarl Skill to 20 (+50% bonus)
	_mock_jarl.stewardship = 20 
	_add_building_to_settlement(TEMP_BUILDING_PATH)
	
	var projection = EconomyManager.get_projected_income()
	# Base 100 * 1.5 = 150
	assert_eq(projection["gold"], 150, "Stewardship should boost income by 50%")

# --- HELPER ---

func _add_building_to_settlement(path: String):
	# Emulates the dictionary structure used by SettlementData
	_mock_settlement.placed_buildings.append({
		"resource_path": path,
		"peasant_count": 1, # 1 Worker assigned
		"thrall_count": 0,
		"grid_position": Vector2i(0,0)
	})
