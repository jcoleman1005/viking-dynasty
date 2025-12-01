class_name TreasuryHUD
extends PanelContainer

# --- UI References (Using Unique Names for portability) ---
# These look for nodes named "Label" inside containers named "%ResGold", etc.
@onready var gold_label: Label = %GoldLabel
@onready var wood_label: Label = %WoodLabel
@onready var food_label: Label = %FoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var pop_label: Label = %PeasantLabel
@onready var thrall_label: Label = %ThrallLabel
@onready var unit_count_label: Label = %UnitCountLabel

func _ready() -> void:
	# 1. Connect to Global Signals
	EventBus.treasury_updated.connect(_update_treasury_display)
	
	# 2. Also refresh when a save is loaded or year ends
	EventBus.settlement_loaded.connect(func(_data): _refresh_from_manager())
	DynastyManager.year_ended.connect(_refresh_from_manager)
	
	# 3. Initial Update (Deferred to ensure Autoloads are ready)
	call_deferred("_refresh_from_manager")

func _refresh_from_manager() -> void:
	if SettlementManager.current_settlement:
		_update_treasury_display(SettlementManager.current_settlement.treasury)

# --- The Logic You Provided (Adapted for Self-Containment) ---
func _update_treasury_display(treasury: Dictionary) -> void:
	if not is_inside_tree(): return

	# Resources
	gold_label.text = "%d" % treasury.get(GameResources.GOLD, 0)
	wood_label.text = "%d" % treasury.get(GameResources.WOOD, 0)
	food_label.text = "%d" % treasury.get(GameResources.FOOD, 0)
	stone_label.text = "%d" % treasury.get(GameResources.STONE, 0)
	
	if SettlementManager.current_settlement:
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
