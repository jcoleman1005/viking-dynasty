# res://scripts/player/RTSController.gd
extends Node2D

# --- Properties ---
var selected_units: Array[Node2D] = []
var selection_box_start: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var selection_box: Rect2

# We need a reference to the camera to convert screen to world coordinates
@onready var camera: Camera2D = get_viewport().get_camera_2d()

func _unhandled_input(event: InputEvent) -> void:
	# --- Left Mouse Button for Selection ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# Start dragging for box selection
			is_dragging = true
			selection_box_start = get_global_mouse_position()
			selection_box = Rect2(selection_box_start, Vector2.ZERO)
		elif is_dragging:
			# End dragging
			is_dragging = false
			_perform_box_selection()
			# Force a redraw to clear the box
			queue_redraw()

	# --- Mouse Motion for Dragging ---
	if event is InputEventMouseMotion and is_dragging:
		var current_mouse_pos = get_global_mouse_position()
		selection_box = Rect2(selection_box_start, current_mouse_pos - selection_box_start).abs()
		# Force a redraw to show the box
		queue_redraw()

	# --- Right Mouse Button for Commands ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		if not selected_units.is_empty():
			_process_smart_command(get_global_mouse_position())

func _draw() -> void:
	"""Draws the selection box rectangle on screen."""
	if is_dragging:
		draw_rect(selection_box, Color(0.0, 1.0, 0.0, 0.2), true) # Filled
		draw_rect(selection_box, Color(0.0, 1.0, 0.0, 0.8), false, 2.0) # Border

func _perform_box_selection() -> void:
	
	# Clear previous selection unless holding Shift (future feature)
	_clear_selection()

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var box_shape := RectangleShape2D.new()
	box_shape.size = selection_box.size
	query.shape = box_shape
	query.transform = Transform2D(0, selection_box.get_center())
	query.collide_with_bodies = true
	query.collision_mask = 1 # Explicitly check layer 1


	var intersecting_bodies = space_state.intersect_shape(query)
	
	for body_dict in intersecting_bodies:
		var body = body_dict.get("collider")
		if body and body.is_in_group("selectable_units"):
			_add_to_selection(body)
			
	# Fallback for single click if the box is very small
	if selection_box.get_area() < 100 and intersecting_bodies.is_empty():
		_perform_single_click_selection(selection_box_start)


func _perform_single_click_selection(click_position: Vector2) -> void:
	_clear_selection()
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = click_position
	query.collide_with_bodies = true
	
	var result = space_state.intersect_point(query, 1)
	if not result.is_empty():
		var body = result[0].get("collider")
		if body and body.is_in_group("selectable_units"):
			_add_to_selection(body)

func _process_smart_command(click_position: Vector2) -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = click_position
	query.collide_with_bodies = true
	# TODO: Define collision layers for enemies
	# query.collision_mask = ENEMY_LAYER 
	
	var result = space_state.intersect_point(query, 1)

	var target_enemy: Node2D = null
	if not result.is_empty():
		var body = result[0].get("collider")
		# TODO: Add faction check
		if body and body.is_in_group("attackable"):
			target_enemy = body

	# Issue commands
	
	for unit in selected_units:
		if not is_instance_valid(unit):
			continue
			
		if "fsm" in unit and is_instance_valid(unit.fsm):
			if is_instance_valid(target_enemy):
				# Attack Command
				unit.fsm.command_attack(target_enemy)
			else:
				# Move Command
				unit.fsm.command_move_to(click_position)

# --- Selection Management ---

func _add_to_selection(unit: Node2D) -> void:
	
	if not unit in selected_units:
		selected_units.append(unit)
		if "selection_indicator" in unit:
			unit.selection_indicator.show()

func _clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and "selection_indicator" in unit:
			unit.selection_indicator.hide()
	selected_units.clear()
