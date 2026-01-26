class_name SpringCouncil_UI
extends Control

## The Spring Seasonal Screen.
## DIAGNOSTIC VERSION: Includes detailed logging to trace visibility failures.

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
	# 1. DIAGNOSTIC: Initial State Check
	Loggie.msg("SpringCouncil_UI Instantiated | Visible: %s | In Tree: %s" % [visible, is_inside_tree()]).domain(LogDomains.UI).info()
	if get_parent():
		Loggie.msg("SpringCouncil Parent: %s" % get_parent().name).domain(LogDomains.UI).info()
	else:
		Loggie.msg("SpringCouncil has NO PARENT").domain(LogDomains.UI).error()
	
	# 2. Connect Signals
	if not EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.connect(_on_season_changed)
		Loggie.msg("SpringCouncil_UI connected to EventBus.season_changed").domain(LogDomains.UI).info()
	else:
		Loggie.msg("SpringCouncil_UI already connected to EventBus").domain(LogDomains.UI).warn()

	# 3. DIAGNOSTIC: Check current state immediately (Race Condition Protection)
	# If the season is ALREADY Spring when this spawns, we might have missed the signal.
	if DynastyManager.current_season == DynastyManager.Season.SPRING:
		Loggie.msg("Spawned during Spring - Attempting immediate activation").domain(LogDomains.UI).info()
		_activate_spring_ui()
	
	# 4. DIAGNOSTIC: 5-Second Timeout Warning
	# If the UI sits here for 5 seconds without activating, log an error.
	get_tree().create_timer(5.0).timeout.connect(_on_diagnostic_timeout)

func _on_season_changed(season_name: String) -> void:
	Loggie.msg("SpringCouncil_UI received season_changed: %s" % season_name).domain(LogDomains.UI).info()
	
	# Case-insensitive check just to be safe
	if season_name.to_lower() == "spring":
		_activate_spring_ui()
	else:
		# Hide if it's not Spring (cleanup)
		if visible:
			Loggie.msg("Hiding SpringCouncil_UI (Season is %s)" % season_name).domain(LogDomains.UI).info()
			visible = false

func _activate_spring_ui() -> void:
	Loggie.msg("Activating SpringCouncil_UI Logic").domain(LogDomains.UI).info()
	
	visible = true
	_deal_cards()
	_has_activated = true
	
	# Log final visibility state
	Loggie.msg("SpringCouncil_UI Activation Complete | Final Visible: %s" % visible).domain(LogDomains.UI).info()

func _on_diagnostic_timeout() -> void:
	if not _has_activated and DynastyManager.current_season == DynastyManager.Season.SPRING:
		Loggie.msg("DIAGNOSTIC FAILURE: SpringCouncil_UI exists but failed to activate after 5s").domain(LogDomains.UI).error()
		Loggie.msg("Current Season: %s | Is Visible: %s" % [DynastyManager.current_season, visible]).domain(LogDomains.UI).error()

# --- Existing Logic (Unchanged but wrapped in logs) ---
func _deal_cards() -> void:
	# 1. Cleanup existing visuals
	for child in card_container.get_children():
		child.queue_free()

	# 2. Filter Deck (Now with Safety Checks)
	var spring_deck: Array[SeasonalCardResource] = []
	
	for i in range(available_advisor_cards.size()):
		var card = available_advisor_cards[i]
		
		# --- SAFETY CHECK: Skip empty Inspector slots ---
		if card == null:
			Loggie.msg("Found NULL card at index %d in SpringCouncil_UI. Check Inspector!" % i).domain(LogDomains.GAMEPLAY).warn()
			continue 
		
		# Now safe to access properties
		if card.season == SeasonalCardResource.SeasonType.SPRING:
			spring_deck.append(card)
	
	# 3. Check if we have playable cards
	if spring_deck.is_empty():
		Loggie.msg("No valid Spring cards found! (Checked %d slots)" % available_advisor_cards.size()).domain(LogDomains.GAMEPLAY).error()
		return

	# 4. Deal
	spring_deck.shuffle()
	var cards_to_spawn = min(hand_size, spring_deck.size())
	
	Loggie.msg("Dealing %d Cards" % cards_to_spawn).domain(LogDomains.UI).info()
	
	for i in range(cards_to_spawn):
		var card_instance = card_prefab.instantiate() as SeasonalCard_UI
		card_container.add_child(card_instance)
		card_instance.setup(spring_deck[i], true) 
		card_instance.card_clicked.connect(_on_card_selected)

func _on_card_selected(card: SeasonalCardResource) -> void:
	_selected_card = card
	_commit_choice()

func _commit_choice() -> void:
	if not _selected_card: return
	
	if _selected_card.modifier_key != "":
		DynastyManager.apply_year_modifier(_selected_card.modifier_key)
		
	if _selected_card.grant_gold > 0:
		EconomyManager.deposit_resources({"gold": _selected_card.grant_gold})
	
	Loggie.msg("Spring Strategy Committed: %s" % _selected_card.modifier_key).domain(LogDomains.GAMEPLAY).info()

	EventBus.advance_season_requested.emit()
	
	visible = false
	queue_free()
