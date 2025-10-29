# res://scenes/units/Base_Unit.gd
#
# Base script for all units in the game.
# It holds a reference to its UnitData resource and applies stats.
# GDD Ref: 7.C.3.b

class_name BaseUnit
extends CharacterBody2D

## Assign the UnitData resource (e.g., Unit_Raider.tres) here.
@export var data: UnitData

## The current health of the unit.
var current_health: int = 50

func _ready() -> void:
	if not data:
		push_warning("BaseUnit scene is missing its UnitData resource.")
		return
	
	# Apply stats from the data resource.
	current_health = data.max_health
	
	# We can apply stats directly to the CharacterBody2D
	self.set_meta("move_speed", data.move_speed)
	
	# In a real implementation, the AI state machine (Task 4)
	# would read this "move_speed" meta property.

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	print("%s took %d damage, %d HP remaining." % [data.display_name, amount, current_health])
	
	if current_health == 0:
		die()

func die() -> void:
	print("%s has been killed." % data.display_name)
	# In the future, we will emit a signal here, e.g.,
	# EventBus.unit_killed.emit(self)
	# and then queue_free().
	queue_free()
