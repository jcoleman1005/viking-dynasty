# res://scenes/buildings/Base_Building.gd
#
# Base script for all buildings in the game.
# It holds a reference to its BuildingData resource and applies
# those stats on _ready().
# GDD Ref: 7.C.2.c

class_name BaseBuilding
extends StaticBody2D

## Assign the BuildingData resource (e.g., Bldg_Wall.tres) here.
@export var data: BuildingData

## The current health of the building.
var current_health: int = 100

func _ready() -> void:
	if not data:
		push_warning("BaseBuilding scene is missing its BuildingData resource.")
		return
	
	# Apply stats from the data resource.
	current_health = data.max_health
	
	# Future logic will go here, e.g., setting up the Sprite2D
	# based on the data.icon, or setting the CollisionShape2D
	# based on the data.grid_size.
	
	# We will connect signals for taking damage here in code
	# once the relevant systems (like Combat) exist.

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	print("%s took %d damage, %d HP remaining." % [data.display_name, amount, current_health])
	
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been destroyed." % data.display_name)
	# In the future, we will emit a signal here, e.g.,
	# EventBus.building_destroyed.emit(self)
	# and then queue_free().
	queue_free()
