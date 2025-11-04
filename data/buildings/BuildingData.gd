# res://data/buildings/BuildingData.gd
#
# Defines the core data for any building in the game.
#
# --- MODIFIED: Added 'class_name BuildingData' ---

class_name BuildingData
extends Resource

## The name displayed in the UI (e.g., "Stone Wall", "Watchtower").
@export var display_name: String = "New Building"

## The scene that will be instanced when this building is placed.
@export var scene_to_spawn: PackedScene

## The icon shown in the build menu.
@export var icon: Texture2D

## Texture shown on screen
@export var building_texture: Texture2D

## The cost in 'Resources' (e.g., wood, gold) to build this.
@export var build_cost: Dictionary

## The building's maximum hit points.
@export var max_health: int = 100

## If true, this building blocks enemy pathfinding.
@export var blocks_pathfinding: bool = true

## The size of the building on the AStarGrid2D.
@export var grid_size: Vector2i = Vector2i.ONE


@export_group("Defensive Stats")
## If true, this building can attack enemies (e.g., Watchtower).
@export var is_defensive_structure: bool = false

## Damage dealt per attack (if defensive).
@export var attack_damage: int = 5

## Range in pixels (if defensive).
@export var attack_range: float = 200.0

## Attacks per second (if defensive).
@export var attack_speed: float = 1.0
