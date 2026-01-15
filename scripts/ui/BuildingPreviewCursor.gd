extends Node2D
class_name BuildingPreviewCursor

# --- Components ---
var current_building_data: BuildingData
var preview_sprite: Sprite2D
var is_active: bool = false

# --- Grid & Placement ---
var grid_overlay: Node2D
var can_place: bool = false

# --- Visual Settings ---
var valid_color: Color = Color(0.0, 1.0, 0.0, 0.7)    # Green
var invalid_color: Color = Color(1.0, 0.0, 0.0, 0.7)  # Red

# --- Tether Settings ---
var nearest_node: ResourceNode = null
var tether_color_valid: Color = Color(0.2, 1.0, 0.2, 0.8) # Green
var tether_color_invalid: Color = Color(1.0, 0.2, 0.2, 0.8) # Red

signal placement_completed
signal placement_cancelled

func _ready() -> void:
	z_index = 100 # Ensure cursor floats above terrain
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)

func set_building_preview(building_data: BuildingData) -> void:
	if not building_data: return
	current_building_data = building_data
	
	_cleanup_preview()
	
	# 1. Create Sprite
	preview_sprite = Sprite2D.new()
	if building_data.building_texture:
		preview_sprite.texture = building_data.building_texture
		
		# --- SAFE SCALING LOGIC ---
		var tile_size = Vector2(64, 32) # Standard size fallback
		if "TILE_SIZE" in SettlementManager:
			tile_size = SettlementManager.TILE_SIZE
		
		# Scale based on Width to preserve aspect ratio (prevents squashing tall buildings)
		var target_width = building_data.grid_size.x * tile_size.x
		var tex_width = preview_sprite.texture.get_width()
		
		# Avoid divide by zero
		if tex_width > 0:
			var scale_factor = target_width / tex_width
			preview_sprite.scale = Vector2(scale_factor, scale_factor)
			
			# Offset so the sprite's "feet" (bottom of texture) sit on the tile center
			preview_sprite.offset = Vector2(0, -preview_sprite.texture.get_height() / 2.0)

	preview_sprite.modulate = valid_color
	add_child(preview_sprite)
	
	# 2. Create Isometric Outline
	_create_grid_outline(building_data.grid_size)
	
	is_active = true
	visible = true

func _process(_delta: float) -> void:
	if not is_active or not current_building_data: return
	
	var mouse_pos = get_global_mouse_position()
	
	# --- MATH DELEGATION ---
	# We rely on SettlementManager for the math to ensure it matches the game logic.
	var grid_pos = Vector2i.ZERO
	if SettlementManager:
		grid_pos = SettlementManager.world_to_grid(mouse_pos)
		# Snap visuals to the center of the calculated tile
		global_position = SettlementManager.grid_to_world(grid_pos)
	else:
		global_position = mouse_pos
	
	can_place = _can_place_at_position(grid_pos)
	
	_find_nearest_resource_node(global_position)
	_update_visual_feedback()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_active: return
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_preview()
			get_viewport().set_input_as_handled()

# --- HELPER FUNCTIONS ---

func _can_place_at_position(grid_pos: Vector2i) -> bool:
	if not SettlementManager: return false
	return SettlementManager.is_placement_valid(grid_pos, current_building_data.grid_size, current_building_data)

func place_building() -> void:
	if not is_active or not can_place: return
	
	# Re-calculate grid pos one last time to be safe
	if SettlementManager:
		var grid_pos = SettlementManager.world_to_grid(global_position)
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

func _update_visual_feedback() -> void:
	if not preview_sprite: return
	preview_sprite.modulate = valid_color if can_place else invalid_color

# --- VISUALIZATION LOGIC ---

func _find_nearest_resource_node(world_pos: Vector2) -> void:
	nearest_node = null
	if not current_building_data is EconomicBuildingData: return
		
	var target_type = (current_building_data as EconomicBuildingData).resource_type
	var min_dist = INF
	
	# Note: Ensure "resource_nodes" group is populated in your map generation!
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
	
	for node in nodes:
		if "resource_type" in node and node.resource_type == target_type:
			if node.has_method("is_depleted") and node.is_depleted(): continue
			
			var dist = world_pos.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_node = node

func _draw() -> void:
	if is_active and nearest_node:
		var start = Vector2.ZERO # Local origin (cursor center)
		var end = to_local(nearest_node.global_position)
		var dist = global_position.distance_to(nearest_node.global_position)
		
		# Check radius if the node has one, otherwise default to "close enough"
		var radius = 300.0
		if "district_radius" in nearest_node:
			radius = nearest_node.district_radius
			
		var is_in_range = dist <= radius
		var color = tether_color_valid if is_in_range else tether_color_invalid
		
		draw_line(start, end, color, 2.0)
		draw_circle(end, 5.0, color)

func _create_grid_outline(grid_size: Vector2i) -> void:
	_clear_grid_overlay()
	
	# Hardcoded Isometric Size (Safe Fallback)
	var tile_size = Vector2(64, 32)
	if "TILE_SIZE" in SettlementManager:
		tile_size = SettlementManager.TILE_SIZE
		
	var half_size = tile_size * 0.5
	
	# Isometric Vectors
	var iso_x_axis = Vector2(half_size.x, half_size.y)
	var iso_y_axis = Vector2(-half_size.x, half_size.y)
	
	# Calculate Corners (Diamond)
	# Top point is (0, -half_height) relative to center
	var p_top = Vector2(0, -half_size.y)
	var p_right = p_top + (iso_x_axis * float(grid_size.x))
	var p_bottom = p_right + (iso_y_axis * float(grid_size.y))
	var p_left = p_top + (iso_y_axis * float(grid_size.y))
	
	var points = PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top])
	
	var line = Line2D.new()
	line.points = points
	line.width = 2.0
	line.default_color = Color(0.2, 1.0, 0.2, 0.8)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	
	grid_overlay.add_child(line)

func _clear_grid_overlay() -> void:
	for child in grid_overlay.get_children(): child.queue_free()
