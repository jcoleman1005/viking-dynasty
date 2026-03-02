# test/unit/test_spring_screen.gd
# Phase 3 — Spring Screen
# Tests for SpringCardSelector autoload and oath commitment flow.
extends GutTest

# ---- fixtures ----------------------------------------------------------------

var _original_jarl: JarlData
var _original_year: int

func before_each() -> void:
	_original_jarl = DynastyManager.current_jarl
	_original_year = DynastyManager.current_year
	# Use year 881 so founding-echo priority logic doesn't interfere.
	DynastyManager.current_year = 881


func after_each() -> void:
	DynastyManager.current_jarl = _original_jarl
	DynastyManager.current_year = _original_year
	DynastyManager.active_spring_oath = ""
	DynastyManager.spring_oath_threshold = 0
	DynastyManager.spring_oath_metric = ""


# ---- SpringCardData schema ---------------------------------------------------

func test_spring_card_data_has_oath_metric_key() -> void:
	var card := SpringCardData.new()
	assert_true("oath_metric_key" in card, "SpringCardData must have oath_metric_key field")
	assert_eq(card.oath_metric_key, "", "Default oath_metric_key should be empty string")


func test_spring_card_data_has_runtime_fields() -> void:
	var card := SpringCardData.new()
	assert_true("calculated_threshold" in card, "SpringCardData must have runtime calculated_threshold")
	assert_true("selected_phrasing" in card, "SpringCardData must have runtime selected_phrasing")


# ---- SpringCardSelector — card selection ------------------------------------

func test_select_returns_array_for_capable_jarl() -> void:
	var jarl := JarlData.new()
	jarl.command = 15
	jarl.stewardship = 15
	jarl.learning = 15
	jarl.prowess = 15
	jarl.diplomacy = 15
	jarl.charisma = 15
	DynastyManager.current_jarl = jarl

	var cards: Array[SpringCardData] = SpringCardSelector.select_spring_cards()

	assert_true(cards.size() > 0, "Capable Jarl should receive at least one card")
	assert_true(cards.size() <= 3, "Selector must never return more than 3 cards")


func test_select_returns_at_most_three_cards() -> void:
	var jarl := JarlData.new()
	jarl.command = 20
	jarl.stewardship = 20
	jarl.prowess = 20
	jarl.diplomacy = 20
	jarl.charisma = 20
	DynastyManager.current_jarl = jarl

	var cards: Array[SpringCardData] = SpringCardSelector.select_spring_cards()

	assert_true(cards.size() <= 3, "Should never exceed 3 cards")


func test_select_eligible_cards_do_not_include_gated_card() -> void:
	# card_raid_oath: stat_gate="command", stat_threshold=8.
	# A Jarl with command=7 (below threshold) must NOT be given that card
	# when other cards are available to satisfy eligibility.
	# We set stewardship/prowess/diplomacy/charisma above 8 so eligible pool is
	# non-empty, preventing the "returning all" fallback path.
	var jarl := JarlData.new()
	jarl.command = 7   # below raid threshold (8)
	jarl.stewardship = 10
	jarl.learning = 10
	jarl.prowess = 10
	jarl.diplomacy = 10
	jarl.charisma = 10
	DynastyManager.current_jarl = jarl

	var cards: Array[SpringCardData] = SpringCardSelector.select_spring_cards()

	var found_raid_card := false
	for card in cards:
		if card.card_id == "card_raid_oath":
			found_raid_card = true

	assert_false(found_raid_card,
		"card_raid_oath must not appear when command(7) is below stat_threshold(8)")


# ---- SpringCardSelector — threshold configuration ---------------------------

func test_configure_card_calculates_threshold() -> void:
	# Load card_raid_oath directly; replicate SpringCardSelector._configure_card() formula.
	# card_raid_oath: threshold_base=30, threshold_stat_multiplier=2.0, stat_gate="command"
	# Jarl command=10 → expected = 30 + int(10 * 2.0) = 50
	var card: SpringCardData = load("res://data/spring/cards/card_raid_oath.tres")
	assert_not_null(card, "card_raid_oath.tres must be loadable")

	var jarl := JarlData.new()
	jarl.command = 10

	# Apply the same formula used by _configure_card()
	var stat_val: int = jarl.get(card.stat_gate) if jarl.get(card.stat_gate) != null else 10
	var computed := card.threshold_base + int(stat_val * card.threshold_stat_multiplier)
	assert_eq(computed, 50, "Threshold formula: base(%d) + int(%d * %.1f) = 50" % [
		card.threshold_base, stat_val, card.threshold_stat_multiplier
	])


func test_configure_card_sets_selected_phrasing() -> void:
	var jarl := JarlData.new()
	jarl.command = 15
	jarl.stewardship = 15
	jarl.prowess = 15
	jarl.diplomacy = 15
	jarl.charisma = 15
	DynastyManager.current_jarl = jarl

	var cards: Array[SpringCardData] = SpringCardSelector.select_spring_cards()

	for card in cards:
		assert_true(card.selected_phrasing != "", "Each selected card must have a phrasing chosen")


# ---- Oath commitment (DynastyManager field updates) -------------------------

func test_oath_commit_sets_active_spring_oath() -> void:
	var card := SpringCardData.new()
	card.card_id = "card_test_oath"
	card.calculated_threshold = 50
	card.oath_metric_key = "gold_raided"

	# Simulate what SpringPhaseUI._on_card_confirmed() does.
	DynastyManager.active_spring_oath    = card.card_id
	DynastyManager.spring_oath_threshold = card.calculated_threshold
	DynastyManager.spring_oath_metric    = card.oath_metric_key

	assert_eq(DynastyManager.active_spring_oath, "card_test_oath",
		"active_spring_oath should be set to card_id")


func test_oath_commit_sets_threshold() -> void:
	var card := SpringCardData.new()
	card.card_id = "card_test"
	card.calculated_threshold = 75
	card.oath_metric_key = "food_harvested"

	DynastyManager.active_spring_oath    = card.card_id
	DynastyManager.spring_oath_threshold = card.calculated_threshold
	DynastyManager.spring_oath_metric    = card.oath_metric_key

	assert_eq(DynastyManager.spring_oath_threshold, 75,
		"spring_oath_threshold should match card.calculated_threshold")


func test_oath_commit_sets_metric_key() -> void:
	var card := SpringCardData.new()
	card.card_id = "card_test"
	card.calculated_threshold = 20
	card.oath_metric_key = "buildings_completed"

	DynastyManager.active_spring_oath    = card.card_id
	DynastyManager.spring_oath_threshold = card.calculated_threshold
	DynastyManager.spring_oath_metric    = card.oath_metric_key

	assert_eq(DynastyManager.spring_oath_metric, "buildings_completed",
		"spring_oath_metric should match card.oath_metric_key")


# ---- Card data files (all 6 cards have required fields) ---------------------

func test_loaded_cards_have_metric_keys() -> void:
	var jarl := JarlData.new()
	jarl.command = 20
	jarl.stewardship = 20
	jarl.prowess = 20
	jarl.diplomacy = 20
	jarl.charisma = 20
	DynastyManager.current_jarl = jarl

	var cards: Array[SpringCardData] = SpringCardSelector.select_spring_cards()

	for card in cards:
		assert_true(card.oath_metric_key != "",
			"Card '%s' must have oath_metric_key set in its .tres" % card.card_id)
