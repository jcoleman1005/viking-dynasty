@tool
class_name GridVisualizer
extends Node2D

# --- Editor Settings ---
@export_group("Grid Settings")
@export var show_grid: bool = true:
	set(value):
		show_grid = value
		queue_redraw()

@export var grid_size: Vector2i = Vector2i(60, 40):
	set(value):
		grid_size = value
		queue_redraw()

@export var tile_dimensions: Vector2i = Vector2i(64, 32):
	set(value):
		tile_dimensions = value
		queue_redraw()

# Button to force update if the editor gets stuck
@export_tool_button("Force Redraw") var force_redraw_action = _on_force_redraw

# --- Visual Settings ---
# Increased opacity from 0.1 -> 0.3 for visibility
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.3) 
const BORDER_COLOR := Color(1.0, 0.6, 0.0, 0.8) # Orange Diamond
const TERRITORY_COLOR := Color(0.2, 1.0, 0.2, 0.2) 
const SOLID_COLOR := Color(1.0, 0.0, 0.0, 0.3)

func _ready() -> void:
	if not Engine.is_editor_hint():
		EventBus.pathfinding_grid_updated.connect(queue_redraw.unbind(1))
	queue_redraw()

func _on_force_redraw() -> void:
	queue_redraw()

func _draw() -> void:
	# 1. Draw the Diamond Border (The "Outline")
	_draw_map_border()

	# 2. Editor: Draw the full grid lines
	if Engine.is_editor_hint():
		if show_grid:
			_draw_optimized_grid()
		return

	# 3. Runtime: Draw occupied tiles
	if not SettlementManager: return
	
	# Territory (Green Tiles)
	if SettlementManager.get("buildable_cells"):
		for cell in SettlementManager.buildable_cells:
			_draw_iso_poly(cell, TERRITORY_COLOR, true)

	# Solids (Red Tiles)
	if SettlementManager.get("active_astar_grid"):
		var grid = SettlementManager.active_astar_grid
		if grid:
			var region = grid.region
			for x in range(region.position.x, region.end.x):
				for y in range(region.position.y, region.end.y):
					var cell = Vector2i(x, y)
					if grid.is_point_solid(cell):
						_draw_iso_poly(cell, SOLID_COLOR, true)

func _draw_map_border() -> void:
	# Calculate the 4 corners of the diamond map
	var top = GridUtils.grid_to_iso(Vector2i(0, 0))
	var right = GridUtils.grid_to_iso(Vector2i(grid_size.x, 0))
	var bottom = GridUtils.grid_to_iso(Vector2i(grid_size.x, grid_size.y))
	var left = GridUtils.grid_to_iso(Vector2i(0, grid_size.y))
	
	# Add the "width" of the last tile so the border wraps AROUND the tiles, not through their centers
	# We shift Right/Bottom points by the visual width/height of one tile
	var half_size = Vector2(tile_dimensions) * 0.5
	
	# Adjust points to encompass the full tile sprites at the edges
	var p1 = top + Vector2(0, -half_size.y)       # Top Tip
	var p2 = right + Vector2(half_size.x, 0)      # Right Tip
	var p3 = bottom + Vector2(0, half_size.y)     # Bottom Tip
	var p4 = left + Vector2(-half_size.x, 0)      # Left Tip
	
	var points = PackedVector2Array([p1, p2, p3, p4, p1]) # Close loop
	draw_polyline(points, BORDER_COLOR, 3.0)

func _draw_optimized_grid() -> void:
	# Instead of drawing 2400 individual polygons, we draw long lines.
	# This is much faster and cleaner.
	
	var col = GRID_COLOR
	var start: Vector2
	var end: Vector2
	
	# Draw lines parallel to X-axis (Top-Left to Bottom-Right visual)
	for x in range(grid_size.x + 1):
		start = GridUtils.grid_to_iso(Vector2i(x, 0))
		end = GridUtils.grid_to_iso(Vector2i(x, grid_size.y))
		draw_line(start, end, col, 1.0)
		
	# Draw lines parallel to Y-axis (Top-Right to Bottom-Left visual)
	for y in range(grid_size.y + 1):
		start = GridUtils.grid_to_iso(Vector2i(0, y))
		end = GridUtils.grid_to_iso(Vector2i(grid_size.x, y))
		draw_line(start, end, col, 1.0)

func _draw_iso_poly(grid_pos: Vector2i, color: Color, fill: bool) -> void:
	var center = GridUtils.grid_to_iso(grid_pos)
	var half_size = Vector2(tile_dimensions) * 0.5
	
	var top = center + Vector2(0, -half_size.y)
	var right = center + Vector2(half_size.x, 0)
	var bottom = center + Vector2(0, half_size.y)
	var left = center + Vector2(-half_size.x, 0)
	
	var points = PackedVector2Array([top, right, bottom, left])
	
	if fill:
		draw_polygon(points, [color])
	else:
		points.append(top)
		draw_polyline(points, color, 1.0)
