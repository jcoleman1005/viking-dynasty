extends Control

## WinterCourtUI - The Seasonal Workspace
##
## Organizes the Winter phase into three persistent strata:
## 1. Burden (Deficits & Severity) - Live Calculation
## 2. Great Hall (Actions & Cards) - Interactive
## 3. Bloodline (Dynasty Context) - Read Only

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
@export_group("Great Hall Stratum")
## The list of Seasonal Cards available this winter (Assigned by Game Design or Manager)
@export var available_court_cards: Array[SeasonalCardResource] = []
## The UI Prefab for a single card (SeasonalCardUi.tscn)
@export var card_prefab: PackedScene

# ------------------------------------------------------------------------------
# Node References (Unique Names)
# ------------------------------------------------------------------------------
# Stratum I: Burden
@onready var severity_label: Label = %SeverityLabel
@onready var deficit_container: VBoxContainer = %DeficitContainer

# Stratum II: Great Hall
@onready var action_points_label: Label = %ActionPointsLabel
@onready var cards_container: HBoxContainer = %CardsContainer
# NEW: Reference to the shared description area
@onready var description_label: Label = %DescriptionLabel 

# Stratum III: Bloodline
@onready var jarl_name_label: Label = %JarlNameLabel
@onready var jarl_status_label: Label = %JarlStatusLabel
@onready var heir_status_label: Label = %HeirStatusLabel

# ------------------------------------------------------------------------------
# State
# ------------------------------------------------------------------------------
var current_ap: int = 0
var max_ap: int = 0

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	
	# Connect global signals
	if EventBus:
		EventBus.hall_action_updated.connect(_on_ap_updated)
		EventBus.treasury_updated.connect(_on_treasury_updated)
		
		if EventBus.has_signal("season_changed"):
			EventBus.season_changed.connect(_on_season_changed)
		elif EventBus.has_signal("winter_started"): 
			EventBus.winter_started.connect(func(): _on_season_changed("Winter", {}))

func _on_season_changed(new_season: String, _context: Dictionary) -> void:
	if new_season == "Winter":
		show()
		setup_winter_view()
	else:
		hide()

func _on_ap_updated(new_amount: int) -> void:
	current_ap = new_amount
	_update_hall_ui()
	_refresh_stratum_hall()

func _on_treasury_updated(_new_treasury: Dictionary) -> void:
	if visible:
		_refresh_stratum_burden()
		_refresh_stratum_hall()

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------
func setup_winter_view() -> void:
	Loggie.msg("Initializing Winter Court UI Strata").domain(LogDomains.UI).info()
	
	var jarl: JarlData = DynastyManager.get_current_jarl()
	if jarl:
		current_ap = jarl.current_hall_actions
		max_ap = jarl.max_hall_actions
	else:
		current_ap = 0
		max_ap = 0
	
	_refresh_stratum_burden()
	_refresh_stratum_bloodline()
	_refresh_stratum_hall()
	_update_hall_ui()
	
	# Clear description on open
	if description_label: description_label.text = "Select a card to view details..."

# ------------------------------------------------------------------------------
# STRATUM I: The Burden of Winter (Live Calculation)
# ------------------------------------------------------------------------------
func _refresh_stratum_burden() -> void:
	var severity_name = "NORMAL"
	if WinterManager.has_method("get_severity_name"):
		severity_name = WinterManager.get_severity_name()
	elif "winter_consumption_report" in WinterManager and not WinterManager.winter_consumption_report.is_empty():
		severity_name = WinterManager.winter_consumption_report.get("severity_name", "NORMAL")
		
	severity_label.text = "Winter Severity: %s" % severity_name
	
	if severity_name == "HARSH": severity_label.modulate = Color.RED
	elif severity_name == "MILD": severity_label.modulate = Color.GREEN
	else: severity_label.modulate = Color.WHITE

	for child in deficit_container.get_children():
		child.queue_free()
	
	var treasury = SettlementManager.current_settlement.treasury
	var forecast = EconomyManager.get_winter_forecast()
	
	var food_demand = forecast.get(GameResources.FOOD, 0)
	var wood_demand = forecast.get(GameResources.WOOD, 0)
	var food_stock = treasury.get(GameResources.FOOD, 0)
	var wood_stock = treasury.get(GameResources.WOOD, 0)
	
	var food_deficit = max(0, food_demand - food_stock)
	var wood_deficit = max(0, wood_demand - wood_stock)
	
	if food_deficit > 0:
		_add_burden_entry("Starvation Risk", "-%d Food" % food_deficit, Color.RED)
	if wood_deficit > 0:
		_add_burden_entry("Freezing Risk", "-%d Wood" % wood_deficit, Color.ORANGE)
	if food_deficit <= 0 and wood_deficit <= 0:
		_add_burden_entry("Supplies Sufficient", "Stockpiles Holding", Color.GREEN)

func _add_burden_entry(title: String, value: String, color: Color) -> void:
	var entry = Label.new()
	entry.text = "%s: %s" % [title, value]
	entry.modulate = color
	deficit_container.add_child(entry)

# ------------------------------------------------------------------------------
# STRATUM II: The Great Hall (Interactive)
# ------------------------------------------------------------------------------
func _refresh_stratum_hall() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	
	if not card_prefab: 
		Loggie.msg("WinterCourt: Missing Card Prefab").domain(LogDomains.UI).error()
		return

	for card_data in available_court_cards:
		var card_instance = card_prefab.instantiate()
		cards_container.add_child(card_instance)
		
		var can_afford = _can_afford(card_data)
		
		if card_instance.has_method("setup"):
			card_instance.setup(card_data, can_afford)
		elif "resource" in card_instance:
			card_instance.resource = card_data
			if "is_disabled" in card_instance:
				card_instance.is_disabled = not can_afford
			
		# Connect Signals
		if card_instance.has_signal("card_clicked"):
			card_instance.card_clicked.connect(_on_card_clicked)
		if card_instance.has_signal("card_denied"):
			card_instance.card_denied.connect(_on_card_denied)
			
		# NEW: Connect Hover Signals
		if card_instance.has_signal("card_hovered"):
			card_instance.card_hovered.connect(_on_card_hovered)
		if card_instance.has_signal("card_exited"):
			card_instance.card_exited.connect(_on_card_exited)

func _can_afford(card: SeasonalCardResource) -> bool:
	if current_ap < card.cost_ap:
		return false
		
	var costs = {}
	if card.cost_gold > 0: costs[GameResources.GOLD] = card.cost_gold
	if card.cost_food > 0: costs[GameResources.FOOD] = card.cost_food
	
	if not costs.is_empty():
		if EconomyManager.has_method("can_afford"):
			return EconomyManager.can_afford(costs)
		return false
	
	return true

func _update_hall_ui() -> void:
	action_points_label.text = "Dynastic Attention: %d / %d" % [current_ap, max_ap]

func _on_card_clicked(card: SeasonalCardResource) -> void:
	var success: bool = WinterManager.play_seasonal_card(card)
	if success:
		Loggie.msg("Played Winter Card: %s" % card.display_name).domain(LogDomains.GAMEPLAY).info()
		_refresh_stratum_hall()
	else:
		_show_error_feedback("Ritual failed to bind.")

func _on_card_denied(card: SeasonalCardResource, reason: String) -> void:
	_show_error_feedback("Not enough resources: %s" % card.display_name)

# NEW: Update the shared description area
func _on_card_hovered(card: SeasonalCardResource) -> void:
	if description_label:
		# Show the text
		description_label.text = "%s\n%s" % [card.display_name.to_upper(), card.description]
		
		# Show the overlay background (The PanelContainer parent)
		var overlay = description_label.get_parent()
		if overlay is Control:
			overlay.show()
			# Optional: Add a quick fade-in tween here for polish

# NEW: Clear or reset the description
func _on_card_exited() -> void:
	if description_label:
		# Instead of setting text to "Select a card...", we just hide the overlay
		# so it doesn't block the view of the Bloodline stratum.
		var overlay = description_label.get_parent()
		if overlay is Control:
			overlay.hide()

func _show_error_feedback(message: String) -> void:
	if action_points_label:
		var original_text = action_points_label.text
		action_points_label.text = message
		action_points_label.add_theme_color_override("font_color", Color.TOMATO)
		
		get_tree().create_timer(2.0).timeout.connect(func():
			if action_points_label:
				action_points_label.text = original_text
				action_points_label.remove_theme_color_override("font_color")
		)

# ------------------------------------------------------------------------------
# STRATUM III: The Bloodline Thread (Read-Only)
# ------------------------------------------------------------------------------
func _refresh_stratum_bloodline() -> void:
	var jarl: JarlData = DynastyManager.get_current_jarl()
	if not jarl:
		jarl_name_label.text = "Interregnum (No Jarl)"
		jarl_status_label.text = "The throne is empty."
		heir_status_label.text = ""
		return
		
	jarl_name_label.text = "%s (Age %d)" % [jarl.display_name, jarl.age]
	
	var status_text: String = "Vigorous"
	var status_color: Color = Color.GREEN
	
	if jarl.is_in_exile:
		status_text = "In Exile"
		status_color = Color.GRAY
	elif jarl.is_wounded:
		status_text = "Wounded"
		status_color = Color.ORANGE
	elif jarl.age > 60:
		status_text = "Frail"
		status_color = Color.YELLOW
		
	jarl_status_label.text = status_text
	jarl_status_label.modulate = status_color
	
	var heir_count: int = jarl.get_available_heir_count()
	if heir_count == 0:
		heir_status_label.text = "Succession: DANGEROUS (No Heirs)"
		heir_status_label.modulate = Color.RED
	elif heir_count == 1:
		heir_status_label.text = "Succession: Fragile (1 Heir)"
		heir_status_label.modulate = Color.YELLOW
	else:
		heir_status_label.text = "Succession: Secure (%d Heirs)" % heir_count
		heir_status_label.modulate = Color.GREEN
