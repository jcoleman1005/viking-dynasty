@tool
class_name GridVisualizer
extends Node2D

# --- Editor Settings ---
@export_group("Editor Grid Settings")
@export var show_in_editor: bool = true:
	set(value):
		show_in_editor = value
		queue_redraw()

@export var grid_size: Vector2i = Vector2i(60, 40):
	set(value):
		grid_size = value
		_update_reference_rect()
		queue_redraw()

@export var tile_dimensions: Vector2i = Vector2i(64, 32):
	set(value):
		tile_dimensions = value
		_update_reference_rect()
		queue_redraw()

# --- Visual Settings ---
const GRID_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.1)
const BORDER_COLOR := Color(1.0, 0.8, 0.2, 0.5)
const SOLID_CELL_COLOR := Color(1.0, 0.0, 0.0, 0.3) 
const TERRITORY_COLOR := Color(0.0, 1.0, 0.0, 0.1) 

@onready var reference_rect: ReferenceRect = get_node_or_null("ReferenceRect")

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Runtime Logic
		EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	
	_update_reference_rect()
	queue_redraw()

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		if EventBus.pathfinding_grid_updated.is_connected(_on_grid_updated):
			EventBus.pathfinding_grid_updated.disconnect(_on_grid_updated)

func _on_grid_updated(_pos):
	queue_redraw()

func _update_reference_rect() -> void:
	if not reference_rect: return
	
	# Calculate Isometric Bounds
	var half_w = tile_dimensions.x * 0.5
	var half_h = tile_dimensions.y * 0.5
	
	# Min X is determined by the bottom-left corner of the grid (0, max_y)
	# Max X is determined by the top-right corner of the grid (max_x, 0)
	var min_x = (0 - grid_size.y) * half_w
	var max_x = (grid_size.x - 0) * half_w
	
	# Min Y is top (0,0) -> 0
	# Max Y is bottom (max_x, max_y)
	var total_height = (grid_size.x + grid_size.y) * half_h
	
	var total_width = max_x - min_x
	
	reference_rect.position = Vector2(min_x, 0)
	reference_rect.size = Vector2(total_width, total_height)
	reference_rect.border_color = BORDER_COLOR
	reference_rect.editor_description = "Visual bounds of the %dx%d isometric map" % [grid_size.x, grid_size.y]

func _draw() -> void:
	# 1. EDITOR DRAWING (The Layout Guide)
	if Engine.is_editor_hint():
		if show_in_editor:
			_draw_full_grid_layout()
		return

	# 2. RUNTIME DRAWING (The Debugger)
	# Draw solids and territory
	var half_w = SettlementManager.TILE_HALF_SIZE.x
	var half_h = SettlementManager.TILE_HALF_SIZE.y
	
	# Territory
	var buildable = SettlementManager.buildable_cells
	for cell in buildable:
		_draw_runtime_tile(cell, TERRITORY_COLOR, half_w, half_h, true)

	# Solids
	var grid = SettlementManager.active_astar_grid
	if grid:
		var region = grid.region
		for x in range(region.position.x, region.end.x):
			for y in range(region.position.y, region.end.y):
				var cell = Vector2i(x, y)
				if grid.is_point_solid(cell):
					_draw_runtime_tile(cell, SOLID_CELL_COLOR, half_w, half_h, true)

func _draw_full_grid_layout() -> void:
	var half_w = tile_dimensions.x * 0.5
	var half_h = tile_dimensions.y * 0.5
	
	# Optimization: Don't draw every single cell if map is huge, just border and major lines
	# But for 60x40, we can draw wireframe.
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell = Vector2i(x, y)
			# Local math to avoid singleton dependency in editor
			var center_x = (cell.x - cell.y) * half_w
			var center_y = (cell.x + cell.y) * half_h
			var center = Vector2(center_x, center_y)
			
			_draw_diamond_outline(center, half_w, half_h, GRID_LINE_COLOR)

func _draw_diamond_outline(center: Vector2, hw: float, hh: float, color: Color) -> void:
	var top = center + Vector2(0, -hh)
	var right = center + Vector2(hw, 0)
	var bottom = center + Vector2(0, hh)
	var left = center + Vector2(-hw, 0)
	var points = PackedVector2Array([top, right, bottom, left, top])
	draw_polyline(points, color, 1.0)

func _draw_runtime_tile(grid_pos: Vector2i, color: Color, hw: float, hh: float, fill: bool) -> void:
	var center = SettlementManager.grid_to_world(grid_pos)
	
	var top = center + Vector2(0, -hh)
	var right = center + Vector2(hw, 0)
	var bottom = center + Vector2(0, hh)
	var left = center + Vector2(-hw, 0)
	
	var points = PackedVector2Array([top, right, bottom, left])
	
	if fill:
		draw_polygon(points, [color])
	else:
		draw_polyline(points + PackedVector2Array([top]), color, 1.0)
