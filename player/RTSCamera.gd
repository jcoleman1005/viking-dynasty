# res://player/RTSCamera.gd
# Basic RTS-style camera controller for Phase 3
# Provides WASD movement and mouse edge panning
# Keeps camera controls simple and focused on tactical gameplay

extends Camera2D
class_name RTSCamera

@export var camera_speed: float = 400.0
@export var edge_pan_margin: float = 20.0
@export var enable_edge_panning: bool = true
@export var enable_wasd_movement: bool = true

# Movement bounds to keep camera on battlefield
@export var bounds_enabled: bool = false
@export var bounds_rect: Rect2 = Rect2(-500, -500, 1500, 1200)

func _ready() -> void:
	# Make this the current camera
	make_current()

func _process(delta: float) -> void:
	var movement_vector := Vector2.ZERO
	
	# WASD camera movement (as specified in GDD Phase 3)
	if enable_wasd_movement:
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
			movement_vector.x -= 1
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
			movement_vector.x += 1
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
			movement_vector.y -= 1
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
			movement_vector.y += 1
	
	# Mouse edge panning (common RTS feature)
	if enable_edge_panning:
		var mouse_pos = get_viewport().get_mouse_position()
		var viewport_size = get_viewport().get_visible_rect().size
		
		if mouse_pos.x <= edge_pan_margin:
			movement_vector.x -= 1
		elif mouse_pos.x >= viewport_size.x - edge_pan_margin:
			movement_vector.x += 1
			
		if mouse_pos.y <= edge_pan_margin:
			movement_vector.y -= 1
		elif mouse_pos.y >= viewport_size.y - edge_pan_margin:
			movement_vector.y += 1
	
	# Apply movement
	if movement_vector != Vector2.ZERO:
		movement_vector = movement_vector.normalized()
		global_position += movement_vector * camera_speed * delta
		
		# Apply bounds if enabled
		if bounds_enabled:
			global_position.x = clamp(global_position.x, bounds_rect.position.x, bounds_rect.position.x + bounds_rect.size.x)
			global_position.y = clamp(global_position.y, bounds_rect.position.y, bounds_rect.position.y + bounds_rect.size.y)
