class_name GridUtils
extends RefCounted

# --- CONSTANTS ---
# The Holy Standards of Viking Dynasty
const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32
const TILE_SIZE := Vector2(TILE_WIDTH, TILE_HEIGHT)
const TILE_HALF := Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)

# --- ISOMETRIC PROJECTION MATH ---

## Converts Logical Grid Coords (Vector2i) -> World Position (Vector2).
## Returns the CENTER of the tile floor.
static func grid_to_iso(grid_pos: Vector2i) -> Vector2:
	# Standard Isometric Matrix for 2:1 Tiles
	# x = (row - col) * half_width
	# y = (row + col) * half_height
	var x = (grid_pos.x - grid_pos.y) * TILE_HALF.x
	var y = (grid_pos.x + grid_pos.y) * TILE_HALF.y
	return Vector2(x, y)

## Converts World Position (Vector2) -> Logical Grid Coords (Vector2i).
## Useful for mouse picking the terrain floor.
static func iso_to_grid(world_pos: Vector2) -> Vector2i:
	# Inverted Matrix
	var x = (world_pos.x / TILE_HALF.x + world_pos.y / TILE_HALF.y) * 0.5
	var y = (world_pos.y / TILE_HALF.y - world_pos.x / TILE_HALF.x) * 0.5
	return Vector2i(floor(x), floor(y))

## Snaps a world position to the exact center of its isometric tile.
static func snap_to_grid(world_pos: Vector2) -> Vector2:
	var grid_pos = iso_to_grid(world_pos)
	return grid_to_iso(grid_pos)

# --- VISUAL HELPERS ---

## Calculates the visual center offset for multi-tile buildings.
## A 2x2 building's sprite center is NOT the anchor tile center.
## It is the center of the union of the 4 tiles.
static func get_center_offset(grid_size: Vector2i) -> Vector2:
	# Formula: (SizeX - SizeY) * HalfWidth, (SizeX + SizeY) * HalfHeight
	# However, we usually want the offset relative to the Anchor Tile (0,0)
	
	# If we assume the sprite pivot is Bottom-Center of the Anchor Tile:
	# We want to move it to the visual center of the footprint.
	
	# For a 1x1: Offset is 0,0
	# For a 2x2: We need to move "down" the screen
	
	# Refined Formula for Pivot correction:
	var offset_x = (grid_size.x - 1.0 - (grid_size.y - 1.0)) * TILE_HALF.x * 0.5
	var offset_y = (grid_size.x - 1.0 + (grid_size.y - 1.0)) * TILE_HALF.y * 0.5
	
	return Vector2(offset_x, offset_y)

# --- EXISTING UTILITIES (Preserved & Typed) ---

static func is_within_bounds(grid: AStarGrid2D, cell: Vector2i) -> bool:
	if not grid: return false
	return grid.region.has_point(cell)

static func is_area_clear(grid: AStarGrid2D, top_left_pos: Vector2i, size: Vector2i) -> bool:
	if not grid: return false
	
	for x in range(size.x):
		for y in range(size.y):
			var cell = top_left_pos + Vector2i(x, y)
			if not is_within_bounds(grid, cell): return false
			if grid.is_point_solid(cell): return false
				
	return true

static func calculate_territory(placed_buildings: Array, grid_region: Rect2i) -> Dictionary:
	var buildable_map: Dictionary = {}
	
	for entry in placed_buildings:
		var path = entry.get("resource_path", "")
		if path == "": continue
		
		var data = load(path) as BuildingData
		if not data: continue
		
		if data.is_territory_hub or data.extends_territory:
			var raw_pos = entry["grid_position"]
			var center = Vector2i(raw_pos.x, raw_pos.y)
			var r = data.territory_radius
			var r_sq = r * r
			
			for x in range(center.x - r, center.x + r + 1):
				for y in range(center.y - r, center.y + r + 1):
					var cell = Vector2i(x, y)
					if not grid_region.has_point(cell): continue
					
					# Distance check (Euclidean distance on logical grid is acceptable for radius)
					if Vector2(cell).distance_squared_to(Vector2(center)) <= r_sq:
						buildable_map[cell] = true

	return buildable_map
