#res://autoload/EventManager.gd
# res://autoload/EventManager.gd
extends Node

@export var event_ui_scene: PackedScene
@export var succession_crisis_scene: PackedScene

# Balance data resource — must be assigned in the Godot Inspector by dragging
# in res://data/balance/EventBalanceData.tres. Handlers will log an error and
# return early if this is null at runtime.
@export var balance_data: EventBalanceData

var event_ui: EventUI
var available_events: Array[EventData] = []
# CHANGE: Added specific storage for disputes as they are a distinct Resource type from EventData
var available_disputes: Array[DisputeEventData] = []
var fired_unique_events: Array[String] = []

# Stores original household member counts while full_quarantine is active.
# Format: { household_name: int }
var _quarantine_snapshot: Dictionary = {}

const TRAIT_RIVAL = preload("res://data/traits/Trait_Rival.tres")

func _ready() -> void:
	call_deferred("initialize_event_system")

func initialize_event_system() -> void:
	if not event_ui_scene:
		Loggie.msg("'event_ui_scene' is not set!").domain("EVENT").error()
		return

	event_ui = event_ui_scene.instantiate()
	add_child(event_ui)
	event_ui.choice_made.connect(_on_choice_made)

	_load_events_from_disk()

	if DynastyManager:
		DynastyManager.year_ended.connect(_on_year_ended)
		DynastyManager.jarl_stats_updated.connect(func(_data): _sync_event_history())
	else:
		Loggie.msg("DynastyManager Autoload not found!").domain("EVENT").error()

	if EventBus.has_signal("season_changed"):
		EventBus.season_changed.connect(_on_season_changed_for_quarantine)

	if not balance_data:
		Loggie.msg("EventManager: 'balance_data' is not assigned in the Inspector! Event handlers will not function correctly.").domain("EVENT").warn()

func _on_season_changed_for_quarantine(season_name: String, _context: Dictionary) -> void:
	# Restore quarantine populations only when Summer ends (not mid-Summer day changes)
	if season_name != "Summer" and not _quarantine_snapshot.is_empty():
		_restore_quarantine_populations()

func _sync_event_history() -> void:
	if DynastyManager.current_jarl:
		fired_unique_events = \
		DynastyManager.current_jarl.event_history.duplicate()

func _load_events_from_disk() -> void:
	available_events.clear()
	available_disputes.clear() # CHANGE: Clear dispute list on reload
	var dir = DirAccess.open("res://data/events/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path = "res://data/events/" + file_name
				# CHANGE: Load as generic Resource first to check type, solving the casting error
				var resource = load(path)
				if resource is EventData:
					available_events.append(resource)
				elif resource is DisputeEventData:
					available_disputes.append(resource)
				else:
					Loggie.msg("Loaded resource is neither EventData nor DisputeEventData: %s" % path).domain("EVENT").warn()
			file_name = dir.get_next()
	# CHANGE: Updated log to reflect both types
	Loggie.msg("Loaded %d events and %d disputes from disk. Total Pool: %d" % [available_events.size(), available_disputes.size(), available_events.size()]).domain("EVENT").info()

func _on_year_ended() -> void:
	Loggie.msg("Checking event triggers for end of year...").domain("EVENT").info()
	var event_was_triggered: bool = _check_event_triggers()
	if not event_was_triggered:
		EventBus.event_system_finished.emit()

func check_daily_events(day: int) -> void:
	Loggie.msg("check_daily_events called. Day: %d Season: %s | Events in Pool: %d" % [day, DynastyManager.get_current_season_name(), available_events.size()]).domain("EVENT").info()
	var jarl = DynastyManager.current_jarl
	if not jarl:
		return
	var season_name = DynastyManager.get_current_season_name()

	for event in available_events:
		if event.trigger_season != "" \
		and event.trigger_season != season_name:
			continue

		if event.trigger_day != -1 \
		and event.trigger_day != day:
			continue

		if _check_conditions(event, jarl):
			_trigger_event(event)
			return

func _check_event_triggers() -> bool:
	var jarl = DynastyManager.get_current_jarl()
	if not jarl:
		Loggie.msg("Cannot check events, Jarl data is null.").domain("EVENT").error()
		return false

	for event in available_events:
		if not event.trigger_season.is_empty():
			continue

		if _check_conditions(event, jarl):
			_trigger_event(event)
			return true
	return false

func _check_conditions(event: EventData, jarl: JarlData) -> bool:
	Loggie.msg("Checking conditions for event: %s" % event.event_id).domain("EVENT").debug()

	if event.is_unique and event.event_id in fired_unique_events:
		Loggie.msg("%s FAILED: already fired" % event.event_id).domain("EVENT").debug()
		return false
	for pre_id in event.prerequisites:
		if not pre_id in fired_unique_events:
			Loggie.msg("%s FAILED: prerequisite missing: %s" % [event.event_id, pre_id]).domain("EVENT").debug()
			return false

	if event.min_renown > -1 and jarl.renown < event.min_renown:
		Loggie.msg("%s FAILED: low renown" % event.event_id).domain("EVENT").debug()
		return false
	if event.min_stewardship > -1 and jarl.get_effective_skill("stewardship") < event.min_stewardship:
		Loggie.msg("%s FAILED: low stewardship" % event.event_id).domain("EVENT").debug()
		return false
	if not event.must_have_trait.is_empty() and not jarl.has_trait(event.must_have_trait):
		Loggie.msg("%s FAILED: missing trait: %s" % [event.event_id, event.must_have_trait]).domain("EVENT").debug()
		return false
	if not event.must_not_have_trait.is_empty() and jarl.has_trait(event.must_not_have_trait):
		Loggie.msg("%s FAILED: has forbidden trait: %s" % [event.event_id, event.must_not_have_trait]).domain("EVENT").debug()
		return false
	if event.min_available_heirs > -1 and jarl.get_available_heir_count() < event.min_available_heirs:
		Loggie.msg("%s FAILED: low heirs" % event.event_id).domain("EVENT").debug()
		return false
	if event.min_conquered_regions > -1 and jarl.conquered_regions.size() < event.min_conquered_regions:
		Loggie.msg("%s FAILED: low regions" % event.event_id).domain("EVENT").debug()
		return false

	# --- Pass 3 Custom Conditions ---
	# Harvest yield condition
	if event.event_id == "autumn_wounded_harvest":
		var modifier = EconomyManager.get_harvest_yield_modifier()
		if modifier >= -0.3:
			Loggie.msg("%s FAILED: harvest not wounded enough" % event.event_id).domain("EVENT").debug()
			return false

	# Household loyalty condition
	if event.event_id == "summer_oath_break":
		if SettlementManager.get_lowest_loyalty() >= 3:
			Loggie.msg("%s FAILED: loyalty too high" % event.event_id).domain("EVENT").debug()
			return false

	# Flag-based chance modifier
	var chance = event.base_chance
	if event.event_id == "winter_sickness_outbreak":
		if DynastyManager.active_year_modifiers.has("sickness_seed"):
			chance = 0.85

	if randf() > chance:
		Loggie.msg("%s FAILED: chance roll" % event.event_id).domain("EVENT").debug()
		return false

	Loggie.msg("Conditions MET for event '%s'" % event.event_id).domain("EVENT").info()
	return true

func _trigger_event(event_data: EventData) -> void:
	if not event_ui:
		Loggie.msg("EventManager: EventUI not initialized.").domain("EVENT").error()
		return

	Loggie.msg("Triggering Event: %s" % event_data.event_id).domain("EVENT").info()

	# Pause the game for the modal event
	get_tree().paused = true
	event_ui.display_event(event_data)

	if event_data.is_unique:
		fired_unique_events.append(event_data.event_id)
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.event_history.append(
				event_data.event_id)

func trigger_event_by_id(id: String) -> void:
	for event in available_events:
		if event.event_id == id:
			_trigger_event(event)
			return

	Loggie.msg("EventManager: Event ID '%s' not found." % id).domain("EVENT").info()

## Returns a list of disputes available for the current winter.
func get_available_disputes() -> Array[DisputeEventData]:
	# CHANGE: Return the distinct array populated during load
	if available_disputes.is_empty():
		return [draw_dispute_card()]
	return available_disputes

func draw_dispute_card() -> DisputeEventData:
	var card = DisputeEventData.new()
	card.title = "Stolen Cattle"
	card.description = "A Bondi accuses a Huscarl of theft."
	card.gold_cost = 50
	card.renown_cost = 10
	card.penalty_modifier_key = "angry_bondi"
	card.penalty_description = "Recruitment halted."
	return card

func _on_choice_made(event: EventData, choice: EventChoice) -> void:
	if not event:
		Loggie.msg("EventManager: choice_made signal received with null event data.").domain("EVENT").warn()
		# Clean up UI state
		if not event_ui.visible:
			get_tree().paused = false
			EventBus.event_system_finished.emit()
		return

	if choice:
		Loggie.msg("Player chose '%s' (%s) for event '%s'" % [choice.choice_text, choice.effect_key, event.event_id]).domain("EVENT").info()
		_apply_event_consequences(event, choice)
	else:
		Loggie.msg("Event '%s' closed with no choice." % event.event_id).domain("EVENT").info()

	# ONLY unpause if the UI is actually hidden (i.e., no follow-up event was triggered)
	if not event_ui.visible:
		get_tree().paused = false
		EventBus.event_system_finished.emit()

## Appends a structured entry to DynastyManager.year_event_log.
## Called at the end of significant event handlers so SkaldReportGenerator can read them.
## significance: 1 = minor, 2 = notable, 3 = saga-worthy
func _log_skald_event(event_id: String, variables: Dictionary, significance: int = 1) -> void:
	DynastyManager.year_event_log.append({
		"event_id":    event_id,
		"variables":   variables,
		"significance": significance,
	})


func _apply_event_consequences(event: EventData, choice: EventChoice) -> void:
	var result_data: Dictionary = {}

	# --- Winter Crisis Logic ---
	if choice.effect_key == "winter_crisis_buy_gold":
		result_data = WinterManager.resolve_crisis_with_gold()

	elif choice.effect_key == "winter_crisis_starve_peasants":
		result_data = WinterManager.resolve_crisis_with_sacrifice("starve_peasants")

	elif choice.effect_key == "winter_crisis_family_rations":
		result_data = WinterManager.resolve_crisis_with_family_sacrifice()

	# --- Pass 2 Event Handlers ---
	elif choice.effect_key == "hire_seer":
		DynastyManager.apply_year_modifier("seer_present")
		EconomyManager.add_resource("gold", -30)

	elif choice.effect_key == "dismiss_seer":
		pass

	elif choice.effect_key == "demand_seer":
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.renown -= 10

	elif choice.effect_key == "contain_fever":
		EconomyManager.add_resource("food", -20)
		EconomyManager.add_resource("gold", -10)

	elif choice.effect_key == "partial_response":
		EconomyManager.add_resource("food", -10)
		if randf() < 0.5:
			DynastyManager.apply_year_modifier("sickness_seed")

	elif choice.effect_key == "ignore_fever":
		DynastyManager.apply_year_modifier("sickness_seed")

	elif choice.effect_key == "full_quarantine":
		_handle_full_quarantine()

	elif choice.effect_key == "partial_quarantine":
		_handle_partial_quarantine()

	elif choice.effect_key == "consult_volva":
		if DynastyManager.active_year_modifiers.has("sickness_seed"):
			DynastyManager.active_year_modifiers.erase("sickness_seed")
		print("consult_volva: sickness resolved")

	elif choice.effect_key == "ignore_sickness":
		var _is_settlement = SettlementManager.current_settlement
		if _is_settlement and _is_settlement.sick_population > 0:
			var _deaths = int(_is_settlement.sick_population * 0.10)
			if _deaths == 0:
				_deaths = 1
			_is_settlement.population_peasants = max(0, _is_settlement.population_peasants - _deaths)
			_is_settlement.sick_population = max(0, _is_settlement.sick_population - _deaths)
			EconomyManager.clamp_demographics(_is_settlement)
			EventBus.treasury_updated.emit(_is_settlement.treasury)
			SettlementManager.save_settlement()

	# --- Pass 3 Event Handlers ---
	elif choice.effect_key == "honour_oath":
		EconomyManager.add_resource("gold", -20)
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.renown += 10

	elif choice.effect_key == "deflect_oath":
		DynastyManager.apply_year_modifier("deflected_oath")

	elif choice.effect_key == "pay_off_oath":
		EconomyManager.add_resource("gold", -40)

	elif choice.effect_key == "grant_land":
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.renown += 10
		print("grant_land: building plot reduction TBD")

	elif choice.effect_key == "pay_bondi":
		EconomyManager.add_resource("gold", -50)

	elif choice.effect_key == "assert_authority":
		print("assert_authority: bondi disgruntled flag TBD")

	elif choice.effect_key == "elevate_bondi":
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.current_authority -= 1
		print("elevate_bondi: new household creation TBD")

	elif choice.effect_key == "mediate_oath":
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.current_authority -= 1

	elif choice.effect_key == "gift_mediate":
		EconomyManager.add_resource("gold", -30)

	elif choice.effect_key == "reassign_rival":
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.current_authority -= 1

	elif choice.effect_key == "coerce_harvest":
		var _ch_settlement = SettlementManager.current_settlement
		if _ch_settlement:
			for _household in _ch_settlement.households:
				_household.loyalty = max(0, _household.loyalty - 5)
			SettlementManager.save_settlement()

	elif choice.effect_key == "trial_stranger":
		if DynastyManager.current_jarl:
			DynastyManager.current_jarl.campaign_flags["stranger_accepted"] = true
		print("trial_stranger: champion unit spawn TBD")

	elif choice.effect_key == "refuse_stranger":
		pass

	elif choice.effect_key == "interrogate_stranger":
		print("interrogate_stranger: unique branch TBD")

	elif choice.effect_key == "slaughter_livestock":
		EconomyManager.add_resource("food", 40)
		DynastyManager.apply_year_modifier("harvest_penalty_next")

	elif choice.effect_key == "emergency_hunt":
		print("emergency_hunt: household reassignment TBD")

	elif choice.effect_key == "weather_shortage":
		DynastyManager.apply_year_modifier("harsh_winter_threshold")

	# --- Pass 1 Event Handlers: Great Feast ---
	elif choice.effect_key == "great_feast":
		_handle_great_feast()

	elif choice.effect_key == "great_feast_provider":
		_handle_great_feast_provider()

	elif choice.effect_key == "great_feast_ring_giver":
		_handle_great_feast_ring_giver()

	elif choice.effect_key == "great_feast_saga_worthy":
		_handle_great_feast_saga_worthy()

	# --- Pass 1 Event Handlers: Burial Rite ---
	elif choice.effect_key == "burial_rite":
		_handle_burial_rite()

	elif choice.effect_key == "burial_rite_pay":
		_handle_burial_rite_pay()

	elif choice.effect_key == "burial_rite_decline":
		_handle_burial_rite_decline()

	# --- Pass 1 Event Handlers: Buy Grain ---
	elif choice.effect_key == "buy_grain_all":
		_handle_buy_grain_all()

	elif choice.effect_key == "buy_grain_all_gold":
		_handle_buy_grain_all_gold()

	elif choice.effect_key == "buy_grain_half_gold":
		_handle_buy_grain_half_gold()

	elif choice.effect_key == "buy_grain_none":
		_handle_buy_grain_none()

	# If we have a crisis result, show the follow-up narrative window
	if not result_data.is_empty():
		show_crisis_result(result_data)
		return

	# --- Legacy Event Logic ---
	if event.event_id == "ambitious_heir_1":
		if choice.effect_key == "accept":
			if not DynastyManager.spend_renown(100):
				Loggie.msg("Tried to spend 100 Renown for event, but failed.").domain("EVENT").warn()
		elif choice.effect_key == "decline":
			var heir = DynastyManager.get_current_jarl().get_first_available_heir()
			if heir and TRAIT_RIVAL:
				DynastyManager.add_trait_to_heir(heir, TRAIT_RIVAL)
			else:
				Loggie.msg("Could not apply 'Rival' trait.").domain("EVENT").warn()

# ---------------------------------------------------------------------------
# HELPER: Quarantine Reduction Calculation
# ---------------------------------------------------------------------------

## Returns the current quarantine labor reduction fraction based on the Summer day.
## Early in Summer the reduction is high (initial_reduction).
## In the final `hold_days_from_end` days the floor is held constant.
func _get_quarantine_reduction() -> float:
	var current_day: int = DynastyManager.current_day
	var summer_days: int = DynastyManager.SUMMER_DAYS
	var days_remaining: int = summer_days - current_day

	if days_remaining <= balance_data.full_quarantine_hold_days_from_end:
		return balance_data.full_quarantine_floor_reduction

	# Linear interpolation from initial_reduction down to floor_reduction
	# across the "non-floor" portion of the season.
	var non_floor_days: int = summer_days - balance_data.full_quarantine_hold_days_from_end
	# Progress: 0.0 at day 1, 1.0 at the day the floor kicks in
	var progress: float = float(current_day - 1) / float(max(1, non_floor_days - 1))
	progress = clampf(progress, 0.0, 1.0)
	return lerpf(balance_data.full_quarantine_initial_reduction, balance_data.full_quarantine_floor_reduction, progress)

# ---------------------------------------------------------------------------
# HANDLER: full_quarantine (Task 3)
# ---------------------------------------------------------------------------

func _handle_full_quarantine() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	var reduction: float = _get_quarantine_reduction()

	# Snapshot original counts before modification
	_quarantine_snapshot.clear()
	for household in settlement.households:
		_quarantine_snapshot[household.household_name] = household.member_count

	# Apply reduction, minimum 1 member per household
	for household in settlement.households:
		var original: int = household.member_count
		var reduced: int = int(original * (1.0 - reduction))
		household.member_count = max(1, reduced)

	EventBus.treasury_updated.emit(settlement.treasury)
	SettlementManager.save_settlement()
	Loggie.msg("full_quarantine applied. Reduction: %.0f%%. Snapshot stored." % (reduction * 100)).domain("EVENT").info()

## Restores household member counts from the quarantine snapshot.
## Called automatically when the season leaves Summer.
func _restore_quarantine_populations() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement or _quarantine_snapshot.is_empty():
		return

	for household in settlement.households:
		if _quarantine_snapshot.has(household.household_name):
			household.member_count = _quarantine_snapshot[household.household_name]

	_quarantine_snapshot.clear()
	SettlementManager.save_settlement()
	Loggie.msg("Quarantine populations restored.").domain("EVENT").info()

# ---------------------------------------------------------------------------
# HANDLER: partial_quarantine (Task 4)
# ---------------------------------------------------------------------------

func _handle_partial_quarantine() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	var current_day: float = float(DynastyManager.current_day)
	var summer_days: float = float(DynastyManager.SUMMER_DAYS)

	# Exponential severity curve: slow early in Summer, fast late
	var base_severity: float = pow(current_day / summer_days, balance_data.partial_quarantine_exponent) \
		* balance_data.partial_quarantine_max_reduction

	var variance: float = randf_range(
		-balance_data.partial_quarantine_random_variance,
		balance_data.partial_quarantine_random_variance
	)
	var final_severity: float = clampf(
		base_severity + variance,
		0.0,
		balance_data.partial_quarantine_max_reduction
	)

	var sick_increase: int = int(settlement.population_peasants * final_severity)
	settlement.sick_population = mini(
		settlement.sick_population + sick_increase,
		settlement.population_peasants
	)

	SettlementManager.save_settlement()

	# Flavor text based on severity
	var flavor: String
	if final_severity < 0.2:
		flavor = "The sickness spread slowly. Your caution may have been enough."
	elif final_severity <= 0.5:
		flavor = "The disease crept through several households. You will feel this in the fields."
	else:
		flavor = "The quarantine failed to contain it. The sickness runs through your settlement like wildfire."

	# Follow-up EventUI
	var follow_up = EventData.new()
	follow_up.title = "The Sickness Spreads"
	follow_up.description = flavor
	follow_up.event_id = "partial_quarantine_result"

	var dismiss = EventChoice.new()
	dismiss.choice_text = "Odin's will."
	follow_up.choices.append(dismiss)

	event_ui.display_event(follow_up)

# ---------------------------------------------------------------------------
# HANDLER: great_feast (Task 5 — entry point)
# ---------------------------------------------------------------------------

func _handle_great_feast() -> void:
	if not balance_data:
		return

	var desc: String = "A feast binds lord and people together. Choose how you wish to be remembered."

	# Saturation warning
	if DynastyManager.days_since_last_feast < balance_data.feast_saturation_cooldown_days:
		desc += "\n\n[color=yellow]Your people have feasted recently. The impact will be diminished.[/color]"

	var follow_up = EventData.new()
	follow_up.title = "What Kind of Feast?"
	follow_up.description = desc
	follow_up.event_id = "great_feast_choice"

	var choice_provider = EventChoice.new()
	choice_provider.choice_text = "The Provider's Feast — 50 Food"
	choice_provider.tooltip_text = "Feed your people. Strengthen their loyalty to you as their source of life."
	choice_provider.effect_key = "great_feast_provider"

	var choice_ring = EventChoice.new()
	choice_ring.choice_text = "The Ring-Giver's Feast — 20 Food, 60 Gold"
	choice_ring.tooltip_text = "Spend treasure to buy glory. Your name will travel far as a generous lord."
	choice_ring.effect_key = "great_feast_ring_giver"

	var choice_saga = EventChoice.new()
	choice_saga.choice_text = "The Saga-Worthy Feast — 100 Food, 100 Gold"
	choice_saga.tooltip_text = "Empty your stores for legend. This will be remembered in oral tradition."
	choice_saga.effect_key = "great_feast_saga_worthy"

	follow_up.choices.append(choice_provider)
	follow_up.choices.append(choice_ring)
	follow_up.choices.append(choice_saga)

	event_ui.display_event(follow_up)

# ---------------------------------------------------------------------------
# HANDLER: great_feast_provider (Task 6)
# ---------------------------------------------------------------------------

func _handle_great_feast_provider() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	# Affordability check
	if settlement.treasury.get("food", 0) < balance_data.provider_food_cost:
		_show_simple_event(
			"The Larder Is Bare",
			"You cannot host a feast your stores cannot support. Your people notice.",
			"Understood."
		)
		return

	# Saturation multiplier
	var saturation_multiplier: float = 1.0
	if DynastyManager.days_since_last_feast < balance_data.feast_saturation_cooldown_days:
		saturation_multiplier = balance_data.feast_saturation_penalty_multiplier

	# Spend food
	EconomyManager.add_resource("food", -balance_data.provider_food_cost)

	# Award renown
	if DynastyManager.current_jarl:
		DynastyManager.current_jarl.renown += int(balance_data.provider_renown_reward * saturation_multiplier)

	# Award loyalty to all households
	var loyalty_gain: int = int(balance_data.provider_loyalty_reward * saturation_multiplier)
	for household in settlement.households:
		household.loyalty = mini(100, household.loyalty + loyalty_gain)

	# Reset feast saturation
	DynastyManager.days_since_last_feast = 0

	EventBus.treasury_updated.emit(settlement.treasury)
	SettlementManager.save_settlement()

	_show_simple_event(
		"The People Are Fed",
		"Smoke rises from every hearth. Bowls are filled. Your name is spoken with warmth tonight.",
		"As it should be."
	)

# ---------------------------------------------------------------------------
# HANDLER: great_feast_ring_giver (Task 7)
# ---------------------------------------------------------------------------

func _handle_great_feast_ring_giver() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	# Affordability check (both food AND gold)
	var has_food: bool = settlement.treasury.get("food", 0) >= balance_data.ring_giver_food_cost
	var has_gold: bool = settlement.treasury.get("gold", 0) >= balance_data.ring_giver_gold_cost
	if not has_food or not has_gold:
		_show_simple_event(
			"The Coffers Are Empty",
			"You cannot offer what you do not have. The warband remembers.",
			"So be it."
		)
		return

	# Saturation multiplier
	var saturation_multiplier: float = 1.0
	if DynastyManager.days_since_last_feast < balance_data.feast_saturation_cooldown_days:
		saturation_multiplier = balance_data.feast_saturation_penalty_multiplier

	# Spend resources
	EconomyManager.add_resource("food", -balance_data.ring_giver_food_cost)
	EconomyManager.add_resource("gold", -balance_data.ring_giver_gold_cost)

	# Award renown
	if DynastyManager.current_jarl:
		DynastyManager.current_jarl.renown += int(balance_data.ring_giver_renown_reward * saturation_multiplier)

	# TODO: [Ring-Giver Feast] Apply morale reward to warbands when WarbandData.morale is implemented.
	# Intended reward: ring_giver_warband_morale_reward. Future consideration: target only
	# elite/named warbands rather than all units.

	# Reset feast saturation
	DynastyManager.days_since_last_feast = 0

	EventBus.treasury_updated.emit(settlement.treasury)
	SettlementManager.save_settlement()

	_show_simple_event(
		"Gold Well Spent",
		"Gold rings pass from your hands to strong ones. The skalds take note. Your name grows.",
		"Let the skalds sing of it."
	)

# ---------------------------------------------------------------------------
# HANDLER: great_feast_saga_worthy (Task 8)
# ---------------------------------------------------------------------------

func _handle_great_feast_saga_worthy() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	# Affordability check (both food AND gold)
	var has_food: bool = settlement.treasury.get("food", 0) >= balance_data.saga_food_cost
	var has_gold: bool = settlement.treasury.get("gold", 0) >= balance_data.saga_gold_cost
	if not has_food or not has_gold:
		_show_simple_event(
			"The Stores Cannot Bear It",
			"A saga-worthy feast demands more than you can give. The opportunity passes.",
			"Not today."
		)
		return

	# Saturation multiplier
	var saturation_multiplier: float = 1.0
	if DynastyManager.days_since_last_feast < balance_data.feast_saturation_cooldown_days:
		saturation_multiplier = balance_data.feast_saturation_penalty_multiplier

	# Spend both resources
	EconomyManager.add_resource("food", -balance_data.saga_food_cost)
	EconomyManager.add_resource("gold", -balance_data.saga_gold_cost)

	# Award renown
	if DynastyManager.current_jarl:
		DynastyManager.current_jarl.renown += int(balance_data.saga_renown_reward * saturation_multiplier)

	# Restore loyalty for all households
	var loyalty_gain: int = int(balance_data.saga_loyalty_reward * saturation_multiplier)
	for household in settlement.households:
		household.loyalty = mini(100, household.loyalty + loyalty_gain)

	# TODO: [Saga-Worthy Feast] In future, emit a campaign flag or trigger a follow-up event chain
	# (e.g. diplomatic visit from a neighbouring Jarl, or a Blood Feud resolution option).

	# Reset feast saturation
	DynastyManager.days_since_last_feast = 0

	EventBus.treasury_updated.emit(settlement.treasury)
	SettlementManager.save_settlement()

	_show_simple_event(
		"A Night For The Ages",
		"Every horn is filled. Every fire burns high. Songs will carry this night across generations. Your deeds outlive you.",
		"This will outlive us all."
	)

# ---------------------------------------------------------------------------
# HANDLER: burial_rite (Task 9 — entry point)
# ---------------------------------------------------------------------------

func _handle_burial_rite() -> void:
	if not balance_data:
		return

	var follow_up = EventData.new()
	follow_up.title = "A Jarl Must Be Laid to Rest"
	follow_up.description = "The rite demands gold. Without it, the household bonds will fray."
	follow_up.event_id = "burial_rite_choice"

	var choice_pay = EventChoice.new()
	choice_pay.choice_text = "Honour the rite. (%d Gold)" % balance_data.burial_rite_gold_cost
	choice_pay.tooltip_text = "Spend gold to ease the succession. Household loyalty loss will be reduced."
	choice_pay.effect_key = "burial_rite_pay"

	var choice_decline = EventChoice.new()
	choice_decline.choice_text = "The settlement cannot afford it. Accept the loss."
	choice_decline.tooltip_text = "No gold spent. Households will suffer the full loyalty penalty."
	choice_decline.effect_key = "burial_rite_decline"

	follow_up.choices.append(choice_pay)
	follow_up.choices.append(choice_decline)

	event_ui.display_event(follow_up)

func _handle_burial_rite_pay() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	# Affordability check
	if settlement.treasury.get("gold", 0) < balance_data.burial_rite_gold_cost:
		_show_simple_event(
			"Your Treasury Is Empty",
			"Your treasury is empty. The rite goes unperformed.",
			"The dead must wait."
		)
		return

	# Spend gold and set the flag for SettlementManager.trigger_succession()
	EconomyManager.add_resource("gold", -balance_data.burial_rite_gold_cost)
	DynastyManager.burial_rite_performed = true

	EventBus.treasury_updated.emit(settlement.treasury)
	SettlementManager.save_settlement()

	_show_simple_event(
		"The Rite Is Honoured",
		"Fire and song carry the Jarl to Valhalla. The transition is eased. Your people grieve, but they do not doubt.",
		"May his name endure."
	)

func _handle_burial_rite_decline() -> void:
	_show_simple_event(
		"The Dead Are Left Unmourned",
		"No rite. No gold spent. The households murmur — a Jarl unmourned is a lord unloved. Loyalty will suffer through the succession.",
		"We cannot afford sentiment."
	)

# ---------------------------------------------------------------------------
# HANDLER: buy_grain_all (Task 10 — entry point and resolution)
# ---------------------------------------------------------------------------

func _handle_buy_grain_all() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	var cost_per_head: int = balance_data.buy_grain_cost_per_villager * balance_data.buy_grain_cost_multiplier
	var total_cost: int = settlement.population_peasants * cost_per_head
	var gold: int = settlement.treasury.get("gold", 0)

	var all_gold_saves: int = mini(gold / cost_per_head, settlement.population_peasants)
	var half_gold: int = int(gold * 0.5)
	var half_gold_saves: int = mini(half_gold / cost_per_head, settlement.population_peasants)
	var pop: int = settlement.population_peasants

	var follow_up = EventData.new()
	follow_up.title = "Purchase Grain for the Hungry"
	follow_up.description = "Famine stalks your settlement. Gold can buy grain — but not enough for all.\n\nCost per head: %d Gold." % cost_per_head
	follow_up.event_id = "buy_grain_choice"

	var choice_all = EventChoice.new()
	choice_all.choice_text = "Spend All Gold — saves ~%d villagers" % all_gold_saves
	choice_all.tooltip_text = "Spend your entire treasury. Save as many as your gold allows."
	choice_all.effect_key = "buy_grain_all_gold"

	var choice_half = EventChoice.new()
	choice_half.choice_text = "Spend Half Gold — saves ~%d villagers" % half_gold_saves
	choice_half.tooltip_text = "A compromise. Lose some people, keep some reserves."
	choice_half.effect_key = "buy_grain_half_gold"

	var choice_none = EventChoice.new()
	choice_none.choice_text = "Accept the Losses — all %d villagers lost" % pop
	choice_none.tooltip_text = "Spend nothing. Your people will die, and your name will suffer."
	choice_none.effect_key = "buy_grain_none"

	follow_up.choices.append(choice_all)
	follow_up.choices.append(choice_half)
	follow_up.choices.append(choice_none)

	event_ui.display_event(follow_up)

## Shared resolution logic for all grain purchase tiers.
func _resolve_grain_purchase(gold_spent: int) -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	var cost_per_head: int = balance_data.buy_grain_cost_per_villager * balance_data.buy_grain_cost_multiplier
	var villagers_saved: int = gold_spent / cost_per_head if cost_per_head > 0 else 0
	var villagers_lost: int = maxi(0, settlement.population_peasants - villagers_saved)

	EconomyManager.add_resource("gold", -gold_spent)
	settlement.population_peasants = maxi(0, settlement.population_peasants - villagers_lost)

	if DynastyManager.current_jarl:
		var renown_loss: int = villagers_lost * balance_data.buy_grain_renown_loss_on_failure
		DynastyManager.current_jarl.renown = maxi(0, DynastyManager.current_jarl.renown - renown_loss)

	EventBus.treasury_updated.emit(settlement.treasury)
	SettlementManager.save_settlement()

func _handle_buy_grain_all_gold() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	var cost_per_head: int = balance_data.buy_grain_cost_per_villager * balance_data.buy_grain_cost_multiplier
	var total_cost: int = settlement.population_peasants * cost_per_head
	var gold_spent: int = mini(settlement.treasury.get("gold", 0), total_cost)
	var saved: int = gold_spent / cost_per_head if cost_per_head > 0 else 0
	var lost: int = maxi(0, settlement.population_peasants - saved)

	_resolve_grain_purchase(gold_spent)

	_show_simple_event(
		"The Grain Ships Come",
		"You emptied the treasury. %d villagers were saved. %d could not be reached in time." % [saved, lost],
		"It is done."
	)

func _handle_buy_grain_half_gold() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	var cost_per_head: int = balance_data.buy_grain_cost_per_villager * balance_data.buy_grain_cost_multiplier
	var total_cost: int = settlement.population_peasants * cost_per_head
	var half_gold: int = int(settlement.treasury.get("gold", 0) * 0.5)
	var gold_spent: int = mini(half_gold, total_cost)
	var saved: int = gold_spent / cost_per_head if cost_per_head > 0 else 0
	var lost: int = maxi(0, settlement.population_peasants - saved)

	_resolve_grain_purchase(gold_spent)

	_show_simple_event(
		"The Grain Ships Come",
		"You spent half your treasury. %d villagers were saved. %d perished." % [saved, lost],
		"It is done."
	)

func _handle_buy_grain_none() -> void:
	if not balance_data:
		return

	var settlement = SettlementManager.current_settlement
	if not settlement:
		return

	var lost: int = settlement.population_peasants
	_resolve_grain_purchase(0)

	_show_simple_event(
		"The Hungry Season",
		"You spent nothing. %d of your people starved. Their names are forgotten. Your name is remembered — for the wrong reasons." % lost,
		"May Odin forgive me."
	)

# ---------------------------------------------------------------------------
# UTILITY: Build and display a simple one-button follow-up event
# ---------------------------------------------------------------------------

func _show_simple_event(title: String, description: String, dismiss_text: String) -> void:
	var result_event = EventData.new()
	result_event.title = title
	result_event.description = description
	result_event.event_id = "simple_result"

	var dismiss = EventChoice.new()
	dismiss.choice_text = dismiss_text
	result_event.choices.append(dismiss)

	event_ui.display_event(result_event)

# ---------------------------------------------------------------------------
# EXISTING: show_crisis_result
# ---------------------------------------------------------------------------

func show_crisis_result(data: Dictionary) -> void:
	if not data.get("success", false):
		var fail_event = EventData.new()
		fail_event.title = "THE ATTEMPT FAILS"
		fail_event.description = data.get("narrative", "You could not afford it. The crisis remains.")
		fail_event.event_id = "winter_crisis_failure"

		# Add a simple dismiss button
		var close_choice = EventChoice.new()
		close_choice.choice_text = "It is done."
		fail_event.choices.append(close_choice)

		event_ui.display_event(fail_event)
		return

	# Create a dynamic "Result" event
	var result_event = EventData.new()
	result_event.title = "THE CONSEQUENCES"
	result_event.event_id = "winter_crisis_result"

	var desc = data.get("narrative", "")
	desc += "\n\n[b]Consequences:[/b]"
	for consequence in data.get("consequences", []):
		desc += "\n- %s" % consequence

	result_event.description = desc

	# --- Task 3.4: Integrate Succession News ---
	var news = SettlementManager.pending_succession_news
	if not news.is_empty():
		result_event.description += "\n\n[b]Household News:[/b]"
		for item in news:
			result_event.description += "\n- %s" % item
		SettlementManager.pending_succession_news.clear()

	# Add a simple "It is done" button
	var close_choice = EventChoice.new()
	close_choice.choice_text = "It is done."
	result_event.choices.append(close_choice)

	# Trigger the UI again with this new data
	event_ui.display_event(result_event)
