extends Node

# --- EFFICIENCY CONSTANTS ---
const BUILDER_EFFICIENCY: int = 6 
const GATHERER_EFFICIENCY: int = 10 
const BASE_GATHERING_CAPACITY: int = 2

# --- POPULATION CONSTANTS ---
const FOOD_PER_PERSON_PER_YEAR: int = 10
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

# --- STORAGE CONSTANTS ---
const BASE_STORAGE_CAPACITY: int = 200 
const BASE_GOLD_CAPACITY: int = 500

# --- RAID CONSTANTS ---
const RAID_LOSS_RATIO_MIN: float = 0.2
const RAID_LOSS_RATIO_MAX: float = 0.4
const RAID_BUILDING_DMG_MIN: int = 50
const RAID_BUILDING_DMG_MAX: int = 150

# --- PUBLIC QUERIES ---

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

## NEW: Centralized Winter Forecast Logic
## Returns anticipated demand for Food and Wood based on population.
func get_winter_forecast() -> Dictionary[String, int]:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {"food": 0, "wood": 0}
	
	var pop = settlement.population_peasants
	# Aligning with _calculate_demographics logic (FOOD_PER_PERSON_PER_YEAR)
	var food_demand = pop * FOOD_PER_PERSON_PER_YEAR
	var wood_demand = WINTER_WOOD_DEMAND
	
	return {
		"food": food_demand,
		"wood": wood_demand
	}

# --- TURN LOGIC (SEASONAL) ---

func calculate_seasonal_payout(season_name: String) -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	# Typed as Variant because it holds both ints (resources) and Array (messages)
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
	if season_name == SEASON_WINTER:
		var jarl = DynastyManager.get_current_jarl()
		_calculate_demographics(settlement, total_payout, jarl)
		# Note: Hunger logic handled by Orchestrator
	
	Loggie.msg("Seasonal Payout Calculated: %s" % total_payout).domain(LogDomains.ECONOMY).info()
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
		
		if settlement.treasury.has(key):
			settlement.treasury[key] += amount_to_add
		else:
			settlement.treasury[key] = amount_to_add

func _calculate_demographics(settlement: SettlementData, payout_report: Dictionary, jarl: JarlData) -> void:
	var pop = settlement.population_peasants
	var current_food = settlement.treasury.get("food", 0)
	var total_food_available = current_food 
	var food_required = pop * FOOD_PER_PERSON_PER_YEAR
	
	var growth_rate = BASE_GROWTH_RATE
	var event_msg = ""
	
	if total_food_available < food_required:
		growth_rate = STARVATION_PENALTY
		event_msg = "[color=red]FAMINE: Food shortage caused deaths![/color]"
		settlement.treasury["food"] = 0
	else:
		var food_consumed = food_required
		settlement.treasury["food"] -= food_consumed
		if total_food_available > (food_required * 1.5): growth_rate += FERTILITY_BONUS
		if jarl and jarl.has_trait(TRAIT_FERTILE): growth_rate += FERTILITY_BONUS
			
	var net_change = int(pop * growth_rate)
	if growth_rate > 0 and net_change == 0: net_change = 1
	settlement.population_peasants = max(0, pop + net_change)
	
	var pop_change_str = ""
	if net_change > 0: pop_change_str = "+%d Peasants" % net_change
	elif net_change < 0: pop_change_str = "%d Peasants (Died)" % net_change
	else: pop_change_str = "No population change"
	
	var msg_list: Array = payout_report["_messages"]
	if event_msg != "": msg_list.append(event_msg)
	payout_report["population_growth"] = pop_change_str
	
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
	# NOTE: Caller must save_settlement() if needed.

# Relaxed typing to accept generic Dictionaries from UI/Resources
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
