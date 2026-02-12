extends Control

## WinterCourtUI - The Seasonal Workspace
##
## ARCHITECTURE: "The Pillar & The Triptych"
## Zone A (Left): The Spine/Pillar. Holds Context (Burden, AP, Descriptions).
## Zone B (Right): The Ritual Stage. Holds the Content (Cards).

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
@export_group("Great Hall Stratum")
## The list of Seasonal Cards available this winter
@export var available_court_cards: Array[SeasonalCardResource] = []
## The UI Prefab for a single card
@export var card_prefab: PackedScene

# ------------------------------------------------------------------------------
# Node References (The Blueprint)
# ------------------------------------------------------------------------------
# ZONE A: THE LEFT SPINE
@onready var severity_label: Label = %SeverityLabel
@onready var resource_totem: VBoxContainer = %ResourceTotem # Was DeficitContainer
@onready var action_points_label: Label = %ActionPointsLabel
@onready var description_label: Label = %DescriptionLabel # Now anchored in the Spine
@onready var jarl_name_label: Label = %JarlNameLabel # Dynasty Context

# ZONE B: THE RITUAL STAGE
@onready var cards_container: HBoxContainer = %CardsContainer

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
	
	if EventBus:
		EventBus.hall_action_updated.connect(_on_ap_updated)
		EventBus.treasury_updated.connect(_on_treasury_updated)
		
		# Task 3.2.2: Connect signals to the new dashboard updater
		EventBus.hall_action_updated.connect(_update_dashboard)
		EventBus.treasury_updated.connect(_update_dashboard)
		
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
	_update_spine_header()
	_refresh_ritual_stage()

func _on_treasury_updated(_new_treasury: Dictionary) -> void:
	if visible:
		_refresh_resource_totem()
		_refresh_ritual_stage()

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------
func setup_winter_view() -> void:
	Loggie.msg("Initializing Winter Court: Pillar & Triptych").domain(LogDomains.UI).info()
	
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
	
	# Reset Description
	if description_label: 
		description_label.text = "Select a card to view details..."
		# Ensure the container is visible if we hid it previously
		var parent = description_label.get_parent()
		if parent is Control: parent.show()

# ------------------------------------------------------------------------------
# ZONE A: THE LEFT SPINE (Context)
# ------------------------------------------------------------------------------
func _refresh_resource_totem() -> void:
	# Get latest data
	var settlement = SettlementManager.current_settlement
	if not settlement: return

	# Clears existing children
	for child in resource_totem.get_children():
		child.queue_free()

	# --- Task 3.1: New Survival Rows ---

	# 1. Sickness Row (Only if present)
	if settlement.sick_population > 0:
		_add_totem_entry("THE SICK", str(settlement.sick_population), Color.MAGENTA)

	# 2. Heating Demand (Always show in Winter)
	# This uses the Phase 1 Cache + Phase 2 Severity Multiplier
	var heating_demand = EconomyManager.get_winter_wood_demand()
	if heating_demand > 0:
		_add_totem_entry("WINTER UPKEEP", "-%d Wood" % heating_demand, Color.ORANGE)

	# --- Existing Deficit Logic (Preserved) ---
	
	# Recalculate deficits based on current stocks vs projected demand
	# We grab the forecast again to ensure we match the UI numbers
	var forecast = EconomyManager.get_winter_forecast()
	var wood_deficit = max(0, forecast[GameResources.WOOD] - settlement.treasury.get(GameResources.WOOD, 0))
	var food_deficit = max(0, forecast[GameResources.FOOD] - settlement.treasury.get(GameResources.FOOD, 0))

	if food_deficit > 0:
		_add_totem_entry("FOOD SHORTAGE", "-%d" % food_deficit, Color.RED)

	if wood_deficit > 0:
		_add_totem_entry("WOOD SHORTAGE", "-%d" % wood_deficit, Color.ORANGE) # or Color.CYAN for freezing

	Loggie.msg("Winter Court: Resource Totem Refreshed").domain(LogDomains.UI).debug()

func _add_totem_entry(title: String, value: String, color: Color) -> void:
	# Create a simple HBox for the totem entry (Label - Value)
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
		action_points_label.text = "ATTENTION: %d / %d" % [current_ap, max_ap]

func _refresh_dynasty_context() -> void:
	var jarl: JarlData = DynastyManager.get_current_jarl()
	if jarl_name_label:
		if jarl:
			jarl_name_label.text = "%s (Age %d)" % [jarl.display_name.to_upper(), jarl.age]
		else:
			jarl_name_label.text = "INTERREGNUM"

# ------------------------------------------------------------------------------
# ZONE B: THE RITUAL STAGE (Content)
# ------------------------------------------------------------------------------
func _refresh_ritual_stage() -> void:
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
			
		# Hover Signals -> Target the Spine Description
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

func _on_card_clicked(card: SeasonalCardResource) -> void:
	var success: bool = WinterManager.play_seasonal_card(card)
	if success:
		Loggie.msg("Played Winter Card: %s" % card.display_name).domain(LogDomains.GAMEPLAY).info()
		_refresh_ritual_stage()
		_on_card_exited() # Clear description
	else:
		# Use the Totem area or AP label for quick feedback
		_flash_spine_warning("RITUAL FAILED")

func _on_card_denied(card: SeasonalCardResource, _reason: String) -> void:
	_flash_spine_warning("NEED RESOURCES")

# --- MASTER-DETAIL LOGIC (Targets the Spine) ---
func _on_card_hovered(card: SeasonalCardResource) -> void:
	if description_label:
		description_label.text = "[b]%s[/b]\n\n%s" % [card.display_name.to_upper(), card.description]
		# Ensure visible
		description_label.get_parent().show()

func _on_card_exited() -> void:
	if description_label:
		description_label.text = "Select a card..."

func _flash_spine_warning(message: String) -> void:
	if action_points_label:
		var original_text = action_points_label.text
		action_points_label.text = message
		action_points_label.add_theme_color_override("font_color", Color.TOMATO)
		
		get_tree().create_timer(1.5).timeout.connect(func():
			if action_points_label:
				action_points_label.text = original_text
				action_points_label.remove_theme_color_override("font_color")
		)


# --- Ghost Preview Helpers (Task 4.1) ---
func _pulse_resource_totem_green() -> void:
	if not resource_totem: return
	
	var pulse_tween = create_tween()
	pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Pulse in green
	pulse_tween.tween_property(resource_totem, "modulate", Color.LIME_GREEN, 0.3)
	# Pulse out to white (or original color)
	pulse_tween.tween_property(resource_totem, "modulate", Color.WHITE, 0.5)
	# Repeat a few times
	pulse_tween.set_loops(3)


# --- Dashboard Updater (Task 3.2.1) ---
# The _payload argument is unused, but required to match the signature of
# signals like 'treasury_updated' which emit a value.
func _update_dashboard(_payload = null) -> void:
	# Checkpoint for Task 3.2.1
	Loggie.msg("UI: Dashboard Refreshed").domain(LogDomains.UI).info()
	
	var settlement = SettlementManager.current_settlement
	if not settlement:
		Loggie.msg("UI: Cannot update dashboard, no settlement loaded.").domain(LogDomains.UI).warn()
		return

	# --- Update Crisis Banner (Severity Label) ---
	var crisis_report = WinterManager.get_live_crisis_report()
	
	if crisis_report.is_crisis:
		severity_label.text = "CRISIS! Food: %d, Wood: %d" % [crisis_report.food_deficit, crisis_report.wood_deficit]
		if "modulate" in severity_label: severity_label.modulate = Color.RED
	else:
		# Use the forecast details for a non-crisis label
		var forecast = WinterManager.get_forecast_details()
		severity_label.text = "Winter Outlook: %s" % forecast.label
		if "modulate" in severity_label: severity_label.modulate = Color.WHITE

	# --- Update Sickness Omen (Description Label) ---
	# Note: This will be overwritten by card hover. It serves as a default state.
	var sick_population = settlement.sick_population
	var total_population = settlement.population_peasants
	
	var omen = WinterManager.get_sickness_omen(sick_population, total_population)
	if not omen.text.is_empty():
		description_label.text = "[b]OMEN:[/b] %s" % omen.text
		if "modulate" in description_label: description_label.modulate = omen.color
	else:
		description_label.text = "Select a card to view details..."
		if "modulate" in description_label: description_label.modulate = Color.WHITE
