# res://autoload/WinterManager.gd
extends Node

signal winter_started
signal winter_ended

# --- Severity Definitions ---
enum WinterSeverity { MILD, NORMAL, HARSH }

# --- Configuration ---
@export_group("Probabilities")
@export_range(0.0, 1.0) var harsh_chance: float = 0.20
@export_range(0.0, 1.0) var mild_chance: float = 0.05

@export_group("Multipliers")
@export var harsh_multiplier: float = 1.5
@export var mild_multiplier: float = 0.75

# --- Internal State ---
var current_severity: WinterSeverity = WinterSeverity.NORMAL
var winter_consumption_report: Dictionary = {}
var winter_upkeep_report: Dictionary = {} 
var winter_crisis_active: bool = false

func start_winter_phase() -> void:
	Loggie.msg("WinterManager: Starting Winter Phase...").domain(LogDomains.SYSTEM).info()
	
	# 1. Decay Fleet Readiness (Environment Effect)
	_apply_environmental_decay()
	
	# 2. Calculate Needs
	_calculate_winter_needs()
	
	winter_started.emit()
	EventBus.scene_change_requested.emit("winter_court")

func end_winter_phase() -> void:
	winter_crisis_active = false
	winter_consumption_report.clear()
	winter_ended.emit()
	
	# Delegate the "End of Year" aging/saving back to DynastyManager
	# But we call it from here to ensure linear flow
	DynastyManager.end_winter_cycle_complete()

# --- CORE LOGIC ---

func calculate_winter_demand(settlement: SettlementData) -> Dictionary:
	if not settlement: return _get_empty_report()

	_roll_severity()
	
	var mult: float = 1.0
	match current_severity:
		WinterSeverity.HARSH: mult = harsh_multiplier
		WinterSeverity.MILD: mult = mild_multiplier
		_: mult = 1.0
		
	var base_food = (settlement.population_peasants * 1) + (settlement.warbands.size() * 5)
	var base_wood = 20
	
	var final_food = int(base_food * mult)
	var final_wood = int(base_wood * mult)
	
	return {
		"severity_enum": current_severity,
		"severity_name": WinterSeverity.keys()[current_severity],
		"multiplier": mult,
		"food_demand": final_food,
		"wood_demand": final_wood
	}

func _calculate_winter_needs() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	var demand_report = calculate_winter_demand(settlement)
	
	var food_cost = demand_report["food_demand"]
	var wood_cost = demand_report["wood_demand"]
	var food_stock = settlement.treasury.get("food", 0)
	var wood_stock = settlement.treasury.get("wood", 0)
	
	var food_deficit = max(0, food_cost - food_stock)
	var wood_deficit = max(0, wood_cost - wood_stock)
	
	winter_consumption_report = {
		"severity": demand_report["severity_name"],
		"multiplier": demand_report["multiplier"],
		"food_cost": food_cost,
		"wood_cost": wood_cost,
		"food_deficit": food_deficit,
		"wood_deficit": wood_deficit
	}
	
	if food_deficit > 0 or wood_deficit > 0:
		winter_crisis_active = true
		Loggie.msg("Winter Crisis Active! Deficit: F%d W%d" % [food_deficit, wood_deficit]).domain(LogDomains.SYSTEM).warn()
	else:
		winter_crisis_active = false
		_apply_winter_consumption()

func _apply_winter_consumption() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	var f_cost = winter_consumption_report.get("food_cost", 0)
	var w_cost = winter_consumption_report.get("wood_cost", 0)
	
	settlement.treasury["food"] = max(0, settlement.treasury.get("food", 0) - f_cost)
	settlement.treasury["wood"] = max(0, settlement.treasury.get("wood", 0) - w_cost)
	
	# Log for UI
	winter_upkeep_report = {
		"food_consumed": f_cost,
		"wood_consumed": w_cost
	}
	
	EventBus.treasury_updated.emit(settlement.treasury)
	Loggie.msg("Winter consumption applied.").domain(LogDomains.SYSTEM).info()

func _apply_environmental_decay() -> void:
	var decay = 0.2
	if current_severity == WinterSeverity.HARSH: decay = 0.4
	
	if SettlementManager.current_settlement:
		var current = SettlementManager.current_settlement.fleet_readiness
		SettlementManager.current_settlement.fleet_readiness = max(0.0, current - decay)

# --- CRISIS RESOLUTION ---

func resolve_crisis_with_gold() -> bool:
	var total_gold_cost = (winter_consumption_report["food_deficit"] * 5) + (winter_consumption_report["wood_deficit"] * 5)
	
	if SettlementManager.attempt_purchase({"gold": total_gold_cost}):
		winter_crisis_active = false
		_apply_winter_consumption()
		return true
	return false

func resolve_crisis_with_sacrifice(sacrifice_type: String) -> bool:
	# Sacrifice costs 1 Action (paid to DynastyManager)
	if not DynastyManager.perform_hall_action(1): 
		return false
		
	var settlement = SettlementManager.current_settlement
	match sacrifice_type:
		"starve_peasants":
			var deaths = max(1, int(winter_consumption_report["food_deficit"] / 5))
			settlement.population_peasants = max(0, settlement.population_peasants - deaths)
			Loggie.msg("%d Peasants starved." % deaths).domain(LogDomains.SYSTEM).warn()
		"disband_warband":
			if not settlement.warbands.is_empty(): 
				settlement.warbands.pop_back()
				Loggie.msg("Warband disbanded.").domain(LogDomains.SYSTEM).warn()
		"burn_ships":
			settlement.fleet_readiness = 0.0
			Loggie.msg("Ships burned for wood.").domain(LogDomains.SYSTEM).warn()
			
	winter_crisis_active = false
	_apply_winter_consumption()
	return true

# --- HELPERS ---

func _roll_severity() -> void:
	var roll = randf()
	if roll < harsh_chance:
		current_severity = WinterSeverity.HARSH
	elif roll > (1.0 - mild_chance):
		current_severity = WinterSeverity.MILD
	else:
		current_severity = WinterSeverity.NORMAL
		
	Loggie.msg("WinterManager: Rolled %s (Val: %.2f)" % [WinterSeverity.keys()[current_severity], roll]).domain(LogDomains.SYSTEM).info()

func _get_empty_report() -> Dictionary:
	return {
		"severity_name": "NORMAL",
		"multiplier": 1.0,
		"food_demand": 0,
		"wood_demand": 0
	}
