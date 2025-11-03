@tool
extends EditorPlugin

func _enter_tree():
	# Add the custom tool to the Tools menu
	add_tool_menu_item("Enemy Base Layout Editor", _open_enemy_base_editor)

func _exit_tree():
	# Remove the tool from the Tools menu
	remove_tool_menu_item("Enemy Base Layout Editor")

func _open_enemy_base_editor():
	print("=== ENEMY BASE LAYOUT EDITOR ===")
	
	var settlement_path = "res://data/settlements/monastery_base.tres"
	var settlement_data: SettlementData = load(settlement_path)
	
	if not settlement_data:
		print("ERROR: Could not load settlement data!")
		push_error("Could not load settlement data from: " + settlement_path)
		return
	
	print("Current layout for: " + settlement_path)
	print("Grid positions (format: Building @ X,Y):")
	print("-".repeat(40))
	
	for i in range(settlement_data.placed_buildings.size()):
		var building = settlement_data.placed_buildings[i]
		var pos = building["grid_position"]
		var building_data: BuildingData = load(building["resource_path"])
		var name = building_data.display_name if building_data else "Unknown"
		
		print("%d. %s @ %d,%d" % [i+1, name, pos.x, pos.y])
	
	print("-".repeat(40))
	print("To modify layout:")
	print("1. Edit grid_position values in the .tres file")
	print("2. Or use the create_fortress_layout() function")
	print("3. Grid range: 0-%d (width), 0-%d (height)" % [
		SettlementManager.grid_width-1, 
		SettlementManager.grid_height-1
	])
	
	# Show completion message
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Enemy Base Layout analysis complete!\nCheck the Output panel for detailed results."
	dialog.title = "Enemy Base Editor"
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

# Helper function to create new enemy base layouts
static func create_enemy_base_layout(buildings: Array[Dictionary], save_path: String):
	var settlement = SettlementData.new()
	settlement.treasury = {"gold": 500, "wood": 200, "food": 150, "stone": 100}
	settlement.placed_buildings = buildings
	
	var error = ResourceSaver.save(settlement, save_path)
	if error == OK:
		print("Created new enemy base: " + save_path)
	else:
		push_error("Failed to save enemy base to: " + save_path)

# Example usage function - call this from the debug console
static func create_fortress_layout():
	var buildings = [
		{"grid_position": Vector2i(30, 20), "resource_path": "res://data/buildings/Bldg_GreatHall.tres"},
		{"grid_position": Vector2i(29, 19), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(30, 19), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(31, 19), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(29, 21), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(30, 21), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(31, 21), "resource_path": "res://data/buildings/Bldg_Wall.tres"},
		{"grid_position": Vector2i(28, 20), "resource_path": "res://data/buildings/LumberYard.tres"},
		{"grid_position": Vector2i(32, 20), "resource_path": "res://data/buildings/LumberYard.tres"},
	]
	
	create_enemy_base_layout(buildings, "res://data/settlements/fortress_base.tres")
