# BuildingPreviewCursor.gd - RTS-style building placement system
extends Node2D
class_name BuildingPreviewCursor

# Building preview components
var current_building_data: BuildingData
var preview_sprite: Sprite2D
var is_active: bool = false

# Grid and placement
var cell_size: int = 32 # Default fallback
var grid_overlay: Node2D
var can_place: bool = false

# Visual feedback
var valid_color: Color = Color(0.0, 1.0, 0.0, 0.7)    # Green for valid placement
var invalid_color: Color = Color(1.0, 0.0, 0.0, 0.7)  # Red for invalid placement

signal placement_completed
signal placement_cancelled

func _ready() -> void:
	# Ensure we're always on top for visibility
	z_index = 100
	
	# Create grid overlay for visual feedback
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)
	
	# --- MODIFIED: Unify grid size source (from review) ---
	# Use SettlementManager as the single source of truth for grid size.
	if SettlementManager and SettlementManager.tile_size > 0:
		cell_size = int(SettlementManager.tile_size)
	else:
		# Use the local 32 only as a fallback if the manager fails
		push_warning("BuildingPreviewCursor: SettlementManager not ready or tile_size invalid. Defaulting to %d." % cell_size)
	# --- END MODIFICATION ---
	
	print("BuildingPreviewCursor ready with cell_size: %d" % cell_size)

func set_building_preview(building_data: BuildingData) -> void:
	"""Start building placement mode with the specified building"""
	if not building_data:
		print("ERROR: No building data provided to set_building_preview")
		return
	
	print("Setting building preview for: %s" % building_data.display_name)
	current_building_data = building_data
	
	# Clean up any existing preview
	_cleanup_preview()
	
	# Create new preview sprite
	preview_sprite = Sprite2D.new()
	preview_sprite.name = "PreviewSprite"
	
	# Set up the building texture
	if building_data.building_texture:
		preview_sprite.texture = building_data.building_texture
		# print("Using building texture for preview") # No longer needed
	else:
		# Create a simple colored rectangle if no texture
		var texture = _create_building_texture(building_data)
		preview_sprite.texture = texture
		print("Created fallback texture for preview")
	
	
	# --- Automatic Scaling Logic ---
	
	# 1. Get the target size based on grid
	# We can now safely use our local 'cell_size' because it's synced.
	var target_size: Vector2 = Vector2(building_data.grid_size) * cell_size
	
	# 2. Scale the Sprite (if texture exists)
	if preview_sprite.texture:
		var texture_size: Vector2 = preview_sprite.texture.get_size()
		
		if texture_size.x > 0 and texture_size.y > 0:
			var new_scale: Vector2 = target_size / texture_size
			preview_sprite.scale = new_scale
		else:
			push_warning("BuildingPreviewCursor: Texture for '%s' has invalid size %s. Cannot scale preview." % [building_data.display_name, texture_size])
	else:
		push_warning("BuildingPreviewCursor: No texture for '%s' preview." % building_data.display_name)
			
	# --- END SCALING LOGIC ---

	
	# Set semi-transparent
	preview_sprite.modulate = valid_color
	add_child(preview_sprite)
	
	# Create grid outline to show building footprint
	# This now correctly uses the synced 'cell_size'
	_create_grid_outline(building_data.grid_size)
	
	# Activate placement mode
	is_active = true
	visible = true
	
	# print("Building preview activated for %s (grid size: %s)" % [building_data.display_name, building_data.grid_size])

func _create_building_texture(building_data: BuildingData) -> ImageTexture:
	"""Create a simple colored texture for buildings without textures"""
	var size = Vector2i(
		building_data.grid_size.x * cell_size,
		building_data.grid_size.y * cell_size
	)
	
	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var color = _get_building_color(building_data)
	image.fill(color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func _create_grid_outline(grid_size: Vector2i) -> void:
	"""Create a visual outline showing the building's grid footprint"""
	_clear_grid_overlay()
	
	var outline_color = Color.WHITE
	var line_width = 2.0
	
	# This var 'rect_size' now correctly uses the synced 'cell_size'
	var rect_size = Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	
	# Create outline using Line2D nodes for each edge
	var lines = []
	
	# Top line
	var top_line = Line2D.new()
	top_line.add_point(Vector2(0, 0))
	top_line.add_point(Vector2(rect_size.x, 0))
	top_line.width = line_width
	top_line.default_color = outline_color
	lines.append(top_line)
	
	# Right line
	var right_line = Line2D.new()
	right_line.add_point(Vector2(rect_size.x, 0))
	right_line.add_point(Vector2(rect_size.x, rect_size.y))
	right_line.width = line_width
	right_line.default_color = outline_color
	lines.append(right_line)
	
	# Bottom line
	var bottom_line = Line2D.new()
	bottom_line.add_point(Vector2(rect_size.x, rect_size.y))
	bottom_line.add_point(Vector2(0, rect_size.y))
	bottom_line.width = line_width
	bottom_line.default_color = outline_color
	lines.append(bottom_line)
	
	# Left line
	var left_line = Line2D.new()
	left_line.add_point(Vector2(0, rect_size.y))
	left_line.add_point(Vector2(0, 0))
	left_line.width = line_width
	left_line.default_color = outline_color
	lines.append(left_line)
	
	# Add lines to grid overlay
	for line in lines:
		grid_overlay.add_child(line)

func _clear_grid_overlay() -> void:
	"""Clear the grid overlay visual elements"""
	for child in grid_overlay.get_children():
		child.queue_free()

func _get_building_color(building_data: BuildingData) -> Color:
	"""Get a representative color for the building type"""
	var name = building_data.display_name.to_lower()
	if "wall" in name:
		return Color(0.7, 0.5, 0.3, 1.0) # Brown
	elif "hall" in name:
		return Color(0.8, 0.8, 0.2, 1.0) # Yellow
	elif "tower" in name or "watchtower" in name:
		return Color(0.5, 0.5, 0.8, 1.0) # Blue
	elif "lumber" in name:
		return Color(0.3, 0.8, 0.3, 1.0) # Green
	elif "granary" in name:
		return Color(0.9, 0.6, 0.2, 1.0) # Orange
	elif "chapel" in name or "library" in name or "scriptorium" in name:
		return Color(0.8, 0.4, 0.8, 1.0) # Purple
	else:
		return Color(0.6, 0.6, 0.6, 1.0) # Gray

func _process(_delta: float) -> void:
	"""Update cursor position and placement validity"""
	if not is_active or not current_building_data:
		return
	
	# Get mouse position and snap to grid
	var mouse_pos = get_global_mouse_position()
	var grid_pos = _world_to_grid(mouse_pos)
	var snapped_world_pos = _grid_to_world(grid_pos)
	
	# Update cursor position
	global_position = snapped_world_pos
	
	# Check placement validity
	can_place = _can_place_at_position(grid_pos)
	
	# Update visual feedback
	_update_visual_feedback()

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	"""Convert world position to grid coordinates"""
	# Now safely uses the synced 'cell_size'
	return Vector2i(int(world_pos.x / cell_size), int(world_pos.y / cell_size))

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convert grid coordinates to world position (centered on cell)"""
	# Now safely uses the synced 'cell_size'
	return Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)

func _can_place_at_position(grid_pos: Vector2i) -> bool:
	"""Check if building can be placed by asking the SettlementManager."""
	if not SettlementManager or not current_building_data:
		return false
	
	# Delegate the check to the manager, which is the single source of truth
	return SettlementManager.is_placement_valid(grid_pos, current_building_data.grid_size)

func _update_visual_feedback() -> void:
	"""Update the visual appearance based on placement validity"""
	if not preview_sprite:
		return
	
	# Change color based on placement validity
	if can_place:
		preview_sprite.modulate = valid_color
		_set_grid_overlay_color(Color.GREEN)
	else:
		preview_sprite.modulate = invalid_color
		_set_grid_overlay_color(Color.RED)

func _set_grid_overlay_color(color: Color) -> void:
	"""Set the color of the grid overlay lines"""
	for child in grid_overlay.get_children():
		if child is Line2D:
			child.default_color = color

func place_building() -> bool:
	"""Attempt to place the building at current position"""
	if not is_active or not current_building_data or not can_place:
		print("Cannot place building: not active (%s), no data (%s), or invalid position (%s)" % [is_active, current_building_data != null, can_place])
		return false
	
	var grid_pos = _world_to_grid(global_position)
	
	print("Attempting to place %s at grid position %s" % [current_building_data.display_name, grid_pos])
	
	# Place building through SettlementManager
	var new_building = SettlementManager.place_building(current_building_data, grid_pos)
	
	if new_building:
		print("Successfully placed building: %s" % current_building_data.display_name)
		placement_completed.emit()
		cancel_preview()
		return true
	else:
		print("Failed to place building through SettlementManager")
		return false

func cancel_preview() -> void:
	"""Cancel building placement and clean up"""
	print("Cancelling building preview")
	
	is_active = false
	visible = false
	current_building_data = null
	can_place = false
	
	_cleanup_preview()
	placement_cancelled.emit()

func _cleanup_preview() -> void:
	"""Clean up preview visual elements"""
	if preview_sprite:
		preview_sprite.queue_free()
		preview_sprite = null
	
	_clear_grid_overlay()

func _input(event: InputEvent) -> void:
	"""Handle input for building placement"""
	if not is_active:
		return
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Attempt to place building
			if place_building():
				print("Building placed successfully")
			else:
				print("Failed to place building")
			get_viewport().set_input_as_handled()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Cancel placement
			print("Building placement cancelled by right click")
			cancel_preview()
			get_viewport().set_input_as_handled()
