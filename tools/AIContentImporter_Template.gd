#res://tools/AIContentImporter_Template.gd
# res://tools/ContentImporter.gd
@tool
extends EditorScript

# --- INSTRUCTIONS ---
# 1. Ask the AI to generate content using the format in 'RAW_DATA'.Example:
#	"Give me the output as a JSON-style array of dictionaries compatible with my Godot importer. 
#	Format: {"type": "unit", "file_name": "Unique_File_Name", "display_name": "In Game Name", "stats": {"hp": int, "dmg": int, "speed": float}, "cost": {"gold": int}}
# 2. Paste the AI's output into the 'RAW_DATA' variable below.
# 3. Run this script (File > Run or Ctrl+Shift+X).
# 4. The .tres files will appear in the target folder.

const SAVE_DIR_UNITS = "res://data/units/generated/"
const SAVE_DIR_BUILDINGS = "res://data/buildings/generated/"

# PASTE AI OUTPUT HERE
var RAW_DATA = [
	{
		"type": "unit",
		"file_name": "Enemy_Berserker",
		"display_name": "Frenzied Berserker",
		"stats": { "hp": 80, "dmg": 25, "speed": 120.0 },
		"cost": { "gold": 50, "food": 50 }
	},
	{
		"type": "building",
		"file_name": "Eco_Fishery",
		"display_name": "Fisherman's Hut",
		"stats": { "hp": 150, "construction_effort": 120 },
		"cost": { "wood": 100 }
	}
]

func _run():
	# Ensure directories exist
	_ensure_dir(SAVE_DIR_UNITS)
	_ensure_dir(SAVE_DIR_BUILDINGS)
	
	var count = 0
	
	for entry in RAW_DATA:
		var res: Resource
		var path: String
		
		if entry["type"] == "unit":
			res = _create_unit(entry)
			path = SAVE_DIR_UNITS + entry["file_name"] + ".tres"
		elif entry["type"] == "building":
			res = _create_building(entry)
			path = SAVE_DIR_BUILDINGS + entry["file_name"] + ".tres"
			
		if res:
			var error = ResourceSaver.save(res, path)
			if error == OK:
				print("✅ Generated: %s" % path)
				count += 1
			else:
				print("❌ Failed to save: %s" % path)
	
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
	
	# Assign default scenes (You can change these later in Inspector)
	u.scene_to_spawn = load("res://scenes/units/EnemyVikingRaider.tscn")
	
	return u

func _create_building(data: Dictionary) -> BuildingData:
	# Default to Economic, can be changed
	var b = EconomicBuildingData.new() 
	b.display_name = data.get("display_name", "Unnamed")
	b.build_cost = data.get("cost", {})
	
	var stats = data.get("stats", {})
	b.max_health = stats.get("hp", 200)
	b.construction_effort_required = stats.get("construction_effort", 100)
	
	# Assign default scenes
	b.scene_to_spawn = load("res://scenes/buildings/Base_Building.tscn")
	
	return b

func _ensure_dir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
