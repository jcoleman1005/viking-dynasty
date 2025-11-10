# res://scenes/world_map/Region.gd
#
# Attached to an Area2D node to make a map province
# clickable and interactive.
class_name Region
extends Area2D

signal region_hovered(data: WorldRegionData, screen_position: Vector2)
signal region_exited()
signal region_selected(data: WorldRegionData)

@export var data: WorldRegionData

# Normally, we'd use a Sprite2d, but for now we'll just use a colorrect
@onready var sprite = $Sprite2D

var default_color: Color = Color(1.0, 1.0, 1.0, 0.2)
var hover_color: Color = Color(1.0, 1.0, 1.0, 0.6)
var selected_color: Color = Color(1.0, 0.9, 0.2, 0.8) # Yellow

var is_selected: bool = false

func _ready() -> void:
	if not data:
		push_error("Region node '%s' has no WorldRegionData assigned!" % name)
		queue_free()
		return
	
	# Essential error checking for collision shapes
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape:
		push_error("Region '%s' - CollisionShape2D NOT FOUND!" % name)
	elif not collision_shape.shape:
		push_error("Region '%s' - CollisionShape2D shape is NULL!" % name)
	
	# Connect to our own signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	if sprite:
		sprite.material = CanvasItemMaterial.new()
		sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		set_visual_state(false)
	else:
		push_warning("Region node '%s' is missing its $Sprite2D child." % name)

func set_visual_state(is_hovered: bool) -> void:
	if not sprite:
		return
		
	var target_color: Color
	if is_selected:
		target_color = selected_color
	elif is_hovered:
		target_color = hover_color
	else:
		target_color = default_color
		
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", target_color, 0.1).set_trans(Tween.TRANS_SINE)

func _on_mouse_entered() -> void:
	set_visual_state(true)
	emit_signal("region_hovered", data, get_global_mouse_position())

func _on_mouse_exited() -> void:
	set_visual_state(false)
	emit_signal("region_exited")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Check for left mouse button click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_selected = true
		set_visual_state(true)
		emit_signal("region_selected", data)
		get_viewport().set_input_as_handled()
