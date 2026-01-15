# res://autoload/NavigationManager.gd
extends Node

var active_astar_grid: AStarGrid2D = null
var grid_owner_node: Node = null 

# TUNING: 
# 1. Ray Thickness: Rejects shortcuts that pass too close to walls.
const SMOOTHING_CHECK_RADIUS: float = 24.0 

# 2. Wall Detour: How far to push waypoints away from adjacent walls.
const WALL_NUDGE_AMOUNT: float = 14.0 

func register_grid(grid: AStarGrid2D, owner_node: Node) -> void:
	active_astar_grid = grid
	grid_owner_node = owner_node
	active_astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	Loggie.msg("Navigation Grid Registered by %s" % owner_node.name).domain("NAVIGATION").info()

func unregister_grid() -> void:
	active_astar_grid = null
	grid_owner_node = null

func get_astar_path(start_pos: Vector2, end_pos: Vector2, allow_partial_path: bool = false) -> PackedVector2Array:
	if not is_instance_valid(active_astar_grid): return PackedVector2Array()
	
	var start = _world_to_grid(start_pos)
	var end = _world_to_grid(end_pos)
	
	if not _is_cell_within_bounds(start): 
		return PackedVector2Array()
	
	var bounds = active_astar_grid.region
	end.x = clampi(end.x, bounds.position.x, bounds.end.x - 1)
	end.y = clampi(end.y, bounds.position.y, bounds.end.y - 1)
	
	# 1. Get Raw Path
	var raw_path = active_astar_grid.get_point_path(start, end, allow_partial_path)
	if raw_path.is_empty(): return raw_path

	# 2. Snap Start
	raw_path[0] = start_pos
	
	# 3. Apply Smoothing (String Pulling)
	var smoothed_path = _smooth_path(raw_path)
	
	# 4. Apply Detour (Corner Nudging)
	# This ensures that even the points we MUST visit are pushed away from walls
	return _apply_wall_nudging(smoothed_path)

# --- NEW: Wall Detour Logic ---
func _apply_wall_nudging(path: PackedVector2Array) -> PackedVector2Array:
	# We don't nudge start (0) or end (size-1) to ensure precision.
	if path.size() <= 2: return path
	
	var nudged_path = path.duplicate()
	var cell_size = active_astar_grid.cell_size
	
	for i in range(1, path.size() - 1):
		var point = path[i]
		var grid_pos = _world_to_grid(point)
		var repulsion = Vector2.ZERO
		
		# Check 8 Neighbors
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0: continue
				
				var neighbor_cell = grid_pos + Vector2i(x, y)
				
				# If neighbor is solid, push AWAY from it
				if is_point_solid(neighbor_cell):
					# Calculate vector from Wall Center -> Waypoint
					# Note: Since we are in Iso, simple (x,y) direction is sufficient for logic
					# but we can be precise by converting back to world.
					
					# Approximate repulsion: Push opposite to the neighbor direction
					# (This works well enough for Grid Logic)
					var push_dir = -Vector2(x, y).normalized()
					
					# Flatten Y push in Iso (since Y is foreshortened visually)? 
					# Actually, standard push is fine.
					repulsion += push_dir
		
		if repulsion != Vector2.ZERO:
			nudged_path[i] += repulsion.normalized() * WALL_NUDGE_AMOUNT
			
	return nudged_path

# --- EXISTING: Math & Smoothing ---

func _world_to_grid(pos: Vector2) -> Vector2i:
	if not is_instance_valid(active_astar_grid): return Vector2i.ZERO
	var cell_size = active_astar_grid.cell_size
	var half_w = cell_size.x * 0.5
	var half_h = cell_size.y * 0.5
	if half_w == 0 or half_h == 0: return Vector2i.ZERO
	var x_part = pos.x / half_w
	var y_part = pos.y / half_h
	return Vector2i(floor((x_part + y_part) * 0.5), floor((y_part - x_part) * 0.5))

func _is_cell_within_bounds(grid_pos: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	var bounds = active_astar_grid.region
	return grid_pos.x >= bounds.position.x and grid_pos.x < bounds.end.x and grid_pos.y >= bounds.position.y and grid_pos.y < bounds.end.y

func set_point_solid(grid_pos: Vector2i, solid: bool) -> void:
	if is_instance_valid(active_astar_grid) and _is_cell_within_bounds(grid_pos):
		active_astar_grid.set_point_solid(grid_pos, solid)

func is_point_solid(grid_pos: Vector2i) -> bool:
	if is_instance_valid(active_astar_grid) and _is_cell_within_bounds(grid_pos):
		return active_astar_grid.is_point_solid(grid_pos)
	return true 

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
	var side_vector = Vector2(-direction.y, direction.x) * radius
	
	for i in range(1, steps):
		var center_pos = from + (direction * (i * step_size))
		if _is_point_solid_world(center_pos): return false
		if _is_point_solid_world(center_pos + side_vector): return false
		if _is_point_solid_world(center_pos - side_vector): return false
	return true

func _is_point_solid_world(world_pos: Vector2) -> bool:
	var cell = _world_to_grid(world_pos)
	if not _is_cell_within_bounds(cell): return true 
	return active_astar_grid.is_point_solid(cell)
