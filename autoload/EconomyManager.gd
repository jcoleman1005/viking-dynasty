extends Node

# --- EFFICIENCY CONSTANTS ---
const BUILDER_EFFICIENCY: int = 6 
const GATHERER_EFFICIENCY: int = 10 
const BASE_GATHERING_CAPACITY: int = 2

# --- POPULATION CONSTANTS ---
const FOOD_PER_PERSON_PER_YEAR: int = 10
const WINTER_FOOD_BASE: int = 1 # Unifies WinterManager's legacy math
const WINTER_WARBAND_FOOD: int = 5 # Unifies WinterManager's legacy math
const BASE_GROWTH_RATE: float = 0.02 
const STARVATION_PENALTY: float = -0.15 
const UNREST_PER_LANDLESS_PEASANT: int = 2
const FERTILITY_BONUS: float = 0.01
const BASE_LAND_CAPACITY: int = 5

# --- LOGIC CONSTANTS ---
const BASE_STEWARDSHIP_THRESHOLD: int = 10
const STEWARDSHIP_SCALAR: float = 0.05
const TRAIT_FERTILE: String = "Fertile"
const SEASON_AUTUMN: String = "Autumn"
const SEASON_WINTER: String = "Winter"
const WINTER_WOOD_DEMAND: int = 20 # Base fireplace cost
const FORECAST_VARIANCE: float = 0.15 # +/- 15% uncertainty in reports
# --- HEALING CONSTANTS ---
const HEAL_COST_GOLD: int = 50

# --- STORAGE CONSTANTS ---
const BASE_STORAGE_CAPACITY: int = 200 
const BASE_GOLD_CAPACITY: int = 500

# --- RAID CONSTANTS ---
const RAID_LOSS_RATIO_MIN: float = 0.2
const RAID_LOSS_RATIO_MAX: float = 0.4
const RAID_BUILDING_DMG_MIN: int = 50
const RAID_BUILDING_DMG_MAX: int = 150

# --- INTERNAL STATE ---
# Track the fiscal year instead of raw frames to prevent double-billing
var _last_paid_winter_year: int = -1
# Private cache to prevent iterating placed_buildings every frame.
# Initialize to -1 to indicate "dirty/uncalculated" state.
var _cached_total_heating: int = -1
# --- Signals ---
# Emitted when the cached heating value changes (construction/destruction)
signal heating_demand_updated(new_total: int)

# Fallback value to prevent freeze loops if cache fails in Winter
const FALLBACK_HEATING_DEMAND: int = 20

func _ready() -> void:
	# Phase 1.2: Connect signals to invalidate/update cache
	# strictly typed signal connections
	if EventBus:
		EventBus.building_construction_completed.connect(_on_building_completed)
		EventBus.building_destroyed.connect(_on_building_destroyed)
		EventBus.settlement_loaded.connect(_on_settlement_loaded)

# --- Phase 1.2: Caching Logic ---

func _recalculate_total_heating() -> void:
	"""
	Iterates current_settlement.placed_buildings once to sum 'heating_cost'.
	Updates _cached_total_heating.
	Uses load(entry['resource_path']) as mandated.
	"""
	if not SettlementManager.current_settlement:
		Loggie.msg("Attempted to calc heating with no settlement loaded.").domain(LogDomains.ECONOMY).warn()
		return

	var total_heating: int = 0
	var buildings: Array = SettlementManager.current_settlement.placed_buildings
	
	for entry in buildings:
		if "resource_path" in entry:
			var path: String = entry["resource_path"]
			# Safety check before load
			if ResourceLoader.exists(path):
				var build_data = load(path) as BuildingData
				if build_data:
					total_heating += build_data.heating_cost
			else:
				Loggie.msg("Building resource missing at path").ctx(path).domain(LogDomains.ECONOMY).error()
	
	_cached_total_heating = total_heating
	
	Loggie.msg("Heating Cache Recalculated: %d" % total_heating).domain(LogDomains.ECONOMY).info()
	heating_demand_updated.emit(_cached_total_heating)

func get_total_heating_demand() -> int:
	"""
	Returns _cached_total_heating.
	Getter is O(1).
	FAIL-SAFE: Returns fallback constant (20) if cache is invalid/dirty.
	"""
	# If cache is dirty (e.g. freshly loaded without init), try to calc once
	if _cached_total_heating == -1:
		_recalculate_total_heating()
		
	# Fail-safe
	if _cached_total_heating == -1:
		Loggie.msg("Heating Cache Invalid! Returning Fallback.").domain(LogDomains.ECONOMY).error()
		return FALLBACK_HEATING_DEMAND
		
	return _cached_total_heating

# --- Signal Handlers ---

func _on_building_completed(entry: Dictionary) -> void:
	# Logic: Load building data -> Add heating_cost to cache -> emit signal
	# This is an incremental update (O(1)) instead of full recalc
	if "resource_path" in entry:
		var path: String = entry["resource_path"]
		var build_data = load(path) as BuildingData
		
		if build_data:
			# If cache was dirty, full recalc instead of incremental
			if _cached_total_heating == -1:
				_recalculate_total_heating()
			else:
				_cached_total_heating += build_data.heating_cost
				Loggie.msg("Heating increased: +%d (New Total: %d)" % [build_data.heating_cost, _cached_total_heating]).domain(LogDomains.ECONOMY).debug()
				heating_demand_updated.emit(_cached_total_heating)

func _on_building_destroyed(building: Node) -> void:
	# Logic: Building destruction is complex (entry vs node). 
	# Safest approach for data integrity is a full recalculation.
	# Since destruction is rare, O(N) here is acceptable to ensure accuracy.
	Loggie.msg("Building destroyed, recalculating heating cache.").domain(LogDomains.ECONOMY).debug()
	_recalculate_total_heating()

func _on_settlement_loaded(data: SettlementData) -> void:
	# Logic: Force full recalculation on load
	_recalculate_total_heating()


# --- Phase 4.1: Forecast Fuzzing (Stub) ---

func get_forecast_display_data() -> Dictionary:
	"""
	Returns formatted strings for UI (e.g. '200-300 Food').
	Separates UI presentation from the deterministic integer logic.
	
	Returns Dictionary format:
	{ 
		"food": { "min": 100, "max": 120, "text": "100 - 120" },
		"wood": { "min": 50,  "max": 60,  "text": "50 - 60" }
	}
	"""
	# 1. Get the Exact Truth (Deterministic)
	var exact_data = get_winter_forecast()
	var display_data = {}
	
	for res_name in exact_data:
		var exact_val = exact_data[res_name]
		
		# If value is 0 (e.g. Rationing NONE), no range needed
		if exact_val <= 0:
			display_data[res_name] = {
				"min": 0,
				"max": 0,
				"text": "0"
			}
			continue
			
		# 2. Calculate Fuzz Range
		var variance = int(float(exact_val) * FORECAST_VARIANCE)
		# Ensure at least a range of 1 if val > 0
		if variance == 0: variance = 1 
		
		var min_val = max(0, exact_val - variance)
		var max_val = exact_val + variance
		
		# 3. Format Output
		display_data[res_name] = {
			"min": min_val,
			"max": max_val,
			"text": "%d - %d" % [min_val, max_val]
		}
		
	return display_data



func get_resource_cap(resource_type: String) -> int:
	var settlement = SettlementManager.current_settlement
	if not settlement: return BASE_STORAGE_CAPACITY
	
	var key = resource_type.to_lower()
	var cap = BASE_STORAGE_CAPACITY
	if key == "gold": cap = BASE_GOLD_CAPACITY
	
	for entry in settlement.placed_buildings:
		if entry.get("resource_path"):
			var data = load(entry["resource_path"])
			if data is EconomicBuildingData:
				var bonus = data.get("storage_capacity_bonus")
				if bonus == null: bonus = 0
				
				if bonus > 0:
					var b_type = data.resource_type.to_lower()
					if b_type == "generic" or b_type == key:
						cap += bonus
						
	return cap

func is_storage_full(resource_type: String) -> bool:
	var settlement = SettlementManager.current_settlement
	if not settlement: return true
	
	var key = resource_type.to_lower()
	var current = settlement.treasury.get(key, 0)
	var cap = get_resource_cap(key)
	return current >= cap

func get_projected_income() -> Dictionary[String, int]:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	var projection: Dictionary[String, int] = {}
	
	var stewardship_bonus := 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - BASE_STEWARDSHIP_THRESHOLD) * STEWARDSHIP_SCALAR
		stewardship_bonus = max(0.5, stewardship_bonus)

	for entry in settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type.to_lower()
			if type == "generic": continue 
			
			if not projection.has(type): projection[type] = 0
			var p_count = entry.get("peasant_count", 0)
			var p_out = p_count * b_data.base_passive_output
			var t_count = entry.get("thrall_count", 0)
			var t_out = t_count * b_data.output_per_thrall
			var production = int((p_out + t_out) * stewardship_bonus)
			
			projection[type] += production

	if jarl:
		for region_path in jarl.conquered_regions:
			var r_data = load(region_path)
			if r_data:
				for res in r_data.yearly_income:
					var key = res.to_lower()
					if not projection.has(key): projection[key] = 0
					projection[key] += int(r_data.yearly_income[res] * stewardship_bonus)
					
	return projection

## Centralized Winter Forecast Logic
func get_winter_forecast() -> Dictionary:
	"""
	Returns the projected resource consumption for the upcoming Winter.
	Used by AutumnLedgerUI to show 'Winter Demand'.
	"""
	# 1. Food: Driven by Rationing Policy (Task 2.2)
	var predicted_food = get_winter_food_demand()
	
	# 2. Wood: Driven by Building Cache + Severity Multiplier
	var predicted_wood = get_winter_wood_demand()
	
	return {
		GameResources.FOOD: predicted_food,
		GameResources.WOOD: predicted_wood
	}

func get_winter_food_demand() -> int:
	"""
	Calculates total food required based on Population and Rationing Policy.
	Returns: Modified food demand (int).
	"""
	var settlement = SettlementManager.current_settlement
	if not settlement: return 0
	
	var pop = settlement.population_peasants
	var base_demand = pop * WINTER_FOOD_BASE
	
	var policy = settlement.rationing_policy
	var final_demand: int = base_demand
	
	match policy:
		SettlementData.RationingPolicy.NORMAL:
			final_demand = base_demand
		SettlementData.RationingPolicy.HALF:
			final_demand = int(base_demand * 0.5)
			# Loggie.msg("Rationing HALF active. Food demand reduced.").domain(LogDomains.ECONOMY).debug()
		SettlementData.RationingPolicy.NONE:
			final_demand = 0
			# Loggie.msg("Rationing NONE active. Food demand zeroed.").domain(LogDomains.ECONOMY).warn()
			
	return final_demand

func get_winter_wood_demand() -> int:
	"""
	Calculates total wood required based on Cached Buildings + Winter Severity.
	This is the Source of Truth for both UI Forecasts and actual Consumption.
	"""
	var base_heating = get_total_heating_demand() # From Task 1.2 Cache
	var severity_mult: float = 1.0
	
	# access WinterManager state safely
	# Note: We use 'upcoming' for forecasts, but during Winter, 'current' and 'upcoming' 
	# should ideally be aligned. For safety, we use current_severity if Winter is active.
	var severity = WinterManager.upcoming_severity
	if WinterManager.current_severity != WinterManager.WinterSeverity.MILD: 
		# If we are actually IN winter, use the current severity
		if WinterManager.has_signal("winter_started"): # weak check if winter is active
			pass # Logic can be expanded, but for now relying on upcoming is safe for forecasts
	
	# Apply Multipliers (Preserving Legacy Intent)
	match severity:
		WinterManager.WinterSeverity.HARSH:
			severity_mult = 1.5 # 50% more wood needed
		WinterManager.WinterSeverity.MILD:
			severity_mult = 0.75 # 25% less wood needed
		_:
			severity_mult = 1.0
			
	return int(base_heating * severity_mult)

"""## Authoritative math for winter demand (commented out)
func calculate_winter_consumption_costs(severity_mult: float) -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {GameResources.FOOD: 0, GameResources.WOOD: 0}

	var pop = settlement.population_peasants
	var warband_food = 0
	
	# Iterate warbands to account for wounded status (2x consumption)
	for wb in settlement.warbands:
		var cost = WINTER_WARBAND_FOOD
		if wb.is_wounded:
			cost *= 2
		warband_food += cost
	
	var base_food = (pop * WINTER_FOOD_BASE) + warband_food
	var base_wood = WINTER_WOOD_DEMAND
	
	return {
		GameResources.FOOD: int(base_food * severity_mult),
		GameResources.WOOD: int(base_wood * severity_mult)
	}"""

# --- TURN LOGIC (SEASONAL) ---

func apply_winter_consumption(costs: Dictionary) -> void:
	# State-Aware Idempotency
	var current_year = DynastyManager.get_current_year()
	if current_year == _last_paid_winter_year:
		Loggie.msg("EconomyManager: Winter consumption already applied for Year %d." % current_year).domain(LogDomains.ECONOMY).warn()
		return
	
	var settlement = SettlementManager.current_settlement
	if not settlement: return

	# Update State
	_last_paid_winter_year = current_year

	# --- FIX: Source of Truth ---
	# We ignore the passed 'costs' dictionary for the math, 
	# ensuring we use the exact same formulas as the UI.
	var final_food_cost = get_winter_food_demand()
	var final_wood_cost = get_winter_wood_demand()
	
	# Mutate Treasury
	var current_food = settlement.treasury.get(GameResources.FOOD, 0)
	var current_wood = settlement.treasury.get(GameResources.WOOD, 0)
	
	settlement.treasury[GameResources.FOOD] = max(0, current_food - final_food_cost)
	settlement.treasury[GameResources.WOOD] = max(0, current_wood - final_wood_cost)
	
	Loggie.msg("EconomyManager: Winter Consumption Applied. Food: %d (Pol: %d), Wood: %d (Sev: %s)" % 
		[final_food_cost, settlement.rationing_policy, final_wood_cost, WinterManager.WinterSeverity.keys()[WinterManager.upcoming_severity]]).domain(LogDomains.ECONOMY).info()
	
	EventBus.treasury_updated.emit(settlement.treasury)
	
## Centralized Crisis Resolution (Sacrifices)
func resolve_winter_crisis_sacrifice(sacrifice_type: String, deficit_data: Dictionary) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	match sacrifice_type:
		"starve_peasants":
			var deaths = max(1, int(deficit_data.get("food_deficit", 0) / 5))
			settlement.population_peasants = max(0, settlement.population_peasants - deaths)
			Loggie.msg("EconomyManager: Sacrificed %d Peasants" % deaths).domain(LogDomains.ECONOMY).warn()
			
		"disband_warband":
			if not settlement.warbands.is_empty(): 
				settlement.warbands.pop_back()
				Loggie.msg("EconomyManager: Disbanded Warband").domain(LogDomains.ECONOMY).warn()
				
		"burn_ships":
			settlement.fleet_readiness = 0.0
			Loggie.msg("EconomyManager: Burned Ships").domain(LogDomains.ECONOMY).warn()
	
	EventBus.treasury_updated.emit(settlement.treasury)

## NEW: Paid healing hook for UI
func heal_warband(warband: WarbandData) -> bool:
	if not warband.is_wounded: return false
	
	if attempt_purchase({GameResources.GOLD: HEAL_COST_GOLD}):
		warband.is_wounded = false
		Loggie.msg("Healed warband for %d Gold" % HEAL_COST_GOLD).domain(LogDomains.ECONOMY).info()
		return true
	return false

func recruit_professional_unit(unit_cost: Dictionary, unit_data: Variant) -> bool:
	if attempt_purchase(unit_cost):
		var settlement = SettlementManager.current_settlement
		settlement.warbands.append(unit_data)
		Loggie.msg("EconomyManager: Recruited Professional Unit").domain(LogDomains.ECONOMY).info()
		return true
	return false

# --- Logic: State Mutators ---

func set_rationing_policy(new_policy: int) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	# Validate input
	if new_policy not in SettlementData.RationingPolicy.values():
		Loggie.msg("Invalid Rationing Policy index: %d" % new_policy).domain(LogDomains.ECONOMY).error()
		return
		
	settlement.rationing_policy = new_policy
	
	# Log the policy shift
	var policy_name = SettlementData.RationingPolicy.keys()[new_policy]
	Loggie.msg("Rationing Policy updated to: %s" % policy_name).domain(LogDomains.ECONOMY).info()
	
	# Optional: Emit a signal if you want the UI to update instantly without closing/reopening
	EventBus.rationing_policy_changed.emit(new_policy)


func calculate_seasonal_payout(season_name: String, external_context: Dictionary = {}) -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	var total_payout: Dictionary[String, Variant] = { "_messages": [] }
	
	# 1. Calculate Payouts
	var yearly_projection = get_projected_income()
	
	for res in yearly_projection:
		var yearly_amount = yearly_projection[res]
		var seasonal_amount = 0
		
		# Resource Distribution Rules
		if res == "food":
			if season_name == SEASON_AUTUMN:
				seasonal_amount = yearly_amount
				var msg_list: Array = total_payout["_messages"]
				msg_list.append("[color=green]Harvest Complete: +%d Food[/color]" % seasonal_amount)
			else:
				seasonal_amount = 0
		else:
			seasonal_amount = int(yearly_amount / 4.0)
		
		if seasonal_amount > 0:
			total_payout[res] = seasonal_amount

	# 2. Apply to Treasury
	_apply_payout_to_treasury(settlement, total_payout)
	
	# 3. Winter Consequences
	# Updated Task 1.3: Pass external_context to the demographic pipeline
	if season_name == SEASON_WINTER:
		var jarl = DynastyManager.get_current_jarl()
		_calculate_demographics(settlement, total_payout, jarl, external_context)
	
	var log_report = total_payout.duplicate()
	log_report.erase("_messages") 
	
	if log_report.is_empty():
		Loggie.msg("Seasonal Payout: None").domain(LogDomains.ECONOMY).info()
	else:
		Loggie.msg("Seasonal Payout: %s" % log_report).domain(LogDomains.ECONOMY).info()
	
	EventBus.treasury_updated.emit(settlement.treasury)
	return total_payout

func _apply_payout_to_treasury(settlement: SettlementData, payout: Dictionary) -> void:
	for res in payout:
		if res == "_messages": continue 
		
		var key = res.to_lower()
		var amount = payout[res]
		
		var cap = get_resource_cap(key)
		var current = settlement.treasury.get(key, 0)
		var space_left = cap - current
		var amount_to_add = clampi(amount, 0, max(0, space_left))
		
		if amount_to_add < amount:
			Loggie.msg("Storage Cap Reached! Wasted %d %s." % [amount - amount_to_add, key]).domain(LogDomains.ECONOMY).warn()
		
		if settlement.treasury.has(key):
			settlement.treasury[key] += amount_to_add
		else:
			settlement.treasury[key] = amount_to_add

func _calculate_demographics(settlement: SettlementData, payout_report: Dictionary, jarl: Resource, context: Dictionary = {}) -> void:
	var pop = settlement.population_peasants
	var current_food = settlement.treasury.get("food", 0)
	var total_food_available = current_food 
	
	# Rely on apply_winter_consumption to deduct food.
	# This function ONLY checks if we have enough surplus for bonuses/growth.
	var food_required_for_growth = pop * WINTER_FOOD_BASE * 2 
	
	var msg_list: Array = payout_report["_messages"]
	
	# --- Task 2.1: Sickness Mortality (Applied BEFORE Growth) ---
	if settlement.sick_population > 0:
		# Use modifier from context if available, else default to 10% mortality for sick pop
		var mortality_rate = context.get("sickness_mortality_rate", 0.10)
		var sick_deaths = int(settlement.sick_population * mortality_rate)
		
		if sick_deaths > 0:
			pop = max(0, pop - sick_deaths)
			settlement.sick_population = max(0, settlement.sick_population - sick_deaths)
			msg_list.append("[color=red]SICKNESS: %d peasants died from illness.[/color]" % sick_deaths)

	# --- Task 2.2: Rationing & Growth Calculation ---
	var growth_rate = BASE_GROWTH_RATE
	var event_msg = ""
	
	var rationing = settlement.rationing_policy
	var is_starving = total_food_available <= 0
	
	# Rationing Override Logic
	if rationing == SettlementData.RationingPolicy.NONE:
		# Artificial Starvation: Even if we have food, we aren't eating it.
		is_starving = true
		event_msg = "[color=red]RATIONING (NONE): Severe Malnutrition![/color]"
	elif rationing == SettlementData.RationingPolicy.HALF:
		# Malnutrition: Reduces growth potential, but doesn't trigger full starvation death unless food is actually gone.
		growth_rate -= 0.05 # Flat penalty to growth
		msg_list.append("[color=orange]RATIONING (HALF): Growth Stunted.[/color]")

	if is_starving:
		# If apply_winter_consumption left us at 0, OR Rationing is NONE.
		growth_rate = STARVATION_PENALTY
		if event_msg == "": event_msg = "[color=red]FAMINE: Food shortage caused deaths![/color]"
	else:
		# We survived. Do we flourish?
		# Only flourish if we aren't on HALF rations
		if total_food_available > food_required_for_growth and rationing == SettlementData.RationingPolicy.NORMAL: 
			growth_rate += FERTILITY_BONUS
		if jarl and jarl.has_trait(TRAIT_FERTILE): 
			growth_rate += FERTILITY_BONUS
			
	# Apply final growth to the survivors
	var net_change = int(pop * growth_rate)
	
	# Ensure at least 1 person grows if positive rate, unless capped
	if growth_rate > 0 and net_change == 0 and pop > 0: net_change = 1
	
	settlement.population_peasants = max(0, pop + net_change)
	
	var pop_change_str = ""
	if net_change > 0: pop_change_str = "+%d Peasants" % net_change
	elif net_change < 0: pop_change_str = "%d Peasants (Died)" % net_change
	else: pop_change_str = "No population change"
	
	if event_msg != "": msg_list.append(event_msg)
	payout_report["population_growth"] = pop_change_str
	
	# --- Land Capacity & Unrest Logic (Preserved) ---
	var land_capacity = _calculate_total_land_capacity(settlement)
	if settlement.population_peasants > land_capacity:
		var excess_men = settlement.population_peasants - land_capacity
		var unrest_gain = excess_men * UNREST_PER_LANDLESS_PEASANT
		settlement.unrest = min(100, settlement.unrest + unrest_gain)
		msg_list.append("[color=orange]LAND HUNGER: +%d Unrest![/color]" % unrest_gain)
	elif settlement.unrest > 0:
		settlement.unrest = max(0, settlement.unrest - 5)
		msg_list.append("[color=green]Stability returns (Unrest -5)[/color]")
func _calculate_total_land_capacity(settlement: SettlementData) -> int:
	var total_cap = BASE_LAND_CAPACITY
	for entry in settlement.placed_buildings:
		var data = load(entry["resource_path"]) as BuildingData
		if data:
			total_cap += data.arable_land_capacity
	return total_cap

# --- DELEGATED FUNCTIONS ---
func get_population_census() -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: 
		return {
			"peasants": {"total": 0, "idle": 0},
			"thralls": {"total": 0, "idle": 0},
			"warbands": 0
		}
	
	var assigned_peasants = 0
	var assigned_thralls = 0
	
	for b_entry in settlement.placed_buildings:
		assigned_peasants += b_entry.get("peasant_count", 0)
		assigned_thralls += b_entry.get("thrall_count", 0)
		
	var total_peasants = settlement.population_peasants
	var total_thralls = settlement.population_thralls
	var warband_count = settlement.warbands.size()
	
	return {
		"peasants": {
			"total": total_peasants,
			"idle": max(0, total_peasants - assigned_peasants)
		},
		"thralls": {
			"total": total_thralls,
			"idle": max(0, total_thralls - assigned_thralls)
		},
		"warbands": warband_count
	}

func can_afford(cost: Dictionary) -> bool:
	var settlement = SettlementManager.current_settlement
	if not settlement: return false
	
	for res in cost:
		var key = res.to_lower()
		if not settlement.treasury.has(key) or settlement.treasury[key] < cost[res]:
			return false
	return true

func deposit_resources(loot: Dictionary) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	Loggie.msg("Depositing resources: %s" % loot).domain(LogDomains.ECONOMY).info()
	
	for res in loot:
		var amount = loot[res]
		var key = res.to_lower()
		
		if key == "population" or key == "thralls":
			settlement.population_thralls += amount
		else:
			var cap = get_resource_cap(key)
			var current = settlement.treasury.get(key, 0)
			var space = cap - current
			var to_add = min(amount, max(0, space))
			
			if settlement.treasury.has(key):
				settlement.treasury[key] += to_add
			else:
				settlement.treasury[key] = to_add
			
	EventBus.treasury_updated.emit(settlement.treasury)

func attempt_purchase(item_cost: Dictionary) -> bool:
	var settlement = SettlementManager.current_settlement
	if not settlement: return false
	
	for res in item_cost:
		var key = res.to_lower()
		if not settlement.treasury.has(key) or settlement.treasury[key] < item_cost[res]:
			EventBus.purchase_failed.emit("Insufficient %s" % res.capitalize())
			Loggie.msg("Purchase failed (Insufficient %s). Cost: %s" % [res, item_cost]).domain(LogDomains.ECONOMY).debug()
			return false
			
	for res in item_cost:
		var key = res.to_lower()
		settlement.treasury[key] -= item_cost[res]
		
	Loggie.msg("Purchase successful: %s" % item_cost).domain(LogDomains.ECONOMY).info()
	EventBus.treasury_updated.emit(settlement.treasury)
	return true

func apply_raid_damages() -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	var report = { "gold_lost": 0, "wood_lost": 0, "buildings_damaged": 0, "buildings_destroyed": 0 }
	var loss_ratio = randf_range(RAID_LOSS_RATIO_MIN, RAID_LOSS_RATIO_MAX)
	
	var g_loss = int(settlement.treasury.get("gold", 0) * loss_ratio)
	settlement.treasury["gold"] -= g_loss
	report["gold_lost"] = g_loss
	
	var w_loss = int(settlement.treasury.get("wood", 0) * loss_ratio)
	settlement.treasury["wood"] -= w_loss
	report["wood_lost"] = w_loss
	
	var indices_to_remove: Array[int] = []
	for i in range(settlement.pending_construction_buildings.size()):
		var entry = settlement.pending_construction_buildings[i]
		if entry.get("progress", 0) > 0:
			var dmg = randi_range(RAID_BUILDING_DMG_MIN, RAID_BUILDING_DMG_MAX)
			entry["progress"] -= dmg
			report["buildings_damaged"] += 1
			if entry["progress"] <= 0:
				indices_to_remove.append(i)
				report["buildings_destroyed"] += 1
	
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for i in indices_to_remove: settlement.pending_construction_buildings.remove_at(i)
	
	settlement.has_stability_debuff = true
	
	Loggie.msg("Raid damages applied: %s" % report).domain(LogDomains.ECONOMY).warn()
	EventBus.treasury_updated.emit(settlement.treasury)
	return report

func add_resources(resources: Dictionary) -> void:
	deposit_resources(resources)
	
# --- ALLOCATION & PROJECTION API ---

func draft_peasants_to_raiders(count: int, template: UnitData) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	if count <= 0: return

	var available = settlement.population_peasants
	var actual_draft = min(available, count)
	
	if actual_draft < count:
		Loggie.msg("EconomyManager: Draft request reduced (Req: %d, Avail: %d)" % [count, available]).domain(LogDomains.ECONOMY).warn()
	
	settlement.population_peasants -= actual_draft
	
	var new_warbands: Array[WarbandData] = []
	var remaining = actual_draft
	
	while remaining > 0:
		var batch_size = min(remaining, 10) 
		var bondi_band = WarbandData.new(template)
		bondi_band.is_bondi = true
		bondi_band.current_manpower = batch_size 
		bondi_band.custom_name = "The Bondi" 
		
		new_warbands.append(bondi_band)
		remaining -= batch_size
		
	if RaidManager:
		RaidManager.outbound_raid_force.append_array(new_warbands)
		
	Loggie.msg("EconomyManager: Drafted %d Peasants into %d Warbands" % [actual_draft, new_warbands.size()]).domain(LogDomains.ECONOMY).info()
	EventBus.population_changed.emit()

func calculate_hypothetical_yields(worker_counts: Dictionary) -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	var yields = {"food": 0, "wood": 0}
	
	var food_workers = worker_counts.get("food", 0)
	var wood_workers = worker_counts.get("wood", 0)
	
	for entry in settlement.placed_buildings:
		if "resource_path" in entry:
			var b_data = load(entry["resource_path"])
			if b_data is EconomicBuildingData:
				var cap = b_data.peasant_capacity
				var type = b_data.resource_type 
				
				if type == "food" and food_workers > 0:
					var assigned = min(food_workers, cap)
					yields["food"] += assigned * b_data.base_passive_output
					food_workers -= assigned
					
				elif type == "wood" and wood_workers > 0:
					var assigned = min(wood_workers, cap)
					yields["wood"] += assigned * b_data.base_passive_output
					wood_workers -= assigned
					
	return yields

# --- RAID OUTCOME API ---

func process_raid_return(result: RaidResultData) -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}

	var outcome = result.outcome
	var grade = result.victory_grade
	
	var raw_gold = result.loot.get(GameResources.GOLD, 0)
	var total_wergild = 0
	var dead_count = 0
	
	for u_data in result.casualties:
		if u_data:
			total_wergild += u_data.wergild_cost
			dead_count += 1
			
	var net_gold = max(0, raw_gold - total_wergild)
	
	var xp_gain = _calculate_raid_xp(outcome, grade)
	var warbands_to_remove: Array[WarbandData] = []
	
	for warband in settlement.warbands:
		if warband.is_bondi or warband.is_seasonal:
			if warband.is_bondi and warband.current_manpower > 0:
				settlement.population_peasants += warband.current_manpower
			
			warbands_to_remove.append(warband)
			
		if not warband.is_wounded and xp_gain > 0:
			warband.experience += xp_gain
			
	for wb in warbands_to_remove:
		settlement.warbands.erase(wb)
		
	Loggie.msg("EconomyManager: Disbanded %d seasonal warbands." % warbands_to_remove.size()).domain(LogDomains.ECONOMY).info()
	EventBus.population_changed.emit() 
	
	var final_report = result.loot.duplicate()
	
	if outcome == "victory":
		var difficulty = 1 
		if RaidManager: difficulty = RaidManager.current_raid_difficulty
		
		# REBALANCE: Lowered base gold (200 -> 50) and scaling (50 -> 25)
		# Goal: Prevent a single raid from funding an entire winter.
		var bonus = 50 + (difficulty * 25)
		if grade == "Decisive": bonus += 50 # Reduced from 100
		
		net_gold += bonus
		
		if not final_report.has("population") and not final_report.has(GameResources.POP_THRALL):
			var thralls = randi_range(2, 4) * difficulty
			final_report["population"] = thralls 
			 
		_update_jarl_stats(grade)
		
	final_report[GameResources.GOLD] = net_gold
	if result.renown_earned != 0:
		final_report["renown"] = result.renown_earned
		
	deposit_resources(final_report)
	
	return {
		"outcome": outcome,
		"grade": grade,
		"net_gold": net_gold,
		"wergild_paid": total_wergild,
		"dead_count": dead_count,
		"loot_summary": final_report
	}

func _calculate_raid_xp(outcome: String, grade: String) -> int:
	var xp = 0
	if outcome == "victory": 
		xp = 50
		if grade == "Decisive": xp = 75
		elif grade == "Pyrrhic": xp = 25
	elif outcome == "retreat": 
		xp = 20
		
	var xp_bonus = DynastyManager.active_year_stats.get("mod_raid_xp", 0.0)
	xp = int(xp * (1.0 + xp_bonus))
		
	return xp

func _update_jarl_stats(grade: String) -> void:
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		jarl.offensive_wins += 1
		jarl.battles_won += 1
		jarl.successful_raids += 1
		if jarl.has_trait("Warlord") and grade == "Decisive":
			jarl.current_authority += 1
		DynastyManager.jarl_stats_updated.emit(jarl)
		
# --- CONSTRUCTION API ---

func advance_construction_progress() -> Array[Dictionary]:
	var settlement = SettlementManager.current_settlement
	if not settlement: return []
	
	var completed_buildings: Array[Dictionary] = []
	var indices_to_remove: Array[int] = []
	
	for i in range(settlement.pending_construction_buildings.size()):
		var entry = settlement.pending_construction_buildings[i]
		
		var workers = entry.get("peasant_count", 0)
		if workers <= 0: continue
		
		var b_path = entry.get("resource_path", "")
		if b_path == "": continue
		
		var b_data = load(b_path) as BuildingData
		if not b_data: continue
		
		var effort_required = 100 
		if "construction_effort_required" in b_data:
			effort_required = b_data.construction_effort_required
			
		var progress_gain = workers * BUILDER_EFFICIENCY
		var current_progress = entry.get("progress", 0)
		var new_progress = current_progress + progress_gain
		
		entry["progress"] = new_progress
		
		if new_progress >= effort_required:
			completed_buildings.append(entry)
			indices_to_remove.append(i)
	
	indices_to_remove.sort()
	indices_to_remove.reverse()
	
	for i in indices_to_remove:
		settlement.pending_construction_buildings.remove_at(i)
		
	if not completed_buildings.is_empty():
		Loggie.msg("EconomyManager: %d buildings completed construction." % completed_buildings.size()).domain(LogDomains.ECONOMY).info()
		
	return completed_buildings

## TODO: AUTUMN LEDGER IMPLEMENTATION (See: https://docs.google.com/document/d/1hPcGKTZ7utKlkwq4-laimI88i7LfDC3eBhSOqZXQmKE/edit?tab=t.0)
## 1. Create FinancialSnapshot Resource (class_name FinancialSnapshot)
## 2. Capture treasury state on Summer transition
## 3. Categorize transactions (PLAYER_ACTION, RAID_LOOT, UPKEEP)
## 4. Calculate: Start + Gains - (Spent + Upkeep)
## 5. Emit seasonal_ledger_finalized via EventBus


## TODO: STORAGE & POPULATION CAPS
## 1. Implement get_max_capacity(resource_type: String) -> int
## 2. Clamp deposit_resources() results to capacity
## 3. Add 'is_at_pop_cap(unit_type)' check to recruitment logic
## 4. Emit EventBus.resource_capped when overflow occurs
## 5. Sync TopBar UI to show actual [Current / Max]
