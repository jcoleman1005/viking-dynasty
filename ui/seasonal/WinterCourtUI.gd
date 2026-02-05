extends Control
class_name WinterCourtUI

## WinterCourtUI - The Seasonal Workspace
##
## Organizes the Winter phase into three persistent strata:
## 1. Burden (Deficits & Severity) - Read Only
## 2. Great Hall (Actions & Cards) - Interactive
## 3. Bloodline (Dynasty Context) - Read Only

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------
# Expected Singletons: WinterManager, DynastyManager, EventBus, Loggie, EconomyManager

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
	# Default to hidden as this is a Phase-specific UI
	visible = false
	
	# Connect internal signals
	end_winter_button.pressed.connect(_on_end_winter_pressed)
	
	# Connect global signals
	EventBus.hall_action_updated.connect(_on_ap_updated)
	
	# Listen for season changes to toggle visibility
	# We check for the signal's existence for safety, assuming standard EventBus
	if EventBus.has_signal("season_changed"):
		EventBus.season_changed.connect(_on_season_changed)
	elif EventBus.has_signal("winter_started"): 
		# Fallback if specific signal is used instead of generic season change
		EventBus.winter_started.connect(func(): _on_season_changed("Winter"))

func _on_season_changed(new_season: String) -> void:
	if new_season == "Winter":
		show()
		setup_winter_view()
	else:
		hide()

func _on_ap_updated(new_amount: int) -> void:
	current_ap = new_amount
	# Update label
	_update_hall_ui()
	# Update card interactivity (affordability may have changed)
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
		# TRUST THE MANAGER: We do not recalculate actions here. 
		current_ap = jarl.current_hall_actions
		max_ap = jarl.max_hall_actions
	else:
		current_ap = 0
		max_ap = 0
	
	# 2. Refresh Strata
	_refresh_stratum_burden()
	_refresh_stratum_bloodline()
	_refresh_stratum_hall()
	
	# 3. Update Visuals
	_update_hall_ui()

# ------------------------------------------------------------------------------
# STRATUM I: The Burden of Winter (Read-Only)
# ------------------------------------------------------------------------------
func _refresh_stratum_burden() -> void:
	var report: Dictionary = WinterManager.winter_consumption_report
	
	# 1. Severity Display
	# Use Enum for robust checking (Fallback to NORMAL = 1 if missing)
	var severity_enum: int = report.get("severity_enum", 1) 
	var severity_name: String = report.get("severity_name", "NORMAL")
	
	severity_label.text = "Winter Severity: %s" % severity_name
	
	# Color code severity using Manager constants if available, or implied logic
	# Assuming WinterManager has the Enum: NORMAL=1, HARSH=2, MILD=0 (Example)
	# Safest approach is to check the integer values we expect or the name
	if severity_name == "HARSH": # Or WinterManager.WinterSeverity.HARSH
		severity_label.modulate = Color.RED
	elif severity_name == "MILD":
		severity_label.modulate = Color.GREEN
	else:
		severity_label.modulate = Color.WHITE

	# 2. Deficit Visualization
	# Clear previous
	for child in deficit_container.get_children():
		child.queue_free()
	
	var food_deficit: int = report.get("food_deficit", 0)
	var wood_deficit: int = report.get("wood_deficit", 0)
	
	# TRUST THE MANAGER: We do not calculate is_crisis_active locally.
	# We only visualize the deficits provided by the report.
	
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
	# Clean up existing cards
	for child in cards_container.get_children():
		child.queue_free()
	
	# SAFETY CHECK: Prevent runtime errors if prefab is missing
	if not card_prefab:
		Loggie.msg("WinterCourtUI: No card_prefab assigned!").domain(LogDomains.UI).warn()
		return

	# Instantiate Cards from the Exported Array
	for card_data in available_court_cards:
		var card_instance = card_prefab.instantiate()
		cards_container.add_child(card_instance)
		
		# Check complete affordability (AP + Resources)
		var can_afford = _can_afford(card_data)
		
		# Attempt to pass data to the card UI with affordability context
		if card_instance.has_method("setup"):
			# Assuming setup signature is setup(resource, is_clickable/can_afford)
			card_instance.setup(card_data, can_afford)
		elif "resource" in card_instance:
			card_instance.resource = card_data
			if "is_disabled" in card_instance:
				card_instance.is_disabled = not can_afford
		else:
			Loggie.msg("WinterCourtUI: Card prefab missing 'setup()' or 'resource' property").domain(LogDomains.UI).error()
			
		# Connect interaction signal
		if card_instance.has_signal("card_clicked"):
			card_instance.card_clicked.connect(_on_card_clicked)

func _can_afford(card: SeasonalCardResource) -> bool:
	# 1. Check AP
	if current_ap < card.cost_ap:
		return false
		
	# 2. Check Resources via EconomyManager
	var costs = {}
	if card.cost_gold > 0: costs["gold"] = card.cost_gold
	if card.cost_food > 0: costs["food"] = card.cost_food
	# Note: SeasonalCardResource currently doesn't have cost_wood defined in provided snippets, 
	# but if it did: if card.cost_wood > 0: costs["wood"] = card.cost_wood
	
	if not costs.is_empty():
		# Ensure EconomyManager has this method (See Adjustment 2)
		if EconomyManager.has_method("can_afford"):
			return EconomyManager.can_afford(costs)
		return false # Fail safe if manager is outdated
	
	return true

func _update_hall_ui() -> void:
	action_points_label.text = "Dynastic Attention: %d / %d" % [current_ap, max_ap]
	
	# Update Button State based on Manager Truth
	if WinterManager.winter_crisis_active:
		end_winter_button.text = "Face the Crisis..."
		end_winter_button.modulate = Color(1.0, 0.5, 0.5) # Reddish tint
	else:
		end_winter_button.text = "The Ice Melts..."
		end_winter_button.modulate = Color.WHITE

func _on_card_clicked(card: SeasonalCardResource) -> void:
	# DELEGATION: Ask Manager to perform action.
	# The Manager handles AP deduction, Resource granting, and Renown awards.
	var success: bool = WinterManager.play_seasonal_card(card)
	
	if success:
		Loggie.msg("Played Winter Card: %s" % card.display_name).domain(LogDomains.GAMEPLAY).info()
		# UI refresh happens automatically via global signals 
		# (EventBus.hall_action_updated -> _on_ap_updated)
	else:
		Loggie.msg("Failed to play card (Cost or State invalid)").domain(LogDomains.UI).warn()

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
		
	# 1. Jarl Details
	jarl_name_label.text = "%s (Age %d)" % [jarl.display_name, jarl.age]
	
	# 2. Status Construction (Priority Order)
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
	
	# 3. Heir Context
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
		# This would trigger the specific crisis resolution modal
		EventBus.winter_crisis_triggered.emit()
	else:
		Loggie.msg("Winter passed peacefully").domain(LogDomains.GAMEPLAY).info()
		
		# Request the WinterManager to close the phase. 
		# WinterManager.end_winter_phase() calls DynastyManager.end_winter_cycle_complete() internally.
		WinterManager.end_winter_phase()
