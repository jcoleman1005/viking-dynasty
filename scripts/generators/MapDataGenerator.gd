# res://scripts/generators/MapDataGenerator.gd
class_name MapDataGenerator
extends RefCounted

# --- Name Generation ---
const REGION_PREFIXES = ["North", "South", "West", "East", "High", "Low", "Old", "New", "Great", "Little"]
const REGION_NAMES = ["Vinland", "Frankia", "Saxony", "Wessex", "Mercia", "Northumbria", "Alba", "Ireland", "Rus", "Novgorod", "Agdir", "Rogaland"]

# --- Templates ---
const LAYOUT_MONASTERY = "res://data/settlements/monastery_base.tres"
const LAYOUT_VILLAGE = "res://data/settlements/economic_base.tres"
const LAYOUT_FORTRESS = "res://data/settlements/fortress_layout.tres"

# --- Generation Logic ---

static func generate_region_data(tier: int) -> WorldRegionData:
	var data = WorldRegionData.new()
	data.display_name = _generate_name()
	data.region_type_tag = "Province"
	
	var base_diff = 1.0 + (float(tier - 1) * 0.8)
	var variance = randf_range(0.0, 0.5)
	var final_difficulty = base_diff + variance
	
	var target_count = randi_range(1, 3)
	var min_cost = 999 
	
	for i in range(target_count):
		var target = _generate_target_for_tier(data.display_name, tier, final_difficulty)
		if target:
			data.raid_targets.append(target)
			if target.raid_cost_authority < min_cost:
				min_cost = target.raid_cost_authority
	
	data.base_authority_cost = min_cost if min_cost != 999 else 1
	data.yearly_income = {"gold": int(10 * final_difficulty), "food": int(20 * final_difficulty)}
	data.description = "A Tier %d region.\nDifficulty Rating: %.1f" % [tier, final_difficulty]
	
	return data

static func _generate_target_for_tier(region_name: String, tier: int, difficulty: float) -> RaidTargetData:
	var target = RaidTargetData.new()
	var layout_path = ""
	var type_name = ""
	
	var roll = randf()
	if tier == 1:
		if roll < 0.4: 
			type_name = "Monastery"
			layout_path = LAYOUT_MONASTERY
		else:
			type_name = "Village"
			layout_path = LAYOUT_VILLAGE
	elif tier == 2:
		if roll < 0.3:
			type_name = "Monastery"
			layout_path = LAYOUT_MONASTERY
		elif roll < 0.7:
			type_name = "Trading Post"
			layout_path = LAYOUT_VILLAGE
		else:
			type_name = "Fortress"
			layout_path = LAYOUT_FORTRESS
	elif tier == 3:
		if roll < 0.2:
			type_name = "Rich Monastery"
			layout_path = LAYOUT_MONASTERY
		else:
			type_name = "Fortress"
			layout_path = LAYOUT_FORTRESS
	
	target.display_name = "%s %s" % [region_name, type_name]
	target.difficulty_rating = int(round(difficulty))
	target.raid_cost_authority = max(1, int(round(difficulty * 0.5)))
	
	# --- FIX: Use manual cloning instead of duplicate(true) ---
	# This prevents the Array[Object] crash by ignoring the old 'warbands' array
	if ResourceLoader.exists(layout_path):
		var original = load(layout_path)
		if original:
			target.settlement_data = _clone_settlement_data(original)
			_scale_garrison(target.settlement_data, difficulty)
	
	return target

static func _clone_settlement_data(original: SettlementData) -> SettlementData:
	var clone = SettlementData.new()
	
	# Deep copy safe properties
	clone.treasury = original.treasury.duplicate()
	
	# Copy Buildings
	clone.placed_buildings = []
	for b in original.placed_buildings:
		clone.placed_buildings.append(b.duplicate())
		
	clone.pending_construction_buildings = []
	for p in original.pending_construction_buildings:
		clone.pending_construction_buildings.append(p.duplicate())
		
	# --- CRITICAL FIX: Reset Warbands ---
	# We do NOT copy the old array. We start fresh.
	# The _scale_garrison function will populate this with new enemies.
	clone.warbands = [] 
	
	clone.max_garrison_bonus = original.max_garrison_bonus
	clone.population_total = original.population_total
	
	return clone

static func _scale_garrison(settlement: SettlementData, multiplier: float) -> void:
	if not settlement: return
	
	# 1. Fallback Generation
	if settlement.warbands.is_empty():
		var enemy_data_path = "res://data/units/EnemyVikingRaider_Data.tres"
		if ResourceLoader.exists(enemy_data_path):
			var unit_data = load(enemy_data_path) as UnitData
			var count = int(3 * multiplier)
			count = max(1, count) 
			
			for i in range(count):
				var wb = WarbandData.new(unit_data)
				wb.custom_name = "Defenders %d" % (i + 1)
				settlement.warbands.append(wb)
		return

	# 2. Scaling Logic (For future templates that HAVE warbands)
	var original_count = settlement.warbands.size()
	var target_count = int(original_count * multiplier)
	var needed = target_count - original_count
	
	if needed > 0:
		for i in range(needed):
			var source = settlement.warbands.pick_random()
			var new_wb = WarbandData.new(source.unit_type)
			new_wb.custom_name = source.custom_name + " (Reinforcements)"
			settlement.warbands.append(new_wb)

static func _generate_name() -> String:
	return "%s %s" % [REGION_PREFIXES.pick_random(), REGION_NAMES.pick_random()]
