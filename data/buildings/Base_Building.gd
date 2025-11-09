# res://data/buildings/Base_Building.gd
#
# --- MODIFIED: (Dev Art Fix) ---
# Now uses a ColorRect and Label instead of a Sprite2D.
class_name BaseBuilding
extends StaticBody2D

## This signal is emitted when health reaches zero.
signal building_destroyed(building: BaseBuilding)

@export var data: BuildingData
var current_health: int = 100

# Get a reference to the new nodes
@onready var background: ColorRect = $ColorRect
@onready var label: Label = $ColorRect/Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Development visual enhancements
var health_bar: ProgressBar
var border_rect: ColorRect

func _ready() -> void:
	if not data:
		push_warning("BaseBuilding: Node is missing its 'BuildingData' resource. Cannot initialize.")
		return
	
	current_health = data.max_health
	
	# --- Apply Data and Scaling ---
	_apply_data_and_scale()
	
	# --- Create Development Visuals ---
	_create_dev_visuals()

func _apply_data_and_scale() -> void:
	"""
	Applies the data from the .tres file and scales the
	ColorRect and collision shape to match the 'data.grid_size'.
	"""
	
	# 1. Validate SettlementManager and get the cell size
	if not SettlementManager:
		push_error("BaseBuilding: SettlementManager not ready. Cannot scale '%s'." % data.display_name)
		return
	
	var cell_size: Vector2 = SettlementManager.get_active_grid_cell_size()
	if cell_size.x <= 0 or cell_size.y <= 0:
		push_error("BaseBuilding: SettlementManager returned invalid cell_size (%s). Cannot scale '%s'." % [cell_size, data.display_name])
		return
		
	# 2. Get the target size based on grid
	var target_size: Vector2 = Vector2(data.grid_size) * cell_size
	
	if target_size.x <= 0 or target_size.y <= 0:
		push_warning("BaseBuilding: '%s' has a grid_size of %s, resulting in an invalid target_size." % [data.display_name, data.grid_size])
		return

	# 3. Apply and Scale the Background
	background.custom_minimum_size = target_size
	
	# --- THIS IS THE FIX (PART 1) ---
	# Shift the background's position so it's centered on the node's origin,
	# just like the collision shape.
	background.position = -target_size / 2.0
	
	# 4. Apply Enhanced Visual Styling
	_apply_visual_styling(target_size)

	# 5. Scale the Collision Shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		# Set size to match the target size (Godot 4.x uses 'size', not 'extents')
		collision_shape.shape.size = target_size
	else:
		# --- THIS IS THE BUG FIX ---
		# The '%' format string now correctly uses brackets [].
		push_warning("BaseBuilding: '%s' is missing its CollisionShape2D node or its shape is not a RectangleShape2D. Collision will not match visuals." % [data.display_name])
		# --- END BUG FIX ---

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	
	# Update health bar if it exists
	if health_bar:
		health_bar.value = current_health
	
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been destroyed." % data.display_name)
	
	_show_destruction_effect()
	
	building_destroyed.emit(self)
	
	remove_from_group("enemy_buildings")
	
	print("Building %s queued for removal from scene" % data.display_name)
	queue_free()

func _show_destruction_effect() -> void:
	"""Add a simple visual destruction effect"""
	var tween = create_tween()
	
	tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.parallel().tween_property(self, "rotation", randf() * TAU, 0.3)

func _apply_visual_styling(target_size: Vector2) -> void:
	"""Enhanced visual styling with color coding and improved label"""
	# Apply building name
	label.text = data.display_name
	label.custom_minimum_size = target_size
	
	# Enhanced label properties
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Adjust font size based on building size
	if target_size.x < 64:
		label.add_theme_font_size_override("font_size", 10)
	elif target_size.x < 128:
		label.add_theme_font_size_override("font_size", 12)
	else:
		label.add_theme_font_size_override("font_size", 14)
	
	# Apply color coding based on building type
	_apply_color_coding()

func _apply_color_coding() -> void:
	"""Apply colors based on building type and properties"""
	var base_color: Color
	
	# Use custom color if set, otherwise use type-based colors
	if data.dev_color != Color.TRANSPARENT and data.dev_color != Color.GRAY:
		base_color = data.dev_color
	else:
		# Color coding by building type
		if data.is_defensive_structure:
			base_color = Color.CRIMSON * 0.8
		elif data.is_player_buildable:
			base_color = Color.ROYAL_BLUE * 0.8
		else:
			base_color = Color.GRAY * 0.8
	
	background.color = base_color

func _create_dev_visuals() -> void:
	"""Create additional development visual aids"""
	if not data:
		return
		
	var target_size: Vector2 = Vector2(data.grid_size) * SettlementManager.get_active_grid_cell_size()
	
	# Create border for defensive structures
	if data.is_defensive_structure:
		_create_border(target_size)
	
	# Create health bar for all buildings
	_create_health_bar(target_size)

func _create_border(target_size: Vector2) -> void:
	"""Create a border rect for defensive buildings"""
	border_rect = ColorRect.new()
	border_rect.color = Color.DARK_RED
	border_rect.custom_minimum_size = target_size + Vector2(4, 4)
	border_rect.position = -border_rect.custom_minimum_size / 2.0
	add_child(border_rect)
	move_child(border_rect, 0)  # Behind main background

func _create_health_bar(target_size: Vector2) -> void:
	"""Create a health bar above the building"""
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(target_size.x, 6)
	health_bar.position = Vector2(-target_size.x/2, -target_size.y/2 - 10)
	health_bar.max_value = data.max_health
	health_bar.value = current_health
	
	# Style the health bar
	health_bar.modulate = Color.WHITE
	add_child(health_bar)
