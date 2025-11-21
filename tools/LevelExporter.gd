# res://tools/LevelExporter.gd
@tool
extends EditorScript

# --- CONFIGURATION ---
# CHANGE THIS PATH before running the script to save to a new file.
const TARGET_SAVE_PATH = "res://data/settlements/new_raid_map.tres"
const CONTAINER_NAME = "BuildingContainer"
const CELL_SIZE = Vector2(32, 32)

func _run():
	# 1. Get the Active Scene Root
	# FIXED: Called directly from the EditorInterface type
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		print("Error: No scene open.")
		return

	# 2. Find the Container
	var container = root.get_node_or_null(CONTAINER_NAME)
	if not container:
		print("Error: Could not find '%s' node. Ensure your scene has a node named exactly '%s'." % [CONTAINER_NAME, CONTAINER_NAME])
		return

	# 3. Create the Data Object
	var settlement_data = SettlementData.new()
	# Default treasury for a raid target (can be edited in Inspector later)
	settlement_data.treasury = {"gold": 500, "wood": 500, "food": 500, "stone": 200}
	settlement_data.placed_buildings = []
	# Initialize garrison with default enemy
	settlement_data.warbands = [] 

	# 4. Scrape the Buildings
	var buildings = container.get_children()
	var count = 0

	for node in buildings:
		# Skip hidden nodes (allows us to temporarily remove things without deleting)
		if not node.visible:
			continue

		if node is BaseBuilding and node.data:
			# Calculate Top-Left Grid Position
			# BaseBuilding centers sprites, so we offset by half size to get grid origin
			var building_size_px = Vector2(node.data.grid_size) * CELL_SIZE
			var top_left_pos = node.position - (building_size_px / 2.0)

			# Round to nearest tile to handle imprecise dragging
			var grid_x = round(top_left_pos.x / CELL_SIZE.x)
			var grid_y = round(top_left_pos.y / CELL_SIZE.y)
			var grid_pos = Vector2i(grid_x, grid_y)

			# Construct the Dictionary Entry expected by SettlementData
			var entry = {
				"resource_path": node.data.resource_path,
				"grid_position": grid_pos
			}

			settlement_data.placed_buildings.append(entry)
			count += 1
		else:
			print("Warning: Found non-building node '%s' in container. Skipping." % node.name)

	# 5. Save to Disk
	var error = ResourceSaver.save(settlement_data, TARGET_SAVE_PATH)
	if error == OK:
		print("✅ SUCCESS: Exported %d buildings to %s" % [count, TARGET_SAVE_PATH])
		# FIXED: Called directly from the EditorInterface type
		EditorInterface.get_resource_filesystem().scan()
	else:
		print("❌ ERROR: Failed to save resource. Error Code: %s" % error)
