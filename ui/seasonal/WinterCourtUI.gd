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
@onready var end_winter_button: Button = %EndWinterButton

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
	
	# Connect internal signals
	end_winter_button.pressed.connect(_on_end_winter_pressed)
	
	# Connect global signals
	EventBus.hall_action_updated.connect(_on_ap_updated)
	
	# NEW: Listen for treasury updates to refresh the "Burden" stratum live
	EventBus.treasury_updated.connect(_on_treasury_updated)
	
	# Listen for season changes to toggle visibility
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

# NEW: Refresh burden when resources change (e.g. Card Played -> Gain Food)
func _on_treasury_updated(_new_treasury: Dictionary) -> void:
	if visible:
		_refresh_stratum_burden()
		# Also refresh cards as affordability might have changed
		_refresh_stratum_hall()

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------
## Main entry point called when the Winter Phase begins
func setup_winter_view() -> void:
	Loggie.msg("Initializing Winter Court UI Strata").domain(LogDomains.UI).info()
	
	# 1. Fetch Jarl Context & Sync AP
	var jarl: JarlData = DynastyManager.get_current_jarl()
	if jarl:
		current_ap = jarl.current_hall_actions
		max_ap = jarl.max_hall_actions
	else:
		current_ap = 0
		max_ap = 0
	
	# 2. Refresh All Strata
	_refresh_stratum_burden()
	_refresh_stratum_bloodline()
	_refresh_stratum_hall()
	_update_hall_ui()

# ------------------------------------------------------------------------------
# STRATUM I: The Burden of Winter (Live Calculation)
# ------------------------------------------------------------------------------
func _refresh_stratum_burden() -> void:
	# 1. Severity (Still read from Manager as it is constant for the season)
	# Fallback logic to prevent crashes if 'winter_consumption_report' is missing/empty
	var severity_name = "NORMAL"
	if WinterManager.has_method("get_severity_name"):
		severity_name = WinterManager.get_severity_name()
	elif "winter_consumption_report" in WinterManager and not WinterManager.winter_consumption_report.is_empty():
		severity_name = WinterManager.winter_consumption_report.get("severity_name", "NORMAL")
		
	severity_label.text = "Winter Severity: %s" % severity_name
	
	if severity_name == "HARSH": severity_label.modulate = Color.RED
	elif severity_name == "MILD": severity_label.modulate = Color.GREEN
	else: severity_label.modulate = Color.WHITE

	# 2. Deficit Visualization (FIX: Calculate LIVE based on Treasury vs Forecast)
	for child in deficit_container.get_children():
		child.queue_free()
	
	var treasury = SettlementManager.current_settlement.treasury
	var forecast = EconomyManager.get_winter_forecast()
	
	# Get Demand (Forecast)
	var food_demand = forecast.get(GameResources.FOOD, 0)
	var wood_demand = forecast.get(GameResources.WOOD, 0)
	
	# Get Supply (Treasury)
	var food_stock = treasury.get(GameResources.FOOD, 0)
	var wood_stock = treasury.get(GameResources.WOOD, 0)
	
	# Calculate Deficits (Demand - Supply)
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
	
	if not card_prefab: return

	for card_data in available_court_cards:
		var card_instance = card_prefab.instantiate()
		cards_container.add_child(card_instance)
		
		var can_afford = _can_afford(card_data)
		
		# Robust Setup Call
		if card_instance.has_method("setup"):
			card_instance.setup(card_data, can_afford)
		elif "resource" in card_instance:
			card_instance.resource = card_data
			if "is_disabled" in card_instance:
				card_instance.is_disabled = not can_afford
			
		if card_instance.has_signal("card_clicked"):
			card_instance.card_clicked.connect(_on_card_clicked)

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
	
	if WinterManager.winter_crisis_active:
		end_winter_button.text = "Face the Crisis..."
		end_winter_button.modulate = Color(1.0, 0.5, 0.5) 
	else:
		end_winter_button.text = "The Ice Melts..."
		end_winter_button.modulate = Color.WHITE

func _on_card_clicked(card: SeasonalCardResource) -> void:
	var success: bool = WinterManager.play_seasonal_card(card)
	
	if success:
		Loggie.msg("Played Winter Card: %s" % card.display_name).domain(LogDomains.GAMEPLAY).info()
	else:
		Loggie.msg("Failed to play card").domain(LogDomains.UI).warn()

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

# ------------------------------------------------------------------------------
# Interaction
# ------------------------------------------------------------------------------
func _on_end_winter_pressed() -> void:
	if WinterManager.winter_crisis_active:
		Loggie.msg("Winter ended with unresolved crisis").domain(LogDomains.GAMEPLAY).warn()
		# FIX: This signal now exists in EventBus
		EventBus.winter_crisis_triggered.emit()
	else:
		Loggie.msg("Winter passed peacefully").domain(LogDomains.GAMEPLAY).info()
		WinterManager.end_winter_phase()
