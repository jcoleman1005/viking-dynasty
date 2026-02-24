# test/unit/test_raid_data.gd
extends "res://test/base/GutTestBase.gd"

# --- RaidResultData Fields ---

func test_raid_result_data_has_loot_field() -> void:
	var result = RaidResultData.new()
	assert_true("loot" in result, "RaidResultData must have loot field")

func test_raid_result_data_has_potential_loot_field() -> void:
	var result = RaidResultData.new()
	assert_true("potential_loot" in result, "RaidResultData must have potential_loot field")

func test_raid_result_data_has_casualties_field() -> void:
	var result = RaidResultData.new()
	assert_true("casualties" in result, "RaidResultData must have casualties field")

func test_raid_result_data_has_outcome_field() -> void:
	var result = RaidResultData.new()
	assert_true("outcome" in result, "RaidResultData must have outcome field")

func test_raid_result_data_has_renown_earned_field() -> void:
	var result = RaidResultData.new()
	assert_true("renown_earned" in result, "RaidResultData must have renown_earned field")

func test_raid_result_data_has_victory_grade_field() -> void:
	var result = RaidResultData.new()
	assert_true("victory_grade" in result, "RaidResultData must have victory_grade field")

# --- Building Loot Values ---

func test_hall_loot_value() -> void:
	var hall_data = load("res://data/buildings/GreatHall.tres")
	assert_not_null(hall_data, "Hall .tres must exist")
	assert_eq(hall_data.base_passive_output, 27, "Hall base_passive_output should be 27")
	assert_eq(hall_data.resource_type, "gold", "Hall resource_type should be gold")

func test_church_loot_value() -> void:
	var church_data = load("res://data/buildings/Monastery_Chapel.tres")
	assert_not_null(church_data, "Church .tres must exist")
	assert_eq(church_data.base_passive_output, 20, "Church base_passive_output should be 20")
	assert_eq(church_data.resource_type, "gold", "Church resource_type should be gold")

func test_longhouse_loot_value() -> void:
	var longhouse_data = load("res://data/buildings/player_economy/Bld_Langhus.tres")
	assert_not_null(longhouse_data, "Longhouse .tres must exist")
	assert_eq(longhouse_data.base_passive_output, 7, "Longhouse base_passive_output should be 7")
	assert_eq(longhouse_data.resource_type, "gold", "Longhouse resource_type should be gold")

func test_granary_loot_value() -> void:
	var granary_data = load("res://data/buildings/Monastery_Granary.tres")
	assert_not_null(granary_data, "Granary .tres must exist")
	assert_eq(granary_data.base_passive_output, 17, "Granary base_passive_output should be 17")
	assert_eq(granary_data.resource_type, "food", "Granary resource_type should be food")

func test_storehouse_loot_value() -> void:
	var storehouse_data = load("res://data/buildings/Eco_Storehouse.tres")
	assert_not_null(storehouse_data, "Storehouse .tres must exist")
	assert_eq(storehouse_data.base_passive_output, 10, "Storehouse base_passive_output should be 10")
	assert_eq(storehouse_data.resource_type, "food", "Storehouse resource_type should be food")

func test_granary_and_storehouse_are_separate_resources() -> void:
	var granary_path = "res://data/buildings/Monastery_Granary.tres"
	var storehouse_path = "res://data/buildings/Eco_Storehouse.tres"
	assert_ne(granary_path, storehouse_path, "Granary and Storehouse must be separate .tres files")
	var granary_data = load(granary_path)
	var storehouse_data = load(storehouse_path)
	assert_eq(granary_data.base_passive_output, 17, "Granary should have output 17")
	assert_eq(storehouse_data.base_passive_output, 10, "Storehouse should have output 10")
