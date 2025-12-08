# res://data/units/UnitData.gd
class_name UnitData
extends Resource

@export var display_name: String = "New Unit"
@export_file("*.tscn") var scene_path: String = ""
@export var scene_to_spawn: PackedScene 

@export var icon: Texture2D
@export var spawn_cost: Dictionary = {"food": 25}

@export_group("Combat Stats")
@export var max_health: int = 50
@export var move_speed: float = 75.0
@export var attack_damage: int = 8
@export var attack_speed: float = 1.2

# --- RESTORED: Range Configuration ---
@export var attack_range: float = 15.0 
## Larger range for buildings to account for their size/collision
@export var building_attack_range: float = 45.0
# -------------------------------------

@export_group("Visuals")
@export var visual_texture: Texture2D
@export var target_pixel_size: Vector2 = Vector2(32, 32)

@export_group("Movement Feel")
@export var acceleration: float = 10.0
@export var linear_damping: float = 5.0

@export_group("Raid Stats")
## How many resource points this unit steals per second.
@export var pillage_speed: int = 10 
## Renown earned for burning a building.
@export var burn_renown: int = 10

@export var ai_component_scene: PackedScene
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0

func load_scene() -> PackedScene:
	if scene_to_spawn: return scene_to_spawn
	if scene_path == "": return null
	if not scene_path.begins_with("uid://") and not ResourceLoader.exists(scene_path): return null
	return load(scene_path)
