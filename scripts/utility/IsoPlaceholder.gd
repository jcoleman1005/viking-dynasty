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

func _draw() -> void:
	if not data:
		# Draw a default 1x1 diamond if no data exists
		_draw_iso_box(Vector2i(1, 1), Color.GRAY)
		return
		
	_draw_iso_box(data.grid_size, color)

func _draw_iso_box(size: Vector2i, base_color: Color) -> void:
	# 1. Calculate Dimensions
	# In Isometric, the "Width" of the visual sprite is based on grid columns
	var half_w = TILE_WIDTH * 0.5
	var half_h = TILE_HEIGHT * 0.5
	
	# Because our system centers the node on the "Footprint Center", 
	# we calculate offsets from (0,0).
	
	# Total pixel dimensions of the footprint
	var total_w = (size.x + size.y) * half_w
	var total_h = (size.x + size.y) * half_h
	
	# 2. Define the 4 Corners of the Base (Footprint) relative to Center
	# Top Tip
	var p_top = Vector2(0, -total_h * 0.5) 
	# Right Tip
	var p_right = Vector2(total_w * 0.5, 0)
	# Bottom Tip
	var p_bottom = Vector2(0, total_h * 0.5)
	# Left Tip
	var p_left = Vector2(-total_w * 0.5, 0)
	
	# Note: The math above assumes a perfectly square bounding box. 
	# For strict Grid sizing (e.g. 2x1 buildings), we use the projection logic:
	
	# Let's do it strictly by vector addition to support non-square buildings (e.g. 3x1 walls)
	# Vector X moves (32, 16). Vector Y moves (-32, 16).
	var vec_x = Vector2(half_w, half_h) # Down-Right
	var vec_y = Vector2(-half_w, half_h) # Down-Left
	
	# Start at Top Tip (which is offset by half the total size to center it)
	var top_origin = -((vec_x * size.x) + (vec_y * size.y)) * 0.5
	
	var c_top = top_origin
	var c_right = top_origin + (vec_x * size.x)
	var c_bottom = top_origin + (vec_x * size.x) + (vec_y * size.y)
	var c_left = top_origin + (vec_y * size.y)
	
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
	
	# D. Footprint Outline (Optional - shows grid alignment)
	var base_pts = PackedVector2Array([c_top, c_right, c_bottom, c_left, c_top])
	draw_polyline(base_pts, Color.WHITE.darkened(0.5), 1.0)
