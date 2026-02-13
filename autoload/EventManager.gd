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
	else:
		Loggie.msg("DynastyManager Autoload not found!").domain("EVENT").error()

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
	Loggie.msg("Loaded %d events and %d disputes from disk." % [available_events.size(), available_disputes.size()]).domain("EVENT").info()

func _on_year_ended() -> void:
	Loggie.msg("Checking event triggers for end of year...").domain("EVENT").info()
	var event_was_triggered: bool = _check_event_triggers()
	if not event_was_triggered:
		EventBus.event_system_finished.emit()

func _check_event_triggers() -> bool:
	var jarl = DynastyManager.get_current_jarl()
	if not jarl:
		Loggie.msg("Cannot check events, Jarl data is null.").domain("EVENT").error()
		return false

	for event in available_events:
		if _check_conditions(event, jarl):
			_trigger_event(event)
			return true 
	return false

func _check_conditions(event: EventData, jarl: JarlData) -> bool:
	if event.is_unique and event.event_id in fired_unique_events: return false
	for pre_id in event.prerequisites:
		if not pre_id in fired_unique_events: return false 
	
	if event.min_renown > -1 and jarl.renown < event.min_renown: return false
	if event.min_stewardship > -1 and jarl.get_effective_skill("stewardship") < event.min_stewardship: return false
	if not event.must_have_trait.is_empty() and not jarl.has_trait(event.must_have_trait): return false
	if not event.must_not_have_trait.is_empty() and jarl.has_trait(event.must_not_have_trait): return false
	if event.min_available_heirs > -1 and jarl.get_available_heir_count() < event.min_available_heirs: return false
	if event.min_conquered_regions > -1 and jarl.conquered_regions.size() < event.min_conquered_regions: return false
	if randf() > event.base_chance: return false
	
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

func show_crisis_result(data: Dictionary) -> void:
	if not data.get("success", false): return
	
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
