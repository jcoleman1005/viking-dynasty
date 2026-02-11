## res://data/buildings/BuildingData.gd
## The master data template for all settlement structures.
class_name BuildingData
extends Resource

@export_group("General Info")
## The human-readable name shown in the UI.
@export var display_name: String = "New Building"
## Narrative description for tooltips and the Building Codex.
@export_multiline var description: String = "A useful structure."
## The actual gameplay scene instantiated when this building is placed.
@export var scene_to_spawn: PackedScene

@export_group("Visuals")
## Small icon used in HUD and menus.
@export var icon: Texture2D
## World-space texture used for previews or UI icons.
@export var building_texture: Texture2D
## Debug color used for editor-only gizmos or placeholders.
@export var dev_color: Color = Color.GRAY

@export_group("Winter Survival")
## Base wood/fuel cost required to heat this structure per day during Winter.
@export var heating_cost: int = 2
## If true, this building acts as a heat source or provides passive insulation, 
## reducing the total settlement demand by a calculated factor.
@export var provides_insulation: bool = false

@export_group("Economy & Construction")
## Dictionary[String, int] mapping resource IDs (e.g., "wood", "stone") to amounts.
@export var build_cost: Dictionary
## Total labor points required to finish construction.
@export var construction_effort_required: int = 100
## Base number of workers this building can support during construction.
@export var base_labor_capacity: int = 3
## If false, this building cannot be selected from the player's build menu.
@export var is_player_buildable: bool = false

@export_group("Placement & Physics")
## Grid footprint of the building in tiles (x, y).
@export var grid_size: Vector2i = Vector2i.ONE
## If true, units must pathfind around this structure.
@export var blocks_pathfinding: bool = true
## Initial structural integrity.
@export var max_health: int = 100

@export_group("Territory & Expansion")
## Authoritative hub for a territory zone (e.g., a Great Hall).
@export var is_territory_hub: bool = false
## If true, this building pushes the settlement borders outward.
@export var extends_territory: bool = false
## The range (in tiles) this building adds to the territory.
@export var territory_radius: int = 4

@export_group("Demographics & Military")
## Number of Squads (not individuals) this building adds to the total fleet capacity.
@export var fleet_capacity_bonus: int = 0
## Amount of arable land (for food production) this building manages.
@export var arable_land_capacity: int = 0 

@export_group("Defensive Stats")
## Enables combat logic for this building (e.g., Watchtowers).
@export var is_defensive_structure: bool = false
## Damage dealt per projectile hit.
@export var attack_damage: int = 5
## Maximum firing range in world units.
@export var attack_range: float = 200.0
## Delay (in seconds) between attacks.
@export var attack_speed: float = 1.0
## Logic component defining targeting behavior.
@export var ai_component_scene: PackedScene
## The projectile scene fired at targets.
@export var projectile_scene: PackedScene
## Speed of the projectile in world units per second.
@export var projectile_speed: float = 400.0
