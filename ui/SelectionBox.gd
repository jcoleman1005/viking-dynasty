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

# --- NEW: Formation Drag ---
var is_command_dragging := false
var command_start_pos := Vector2.ZERO
# ---------------------------

func _ready() -> void:
	# This node handles its own input via _gui_input,
	# so it doesn't need to connect to the EventRouter.
	pass

func _gui_input(event: InputEvent) -> void:
	# We use _gui_input, which is only called if the mouse
	# is over this Control. Since it's fullscreen,
	# this will always be the case.
	
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
		
		# --- MODIFIED: Handle Right Click Drag ---
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				is_command_dragging = true
				command_start_pos = get_local_mouse_position()
				accept_event()
			else: # On Right-Click Release
				if not is_command_dragging:
					# This can happen if the click started outside the window
					# and was released inside. Ignore it.
					return
					
				is_command_dragging = false
				var end_pos = get_local_mouse_position()
				var drag_vector = end_pos - command_start_pos
				
				var main_camera: Camera2D = get_viewport().get_camera_2d()
				if not main_camera: 
					push_error("SelectionBox: No Camera2D found.")
					return

				# Convert screen positions to world
				# We use get_global_mouse_position() for the *end*
				# and calculate the start based on the drag vector
				var world_end_pos = main_camera.get_global_mouse_position()
				var world_start_pos = world_end_pos - (drag_vector / main_camera.zoom)
				
				# Check if it was a drag or just a click
				if drag_vector.length_squared() > 225: # 15px drag threshold
					# It was a drag. Emit formation move.
					# The direction is from start to end
					var world_drag_vector = (world_end_pos - world_start_pos).normalized()
					EventBus.formation_move_command.emit(world_start_pos, world_drag_vector)
				else:
					# It was a click. Do smart command.
					_handle_smart_command(end_pos)
					
				queue_redraw() # Clear drag line
				accept_event()
		# -----------------------------------------
	
	elif event is InputEventMouseMotion:
		if is_dragging or is_command_dragging:
			# Update the draw loop as the mouse moves
			queue_redraw()
			accept_event()

func _handle_smart_command(screen_pos: Vector2) -> void:
	# This function determines if a right-click
	# is a "move" or "attack" command.
	var world_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	
	if not main_camera:
		push_error("SelectionBox: No Camera2D found in viewport.")
		return
		
	# Convert screen position to world position
	var world_pos: Vector2 = main_camera.get_global_mouse_position()
	
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# We only want to hit "enemy" things
	# GDD: "right-click is the 'smart' command (move on ground, attack on enemy)"
	# We assume layer 2 is "enemy_units" and layer 3 is "enemy_buildings"
	query.collision_mask = 6 # (Binary 0110 = Layers 2 and 3)
	
	var results: Array = world_space.intersect_point(query)
	
	if not results.is_empty():
		# We hit an enemy! Emit an attack command.
		var target = results[0].collider
		EventBus.emit_signal("attack_command", target)
	else:
		# We hit the ground. Emit a move command.
		EventBus.emit_signal("move_command", world_pos)

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
