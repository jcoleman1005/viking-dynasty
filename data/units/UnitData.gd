# res://data/units/UnitData.gd
#
# Defines the core data for any unit in the game.
# This resource is used by Base_Unit.tscn to configure instances.
# GDD Ref: 7.C.1.b

class_name UnitData
extends Resource

## The name displayed in the UI (e.g., "Viking Raider").
@export var display_name: String = "New Unit"

## The scene that will be instanced when this unit is spawned.
@export var scene_to_spawn: PackedScene

## The icon shown in the training menu.
@export var icon: Texture2D

## The cost in 'Resources' to train this unit.
@export var spawn_cost: Dictionary = {"food": 25}


@export_group("Combat Stats")
## The unit's maximum hit points.
@export var max_health: int = 50

## Movement speed in pixels per second.
@export var move_speed: float = 75.0

## Damage dealt per attack.
@export var attack_damage: int = 8

## Range in pixels. (e.g., 10 for melee, 300 for archer).
@export var attack_range: float = 10.0

## Attacks per second.
@export var attack_speed: float = 1.2
