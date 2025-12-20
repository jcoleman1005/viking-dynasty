# res://scripts/generators/MapDataGenerator.gd
class_name MapDataGenerator
extends RefCounted

# --- Historical Names List (Fallback) ---
const REGION_NAMES = [
	"Geatland", "Viken", "Swealand", "Halogaland", 
	"Denmark", "Kvenland", "Estland", "Courland", 
	"Samland", "Bjarmaland", "Wendland", "Saxony", 
	"Frankland", "Britland"
]

# --- Templates ---
const LAYOUT_MONASTERY = "res://data/settlements/monastery_base.tres"
const LAYOUT_VILLAGE = "res://data/settlements/economic_base.tres"
const LAYOUT_FORTRESS = "res://data/settlements/fortress_layout.tres"

# --- Generation Logic ---
const B_FARM = "res://data/buildings/generated/Eco_Farm.tres"
const B_MARKET = "res://data/buildings/generated/Eco_Market.tres"
const B_RELIC = "res://data/buildings/generated/Eco_Reliquary.tres"
const B_HALL = "res://data/buildings/GreatHall.tres"
const B_WALL = "res://data/buildings/Bldg_Wall.tres"

# --- MODIFIED: Added fixed_name parameter ---
static func generate_region_data(tier: int, fixed_name: String = "") -> WorldRegionData:
	var data = WorldRegionData.new()
	
	# 1. Name Logic
	if fixed_name != "":
		data.display_name = fixed_name
	else:
		data.display_name = _generate_name()
		
	data.region_type_tag = "Province"
	
	# 2. Difficulty Logic
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

static func _generate_name() -> String:
	# Removed Prefix logic. Just pick a valid historical name.
	return REGION_NAMES.pick_random()

# ... (Keep _generate_target_for_tier, _pick_type_by_tier, _generate_procedural_settlement, etc. exactly as they were) ...
static func _generate_target_for_tier(region_name: String, tier: int, difficulty: float) -> RaidTargetData:
	var target = RaidTargetData.new()
	var type = _pick_type_by_tier(tier)
	
	target.display_name = "%s %s" % [region_name, type]
	target.difficulty_rating = int(round(difficulty))
	target.raid_cost_authority = max(1, int(round(difficulty * 0.5)))
	target.settlement_data = _generate_procedural_settlement(type, difficulty)
	return target

static func _pick_type_by_tier(tier: int) -> String:
	var roll = randf()
	match tier:
		1: return "Farmstead" if roll < 0.6 else "Monastery"
		2: return "Village" if roll < 0.5 else "Trading Post"
		_: return "Fortress"

static func _generate_procedural_settlement(type: String, difficulty: float) -> SettlementData:
	var s = SettlementData.new()
	s.placed_buildings.clear()
	s.warbands.clear()
	
	# 1. Base Treasury (The "Storehouse" Loot)
	match type:
		"Farmstead":
			s.treasury = {"food": 500, "wood": 100, "gold": 20}
		"Monastery":
			s.treasury = {"gold": 400, "food": 50, "wood": 0}
		"Trading Post":
			s.treasury = {"gold": 250, "wood": 250, "food": 100}
		_:
			s.treasury = {"gold": 100, "wood": 100, "food": 100}
			
	# 2. Place Buildings (The "Destruction" Loot)
	# Always start with a Hall in the center (approx 30, 20 on a 60x40 grid)
	s.placed_buildings.append({ 
	"resource_path": B_HALL, 
	"grid_position": Vector2i(30, 10) 
})
	
	var building_count = int(3 * difficulty)
	var primary_bldg = B_FARM
	
	if type == "Monastery": primary_bldg = B_RELIC
	elif type == "Trading Post" or type == "Village": primary_bldg = B_MARKET
	
	# Scatter buildings around the hall
	for i in range(building_count):
		var offset_x = randi_range(-6, 6)
		var offset_y = randi_range(-6, 6)
		# Ensure we don't overwrite the hall (simple check)
		if abs(offset_x) < 3 and abs(offset_y) < 3: continue
		
		s.placed_buildings.append({
			"resource_path": primary_bldg,
			"grid_position": Vector2i(30 + offset_x, 20 + offset_y)
		})
		
	# 3. Scale Garrison
	_scale_garrison(s, difficulty)
	
	return s

static func _clone_settlement_data(original: SettlementData) -> SettlementData:
	var clone = SettlementData.new()
	
	# Deep copy safe properties
	clone.treasury = original.treasury.duplicate()
	
	# --- FIX: Use clear() + append for strict arrays ---
	# Do not assign [] directly, as Godot 4 treats that as a generic Array
	# which conflicts with Array[Dictionary]
	
	clone.placed_buildings.clear()
	for b in original.placed_buildings:
		clone.placed_buildings.append(b.duplicate())
		
	clone.pending_construction_buildings.clear()
	for p in original.pending_construction_buildings:
		clone.pending_construction_buildings.append(p.duplicate())
	# ---------------------------------------------------
		
	# Warbands start empty for new clones (to be scaled later)
	clone.warbands.clear() 
	
	clone.population_peasants = original.population_peasants
	clone.population_thralls = original.population_thralls
	
	return clone

static func _scale_garrison(settlement: SettlementData, multiplier: float) -> void:
	if not settlement: return
	
	if settlement.warbands.is_empty():
		# 1. Define a Priority List of units to spawn
		var possible_paths = [
			"res://data/units/EnemyVikingRaider_Data.tres", # Dedicated Enemy (Best)
			"res://data/units/Unit_Bondi.tres",             # Common Fallback
			"res://data/units/Unit_Drengr.tres"             # Elite Fallback
		]
		
		var unit_data: UnitData = null
		
		# 2. Find the first valid file
		for path in possible_paths:
			if ResourceLoader.exists(path):
				unit_data = load(path)
				break
		
		# 3. Spawn or Error
		if unit_data:
			var count = int(3 * multiplier)
			count = max(1, count) 
			
			for i in range(count):
				# Create the data container
				var wb = WarbandData.new(unit_data)
				wb.custom_name = "Defenders %d" % (i + 1)
				settlement.warbands.append(wb)
				
			print("MapGenerator: Assigned %d squads of %s to settlement." % [count, unit_data.display_name])
		else:
			printerr("CRITICAL: MapDataGenerator could not find ANY unit files to spawn defenders!")
			return

	var original_count = settlement.warbands.size()
	var target_count = int(original_count * multiplier)
	var needed = target_count - original_count
	if needed > 0:
		for i in range(needed):
			var source = settlement.warbands.pick_random()
			var new_wb = WarbandData.new(source.unit_type)
			new_wb.custom_name = source.custom_name + " (Reinforcements)"
			settlement.warbands.append(new_wb)
