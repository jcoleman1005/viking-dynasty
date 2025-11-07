# SettlementLayoutEditor.gd
# Tool to help create custom settlement layouts
@tool
extends EditorScript

# Define available buildings with their paths
const BUILDINGS = {
	"Great Hall": "res://data/buildings/GreatHall.tres",
	"Wall": "res://data/buildings/Bldg_Wall.tres", 
	"Lumber Yard": "res://data/buildings/LumberYard.tres",
	"Chapel": "res://data/buildings/Monastery_Chapel.tres",
	"Granary": "res://data/buildings/Monastery_Granary.tres",
	"Library": "res://data/buildings/Monastery_Library.tres",
	"Scriptorium": "res://data/buildings/Monastery_Scriptorium.tres",
	"Watchtower": "res://data/buildings/Monastery_Watchtower.tres"
}

func _run():
	print("=== SETTLEMENT LAYOUT EDITOR ===")
	print("Available buildings:")
	for name in BUILDINGS.keys():
		print("  - %s: %s" % [name, BUILDINGS[name]])
	
	print("\n=== EXAMPLE LAYOUTS ===")
	
	# Example 1: Small Defensive Settlement
	var small_defensive = create_small_defensive_layout()
	print("\n1. SMALL DEFENSIVE LAYOUT:")
	print_layout(small_defensive)
	save_layout(small_defensive, "res://data/settlements/small_defensive.tres")
	
	# Example 2: Economic Settlement
	var economic = create_economic_layout()
	print("\n2. ECONOMIC LAYOUT:")
	print_layout(economic)
	save_layout(economic, "res://data/settlements/economic_base.tres")
	
	# Example 3: Monastery Layout
	var monastery = create_monastery_layout()
	print("\n3. MONASTERY LAYOUT:")
	print_layout(monastery)
	save_layout(monastery, "res://data/settlements/monastery_base.tres")
	
	print("\n=== LAYOUT FILES CREATED ===")
	print("You can now use these layouts by:")
	print("1. Loading them in the Inspector on SettlementBridge")
	print("2. Or copying the placement arrays manually")

func create_small_defensive_layout() -> Array[Dictionary]:
	return [
		# Great Hall in center
		{"resource_path": BUILDINGS["Great Hall"], "grid_position": Vector2i(8, 6)},
		
		# Defensive walls around perimeter
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(5, 4)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(6, 4)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(7, 4)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(11, 4)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(12, 4)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(13, 4)},
		
		# Watchtowers at corners
		{"resource_path": BUILDINGS["Watchtower"], "grid_position": Vector2i(4, 3)},
		{"resource_path": BUILDINGS["Watchtower"], "grid_position": Vector2i(14, 3)},
		
		# Basic resource building
		{"resource_path": BUILDINGS["Lumber Yard"], "grid_position": Vector2i(6, 8)}
	]

func create_economic_layout() -> Array[Dictionary]:
	return [
		# Great Hall
		{"resource_path": BUILDINGS["Great Hall"], "grid_position": Vector2i(10, 8)},
		
		# Economic buildings clustered together
		{"resource_path": BUILDINGS["Lumber Yard"], "grid_position": Vector2i(6, 6)},
		{"resource_path": BUILDINGS["Granary"], "grid_position": Vector2i(8, 6)},
		{"resource_path": BUILDINGS["Lumber Yard"], "grid_position": Vector2i(12, 6)},
		{"resource_path": BUILDINGS["Granary"], "grid_position": Vector2i(14, 6)},
		
		# Minimal defenses
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(8, 4)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(10, 4)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(12, 4)},
		{"resource_path": BUILDINGS["Watchtower"], "grid_position": Vector2i(10, 3)}
	]

func create_monastery_layout() -> Array[Dictionary]:
	return [
		# Central Great Hall
		{"resource_path": BUILDINGS["Great Hall"], "grid_position": Vector2i(10, 10)},
		
		# Monastery buildings in organized pattern
		{"resource_path": BUILDINGS["Chapel"], "grid_position": Vector2i(8, 7)},
		{"resource_path": BUILDINGS["Library"], "grid_position": Vector2i(12, 7)},
		{"resource_path": BUILDINGS["Scriptorium"], "grid_position": Vector2i(8, 13)},
		{"resource_path": BUILDINGS["Granary"], "grid_position": Vector2i(12, 13)},
		
		# Outer walls for protection
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(6, 5)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(8, 5)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(12, 5)},
		{"resource_path": BUILDINGS["Wall"], "grid_position": Vector2i(14, 5)},
		
		# Watchtowers
		{"resource_path": BUILDINGS["Watchtower"], "grid_position": Vector2i(5, 4)},
		{"resource_path": BUILDINGS["Watchtower"], "grid_position": Vector2i(15, 4)},
		{"resource_path": BUILDINGS["Watchtower"], "grid_position": Vector2i(5, 15)},
		{"resource_path": BUILDINGS["Watchtower"], "grid_position": Vector2i(15, 15)}
	]

func print_layout(layout: Array[Dictionary]):
	for i in range(layout.size()):
		var building = layout[i]
		var name = get_building_name(building["resource_path"])
		var pos = building["grid_position"]
		print("  [%d] %s at (%d, %d)" % [i, name, pos.x, pos.y])

func get_building_name(path: String) -> String:
	for name in BUILDINGS.keys():
		if BUILDINGS[name] == path:
			return name
	return "Unknown"

func save_layout(layout: Array[Dictionary], path: String):
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 1000, "wood": 500, "food": 200, "stone": 300}
	settlement.placed_buildings = layout
	settlement.garrisoned_units = {"res://data/units/Unit_PlayerRaider.tres": 3}
	
	var error = ResourceSaver.save(settlement, path)
	if error == OK:
		print("✅ Saved layout to: %s" % path)
	else:
		print("❌ Failed to save layout to: %s" % path)
