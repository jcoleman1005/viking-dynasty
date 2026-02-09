#res://autoload/NavigationManager.gd
extends Node

## Singleton handling AStarGrid2D pathfinding and Coordinate Conversions.
## Accessed via NavigationManager.function()

signal navigation_grid_ready

# --- Configuration ---
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF_SIZE = Vector2(32, 16)
# CRITICAL: Match TileMap layout. Standard Isometric usually needs DIAGONAL_MODE_ALWAYS.
const DIAGONAL_MODE = AStarGrid2D.DIAGONAL_MODE_ALWAYS 
const HEURISTIC = AStarGrid2D.HEURISTIC_EUCLIDEAN

# --- Tuning ---
const SMOOTHING_CHECK_RADIUS: float = 24.0 
const WALL_NUDGE_AMOUNT: float = 14.0 

# --- State ---
var active_astar_grid: AStarGrid2D
var active_tilemap_layer: TileMapLayer
var _grid_rect: Rect2i

func _ready() -> void:
	Loggie.msg("NavigationManager Initialized").domain(LogDomains.SYSTEM).info()
	# Pre-allocate generic grid, though it will be overwritten by initialize/register
	_setup_base_grid()

func _setup_base_grid() -> void:
	active_astar_grid = AStarGrid2D.new()
	active_astar_grid.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN
	active_astar_grid.default_compute_heuristic = HEURISTIC
	active_astar_grid.default_estimate_heuristic = HEURISTIC
	active_astar_grid.diagonal_mode = DIAGONAL_MODE
	active_astar_grid.cell_size = Vector2(TILE_WIDTH, TILE_HEIGHT)

# --- MAP REGISTRATION (Legacy Support + New API) ---

## Legacy compatibility for LevelBase.gd
func initialize_grid_from_tilemap(tilemap: TileMapLayer, map_size: Vector2i, tile_shape: Vector2i) -> void:
	# Forward to the robust registration logic
	# We interpret map_size as the region size starting from 0,0
	var manual_rect = Rect2i(0, 0, map_size.x, map_size.y)
	register_map(tilemap, manual_rect)

## Robust registration
func register_map(map_layer: TileMapLayer, manual_rect: Rect2i = Rect2i()) -> void:
	active_tilemap_layer = map_layer
	
	# Determine bounds: Use manual if provided, otherwise detect from map
	var used_rect = manual_rect
	if used_rect == Rect2i():
		used_rect = map_layer.get_used_rect()
		# Add padding to allow moving slightly off-map if needed
		used_rect = used_rect.grow(2)
	
	_grid_rect = used_rect
	
	# Re-init grid with specific region
	_setup_base_grid()
	active_astar_grid.region = used_rect
	active_astar_grid.update()
	
	# Sync Obstacles (Solid tiles)
	_sync_solids_from_map(map_layer)
	
	# FIX: formatting context into string instead of using .ctx()
	Loggie.msg("Navigation Grid Registered: Rect=%s, CellSize=%s" % [used_rect, active_astar_grid.cell_size]).domain(LogDomains.GAMEPLAY).info()
	
	emit_signal("navigation_grid_ready")

func _sync_solids_from_map(map: TileMapLayer) -> void:
	var rect = active_astar_grid.region
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords = Vector2i(x, y)
			var tile_data = map.get_cell_tile_data(coords)
			if tile_data:
				# Custom Data "is_unwalkable" (Negative Logic)
				var is_unwalkable = tile_data.get_custom_data("is_unwalkable")
				if is_unwalkable:
					active_astar_grid.set_point_solid(coords, true)
			else:
				# Void tiles (no visual) are usually solid in isometric games
				# unless strictly using a background layer.
				# Uncomment the line below if "empty space" = "cliff/void"
				active_astar_grid.set_point_solid(coords, true)
				pass

func unregister_grid() -> void:
	active_astar_grid = null
	active_tilemap_layer = null

# --- PATHFINDING ---

## Returns a world-space path from Start to End.
func get_astar_path(start_world: Vector2, end_world: Vector2, allow_partial: bool = true) -> PackedVector2Array:
	if not active_astar_grid:
		Loggie.msg("Path requested but Grid not ready").domain(LogDomains.GAMEPLAY).warn()
		return PackedVector2Array()

	var start_grid = _world_to_grid(start_world)
	var end_grid = _world_to_grid(end_world)

	# Boundary check
	if not active_astar_grid.is_in_boundsv(start_grid) or not active_astar_grid.is_in_boundsv(end_grid):
		# Optional: Clamp end grid to bounds if user clicked outside
		# end_grid.x = clampi(end_grid.x, _grid_rect.position.x, _grid_rect.end.x - 1)
		# end_grid.y = clampi(end_grid.y, _grid_rect.position.y, _grid_rect.end.y - 1)
		# For now, return empty if out of bounds to be safe
		# FIX: formatting context into string instead of using .ctx()
		Loggie.msg("Path request out of bounds: Start%s End%s" % [start_grid, end_grid]).domain(LogDomains.GAMEPLAY).debug()
		return PackedVector2Array()

	# Get ID path (Grid Coords) first to verify connectivity
	var path = active_astar_grid.get_point_path(start_grid, end_grid, allow_partial)
	
	if path.size() > 0:
		# Fix start point to be exact actor position, not tile center
		path[0] = start_world
		
		# Pruning: If the first point (center of current tile) is "behind" us or extremely close
		if path.size() > 1 and start_world.distance_to(path[1]) < start_world.distance_to(path[0]):
			# We are closer to point 1 than point 0 (backtracking), so skip 0
			path.remove_at(0)
	
	# Apply Post-Processing
	var smoothed = _smooth_path(path)
	var nudged = _apply_wall_nudging(smoothed)
	
	return nudged

# --- COORDINATE MATH (ISOMETRIC) ---

## Converts World Position (Pixels) to Grid Coordinate (Vector2i)
func _world_to_grid(pos: Vector2) -> Vector2i:
	# Prefer TileMap Logic if available (Source of Truth)
	if is_instance_valid(active_tilemap_layer):
		var local = active_tilemap_layer.to_local(pos)
		return active_tilemap_layer.local_to_map(local)

	# Fallback Math (Standard Isometric Down)
	var x_part = pos.x / TILE_HALF_SIZE.x
	var y_part = pos.y / TILE_HALF_SIZE.y
	
	var grid_x = floor((x_part + y_part) * 0.5)
	var grid_y = floor((y_part - x_part) * 0.5)
	
	return Vector2i(grid_x, grid_y)

## Converts Grid Coordinate to World Position (Top-Left of tile usually)
func _grid_to_world(grid: Vector2i) -> Vector2:
	# Prefer TileMap Logic
	if is_instance_valid(active_tilemap_layer):
		var local = active_tilemap_layer.map_to_local(grid)
		return active_tilemap_layer.to_global(local)

	# Fallback Math
	var x = (grid.x - grid.y) * TILE_HALF_SIZE.x
	var y = (grid.x + grid.y) * TILE_HALF_SIZE.y
	return Vector2(x, y)

# --- SPATIAL QUERY ---

func request_valid_spawn_point(target_world_pos: Vector2, max_radius: int = 5) -> Vector2:
	var start_cell = _world_to_grid(target_world_pos)
	
	if not is_point_solid(start_cell):
		return target_world_pos
		
	for r in range(1, max_radius + 1):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				var check = start_cell + Vector2i(x, y)
				if _is_cell_within_bounds(check) and not is_point_solid(check):
					# Return CENTER of the valid tile
					return snap_to_grid_center(_grid_to_world(check))
					
	return Vector2.INF

# --- HELPERS & POST-PROCESSING ---

func is_point_solid(grid_pos: Vector2i) -> bool:
	if not active_astar_grid: return false
	if not active_astar_grid.is_in_boundsv(grid_pos): return true
	return active_astar_grid.is_point_solid(grid_pos)

func set_point_solid(grid_pos: Vector2i, is_solid: bool) -> void:
	if not active_astar_grid: return
	if active_astar_grid.is_in_boundsv(grid_pos):
		active_astar_grid.set_point_solid(grid_pos, is_solid)

func snap_to_grid_center(world_pos: Vector2) -> Vector2:
	var grid = _world_to_grid(world_pos)
	var top_left = _grid_to_world(grid)
	# Add half-height offset to hit visual center of the diamond
	return top_left + Vector2(0, TILE_HALF_SIZE.y) # Removed vertical offset for consistency with TileMap logic

func _is_cell_within_bounds(grid_pos: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	return active_astar_grid.region.has_point(grid_pos)

func _is_point_solid_world(world_pos: Vector2) -> bool:
	var cell = _world_to_grid(world_pos)
	if not _is_cell_within_bounds(cell): return true 
	return active_astar_grid.is_point_solid(cell)

func _smooth_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2: return path
	var smoothed: PackedVector2Array = []
	smoothed.append(path[0])
	var current_idx = 0
	
	while current_idx < path.size() - 1:
		var lookahead_limit = min(path.size() - 1, current_idx + 18)
		var check_idx = lookahead_limit
		var found_shortcut = false
		
		while check_idx > current_idx + 1:
			if _has_thick_line_of_sight(path[current_idx], path[check_idx], SMOOTHING_CHECK_RADIUS):
				current_idx = check_idx
				smoothed.append(path[current_idx])
				found_shortcut = true
				break
			check_idx -= 1
			
		if not found_shortcut:
			current_idx += 1
			smoothed.append(path[current_idx])
			
	return smoothed

func _has_thick_line_of_sight(from: Vector2, to: Vector2, radius: float) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	var cell_size = active_astar_grid.cell_size
	var dist = from.distance_to(to)
	if dist < 1.0: return true
	
	var step_size = min(cell_size.x, cell_size.y) / 2.0 
	var steps = ceil(dist / step_size)
	var direction = (to - from).normalized()
	
	# Check perpendicular vectors for thickness
	var side_vector = Vector2(-direction.y, direction.x) * radius
	
	for i in range(1, int(steps)):
		var center_pos = from + (direction * (i * step_size))
		if _is_point_solid_world(center_pos): return false
		if _is_point_solid_world(center_pos + side_vector): return false
		if _is_point_solid_world(center_pos - side_vector): return false
		
	return true

func _apply_wall_nudging(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2: return path
	var nudged_path = path.duplicate()
	
	for i in range(1, path.size() - 1):
		var point = path[i]
		var grid_pos = _world_to_grid(point)
		var repulsion = Vector2.ZERO
		
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0: continue
				var neighbor_cell = grid_pos + Vector2i(x, y)
				if is_point_solid(neighbor_cell):
					# Push away from solid wall
					var push_dir = -Vector2(x, y).normalized() 
					# Note: In iso, normalized vector might feel skewed, but sufficient for nudge
					repulsion += push_dir
					
		if repulsion != Vector2.ZERO:
			nudged_path[i] += repulsion.normalized() * WALL_NUDGE_AMOUNT
			
	return nudged_path
