# res://scenes/spring/SpringPhaseUI.gd
# Spring phase full-screen UI.
# Self-managed: listens to EventBus.season_changed, shows on "Spring".
# Two-column layout: card hand (left 65%) + context panel (right 35%).
# The oath card's confirm button is the only advance path — no "End Spring" button.
extends Control

const OATH_CARD_SCENE := preload("res://ui/components/SpringOathCard.tscn")

@onready var year_label:       Label         = $Layout/Left/Header/YearLabel
@onready var card_hand:        HBoxContainer = $Layout/Left/CardHand
@onready var forecast_label:   Label         = $Layout/Right/ContextPanel/Inner/ForecastLabel
@onready var jarl_stats_label: Label         = $Layout/Right/ContextPanel/Inner/JarlStatsLabel
@onready var household_label:  Label         = $Layout/Right/ContextPanel/Inner/HouseholdLabel

var _selected_card: SpringOathCard = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.season_changed.connect(_on_season_changed)


func _on_season_changed(season_name: String, _context: Dictionary) -> void:
	if season_name == "Spring":
		await get_tree().process_frame
		_open()


func _open() -> void:
	_populate()
	visible = true
	move_to_front()
	Loggie.msg("SpringPhaseUI: Opened for Year %d." % DynastyManager.current_year).domain(LogDomains.UI).info()


# --- Population ---

func _populate() -> void:
	_selected_card = null
	year_label.text = "Year %d — Choose Your Oath" % DynastyManager.current_year
	_populate_cards()
	_populate_context()


func _populate_cards() -> void:
	for child in card_hand.get_children():
		child.queue_free()

	var jarl := DynastyManager.current_jarl
	var cards: Array[SpringCardData] = SpringCardSelector.select_spring_cards()

	if cards.is_empty():
		var fallback := Label.new()
		fallback.text = "No oath cards available this Spring."
		card_hand.add_child(fallback)
		return

	for card_data in cards:
		var card_node: SpringOathCard = OATH_CARD_SCENE.instantiate()
		card_hand.add_child(card_node)
		card_node.setup(card_data, jarl)
		card_node.card_selected.connect(_on_card_selected)
		card_node.card_confirmed.connect(_on_card_confirmed)


func _populate_context() -> void:
	_update_forecast()
	_update_jarl_stats()
	_update_household_summary()


func _update_forecast() -> void:
	var settlement := SettlementManager.current_settlement
	if not settlement:
		forecast_label.text = "No settlement data."
		return

	var food := int(settlement.treasury.get("food", 0))
	var forecast: Dictionary = EconomyManager.get_winter_forecast()
	var demand := int(forecast.get("food", 0))

	if demand <= 0:
		forecast_label.text = "Winter food demand: unknown."
		return

	var diff := food - demand
	if diff >= 0:
		forecast_label.text = "At current stores, you will enter Winter secure (+%d food)." % diff
	else:
		forecast_label.text = "At current stores, you will be short by ~%d food this Winter." % abs(diff)


func _update_jarl_stats() -> void:
	var jarl := DynastyManager.current_jarl
	if not jarl:
		jarl_stats_label.text = "—"
		return
	jarl_stats_label.text = "%s  ·  Renown %d\nMight %d  |  Prosperity %d  |  Authority %d" % [
		jarl.display_name, jarl.renown,
		jarl.might_score, jarl.prosperity_score, jarl.authority_score
	]


func _update_household_summary() -> void:
	var settlement := SettlementManager.current_settlement
	if not settlement or settlement.households.is_empty():
		household_label.text = "No households."
		return
	var lines: Array[String] = []
	for h in settlement.households:
		lines.append("%s — Loyalty %d" % [
			h.household_name if h.household_name else "Household", h.loyalty
		])
	household_label.text = "\n".join(lines)


# --- Selection & Commit ---

func _on_card_selected(clicked: SpringOathCard) -> void:
	if _selected_card == clicked:
		return
	# Deselect the previous card
	if _selected_card and is_instance_valid(_selected_card):
		_selected_card.set_selected(false)
	_selected_card = clicked
	clicked.set_selected(true)


func _on_card_confirmed(card: SpringCardData) -> void:
	DynastyManager.active_spring_oath    = card.card_id
	DynastyManager.spring_oath_threshold = card.calculated_threshold
	DynastyManager.spring_oath_metric    = card.oath_metric_key

	Loggie.msg("SpringPhaseUI: Oath committed — %s (metric: %s, threshold: %d)" % [
		card.card_id, card.oath_metric_key, card.calculated_threshold
	]).domain(LogDomains.DYNASTY).info()

	visible = false
	EventBus.advance_season_requested.emit()
