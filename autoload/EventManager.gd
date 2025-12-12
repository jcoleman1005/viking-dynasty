# res://autoload/EventManager.gd
extends Node

@export var event_ui_scene: PackedScene
@export var succession_crisis_scene: PackedScene

var event_ui: EventUI
var available_events: Array[EventData] = []
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
	var dir = DirAccess.open("res://data/events/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path = "res://data/events/" + file_name
				var event_data = load(path) as EventData 
				if event_data:
					available_events.append(event_data)
				else:
					Loggie.msg("Failed to load event resource from %s." % path).domain("EVENT").warn()
			file_name = dir.get_next()
	Loggie.msg("Loaded %d events from disk." % available_events.size()).domain("EVENT").info()

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
	# Implementation depends on your existing EventManager, 
	# assuming it emits a signal or opens a UI.
	# For this refactor, we just ensure this file exists and works.
	Loggie.msg("Event Triggered: %s" % event_data.event_id).domain("EVENT").info()
	# Example: EventBus.event_triggered.emit(event_data)

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
	if choice:
		Loggie.msg("Player chose '%s' (%s) for event '%s'" % [choice.choice_text, choice.effect_key, event.event_id]).domain("EVENT").info()
		_apply_event_consequences(event, choice)
	else:
		Loggie.msg("Event '%s' closed with no choice." % event.event_id).domain("EVENT").info()
		
	get_tree().paused = false
	EventBus.event_system_finished.emit()

func _apply_event_consequences(event: EventData, choice: EventChoice) -> void:
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
