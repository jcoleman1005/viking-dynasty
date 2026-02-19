#res://autoload/EventManager.gd
# res://autoload/EventManager.gd
extends Node

@export var event_ui_scene: PackedScene
@export var succession_crisis_scene: PackedScene

var event_ui: EventUI
var available_events: Array[EventData] = []
# CHANGE: Added specific storage for disputes as they are a distinct Resource type from EventData
var available_disputes: Array[DisputeEventData] = []
var fired_unique_events: Array[String] = []

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
	
	Loggie.msg("EventManager: Event ID '%s' not found." % id).domain("EVENT").warn()

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
		# Placeholder - household labor reduction
		# not yet implemented, print for now
		print("full_quarantine: household labor TBD")
	
	elif choice.effect_key == "partial_quarantine":
		if randf() < 0.5:
			print("partial_quarantine: sickness spreads TBD")
	
	elif choice.effect_key == "consult_volva":
		if DynastyManager.active_year_modifiers.has("sickness_seed"):
			DynastyManager.active_year_modifiers.erase("sickness_seed")
		print("consult_volva: sickness resolved")
	
	elif choice.effect_key == "ignore_sickness":
		print("ignore_sickness: population penalty TBD")

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
		print("coerce_harvest: permanent loyalty TBD")
	
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
				
	# TODO: Implement handlers for all 'pass_1' event effect_keys (e.g., 'great_feast', 'burial_rite', 'buy_grain_all').
	# These must interface with EconomyManager for resource additions/deductions and emit
	# EventBus.treasury_updated to refresh the UI, alongside floating text for player feedback.

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
