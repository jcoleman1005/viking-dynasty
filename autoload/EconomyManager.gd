# res://autoload/EconomyManager.gd
extends Node

# Constants moved from SettlementManager
const BUILDER_EFFICIENCY: int = 25
const GATHERER_EFFICIENCY: int = 10 
const BASE_GATHERING_CAPACITY: int = 2

func calculate_payout() -> Dictionary:
	# Dependency: Needs access to the data holder
	var settlement = SettlementManager.current_settlement
	if not settlement: return {}
	
	# Trigger construction progress (Labor logic remains in SettlementManager or moves here? 
	# For now, let's trigger it via SettlementManager to keep grid logic there)
	SettlementManager.process_construction_labor()
	
	var hunger_warnings = SettlementManager.process_warband_hunger()
	var total_payout: Dictionary = {}
	if not hunger_warnings.is_empty():
		total_payout["_messages"] = hunger_warnings

	var stewardship_bonus := 1.0
	var jarl = DynastyManager.get_current_jarl()
	if jarl:
		var skill = jarl.get_effective_skill("stewardship")
		stewardship_bonus = 1.0 + (skill - 10) * 0.05
		stewardship_bonus = max(0.5, stewardship_bonus)

	# Calculate Building Yields
	for entry in settlement.placed_buildings:
		var b_data = load(entry["resource_path"])
		if b_data is EconomicBuildingData:
			var type = b_data.resource_type
			if not total_payout.has(type): total_payout[type] = 0
			
			var p_count = entry.get("peasant_count", 0)
			var p_out = p_count * b_data.output_per_peasant
			
			var t_count = entry.get("thrall_count", 0)
			var t_out = t_count * b_data.output_per_thrall
			
			var production = int((p_out + t_out) * stewardship_bonus)
			total_payout[type] += production

	# Calculate Region Yields
	if jarl:
		for region_path in jarl.conquered_regions:
			var r_data = load(region_path)
			if r_data:
				for res in r_data.yearly_income:
					if not total_payout.has(res): total_payout[res] = 0
					total_payout[res] += int(r_data.yearly_income[res] * stewardship_bonus)

	# Apply Stability Debuff
	if jarl and settlement.has_stability_debuff:
		if total_payout.has(GameResources.GOLD): 
			total_payout[GameResources.GOLD] = int(total_payout[GameResources.GOLD] * 0.75)
		settlement.has_stability_debuff = false
		SettlementManager.save_settlement()

	return total_payout

func deposit_resources(loot: Dictionary) -> void:
	var settlement = SettlementManager.current_settlement
	if not settlement: return
	
	for resource_type in loot:
		if resource_type.begins_with("_"): continue
		
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
	
	# Building Damage logic involves grids/lists, but it fits "Damages".
	# We can keep the logic here or call back to SettlementManager.
	# For now, let's keep it here to centralize "Loss".
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
