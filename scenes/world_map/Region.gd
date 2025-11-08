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
	
	# Debug collision shape
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		print("Region '%s' - CollisionShape2D found!" % name)
		print("  Shape: %s" % collision_shape.shape)
		if collision_shape.shape:
			print("  Shape type: %s" % collision_shape.shape.get_class())
			# Check the actual size
			if collision_shape.shape is RectangleShape2D:
				print("  Rectangle size: %s" % collision_shape.shape.size)
			elif collision_shape.shape is CircleShape2D:
				print("  Circle radius: %s" % collision_shape.shape.radius)
		else:
			push_error("  ERROR: Shape is NULL!")
	else:
		push_error("Region '%s' - CollisionShape2D NOT FOUND!" % name)
	
	print("Region '%s' initialized at position: %s" % [name, global_position])
	print("  - Input Pickable: %s" % input_pickable)
	print("  - Monitoring: %s" % monitoring)
	print("  - Monitorable: %s" % monitorable)
	
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

# Debug: Track ALL mouse clicks globally
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen_pos = get_viewport().get_mouse_position()
		var world_pos = get_global_mouse_position()
		var canvas_pos = get_canvas_transform().affine_inverse() * screen_pos
		print("=== LEFT CLICK DETECTED ===")
		print("  Screen position: %s" % screen_pos)
		print("  World position (get_global_mouse): %s" % world_pos)
		print("  Canvas position (corrected): %s" % canvas_pos)
		print("  Region '%s' position: %s" % [name, global_position])
		print("  Distance to region (world): %s" % global_position.distance_to(world_pos))
		print("  Distance to region (canvas): %s" % global_position.distance_to(canvas_pos))

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
	print("Mouse entered region: %s" % data.display_name)
	set_visual_state(true)
	emit_signal("region_hovered", data, get_global_mouse_position())

func _on_mouse_exited() -> void:
	print("Mouse exited region: %s" % data.display_name)
	set_visual_state(false)
	emit_signal("region_exited")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	print("Input event in region: %s, event: %s" % [data.display_name, event])
	# Check for left mouse button click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Region clicked: %s" % data.display_name)
		is_selected = true
		set_visual_state(true)
		emit_signal("region_selected", data)
		get_viewport().set_input_as_handled()
