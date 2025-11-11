# res://autoload/EventManager.gd
#
# Global singleton (Autoload) to manage the "Full Event System" (Phase 3b).
# This manager loads all events, checks their triggers,
# and displays them to the player.
extends Node

# Assign res://ui/Event_UI.tscn in the Autoload settings in Godot
@export var event_ui_scene: PackedScene
@export var succession_crisis_scene: PackedScene # Add this in the Inspector

var event_ui: EventUI
var available_events: Array[EventData] = []
var fired_unique_events: Array[String] = []

# Preload resources needed for consequences
const TRAIT_RIVAL = preload("res://data/traits/Trait_Rival.tres")

func _ready() -> void:
	# Defer initialization to ensure all Autoloads are ready
	call_deferred("initialize_event_system")

func initialize_event_system() -> void:
	"""Handles all initialization after the engine is stable."""
	if not event_ui_scene:
		push_error("EventManager: 'event_ui_scene' is not set in Autoload Inspector! Event system is disabled.")
		return
	
	# 1. Instance and add the UI
	event_ui = event_ui_scene.instantiate()
	add_child(event_ui)
	event_ui.choice_made.connect(_on_choice_made)
	
	# 2. Load all events
	_load_events_from_disk()
	
	# 3. Connect to the main game trigger
	if DynastyManager:
		DynastyManager.year_ended.connect(_on_year_ended)
	else:
		push_error("EventManager: DynastyManager Autoload is not found! Cannot connect year_ended signal.")

func _load_events_from_disk() -> void:
	"""Scans the res://data/events/ directory for EventData resources."""
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
					push_warning("EventManager: Failed to load event resource from %s." % path)
			file_name = dir.get_next()
	print("EventManager: Loaded %d events from disk." % available_events.size())

func _on_year_ended() -> void:
	"""Triggered by DynastyManager, this checks all events."""
	print("EventManager: Checking event triggers for end of year...")
	
	var event_was_triggered: bool = _check_event_triggers()
	
	# Status print remains for end-of-year summary
	if event_was_triggered:
		print("EventManager: An event was recognized and triggered.")
	else:
		print("EventManager: No events were recognized or triggered this year.")
	
	if not event_was_triggered:
		# No events were found, so we signal the "all-clear" immediately.
		EventBus.event_system_finished.emit()

func _check_event_triggers() -> bool:
	"""
	Checks all events. Returns true if an event was triggered, false otherwise.
	"""
	var jarl = DynastyManager.get_current_jarl()
	if not jarl:
		push_error("EventManager: Cannot check events, Jarl data is null.")
		return false

	for event in available_events:
		if _check_conditions(event, jarl):
			_trigger_event(event)
			return true # An event was triggered
	
	return false # No events were triggered

func _check_conditions(event: EventData, jarl: JarlData) -> bool:
	"""Checks if a single event's trigger conditions are met."""
	
	# Check if unique and already fired
	if event.is_unique and event.event_id in fired_unique_events:
		return false
		
	# Check prerequisites
	for pre_id in event.prerequisites:
		if not pre_id in fired_unique_events:
			return false 
			
	# Check Jarl stats
	if event.min_renown > -1 and jarl.renown < event.min_renown:
		return false
	if event.min_stewardship > -1 and jarl.get_effective_skill("stewardship") < event.min_stewardship:
		return false
	
	# Check Jarl traits
	if not event.must_have_trait.is_empty() and not jarl.has_trait(event.must_have_trait):
		return false
	if not event.must_not_have_trait.is_empty() and jarl.has_trait(event.must_not_have_trait):
		return false
	
	# Check Dynasty state
	if event.min_available_heirs > -1 and jarl.get_available_heir_count() < event.min_available_heirs:
		return false
	
	# Check World state
	if event.min_conquered_regions > -1 and jarl.conquered_regions.size() < event.min_conquered_regions:
		return false
		
	# Check base chance
	if randf() > event.base_chance:
		return false
	
	# All conditions passed
	print("EventManager: Conditions MET for event '%s'" % event.event_id)
	return true

func _trigger_event(event: EventData) -> void:
	"""Pauses the game and displays the event UI."""
	
	# --- NEW: Special Case for Succession ---
	if event.event_id == "succession_crisis":
		if not succession_crisis_scene:
			push_error("EventManager: succession_crisis_scene is not set!")
			return
		
		var crisis_ui = succession_crisis_scene.instantiate()
		add_child(crisis_ui)
		
		var jarl = DynastyManager.get_current_jarl()
		var settlement = SettlementManager.current_settlement
		crisis_ui.display_crisis(jarl, settlement)
		
		# The crisis UI will emit 'succession_choices_made' on its own
		# and then call EventBus.event_system_finished when it closes.
	else:
	# --- END NEW ---
		print("EventManager: Triggering event '%s'" % event.event_id)
		
		get_tree().paused = true
		event_ui.display_event(event)
	
	if event.is_unique:
		fired_unique_events.append(event.event_id)

func _on_choice_made(event: EventData, choice: EventChoice) -> void:
	"""
	Called by the EventUI.
	Applies consequences, unpauses, and signals the "all-clear".
	"""
	
	if choice:
		print("EventManager: Player chose '%s' (%s) for event '%s'" % [choice.choice_text, choice.effect_key, event.event_id])
		_apply_event_consequences(event, choice)
	else:
		print("EventManager: Event '%s' closed with no choice." % event.event_id)
		
	get_tree().paused = false
	
	# This is the "all-clear" signal.
	EventBus.event_system_finished.emit()

func _apply_event_consequences(event: EventData, choice: EventChoice) -> void:
	"""
	This is the "logic" part of the event system.
	It matches the event_id and choice.effect_key to apply results.
	"""
	
	if event.event_id == "ambitious_heir_1":
		
		if choice.effect_key == "accept":
			var success = DynastyManager.spend_renown(100)
			if not success:
				push_warning("EventManager: Tried to spend 100 Renown for event, but failed.")
			
		elif choice.effect_key == "decline":
			var heir = DynastyManager.get_current_jarl().get_first_available_heir()
			if heir and TRAIT_RIVAL:
				DynastyManager.add_trait_to_heir(heir, TRAIT_RIVAL)
			else:
				push_warning("EventManager: Could not apply 'Rival' trait. No heir or trait not loaded.")
