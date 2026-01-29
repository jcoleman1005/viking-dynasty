extends GutTest

## test_dynasty_modifiers.gd
## Verifies the Data-Driven Seasonal Modifier logic in DynastyManager.
## Ensures cards correctly aggregate stats and reset properly.

func before_each():
	# Ensure a clean slate before every test
	DynastyManager.reset_year_stats()

func after_each():
	# Cleanup after tests
	DynastyManager.reset_year_stats()

func test_initial_state():
	# Verify all stats start at 0.0
	var stats = DynastyManager.active_year_modifiers
	assert_eq(stats["mod_unit_damage"], 0.0, "Damage mod should init at 0")
	assert_eq(stats["mod_raid_xp"], 0.0, "Raid XP mod should init at 0")

func test_single_card_aggregation():
	# Setup
	var card = SeasonalCardResource.new()
	card.display_name = "Test Feast"
	card.mod_unit_damage = 0.15 # +15% Damage
	card.mod_raid_xp = 0.0
	
	# Execute
	DynastyManager.aggregate_card_effects(card)
	
	# Assert
	var stats = DynastyManager.active_year_modifiers
	assert_almost_eq(stats["mod_unit_damage"], 0.15, 0.001, "Damage mod should update to 0.15")
	assert_eq(stats["mod_raid_xp"], 0.0, "Unchanged stat should remain 0")

func test_modifier_stacking():
	# Setup Card A (+10% Damage)
	var card_a = SeasonalCardResource.new()
	card_a.display_name = "Training"
	card_a.mod_unit_damage = 0.10
	
	# Setup Card B (+5% Damage, +20% Harvest)
	var card_b = SeasonalCardResource.new()
	card_b.display_name = "Blessing"
	card_b.mod_unit_damage = 0.05
	card_b.mod_harvest_yield = 0.20
	
	# Execute
	DynastyManager.aggregate_card_effects(card_a)
	DynastyManager.aggregate_card_effects(card_b)
	
	# Assert
	var stats = DynastyManager.active_year_modifiers
	# 0.10 + 0.05 should equal 0.15
	assert_almost_eq(stats["mod_unit_damage"], 0.15, 0.001, "Damage modifiers should stack")
	assert_almost_eq(stats["mod_harvest_yield"], 0.20, 0.001, "Harvest modifier should be applied")

func test_negative_modifiers():
	# Setup Penalty Card (-10% XP)
	var card = SeasonalCardResource.new()
	card.mod_raid_xp = -0.10
	
	# Execute
	DynastyManager.aggregate_card_effects(card)
	
	# Assert
	assert_almost_eq(DynastyManager.active_year_modifiers["mod_raid_xp"], -0.10, 0.001, "Should handle negative modifiers")

func test_reset_functionality():
	# Setup
	var card = SeasonalCardResource.new()
	card.mod_birth_chance = 0.5
	DynastyManager.aggregate_card_effects(card)
	
	# Pre-check
	assert_gt(DynastyManager.active_year_modifiers["mod_birth_chance"], 0.0, "Stat should be set before reset")
	
	# Execute Reset
	DynastyManager.reset_year_stats()
	
	# Assert
	assert_eq(DynastyManager.active_year_modifiers["mod_birth_chance"], 0.0, "Stat should be 0.0 after reset")
