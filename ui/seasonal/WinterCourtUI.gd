class_name WinterCourt_UI
extends Control

## The Winter Court.
## Players spend Hall Actions (AP) on cards to gain Legacy/Renown.

# --- Configuration ---
@export_group("Deck Configuration")
## Assign cards with Season = WINTER here
@export var available_court_cards: Array[SeasonalCardResource] = []
@export var hand_size: int = 3

@export_group("References")
@export var card_prefab: PackedScene # res://ui/seasonal/SeasonalCard_UI.tscn
@export var card_container: HBoxContainer
@onready var ap_label: Label = %APLabel
@onready var end_year_button: Button = %EndYearButton

# --- State ---
var _current_ap: int = 0

func _ready() -> void:
	# Lifecycle: Only visible in Winter
	EventBus.season_changed.connect(_on_season_changed)
	
	# Initial Check
	if DynastyManager.current_season == DynastyManager.Season.WINTER:
		visible = true
		_init_winter_court()
	else:
		visible = false
		
	end_year_button.pressed.connect(_on_end_year_pressed)
	
	# Listen for AP changes
	if DynastyManager.has_signal("jarl_stats_updated"):
		DynastyManager.jarl_stats_updated.connect(_on_jarl_stats_updated)

func _on_season_changed(season_name: String) -> void:
	if season_name.to_lower() == "winter":
		visible = true
		_init_winter_court()
	else:
		visible = false

func _init_winter_court() -> void:
	# 1. Fetch AP
	if DynastyManager.current_jarl:
		_current_ap = DynastyManager.current_jarl.current_hall_actions
	else:
		_current_ap = 0
		Loggie.msg("CRITICAL: No Jarl found for Winter Court").domain(LogDomains.GAMEPLAY).error()
	
	_update_hud()
	_deal_cards()
	
	# FIX: Replaced .data() with string formatting
	Loggie.msg("Winter Court Opened | AP: %d" % _current_ap).domain(LogDomains.UI).info()

func _update_hud() -> void:
	ap_label.text = "Hall Actions: %d" % _current_ap
	
	# Update card interactability based on new AP
	for card_ui in card_container.get_children():
		if card_ui is SeasonalCard_UI:
			# Re-run setup to refresh disabled state
			card_ui.setup(card_ui._card_data, _can_afford(card_ui._card_data))

func _can_afford(card: SeasonalCardResource) -> bool:
	return _current_ap >= card.cost_ap

func _deal_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()

	# Filter for Winter cards
	var winter_deck: Array[SeasonalCardResource] = []
	for card in available_court_cards:
		if card and card.season == SeasonalCardResource.SeasonType.WINTER:
			winter_deck.append(card)
	
	if winter_deck.is_empty():
		Loggie.msg("No Winter cards found in deck!").domain(LogDomains.GAMEPLAY).warn()
		return

	winter_deck.shuffle()
	var cards_to_spawn = min(hand_size, winter_deck.size())
	
	for i in range(cards_to_spawn):
		var card_instance = card_prefab.instantiate() as SeasonalCard_UI
		card_container.add_child(card_instance)
		
		# Setup with Affordability Check
		var card_data = winter_deck[i]
		card_instance.setup(card_data, _can_afford(card_data))
		card_instance.card_clicked.connect(_on_card_clicked)

func _on_card_clicked(card: SeasonalCardResource) -> void:
	if not _can_afford(card):
		Loggie.msg("Cannot afford card: %s" % card.title).domain(LogDomains.UI).warn()
		return
		
	Loggie.msg("Winter Action: %s" % card.title).domain(LogDomains.GAMEPLAY).info()
	
	# 1. Deduct AP (Via Manager)
	var success = DynastyManager.perform_hall_action(card.cost_ap)
	
	if success:
		# 2. Apply Effects
		if card.grant_gold > 0:
			EconomyManager.deposit_resources({"gold": card.grant_gold})
		if card.grant_renown > 0:
			DynastyManager.award_renown(card.grant_renown)
			
		# 3. Refresh Local State
		_current_ap -= card.cost_ap
		_update_hud()
		
		# 4. Remove card (One-time use per winter)
		for child in card_container.get_children():
			if child._card_data == card:
				child.queue_free()
				break
	else:
		Loggie.msg("DynastyManager rejected AP spend").domain(LogDomains.GAMEPLAY).error()

func _on_jarl_stats_updated(jarl_data) -> void:
	# React to external changes
	_current_ap = jarl_data.current_hall_actions
	_update_hud()

func _on_end_year_pressed() -> void:
	Loggie.msg("The Ice Melts - Year Ending").domain(LogDomains.GAMEPLAY).info()
	
	# Transition Flow
	EventBus.winter_ended.emit()
	EventBus.advance_season_requested.emit()
	
	visible = false
