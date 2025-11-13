# res://scenes/world_map/Region.gd
class_name Region
extends Area2D

# Signals to notify the MacroMap controller
signal region_hovered(data: WorldRegionData, screen_position: Vector2)
signal region_exited()
signal region_selected(data: WorldRegionData)

# The data resource representing this province
@export var data: WorldRegionData

# Reference to the visual polygon (Source of Truth)
@onready var highlight_poly: Polygon2D = get_node_or_null("HighlightPoly")
# Reference to the collision polygon (Target)
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D")

# Visual Settings
var default_color: Color = Color(0, 0, 0, 0)       # Invisible
var hover_color: Color = Color(1.0, 1.0, 1.0, 0.2) # Faint White
var selected_color: Color = Color(1.0, 0.9, 0.2, 0.4) # Yellowish

var is_selected: bool = false

func _ready() -> void:
	# 1. Data Validation
	if not data:
		push_error("Region node '%s' has no WorldRegionData assigned!" % name)
		return
	
	# 2. Node Validation & Sync
	if not highlight_poly:
		push_error("Region '%s' is missing 'HighlightPoly' (Polygon2D)." % name)
		return
		
	if not collision_poly:
		# Optional: Create it if it doesn't exist
		collision_poly = CollisionPolygon2D.new()
		collision_poly.name = "CollisionPolygon2D"
		add_child(collision_poly)
		print("Region '%s': Created missing CollisionPolygon2D." % name)
	
	# --- THE MAGIC FIX ---
	_sync_collision_shape()
	# ---------------------
	
	# 3. Input Connection
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	# 4. Initial State
	set_visual_state(false)

func _sync_collision_shape() -> void:
	"""Copies points from the Visual Polygon to the Collision Polygon."""
	if not highlight_poly: return
	
	if highlight_poly.polygon.is_empty():
		push_warning("Region '%s': HighlightPoly has no points!" % name)
		return
	
	# --- DEBUG PRINT ---
	print("Region: Syncing shape for '%s' (%d points)..." % [name, highlight_poly.polygon.size()])
	# -------------------

	# Copy the points over
	collision_poly.polygon = highlight_poly.polygon
	
	# Ensure positions match
	collision_poly.position = highlight_poly.position
	collision_poly.scale = highlight_poly.scale

func set_visual_state(is_hovered: bool) -> void:
	if not highlight_poly: return
		
	var target_color: Color
	
	if is_selected:
		target_color = selected_color
		highlight_poly.visible = true
	elif is_hovered:
		target_color = hover_color
		highlight_poly.visible = true
	else:
		target_color = default_color
		highlight_poly.visible = false 
		
	var tween = create_tween()
	tween.tween_property(highlight_poly, "color", target_color, 0.1)

# --- Signal Handlers ---

func _on_mouse_entered() -> void:
	if not is_selected:
		set_visual_state(true)
	emit_signal("region_hovered", data, get_global_mouse_position())

func _on_mouse_exited() -> void:
	if not is_selected:
		set_visual_state(false)
	emit_signal("region_exited")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_selected = true
		set_visual_state(true)
		emit_signal("region_selected", data)
		get_viewport().set_input_as_handled()
func get_global_center() -> Vector2:
	# If no poly, fallback to node position
	if not collision_poly or collision_poly.polygon.is_empty():
		return global_position
		
	var sum_points = Vector2.ZERO
	for point in collision_poly.polygon:
		sum_points += point
		
	var local_center = sum_points / collision_poly.polygon.size()
	
	# Apply the node's transform (position/scale/rotation) to get world coords
	return to_global(local_center)
	
