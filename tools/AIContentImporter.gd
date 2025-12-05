# res://tools/AIContentImporter.gd
@tool
extends EditorScript

# --- INSTRUCTIONS ---
# 1. Ask the AI to generate content.
# 2. Use "sub_folder" to organize files (e.g., "player", "enemy", "bosses").
#
# Format: 
#   {
#       "type": "unit", 
#       "sub_folder": "player",  <-- NEW FIELD
#       "file_name": "Unit_Huscarl", 
#       "display_name": "Huscarl", 
#       ...
#   }

const BASE_DIR_UNITS = "res://data/units/"
const BASE_DIR_BUILDINGS = "res://data/buildings/"

# PASTE AI OUTPUT HERE
var RAW_DATA = [
	{
		"type": "building",
		"file_name": "Eco_Farm",
		"display_name": "Farmstead",
		"description": "A cluster of crops and livestock. Yields FOOD when raided.",
		"resource_type": "food", # Used by EconomicBuildingData
		"base_passive_output": 100, # Base loot amount
		"cost": { "wood": 50 },
		"stats": { "hp": 50, "construction_effort": 50 }
	},
	{
		"type": "building",
		"file_name": "Eco_Market",
		"display_name": "Trade Stall",
		"description": "A merchant's stall. Yields GOLD and GOODS when raided.",
		"resource_type": "gold",
		"base_passive_output": 75,
		"cost": { "wood": 100 },
		"stats": { "hp": 80, "construction_effort": 80 }
	},
	{
		"type": "building",
		"file_name": "Eco_Reliquary",
		"display_name": "Reliquary",
		"description": "A holy shrine containing silver and relics. Yields HIGH GOLD.",
		"resource_type": "gold",
		"base_passive_output": 150,
		"cost": { "stone": 100, "gold": 100 },
		"stats": { "hp": 60, "construction_effort": 120 }
	}
]

func _run():
	var count = 0
	
	for entry in RAW_DATA:
		var res: Resource
		var base_path = ""
		var sub_folder = entry.get("sub_folder", "generated") # Default to 'generated' if missing
		
		if entry["type"] == "unit":
			res = _create_unit(entry)
			base_path = BASE_DIR_UNITS
		elif entry["type"] == "building":
			res = _create_building(entry)
			base_path = BASE_DIR_BUILDINGS
			
		if res and base_path != "":
			# Construct full path with subfolder
			var target_dir = base_path.path_join(sub_folder)
			_ensure_dir(target_dir)
			
			var full_path = target_dir.path_join(entry["file_name"] + ".tres")
			
			var error = ResourceSaver.save(res, full_path)
			if error == OK:
				print("✅ Generated: %s" % full_path)
				count += 1
			else:
				print("❌ Failed to save: %s" % full_path)
	
	print("--- Import Complete: %d files created ---" % count)
	EditorInterface.get_resource_filesystem().scan()

func _create_unit(data: Dictionary) -> UnitData:
	var u = UnitData.new()
	u.display_name = data.get("display_name", "Unnamed")
	u.spawn_cost = data.get("cost", {})
	
	var stats = data.get("stats", {})
	u.max_health = stats.get("hp", 50)
	u.attack_damage = stats.get("dmg", 10)
	u.move_speed = stats.get("speed", 100.0)
	
	# Assign default scenes
	u.scene_to_spawn = load("res://scenes/units/PlayerVikingRaider.tscn")
	
	return u

func _create_building(data: Dictionary) -> BuildingData:
	# Default to Economic, can be changed
	var b = EconomicBuildingData.new() 
	b.display_name = data.get("display_name", "Unnamed")
	b.description = data.get("description", "No description provided.")
	b.build_cost = data.get("cost", {})
	
	var stats = data.get("stats", {})
	b.max_health = stats.get("hp", 200)
	b.construction_effort_required = stats.get("construction_effort", 100)
	
	# --- NEW: Import Fleet Capacity ---
	if data.has("fleet_capacity"):
		b.fleet_capacity_bonus = data["fleet_capacity"]
	# ----------------------------------
	
	# Assign default scenes
	# If you have a specific Naust scene, you can change this line manually later
	# or add logic here to pick based on name.
	b.scene_to_spawn = load("res://scenes/buildings/Base_Building.tscn")
	b.is_player_buildable = true 
	
	return b
func _ensure_dir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
