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
# UI REFERENCES (Unique Names for Scene Portability)
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
@onready var pop_label: Label = %PeasantLabel
@onready var thrall_label: Label = %ThrallLabel
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
	# 1. Resource Signals (Legacy TreasuryHUD Pattern)
	if EventBus:
		EventBus.treasury_updated.connect(_on_treasury_updated)
		EventBus.settlement_loaded.connect(func(_data): refresh_all())
	else:
		Loggie.msg("EventBus missing in TopBar").domain(Loggie.LogDomains.UI).error()

	# 2. Dynasty/Time Signals
	if DynastyManager:
		DynastyManager.year_ended.connect(refresh_all)
		# Listen for jarl updates if a specific signal exists, otherwise rely on MainGameUI to trigger identity refreshes
		# or the year_ended signal which often correlates with changes.

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

func refresh_identity(jarl_data: Resource = null) -> void:
	if jarl_data:
		_update_identity_labels(jarl_data)
	else:
		_refresh_identity() # Fallback to fetching from Singleton

func refresh_treasury(treasury_data: Dictionary) -> void:
	_update_resource_labels(treasury_data)
	# We also update population stats when treasury updates, as they are often linked
	_update_population_stats()

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
		_update_population_stats()

# --- Display Updaters ---

func _update_identity_labels(jarl: Resource) -> void:
	# Guard clauses for optional nodes
	if jarl_label: jarl_label.text = jarl.display_name
	if authority_label: authority_label.text = "Auth: %d" % jarl.current_authority
	if renown_label: renown_label.text = "Renown: %d" % jarl.renown

func _update_resource_labels(treasury: Dictionary) -> void:
	# Uses GameResources constants for safety, defaults to 0
	if gold_label: gold_label.text = "%d" % treasury.get(GameResources.GOLD, 0)
	if wood_label: wood_label.text = "%d" % treasury.get(GameResources.WOOD, 0)
	if food_label: food_label.text = "%d" % treasury.get(GameResources.FOOD, 0)
	if stone_label: stone_label.text = "%d" % treasury.get(GameResources.STONE, 0)

func _update_population_stats() -> void:
	# Legacy Calculation Logic from TreasuryHUD
	if not SettlementManager or not SettlementManager.current_settlement: return

	# Army Count
	if unit_count_label:
		unit_count_label.text = "%d" % SettlementManager.current_settlement.warbands.size()
	
	# Population Math
	var idle_p = SettlementManager.get_idle_peasants()
	var total_p = SettlementManager.current_settlement.population_peasants
	var idle_t = SettlementManager.get_idle_thralls()
	var total_t = SettlementManager.current_settlement.population_thralls
	
	# Update Labels
	if pop_label: pop_label.text = "%d/%d" % [idle_p, total_p]
	if thrall_label: thrall_label.text = "%d/%d" % [idle_t, total_t]

# --- Signal Handlers ---

func _on_treasury_updated(new_treasury: Dictionary) -> void:
	refresh_treasury(new_treasury)
