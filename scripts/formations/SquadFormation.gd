# res://scripts/formations/SquadFormation.gd
# Squad Formation Manager - Company of Heroes style formations
# Handles formation positioning and movement for multiple units

class_name SquadFormation

enum FormationType {
	LINE,      # Horizontal line formation  
	COLUMN,    # Vertical column formation
	WEDGE,     # V-shaped formation
	BOX,       # Rectangular formation
	CIRCLE     # Circular formation
}

# Formation settings
var formation_type: FormationType = FormationType.LINE
var unit_spacing: float = 40.0
var max_units_per_row: int = 4

# Squad data
var units: Array[Node2D] = []
var leader_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var formation_center: Vector2 = Vector2.ZERO

# Movement state
var is_moving: bool = false
var move_speed: float = 100.0

func _init(squad_units: Array[Node2D] = []) -> void:
	units = squad_units
	if not units.is_empty():
		formation_center = _calculate_center_position()

func add_unit(unit: Node2D) -> void:
	"""Add a unit to the squad"""
	if unit not in units:
		units.append(unit)
		_update_formation_positions()

func remove_unit(unit: Node2D) -> void:
	"""Remove a unit from the squad"""
	units.erase(unit)
	_update_formation_positions()

func set_formation_type(new_type: FormationType) -> void:
	"""Change the formation type"""
	formation_type = new_type
	_update_formation_positions()

func move_to_position(target_pos: Vector2) -> void:
	"""Command the entire squad to move to a target position"""
	target_position = target_pos
	is_moving = true
	
	# Calculate formation positions around the target
	var formation_positions = _calculate_formation_positions(target_pos)
	
	# Assign each unit a position in the formation
	for i in range(min(units.size(), formation_positions.size())):
		var unit = units[i]
		var target_formation_pos = formation_positions[i]
		
		# Move the unit to its formation position
		_move_unit_to_position(unit, target_formation_pos)
	
	print("Squad moving to %s in %s formation with %d units" % [target_pos, FormationType.keys()[formation_type], units.size()])

func _calculate_formation_positions(center_pos: Vector2) -> Array[Vector2]:
	"""Calculate formation positions based on formation type"""
	var positions: Array[Vector2] = []
	var unit_count = units.size()
	
	match formation_type:
		FormationType.LINE:
			positions = _calculate_line_formation(center_pos, unit_count)
		FormationType.COLUMN:
			positions = _calculate_column_formation(center_pos, unit_count)
		FormationType.WEDGE:
			positions = _calculate_wedge_formation(center_pos, unit_count)
		FormationType.BOX:
			positions = _calculate_box_formation(center_pos, unit_count)
		FormationType.CIRCLE:
			positions = _calculate_circle_formation(center_pos, unit_count)
	
	return positions

func _calculate_line_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	"""Calculate horizontal line formation positions"""
	var positions: Array[Vector2] = []
	var start_x = center_pos.x - (unit_count - 1) * unit_spacing * 0.5
	
	for i in range(unit_count):
		var pos = Vector2(start_x + i * unit_spacing, center_pos.y)
		positions.append(pos)
	
	return positions

func _calculate_column_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	"""Calculate vertical column formation positions"""
	var positions: Array[Vector2] = []
	var start_y = center_pos.y - (unit_count - 1) * unit_spacing * 0.5
	
	for i in range(unit_count):
		var pos = Vector2(center_pos.x, start_y + i * unit_spacing)
		positions.append(pos)
	
	return positions

func _calculate_wedge_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	"""Calculate V-shaped wedge formation positions"""
	var positions: Array[Vector2] = []
	
	# Leader at the front
	positions.append(center_pos)
	
	# Place remaining units in V formation behind the leader
	var side_offset = unit_spacing * 0.7  # 70% spacing for tighter formation
	var rear_offset = unit_spacing
	
	for i in range(1, unit_count):
		var row = (i + 1) / 2  # Which row behind the leader
		var side = 1 if i % 2 == 1 else -1  # Left or right side
		
		var pos = Vector2(
			center_pos.x + side * side_offset * row,
			center_pos.y + rear_offset * row
		)
		positions.append(pos)
	
	return positions

func _calculate_box_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	"""Calculate rectangular box formation positions"""
	var positions: Array[Vector2] = []
	
	var rows = int(ceil(float(unit_count) / max_units_per_row))
	var cols = min(unit_count, max_units_per_row)
	
	var start_x = center_pos.x - (cols - 1) * unit_spacing * 0.5
	var start_y = center_pos.y - (rows - 1) * unit_spacing * 0.5
	
	for i in range(unit_count):
		var row = i / max_units_per_row
		var col = i % max_units_per_row
		
		# Center the last row if it has fewer units
		var row_unit_count = min(max_units_per_row, unit_count - row * max_units_per_row)
		var row_start_x = center_pos.x - (row_unit_count - 1) * unit_spacing * 0.5
		
		var pos = Vector2(
			row_start_x + col * unit_spacing,
			start_y + row * unit_spacing
		)
		positions.append(pos)
	
	return positions

func _calculate_circle_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	"""Calculate circular formation positions"""
	var positions: Array[Vector2] = []
	var radius = max(unit_spacing, unit_count * unit_spacing / (2 * PI))
	
	for i in range(unit_count):
		var angle = (2 * PI * i) / unit_count
		var pos = Vector2(
			center_pos.x + cos(angle) * radius,
			center_pos.y + sin(angle) * radius
		)
		positions.append(pos)
	
	return positions

func _move_unit_to_position(unit: Node2D, target_pos: Vector2) -> void:
	"""Move a specific unit to a target position"""
	if not is_instance_valid(unit):
		return
	
	# Check if unit has FSM (proper unit system)
	if "fsm" in unit and unit.fsm != null:
		unit.fsm.command_move_to(target_pos)
	# Check if unit has direct movement method
	elif unit.has_method("command_move_to"):
		unit.command_move_to(target_pos)
	# Fallback: simple movement for test units
	else:
		_simple_unit_movement(unit, target_pos)

func _simple_unit_movement(unit: Node2D, target_pos: Vector2) -> void:
	"""Simple movement system for test units without FSM"""
	if not unit.has_method("set_target_position"):
		# Add simple movement script to unit if it doesn't have one
		var movement_script = """
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 100.0
var is_moving: bool = false

func set_target_position(pos: Vector2) -> void:
	target_position = pos
	is_moving = true

func _physics_process(delta: float) -> void:
	if is_moving and target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		var distance = global_position.distance_to(target_position)
		
		if distance < 5.0:
			is_moving = false
			velocity = Vector2.ZERO
		else:
			velocity = direction * move_speed
		
		move_and_slide()
"""
		# Create and attach movement behavior
		var script = GDScript.new()
		script.source_code = unit.get_script().source_code + "\n" + movement_script
		script.reload()
		unit.set_script(script)
	
	# Set the target position
	unit.set_target_position(target_pos)

func _update_formation_positions() -> void:
	"""Update formation positions for current units"""
	if not units.is_empty():
		formation_center = _calculate_center_position()

func _calculate_center_position() -> Vector2:
	"""Calculate the center position of all units"""
	if units.is_empty():
		return Vector2.ZERO
	
	var total_pos = Vector2.ZERO
	for unit in units:
		if is_instance_valid(unit):
			total_pos += unit.global_position
	
	return total_pos / units.size()

func get_unit_count() -> int:
	"""Get the number of units in the squad"""
	return units.size()

func is_squad_moving() -> bool:
	"""Check if the squad is currently moving"""
	return is_moving

func get_formation_info() -> Dictionary:
	"""Get information about the current formation"""
	return {
		"type": FormationType.keys()[formation_type],
		"unit_count": units.size(),
		"spacing": unit_spacing,
		"center": formation_center,
		"is_moving": is_moving
	}
