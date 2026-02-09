class_name TopBar
extends PanelContainer

## Component: TopBar
## Handles the display of Player Identity (Jarl/Dynasty) and Economic Resources.
## Merges functionality from the legacy TreasuryHUD into the new UI architecture.

# ------------------------------------------------------------------------------
# SIGNALS
# ------------------------------------------------------------------------------

signal dynasty_view_requested

# ------------------------------------------------------------------------------
# UI REFERENCES
# ------------------------------------------------------------------------------

# Identity Section
@onready var jarl_label: Label = %JarlLabel
@onready var authority_label: Label = %AuthorityLabel
@onready var renown_label: Label = %RenownLabel
@onready var dynasty_button: Button = %DynastyButton

# Resource Section (Legacy TreasuryHUD Mappings)
@onready var gold_label: Label = %GoldLabel
@onready var wood_label: Label = %WoodLabel
@onready var food_label: Label = %FoodLabel
@onready var stone_label: Label = %StoneLabel

# Population Section (New Text-Based HUD)
# Note: Paths derived from new .tscn structure. 
# Recommend setting 'Access as Unique Name' in Scene dock for robustness if structure changes.
@onready var villager_label: Label = %VillagerLabel
@onready var thrall_label: Label = %ThrallLabel
@onready var soldier_label: Label = %SoldierLabel
@onready var total_pop_label: Label = %TotalPopLabel
@onready var total_idle_pop_label: Label = %TotalIdlePopLabel
# Legacy Army Count (Keep reference if needed for tooltip or debug, otherwise ignore)
@onready var unit_count_label: Label = %UnitCountLabel

# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------

func _ready() -> void:
	_connect_signals()
	_connect_local_input()
	
	# Initial fetch deferred to ensure Autoloads (SettlementManager/DynastyManager) are ready
	call_deferred("refresh_all")

func _connect_signals() -> void:
	if EventBus:
		# 1. Resource Signals
		EventBus.treasury_updated.connect(_on_treasury_updated)
		EventBus.settlement_loaded.connect(func(_data): refresh_all())
		
		# 2. Population Signals (NEW)
		if EventBus.has_signal("population_changed"):
			EventBus.population_changed.connect(_update_population_display)
	else:
		Loggie.msg("EventBus missing in TopBar").domain(LogDomains.UI).error()

	# 3. Dynasty/Time Signals
	if DynastyManager:
		DynastyManager.year_ended.connect(refresh_all)

func _connect_local_input() -> void:
	if dynasty_button:
		dynasty_button.pressed.connect(func(): dynasty_view_requested.emit())

# ------------------------------------------------------------------------------
# PUBLIC METHODS (Controller Interface)
# ------------------------------------------------------------------------------

func refresh_all() -> void:
	if not is_inside_tree(): return
	
	_refresh_identity()
	_refresh_treasury_from_manager()
	_update_population_display()

func refresh_identity(jarl_data: Resource = null) -> void:
	if jarl_data:
		_update_identity_labels(jarl_data)
	else:
		_refresh_identity() # Fallback to fetching from Singleton

func refresh_treasury(treasury_data: Dictionary) -> void:
	_update_resource_labels(treasury_data)
	# Treasury updates often correlate with purchase/drafting, so refresh pop too
	_update_population_display()

# ------------------------------------------------------------------------------
# INTERNAL LOGIC
# ------------------------------------------------------------------------------

func _refresh_identity() -> void:
	if DynastyManager:
		var jarl = DynastyManager.get_current_jarl()
		if jarl:
			_update_identity_labels(jarl)

func _refresh_treasury_from_manager() -> void:
	if SettlementManager and SettlementManager.current_settlement:
		_update_resource_labels(SettlementManager.current_settlement.treasury)

# --- Display Updaters ---

func _update_identity_labels(jarl: Resource) -> void:
	if jarl_label: jarl_label.text = jarl.display_name
	if authority_label: authority_label.text = "Auth: %d" % jarl.current_authority
	if renown_label: renown_label.text = "Renown: %d" % jarl.renown

func _update_resource_labels(treasury: Dictionary) -> void:
	if gold_label: gold_label.text = "%d" % treasury.get(GameResources.GOLD, 0)
	if wood_label: wood_label.text = "%d" % treasury.get(GameResources.WOOD, 0)
	if food_label: food_label.text = "%d" % treasury.get(GameResources.FOOD, 0)
	if stone_label: stone_label.text = "%d" % treasury.get(GameResources.STONE, 0)

## NEW: Aggregates census data and updates the segmented labels
func _update_population_display() -> void:
	if not EconomyManager: 
		Loggie.msg("TopBar: EconomyManager not found during update").domain(LogDomains.UI).warn()
		return
	
	# Pull complete census (includes calculated totals and idle counts)
	var census = EconomyManager.get_population_census()
	
	# Extract Totals
	var peasants_total = census.get("peasants", {}).get("total", 0)
	var thralls_total = census.get("thralls", {}).get("total", 0)
	var soldiers_total = census.get("soldiers", {}).get("total", 0)
	
	# Extract Idle counts
	var peasants_idle = census.get("peasants", {}).get("idle", 0)
	var thralls_idle = census.get("thralls", {}).get("idle", 0)
	
	# Calculate Global Totals
	var total_pop = peasants_total + thralls_total + soldiers_total
	var total_idle = peasants_idle + thralls_idle
	
	# Update Category Labels
	_update_count_label(villager_label, peasants_total)
	_update_count_label(thrall_label, thralls_total)
	_update_count_label(soldier_label, soldiers_total)
	
	# Update Total Population Label
	if total_pop_label:
		total_pop_label.text = "Total Population: %d" % total_pop
		
	# Update Idle Population Label
	if total_idle_pop_label:
		total_idle_pop_label.text = "Idle: %d" % total_idle
		# Optional: Visual cue if idle pop is high or zero
		total_idle_pop_label.modulate = Color.WHITE if total_idle > 0 else Color(1, 1, 1, 0.5)

	Loggie.msg("TopBar updated: Total %d | Idle %d" % [total_pop, total_idle]).domain(LogDomains.UI).debug()

## Helper to format and dim labels based on value
func _update_count_label(lbl: Label, count: int) -> void:
	if not lbl: return
	
	lbl.text = str(count)
	
	# Visual Feedback: Dim the text if 0, Brighten if active
	if count > 0:
		lbl.modulate = Color(1, 1, 1, 1) # White
	else:
		lbl.modulate = Color(1, 1, 1, 0.5) # Gray/Dim

# --- Signal Handlers ---

func _on_treasury_updated(new_treasury: Dictionary) -> void:
	refresh_treasury(new_treasury)
