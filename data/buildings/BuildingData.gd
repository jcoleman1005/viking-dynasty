# res://data/buildings/BuildingData.gd
#
# Defines the core data for any building in the game.
# --- MODIFIED: Added Construction Stats for Phase 1.1 ---

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

## Development visual color for the building rectangle.
@export var dev_color: Color = Color.GRAY

## If true, this building will appear in the player's Storefront UI.
@export var is_player_buildable: bool = false

# --- NEW: Phase 1.1 Construction Stats ---
@export_group("Construction")
## Total work points required to finish construction.
@export var construction_effort_required: int = 100

## Max workers allowed to build this at once (prevents zerging small buildings).
@export var base_labor_capacity: int = 3
# -----------------------------------------

@export_group("Defensive Stats")
## If true, this building can attack enemies (e.g., Watchtower).
@export var is_defensive_structure: bool = false

## Damage dealt per attack (if defensive).
@export var attack_damage: int = 5

## Range in pixels (if defensive).
@export var attack_range: float = 200.0

## Attacks per second (if defensive).
@export var attack_speed: float = 1.0

## An optional AI scene to instance (e.g., for defensive buildings)
@export var ai_component_scene: PackedScene

## The projectile scene to spawn when this building attacks (for defensive structures).
@export var projectile_scene: PackedScene

## The speed of the projectile, in pixels per second.
@export var projectile_speed: float = 400.0
