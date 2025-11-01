# res://player/RTSController.gd
# RTS input controller for Phase 3 with improved box selection
# GDD Ref: Phase 3 Task 5

extends Node2D

# Selection System
var selected_units: Array[Node2D] = []
var selection_box_start: Vector2 = Vector2.ZERO
var selection_box_current: Vector2 = Vector2.ZERO
var is_dragging: bool = false

# Squad Formation System
var current_squad: SquadFormation = null
var formation_type: SquadFormation.FormationType = SquadFormation.FormationType.LINE

# Input State
var left_mouse_pressed: bool = false

# Camera reference for screen-to-world conversion
@onready var camera: Camera2D = get_viewport().get_camera_2d()

# Selection box visual
var selection_rect: Rect2 = Rect2()

func _ready() -> void:
	# Ensure we can draw and handle input
	set_process_unhandled_input(true)
	# Position at world origin for proper drawing coordinates
	global_position = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start selection or single select
			left_mouse_pressed = true
			selection_box_start = get_global_mouse_position()
			selection_box_current = selection_box_start
			is_dragging = false
			queue_redraw()
		else:
			# End selection
			left_mouse_pressed = false
			if is_dragging:
				_complete_box_selection()
				is_dragging = false
			else:
				_single_select()
			queue_redraw()
	
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if left_mouse_pressed:
		selection_box_current = get_global_mouse_position()
		var drag_distance = selection_box_current.distance_to(selection_box_start)
		if drag_distance > 10.0: # Minimum drag distance to start box selection
			is_dragging = true
			_update_selection_box()
			queue_redraw()

func _update_selection_box() -> void:
	var top_left = Vector2(
		min(selection_box_start.x, selection_box_current.x),
		min(selection_box_start.y, selection_box_current.y)
	)
	var bottom_right = Vector2(
		max(selection_box_start.x, selection_box_current.x),
		max(selection_box_start.y, selection_box_current.y)
	)
	selection_rect = Rect2(top_left, bottom_right - top_left)

func _single_select() -> void:
	# Select a single unit at the click position
	var world_pos = get_global_mouse_position()
	
	# Clear previous selection
	_clear_selection()
	
	# Method 1: Try physics query first
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 1 # Units should be on layer 1
	
	var results = space_state.intersect_point(query, 1)
	
	for result in results:
		var body = result["collider"]
		if _is_player_unit(body):
			_add_to_selection(body)
			return
	
	# Method 2: Fallback - Check all player units for proximity
	var all_units = get_tree().get_nodes_in_group("player_units")
	
	var closest_unit: Node2D = null
	var closest_distance: float = 50.0  # Max click distance in pixels
	
	for unit in all_units:
		if unit is Node2D:
			var distance = unit.global_position.distance_to(world_pos)
			if distance < closest_distance and _is_player_unit(unit):
				closest_distance = distance
				closest_unit = unit
	
	# Select the closest unit if found
	if closest_unit:
		_add_to_selection(closest_unit)

func _complete_box_selection() -> void:
	# Complete box selection and select all units in the box
	var units_in_box = _get_units_in_rect(selection_rect)
	
	# Clear previous selection
	_clear_selection()
	
	# Add all units in box to selection
	for unit in units_in_box:
		if _is_player_unit(unit):
			_add_to_selection(unit)
	
	# Create squad formation with selected units
	_create_squad_formation()
	
	print("Box selection completed: %d units selected" % selected_units.size())

func _get_units_in_rect(rect: Rect2) -> Array:
	# Get all units whose positions are within the given rectangle
	var units_in_rect: Array = []
	
	# Find all units in the scene
	var units = get_tree().get_nodes_in_group("player_units")
	
	for unit in units:
		if unit is Node2D and rect.has_point(unit.global_position):
			units_in_rect.append(unit)
	
	return units_in_rect

func _handle_right_click() -> void:
	# Handle right mouse click for movement/attack commands
	if selected_units.is_empty():
		return
	
	var world_pos = get_global_mouse_position()
	var target = _get_target_at_position(world_pos)
	
	if target and _is_enemy_unit(target):
		# Attack command
		print("Commanding %d units to attack %s" % [selected_units.size(), target.name])
		for unit in selected_units:
			if unit.has_method("command_attack"):
				unit.command_attack(target)
			elif "fsm" in unit and unit.fsm != null and unit.fsm.has_method("command_attack"):
				unit.fsm.command_attack(target)
	else:
		# Move command using squad formation
		if current_squad and selected_units.size() > 1:
			print("Squad formation moving to %s with %d units" % [world_pos, selected_units.size()])
			current_squad.move_to_position(world_pos)
		else:
			# Single unit or no squad - use individual movement
			print("Commanding %d units to move to %s" % [selected_units.size(), world_pos])
			for unit in selected_units:
				if unit.has_method("command_move_to"):
					unit.command_move_to(world_pos)
				elif "fsm" in unit and unit.fsm != null and unit.fsm.has_method("command_move_to"):
					unit.fsm.command_move_to(world_pos)

func _get_target_at_position(world_pos: Vector2) -> Node2D:
	# Get the target (enemy unit/building) at the given screen position
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 2 # Assuming enemies are on layer 2
	
	var results = space_state.intersect_point(query, 1)
	
	for result in results:
		var body = result["collider"]
		if _is_enemy_unit(body):
			return body
	
	# Fallback: check enemy groups for proximity
	var enemy_units = get_tree().get_nodes_in_group("enemy_units")
	var enemy_buildings = get_tree().get_nodes_in_group("enemy_buildings")
	var all_enemies = enemy_units + enemy_buildings
	
	var closest_enemy: Node2D = null
	var closest_distance: float = 50.0
	
	for enemy in all_enemies:
		if enemy is Node2D:
			var distance = enemy.global_position.distance_to(world_pos)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	return closest_enemy

func _is_player_unit(node: Node) -> bool:
	# Check if the node is a player unit
	return node.is_in_group("player_units") and (
		node.has_method("command_move_to") or 
		("fsm" in node and node.fsm != null)
	)

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

func _draw() -> void:
	# Draw the selection box if dragging
	if is_dragging and selection_rect.size.length() > 0:
		# Convert world coordinates to local coordinates for drawing
		var local_rect = Rect2(
			to_local(selection_rect.position),
			selection_rect.size
		)
		
		# Draw selection box with semi-transparent fill
		var fill_color = Color.YELLOW
		fill_color.a = 0.2
		draw_rect(local_rect, fill_color)
		
		# Draw selection box border
		draw_rect(local_rect, Color.YELLOW, false, 2.0)

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

# --- Debug Methods ---

func get_selected_units() -> Array[Node2D]:
	"""Get currently selected units - useful for debugging"""
	return selected_units

func get_selection_count() -> int:
	"""Get number of selected units"""
	return selected_units.size()

# --- Squad Formation System ---

func _create_squad_formation() -> void:
	"""Create a squad formation with currently selected units"""
	if selected_units.size() > 1:
		current_squad = SquadFormation.new(selected_units)
		current_squad.set_formation_type(formation_type)
		print("Created squad formation: %s with %d units" % [SquadFormation.FormationType.keys()[formation_type], selected_units.size()])
	else:
		current_squad = null

func _handle_keyboard_input(event: InputEventKey) -> void:
	"""Handle keyboard shortcuts for formation changes"""
	if selected_units.is_empty():
		return
	
	# Formation hotkeys (Company of Heroes style)
	match event.keycode:
		KEY_1: # Line formation
			_change_formation(SquadFormation.FormationType.LINE)
		KEY_2: # Column formation  
			_change_formation(SquadFormation.FormationType.COLUMN)
		KEY_3: # Wedge formation
			_change_formation(SquadFormation.FormationType.WEDGE)
		KEY_4: # Box formation
			_change_formation(SquadFormation.FormationType.BOX)
		KEY_5: # Circle formation
			_change_formation(SquadFormation.FormationType.CIRCLE)

func _change_formation(new_formation: SquadFormation.FormationType) -> void:
	"""Change the formation type of the current squad"""
	formation_type = new_formation
	
	if current_squad:
		current_squad.set_formation_type(formation_type)
		print("Formation changed to: %s" % SquadFormation.FormationType.keys()[formation_type])
	else:
		print("Formation set to: %s (will apply to next selection)" % SquadFormation.FormationType.keys()[formation_type])

# --- Squad Formation Commands ---

func cycle_formation() -> void:
	"""Cycle through available formations"""
	var formations = SquadFormation.FormationType.values()
	var current_index = formations.find(formation_type)
	var next_index = (current_index + 1) % formations.size()
	_change_formation(formations[next_index])

func get_formation_info() -> String:
	"""Get current formation information for UI display"""
	if current_squad:
		var info = current_squad.get_formation_info()
		return "Formation: %s | Units: %d | Moving: %s" % [info.type, info.unit_count, info.is_moving]
	else:
		return "Formation: %s (Ready)" % SquadFormation.FormationType.keys()[formation_type]
