#res://scripts/utility/IsoPlaceholder.gd
@tool
class_name IsoPlaceholder
extends Node2D

# --- Configuration ---
@export var data: BuildingData:
	set(value):
		data = value
		queue_redraw()

@export var color: Color = Color.CORNFLOWER_BLUE:
	set(value):
		color = value
		queue_redraw()

@export var height: float = 64.0:
	set(value):
		height = value
		queue_redraw()

# --- Constants (Must match SettlementManager) ---
const TILE_WIDTH = 64
const TILE_HEIGHT = 32

func _ready() -> void:
	# Auto-grab data if attached to a BaseBuilding that has it
	if not data and get_parent().get("data"):
		data = get_parent().data
		Loggie.msg("IsoPlaceholder: Inherited data from parent: %s" % data.display_name).domain(LogDomains.SYSTEM).debug()

func _draw() -> void:
	if not data:
		# Draw a default 1x1 diamond if no data exists
		_draw_iso_box(Vector2i(1, 1), Color.GRAY)
		Loggie.msg("IsoPlaceholder: Drawing default 1x1 (data is null)").domain(LogDomains.SYSTEM).debug()
		return
		
	Loggie.msg("IsoPlaceholder: Drawing %s %s" % [data.display_name, data.grid_size]).domain(LogDomains.SYSTEM).debug()
	_draw_iso_box(data.grid_size, color)

func _draw_iso_box(size: Vector2i, base_color: Color) -> void:
	# 1. Calculate Dimensions
	var half_w = TILE_WIDTH * 0.5
	var half_h = TILE_HEIGHT * 0.5
	
	# Basis vectors for the grid
	var vec_x = Vector2(half_w, half_h)
	var vec_y = Vector2(-half_w, half_h)
	
	# Center the diamond at (0,0)
	# The geometric center of an MxN grid starting at Top Vertex (0,0) is:
	# center = (vec_x * M + vec_y * N) * 0.5
	# So to center at (0,0), we start at -center
	var origin_offset = (vec_x * float(size.x) + vec_y * float(size.y)) * 0.5
	
	var c_top = -origin_offset
	var c_right = c_top + (vec_x * float(size.x))
	var c_bottom = origin_offset
	var c_left = c_top + (vec_y * float(size.y))
	
	# 3. Define the Roof (Base shifted up by height)
	var roof_offset = Vector2(0, -height)
	var r_top = c_top + roof_offset
	var r_right = c_right + roof_offset
	var r_bottom = c_bottom + roof_offset
	var r_left = c_left + roof_offset
	
	# --- DRAWING ---
	
	# A. Left Wall (Darkest)
	var wall_left_pts = PackedVector2Array([c_left, c_bottom, r_bottom, r_left])
	draw_colored_polygon(wall_left_pts, base_color.darkened(0.4))
	draw_polyline(wall_left_pts, Color.BLACK, 2.0)
	
	# B. Right Wall (Medium)
	var wall_right_pts = PackedVector2Array([c_bottom, c_right, r_right, r_bottom])
	draw_colored_polygon(wall_right_pts, base_color.darkened(0.2))
	draw_polyline(wall_right_pts, Color.BLACK, 2.0)
	
	# C. Roof (Lightest)
	var roof_pts = PackedVector2Array([r_left, r_bottom, r_right, r_top])
	draw_colored_polygon(roof_pts, base_color)
	draw_polyline(roof_pts, Color.BLACK, 2.0)
	
	# D. Footprint Outline
	var base_pts = PackedVector2Array([c_top, c_right, c_bottom, c_left, c_top])
	draw_polyline(base_pts, Color.WHITE.darkened(0.5), 1.0)
	
	# E. DEBUG CROSSHAIR (Center of node)
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color.RED, 2.0)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color.RED, 2.0)
