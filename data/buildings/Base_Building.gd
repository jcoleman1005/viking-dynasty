# res://scenes/buildings/Base_Building.gd
#
# --- MODIFIED: Added code to apply building_texture ---

class_name BaseBuilding
extends StaticBody2D

## This signal is emitted when health reaches zero.
## GDD Ref:
signal building_destroyed(building: BaseBuilding)

@export var data: BuildingData
var current_health: int = 100

# Get a reference to the Sprite2D node
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if not data:
		push_warning("BaseBuilding scene is missing its BuildingData resource.")
		return
	
	current_health = data.max_health
	
	# --- ADDED: Apply the texture from the data ---
	# This checks if a texture has been assigned in the .tres file
	if data.building_texture:
		# If it has, apply it to our Sprite2D node
		sprite.texture = data.building_texture
	# --- END ADDED ---

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	print("%s took %d damage, %d HP remaining." % [data.display_name, amount, current_health])
	
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been destroyed." % data.display_name)
	
	# Add visual feedback for destruction
	_show_destruction_effect()
	
	# --- ADDED ---
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
