# res://scenes/buildings/Base_Building.gd
#
# --- MODIFIED: Added 'building_destroyed' signal ---

class_name BaseBuilding
extends StaticBody2D

## This signal is emitted when health reaches zero.
## GDD Ref:
signal building_destroyed(building: BaseBuilding)

@export var data: BuildingData
var current_health: int = 100

func _ready() -> void:
	if not data:
		push_warning("BaseBuilding scene is missing its BuildingData resource.")
		return
	
	current_health = data.max_health

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	print("%s took %d damage, %d HP remaining." % [data.display_name, amount, current_health])
	
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been destroyed." % data.display_name)
	
	# --- ADDED ---
	# Emit the signal *before* queue_free() so listeners
	# can react before the node is deleted.
	building_destroyed.emit(self)
	
	queue_free()
