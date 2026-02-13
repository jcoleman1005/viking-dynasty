extends Control
class_name SeasonalCouncilUI

## SeasonalCouncilUI - The Unified Seasonal Workspace
## Handles both Spring Council and Winter Court logic.
##
## ARCHITECTURE: "The Pillar & The Triptych"
## Zone A (Left): The Spine/Pillar. Holds Context (Burden, AP, Descriptions).
## Zone B (Right): The Ritual Stage. Holds the Content (Cards).

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
@export_group("Great Hall Stratum")
## Cards available during the Spring Council
@export var spring_council_cards: Array[SeasonalCardResource] = []
## Cards available during the Winter Court
@export var winter_court_cards: Array[SeasonalCardResource] = []
## The number of random cards to display from the deck
@export var hand_size: int = 3
## The UI Prefab for a single card
@export var card_prefab: PackedScene

# ------------------------------------------------------------------------------
# Node References (The Blueprint)
# ------------------------------------------------------------------------------
# ZONE A: THE LEFT SPINE
@onready var severity_label: Label = %SeverityLabel
@onready var resource_totem: VBoxContainer = %ResourceTotem
@onready var action_points_label: Label = %ActionPointsLabel
@onready var description_label: Label = %DescriptionLabel 
@onready var jarl_name_label: Label = %JarlNameLabel
@onready var sickness_omen_label: Label = %SicknessOmenLabel 

# ZONE B: THE RITUAL STAGE
@onready var cards_container: HBoxContainer = %CardsContainer

# ------------------------------------------------------------------------------
# State
# ------------------------------------------------------------------------------
var current_ap: int = 0
var max_ap: int = 0
var _current_season: String = "Winter"

const COLOR_SPRING = Color("a8e6cf") # Soft Spring Green
const COLOR_WINTER = Color("dcedc1") # Existing Winter Cream/White
const COLOR_FAIL = Color("ff5555")
const COLOR_OK = Color("55ff55")

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	
	if EventBus:
		EventBus.hall_action_updated.connect(_on_ap_updated)
		EventBus.treasury_updated.connect(_on_treasury_updated)
		EventBus.treasury_updated.connect(_update_dashboard)
		EventBus.hall_action_updated.connect(_update_dashboard)
		
		# Fix: Re-evaluate cards as soon as real settlement data arrives
		EventBus.settlement_loaded.connect(_on_settlement_loaded)
		
		if EventBus.has_signal("season_changed"):
			EventBus.season_changed.connect(_on_season_changed)

func _on_settlement_loaded(_data: SettlementData) -> void:
	if visible:
		Loggie.msg("Seasonal Council: Settlement Loaded. Refreshing cards.").domain(LogDomains.UI).debug()
		_refresh_resource_totem()
		_refresh_ritual_stage()

func _on_season_changed(new_season: String, _context: Dictionary) -> void:
	_current_season = new_season
	if _current_season == "Winter" or _current_season == "Spring":
		show()
		setup_seasonal_view()
		_apply_seasonal_theme()
	else:
		hide()

func _on_ap_updated(new_amount: int) -> void:
	current_ap = new_amount
	_update_spine_header()
	_refresh_ritual_stage()

func _on_treasury_updated(_new_treasury: Dictionary) -> void:
	if visible:
		_refresh_resource_totem()
		_refresh_ritual_stage()

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------
func setup_seasonal_view() -> void:
	Loggie.msg("Initializing %s Council" % _current_season).domain(LogDomains.UI).info()
	
	var jarl: JarlData = DynastyManager.get_current_jarl()
	if jarl:
		current_ap = jarl.current_hall_actions
		max_ap = jarl.max_hall_actions
	else:
		current_ap = 0
		max_ap = 0
	
	_refresh_resource_totem()
	_refresh_dynasty_context()
	_refresh_ritual_stage()
	_update_spine_header()
	_update_dashboard()
	
	if description_label: 
		description_label.text = "Select a course of action..."
		description_label.get_parent().show()

func _apply_seasonal_theme() -> void:
	var theme_color = COLOR_WINTER
	var show_severity = true
	
	if _current_season == "Spring":
		theme_color = COLOR_SPRING
		show_severity = false
	
	# Apply color and visibility to the main labels for a thematic shift
	if severity_label: 
		severity_label.modulate = theme_color
		severity_label.visible = show_severity
		
	if jarl_name_label: jarl_name_label.modulate = theme_color

# ------------------------------------------------------------------------------
# ZONE A: THE LEFT SPINE (Context)
# ------------------------------------------------------------------------------
func _refresh_resource_totem() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return

	for child in resource_totem.get_children():
		child.queue_free()

	# 1. Sickness (Winter Only)
	if _current_season == "Winter" and settlement.sick_population > 0:
		_add_totem_entry("THE SICK", str(settlement.sick_population), Color.MAGENTA)

	# 2. Upkeep (Winter Only)
	if _current_season == "Winter":
		var heating_demand = EconomyManager.get_winter_wood_demand()
		if heating_demand > 0:
			_add_totem_entry("WINTER UPKEEP", "-%d Wood" % heating_demand, Color.ORANGE)

	Loggie.msg("Seasonal Council: Resource Totem Refreshed").domain(LogDomains.UI).debug()

func _add_totem_entry(title: String, value: String, color: Color) -> void:
	var box = HBoxContainer.new()
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl_val = Label.new()
	lbl_val.text = value
	lbl_val.modulate = color
	
	box.add_child(lbl_title)
	box.add_child(lbl_val)
	resource_totem.add_child(box)

func _update_spine_header() -> void:
	if action_points_label:
		if _current_season == "Spring":
			action_points_label.text = "SPRING COUNCIL"
		else:
			action_points_label.text = "HALL ACTIONS: %d / %d" % [current_ap, max_ap]

func _refresh_dynasty_context() -> void:
	var jarl: JarlData = DynastyManager.get_current_jarl()
	if jarl_name_label:
		if jarl:
			jarl_name_label.text = "%s (Age %d)" % [jarl.display_name.to_upper(), jarl.age]
			
			# Add Tooltip for Pillar Scores (Condensed breakdown)
			var damage_bonus = (jarl.might_score - 10) * 10 if jarl.might_score > 10 else 0
			var income_bonus = (jarl.prosperity_score - 10) * 5 if jarl.prosperity_score > 10 else 0
			
			var tip = "THE JARL'S PILLARS:\n"
			tip += "⚔️ MIGHT: %d (+%d%% Damage)\n" % [jarl.might_score, damage_bonus]
			tip += "💰 PROSPERITY: %d (+%d%% Income)\n" % [jarl.prosperity_score, income_bonus]
			tip += "👑 AUTHORITY: %d (%d Hall Actions)" % [jarl.authority_score, jarl.max_hall_actions]
			
			jarl_name_label.tooltip_text = tip
			jarl_name_label.mouse_filter = Control.MOUSE_FILTER_PASS # Ensure tooltip shows
		else:
			jarl_name_label.text = "INTERREGNUM"
			jarl_name_label.tooltip_text = ""

# ------------------------------------------------------------------------------
# ZONE B: THE RITUAL STAGE (Content)
# ------------------------------------------------------------------------------
func _refresh_ritual_stage() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	
	if not card_prefab: return

	# Use the appropriate deck for the current season
	var active_deck = winter_court_cards.duplicate() if _current_season == "Winter" else spring_council_cards.duplicate()
	active_deck.shuffle()
	
	var cards_to_show = min(hand_size, active_deck.size())
	
	for i in range(cards_to_show):
		var card_data = active_deck[i]
		if not card_data: continue
		
		var card_instance = card_prefab.instantiate()
		cards_container.add_child(card_instance)
		
		var can_afford = _can_afford(card_data)
		var denial_reason = ""
		if not can_afford:
			denial_reason = _get_denial_reason(card_data)
		
		if card_instance.has_method("setup"):
			card_instance.setup(card_data, can_afford, denial_reason)
		
		if card_instance.has_signal("card_clicked"):
			card_instance.card_clicked.connect(_on_card_clicked)
		if card_instance.has_signal("card_hovered"):
			card_instance.card_hovered.connect(_on_card_hovered)
		if card_instance.has_signal("card_exited"):
			card_instance.card_exited.connect(_on_card_exited)

func _can_afford(card: SeasonalCardResource) -> bool:
	return _get_denial_reason(card) == ""

func _get_denial_reason(card: SeasonalCardResource) -> String:
	# 1. Check AP (Winter Only)
	if _current_season == "Winter" and current_ap < card.cost_ap:
		return "Not enough Hall Actions"
		
	# 2. Check Resources
	if card.cost_gold > 0:
		if not EconomyManager.can_afford({GameResources.GOLD: card.cost_gold}):
			return "Insufficient Gold"
			
	if card.cost_food > 0:
		if not EconomyManager.can_afford({GameResources.FOOD: card.cost_food}):
			return "Insufficient Food"
	
	return ""

func _on_card_clicked(card: SeasonalCardResource) -> void:
	var success: bool = WinterManager.play_seasonal_card(card)
	if success:
		Loggie.msg("Executed %s Choice: %s" % [_current_season, card.display_name]).domain(LogDomains.GAMEPLAY).info()
		
		if _current_season == "Spring":
			# Spring is a one-time major decision. Advance immediately.
			EventBus.advance_season_requested.emit()
			hide()
		else:
			_refresh_ritual_stage()
			_on_card_exited()
	else:
		_flash_spine_warning("NEED RESOURCES")

# --- MASTER-DETAIL LOGIC ---
func _on_card_hovered(card: SeasonalCardResource) -> void:
	if description_label:
		var text_to_show = card.condensed_effects if not card.condensed_effects.is_empty() else card.description
		description_label.text = "[b]%s[/b]

%s" % [card.display_name.to_upper(), text_to_show]
		description_label.get_parent().show()

	# Ghost logic (Only relevant in Winter crisis)
	if _current_season == "Winter":
		_check_ghost_preview(card)

func _check_ghost_preview(card: SeasonalCardResource) -> void:
	if not SettlementManager.has_current_settlement(): return
	var current_treasury = SettlementManager.current_settlement.treasury
	var hypothetical_treasury = current_treasury.duplicate()
	
	hypothetical_treasury[GameResources.GOLD] = max(0, hypothetical_treasury.get(GameResources.GOLD, 0) - card.cost_gold)
	hypothetical_treasury[GameResources.FOOD] = max(0, hypothetical_treasury.get(GameResources.FOOD, 0) - card.cost_food)
	
	var current_verdict = EconomyManager.get_survival_verdict(current_treasury)
	var hypothetical_verdict = EconomyManager.get_survival_verdict(hypothetical_treasury)
	
	if current_verdict >= EconomyManager.SurvivalVerdict.UNCERTAIN and hypothetical_verdict == EconomyManager.SurvivalVerdict.SECURE:
		_pulse_resource_totem_green()

func _on_card_exited() -> void:
	if description_label:
		description_label.text = "Select a course of action..."

func _flash_spine_warning(message: String) -> void:
	if action_points_label:
		var old_text = action_points_label.text
		action_points_label.text = message
		action_points_label.add_theme_color_override("font_color", Color.TOMATO)
		get_tree().create_timer(1.5).timeout.connect(func():
			if action_points_label:
				action_points_label.text = old_text
				action_points_label.remove_theme_color_override("font_color")
		)

func _pulse_resource_totem_green() -> void:
	var pulse_tween = create_tween().set_loops(3)
	pulse_tween.tween_property(resource_totem, "modulate", Color.LIME_GREEN, 0.3)
	pulse_tween.tween_property(resource_totem, "modulate", Color.WHITE, 0.5)

# --- Dashboard Updater ---
func _update_dashboard(_payload = null) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return

	# 1. Severity/Crisis Banner
	if _current_season == "Winter":
		var report = WinterManager.get_live_crisis_report()
		if report.is_crisis:
			severity_label.text = "CRISIS! Food: %d, Wood: %d" % [report.food_deficit, report.wood_deficit]
			severity_label.modulate = Color.RED
		else:
			severity_label.text = "All is well."
			severity_label.modulate = COLOR_OK
	else:
		severity_label.text = "A New Year Begins"
		severity_label.modulate = COLOR_SPRING

	# 2. Sickness Omen
	if sickness_omen_label:
		var omen = WinterManager.get_sickness_omen(settlement.sick_population, settlement.population_peasants)
		if _current_season == "Winter" and not omen.text.is_empty():
			sickness_omen_label.text = "[b]OMEN:[/b] %s" % omen.text
			sickness_omen_label.modulate = omen.color
		else:
			sickness_omen_label.text = ""
