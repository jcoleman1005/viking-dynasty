# res://data/buildings/BuildingData.gd
# Defines the core data for any building in the game.
class_name BuildingData
extends Resource

## The name displayed in the UI.
@export var display_name: String = "New Building"
@export var scene_to_spawn: PackedScene
@export var icon: Texture2D
@export var building_texture: Texture2D
@export var build_cost: Dictionary
@export var max_health: int = 100
@export var blocks_pathfinding: bool = true
@export var grid_size: Vector2i = Vector2i.ONE
@export var dev_color: Color = Color.GRAY
@export var is_player_buildable: bool = false

@export_group("Construction")
@export var construction_effort_required: int = 100
@export var base_labor_capacity: int = 3

@export_group("Territory & Expansion")
## If true, this building generates territory even if not connected to anything (e.g., Great Hall).
@export var is_territory_hub: bool = false

## If true, this building extends territory if connected to a Hub (e.g., Walls, Roads).
@export var extends_territory: bool = false

## The radius of buildable land this building provides around itself.
@export var territory_radius: int = 4
# -----------------------------------------

@export_group("Defensive Stats")
@export var is_defensive_structure: bool = false
@export var attack_damage: int = 5
@export var attack_range: float = 200.0
@export var attack_speed: float = 1.0
@export var ai_component_scene: PackedScene
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0
