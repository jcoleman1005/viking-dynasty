# res://data/buildings/BuildingData.gd
#
# Defines the core data for any building in the game.
# This resource is used by Base_Building.tscn to configure instances.
# GDD Ref: 7.C.1.a

class_name BuildingData
extends Resource

## The name displayed in the UI (e.g., "Stone Wall", "Watchtower").
@export var display_name: String = "New Building"

## The scene that will be instanced when this building is placed.
@export var scene_to_spawn: PackedScene

## The icon shown in the build menu.
@export var icon: Texture2D

## The cost in 'Resources' (e.g., wood, gold) to build this.
@export var build_cost: int = 10

## The building's maximum hit points.
@export var max_health: int = 100

## If true, this building blocks enemy pathfinding.
## GDD Ref:
@export var blocks_pathfinding: bool = true

## The size of the building on the AStarGrid2D.
## GDD Ref:
@export var grid_size: Vector2i = Vector2i.ONE


@export_group("Defensive Stats")
## If true, this building can attack enemies (e.g., Watchtower).
## GDD Ref:
@export var is_defensive_structure: bool = false

## Damage dealt per attack (if defensive).
@export var attack_damage: int = 5

## Range in pixels (if defensive).
@export var attack_range: float = 200.0

## Attacks per second (if defensive).
@export var attack_speed: float = 1.0
