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
		"file_name": "Bld_Langhus",
		"display_name": "Langhús",
		"description": "The fundamental unit of Norse society. A long turf dwelling where extended families live together. Increases max population.",
		"stats": {
			"hp": 800,
			"construction_effort": 150
		},
		"cost": {
			"wood": 100,
			"stone": 20
		}
	},
	{
		"type": "building",
		"file_name": "Bld_Skemma",
		"display_name": "Skemma",
		"description": "A raised timber storehouse used to keep supplies dry. Increases food storage capacity and reduces spoilage during winter.",
		"stats": {
			"hp": 300,
			"construction_effort": 80
		},
		"cost": {
			"wood": 60
		}
	},
	{
		"type": "building",
		"file_name": "Bld_Smidja",
		"display_name": "Smiðja",
		"description": "A hot, dark workshop for working bog iron. Unlocks the recruitment of armored Huscarls and weapon upgrades.",
		"stats": {
			"hp": 600,
			"construction_effort": 200
		},
		"cost": {
			"wood": 120,
			"stone": 50
		}
	},
	{
		"type": "building",
		"file_name": "Bld_Naust",
		"display_name": "Naust",
		"description": "A stone-walled slipway for protecting ships. Ships docked here in winter are safe from ice damage and are repaired.",
		"stats": {
			"hp": 1000,
			"construction_effort": 300
		},
		"cost": {
			"wood": 200,
			"stone": 50
		}
	},
	{
		"type": "building",
		"file_name": "Bld_Reykhus",
		"display_name": "Reykhús",
		"description": "A specialized smokehouse. Converts raw food into non-perishable provisions necessary for long sea voyages.",
		"stats": {
			"hp": 400,
			"construction_effort": 100
		},
		"cost": {
			"wood": 80,
			"stone": 40
		}
	},
	{
		"type": "building",
		"file_name": "Bld_Hof",
		"display_name": "Hof",
		"description": "A sacred wooden structure dedicated to the gods. Generates Piety passively and reduces local civil unrest.",
		"stats": {
			"hp": 500,
			"construction_effort": 250
		},
		"cost": {
			"wood": 150,
			"stone": 20,
			"gold": 50
		}
	},
	{
		"type": "building",
		"file_name": "Bld_Skali",
		"display_name": "Skáli",
		"description": "A grand feasting hall for the Jarl's court. Allows you to maintain a larger retinue of elite warriors through the winter.",
		"stats": {
			"hp": 2500,
			"construction_effort": 600
		},
		"cost": {
			"wood": 400,
			"stone": 100,
			"gold": 100
		}
	},
	{
		"type": "building",
		"file_name": "Eco_Torg",
		"display_name": "Torg",
		"description": "An open marketplace where craftsmen and merchants trade. Generates gold slowly, but increases the settlement's attractiveness to raiders.",
		"stats": {
			"hp": 300,
			"construction_effort": 100
		},
		"cost": {
			"wood": 50
		}
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
	var b = EconomicBuildingData.new() 
	b.display_name = data.get("display_name", "Unnamed")
	b.description = data.get("description", "No description provided.")
	b.build_cost = data.get("cost", {})
	
	var stats = data.get("stats", {})
	b.max_health = stats.get("hp", 200)
	b.construction_effort_required = stats.get("construction_effort", 100)
	
	# Assign default scenes
	b.scene_to_spawn = load("res://scenes/buildings/Base_Building.tscn")
	b.is_player_buildable = true # Assume player stuff is buildable
	
	return b

func _ensure_dir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
