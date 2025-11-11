# res://player/RTSCamera.gd
# Basic RTS-style camera controller for Phase 3
# Provides WASD movement, mouse edge panning, drag panning, and zooming.
# Keeps camera controls simple and focused on tactical gameplay.

extends Camera2D
class_name RTSCamera

# --- Movement Settings ---
@export_group("Movement")
@export var camera_speed: float = 400.0
@export var edge_pan_margin: float = 20.0
@export var enable_edge_panning: bool = true
@export var enable_wasd_movement: bool = true
@export var enable_drag_panning: bool = true

# --- Zoom Settings ---
@export_group("Zoom")
@export var min_zoom: float = 0.5  # Far away
@export var max_zoom: float = 2.0  # Close up
@export var zoom_speed: float = 0.1
@export var zoom_smoothing: float = 10.0

# --- Bounds Settings ---
@export_group("Bounds")
@export var bounds_enabled: bool = true
@export var bounds_rect: Rect2 = Rect2(-1000, -1000, 3000, 2500)

# Internal State
var target_zoom: Vector2 = Vector2.ONE
var is_dragging: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("RTS Camera Initialized") # Check your Output tab for this!
	# Initialize target zoom to current zoom
	target_zoom = zoom
	make_current()

func _unhandled_input(event: InputEvent) -> void:
	# --- Zoom Control (Mouse Wheel) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
			get_viewport().set_input_as_handled()
			
		# --- Drag Panning (Middle Mouse) ---
		elif event.button_index == MOUSE_BUTTON_MIDDLE and enable_drag_panning:
			if event.is_pressed():
				is_dragging = true
				drag_start_mouse_pos = get_viewport().get_mouse_position()
				drag_start_camera_pos = global_position
				get_viewport().set_input_as_handled()
			else:
				is_dragging = false
				get_viewport().set_input_as_handled()

	# --- Handle Drag Motion ---
	if event is InputEventMouseMotion and is_dragging:
		var current_mouse_pos = get_viewport().get_mouse_position()
		var mouse_delta = drag_start_mouse_pos - current_mouse_pos
		
		# Scale delta by zoom so dragging feels consistent at all zoom levels
		global_position = drag_start_camera_pos + (mouse_delta / zoom.x)
		
		_clamp_position()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# 1. Apply Smooth Zoom
	zoom = zoom.lerp(target_zoom, zoom_smoothing * delta)
	
	# 2. Handle Keyboard/Edge Movement (Only if not dragging)
	if not is_dragging:
		_handle_keyboard_movement(delta)

	# 3. Clamp Bounds
	_clamp_position()

func _handle_keyboard_movement(delta: float) -> void:
	var movement_vector := Vector2.ZERO
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	
	# WASD Movement
	if enable_wasd_movement:
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
		# Check X axis
		if mouse_pos.x <= edge_pan_margin:
			movement_vector.x -= 1
		elif mouse_pos.x >= viewport_size.x - edge_pan_margin:
			movement_vector.x += 1
			
		# Check Y axis
		if mouse_pos.y <= edge_pan_margin:
			movement_vector.y -= 1
		elif mouse_pos.y >= viewport_size.y - edge_pan_margin:
			movement_vector.y += 1
	
	# Apply Movement
	if movement_vector != Vector2.ZERO:
		movement_vector = movement_vector.normalized()
		# Adjust speed based on zoom level (faster when zoomed out)
		var zoom_multiplier = 1.0 / zoom.x
		global_position += movement_vector * camera_speed * zoom_multiplier * delta

func _zoom_in() -> void:
	target_zoom += Vector2(zoom_speed, zoom_speed)
	_clamp_zoom()

func _zoom_out() -> void:
	target_zoom -= Vector2(zoom_speed, zoom_speed)
	_clamp_zoom()

func _clamp_zoom() -> void:
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

func _clamp_position() -> void:
	if bounds_enabled:
		global_position.x = clamp(global_position.x, bounds_rect.position.x, bounds_rect.end.x)
		global_position.y = clamp(global_position.y, bounds_rect.position.y, bounds_rect.end.y)
