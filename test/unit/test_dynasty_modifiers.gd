#res://test/unit/test_dynasty_modifiers.gd
extends GutTest

## test_dynasty_modifiers.gd
## Verifies the Data-Driven Seasonal Modifier logic in DynastyManager.
## Card-based tests removed — SeasonalCardResource retired in Winter-Refactor.

func before_each():
	DynastyManager.reset_year_stats()

func after_each():
	DynastyManager.reset_year_stats()

func test_initial_state():
	var stats = DynastyManager.active_year_modifiers
	assert_eq(stats["mod_unit_damage"], 0.0, "Damage mod should init at 0")
	assert_eq(stats["mod_raid_xp"], 0.0, "Raid XP mod should init at 0")

func test_reset_clears_all_modifiers():
	# Manually dirty a modifier
	DynastyManager.active_year_modifiers["mod_birth_chance"] = 0.5
	assert_true(DynastyManager.active_year_modifiers["mod_birth_chance"] > 0.0)

	DynastyManager.reset_year_stats()

	assert_eq(DynastyManager.active_year_modifiers["mod_birth_chance"], 0.0,
		"Stat should be 0.0 after reset")

func test_apply_year_modifier_sets_flag():
	DynastyManager.apply_year_modifier("BLOT_FREYR")
	assert_true(DynastyManager.active_year_modifiers.has("BLOT_FREYR"),
		"Flag modifier should be stored in active_year_modifiers")

func test_reset_clears_year_event_log():
	DynastyManager.year_event_log.append({"event_id": "test", "variables": {}, "significance": 1})
	assert_true(DynastyManager.year_event_log.size() > 0)
	DynastyManager.reset_year_stats()
	assert_eq(DynastyManager.year_event_log.size(), 0, "Event log should be empty after reset")

func test_reset_clears_oath_state():
	DynastyManager.active_spring_oath = "harvest_oath"
	DynastyManager.oath_broken_this_year = true
	DynastyManager.reset_year_stats()
	assert_eq(DynastyManager.active_spring_oath, "", "Oath should clear on reset")
	assert_false(DynastyManager.oath_broken_this_year, "Broken flag should clear on reset")
