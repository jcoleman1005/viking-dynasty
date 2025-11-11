# res://scenes/world_map/MacroCamera.gd
#
# Camera controller for the Macro Map.
# Implements WASD and Middle-Mouse-Drag panning
# with boundaries.
extends Camera2D 
class_name MacroCamera

@export var camera_speed: float = 500.0
@export var bounds_enabled: bool = true 
@export var bounds_rect: Rect2 = Rect2(0, 0, 1920, 1080)

var is_dragging: bool = false
var drag_start_pos: Vector2

func _ready() -> void:
	make_current()

func _process(delta: float) -> void:
	var movement_vector := Vector2.ZERO
	
	# WASD camera movement [cite: 471]
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		movement_vector.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		movement_vector.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		movement_vector.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		movement_vector.y += 1
	
	if movement_vector != Vector2.ZERO:
		global_position += movement_vector.normalized() * camera_speed * delta
		
	# Apply clamping
	_clamp_camera_to_bounds()

func _unhandled_input(event: InputEvent) -> void:
	# Middle-Mouse-Drag Panning [cite: 472]
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				is_dragging = true
				drag_start_pos = get_global_mouse_position() - global_position
				get_viewport().set_input_as_handled()
			else:
				is_dragging = false
				get_viewport().set_input_as_handled()
				
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_start_pos
		_clamp_camera_to_bounds()
		get_viewport().set_input_as_handled()

func _clamp_camera_to_bounds() -> void:
	if bounds_enabled:
		global_position.x = clamp(global_position.x, bounds_rect.position.x, bounds_rect.end.x)
		global_position.y = clamp(global_position.y, bounds_rect.position.y, bounds_rect.end.y)
