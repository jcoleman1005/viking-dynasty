# res://ui/components/ResourceBar.gd
class_name ResourceBar
extends PanelContainer

# --- UI References ---
@export var label_gold: Label
@export var label_wood: Label
@export var label_food: Label
@export var label_stone: Label
@export var label_renown: Label
@export var label_pop: Label

func _ready() -> void:
	EventBus.treasury_updated.connect(_on_treasury_updated)
	DynastyManager.jarl_stats_updated.connect(_on_jarl_stats_updated)
	EventBus.settlement_loaded.connect(_on_settlement_loaded)
	
	if SettlementManager.current_settlement:
		_on_treasury_updated(SettlementManager.current_settlement.treasury)
		_update_population(SettlementManager.current_settlement)
		
	if DynastyManager.current_jarl:
		_on_jarl_stats_updated(DynastyManager.current_jarl)

func _on_settlement_loaded(data: SettlementData) -> void:
	_on_treasury_updated(data.treasury)
	_update_population(data)

func _on_treasury_updated(treasury: Dictionary) -> void:
	if label_gold: label_gold.text = str(treasury.get("gold", 0))
	if label_wood: label_wood.text = str(treasury.get("wood", 0))
	if label_stone: label_stone.text = str(treasury.get("stone", 0))
	if label_food: label_food.text = str(treasury.get("food", 0))

func _on_jarl_stats_updated(jarl: JarlData) -> void:
	if label_renown:
		label_renown.text = str(jarl.renown)

func _update_population(data: SettlementData) -> void:
	if not label_pop: return
	
	var idle_p = SettlementManager.get_idle_peasants()
	var idle_t = SettlementManager.get_idle_thralls()
	var total_idle = idle_p + idle_t
	var total_pop = data.population_peasants + data.population_thralls
	
	label_pop.text = "%d / %d" % [total_idle, total_pop]
	
	if total_idle > 0:
		label_pop.modulate = Color.GOLD
		label_pop.tooltip_text = "Idle Workers Available!\nAssign them to buildings to generate resources."
	else:
		label_pop.modulate = Color.WHITE
		label_pop.tooltip_text = "Full Employment"
