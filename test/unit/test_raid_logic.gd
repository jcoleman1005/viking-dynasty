# test/unit/test_raid_logic.gd
extends "res://test/base/GutTestBase.gd"

var obj_manager: Node

func before_each() -> void:
	super.before_each()
	obj_manager = load("res://scenes/missions/RaidObjectiveManager.gd").new()
	obj_manager.base_renown = 200
	obj_manager.renown_per_difficulty = 50
	RaidManager.current_raid_difficulty = 1
	add_child_autoqfree(obj_manager)

func after_each() -> void:
	RaidManager.current_raid_difficulty = 1

# --- Renown: Victory ---

func test_decisive_victory_renown_is_150_percent_of_base() -> void:
	var base = 200 + (1 * 50)
	var result = obj_manager._calculate_renown_for_victory("Decisive")
	assert_eq(result, floor(base * 1.5), "Decisive renown should be 1.5x base")

func test_standard_victory_renown_equals_base() -> void:
	var base = 200 + (1 * 50)
	var result = obj_manager._calculate_renown_for_victory("Standard")
	assert_eq(result, base, "Standard renown should equal base")

func test_pyrrhic_victory_renown_is_negative() -> void:
	var result = obj_manager._calculate_renown_for_victory("Pyrrhic")
	assert_lt(result, 0, "Pyrrhic renown should be negative")

# --- Renown: Retreat ---

func test_retreat_renown_zero_when_gold_exceeds_threshold() -> void:
	RaidManager.current_raid_difficulty = 2
	var loot = RaidLootData.new()
	loot.add_loot("gold", 80)
	obj_manager.raid_loot = loot
	obj_manager.dead_units_log.clear()
	var result = obj_manager._calculate_renown_for_retreat()
	assert_eq(result, 0, "Wise Greed: heavy loot retreat should cost no renown")

func test_retreat_renown_zero_when_difficulty_high() -> void:
	RaidManager.current_raid_difficulty = 4
	var loot = RaidLootData.new()
	obj_manager.raid_loot = loot
	obj_manager.dead_units_log.clear()
	var result = obj_manager._calculate_renown_for_retreat()
	assert_eq(result, 0, "Saga Factor: retreating from strong enemy costs no renown")

func test_retreat_renown_negative_when_dead_units_left() -> void:
	RaidManager.current_raid_difficulty = 2
	var loot = RaidLootData.new()
	loot.add_loot("gold", 10)
	obj_manager.raid_loot = loot
	obj_manager.dead_units_log.clear()
	obj_manager.dead_units_log.append(UnitData.new())
	var result = obj_manager._calculate_renown_for_retreat()
	assert_lt(result, 0, "Blood Debt: leaving dead behind costs renown")

func test_retreat_renown_negative_when_difficulty_low() -> void:
	RaidManager.current_raid_difficulty = 1
	var loot = RaidLootData.new()
	loot.add_loot("gold", 10)
	obj_manager.raid_loot = loot
	obj_manager.dead_units_log.clear()
	var result = obj_manager._calculate_renown_for_retreat()
	assert_lt(result, 0, "Saga Factor low: retreating from weak enemy costs renown")

# --- Pyrrhic Threshold ---

func test_pyrrhic_triggers_above_50_percent_casualties() -> void:
	var casualties = 6
	var starting_size = 10
	assert_true(casualties > floor(starting_size * 0.5), "6/10 casualties should trigger Pyrrhic")

func test_pyrrhic_does_not_trigger_at_exactly_50_percent() -> void:
	var casualties = 5
	var starting_size = 10
	assert_false(casualties > floor(starting_size * 0.5), "5/10 casualties should not trigger Pyrrhic")

func test_pyrrhic_does_not_trigger_at_low_casualties() -> void:
	var casualties = 2
	var starting_size = 10
	assert_false(casualties > floor(starting_size * 0.5), "2/10 casualties should not trigger Pyrrhic")
