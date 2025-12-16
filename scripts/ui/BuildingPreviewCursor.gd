extends Node2D
class_name BuildingPreviewCursor

# Building preview components
var current_building_data: BuildingData
var preview_sprite: Sprite2D
var is_active: bool = false

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

func _ready() -> void:
	z_index = 100
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)

func set_building_preview(building_data: BuildingData) -> void:
	if not building_data: return
	current_building_data = building_data
	
	_cleanup_preview()
	
	preview_sprite = Sprite2D.new()
	if building_data.building_texture:
		preview_sprite.texture = building_data.building_texture
		
		# ISOMETRIC SCALING
		# We generally maintain 1:1 scale for pixel art, but if you need auto-scaling:
		# Use TILE_WIDTH (64) as the base metric
		# var base_width = SettlementManager.TILE_WIDTH * building_data.grid_size.x
		# var tex_size = preview_sprite.texture.get_size()
		# preview_sprite.scale = Vector2(base_width / tex_size.x, base_width / tex_size.x) 
		
		# For now, default to 1.0 or use pivot adjustments in the sprite itself
		preview_sprite.position.y = -16 # Visually lift sprite so feet sit on diamond

	preview_sprite.modulate = valid_color
	add_child(preview_sprite)
	
	_create_grid_outline(building_data.grid_size)
	is_active = true
	visible = true

func _process(_delta: float) -> void:
	if not is_active or not current_building_data: return
	
	var mouse_pos = get_global_mouse_position()
	
	# 1. Snap to Grid
	var grid_pos = _world_to_grid(mouse_pos)
	
	# 2. Convert back to World for display
	# Note: This returns the CENTER of the anchor tile.
	var snapped_pos = _grid_to_world(grid_pos)
	
	# 3. Apply Centering Offset for Multi-tile Buildings
	# Isometric depth moves down-right (+X) and down-left (+Y).
	# We center the cursor visually on the building's footprint.
	var size = current_building_data.grid_size
	var half_w = SettlementManager.TILE_HALF_SIZE.x
	var half_h = SettlementManager.TILE_HALF_SIZE.y
	
	# Calculate visual center of the diamond footprint relative to anchor
	var offset_x = (size.x - size.y) * half_w * 0.5
	var offset_y = (size.x + size.y - 2) * half_h * 0.5 # -2 to keep anchor at top
	
	# Update Position
	global_position = snapped_pos + Vector2(offset_x, offset_y)
	
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

# --- COORDINATE HANDLERS ---

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return SettlementManager.world_to_grid(world_pos)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return SettlementManager.grid_to_world(grid_pos)

func _can_place_at_position(grid_pos: Vector2i) -> bool:
	return SettlementManager.is_placement_valid(grid_pos, current_building_data.grid_size, current_building_data)

func _update_visual_feedback() -> void:
	if not preview_sprite: return
	preview_sprite.modulate = valid_color if can_place else invalid_color

func place_building() -> void:
	if not is_active or not can_place: return
	var grid_pos = _world_to_grid(get_global_mouse_position())
	
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
	
	# Create Diamond Footprint
	var half_w = SettlementManager.TILE_HALF_SIZE.x
	var half_h = SettlementManager.TILE_HALF_SIZE.y
	
	# Calculate the 4 corners of the isometric rectangle (which looks like a diamond)
	# Local 0,0 is the Center of the Top Tile.
	
	# Top Corner (Local 0,0 is center, so top is -half_h)
	var top = Vector2(0, -half_h)
	
	# Right Corner (Walk grid_size.x steps right)
	var right = Vector2(grid_size.x * half_w, grid_size.x * half_h) + Vector2(0, -half_h)
	
	# Bottom Corner (Walk grid_size.x right + grid_size.y left)
	# Wait, isometric addition:
	# Right Vector: (+HalfW, +HalfH)
	# Left Vector:  (-HalfW, +HalfH)
	
	var v_right = Vector2(half_w, half_h)
	var v_left = Vector2(-half_w, half_h)
	
	var p_top = Vector2(0, -half_h) # Top of the first tile
	var p_right = p_top + (v_right * grid_size.x)
	var p_bottom = p_right + (v_left * grid_size.y)
	var p_left = p_top + (v_left * grid_size.y)
	
	# Re-center relative to cursor if needed, but for now draw raw
	var points = PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top])
	
	var line = Line2D.new()
	line.points = points
	line.width = 2.0
	line.default_color = Color(1, 1, 1, 0.5)
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
