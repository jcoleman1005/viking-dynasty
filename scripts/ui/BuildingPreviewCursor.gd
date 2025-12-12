extends Node2D
class_name BuildingPreviewCursor

# Building preview components
var current_building_data: BuildingData
var preview_sprite: Sprite2D
var is_active: bool = false

# Grid and placement
# [REMOVED] var cell_size: int = 32  <-- We now use SettlementManager.CELL_SIZE_PX
var grid_overlay: Node2D
var can_place: bool = false

# Visual feedback
var valid_color: Color = Color(0.0, 1.0, 0.0, 0.7)    # Green
var invalid_color: Color = Color(1.0, 0.0, 0.0, 0.7)  # Red

# Tether Visualization
var nearest_node: ResourceNode = null
var tether_color_valid: Color = Color(0.2, 1.0, 0.2, 0.8) # Green
var tether_color_invalid: Color = Color(1.0, 0.2, 0.2, 0.8) # Red

signal placement_completed
signal placement_cancelled

# [REMOVED] var grid_manager: Node = null

func _ready() -> void:
	z_index = 100
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)
	# [REMOVED] grid_manager lookup

func set_building_preview(building_data: BuildingData) -> void:
	if not building_data: return
	current_building_data = building_data
	
	_cleanup_preview()
	
	preview_sprite = Sprite2D.new()
	if building_data.building_texture:
		preview_sprite.texture = building_data.building_texture
		
		# [FIX] Use Authority Constant for scaling
		var cs = SettlementManager.CELL_SIZE_PX
		var target_size = Vector2(building_data.grid_size) * cs
		var tex_size = preview_sprite.texture.get_size()
		preview_sprite.scale = target_size / tex_size

	preview_sprite.modulate = valid_color
	add_child(preview_sprite)
	
	_create_grid_outline(building_data.grid_size)
	is_active = true
	visible = true

func _process(_delta: float) -> void:
	if not is_active or not current_building_data: return
	
	var mouse_pos = get_global_mouse_position()
	var grid_pos = _world_to_grid(mouse_pos)
	global_position = _grid_to_world(grid_pos)
	
	can_place = _can_place_at_position(grid_pos)
	
	# Find tether target
	_find_nearest_resource_node(global_position)
	
	_update_visual_feedback()
	queue_redraw()

func _find_nearest_resource_node(world_pos: Vector2) -> void:
	nearest_node = null
	if not current_building_data is EconomicBuildingData: return
		
	var target_type = (current_building_data as EconomicBuildingData).resource_type
	var min_dist = INF
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
	
	for node in nodes:
		if node is ResourceNode and node.resource_type == target_type:
			if node.is_depleted(): continue
			var dist = world_pos.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_node = node

func _draw() -> void:
	if is_active and nearest_node:
		var start = Vector2.ZERO
		var end = to_local(nearest_node.global_position)
		var dist = global_position.distance_to(nearest_node.global_position)
		var is_in_range = dist <= nearest_node.district_radius
		var color = tether_color_valid if is_in_range else tether_color_invalid
		
		draw_line(start, end, color, 2.0)
		draw_circle(end, 5.0, color)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	# [FIX] Use Authority Constant
	var cs = SettlementManager.CELL_SIZE_PX
	return Vector2i(int(world_pos.x / cs), int(world_pos.y / cs))

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	# [FIX] Use Authority Constant
	var cs = SettlementManager.CELL_SIZE_PX
	return Vector2(grid_pos.x * cs, grid_pos.y * cs)

func _can_place_at_position(grid_pos: Vector2i) -> bool:
	# [FIX] Delegate directly to SettlementManager (Authority)
	return SettlementManager.is_placement_valid(grid_pos, current_building_data.grid_size, current_building_data)

func _update_visual_feedback() -> void:
	if not preview_sprite: return
	preview_sprite.modulate = valid_color if can_place else invalid_color

func place_building() -> void:
	if not is_active or not can_place: return
	var grid_pos = _world_to_grid(global_position)
	
	# [FIX] Calls Authority to place (Data + Grid Update)
	SettlementManager.place_building(current_building_data, grid_pos, true)
	
	placement_completed.emit()
	cancel_preview()

func cancel_preview() -> void:
	is_active = false
	visible = false
	current_building_data = null
	_cleanup_preview()
	placement_cancelled.emit()

func _cleanup_preview() -> void:
	if preview_sprite: preview_sprite.queue_free()
	_clear_grid_overlay()

func _create_grid_outline(grid_size: Vector2i) -> void:
	_clear_grid_overlay()
	
	# [FIX] Use Authority Constant
	var cs = SettlementManager.CELL_SIZE_PX
	var rect_size = Vector2(grid_size.x * cs, grid_size.y * cs)
	
	var points = [Vector2(0,0), Vector2(rect_size.x, 0), Vector2(rect_size.x, rect_size.y), Vector2(0, rect_size.y), Vector2(0,0)]
	var line = Line2D.new()
	line.points = points
	line.width = 2.0
	grid_overlay.add_child(line)

func _clear_grid_overlay() -> void:
	for child in grid_overlay.get_children(): child.queue_free()

func _input(event: InputEvent) -> void:
	if not is_active: return
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_preview()
			get_viewport().set_input_as_handled()
