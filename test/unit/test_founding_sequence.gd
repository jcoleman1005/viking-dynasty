extends GutTest

var _original_jarl: JarlData
var _original_settlement: SettlementData
var _original_balance: EventBalanceData

func before_each() -> void:
	_original_jarl = DynastyManager.current_jarl
	_original_settlement = SettlementManager.current_settlement
	_original_balance = EventManager.balance_data

	# Minimal jarl
	var jarl := JarlData.new()
	jarl.display_name = "TestJarl"
	DynastyManager.current_jarl = jarl

	# Settlement with 3 households
	var settlement := SettlementData.new()
	settlement.treasury = {"food": 200, "wood": 100, "gold": 50}
	for i in 3:
		var h := HouseholdData.new()
		h.loyalty = 50
		settlement.households.append(h)
	SettlementManager.current_settlement = settlement

	# Balance data
	var bd := EventBalanceData.new()
	bd.opportunity_seeker_winter_multiplier = 1.5
	EventManager.balance_data = bd

	# Reset founding flags
	SettlementManager.founding_warband_active = false
	SettlementManager.wildfire_risk_enabled = false
	SettlementManager.coastal_storm_risk_enabled = false
	SettlementManager.foreign_threat_visibility_enabled = false
	SettlementManager.raid_target_visibility_multiplier = 1.0

func after_each() -> void:
	DynastyManager.current_jarl = _original_jarl
	SettlementManager.current_settlement = _original_settlement
	EventManager.balance_data = _original_balance

func test_boosted_stat_in_high_range() -> void:
	var fd := FoundingData.new()
	fd.father_archetype = "warrior"
	fd.boosted_stat = "command"
	fd.penalised_stat = "diplomacy"
	FoundingSequenceManager._apply_founding_to_jarl(fd)
	var jarl := DynastyManager.current_jarl
	assert_true(jarl.command >= 10, "Boosted stat at least 10")
	assert_true(jarl.command <= 15, "Boosted stat at most 15")

func test_penalised_stat_in_low_range() -> void:
	var fd := FoundingData.new()
	fd.father_archetype = "warrior"
	fd.boosted_stat = "command"
	fd.penalised_stat = "diplomacy"
	FoundingSequenceManager._apply_founding_to_jarl(fd)
	var jarl := DynastyManager.current_jarl
	assert_true(jarl.diplomacy >= 5, "Penalised stat at least 5")
	assert_true(jarl.diplomacy <= 8, "Penalised stat at most 8")

func test_rival_jarl_exile_reduces_households() -> void:
	var fd := FoundingData.new()
	fd.exile_reason = "rival_jarl"
	fd.founding_location = ""
	fd.first_act = ""
	FoundingSequenceManager._apply_founding_to_settlement(fd)
	assert_eq(SettlementManager.current_settlement.households.size(), 2,
		"Rival Jarl exile trims households to 2")

func test_rival_jarl_exile_sets_warband_flag() -> void:
	var fd := FoundingData.new()
	fd.exile_reason = "rival_jarl"
	fd.founding_location = ""
	fd.first_act = ""
	FoundingSequenceManager._apply_founding_to_settlement(fd)
	assert_true(SettlementManager.founding_warband_active,
		"Rival Jarl exile activates founding warband flag")

func test_opportunity_exile_increases_loyalty() -> void:
	var fd := FoundingData.new()
	fd.exile_reason = "seeking_opportunity"
	fd.founding_location = ""
	fd.first_act = ""
	FoundingSequenceManager._apply_founding_to_settlement(fd)
	for household in SettlementManager.current_settlement.households:
		assert_true(household.loyalty >= 60,
			"Opportunity exile increases each household loyalty by 10")

func test_generous_gift_halves_food() -> void:
	var fd := FoundingData.new()
	fd.exile_reason = ""
	fd.founding_location = ""
	fd.first_act = "generous_gift"
	var food_before: int = SettlementManager.current_settlement.treasury.get("food", 0)
	FoundingSequenceManager._apply_founding_to_settlement(fd)
	var food_after: int = SettlementManager.current_settlement.treasury.get("food", 0)
	assert_eq(food_after, int(food_before * 0.5), "Generous gift halves starting food")

func test_founding_epithet_assembled_from_archetype_and_exile() -> void:
	var fd := FoundingData.new()
	fd.father_archetype = "warrior"
	fd.boosted_stat = "command"
	fd.penalised_stat = "diplomacy"
	fd.exile_reason = "frankish_persecution"
	FoundingSequenceManager._apply_founding_to_jarl(fd)
	# Assemble epithet separately (normally called from _finish_sequence)
	FoundingSequenceManager.current_founding_data = fd
	FoundingSequenceManager._assemble_founding_epithet()
	assert_true(DynastyManager.current_jarl.founding_epithet.length() > 0,
		"Founding epithet is non-empty")


func test_founding_epithet_builder_archetype() -> void:
	var fd := FoundingData.new()
	fd.father_archetype = "builder"
	fd.boosted_stat = "stewardship"
	fd.exile_reason = "rival_jarl"
	FoundingSequenceManager._apply_founding_to_jarl(fd)
	FoundingSequenceManager.current_founding_data = fd
	FoundingSequenceManager._assemble_founding_epithet()
	var epithet := DynastyManager.current_jarl.founding_epithet
	assert_true(epithet.length() > 0, "Builder epithet is non-empty")
	assert_true(epithet.contains("Grain-Counter") or epithet.contains("Stone-Knower"),
		"Builder epithet contains expected father title")


func test_founding_epithet_diplomat_archetype() -> void:
	var fd := FoundingData.new()
	fd.father_archetype = "diplomat"
	fd.boosted_stat = "charisma"
	fd.exile_reason = "seeking_opportunity"
	FoundingSequenceManager._apply_founding_to_jarl(fd)
	FoundingSequenceManager.current_founding_data = fd
	FoundingSequenceManager._assemble_founding_epithet()
	var epithet := DynastyManager.current_jarl.founding_epithet
	assert_true(epithet.length() > 0, "Diplomat epithet is non-empty")
	assert_true(epithet.contains("Silver-Tongued") or epithet.contains("Peace-Maker"),
		"Diplomat epithet contains expected father title")


func test_frankish_exile_reduces_food_by_30_percent() -> void:
	var fd := FoundingData.new()
	fd.exile_reason = "frankish_persecution"
	fd.founding_location = ""
	fd.first_act = ""
	var food_before: int = SettlementManager.current_settlement.treasury.get("food", 0)
	FoundingSequenceManager._apply_founding_to_settlement(fd)
	var food_after: int = SettlementManager.current_settlement.treasury.get("food", 0)
	assert_eq(food_after, int(food_before * 0.7),
		"Frankish exile reduces food by 30%")


func test_frankish_exile_sets_efficiency_obligation_flag() -> void:
	var fd := FoundingData.new()
	fd.exile_reason = "frankish_persecution"
	fd.founding_location = ""
	fd.first_act = ""
	FoundingSequenceManager._apply_founding_to_settlement(fd)
	var flagged := false
	for h in SettlementManager.current_settlement.households:
		if h.obligation_flag == "frankish_persecution_debuff":
			flagged = true
	assert_true(flagged, "Frankish exile sets obligation_flag on one household")


func test_opportunity_exile_scales_winter_harsh_chance() -> void:
	var original_chance := WinterManager.harsh_chance
	var fd := FoundingData.new()
	fd.exile_reason = "seeking_opportunity"
	fd.founding_location = ""
	fd.first_act = ""
	FoundingSequenceManager._apply_founding_to_settlement(fd)
	assert_true(WinterManager.harsh_chance > original_chance,
		"Opportunity exile increases winter harsh_chance")
	WinterManager.harsh_chance = original_chance  # restore
