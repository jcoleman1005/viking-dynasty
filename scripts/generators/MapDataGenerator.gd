#res://scripts/generators/MapDataGenerator.gd
class_name MapDataGenerator
extends RefCounted

# --- Historical Names List ---
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

# --- Building Resources ---
const B_FARM = "res://data/buildings/generated/Eco_Farm.tres"
const B_MARKET = "res://data/buildings/generated/Eco_Market.tres"
const B_RELIC = "res://data/buildings/generated/Eco_Reliquary.tres"
const B_HALL = "res://data/buildings/GreatHall.tres"
const B_WALL = "res://data/buildings/Bldg_Wall.tres"

# --- Generation Logic ---

static func generate_region_data(tier: int, fixed_name: String = "") -> WorldRegionData:
	var data = WorldRegionData.new()
	
	if fixed_name != "":
		data.display_name = fixed_name
	else:
		data.display_name = _generate_name()
		
	data.region_type_tag = "Province"
	
	# Difficulty Logic
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
	return REGION_NAMES.pick_random()

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

# =========================================================
# === PROCEDURAL SETTLEMENT GENERATION (GRID AWARE) ===
# =========================================================

static func _generate_procedural_settlement(type: String, difficulty: float) -> SettlementData:
	var s = SettlementData.new()
	s.map_seed = randi() 
	s.placed_buildings.clear()
	s.warbands.clear()
	
	# 1. Generate a consistent Seed for this map
	# This ensures TerrainGenerator creates the same land every time we load this specific RaidTarget
	
	
	# 2. Setup Economy (Loot)
	match type:
		"Farmstead": s.treasury = {"food": 500, "wood": 100, "gold": 20}
		"Monastery": s.treasury = {"gold": 400, "food": 50, "wood": 0}
		"Trading Post": s.treasury = {"gold": 250, "wood": 250, "food": 100}
		_: s.treasury = {"gold": 100, "wood": 100, "food": 100}
			
	# 3. Smart Placement System
	# We use a Dictionary to track occupied tiles: { Vector2i: true }
	var occupied_grid = {}
	
	# Determine Layout Center (Safe Zone for Terrain)
	# Assuming 60x60 grid, center is 30,30. We shift slightly up (20) for Isometric view balance.
	var map_center = Vector2i(30, 20)
	
	# --- STEP A: Place Great Hall (Always Center) ---
	var hall_path = B_HALL
	if type == "Monastery": hall_path = B_RELIC # Monasteries have Reliquaries as their "Hall"
	
	_try_place_building(s, occupied_grid, hall_path, map_center)
	
	# --- STEP B: Place Support Buildings ---
	var building_count = int(3 * difficulty)
	var primary_path = B_FARM
	if type == "Monastery": primary_path = B_RELIC
	elif type == "Trading Post" or type == "Village": primary_path = B_MARKET
	
	for i in range(building_count):
		# Pick a random building type based on the theme
		var path = primary_path
		if randf() < 0.3: path = B_FARM # Mixed economy
		
		# Find a valid spot spiraling out from center
		# We try 10 times to find a spot for this specific building
		for attempt in range(10):
			var radius = randi_range(4, 12) # Keep within 4-12 tiles of center (Safe Land)
			var angle = randf() * TAU
			var offset = Vector2(cos(angle), sin(angle)) * radius
			var target_pos = map_center + Vector2i(round(offset.x), round(offset.y))
			
			if _try_place_building(s, occupied_grid, path, target_pos):
				break # Success, move to next building
	
	# --- STEP C: Garrison ---
	_scale_garrison(s, difficulty)
	
	return s

## Attempts to place a building at the target grid position.
## Returns true if successful (space was empty), false if blocked.
static func _try_place_building(settlement: SettlementData, occupied: Dictionary, res_path: String, pos: Vector2i) -> bool:
	# 1. Load Data to check Size
	if not ResourceLoader.exists(res_path): 
		return false
		
	var b_data = load(res_path) as BuildingData
	if not b_data: return false
	
	var width = b_data.grid_size.x
	var height = b_data.grid_size.y
	
	# 2. Check Overlap
	# We buffer by 1 extra tile to leave walking space between buildings
	var buffer = 1 
	
	for x in range(-buffer, width + buffer):
		for y in range(-buffer, height + buffer):
			var check_pos = pos + Vector2i(x, y)
			
			# Check Bounds (Safety against map edge)
			if check_pos.x < 2 or check_pos.x > 58 or check_pos.y < 2 or check_pos.y > 58:
				return false
				
			# Check Occupancy
			# Note: We strictly forbid overlap on the building footprint (0 to width),
			# but the buffer is just a "preference". For this simple generator, 
			# we treat the buffer as hard occupancy to prevent clutter.
			if occupied.has(check_pos):
				return false
	
	# 3. Place Logic
	# If we got here, the space is clear.
	settlement.placed_buildings.append({
		"resource_path": res_path,
		"grid_position": pos
	})
	
	# 4. Mark Occupied
	for x in range(width):
		for y in range(height):
			var mark_pos = pos + Vector2i(x, y)
			occupied[mark_pos] = true
			
	return true

# =========================================================
# === HELPERS ===
# =========================================================

static func _clone_settlement_data(original: SettlementData) -> SettlementData:
	var clone = SettlementData.new()
	clone.treasury = original.treasury.duplicate()
	clone.map_seed = original.map_seed # Preserve seed!
	
	clone.placed_buildings.clear()
	for b in original.placed_buildings:
		clone.placed_buildings.append(b.duplicate())
		
	clone.pending_construction_buildings.clear()
	for p in original.pending_construction_buildings:
		clone.pending_construction_buildings.append(p.duplicate())
		
	clone.warbands.clear() 
	clone.population_peasants = original.population_peasants
	clone.population_thralls = original.population_thralls
	
	return clone

static func _scale_garrison(settlement: SettlementData, multiplier: float) -> void:
	if not settlement: return
	
	if settlement.warbands.is_empty():
		var possible_paths = [
			"res://data/units/EnemyVikingRaider_Data.tres",
			"res://data/units/Unit_Bondi.tres",
			"res://data/units/Unit_Drengr.tres"
		]
		
		var unit_data: UnitData = null
		for path in possible_paths:
			if ResourceLoader.exists(path):
				unit_data = load(path)
				break
		
		if unit_data:
			var count = int(3 * multiplier)
			count = max(1, count) 
			
			for i in range(count):
				var wb = WarbandData.new(unit_data)
				wb.custom_name = "Defenders %d" % (i + 1)
				settlement.warbands.append(wb)
				
			print("MapGenerator: Assigned %d squads of %s." % [count, unit_data.display_name])
		else:
			printerr("CRITICAL: MapDataGenerator could not find ANY unit files!")
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
