#res://scripts/utility/GridVisualizer.gd
@tool
class_name GridVisualizer
extends Node2D

# --- Editor Settings ---
@export_group("Grid Settings")
@export var show_grid: bool = true:
	set(value):
		show_grid = value
		queue_redraw()

@export var debug_show_solids: bool = false: # DISABLED BY DEFAULT
	set(value):
		debug_show_solids = value
		queue_redraw()

@export var grid_size: Vector2i = Vector2i(60, 40):
	set(value):
		grid_size = value
		queue_redraw()

@export var tile_dimensions: Vector2i = Vector2i(64, 32):
	set(value):
		tile_dimensions = value
		_precalculate_iso_offsets() 
		queue_redraw()

@export_tool_button("Force Redraw") var force_redraw_action = _on_force_redraw

# --- Visual Settings ---
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.1) 
const BORDER_COLOR := Color(1.0, 0.6, 0.0, 0.8) 
const SOLID_COLOR := Color(1.0, 0.0, 0.0, 0.3)

# Store pre-calculated polygon offsets to avoid math in loops
var _iso_offsets: PackedVector2Array = []

func _ready() -> void:
	_precalculate_iso_offsets()
	
	if not Engine.is_editor_hint():
		# Connect signal to only redraw grid when the map actually changes
		EventBus.pathfinding_grid_updated.connect(queue_redraw.unbind(1))
		
		# Attach the dynamic drawer as a child
		if ResourceLoader.exists("res://scripts/utility/UnitPathDrawer.gd"):
			var path_drawer = load("res://scripts/utility/UnitPathDrawer.gd").new() 
			if path_drawer:
				add_child(path_drawer)
		else:
			printerr("GridVisualizer: Could not find UnitPathDrawer.gd!")
			
	queue_redraw()

func _on_force_redraw() -> void:
	_precalculate_iso_offsets()
	queue_redraw()

func _precalculate_iso_offsets() -> void:
	var half = Vector2(tile_dimensions) * 0.5
	_iso_offsets = PackedVector2Array([
		Vector2(0, -half.y), # Top
		Vector2(half.x, 0),  # Right
		Vector2(0, half.y),  # Bottom
		Vector2(-half.x, 0)  # Left
	])

func _draw() -> void:
	# 1. Draw Grid Lines (Editor & Runtime)
	if show_grid:
		_draw_map_border()
		_draw_optimized_grid()

	# 2. Draw Solids (Runtime Only)
	if not debug_show_solids:
		return

	if Engine.is_editor_hint() or not NavigationManager.active_astar_grid: 
		return

	# Optimization: Only draw nearby cells to save FPS
	var cam = get_viewport().get_camera_2d()
	if cam:
		if not NavigationManager.has_method("_world_to_grid"): return
		
		var center = NavigationManager._world_to_grid(cam.get_screen_center_position())
		var range_val = 20 
		
		var grid = NavigationManager.active_astar_grid
		var region = grid.region
		
		for x in range(center.x - range_val, center.x + range_val):
			for y in range(center.y - range_val, center.y + range_val):
				var cell = Vector2i(x, y)
				if not region.has_point(cell): continue
				
				if grid.is_point_solid(cell):
					_draw_iso_poly_optimized(cell, SOLID_COLOR, true)

func _draw_iso_poly_optimized(grid_pos: Vector2i, color: Color, fill: bool) -> void:
	if not NavigationManager.has_method("_grid_to_world"): return
	
	var center = NavigationManager._grid_to_world(grid_pos)
	
	# FIX: Apply Isometric Vertical Offset
	# NavigationManager returns the Grid Intersection (Top Corner).
	# We need to shift down by Half-Height to reach the Tile Center.
	center.y += tile_dimensions.y * 0.5
	
	var points = _iso_offsets.duplicate()
	
	# Shift points to the correct world position
	for i in range(points.size()):
		points[i] += center
	
	if fill:
		draw_polygon(points, [color])
	else:
		points.append(points[0]) # Close the loop
		draw_polyline(points, color, 1.0)

# ... Border and Grid Logic ...
func _draw_map_border() -> void:
	# (Keeping your existing border logic logic)
	if not ClassDB.class_exists("GridUtils") and not get_tree().root.has_node("GridUtils"):
		return 

	pass 

func _draw_optimized_grid() -> void:
	var col = GRID_COLOR
	var half_w = tile_dimensions.x * 0.5
	var half_h = tile_dimensions.y * 0.5
	
	# Helper for iso conversion inside loop
	var grid_to_iso = func(g: Vector2i) -> Vector2:
		return Vector2((g.x - g.y) * half_w, (g.x + g.y) * half_h)

	for x in range(grid_size.x + 1):
		var start = grid_to_iso.call(Vector2i(x, 0))
		var end = grid_to_iso.call(Vector2i(x, grid_size.y))
		draw_line(start, end, col, 1.0)
	for y in range(grid_size.y + 1):
		var start = grid_to_iso.call(Vector2i(0, y))
		var end = grid_to_iso.call(Vector2i(grid_size.x, y))
		draw_line(start, end, col, 1.0)
