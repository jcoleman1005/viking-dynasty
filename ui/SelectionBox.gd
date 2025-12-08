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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				# 1. Try to pick a building first
				if _try_select_building(get_local_mouse_position()):
					accept_event()
					return
				
				# 2. If no building, start drag selection
				is_dragging = true
				start_pos = get_local_mouse_position()
				accept_event()
				
				# Clear previous building selection when clicking ground
				EventBus.building_deselected.emit()
				
			elif is_dragging: # Release
				is_dragging = false
				var end_pos := get_local_mouse_position()
				var rect := Rect2(start_pos, end_pos - start_pos).abs()
				var is_box_select = rect.size.length_squared() > 100
				EventBus.select_command.emit(rect, is_box_select)
				queue_redraw()
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
	query.collision_mask = 13 # Layers 1, 4, 8
	
	var results: Array = world_space.intersect_point(query)
	
	if not results.is_empty():
		var hit_object = results[0].collider
		
		# Bubble up from Hitbox
		var final_target = hit_object
		if hit_object.name == "Hitbox" and hit_object.get_parent() is BaseBuilding:
			final_target = hit_object.get_parent()
		
		# 1. Friendly Building -> INTERACT
		if final_target.collision_layer == 1 and final_target is BaseBuilding:
			Loggie.msg("SelectionBox: Friendly interact.").domain("UI").debug()
			EventBus.interact_command.emit(final_target)
			
		# 2. Enemy Building -> CHECK MODIFIER
		elif final_target is BaseBuilding:
			if Input.is_key_pressed(KEY_CTRL):
				# CTRL Held: BURN (Attack)
				Loggie.msg("SelectionBox: CTRL held -> BURN command.").domain("UI").info()
				EventBus.attack_command.emit(final_target)
			else:
				# Normal Click: PILLAGE
				Loggie.msg("SelectionBox: Normal click -> PILLAGE command.").domain("UI").info()
				EventBus.pillage_command.emit(final_target)
				
		# 3. Enemy Unit -> ALWAYS ATTACK
		else:
			EventBus.attack_command.emit(final_target)
			
	else:
		EventBus.move_command.emit(world_pos)

func _try_select_building(screen_pos: Vector2) -> bool:
	var world_space = get_world_2d().direct_space_state
	var main_camera = get_viewport().get_camera_2d()
	if not main_camera: return false
	
	var world_pos = main_camera.get_global_mouse_position()
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_bodies = true
	query.collide_with_areas = true
	# Layer 1 (Player Building) + 9 (Hitboxes) usually. 
	# We check for objects that have the 'data' property or are BaseBuilding.
	query.collision_mask = 1 # Layer 1 is Environment/Player Buildings
	
	var results = world_space.intersect_point(query)
	
	for res in results:
		var collider = res.collider
		# Bubble up from Hitbox if needed
		if collider.name == "Hitbox" and collider.get_parent() is BaseBuilding:
			collider = collider.get_parent()
			
		if collider is BaseBuilding:
			EventBus.building_selected.emit(collider)
			return true
			
	return false
		
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
