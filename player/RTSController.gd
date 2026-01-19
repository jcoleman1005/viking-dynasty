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
	EventBus.interact_command.connect(_on_interact_command)
	EventBus.pillage_command.connect(_on_pillage_command)
	# Keyboard Commands
	EventBus.control_group_command.connect(_on_control_group_command)
	EventBus.formation_change_command.connect(_on_formation_change_command)
	
	EventBus.player_unit_spawned.connect(add_unit_to_group)

# --- NEW: Helper to broadcast state ---
func _emit_selection_update() -> void:
	# Broadcast the new list so UI can update context buttons
	EventBus.units_selected.emit(selected_units)
# --------------------------------------

func _on_interact_command(target: Node2D) -> void:
	_validate_selection()
	if selected_units.is_empty(): return
		
	for unit in selected_units:
		if unit.is_in_group("civilians") and unit.has_method("command_interact"):
			unit.command_interact(target)
		else:
			# Soldiers move to guard the interaction point
			unit.command_move_to(target.global_position)

# --- MOVEMENT LOGIC REFACTOR ---

func _on_move_command(target_position: Vector2) -> void:
	_validate_selection()
	if selected_units.is_empty(): return
	
	_handle_movement_logic(target_position, Vector2.DOWN)

func _on_formation_move_command(target_position: Vector2, direction_vector: Vector2) -> void:
	_validate_selection()
	if selected_units.is_empty(): return
	
	_handle_movement_logic(target_position, direction_vector)

func _handle_movement_logic(target_pos: Vector2, direction: Vector2) -> void:
	# 1. Sort units by type
	var soldiers: Array[Node2D] = []
	var civilians: Array[Node2D] = []
	
	for unit in selected_units:
		if unit.is_in_group("civilians"):
			civilians.append(unit)
		else:
			soldiers.append(unit)
	
	# 2. Move Soldiers (Strict Formation)
	if not soldiers.is_empty():
		if soldiers.size() == 1:
			if soldiers[0].has_method("command_move_to"):
				soldiers[0].command_move_to(target_pos)
		else:
			_move_group_in_formation(soldiers, target_pos, direction)
			
	# 3. Move Civilians (Organic Mob)
	if not civilians.is_empty():
		_move_civilians_as_mob(civilians, target_pos)

func _move_group_in_formation(unit_list: Array[Node2D], target: Vector2, direction: Vector2) -> void:
	var formation = SquadFormation.new(unit_list)
	formation.formation_type = current_formation
	formation.unit_spacing = 45.0
	formation.move_to_position(target, direction)

func _move_civilians_as_mob(unit_list: Array[Node2D], target: Vector2) -> void:
	var unit_count = unit_list.size()
	var mob_radius = sqrt(unit_count) * 20.0 
	
	for unit in unit_list:
		if not is_instance_valid(unit): continue
		var angle = randf() * TAU
		var distance = randf() * mob_radius
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var specific_dest = target + offset
		
		if unit.has_method("command_move_to"):
			unit.command_move_to(specific_dest)

# ---------------------------------------------------------

func add_unit_to_group(unit: Node2D) -> void:
	if not unit is BaseUnit: return
	if unit in controllable_units: return
	
	controllable_units.append(unit)
	
	if unit.is_selected and not unit in selected_units:
		selected_units.append(unit)
		# Update UI if we auto-selected a new spawn
		_emit_selection_update()
	
	if unit.has_signal("destroyed"):
		unit.destroyed.connect(remove_unit.bind(unit), CONNECT_DEFERRED)

func remove_unit(unit: BaseUnit) -> void:
	var was_selected = unit in selected_units
	
	if unit in selected_units:
		selected_units.erase(unit)
		if is_instance_valid(unit): unit.set_selected(false)
	if unit in controllable_units:
		controllable_units.erase(unit)
	var unit_id = unit.get_instance_id()
	for group_num in control_groups:
		if control_groups[group_num].has(unit_id):
			control_groups[group_num].erase(unit_id)
			
	if was_selected:
		_emit_selection_update()

func _on_select_command(select_rect: Rect2, is_box_select: bool) -> void:
	_prune_dead_units()
	_clear_selection() # Clears array
	
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	if not main_camera: 
		_emit_selection_update() # Emit empty if camera missing
		return
	
	if is_box_select:
		var camera_pos = main_camera.get_screen_center_position()
		var camera_zoom = main_camera.zoom
		var viewport_size = get_viewport().get_visible_rect().size
		var world_rect_min = camera_pos - (viewport_size / (2.0 * camera_zoom)) + (select_rect.position / camera_zoom)
		var world_rect_max = world_rect_min + (select_rect.size / camera_zoom)
		var world_rect = Rect2(world_rect_min, world_rect_max - world_rect_min)
		
		for unit in controllable_units:
			if _is_squad_in_rect(unit, world_rect):
				selected_units.append(unit)
				unit.set_selected(true)
	else:
		var click_world_pos := main_camera.get_global_mouse_position()
		var closest_leader: BaseUnit = null
		var min_dist_sq = INF
		var click_radius_sq = 40 * 40
		
		for unit in controllable_units:
			var dist_sq = _get_closest_distance_to_squad(unit, click_world_pos)
			
			if dist_sq < min_dist_sq and dist_sq < click_radius_sq:
				min_dist_sq = dist_sq
				closest_leader = unit
				
		if closest_leader:
			selected_units.append(closest_leader)
			closest_leader.set_selected(true)
			
	print("DEBUG: Selection Updated. Count: ", selected_units.size())
	_emit_selection_update() # BROADCAST THE RESULT

func _is_squad_in_rect(unit: BaseUnit, rect: Rect2) -> bool:
	if rect.has_point(unit.global_position):
		return true
	if unit is SquadLeader:
		for soldier in unit.squad_soldiers:
			if is_instance_valid(soldier) and rect.has_point(soldier.global_position):
				return true
	return false

func _get_closest_distance_to_squad(unit: BaseUnit, point: Vector2) -> float:
	var min_d = unit.global_position.distance_squared_to(point)
	if unit is SquadLeader:
		for soldier in unit.squad_soldiers:
			if is_instance_valid(soldier):
				var d = soldier.global_position.distance_squared_to(point)
				if d < min_d:
					min_d = d
	return min_d

func _on_attack_command(target_node: Node2D) -> void:
	_validate_selection()
	for unit in selected_units:
		unit.command_attack(target_node)

func command_scramble(target_position: Vector2) -> void:
	_clear_selection()
	_emit_selection_update() # Emit empty after scramble
	
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
	
	_emit_selection_update() # BROADCAST GROUP SELECTION

func _prune_dead_units() -> void:
	var alive_units: Array[BaseUnit] = []
	for unit in controllable_units:
		if is_instance_valid(unit):
			alive_units.append(unit)
	controllable_units = alive_units

func _on_pillage_command(target_node: Node2D) -> void:
	_validate_selection()
	if selected_units.is_empty(): return
	
	Loggie.msg("RTSController: Ordering %d units to Pillage %s" % [selected_units.size(), target_node.name]).domain("RTS").info()
	
	for unit in selected_units:
		if unit.fsm and unit.fsm.has_method("command_pillage"):
			unit.fsm.command_pillage(target_node)
		else:
			unit.command_move_to(target_node.global_position)
