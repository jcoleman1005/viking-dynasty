# res://scenes/world_map/MacroCamera.gd
# Upgraded with Zoom and Edge Panning
extends Camera2D 
class_name MacroCamera

# --- Movement Settings ---
@export_group("Movement")
@export var camera_speed: float = 500.0
@export var edge_pan_margin: float = 20.0
@export var enable_edge_panning: bool = true
@export var enable_keyboard_movement: bool = true

# --- Zoom Settings ---
@export_group("Zoom")
@export var min_zoom: float = 0.5  # Far away
@export var max_zoom: float = 2.0  # Close up
@export var zoom_speed: float = 0.1
@export var zoom_smoothing: float = 10.0

# --- Bounds Settings ---
@export_group("Bounds")
@export var bounds_enabled: bool = true 
@export var bounds_rect: Rect2 = Rect2(0, 0, 1920, 1080)

# Internal State
var target_zoom: Vector2 = Vector2.ONE
var is_dragging: bool = false
var drag_start_pos: Vector2

func _ready() -> void:
	target_zoom = zoom
	make_current()

func snap_to_target(target_position: Vector2) -> void:
	global_position = target_position
	_clamp_camera_to_bounds()

func _process(delta: float) -> void:
	# 1. Apply Smooth Zoom
	zoom = zoom.lerp(target_zoom, zoom_smoothing * delta)
	
	# 2. Handle Movement
	if not is_dragging:
		_handle_movement(delta)
		
	# 3. Clamp Bounds
	_clamp_camera_to_bounds()

func _handle_movement(delta: float) -> void:
	var movement_vector := Vector2.ZERO
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Keyboard Movement
	if enable_keyboard_movement:
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			movement_vector.x -= 1
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			movement_vector.x += 1
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			movement_vector.y -= 1
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			movement_vector.y += 1
	
	# Edge Panning
	if enable_edge_panning:
		if mouse_pos.x <= edge_pan_margin:
			movement_vector.x -= 1
		elif mouse_pos.x >= viewport_size.x - edge_pan_margin:
			movement_vector.x += 1
		if mouse_pos.y <= edge_pan_margin:
			movement_vector.y -= 1
		elif mouse_pos.y >= viewport_size.y - edge_pan_margin:
			movement_vector.y += 1
	
	# Apply Movement
	if movement_vector != Vector2.ZERO:
		movement_vector = movement_vector.normalized()
		# Adjust speed based on zoom (move faster when zoomed out)
		var zoom_multiplier = 1.0 / zoom.x
		global_position += movement_vector * camera_speed * zoom_multiplier * delta

func _unhandled_input(event: InputEvent) -> void:
	# Zoom Controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
			get_viewport().set_input_as_handled()
			
		# Middle-Mouse Drag
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
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

func _zoom_in() -> void:
	target_zoom += Vector2(zoom_speed, zoom_speed)
	_clamp_zoom()

func _zoom_out() -> void:
	target_zoom -= Vector2(zoom_speed, zoom_speed)
	_clamp_zoom()

func _clamp_zoom() -> void:
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

func _clamp_camera_to_bounds() -> void:
	if bounds_enabled:
		# Adjust bounds based on zoom to prevent seeing outside the map
		var view_size = get_viewport_rect().size / zoom
		var min_x = bounds_rect.position.x + view_size.x / 2
		var max_x = bounds_rect.end.x - view_size.x / 2
		var min_y = bounds_rect.position.y + view_size.y / 2
		var max_y = bounds_rect.end.y - view_size.y / 2
		
		# Only clamp if the map is larger than the view
		if min_x < max_x: global_position.x = clamp(global_position.x, min_x, max_x)
		if min_y < max_y: global_position.y = clamp(global_position.y, min_y, max_y)
