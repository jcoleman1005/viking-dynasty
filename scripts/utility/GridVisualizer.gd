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

@export_tool_button("Force Redraw") var force_redraw_action = _on_force_redraw

# --- Visual Settings ---
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.1) 
const BORDER_COLOR := Color(1.0, 0.6, 0.0, 0.8) 
const TERRITORY_COLOR := Color(0.2, 1.0, 0.2, 0.2) 
const SOLID_COLOR := Color(1.0, 0.0, 0.0, 0.3) # Red for Obstacles

func _ready() -> void:
	if not Engine.is_editor_hint():
		EventBus.pathfinding_grid_updated.connect(queue_redraw.unbind(1))
	queue_redraw()

func _process(_delta: float) -> void:
	# Runtime Only: Redraw every frame to animate unit paths
	if not Engine.is_editor_hint() and show_grid:
		queue_redraw()

func _on_force_redraw() -> void:
	queue_redraw()

func _draw() -> void:
	# 1. Editor: Draw the clean grid
	if Engine.is_editor_hint():
		if show_grid:
			_draw_map_border()
			_draw_optimized_grid()
		return

	# 2. Runtime: Draw Logic
	if not is_instance_valid(SettlementManager) or not SettlementManager.active_astar_grid: 
		return

	# Draw Solids (Red)
	# Optimization: Only draw nearby cells to save FPS
	var cam = get_viewport().get_camera_2d()
	if cam:
		var center = SettlementManager.world_to_grid(cam.get_screen_center_position())
		var range_val = 20 # Draw 20 tiles around camera
		
		var grid = SettlementManager.active_astar_grid
		var region = grid.region
		
		for x in range(center.x - range_val, center.x + range_val):
			for y in range(center.y - range_val, center.y + range_val):
				var cell = Vector2i(x, y)
				if not region.has_point(cell): continue
				
				if grid.is_point_solid(cell):
					_draw_iso_poly(cell, SOLID_COLOR, true)

	# --- NEW: Draw Unit Paths ---
	var units = get_tree().get_nodes_in_group("player_units")
	for unit in units:
		if unit.get("fsm") and unit.fsm.path.size() > 0:
			var points = PackedVector2Array([unit.global_position] + unit.fsm.path)
			draw_polyline(points, Color.CYAN, 2.0)
			# Draw destination dot
			draw_circle(unit.fsm.target_position, 4.0, Color.BLUE)

func _draw_iso_poly(grid_pos: Vector2i, color: Color, fill: bool) -> void:
	# CRITICAL: Use SettlementManager math to ensure visual matches logic
	var center = SettlementManager.grid_to_world(grid_pos)
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

# ... (Keep _draw_map_border and _draw_optimized_grid as they were) ...
func _draw_map_border() -> void:
	var top = GridUtils.grid_to_iso(Vector2i(0, 0))
	var right = GridUtils.grid_to_iso(Vector2i(grid_size.x, 0))
	var bottom = GridUtils.grid_to_iso(Vector2i(grid_size.x, grid_size.y))
	var left = GridUtils.grid_to_iso(Vector2i(0, grid_size.y))
	
	var half_size = Vector2(tile_dimensions) * 0.5
	var p1 = top + Vector2(0, -half_size.y)
	var p2 = right + Vector2(half_size.x, 0)
	var p3 = bottom + Vector2(0, half_size.y)
	var p4 = left + Vector2(-half_size.x, 0)
	
	draw_polyline(PackedVector2Array([p1, p2, p3, p4, p1]), BORDER_COLOR, 3.0)

func _draw_optimized_grid() -> void:
	var col = GRID_COLOR
	for x in range(grid_size.x + 1):
		var start = GridUtils.grid_to_iso(Vector2i(x, 0))
		var end = GridUtils.grid_to_iso(Vector2i(x, grid_size.y))
		draw_line(start, end, col, 1.0)
	for y in range(grid_size.y + 1):
		var start = GridUtils.grid_to_iso(Vector2i(0, y))
		var end = GridUtils.grid_to_iso(Vector2i(grid_size.x, y))
		draw_line(start, end, col, 1.0)
