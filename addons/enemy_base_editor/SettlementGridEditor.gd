@tool
extends Control
class_name SettlementGridEditor

signal building_placed(building_data: BuildingData, position: Vector2i)
signal building_removed(position: Vector2i)
signal building_selected(building_data: BuildingData, position: Vector2i)

# Grid settings
const CELL_SIZE = 32
const GRID_WIDTH = 120
const GRID_HEIGHT = 80

# Visual settings
const GRID_COLOR = Color(0.3, 0.3, 0.3, 0.5)
const SELECTION_COLOR = Color(1.0, 1.0, 0.0, 0.8)
const VALID_PLACEMENT_COLOR = Color(0.0, 1.0, 0.0, 0.5)
const INVALID_PLACEMENT_COLOR = Color(1.0, 0.0, 0.0, 0.5)

# State
var current_settlement: SettlementData
var selected_building: BuildingData
var hovered_position: Vector2i = Vector2i(-1, -1)
var dragging: bool = false
var drag_start_position: Vector2i

# Visual elements
var grid_tiles: Array[Array] = []
var building_sprites: Dictionary = {} # position -> Sprite2D

func _ready():
	name = "SettlementGridEditor"
	custom_minimum_size = Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
	setup_grid()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup_grid():
	# Initialize grid tiles array
	grid_tiles.resize(GRID_WIDTH)
	for x in range(GRID_WIDTH):
		grid_tiles[x] = []
		grid_tiles[x].resize(GRID_HEIGHT)
		for y in range(GRID_HEIGHT):
			grid_tiles[x][y] = null

func set_settlement(settlement: SettlementData):
	current_settlement = settlement
	_update_visual_buildings()

func set_selected_building(building: BuildingData):
	selected_building = building
	queue_redraw()

func _update_visual_buildings():
	# Clear existing building sprites
	for sprite in building_sprites.values():
		if is_instance_valid(sprite):
			sprite.queue_free()
	building_sprites.clear()
	
	if not current_settlement:
		return
	
	# Create sprites for each building
	for building_entry in current_settlement.placed_buildings:
		var pos = building_entry["grid_position"]
		var building_data = load(building_entry["resource_path"]) as BuildingData
		if building_data:
			_create_building_sprite(building_data, pos)
	
	queue_redraw()

func _create_building_sprite(building_data: BuildingData, position: Vector2i):
	var sprite = Sprite2D.new()
	sprite.position = Vector2(position * CELL_SIZE) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	
	# Use building texture if available, otherwise create a colored rectangle
	if building_data.building_texture:
		sprite.texture = building_data.building_texture
		sprite.scale = Vector2(CELL_SIZE, CELL_SIZE) / sprite.texture.get_size()
	else:
		# Create a simple colored texture
		var texture = ImageTexture.new()
		var image = Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
		var color = _get_building_color(building_data)
		image.fill(color)
		texture.set_image(image)
		sprite.texture = texture
	
	add_child(sprite)
	building_sprites[position] = sprite

func _get_building_color(building_data: BuildingData) -> Color:
	# Assign colors based on building type
	var name = building_data.display_name.to_lower()
	if "wall" in name:
		return Color(0.7, 0.5, 0.3, 1.0) # Brown
	elif "hall" in name:
		return Color(0.8, 0.8, 0.2, 1.0) # Yellow
	elif "tower" in name or "watchtower" in name:
		return Color(0.5, 0.5, 0.8, 1.0) # Blue
	elif "lumber" in name or "wood" in name:
		return Color(0.3, 0.8, 0.3, 1.0) # Green
	elif "chapel" in name or "library" in name:
		return Color(0.8, 0.3, 0.8, 1.0) # Purple
	else:
		return Color(0.6, 0.6, 0.6, 1.0) # Gray

func _draw():
	_draw_grid()
	_draw_hover_preview()

func _draw_grid():
	# Draw grid lines
	for x in range(GRID_WIDTH + 1):
		var start_pos = Vector2(x * CELL_SIZE, 0)
		var end_pos = Vector2(x * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
		draw_line(start_pos, end_pos, GRID_COLOR, 1.0)
	
	for y in range(GRID_HEIGHT + 1):
		var start_pos = Vector2(0, y * CELL_SIZE)
		var end_pos = Vector2(GRID_WIDTH * CELL_SIZE, y * CELL_SIZE)
		draw_line(start_pos, end_pos, GRID_COLOR, 1.0)

func _draw_hover_preview():
	if hovered_position.x < 0 or hovered_position.y < 0:
		return
	
	var rect = Rect2(Vector2(hovered_position * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
	
	# Draw selection highlight
	draw_rect(rect, SELECTION_COLOR, false, 2.0)
	
	# Draw placement preview if building is selected
	if selected_building:
		var can_place = _can_place_building(selected_building, hovered_position)
		var preview_color = VALID_PLACEMENT_COLOR if can_place else INVALID_PLACEMENT_COLOR
		draw_rect(rect, preview_color)
		
		# Draw building name
		var font = ThemeDB.fallback_font
		var text = selected_building.display_name
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var text_pos = rect.position + (rect.size - text_size) * 0.5
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

func _gui_input(event):
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)

func _handle_mouse_motion(event: InputEventMouseMotion):
	var local_pos = event.position
	var grid_pos = Vector2i(local_pos / CELL_SIZE)
	
	if grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT:
		if hovered_position != grid_pos:
			hovered_position = grid_pos
			queue_redraw()
	else:
		if hovered_position != Vector2i(-1, -1):
			hovered_position = Vector2i(-1, -1)
			queue_redraw()

func _handle_mouse_button(event: InputEventMouseButton):
	if not event.pressed:
		return
	
	var local_pos = event.position
	var grid_pos = Vector2i(local_pos / CELL_SIZE)
	
	if grid_pos.x < 0 or grid_pos.x >= GRID_WIDTH or grid_pos.y < 0 or grid_pos.y >= GRID_HEIGHT:
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(grid_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(grid_pos)

func _handle_left_click(grid_pos: Vector2i):
	var existing_building = _get_building_at_position(grid_pos)
	
	if existing_building:
		# Select existing building
		building_selected.emit(existing_building, grid_pos)
	elif selected_building:
		# Try to place new building
		if _can_place_building(selected_building, grid_pos):
			building_placed.emit(selected_building, grid_pos)
			# Note: Don't create sprite here - let the main dock update settlement data
			# and then refresh the visual buildings through _update_visual_buildings()

func _handle_right_click(grid_pos: Vector2i):
	var existing_building = _get_building_at_position(grid_pos)
	if existing_building:
		# Remove building - the main dock will handle the data update and refresh
		building_removed.emit(grid_pos)

func _get_building_at_position(grid_pos: Vector2i) -> BuildingData:
	if not current_settlement:
		return null
	
	for building_entry in current_settlement.placed_buildings:
		if building_entry["grid_position"] == grid_pos:
			return load(building_entry["resource_path"]) as BuildingData
	
	return null

func _can_place_building(building_data, position: Vector2i) -> bool:
	if not current_settlement:
		return false
	
	# Check if position is within grid bounds
	if position.x < 0 or position.x >= GRID_WIDTH or position.y < 0 or position.y >= GRID_HEIGHT:
		return false
	
	# Check for building overlap
	return _get_building_at_position(position) == null

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	hovered_position = Vector2i(-1, -1)
	queue_redraw()

# Utility functions for external access
func get_grid_size() -> Vector2i:
	return Vector2i(GRID_WIDTH, GRID_HEIGHT)

func get_cell_size() -> int:
	return CELL_SIZE

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / CELL_SIZE)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos * CELL_SIZE) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
