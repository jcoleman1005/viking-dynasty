# res://player/RTSController.gd
#
# --- REFACTORED ---
# This script is now decoupled from input.
# It listens for clean signals from the EventBus
# (which are fired by SelectionBox.gd).
# It also correctly cleans up dead units.

extends Node
class_name RTSController

var selected_units: Array[BaseUnit] = []
var controllable_units: Array[BaseUnit] = []

func _ready() -> void:
	# Connect to the clean signals from our new EventBus/SelectionBox
	EventBus.select_command.connect(_on_select_command)
	EventBus.move_command.connect(_on_move_command)
	EventBus.attack_command.connect(_on_attack_command)

# --- PUBLIC API ---

func add_unit_to_group(unit: Node2D) -> void:
	# Verify the unit is a BaseUnit (which has 'destroyed' signal)
	if not unit is BaseUnit:
		push_error("RTSController: Tried to add unit '%s' that doesn't extend BaseUnit." % unit.name)
		return
		
	if unit in controllable_units:
		return

	controllable_units.append(unit)
	
	# --- THIS IS THE DEAD UNIT CRASH FIX ---
	# Connect to this unit's 'destroyed' signal.
	# When it's destroyed, we'll clean it up.
	# We use CONNECT_DEFERRED to avoid race conditions.
	if unit.has_signal("destroyed"):
		unit.destroyed.connect(remove_unit.bind(unit), CONNECT_DEFERRED)
	else:
		# This check is vital. Our old debug units will fail this.
		push_warning("Unit %s does not have 'destroyed' signal!" % unit.name)

func remove_unit(unit: BaseUnit) -> void:
	"""Removes a unit from tracking. Called by the unit's 'destroyed' signal."""
	print("RTSController: Unit %s was destroyed/removed." % unit.name)
	
	if unit in selected_units:
		selected_units.erase(unit)
		if is_instance_valid(unit):
			# set_selected is a function on BaseUnit
			unit.set_selected(false)
			
	if unit in controllable_units:
		controllable_units.erase(unit)
		
	# Check if this was the last unit
	if controllable_units.is_empty():
		print("RTSController: All units are gone.")

# --- REMOVED ---
# _on_global_input, _draw, _process, _handle_selection,
# and _handle_command are all removed.
# They are replaced by the functions below.
# -----------------

# --- NEW: EVENTBUS HANDLERS ---

func _on_select_command(select_rect: Rect2, is_box_select: bool) -> void:
	_clear_selection()
	
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	if not main_camera:
		push_error("RTSController: No Camera2D found to perform selection.")
		return
	
	if is_box_select:
		# Box select - convert screen rect to world coordinates instead
		# This is more reliable than converting world to screen for each unit
		var camera_pos = main_camera.get_screen_center_position()
		var camera_zoom = main_camera.zoom
		var viewport_size = get_viewport().get_visible_rect().size
		
		# Convert screen rectangle to world coordinates
		var world_rect_min = camera_pos - (viewport_size / (2.0 * camera_zoom)) + (select_rect.position / camera_zoom)
		var world_rect_max = world_rect_min + (select_rect.size / camera_zoom)
		var world_rect = Rect2(world_rect_min, world_rect_max - world_rect_min)
		
		for unit in controllable_units:
			if world_rect.has_point(unit.global_position):
				selected_units.append(unit)
				unit.set_selected(true)
	else:
		# Single select (find closest unit to the click)
		# We must get the world position from the camera
		var click_world_pos := main_camera.get_global_mouse_position()
		var closest_unit: BaseUnit = null
		var min_dist_sq = INF
		
		for unit in controllable_units:
			var dist_sq = unit.global_position.distance_squared_to(click_world_pos)
			# 40px click radius
			if dist_sq < min_dist_sq and dist_sq < (40 * 40): 
				min_dist_sq = dist_sq
				closest_unit = unit
				
		if closest_unit:
			selected_units.append(closest_unit)
			closest_unit.set_selected(true)

func _on_move_command(target_position: Vector2) -> void:
	if selected_units.is_empty():
		return
		
	# TODO: Add formation logic for movement
	for unit in selected_units:
		unit.command_move_to(target_position)

func _on_attack_command(target_node: Node2D) -> void:
	if selected_units.is_empty():
		return
		
	for unit in selected_units:
		unit.command_attack(target_node)

func _clear_selection() -> void:
	for unit in selected_units:
		# Check if it's valid, it might have been destroyed
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()
