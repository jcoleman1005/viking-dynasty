extends Node

## WinterManager
## Handles winter severity rolling, consumption calculations, and crisis resolution.
## Updated: Crisis Gold Cost increased to 50x deficit.

signal winter_started(severity: int)
signal winter_ended

enum WinterSeverity { MILD, NORMAL, HARSH }

# --- Configuration ---
@export_group("Probabilities")
@export_range(0.0, 1.0) var harsh_chance: float = 0.20
@export_range(0.0, 1.0) var mild_chance: float = 0.05

@export_group("Multipliers")
@export var harsh_multiplier: float = 1.5
@export var mild_multiplier: float = 0.75
@export var winter_duration_seconds: float = 60.0

# --- Internal State ---
var current_severity: int = WinterSeverity.NORMAL
## Stores the fate of the COMING winter so UI can predict it accurately.
var upcoming_severity: int = WinterSeverity.NORMAL

var winter_consumption_report: Dictionary = {}
var winter_upkeep_report: Dictionary = {} 
var winter_crisis_active: bool = false

func _ready() -> void:
	if EventBus:
		EventBus.season_changed.connect(_on_season_changed)
	else:
		Loggie.msg("WinterManager: EventBus not found!").domain(LogDomains.SYSTEM).error()

func _on_season_changed(new_season: String, _context: Dictionary) -> void:
	# Roll in Spring so Summer Council can see it
	if new_season == "Spring":
		_roll_upcoming_severity()
	
	if new_season == "Winter":
		start_winter_phase()

func start_winter_phase() -> void:
	# Commit the forecast fate
	current_severity = upcoming_severity
	
	Loggie.msg("WinterManager: Transitioning to %s Winter" % _get_severity_name(current_severity)).domain(LogDomains.SYSTEM).info()
	
	# 1. Decay Fleet Readiness (Environment Effect)
	_apply_environmental_decay()
	
	# 2. Calculate Needs
	_calculate_winter_needs()
	
	winter_started.emit(current_severity)

func end_winter_phase() -> void:
	winter_crisis_active = false
	winter_consumption_report.clear()
	winter_ended.emit()
	
	if DynastyManager.has_method("end_winter_cycle_complete"):
		DynastyManager.end_winter_cycle_complete()

# --- CORE LOGIC ---

func _roll_upcoming_severity() -> void:
	var roll = randf()
	if roll < harsh_chance:
		upcoming_severity = WinterSeverity.HARSH
	elif roll > (1.0 - mild_chance):
		upcoming_severity = WinterSeverity.MILD
	else:
		upcoming_severity = WinterSeverity.NORMAL
	
	Loggie.msg("Winter Oracle: Forecast for this year is %s" % _get_severity_name(upcoming_severity)).domain(LogDomains.GAMEPLAY).info()

func get_forecast_details() -> Dictionary:
	var mult = get_multiplier_for_severity(upcoming_severity)
	return {
		"label": _get_severity_name(upcoming_severity),
		"multiplier": mult,
		"percent": int(mult * 100)
	}

func calculate_winter_demand(settlement: SettlementData) -> Dictionary:
	if not settlement: return _get_empty_report()

	var mult = get_multiplier_for_severity(upcoming_severity)
		
	var base_food = (settlement.population_peasants * 1) + (settlement.warbands.size() * 5)
	var base_wood = 20
	
	var final_food = int(base_food * mult)
	var final_wood = int(base_wood * mult)
	
	return {
		"severity_enum": upcoming_severity,
		"severity_name": _get_severity_name(upcoming_severity),
		"multiplier": mult,
		"food_demand": final_food,
		"wood_demand": final_wood
	}

func _calculate_winter_needs() -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	var mult = get_multiplier_for_severity(current_severity)
	var costs = EconomyManager.calculate_winter_consumption_costs(mult)
	var food_cost = costs.get(GameResources.FOOD, 0)
	var wood_cost = costs.get(GameResources.WOOD, 0)
	
	var food_stock = settlement.treasury.get(GameResources.FOOD, 0)
	var wood_stock = settlement.treasury.get(GameResources.WOOD, 0)
	
	var food_deficit = max(0, food_cost - food_stock)
	var wood_deficit = max(0, wood_cost - wood_stock)
	
	winter_consumption_report = {
		"severity_name": _get_severity_name(current_severity),
		"multiplier": mult,
		"food_cost": food_cost,
		"wood_cost": wood_cost,
		"food_deficit": food_deficit,
		"wood_deficit": wood_deficit
	}
	
	Loggie.msg("Winter Calculation Complete: %s" % str(winter_consumption_report)).domain(LogDomains.ECONOMY).info()
	
	if food_deficit > 0 or wood_deficit > 0:
		winter_crisis_active = true
		Loggie.msg("Winter Crisis Active! Deficit: %s" % winter_consumption_report).domain(LogDomains.SYSTEM).warn()
	else:
		winter_crisis_active = false
		_apply_winter_consumption()

func _apply_winter_consumption() -> void:
	var costs = {
		GameResources.FOOD: winter_consumption_report.get("food_cost", 0),
		GameResources.WOOD: winter_consumption_report.get("wood_cost", 0)
	}
	EconomyManager.apply_winter_consumption(costs)
	
	winter_upkeep_report = {
		"food_consumed": costs[GameResources.FOOD],
		"wood_consumed": costs[GameResources.WOOD]
	}

func _apply_environmental_decay() -> void:
	var decay = 0.2
	if current_severity == WinterSeverity.HARSH: decay = 0.4
	
	if SettlementManager.current_settlement:
		var current = SettlementManager.current_settlement.fleet_readiness
		SettlementManager.current_settlement.fleet_readiness = max(0.0, current - decay)

# --- CRISIS RESOLUTION ---

func resolve_crisis_with_gold() -> bool:
	# REBALANCE: Increased cost from 5x to 50x to force harder choices.
	# A simple deficit should not be solvable by a single raid.
	var cost_multiplier = 50 
	
	var total_gold_cost = (winter_consumption_report["food_deficit"] * cost_multiplier) + (winter_consumption_report["wood_deficit"] * cost_multiplier)
	
	if EconomyManager.attempt_purchase({GameResources.GOLD: total_gold_cost}):
		winter_crisis_active = false
		_apply_winter_consumption()
		Loggie.msg("Crisis resolved via Gold purchase (%dg)" % total_gold_cost).domain(LogDomains.ECONOMY).info()
		return true
		
	return false

func play_seasonal_card(card: SeasonalCardResource) -> bool:
	# 1. Validate AP
	var jarl = DynastyManager.get_current_jarl()
	if not jarl or jarl.current_hall_actions < card.cost_ap:
		return false

	# 2. Validate Resources
	var cost_dict = {}
	if card.cost_gold > 0: cost_dict["gold"] = card.cost_gold
	if card.cost_food > 0: cost_dict["food"] = card.cost_food
	
	if not EconomyManager.attempt_purchase(cost_dict):
		return false

	# 3. Deduct AP
	DynastyManager.perform_hall_action(card.cost_ap)

	# 4. Apply Rewards
	if card.grant_gold > 0:
		EconomyManager.deposit_resources({"gold": card.grant_gold})
	if card.grant_renown > 0:
		DynastyManager.award_renown(card.grant_renown)
	if card.grant_authority > 0:
		if jarl:
			jarl.current_authority += card.grant_authority
			Loggie.msg("Granted %d Authority via card" % card.grant_authority).domain(LogDomains.DYNASTY).info()
			DynastyManager.jarl_stats_updated.emit(jarl)

	# 5. Apply Modifiers
	DynastyManager.aggregate_card_effects(card)
		
	return true

func resolve_crisis_with_sacrifice(sacrifice_type: String) -> bool:
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

func get_multiplier_for_severity(severity_enum: int) -> float:
	match severity_enum:
		WinterSeverity.HARSH: return harsh_multiplier
		WinterSeverity.MILD: return mild_multiplier
		_: return 1.0

func _get_severity_name(severity_enum: int) -> String:
	return WinterSeverity.keys()[severity_enum]

func _get_empty_report() -> Dictionary:
	return {
		"severity_name": "NORMAL",
		"multiplier": 1.0,
		"food_demand": 0,
		"wood_demand": 0
	}
