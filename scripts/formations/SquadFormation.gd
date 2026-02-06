#res://scripts/formations/SquadFormation.gd
# res://scripts/formations/SquadFormation.gd
# Squad Formation Manager - Company of Heroes style formations
# Handles formation positioning and movement for multiple units

class_name SquadFormation
extends RefCounted # Changed from implicit to explicit for better memory management

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
	if unit not in units:
		units.append(unit)
		_update_formation_positions()

func remove_unit(unit: Node2D) -> void:
	units.erase(unit)
	_update_formation_positions()

func set_formation_type(new_type: FormationType) -> void:
	formation_type = new_type
	_update_formation_positions()

func move_to_position(target_pos: Vector2, direction: Vector2 = Vector2.DOWN) -> void:
	target_position = target_pos
	is_moving = true
	
	var formation_positions = _calculate_formation_positions(target_pos, direction)
	
	# TRACKER: Keep track of grid cells claimed by this squad
	var claimed_cells: Array[Vector2i] = []
	
	for i in range(min(units.size(), formation_positions.size())):
		var unit = units[i]
		if not is_instance_valid(unit): continue
			
		var raw_dest = formation_positions[i]
		var final_dest = raw_dest
		
		# --- PHASE 4 FIX: ANTI-BUNCHING ---
		if SettlementManager:
			# Pass the 'claimed_cells' so this unit doesn't pick a spot 
			# that a previous squadmate already took.
			final_dest = SettlementManager.validate_formation_point(raw_dest, claimed_cells)
			
			# Register this spot as taken
			var grid_spot = SettlementManager.world_to_grid(final_dest)
			claimed_cells.append(grid_spot)
		# ----------------------------------
		
		_move_unit_to_position(unit, final_dest)
	
	Loggie.msg("Squad moving to %s in %s formation" % [target_pos, FormationType.keys()[formation_type]]).domain("RTS").info()


# --- EXISTING SHAPE LOGIC (Preserved) ---

func _calculate_formation_positions(center_pos: Vector2, direction: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var unit_count = units.size()
	
	# Invert direction to correct rotation (AI Fix preserved)
	var rotation_angle = Vector2.DOWN.angle_to(direction * -1.0)
	
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
	
	# Apply Rotation
	var rotated_positions: Array[Vector2] = []
	for pos in positions:
		var relative_pos = pos - center_pos
		var rotated_relative_pos = relative_pos.rotated(rotation_angle)
		rotated_positions.append(center_pos + rotated_relative_pos)
	
	return rotated_positions

func _calculate_line_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var start_x = center_pos.x - (unit_count - 1) * unit_spacing * 0.5
	for i in range(unit_count):
		positions.append(Vector2(start_x + i * unit_spacing, center_pos.y))
	return positions

func _calculate_column_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var start_y = center_pos.y - (unit_count - 1) * unit_spacing * 0.5
	for i in range(unit_count):
		positions.append(Vector2(center_pos.x, start_y + i * unit_spacing))
	return positions

func _calculate_wedge_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.append(center_pos) # Leader
	
	var side_offset = unit_spacing * 0.7 
	var rear_offset = unit_spacing
	
	for i in range(1, unit_count):
		var row = (i + 1) / 2 
		var side = 1 if i % 2 == 1 else -1 
		# Use + to face DOWN default
		var pos = Vector2(
			center_pos.x + side * side_offset * row,
			center_pos.y + rear_offset * row
		)
		positions.append(pos)
	return positions

func _calculate_box_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var rows = int(ceil(float(unit_count) / max_units_per_row))
	var cols = min(unit_count, max_units_per_row)
	
	var start_x = center_pos.x - (cols - 1) * unit_spacing * 0.5
	var start_y = center_pos.y - (rows - 1) * unit_spacing * 0.5
	
	for i in range(unit_count):
		var row = i / max_units_per_row
		var col = i % max_units_per_row
		
		# Center last row
		var row_unit_count = min(max_units_per_row, unit_count - row * max_units_per_row)
		var row_start_x = center_pos.x - (row_unit_count - 1) * unit_spacing * 0.5
		
		var pos = Vector2(
			row_start_x + col * unit_spacing,
			start_y + row * unit_spacing
		)
		positions.append(pos)
	return positions

func _calculate_circle_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var radius = max(unit_spacing, unit_count * unit_spacing / (2 * PI))
	for i in range(unit_count):
		var angle = (2 * PI * i) / unit_count
		positions.append(Vector2(
			center_pos.x + cos(angle) * radius,
			center_pos.y + sin(angle) * radius
		))
	return positions

func _move_unit_to_position(unit: Node2D, target_pos: Vector2) -> void:
	if not is_instance_valid(unit): return
	
	# Prefer FSM Formation Move (Clears current target, sets path)
	if "fsm" in unit and unit.fsm != null:
		unit.fsm.command_move_to_formation_pos(target_pos)
	elif unit.has_method("command_move_to"):
		unit.command_move_to(target_pos)

func _update_formation_positions() -> void:
	if not units.is_empty():
		formation_center = _calculate_center_position()

func _calculate_center_position() -> Vector2:
	if units.is_empty(): return Vector2.ZERO
	var total_pos = Vector2.ZERO
	for unit in units:
		if is_instance_valid(unit): total_pos += unit.global_position
	return total_pos / units.size()

func get_unit_count() -> int: return units.size()
func is_squad_moving() -> bool: return is_moving
func get_formation_info() -> Dictionary:
	return {
		"type": FormationType.keys()[formation_type],
		"unit_count": units.size(),
		"spacing": unit_spacing,
		"center": formation_center,
		"is_moving": is_moving
	}
