# res://player/RTSController.gd
#
# --- REFACTORED ---
# This script is now decoupled from input.
# It listens for clean signals from the EventBus
# (which are fired by SelectionBox.gd).
# It also correctly cleans up dead units.
#
# --- ADDED: Control Group & Formation Drag Support ---

extends Node
class_name RTSController

var selected_units: Array[BaseUnit] = []
var controllable_units: Array[BaseUnit] = []
var current_formation: SquadFormation.FormationType = SquadFormation.FormationType.LINE

# --- NEW: Control Group Storage ---
# We store the unit instance IDs, not the nodes themselves,
# to more safely handle units dying.
var control_groups: Dictionary = {
	1: [], 2: [], 3: [], 4: [], 5: [],
	6: [], 7: [], 8: [], 9: [], 0: [],
}
# ---------------------------------


func _ready() -> void:
	# Connect to the clean signals from our new EventBus/SelectionBox
	EventBus.select_command.connect(_on_select_command)
	EventBus.move_command.connect(_on_move_command)
	EventBus.attack_command.connect(_on_attack_command)
	# --- THIS LINE IS REQUIRED FOR DRAG-FORMATIONS ---
	EventBus.formation_move_command.connect(_on_formation_move_command)

func _input(event: InputEvent) -> void:
	# --- MODIFIED: Handle Control Group logic ---
	if event is InputEventKey and event.is_pressed():
		var key = event.keycode
		
		# --- THIS IS THE FIX (Line 41) ---
		# We use the 'ctrl_pressed' *property*
		var is_ctrl_pressed: bool = event.ctrl_pressed
		# ---------------------------------

		# Handle number keys 0-9
		if key >= KEY_0 and key <= KEY_9:
			var num = key - KEY_0 # Get the integer 0-9
			
			if is_ctrl_pressed:
				# Ctrl + Number: SET group
				_set_control_group(num)
				get_viewport().set_input_as_handled()
			else:
				# Number: SELECT group
				_select_control_group(num)
				get_viewport().set_input_as_handled()
		# -------------------------------------------
		else:
			# Handle non-number-key inputs (like formations)
			match event.keycode:
				# --- MOVED to F-Keys to avoid conflict ---
				KEY_F1:
					current_formation = SquadFormation.FormationType.LINE
					Loggie.msg("Formation: LINE").domain("RTS").info()
				KEY_F2:
					current_formation = SquadFormation.FormationType.COLUMN
					Loggie.msg("Formation: COLUMN").domain("RTS").info()
				KEY_F3:
					current_formation = SquadFormation.FormationType.WEDGE
					Loggie.msg("Formation: WEDGE").domain("RTS").info()
				KEY_F4:
					current_formation = SquadFormation.FormationType.BOX
					Loggie.msg("Formation: BOX").domain("RTS").info()
				# -----------------------------------------

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
	Loggie.msg("RTSController: Unit %s was destroyed/removed." % unit.name).domain("RTS").info()
	
	if unit in selected_units:
		selected_units.erase(unit)
		if is_instance_valid(unit):
			# set_selected is a function on BaseUnit
			unit.set_selected(false)
			
	if unit in controllable_units:
		controllable_units.erase(unit)
		
	# --- NEW: Clean up control groups ---
	var unit_id = unit.get_instance_id()
	for group_num in control_groups:
		if control_groups[group_num].has(unit_id):
			control_groups[group_num].erase(unit_id)
	# ------------------------------------
		
	# Check if this was the last unit
	if controllable_units.is_empty():
		Loggie.msg("RTSController: All units are gone.").domain("RTS").info()

# --- EVENTBUS HANDLERS ---

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
	# --- FIX: Prune invalid units immediately ---
	# This removes any "zombies" that might have sneaked into the selection
	var valid_units: Array[BaseUnit] = []
	for unit in selected_units:
		if is_instance_valid(unit):
			valid_units.append(unit)
	selected_units = valid_units
	# --------------------------------------------

	if selected_units.is_empty():
		return
	
	if selected_units.size() == 1:
		# Single unit - direct movement
		selected_units[0].command_move_to(target_position)
	else:
		# Multiple units - use formation
		var units_as_node2d: Array[Node2D] = []
		for unit in selected_units:
			# Double-check validity just to be safe
			if is_instance_valid(unit):
				units_as_node2d.append(unit)
		
		if units_as_node2d.is_empty(): return

		var formation = SquadFormation.new(units_as_node2d)
		formation.formation_type = current_formation
		formation.unit_spacing = 45.0
		
		# Calculate direction
		var group_center = formation.formation_center
		var direction = (target_position - group_center).normalized()
		if direction.is_zero_approx():
			direction = Vector2.DOWN 
			
		formation.move_to_position(target_position, direction)

# --- THIS IS THE NEW FUNCTION FOR DRAG-FORMATIONS ---
func _on_formation_move_command(target_position: Vector2, direction_vector: Vector2):
	# --- DEBUG ---
	Loggie.msg("==================================================").domain("RTS").info()
	Loggie.msg("RTSController: Received formation_move_command.").domain("RTS").info()
	Loggie.msg("  -> Target Center: %s, Direction: %s" % [target_position, direction_vector]).domain("RTS").info()
	# --- END DEBUG ---
	
	if selected_units.is_empty():
		return

	if selected_units.size() == 1:
		# Single unit - just move, ignore direction
		selected_units[0].command_move_to(target_position)
	else:
		# Multiple units - use formation
		var units_as_node2d: Array[Node2D] = []
		for unit in selected_units:
			units_as_node2d.append(unit)
		
		var formation = SquadFormation.new(units_as_node2d)
		formation.formation_type = current_formation
		formation.unit_spacing = 45.0
		# Pass the specific direction from the drag
		formation.move_to_position(target_position, direction_vector)
# ---------------------------------------------

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

# --- Control Group Functions ---

func _set_control_group(num: int) -> void:
	Loggie.msg("Setting control group %d" % num).domain("RTS").info()
	# Clear the old group
	control_groups[num].clear()
	# Add all currently selected units by their ID
	for unit in selected_units:
		control_groups[num].append(unit.get_instance_id())

func _select_control_group(num: int) -> void:
	Loggie.msg("Selecting control group %d" % num).domain("RTS").info()
	_clear_selection()
	
	var new_group_ids = control_groups[num]
	var still_valid_ids = []
	
	for unit_id in new_group_ids:
		var unit = instance_from_id(unit_id) as BaseUnit
		
		# Check if unit is still alive and controllable
		if is_instance_valid(unit) and unit in controllable_units:
			selected_units.append(unit)
			unit.set_selected(true)
			still_valid_ids.append(unit_id)
		
	# Prune any dead units from the control group
	control_groups[num] = still_valid_ids

	# --- Optional: Camera Pan ---
	# If we selected units, pan camera to them
	if not selected_units.is_empty():
		var center_pos = Vector2.ZERO
		for unit in selected_units:
			center_pos += unit.global_position
		center_pos /= selected_units.size()
		
		# Pan camera (assuming camera is RTSCamera)
		var camera = get_viewport().get_camera_2d()
		if camera and camera is RTSCamera:
			# Simple jump, as RTSCamera has no tween_pan_to method
			camera.global_position = center_pos
		elif camera:
			camera.global_position = center_pos
			
func command_scramble(target_position: Vector2) -> void:
	"""
	Orders ALL controllable units to run individually to the target.
	Uses the new RETREAT state to ignore combat.
	"""
	Loggie.msg("RTSController: SCRAMBLE! Breaking formation.").domain("RTS").info()
	
	_clear_selection()
	
	for unit in controllable_units:
		if not is_instance_valid(unit): continue
		
		var panic_offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var unique_dest = target_position + panic_offset
		
		# --- FIX: Check for specific retreat command ---
		if unit.fsm and unit.fsm.has_method("command_retreat"):
			unit.fsm.command_retreat(unique_dest)
		else:
			# Fallback for older unit types
			unit.command_move_to(unique_dest)
