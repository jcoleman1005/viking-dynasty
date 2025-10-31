# res://player/RTSController.gd
# RTS input controller for Phase 3
# GDD Ref: Phase 3 Task 5

extends Node

# Selection System
var selected_units: Array[Node2D] = []
var selection_box_start: Vector2 = Vector2.ZERO
var is_dragging: bool = false

# Input State
var left_mouse_pressed: bool = false

# Camera reference for screen-to-world conversion
@onready var camera: Camera2D = get_viewport().get_camera_2d()

# Selection box visual
var selection_rect: Rect2 = Rect2()

func _ready() -> void:
	# Ensure we can draw
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start selection or single select
			left_mouse_pressed = true
			selection_box_start = event.global_position
			is_dragging = false
			queue_redraw()
		else:
			# End selection
			left_mouse_pressed = false
			if is_dragging:
				_complete_box_selection()
				is_dragging = false
			else:
				_single_select(event.global_position)
			queue_redraw()
	
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click(event.global_position)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if left_mouse_pressed:
		var drag_distance = event.global_position.distance_to(selection_box_start)
		if drag_distance > 5.0: # Minimum drag distance to start box selection
			is_dragging = true
			_update_selection_box(event.global_position)
			queue_redraw()

func _update_selection_box(current_pos: Vector2) -> void:
	var top_left = Vector2(
		min(selection_box_start.x, current_pos.x),
		min(selection_box_start.y, current_pos.y)
	)
	var bottom_right = Vector2(
		max(selection_box_start.x, current_pos.x),
		max(selection_box_start.y, current_pos.y)
	)
	selection_rect = Rect2(top_left, bottom_right - top_left)

func _single_select(screen_pos: Vector2) -> void:
	# Select a single unit at the click position
	var world_pos = _screen_to_world(screen_pos)
	var space_state = get_world_2d().direct_space_state
	
	# Create a small area query around the click point
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 1 # Assuming units are on layer 1
	
	var results = space_state.intersect_point(query, 1)
	
	# Clear previous selection
	_clear_selection()
	
	# Check if we clicked on a unit
	for result in results:
		var body = result["collider"]
		if _is_player_unit(body):
			_add_to_selection(body)
			break

func _complete_box_selection() -> void:
	# Complete box selection and select all units in the box
	var world_rect = _screen_rect_to_world(selection_rect)
	var units_in_box = _get_units_in_rect(world_rect)
	
	# Clear previous selection
	_clear_selection()
	
	# Add all units in box to selection
	for unit in units_in_box:
		if _is_player_unit(unit):
			_add_to_selection(unit)

func _get_units_in_rect(rect: Rect2) -> Array:
	# Get all units whose positions are within the given rectangle
	var units_in_rect: Array = []
	
	# Find all units in the scene
	var units = get_tree().get_nodes_in_group("player_units")
	
	for unit in units:
		if unit is Node2D and rect.has_point(unit.global_position):
			units_in_rect.append(unit)
	
	return units_in_rect

func _handle_right_click(screen_pos: Vector2) -> void:
	# Handle right mouse click for movement/attack commands
	if selected_units.is_empty():
		return
	
	var world_pos = _screen_to_world(screen_pos)
	var target = _get_target_at_position(screen_pos)
	
	if target and _is_enemy_unit(target):
		# Attack command
		print("Commanding %d units to attack %s" % [selected_units.size(), target.name])
		for unit in selected_units:
			if unit.has_method("command_attack"):
				unit.fsm.command_attack(target)
	else:
		# Move command
		print("Commanding %d units to move to %s" % [selected_units.size(), world_pos])
		for unit in selected_units:
			if unit.has_method("command_move_to"):
				unit.fsm.command_move_to(world_pos)

func _get_target_at_position(screen_pos: Vector2) -> Node2D:
	# Get the target (enemy unit/building) at the given screen position
	var world_pos = _screen_to_world(screen_pos)
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 2 # Assuming enemies are on layer 2
	
	var results = space_state.intersect_point(query, 1)
	
	for result in results:
		var body = result["collider"]
		if _is_enemy_unit(body):
			return body
	
	return null

func _is_player_unit(node: Node) -> bool:
	# Check if the node is a player unit
	return node.is_in_group("player_units") and node.has_method("command_move_to")

func _is_enemy_unit(node: Node) -> bool:
	# Check if the node is an enemy unit or building
	return node.is_in_group("enemy_units") or node.is_in_group("enemy_buildings")

func _clear_selection() -> void:
	# Clear all selected units
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)
	selected_units.clear()
	print("Selection cleared")

func _add_to_selection(unit: Node2D) -> void:
	# Add a unit to the selection
	if unit not in selected_units:
		selected_units.append(unit)
		if unit.has_method("set_selected"):
			unit.set_selected(true)
		print("Added %s to selection. Total selected: %d" % [unit.name, selected_units.size()])

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convert screen position to world position
	if camera:
		return camera.get_global_mouse_position()
	else:
		return get_global_mouse_position()

func _screen_rect_to_world(screen_rect: Rect2) -> Rect2:
	# Convert screen rectangle to world rectangle
	var top_left = _screen_to_world(screen_rect.position)
	var bottom_right = _screen_to_world(screen_rect.position + screen_rect.size)
	return Rect2(top_left, bottom_right - top_left)

func _draw() -> void:
	# Draw the selection box if dragging
	if is_dragging and selection_rect.size.length() > 0:
		# Draw selection box
		var color = Color.YELLOW
		color.a = 0.3
		draw_rect(selection_rect, color)
		draw_rect(selection_rect, Color.YELLOW, false, 2.0)

# --- Unit Management ---

func add_unit_to_group(unit: Node2D) -> void:
	# Add a unit to the player_units group for selection
	unit.add_to_group("player_units")
	print("Added %s to player_units group" % unit.name)

func remove_unit_from_group(unit: Node2D) -> void:
	# Remove a unit from selection and groups
	if unit in selected_units:
		selected_units.erase(unit)
	unit.remove_from_group("player_units")
