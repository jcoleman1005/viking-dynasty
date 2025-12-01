# res://autoload/EconomyManager.gd
extends Node

const BUILDER_EFFICIENCY: int = 25
const GATHERER_EFFICIENCY: int = 10 
const BASE_GATHERING_CAPACITY: int = 2

# --- POPULATION CONSTANTS ---
const FOOD_PER_PERSON_PER_YEAR: int = 10
const BASE_GROWTH_RATE: float = 0.02 # 2% natural growth
const STARVATION_PENALTY: float = -0.15 # 15% death rate
const UNREST_PER_LANDLESS_PEASANT: int = 2

func calculate_payout() -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	# 1. Trigger Construction
	SettlementManager.process_construction_labor()
	
	# 2. Existing Hunger/Loyalty check (Warbands)
	var hunger_warnings = SettlementManager.process_warband_hunger()
	
	# --- FIX: Initialize dictionary with empty messages list ---
	var total_payout: Dictionary = {
		"_messages": []
	}
	# -----------------------------------------------------------
	
	if not hunger_warnings.is_empty():
		total_payout["_messages"].append_array(hunger_warnings)

	var stewardship_bonus := 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - 10) * 0.05
		stewardship_bonus = max(0.5, stewardship_bonus)

	# Calculate Yields
	for entry in settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type
			if not total_payout.has(type): total_payout[type] = 0
			var p_count = entry.get("peasant_count", 0)
			var p_out = p_count * b_data.base_passive_output
			var t_count = entry.get("thrall_count", 0)
			var t_out = t_count * b_data.output_per_thrall
			var production = int((p_out + t_out) * stewardship_bonus)
			total_payout[type] += production

	# Region Yields
	if jarl:
		for region_path in jarl.conquered_regions:
			var r_data = load(region_path)
			if r_data:
				for res in r_data.yearly_income:
					if not total_payout.has(res): total_payout[res] = 0
					total_payout[res] += int(r_data.yearly_income[res] * stewardship_bonus)

	# --- NEW: POPULATION GROWTH & UNREST CALCULATION ---
	_calculate_demographics(settlement, total_payout, jarl)
	
	return total_payout

func _calculate_demographics(settlement: SettlementData, payout_report: Dictionary, jarl: JarlData) -> void:
	var pop = settlement.population_peasants
	var current_food = settlement.treasury.get(GameResources.FOOD, 0)
	var new_food = payout_report.get(GameResources.FOOD, 0)
	var total_food_available = current_food + new_food
	
	var food_required = pop * FOOD_PER_PERSON_PER_YEAR
	
	# 1. Food Gate Logic
	var growth_rate = BASE_GROWTH_RATE
	var event_msg = ""
	
	if total_food_available < food_required:
		# Starvation
		growth_rate = STARVATION_PENALTY
		event_msg = "[color=red]FAMINE: Food shortage caused deaths![/color]"
		# Consume all food
		settlement.treasury[GameResources.FOOD] = 0
		payout_report[GameResources.FOOD] = 0 # Net change is we used it all
	else:
		# Eat
		var food_consumed = food_required
		if payout_report.has(GameResources.FOOD):
			payout_report[GameResources.FOOD] -= food_consumed
		
		# Abundance check
		if total_food_available > (food_required * 1.5):
			growth_rate += 0.01
			
		# Jarl Trait check
		if jarl and jarl.has_trait("Fertile"):
			growth_rate += 0.01
			
	# 2. Apply Growth
	var net_change = int(pop * growth_rate)
	if growth_rate > 0 and net_change == 0: net_change = 1
	
	settlement.population_peasants = max(0, pop + net_change)
	
	# Add to report
	var pop_change_str = ""
	if net_change > 0: pop_change_str = "+%d Peasants" % net_change
	elif net_change < 0: pop_change_str = "%d Peasants (Died)" % net_change
	else: pop_change_str = "No population change"
	
	# Safe append (because we initialized _messages in calculate_payout)
	if event_msg != "": 
		payout_report["_messages"].append(event_msg)
	
	payout_report["population_growth"] = pop_change_str
	
	# 3. Land Hunger (Restless Youth)
	var land_capacity = _calculate_total_land_capacity(settlement)
	
	if settlement.population_peasants > land_capacity:
		var excess_men = settlement.population_peasants - land_capacity
		var unrest_gain = excess_men * UNREST_PER_LANDLESS_PEASANT
		settlement.unrest = min(100, settlement.unrest + unrest_gain)
		
		payout_report["_messages"].append(
			"[color=orange]LAND HUNGER: %d landless men cause +%d Unrest![/color]" % [excess_men, unrest_gain]
		)
	elif settlement.unrest > 0:
		settlement.unrest = max(0, settlement.unrest - 5)
		payout_report["_messages"].append("[color=green]Stability returns (Unrest -5)[/color]")

func _calculate_total_land_capacity(settlement: SettlementData) -> int:
	var total_cap = 5 # Base capacity (The Jarl's own land)
	
	for entry in settlement.placed_buildings:
		var data = load(entry["resource_path"]) as BuildingData
		if data:
			total_cap += data.arable_land_capacity
			
	return total_cap

# --- DELEGATED FUNCTIONS (Required for SettlementManager) ---

func deposit_resources(loot: Dictionary) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	for resource_type in loot:
		if resource_type.begins_with("_") or resource_type == "population_growth": continue
		
		var amount = loot[resource_type]
		
		if resource_type == "population" or resource_type == GameResources.POP_THRALL:
			settlement.population_thralls += amount
		elif settlement.treasury.has(resource_type):
			settlement.treasury[resource_type] += amount
		else:
			settlement.treasury[resource_type] = amount
			
	EventBus.treasury_updated.emit(settlement.treasury)
	SettlementManager.save_settlement()

func attempt_purchase(item_cost: Dictionary) -> bool:
	var settlement = SettlementManager.current_settlement
	if not settlement: return false
	
	# Validation
	for res in item_cost:
		if not settlement.treasury.has(res) or settlement.treasury[res] < item_cost[res]:
			var res_name = res.capitalize()
			EventBus.purchase_failed.emit("Insufficient %s" % res_name)
			return false
			
	# Deduction
	for res in item_cost:
		settlement.treasury[res] -= item_cost[res]
		
	EventBus.treasury_updated.emit(settlement.treasury)
	return true

func apply_raid_damages() -> Dictionary:
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	var report = { 
		"gold_lost": 0, 
		"wood_lost": 0, 
		"buildings_damaged": 0, 
		"buildings_destroyed": 0 
	}
	
	var loss_ratio = randf_range(0.2, 0.4)
	
	var g_loss = int(settlement.treasury.get(GameResources.GOLD, 0) * loss_ratio)
	settlement.treasury[GameResources.GOLD] -= g_loss
	report["gold_lost"] = g_loss
	
	var w_loss = int(settlement.treasury.get(GameResources.WOOD, 0) * loss_ratio)
	settlement.treasury[GameResources.WOOD] -= w_loss
	report["wood_lost"] = w_loss
	
	var indices_to_remove: Array[int] = []
	for i in range(settlement.pending_construction_buildings.size()):
		var entry = settlement.pending_construction_buildings[i]
		if entry.get("progress", 0) > 0:
			entry["progress"] -= randi_range(50, 150)
			report["buildings_damaged"] += 1
			if entry["progress"] <= 0:
				indices_to_remove.append(i)
				report["buildings_destroyed"] += 1
				
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for i in indices_to_remove: settlement.pending_construction_buildings.remove_at(i)
	
	settlement.has_stability_debuff = true
	SettlementManager.save_settlement()
	EventBus.treasury_updated.emit(settlement.treasury)
	return report
