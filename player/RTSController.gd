# res://player/RTSController.gd
extends Node
class_name RTSController

var selected_units: Array[BaseUnit] = []
var controllable_units: Array[BaseUnit] = []
var current_formation: SquadFormation.FormationType = SquadFormation.FormationType.LINE

# Control Group Storage
var control_groups: Dictionary = {
	1: [], 2: [], 3: [], 4: [], 5: [],
	6: [], 7: [], 8: [], 9: [], 0: [],
}

func _ready() -> void:
	print("DEBUG: RTSController Initialized.")
	
	# Mouse Commands
	EventBus.select_command.connect(_on_select_command)
	EventBus.move_command.connect(_on_move_command)
	EventBus.attack_command.connect(_on_attack_command)
	EventBus.formation_move_command.connect(_on_formation_move_command)
	
	# --- THIS WAS CAUSING THE ERROR ---
	# We connect it here, and define the function below
	EventBus.interact_command.connect(_on_interact_command)
	# ----------------------------------
	
	# Keyboard Commands
	EventBus.control_group_command.connect(_on_control_group_command)
	EventBus.formation_change_command.connect(_on_formation_change_command)

# --- NEW FUNCTION: The Missing Piece ---
func _on_interact_command(target: Node2D) -> void:
	print("DEBUG: RTSController received INTERACT command for target: ", target.name)
	
	_validate_selection()
	
	if selected_units.is_empty():
		print("DEBUG: ...but NO units are selected.")
		return
		
	for unit in selected_units:
		# Check if it's a worker
		if unit.is_in_group("civilians"):
			if unit.has_method("command_interact"):
				print("DEBUG: Calling command_interact() on %s" % unit.name)
				unit.command_interact(target)
			else:
				print("DEBUG: ERROR - %s is missing 'command_interact' method!" % unit.name)
		else:
			# Soldiers just move to guard it
			print("DEBUG: Unit %s is MILITARY. Move to target." % unit.name)
			unit.command_move_to(target.global_position)
# ---------------------------------------

# --- STANDARD LOGIC ---

func add_unit_to_group(unit: Node2D) -> void:
	if not unit is BaseUnit: return
	if unit in controllable_units: return
	controllable_units.append(unit)
	if unit.has_signal("destroyed"):
		unit.destroyed.connect(remove_unit.bind(unit), CONNECT_DEFERRED)

func remove_unit(unit: BaseUnit) -> void:
	if unit in selected_units:
		selected_units.erase(unit)
		if is_instance_valid(unit): unit.set_selected(false)
	if unit in controllable_units:
		controllable_units.erase(unit)
	var unit_id = unit.get_instance_id()
	for group_num in control_groups:
		if control_groups[group_num].has(unit_id):
			control_groups[group_num].erase(unit_id)

func _on_select_command(select_rect: Rect2, is_box_select: bool) -> void:
	_prune_dead_units()
	_clear_selection()
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	if not main_camera: return
	
	if is_box_select:
		var camera_pos = main_camera.get_screen_center_position()
		var camera_zoom = main_camera.zoom
		var viewport_size = get_viewport().get_visible_rect().size
		var world_rect_min = camera_pos - (viewport_size / (2.0 * camera_zoom)) + (select_rect.position / camera_zoom)
		var world_rect_max = world_rect_min + (select_rect.size / camera_zoom)
		var world_rect = Rect2(world_rect_min, world_rect_max - world_rect_min)
		
		for unit in controllable_units:
			if world_rect.has_point(unit.global_position):
				selected_units.append(unit)
				unit.set_selected(true)
	else:
		var click_world_pos := main_camera.get_global_mouse_position()
		var closest_unit: BaseUnit = null
		var min_dist_sq = INF
		
		for unit in controllable_units:
			var dist_sq = unit.global_position.distance_squared_to(click_world_pos)
			if dist_sq < min_dist_sq and dist_sq < (40 * 40): 
				min_dist_sq = dist_sq
				closest_unit = unit
				
		if closest_unit:
			selected_units.append(closest_unit)
			closest_unit.set_selected(true)
			
	print("DEBUG: Selection Updated. Count: ", selected_units.size())

func _on_move_command(target_position: Vector2) -> void:
	_validate_selection()
	if selected_units.is_empty(): return
	if selected_units.size() == 1:
		selected_units[0].command_move_to(target_position)
	else:
		_move_group_in_formation(target_position, Vector2.DOWN)

func _on_formation_move_command(target_position: Vector2, direction_vector: Vector2) -> void:
	_validate_selection()
	if selected_units.is_empty(): return
	if selected_units.size() == 1:
		selected_units[0].command_move_to(target_position)
	else:
		_move_group_in_formation(target_position, direction_vector)

func _on_attack_command(target_node: Node2D) -> void:
	_validate_selection()
	for unit in selected_units:
		unit.command_attack(target_node)

func command_scramble(target_position: Vector2) -> void:
	_clear_selection()
	for unit in controllable_units:
		if not is_instance_valid(unit): continue
		var panic_offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var unique_dest = target_position + panic_offset
		if unit.fsm and unit.fsm.has_method("command_retreat"):
			unit.fsm.command_retreat(unique_dest)
		else:
			unit.command_move_to(unique_dest)

func _validate_selection() -> void:
	var valid_units: Array[BaseUnit] = []
	for unit in selected_units:
		if is_instance_valid(unit): valid_units.append(unit)
	selected_units = valid_units

func _clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit): unit.set_selected(false)
	selected_units.clear()

func _move_group_in_formation(target: Vector2, direction: Vector2) -> void:
	var units_as_node2d: Array[Node2D] = []
	for unit in selected_units: units_as_node2d.append(unit)
	var formation = SquadFormation.new(units_as_node2d)
	formation.formation_type = current_formation
	formation.unit_spacing = 45.0
	formation.move_to_position(target, direction)

func _on_control_group_command(group_index: int, is_assigning: bool) -> void:
	if is_assigning: _set_control_group(group_index)
	else: _select_control_group(group_index)

func _on_formation_change_command(formation_type: int) -> void:
	current_formation = formation_type as SquadFormation.FormationType

func _set_control_group(num: int) -> void:
	control_groups[num].clear()
	for unit in selected_units:
		control_groups[num].append(unit.get_instance_id())

func _select_control_group(num: int) -> void:
	_clear_selection()
	var new_group_ids = control_groups[num]
	for unit_id in new_group_ids:
		var unit = instance_from_id(unit_id) as BaseUnit
		if is_instance_valid(unit) and unit in controllable_units:
			selected_units.append(unit)
			unit.set_selected(true)

func _prune_dead_units() -> void:
	# Rebuilds the list, keeping only valid units
	var alive_units: Array[BaseUnit] = []
	for unit in controllable_units:
		if is_instance_valid(unit):
			alive_units.append(unit)
	controllable_units = alive_units
