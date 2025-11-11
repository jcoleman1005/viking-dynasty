# BuildingPreviewCursor.gd - RTS-style building placement system
extends Node2D
class_name BuildingPreviewCursor

# Building preview components
var current_building_data: BuildingData
var preview_sprite: Sprite2D
var is_active: bool = false

# Grid and placement
var cell_size: int = 32 
var grid_overlay: Node2D
var can_place: bool = false

# Visual feedback
var valid_color: Color = Color(0.0, 1.0, 0.0, 0.7)    # Green
var invalid_color: Color = Color(1.0, 0.0, 0.0, 0.7)  # Red

signal placement_completed
signal placement_cancelled

# --- NEW: Reference to GridManager for Phase 3 checks ---
var grid_manager: Node = null

func _ready() -> void:
	z_index = 100
	
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)
	
	# Find GridManager sibling
	grid_manager = get_parent().get_node_or_null("GridManager")
	
	print("BuildingPreviewCursor ready.")

func set_building_preview(building_data: BuildingData) -> void:
	if not building_data: return
	if cell_size <= 0: return
	
	print("Setting building preview for: %s" % building_data.display_name)
	current_building_data = building_data
	
	_cleanup_preview()
	
	preview_sprite = Sprite2D.new()
	preview_sprite.name = "PreviewSprite"
	
	if building_data.building_texture:
		preview_sprite.texture = building_data.building_texture
	else:
		var texture = _create_building_texture(building_data)
		preview_sprite.texture = texture
	
	# Scale
	var target_size: Vector2 = Vector2(building_data.grid_size) * cell_size
	if preview_sprite.texture:
		var texture_size: Vector2 = preview_sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			preview_sprite.scale = target_size / texture_size
	
	preview_sprite.modulate = valid_color
	add_child(preview_sprite)
	
	_create_grid_outline(building_data.grid_size)
	
	is_active = true
	visible = true

func _create_building_texture(building_data: BuildingData) -> ImageTexture:
	var size = Vector2i(building_data.grid_size.x * cell_size, building_data.grid_size.y * cell_size)
	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.6, 0.6, 0.6, 1.0))
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func _create_grid_outline(grid_size: Vector2i) -> void:
	_clear_grid_overlay()
	var outline_color = Color.WHITE
	var line_width = 2.0
	var rect_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	
	var points = [
		Vector2(0, 0), Vector2(rect_size.x, 0), 
		Vector2(rect_size.x, rect_size.y), Vector2(0, rect_size.y), 
		Vector2(0, 0)
	]
	
	var line = Line2D.new()
	line.points = points
	line.width = line_width
	line.default_color = outline_color
	grid_overlay.add_child(line)

func _clear_grid_overlay() -> void:
	for child in grid_overlay.get_children():
		child.queue_free()

func _process(_delta: float) -> void:
	if not is_active or not current_building_data: return
	
	var mouse_pos = get_global_mouse_position()
	var grid_pos = _world_to_grid(mouse_pos)
	global_position = _grid_to_world(grid_pos)
	
	can_place = _can_place_at_position(grid_pos)
	_update_visual_feedback()

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	if cell_size <= 0: return Vector2i.ZERO
	return Vector2i(int(world_pos.x / cell_size), int(world_pos.y / cell_size))

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)

# --- MODIFIED: Enforce Phase 3 Territory Constraints ---
func _can_place_at_position(grid_pos: Vector2i) -> bool:
	if not SettlementManager or not current_building_data:
		return false
	
	# 1. Check Collision (Is the ground solid?)
	if not SettlementManager.is_placement_valid(grid_pos, current_building_data.grid_size):
		return false
		
	# 2. Check Territory (Is it in the Green Zone?)
	if grid_manager and grid_manager.has_method("is_cell_buildable"):
		# We check every tile in the building's footprint
		for x in range(current_building_data.grid_size.x):
			for y in range(current_building_data.grid_size.y):
				var check_pos = grid_pos + Vector2i(x, y)
				# If ANY part of the building is outside territory, deny placement
				if not grid_manager.is_cell_buildable(check_pos):
					return false
	
	return true
# -----------------------------------------------------

func _update_visual_feedback() -> void:
	if not preview_sprite: return
	if can_place:
		preview_sprite.modulate = valid_color
		_set_grid_overlay_color(Color.GREEN)
	else:
		preview_sprite.modulate = invalid_color
		_set_grid_overlay_color(Color.RED)

func _set_grid_overlay_color(color: Color) -> void:
	for child in grid_overlay.get_children():
		if child is Line2D:
			child.default_color = color

func place_building() -> bool:
	if not is_active or not current_building_data or not can_place:
		return false
	
	var grid_pos = _world_to_grid(global_position)
	var new_building = SettlementManager.place_building(current_building_data, grid_pos, true)
	
	if new_building:
		placement_completed.emit()
		cancel_preview()
		return true
	return false

func cancel_preview() -> void:
	is_active = false
	visible = false
	current_building_data = null
	can_place = false
	_cleanup_preview()
	placement_cancelled.emit()

func _cleanup_preview() -> void:
	if preview_sprite:
		preview_sprite.queue_free()
		preview_sprite = null
	_clear_grid_overlay()

func _input(event: InputEvent) -> void:
	if not is_active: return
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_preview()
			get_viewport().set_input_as_handled()
