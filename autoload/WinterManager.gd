extends Node

## WinterManager
## Handles winter severity rolling, consumption calculations, and crisis resolution.
## Updated: Crisis Gold Cost increased to 50x deficit.

signal winter_started(severity: int)
signal winter_ended

enum WinterSeverity {
	MILD = 0,
	NORMAL = 1,
	HARSH = 2
}

# --- Configuration ---
@export_group("Probabilities")
@export_range(0.0, 1.0) var harsh_chance: float = 0.20
@export_range(0.0, 1.0) var mild_chance: float = 0.05

@export_group("Multipliers")
@export var harsh_multiplier: float = 1.5
@export var mild_multiplier: float = 0.75
@export var winter_duration_seconds: float = 60.0

# --- Internal State ---
var current_severity: WinterSeverity = WinterSeverity.NORMAL
## Stores the fate of the COMING winter so UI can predict it accurately.
var upcoming_severity: WinterSeverity = WinterSeverity.NORMAL
var sickness_chance_base: float = 0.10
var winter_consumption_report: Dictionary = {}
var winter_upkeep_report: Dictionary = {} 
var winter_crisis_active: bool = false
# Base chance range for sickness (5% to 20%)
const SICKNESS_MIN_PCT: float = 0.05
const SICKNESS_MAX_PCT: float = 0.20

func _ready() -> void:
	if EventBus:
		EventBus.season_changed.connect(_on_season_changed)
	else:
		Loggie.msg("WinterManager: EventBus not found!").domain(LogDomains.SYSTEM).error()

func _on_season_changed(new_season: String, _context: Dictionary) -> void:
	# Roll in Spring so Summer Council can see it
	if new_season == "Spring":
		roll_upcoming_severity()
	
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
	
	# 3. Sickness triggers
	var settlement = SettlementManager.current_settlement
	if settlement:
		# 1. Calculate and Apply Sickness
		var new_sick_count = _calculate_sickness_risk(settlement)
		
		if new_sick_count > 0:
			# Update Data Model (Persistence)
			# We add to existing sick population (in case of carry-over), clamped to total pop.
			var total_sick = settlement.sick_population + new_sick_count
			settlement.sick_population = min(settlement.population_peasants, total_sick)
			
			Loggie.msg("Outbreak! %d new peasants have fallen ill." % new_sick_count).domain(LogDomains.GAMEPLAY).warn()
		else:
			Loggie.msg("Winter started with clean bill of health.").domain(LogDomains.GAMEPLAY).info()
	
	winter_started.emit(current_severity)
	var severity_name = WinterSeverity.keys()[current_severity]
	Loggie.msg("Winter Phase Started. Severity: %s" % severity_name).domain(LogDomains.GAMEPLAY).info()

func _calculate_sickness_risk(settlement: SettlementData) -> int:
	"""
	Determines how many people get sick.
	Triggers: HARSH severity OR Critical Food Shortage.
	Returns: Integer count of NEW sick people.
	"""
	var risk_triggered: bool = false
	var reason: String = ""
	
	# Trigger 1: Environmental Severity
	if current_severity == WinterSeverity.HARSH:
		risk_triggered = true
		reason = "Harsh Winter"
		
	# Trigger 2: Critical Food Shortage (Start of Winter)
	# If we have less food than population, malnutrition weakens immunity immediately.
	var current_food = settlement.treasury.get(GameResources.FOOD, 0)
	if current_food < settlement.population_peasants:
		risk_triggered = true
		reason = "Malnutrition (Low Food)"

	if not risk_triggered:
		return 0
		
	# Calculate Payload
	var sick_pct = randf_range(SICKNESS_MIN_PCT, SICKNESS_MAX_PCT)
	var sick_count = int(settlement.population_peasants * sick_pct)
	
	# Ensure at least 1 person gets sick if triggered and pop > 0
	if sick_count == 0 and settlement.population_peasants > 0:
		sick_count = 1
		
	Loggie.msg("Sickness Triggered by %s. Rate: %.1f%%" % [reason, sick_pct * 100]).domain(LogDomains.GAMEPLAY).debug()
	
	return sick_count

func end_winter_phase() -> void:
	winter_crisis_active = false
	winter_consumption_report.clear()
	winter_ended.emit()
	
	if DynastyManager.has_method("end_winter_cycle_complete"):
		DynastyManager.end_winter_cycle_complete()

# --- CORE LOGIC ---

func roll_upcoming_severity() -> void:
	"""
	Determines the severity of the NEXT winter.
	Must be called by DynastyManager in Autumn before 'season_changed' is emitted.
	"""
	# Logic: 30% chance of HARSH, otherwise NORMAL.
	# (MILD is currently unused in this specific logic pass, but available for future expansion)
	if randf() < 0.3:
		upcoming_severity = WinterSeverity.HARSH
	else:
		upcoming_severity = WinterSeverity.NORMAL
		
	# Log using the keys from the Enum for readability
	var severity_name = WinterSeverity.keys()[upcoming_severity]
	Loggie.msg("Winter Forecast Rolled: %s" % severity_name).domain(LogDomains.GAMEPLAY).info()


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
	
	# --- FIX: Use new EconomyManager API (Phase 2) ---
	# We no longer calculate costs based on a single generic multiplier.
	# Food is driven by Rationing; Wood is driven by Heating + Severity.
	
	var food_cost = EconomyManager.get_winter_food_demand()
	var wood_cost = EconomyManager.get_winter_wood_demand()
	
	# Calculate Stocks & Deficits
	var food_stock = settlement.treasury.get(GameResources.FOOD, 0)
	var wood_stock = settlement.treasury.get(GameResources.WOOD, 0)
	
	var food_deficit = max(0, food_cost - food_stock)
	var wood_deficit = max(0, wood_cost - wood_stock)
	
	# Construct Report (Updated for new logic)
	winter_consumption_report = {
		"severity_name": WinterSeverity.keys()[current_severity],
		"rationing_policy": SettlementData.RationingPolicy.keys()[settlement.rationing_policy],
		"food_cost": food_cost,
		"wood_cost": wood_cost,
		"food_deficit": food_deficit,
		"wood_deficit": wood_deficit
	}
	
	Loggie.msg("Winter Calculation Complete: %s" % str(winter_consumption_report)).domain(LogDomains.ECONOMY).info()
	
	# Determine Crisis State
	if food_deficit > 0 or wood_deficit > 0:
		winter_crisis_active = true
		Loggie.msg("Winter Crisis Active! Deficits: Food %d, Wood %d" % [food_deficit, wood_deficit]).domain(LogDomains.SYSTEM).warn()
	else:
		winter_crisis_active = false
		
		# Apply Consumption immediately if affordable
		# We pass the calculated costs for logging/consistency, though EconomyManager relies on its internal truth.
		EconomyManager.apply_winter_consumption({
			GameResources.FOOD: food_cost,
			GameResources.WOOD: wood_cost
		})

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
	var jarl = DynastyManager.get_current_jarl()
	
	# 1. Validate AP (ONLY for Winter cards)
	var is_winter_card = (card.season == SeasonalCardResource.SeasonType.WINTER)
	if is_winter_card:
		if not jarl or jarl.current_hall_actions < card.cost_ap:
			return false

	# 2. Validate Resources (Always required)
	var cost_dict = {}
	if card.cost_gold > 0: cost_dict[GameResources.GOLD] = card.cost_gold
	if card.cost_food > 0: cost_dict[GameResources.FOOD] = card.cost_food
	
	if not EconomyManager.attempt_purchase(cost_dict):
		return false

	# 3. Deduct AP (ONLY for Winter cards)
	if is_winter_card:
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
			EconomyManager.clamp_demographics(settlement)
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


# --- UI HOOKS & LIVE DATA API ---

func get_live_crisis_report() -> Dictionary:
	"""
	Recalculates winter deficits on-demand for live UI updates.
	Compares current treasury vs the forecast from EconomyManager.
	Updates the manager's internal `winter_crisis_active` state.
	"""
	var settlement = SettlementManager.current_settlement
	if not settlement:
		return {"food_deficit": 0, "wood_deficit": 0, "is_crisis": false}

	# Get the authoritative demand forecast from EconomyManager
	var forecast = EconomyManager.get_winter_forecast()
	var food_demand = forecast.get(GameResources.FOOD, 0)
	var wood_demand = forecast.get(GameResources.WOOD, 0)
	
	# Get current stockpile
	var food_stock = settlement.treasury.get(GameResources.FOOD, 0)
	var wood_stock = settlement.treasury.get(GameResources.WOOD, 0)
	
	# Calculate deficits
	var food_deficit = max(0, food_demand - food_stock)
	var wood_deficit = max(0, wood_demand - wood_stock)
	
	# Update internal state
	winter_crisis_active = (food_deficit > 0 or wood_deficit > 0)
	
	return {
		"food_deficit": food_deficit,
		"wood_deficit": wood_deficit,
		"is_crisis": winter_crisis_active
	}

func get_sickness_omen(sick_pop: int, total_pop: int) -> Dictionary:
	"""
	Returns thematic text and color based on the percentage of sick population.
	Used for flavor text in the UI.
	"""
	if total_pop <= 0 or sick_pop <= 0:
		return {"text": "", "color": Color.WHITE}

	var ratio = float(sick_pop) / float(total_pop)
	
	if ratio >= 0.5:
		return {
			"text": "The long dark has taken root...",
			"color": Color.DARK_RED
		}
	elif ratio >= 0.2:
		return {
			"text": "The breath of the frost is on their necks.",
			"color": Color.ORANGE_RED
		}
	elif ratio > 0:
		return {
			"text": "A cough echoes in the hall.",
			"color": Color.PALE_VIOLET_RED
		}
		
	return {"text": "", "color": Color.WHITE}
