# res://autoload/NavigationManager.gd
extends Node

var active_astar_grid: AStarGrid2D = null
var grid_owner_node: Node = null # Debug ref (who owns this grid?)

func register_grid(grid: AStarGrid2D, owner_node: Node) -> void:
	active_astar_grid = grid
	grid_owner_node = owner_node
	Loggie.msg("Navigation Grid Registered by %s" % owner_node.name).domain("NAVIGATION").info()

func unregister_grid() -> void:
	active_astar_grid = null
	grid_owner_node = null

func get_astar_path(start_pos: Vector2, end_pos: Vector2, allow_partial_path: bool = false) -> PackedVector2Array:
	if not is_instance_valid(active_astar_grid): return PackedVector2Array()
	
	var cell_size = active_astar_grid.cell_size
	var start = Vector2i(start_pos / cell_size)
	var end = Vector2i(end_pos / cell_size)
	
	# 1. Start validation
	if not _is_cell_within_bounds(start): 
		return PackedVector2Array()
	
	# 2. Clamp Target
	var bounds = active_astar_grid.region
	end.x = clampi(end.x, bounds.position.x, bounds.end.x - 1)
	end.y = clampi(end.y, bounds.position.y, bounds.end.y - 1)
	
	return active_astar_grid.get_point_path(start, end, allow_partial_path)

func set_point_solid(grid_pos: Vector2i, solid: bool) -> void:
	if is_instance_valid(active_astar_grid) and _is_cell_within_bounds(grid_pos):
		active_astar_grid.set_point_solid(grid_pos, solid)

func is_point_solid(grid_pos: Vector2i) -> bool:
	if is_instance_valid(active_astar_grid) and _is_cell_within_bounds(grid_pos):
		return active_astar_grid.is_point_solid(grid_pos)
	return true # Default to solid if grid invalid

func _is_cell_within_bounds(grid_pos: Vector2i) -> bool:
	if not is_instance_valid(active_astar_grid): return false
	var bounds = active_astar_grid.region
	# FIX: changed 'grid_position' to 'grid_pos' in the Y-axis checks
	return grid_pos.x >= bounds.position.x and grid_pos.x < bounds.end.x and grid_pos.y >= bounds.position.y and grid_pos.y < bounds.end.y

func get_cell_size() -> Vector2:
	if is_instance_valid(active_astar_grid): return active_astar_grid.cell_size
	return Vector2(32, 32)
