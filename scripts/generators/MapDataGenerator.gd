# res://scripts/generators/MapDataGenerator.gd
class_name MapDataGenerator
extends RefCounted

# --- Name Generation ---
const REGION_PREFIXES = ["North", "South", "West", "East", "High", "Low", "Old", "New", "Great", "Little"]
const REGION_NAMES = ["Vinland", "Frankia", "Saxony", "Wessex", "Mercia", "Northumbria", "Alba", "Ireland", "Rus", "Novgorod", "Agdir", "Rogaland"]
const REGION_SUFFIXES = ["Hold", "Reach", "Lands", "Coast", "Valley", "Fjord", "Isle", "Haven", "March"]

# --- Templates ---
const LAYOUT_MONASTERY = "res://data/settlements/monastery_base.tres"
const LAYOUT_VILLAGE = "res://data/settlements/economic_base.tres" # Placeholder
const LAYOUT_FORTRESS = "res://data/settlements/fortress_layout.tres"

# --- Generation Logic ---

static func generate_region_data(tier: int) -> WorldRegionData:
	var data = WorldRegionData.new()
	
	# 1. Identity
	data.display_name = _generate_name()
	data.region_type_tag = "Province"
	
	# 2. Difficulty Scaling
	var base_diff = 1.0 + (float(tier - 1) * 0.8)
	var variance = randf_range(0.0, 0.5)
	var final_difficulty = base_diff + variance
	
	# 3. Generate Targets
	var target_count = randi_range(1, 3)
	
	# --- FIX: Declare this BEFORE the loop ---
	var min_cost = 999 
	# ---------------------------------------
	
	for i in range(target_count):
		var target = _generate_target_for_tier(data.display_name, tier, final_difficulty)
		if target:
			data.raid_targets.append(target)
			# Check if this target is cheaper than the current minimum
			if target.raid_cost_authority < min_cost:
				min_cost = target.raid_cost_authority
	
	# 4. Set the region base cost (Safe check if loop failed)
	data.base_authority_cost = min_cost if min_cost != 999 else 1
	
	# 5. Income & Description
	data.yearly_income = {"gold": int(10 * final_difficulty), "food": int(20 * final_difficulty)}
	data.description = "A Tier %d region. Difficulty Rating: %.1f" % [tier, final_difficulty]
	
	return data

static func _generate_target_for_tier(region_name: String, tier: int, difficulty: float) -> RaidTargetData:
	var target = RaidTargetData.new()
	var layout_path = ""
	var type_name = ""
	
	# Biased RNG based on Tier
	var roll = randf()
	
	if tier == 1:
		# Mostly Monasteries/Villages
		if roll < 0.4: 
			type_name = "Monastery"
			layout_path = LAYOUT_MONASTERY
		else:
			type_name = "Village"
			layout_path = LAYOUT_VILLAGE
			
	elif tier == 2:
		# Mix
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
		# Mostly Hard Targets
		if roll < 0.2:
			type_name = "Rich Monastery"
			layout_path = LAYOUT_MONASTERY
		else:
			type_name = "Fortress"
			layout_path = LAYOUT_FORTRESS
	
	target.display_name = "%s %s" % [region_name, type_name]
	target.difficulty_rating = int(round(difficulty))
	target.raid_cost_authority = max(1, int(round(difficulty * 0.5)))
	
	# Load Layout Template
	if ResourceLoader.exists(layout_path):
		target.settlement_data = load(layout_path).duplicate(true)
		
		# Scale Garrison Size by Difficulty
		_scale_garrison(target.settlement_data, difficulty)
	
	return target

static func _scale_garrison(settlement: SettlementData, multiplier: float) -> void:
	if not settlement or not settlement.garrisoned_units: return
	
	for unit_path in settlement.garrisoned_units:
		var count = settlement.garrisoned_units[unit_path]
		settlement.garrisoned_units[unit_path] = int(count * multiplier)

static func _generate_name() -> String:
	return "%s %s" % [REGION_PREFIXES.pick_random(), REGION_NAMES.pick_random()]
