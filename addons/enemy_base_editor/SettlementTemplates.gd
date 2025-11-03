@tool
extends RefCounted
class_name SettlementTemplates

# Pre-made settlement templates for quick creation
static func create_fortress_template() -> SettlementData:
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 1000, "wood": 500, "food": 300, "stone": 400}
	
	settlement.placed_buildings = [
		# Central Great Hall
		{"grid_position": Vector2i(30, 20), "resource_path": "res://data/buildings/Bldg_GreatHall.tres"},
		
		# Surrounding walls
		{"grid_position": Vector2i(29, 19), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(30, 19), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(31, 19), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(29, 21), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(30, 21), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(31, 21), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		
		# Corner towers
		{"grid_position": Vector2i(28, 18), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
		{"grid_position": Vector2i(32, 18), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
		{"grid_position": Vector2i(28, 22), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
		{"grid_position": Vector2i(32, 22), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
		
		# Economic buildings
		{"grid_position": Vector2i(27, 20), "resource_path": "res://data/buildings/LumberYard.tres"},
		{"grid_position": Vector2i(33, 20), "resource_path": "res://data/buildings/LumberYard.tres"},
	]
	
	settlement.garrisoned_units = {
		"res://data/units/VikingRaider.tres": 8,
		"res://data/units/Base_Unit.tres": 4
	}
	
	return settlement

static func create_monastery_template() -> SettlementData:
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 800, "wood": 300, "food": 600, "stone": 200}
	
	settlement.placed_buildings = [
		# Central chapel
		{"grid_position": Vector2i(25, 25), "resource_path": "res://data/buildings/Monastery_Chapel.tres"},
		
		# Library and scriptorium
		{"grid_position": Vector2i(23, 25), "resource_path": "res://data/buildings/Monastery_Library.tres"},
		{"grid_position": Vector2i(27, 25), "resource_path": "res://data/buildings/Monastery_Scriptorium.tres"},
		
		# Storage and resources
		{"grid_position": Vector2i(25, 23), "resource_path": "res://data/buildings/Monastery_Granary.tres"},
		
		# Defensive watchtower
		{"grid_position": Vector2i(25, 27), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
		
		# Outer walls for protection
		{"grid_position": Vector2i(22, 24), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(22, 25), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(22, 26), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(28, 24), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(28, 25), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(28, 26), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
	]
	
	settlement.garrisoned_units = {
		"res://data/units/Base_Unit.tres": 6
	}
	
	return settlement

static func create_village_template() -> SettlementData:
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 600, "wood": 400, "food": 200, "stone": 100}
	
	settlement.placed_buildings = [
		# Great Hall (village center)
		{"grid_position": Vector2i(15, 15), "resource_path": "res://data/buildings/Bldg_GreatHall.tres"},
		
		# Economic buildings scattered around
		{"grid_position": Vector2i(13, 15), "resource_path": "res://data/buildings/LumberYard.tres"},
		{"grid_position": Vector2i(17, 15), "resource_path": "res://data/buildings/LumberYard.tres"},
		{"grid_position": Vector2i(15, 13), "resource_path": "res://data/buildings/Monastery_Granary.tres"},
		{"grid_position": Vector2i(15, 17), "resource_path": "res://data/buildings/Monastery_Granary.tres"},
		
		# Minimal defensive structures
		{"grid_position": Vector2i(12, 12), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
		{"grid_position": Vector2i(18, 18), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
	]
	
	settlement.garrisoned_units = {
		"res://data/units/Base_Unit.tres": 3
	}
	
	return settlement

static func create_outpost_template() -> SettlementData:
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 300, "wood": 200, "food": 100, "stone": 150}
	
	settlement.placed_buildings = [
		# Single watchtower as main structure
		{"grid_position": Vector2i(10, 10), "resource_path": "res://data/buildings/Monastery_Watchtower.tres"},
		
		# Surrounding walls for basic protection
		{"grid_position": Vector2i(9, 9), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(10, 9), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(11, 9), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(9, 11), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(10, 11), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(11, 11), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		
		# Basic economic support
		{"grid_position": Vector2i(8, 10), "resource_path": "res://data/buildings/LumberYard.tres"},
	]
	
	settlement.garrisoned_units = {
		"res://data/units/Base_Unit.tres": 2
	}
	
	return settlement

static func get_template_names() -> Array[String]:
	return ["Fortress", "Monastery", "Village", "Outpost"]

static func create_template_by_name(template_name: String) -> SettlementData:
	match template_name:
		"Fortress":
			return create_fortress_template()
		"Monastery":
			return create_monastery_template()
		"Village":
			return create_village_template()
		"Outpost":
			return create_outpost_template()
		_:
			print("Unknown template: " + template_name)
			return SettlementData.new()

static func get_template_description(template_name: String) -> String:
	match template_name:
		"Fortress":
			return "A heavily fortified settlement with walls, towers, and strong defenses. Good for challenging raids."
		"Monastery":
			return "A peaceful religious settlement with chapel, library, and scriptorium. Moderate defenses."
		"Village":
			return "A basic settlement with economic buildings and minimal defenses. Good for early game raids."
		"Outpost":
			return "A small military outpost with basic walls and a watchtower. Minimal resources but strategic placement."
		_:
			return "No description available."
