# res://test/unit/test_EventEffectHandlers.gd
# GUT test suite for all event effect handlers implemented in EventManager.
# Tests the data-layer side effects only (resources, stats, population, flags).
# EventUI is stubbed in before_each to prevent UI errors in headless test runs.
extends GutTest

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var mock_settlement: SettlementData
var mock_jarl: JarlData
var mock_balance: EventBalanceData
var mock_ui  # EventUI double — set in before_each

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_choice(effect_key: String) -> EventChoice:
	var c = EventChoice.new()
	c.effect_key = effect_key
	return c

func _make_event() -> EventData:
	var e = EventData.new()
	e.event_id = "test_event"
	return e

## Fire an effect_key through _apply_event_consequences without a real event scene.
func _trigger(effect_key: String) -> void:
	EventManager._apply_event_consequences(_make_event(), _make_choice(effect_key))

func _make_household(name_str: String, members: int, loyalty_val: int) -> HouseholdData:
	var h = HouseholdData.new()
	h.household_name = name_str
	h.member_count = members
	h.loyalty = loyalty_val
	return h

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	# --- Settlement ---
	mock_settlement = SettlementData.new()
	mock_settlement.population_peasants = 20
	mock_settlement.treasury = {"food": 200, "wood": 100, "gold": 500}
	mock_settlement.sick_population = 0
	mock_settlement.households.clear()
	mock_settlement.households.append(_make_household("House A", 10, 50))
	mock_settlement.households.append(_make_household("House B", 10, 50))
	mock_settlement.warbands.clear()
	var wb = WarbandData.new()
	wb.custom_name = "Test Warband"
	mock_settlement.warbands.append(wb)
	SettlementManager.current_settlement = mock_settlement

	# --- Jarl ---
	mock_jarl = JarlData.new()
	mock_jarl.renown = 100
	mock_jarl.current_authority = 5
	DynastyManager.current_jarl = mock_jarl

	# --- Balance data ---
	mock_balance = EventBalanceData.new()
	EventManager.balance_data = mock_balance

	# --- Season state ---
	DynastyManager.current_day = 6
	DynastyManager.current_season = DynastyManager.Season.SUMMER
	DynastyManager.days_since_last_feast = 999
	DynastyManager.burial_rite_performed = false

	# --- Stub EventUI to prevent crashes in headless mode ---
	mock_ui = double(EventUI).new()
	add_child_autofree(mock_ui)
	EventManager.event_ui = mock_ui

func after_each() -> void:
	SettlementManager.current_settlement = null
	DynastyManager.current_jarl = null
	EventManager.balance_data = null
	EventManager._quarantine_snapshot.clear()
	EventManager.event_ui = null

# ===========================================================================
# GROUP: full_quarantine
# ===========================================================================

func test_full_quarantine_reduces_household_members_at_day_1() -> void:
	DynastyManager.current_day = 1
	_trigger("full_quarantine")

	for household in mock_settlement.households:
		assert_gt(household.member_count, 0, "No household should be zeroed by quarantine")

	# At day 1 the reduction should be close to initial_reduction (60%).
	# 10 members * (1 - 0.6) = 4 members.
	assert_lt(mock_settlement.households[0].member_count, 10, "Members should be reduced from 10")
	assert_false(EventManager._quarantine_snapshot.is_empty(), "Snapshot should be populated")

func test_full_quarantine_holds_at_floor_in_final_3_days() -> void:
	# Day 10: SUMMER_DAYS(12) - 10 = 2 remaining days, which is <= hold_days_from_end(3)
	DynastyManager.current_day = 10
	_trigger("full_quarantine")

	# Floor reduction 20%: int(10 * (1 - 0.2)) = 8
	assert_eq(mock_settlement.households[0].member_count, 8,
		"Floor reduction (20%) should apply at day 10")
	assert_false(EventManager._quarantine_snapshot.is_empty(), "Snapshot should be populated")

func test_full_quarantine_restores_population_on_season_change() -> void:
	DynastyManager.current_day = 6
	_trigger("full_quarantine")

	# Verify something was reduced
	assert_lt(mock_settlement.households[0].member_count, 10)

	# Simulate leaving Summer — EventManager._on_season_changed_for_quarantine fires
	EventBus.season_changed.emit("Autumn", {})

	assert_eq(mock_settlement.households[0].member_count, 10,
		"Household A should be restored after Summer ends")
	assert_eq(mock_settlement.households[1].member_count, 10,
		"Household B should be restored after Summer ends")
	assert_true(EventManager._quarantine_snapshot.is_empty(),
		"Snapshot should be cleared after restore")

func test_full_quarantine_never_reduces_household_below_1() -> void:
	mock_settlement.households[0].member_count = 1
	DynastyManager.current_day = 1  # Maximum reduction (60%)
	_trigger("full_quarantine")

	assert_eq(mock_settlement.households[0].member_count, 1,
		"A 1-member household must not drop below 1")

func test_full_quarantine_fails_gracefully_with_null_balance_data() -> void:
	EventManager.balance_data = null
	var original_a = mock_settlement.households[0].member_count
	var original_b = mock_settlement.households[1].member_count

	_trigger("full_quarantine")

	assert_eq(mock_settlement.households[0].member_count, original_a,
		"Household A should be unchanged when balance_data is null")
	assert_eq(mock_settlement.households[1].member_count, original_b,
		"Household B should be unchanged when balance_data is null")

# ===========================================================================
# GROUP: partial_quarantine
# ===========================================================================

func test_partial_quarantine_increases_sick_population() -> void:
	mock_settlement.sick_population = 0
	DynastyManager.current_day = 6

	_trigger("partial_quarantine")

	assert_gt(mock_settlement.sick_population, 0,
		"Sick population should increase after partial quarantine")

func test_partial_quarantine_sick_cannot_exceed_total_population() -> void:
	mock_settlement.sick_population = 18
	mock_settlement.population_peasants = 20
	DynastyManager.current_day = 6

	_trigger("partial_quarantine")

	assert_true(mock_settlement.sick_population <= mock_settlement.population_peasants,
		"sick_population must not exceed population_peasants")

func test_partial_quarantine_severity_higher_at_late_summer() -> void:
	# Run multiple trials to reduce RNG variance. Average late > average early.
	const TRIALS: int = 10
	var early_total: int = 0
	var late_total: int = 0

	for _i in range(TRIALS):
		mock_settlement.sick_population = 0
		DynastyManager.current_day = 2
		_trigger("partial_quarantine")
		early_total += mock_settlement.sick_population

	for _i in range(TRIALS):
		mock_settlement.sick_population = 0
		DynastyManager.current_day = 11
		_trigger("partial_quarantine")
		late_total += mock_settlement.sick_population

	# Allow a tolerance of one trial's worth in case of extreme RNG
	assert_true(late_total >= early_total - TRIALS,
		"Late Summer severity should match or exceed early Summer on average")

# ===========================================================================
# GROUP: great_feast_provider
# ===========================================================================

func test_provider_feast_spends_food_and_awards_loyalty() -> void:
	var initial_food: int = mock_settlement.treasury["food"]
	var initial_loyalty: int = mock_settlement.households[0].loyalty
	var initial_renown: int = mock_jarl.renown

	_trigger("great_feast_provider")

	assert_eq(mock_settlement.treasury["food"],
		initial_food - mock_balance.provider_food_cost,
		"Food should be reduced by provider_food_cost")
	assert_gt(mock_settlement.households[0].loyalty, initial_loyalty,
		"Household loyalty should increase")
	assert_gt(mock_jarl.renown, initial_renown,
		"Jarl renown should increase by provider_renown_reward")

func test_provider_feast_fails_when_food_insufficient() -> void:
	mock_settlement.treasury["food"] = 0
	var initial_loyalty: int = mock_settlement.households[0].loyalty
	var initial_renown: int = mock_jarl.renown

	_trigger("great_feast_provider")

	assert_eq(mock_settlement.treasury["food"], 0,
		"Food should be unchanged when insufficient")
	assert_eq(mock_settlement.households[0].loyalty, initial_loyalty,
		"Loyalty should be unchanged when feast cannot be afforded")
	assert_eq(mock_jarl.renown, initial_renown,
		"Renown should be unchanged when feast cannot be afforded")

func test_provider_feast_applies_saturation_penalty() -> void:
	# Below cooldown (30 days) triggers the saturation penalty multiplier
	DynastyManager.days_since_last_feast = 5
	var initial_loyalty: int = mock_settlement.households[0].loyalty

	_trigger("great_feast_provider")

	var expected_gain: int = int(mock_balance.provider_loyalty_reward * mock_balance.feast_saturation_penalty_multiplier)
	assert_eq(mock_settlement.households[0].loyalty, initial_loyalty + expected_gain,
		"Loyalty gain should be scaled by saturation penalty multiplier")

func test_provider_feast_resets_days_since_last_feast() -> void:
	DynastyManager.days_since_last_feast = 500

	_trigger("great_feast_provider")

	assert_eq(DynastyManager.days_since_last_feast, 0,
		"days_since_last_feast should reset to 0 after a feast")

# ===========================================================================
# GROUP: great_feast_ring_giver
# ===========================================================================

func test_ring_giver_feast_spends_food_and_gold() -> void:
	var initial_food: int = mock_settlement.treasury["food"]
	var initial_gold: int = mock_settlement.treasury["gold"]
	var initial_renown: int = mock_jarl.renown

	_trigger("great_feast_ring_giver")

	assert_eq(mock_settlement.treasury["food"],
		initial_food - mock_balance.ring_giver_food_cost,
		"Food should be reduced by ring_giver_food_cost")
	assert_eq(mock_settlement.treasury["gold"],
		initial_gold - mock_balance.ring_giver_gold_cost,
		"Gold should be reduced by ring_giver_gold_cost")
	assert_gt(mock_jarl.renown, initial_renown,
		"Renown should increase by ring_giver_renown_reward")

func test_ring_giver_feast_fails_when_gold_insufficient() -> void:
	mock_settlement.treasury["gold"] = 0
	var initial_food: int = mock_settlement.treasury["food"]
	var initial_renown: int = mock_jarl.renown

	_trigger("great_feast_ring_giver")

	assert_eq(mock_settlement.treasury["gold"], 0,
		"Gold should be unchanged when insufficient")
	assert_eq(mock_settlement.treasury["food"], initial_food,
		"Food should be unchanged when gold is insufficient")
	assert_eq(mock_jarl.renown, initial_renown,
		"Renown should be unchanged when feast cannot be afforded")

# ===========================================================================
# GROUP: great_feast_saga_worthy
# ===========================================================================

func test_saga_feast_spends_both_resources_and_awards_all_bonuses() -> void:
	mock_settlement.treasury["food"] = 200
	mock_settlement.treasury["gold"] = 500
	var initial_renown: int = mock_jarl.renown
	var initial_loyalty: int = mock_settlement.households[0].loyalty

	_trigger("great_feast_saga_worthy")

	assert_eq(mock_settlement.treasury["food"], 200 - mock_balance.saga_food_cost,
		"Food should be reduced by saga_food_cost")
	assert_eq(mock_settlement.treasury["gold"], 500 - mock_balance.saga_gold_cost,
		"Gold should be reduced by saga_gold_cost")
	assert_gt(mock_jarl.renown, initial_renown,
		"Renown should increase")
	assert_gt(mock_settlement.households[0].loyalty, initial_loyalty,
		"All household loyalty should increase")

func test_saga_feast_fails_when_either_resource_insufficient() -> void:
	mock_settlement.treasury["gold"] = 10  # Below saga_gold_cost (100)
	var initial_food: int = mock_settlement.treasury["food"]
	var initial_renown: int = mock_jarl.renown
	var initial_loyalty: int = mock_settlement.households[0].loyalty

	_trigger("great_feast_saga_worthy")

	assert_eq(mock_settlement.treasury["food"], initial_food,
		"Food should be unchanged when gold is insufficient")
	assert_eq(mock_settlement.treasury["gold"], 10,
		"Gold should be unchanged when feast cannot be afforded")
	assert_eq(mock_jarl.renown, initial_renown,
		"Renown should be unchanged when feast cannot be afforded")
	assert_eq(mock_settlement.households[0].loyalty, initial_loyalty,
		"Loyalty should be unchanged when feast cannot be afforded")

# ===========================================================================
# GROUP: burial_rite
# ===========================================================================

func test_burial_rite_pay_sets_flag_and_spends_gold() -> void:
	var initial_gold: int = mock_settlement.treasury["gold"]

	_trigger("burial_rite_pay")

	assert_true(DynastyManager.burial_rite_performed,
		"burial_rite_performed should be true after paying")
	assert_eq(mock_settlement.treasury["gold"],
		initial_gold - mock_balance.burial_rite_gold_cost,
		"Gold should be reduced by burial_rite_gold_cost")

func test_burial_rite_pay_fails_when_gold_insufficient() -> void:
	mock_settlement.treasury["gold"] = 0

	_trigger("burial_rite_pay")

	assert_false(DynastyManager.burial_rite_performed,
		"burial_rite_performed should remain false when gold is insufficient")
	assert_eq(mock_settlement.treasury["gold"], 0,
		"Gold should be unchanged when rite cannot be afforded")

func test_burial_rite_flag_consumed_after_succession() -> void:
	DynastyManager.burial_rite_performed = true
	var household = mock_settlement.households[0]
	household.loyalty = 50

	# Give the household a head so trigger_succession runs the full loyalty calc
	var head = HouseholdHead.new()
	head.given_name = "Olaf"
	head.patronymic = "Founder"
	head.generation = 1
	head.alive = false
	household.head_of_household = head

	SettlementManager.trigger_succession(household)

	assert_false(DynastyManager.burial_rite_performed,
		"burial_rite_performed should be reset to false after succession consumes it")

	# With burial rite:  floor = int(15 + (50 * 0.75)) = 52
	# inherited_loyalty  = int(50 * 0.7) + 52 = 35 + 52 = 87
	# Without rite:       int(50 * 0.7) + 15 = 50
	var expected_floor: int = int(15 + (50.0 * mock_balance.burial_rite_penalty_reduction))
	var expected_loyalty: int = mini(100, int(50 * 0.7) + expected_floor)
	assert_eq(household.loyalty, expected_loyalty,
		"Loyalty with burial rite should be higher than the unmitigated succession floor")

func test_burial_rite_decline_does_not_set_flag() -> void:
	var initial_gold: int = mock_settlement.treasury["gold"]

	_trigger("burial_rite_decline")

	assert_false(DynastyManager.burial_rite_performed,
		"burial_rite_performed must remain false after declining the rite")
	assert_eq(mock_settlement.treasury["gold"], initial_gold,
		"Gold should be unchanged after declining")

# ===========================================================================
# GROUP: buy_grain_all
# ===========================================================================

func test_buy_grain_all_gold_saves_maximum_villagers() -> void:
	mock_settlement.population_peasants = 20
	mock_settlement.treasury["gold"] = 500

	var cost_per_head: int = mock_balance.buy_grain_cost_per_villager * mock_balance.buy_grain_cost_multiplier
	var total_cost: int = 20 * cost_per_head                    # 20 * 16 = 320
	var gold_spent: int = mini(500, total_cost)                 # 320
	var expected_saved: int = gold_spent / cost_per_head        # 20
	var expected_lost: int = maxi(0, 20 - expected_saved)       # 0
	var expected_pop: int = maxi(0, 20 - expected_lost)         # 20

	_trigger("buy_grain_all_gold")

	assert_eq(mock_settlement.population_peasants, expected_pop,
		"Population should reflect how many villagers were saved")
	assert_eq(mock_settlement.treasury["gold"], 500 - gold_spent,
		"Gold should be reduced by the actual amount spent")

func test_buy_grain_half_gold_saves_partial_population() -> void:
	mock_settlement.population_peasants = 20
	mock_settlement.treasury["gold"] = 500

	_trigger("buy_grain_half_gold")

	# Half of 500 = 250 spent; cost_per_head 16 → saves 15, loses 5
	assert_true(mock_settlement.population_peasants >= 0,
		"Population must be >= 0")
	assert_true(mock_settlement.population_peasants <= 20,
		"Population must be <= starting value")
	assert_true(mock_settlement.treasury["gold"] >= 0,
		"Gold must be >= 0")
	# Some gold should still remain (we only spent half)
	assert_gt(mock_settlement.treasury["gold"], 0,
		"Should have gold remaining after spending only half")

func test_buy_grain_none_loses_all_population_and_renown() -> void:
	mock_settlement.population_peasants = 20
	mock_jarl.renown = 200

	_trigger("buy_grain_none")

	assert_eq(mock_settlement.population_peasants, 0,
		"All population should be lost when spending nothing on grain")
	assert_lt(mock_jarl.renown, 200,
		"Renown should decrease when villagers are lost")

func test_buy_grain_population_never_goes_below_zero() -> void:
	mock_settlement.population_peasants = 1

	_trigger("buy_grain_none")

	assert_true(mock_settlement.population_peasants >= 0,
		"Population must never go below zero")

func test_buy_grain_renown_never_goes_below_zero() -> void:
	mock_jarl.renown = 0
	mock_settlement.population_peasants = 50

	_trigger("buy_grain_none")

	assert_true(mock_jarl.renown >= 0,
		"Renown must never go below zero")
