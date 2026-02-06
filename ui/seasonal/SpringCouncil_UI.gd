#res://ui/seasonal/SpringCouncil_UI.gd
class_name SpringCouncil_UI
extends Control

## The Spring Seasonal Screen.
## REFACTORED VERSION: Uses Data-Driven Aggregator instead of String Keys.

# --- Configuration ---
@export_group("Deck Configuration")
@export var available_advisor_cards: Array[SeasonalCardResource] = []
@export var hand_size: int = 3

@export_group("References")
@export var card_prefab: PackedScene 
@export var card_container: HBoxContainer

# --- State ---
var _selected_card: SeasonalCardResource
var _has_activated: bool = false

func _ready() -> void:
	# Initial State Check
	Loggie.msg("SpringCouncil_UI Instantiated").domain(LogDomains.UI).info()
	
	# Connect Signals
	if not EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.connect(_on_season_changed)

	# Check current state immediately
	if DynastyManager.current_season == DynastyManager.Season.SPRING:
		_activate_spring_ui()
	
	get_tree().create_timer(5.0).timeout.connect(_on_diagnostic_timeout)

func _on_season_changed(season_name: String, context) -> void:
	if season_name.to_lower() == "spring":
		_activate_spring_ui()
	else:
		if visible:
			visible = false

func _activate_spring_ui() -> void:
	visible = true
	_deal_cards()
	_has_activated = true

func _on_diagnostic_timeout() -> void:
	if not _has_activated and DynastyManager.current_season == DynastyManager.Season.SPRING:
		Loggie.msg("FAILURE: SpringCouncil_UI failed to activate").domain(LogDomains.UI).error()

func _deal_cards() -> void:
	# 1. Cleanup
	for child in card_container.get_children():
		child.queue_free()

	# 2. Filter Deck
	var spring_deck: Array[SeasonalCardResource] = []
	for card in available_advisor_cards:
		if card and card.season == SeasonalCardResource.SeasonType.SPRING:
			spring_deck.append(card)
	
	if spring_deck.is_empty():
		return

	# 3. Deal
	spring_deck.shuffle()
	var cards_to_spawn = min(hand_size, spring_deck.size())
	
	for i in range(cards_to_spawn):
		var card_instance = card_prefab.instantiate() as SeasonalCard_UI
		card_container.add_child(card_instance)
		card_instance.setup(spring_deck[i], true) 
		card_instance.card_clicked.connect(_on_card_selected)

func _on_card_selected(card: SeasonalCardResource) -> void:
	_selected_card = card
	_commit_choice()

func _commit_choice() -> void:
	if not _selected_card: 
		return
	
	# 1. Aggregate Seasonal Stats
	# This adds all mod_* values from the card to the DynastyManager's active_year_stats
	DynastyManager.aggregate_card_effects(_selected_card)
		
	# 2. Immediate Rewards
	if _selected_card.grant_gold > 0:
		EconomyManager.deposit_resources({"gold": _selected_card.grant_gold})
	
	if _selected_card.grant_renown > 0:
		DynastyManager.award_renown(_selected_card.grant_renown)
	
	Loggie.msg("Spring Strategy Committed: %s" % _selected_card.display_name).domain(LogDomains.GAMEPLAY).info()

	# 3. Cleanup & Transition
	EventBus.advance_season_requested.emit()
	visible = false
	queue_free()
