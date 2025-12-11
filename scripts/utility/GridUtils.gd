class_name GridUtils
extends RefCounted

# Checks if a specific cell is inside the valid map bounds
static func is_within_bounds(grid: AStarGrid2D, cell: Vector2i) -> bool:
	if not grid: return false
	return grid.region.has_point(cell)

# Checks if a rectangular footprint is completely clear of obstacles
static func is_area_clear(grid: AStarGrid2D, top_left_pos: Vector2i, size: Vector2i) -> bool:
	if not grid: return false
	
	for x in range(size.x):
		for y in range(size.y):
			var cell = top_left_pos + Vector2i(x, y)
			if not is_within_bounds(grid, cell): return false
			if grid.is_point_solid(cell): return false
				
	return true

# Recalculates the entire territory map based on placed buildings
# Returns: Dictionary { Vector2i: bool }
static func calculate_territory(placed_buildings: Array, grid_region: Rect2i) -> Dictionary:
	var buildable_map: Dictionary = {}
	
	for entry in placed_buildings:
		var path = entry.get("resource_path", "")
		if path == "": continue
		
		var data = load(path) as BuildingData
		if not data: continue
		
		if data.is_territory_hub or data.extends_territory:
			# Normalize grid position (Vector2 -> Vector2i)
			var raw_pos = entry["grid_position"]
			var center = Vector2i(raw_pos.x, raw_pos.y)
			
			var r = data.territory_radius
			var r_sq = r * r
			
			# Check bounding box around radius for efficiency
			for x in range(center.x - r, center.x + r + 1):
				for y in range(center.y - r, center.y + r + 1):
					var cell = Vector2i(x, y)
					if not grid_region.has_point(cell): continue
					
					if Vector2(cell).distance_squared_to(Vector2(center)) <= r_sq:
						buildable_map[cell] = true

	return buildable_map
