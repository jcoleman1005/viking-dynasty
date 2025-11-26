# res://ui/SelectionBox.gd
# This Control node covers the entire screen.
# It listens for
# raw input, draws the selection box, and emits clean,
# intent-based signals to the EventBus.
# It also uses
# accept_event() to stop input from passing through the UI.
extends Control
var is_dragging := false
var start_pos := Vector2.ZERO
var is_command_dragging := false
var command_start_pos := Vector2.ZERO
# ---------------------------

func _ready() -> void:
	# Allow unused mouse events (like Zoom) to pass to the Camera
	# but DON'T consume mouse events here; let other UI handle them
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	# We use _gui_input, which is only called if the mouse
	# is over this Control. Since it's fullscreen,
	# this will always be the case.
	if event is InputEventMouseButton and event.pressed:
		print("DEBUG: SelectionBox received click! Button: ", event.button_index)
	if event is InputEventMouseButton:
		# --- DEBUG: Print ALL mouse button events ---
		var state = "DOWN" if event.pressed else "UP"
		print("DEBUG: Mouse Btn ", event.button_index, " is ", state)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				is_dragging = true
				start_pos = get_local_mouse_position()
				# This is the UI-bug-fix. We consume the
				# event so nothing else can process it.
				accept_event()
			elif is_dragging: # On Left-Click Release
				is_dragging = false
				var end_pos := get_local_mouse_position()
				var rect := Rect2(start_pos, end_pos - start_pos).abs()
				
				# Check if it was a "drag" or just a "click"
				# A 'click' is a box with a very small area.
				var is_box_select = rect.size.length_squared() > 100 # 10x10 px
				
				# Emit the clean command for the RTSController
				EventBus.emit_signal("select_command", rect, is_box_select)
				
				queue_redraw() # Clear the box
				accept_event()
		
	# Right Click Handling
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				is_command_dragging = true
				command_start_pos = get_local_mouse_position()
				accept_event()
			else: # On Release
				if not is_command_dragging: return
				is_command_dragging = false
				
				var end_pos = get_local_mouse_position()
				var drag_vector = end_pos - command_start_pos
				
				# Check for drag vs click
				if drag_vector.length_squared() > 225:
					# Drag Logic (Formation)
					var main_camera = get_viewport().get_camera_2d()
					if main_camera:
						var world_end = main_camera.get_global_mouse_position()
						var world_start = world_end - (drag_vector / main_camera.zoom)
						var dir = (world_end - world_start).normalized()
						EventBus.formation_move_command.emit(world_start, dir)
				else:
					# Click Logic (Smart Command)
					_handle_smart_command(end_pos)
					
				queue_redraw()
				accept_event()
				
	elif event is InputEventMouseMotion:
		if is_dragging or is_command_dragging:
			# Update the draw loop as the mouse moves
			queue_redraw()
			accept_event()

func _handle_smart_command(_screen_pos: Vector2) -> void:
	var world_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	
	if not main_camera: return
		
	var world_pos: Vector2 = main_camera.get_global_mouse_position()
	
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# 1 (Friendly/Env) + 4 (Enemy Unit) + 8 (Enemy Building) = 13
	query.collision_mask = 13 
	
	var results: Array = world_space.intersect_point(query)
	
	if not results.is_empty():
		var hit_object = results[0].collider
		print("DEBUG: Raycast hit ", hit_object.name, " (Type: ", hit_object.get_class(), ")")
		
		# --- RESOLVE TARGET ---
		# If we hit the child "Hitbox", bubble up to the parent Building
		var final_target = hit_object
		if hit_object.name == "Hitbox" and hit_object.get_parent() is BaseBuilding:
			final_target = hit_object.get_parent()
			print("DEBUG: Bubbled up to parent building: ", final_target.name)
		# ----------------------
		
		# Check Layer 1 (Friendly) AND Type
		if final_target.collision_layer == 1 and final_target is BaseBuilding:
			print("DEBUG: Friendly Building detected. INTERACT.")
			EventBus.interact_command.emit(final_target)
		else:
			print("DEBUG: Enemy/Other detected. ATTACK.")
			EventBus.attack_command.emit(final_target)
	else:
		print("DEBUG: Ground clicked. MOVE.")
		EventBus.move_command.emit(world_pos)
		
func _draw() -> void:
	# This function draws the selection box
	if is_dragging:
		var current_pos := get_local_mouse_position()
		var rect := Rect2(start_pos, current_pos - start_pos).abs()
		
		# Draw a semi-transparent fill
		draw_rect(rect, Color(0.8, 0.8, 1.0, 0.2), true)
		# Draw a solid outline
		draw_rect(rect, Color(0.8, 0.8, 1.0, 1.0), false, 1.0)
	
	# --- NEW: Draw command drag line ---
	if is_command_dragging:
		var current_pos := get_local_mouse_position()
		draw_line(command_start_pos, current_pos, Color.GREEN, 2.0)
		draw_circle(command_start_pos, 5.0, Color.GREEN)
		draw_circle(current_pos, 3.0, Color.GREEN)
	# ----------------------------------
