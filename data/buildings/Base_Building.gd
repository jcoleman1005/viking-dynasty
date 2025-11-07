# res://data/buildings/Base_Building.gd
#
# --- MODIFIED: (The "Proper Fix") ---
# Now uses SettlementManager.get_active_grid_cell_size()
# to get the grid size, instead of accessing a hard-coded
# .tile_size property.

class_name BaseBuilding
extends StaticBody2D

## This signal is emitted when health reaches zero.
## GDD Ref:
signal building_destroyed(building: BaseBuilding)

@export var data: BuildingData
var current_health: int = 100

# Get a reference to the nodes
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if not data:
		push_warning("BaseBuilding: Node is missing its 'BuildingData' resource. Cannot initialize.")
		return
	
	current_health = data.max_health
	
	# --- Apply Texture and Scaling ---
	_apply_texture_and_scale()

func _apply_texture_and_scale() -> void:
	"""
	Applies the texture from 'data' and scales both the
	sprite and collision shape to match the 'data.grid_size'.
	"""
	
	# 1. Validate SettlementManager and get the cell size
	if not SettlementManager:
		push_error("BaseBuilding: SettlementManager not ready. Cannot scale '%s'." % data.display_name)
		return
	
	# --- THIS IS THE FIX ---
	# Get the cell size from the manager, which gets it from the active grid
	var cell_size: Vector2 = SettlementManager.get_active_grid_cell_size()
	if cell_size.x <= 0 or cell_size.y <= 0:
		push_error("BaseBuilding: SettlementManager returned invalid cell_size (%s). Cannot scale '%s'." % [cell_size, data.display_name])
		return
	# --- END FIX ---
		
	# 2. Get the target size based on grid
	var target_size: Vector2 = Vector2(data.grid_size) * cell_size
	
	if target_size.x <= 0 or target_size.y <= 0:
		push_warning("BaseBuilding: '%s' has a grid_size of %s, resulting in an invalid target_size." % [data.display_name, data.grid_size])
		return

	# 3. Apply and Scale the Sprite
	if data.building_texture:
		sprite.texture = data.building_texture
		var texture_size: Vector2 = sprite.texture.get_size()
		
		if texture_size.x > 0 and texture_size.y > 0:
			# Non-uniform scaling to fill the grid space
			var new_scale: Vector2 = target_size / texture_size
			sprite.scale = new_scale
		else:
			push_warning("BaseBuilding: Texture for '%s' has an invalid size of %s. Cannot scale sprite." % [data.display_name, texture_size])
	else:
		push_warning("BaseBuilding: '%s' is missing its 'building_texture'. Sprite will be blank or use placeholder." % data.display_name)
		
	# 4. Scale the Collision Shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		# Set extents to *half* the target size (from center)
		collision_shape.shape.extents = target_size / 2.0
	else:
		push_warning("BaseBuilding: '%s' is missing its CollisionShape2D node or its shape is not a RectangleShape2D. Collision will not match visuals." % data.display_name)

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	# Removed the print statement for cleaner debug output
	# print("%s took %d damage, %d HP remaining." % [data.display_name, amount, current_health])
	
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been destroyed." % data.display_name)
	
	# Add visual feedback for destruction
	_show_destruction_effect()
	
	# Emit the signal *before* queue_free() so listeners
	# can react before the node is deleted.
	building_destroyed.emit(self)
	
	# Remove from groups before deletion
	remove_from_group("enemy_buildings")
	
	# Queue for deletion on the next frame
	print("Building %s queued for removal from scene" % data.display_name)
	queue_free()

func _show_destruction_effect() -> void:
	"""Add a simple visual destruction effect"""
	# Create a simple destruction tween for visual feedback
	var tween = create_tween()
	
	# Scale down and fade out
	tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	
	# Optional: Add rotation for dramatic effect
	tween.parallel().tween_property(self, "rotation", randf() * TAU, 0.3)
