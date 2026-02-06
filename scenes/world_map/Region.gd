#res://scenes/world_map/Region.gd
# res://scenes/world_map/Region.gd
class_name Region
extends Area2D

# Signals
signal region_hovered(data: WorldRegionData, screen_position: Vector2)
signal region_exited()
signal region_selected(data: WorldRegionData)

# Data
@export var data: WorldRegionData

# Node Refs
@onready var highlight_poly: Polygon2D = get_node_or_null("HighlightPoly")
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D")

# --- Visual Settings ---
var default_color: Color = Color(0, 0, 0, 0)       # Invisible
var hover_color: Color = Color(1.0, 1.0, 1.0, 0.2) # Faint White
var selected_color: Color = Color(1.0, 0.9, 0.2, 0.4) # Yellowish

# --- NEW: Status Colors ---
var home_color: Color = Color(0.2, 0.4, 0.8, 0.25) # Royal Blue (Owned)
var allied_hover_color: Color = Color(0.2, 0.8, 1.0, 0.3) # Cyan (Friendly)
# --------------------------

# --- State Flags ---
var is_selected: bool = false
var is_home: bool = false   # Is this the player's starting region?
var is_allied: bool = false # Is this region allied via marriage?

func _ready() -> void:
	if not data:
		push_error("Region node '%s' has no WorldRegionData!" % name)
		return
	
	if not highlight_poly:
		push_error("Region '%s' missing 'HighlightPoly'." % name)
		return
		
	if not collision_poly:
		collision_poly = CollisionPolygon2D.new()
		collision_poly.name = "CollisionPolygon2D"
		add_child(collision_poly)
	
	_sync_collision_shape()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	set_visual_state(false)

func _sync_collision_shape() -> void:
	if not highlight_poly or highlight_poly.polygon.is_empty(): return
	collision_poly.polygon = highlight_poly.polygon
	collision_poly.position = highlight_poly.position
	collision_poly.scale = highlight_poly.scale

# --- VISUAL STATE LOGIC ---
func set_visual_state(is_hovered: bool) -> void:
	if not highlight_poly: return
		
	var target_color: Color
	var should_be_visible = true
	
	if is_selected:
		target_color = selected_color
	
	elif is_hovered:
		if is_allied:
			target_color = allied_hover_color
		else:
			target_color = hover_color
			
	elif is_home:
		target_color = home_color
		
	else:
		# Default state (Unknown/Neutral)
		target_color = default_color
		should_be_visible = false
		
	highlight_poly.visible = should_be_visible
		
	var tween = create_tween()
	tween.tween_property(highlight_poly, "color", target_color, 0.15)

# --- Input Handlers ---
func _on_mouse_entered() -> void:
	if not is_selected: set_visual_state(true)
	emit_signal("region_hovered", data, get_global_mouse_position())

func _on_mouse_exited() -> void:
	if not is_selected: set_visual_state(false)
	emit_signal("region_exited")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_selected = true
		set_visual_state(true)
		emit_signal("region_selected", data)
		get_viewport().set_input_as_handled()

func get_global_center() -> Vector2:
	if not collision_poly or collision_poly.polygon.is_empty():
		return global_position
	var sum = Vector2.ZERO
	for p in collision_poly.polygon: sum += p
	return to_global(sum / collision_poly.polygon.size())
