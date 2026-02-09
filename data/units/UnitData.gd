#res://data/units/UnitData.gd
### FILE: res://data/units/UnitData.gd ###
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
@export var attack_range: float = 15.0 
@export var building_attack_range: float = 45.0

@export_group("Inventory & Logistics")
## Maximum gold/resources this unit can carry before capping out.
@export var max_loot_capacity: int = 100 
## Percentage of speed lost when fully encumbered (0.0 - 1.0). 0.5 = 50% slower.
@export var encumbrance_speed_penalty: float = 0.5 # 50% slow at max load

@export_group("Visuals")
@export var visual_texture: Texture2D
@export var target_pixel_size: Vector2 = Vector2(32, 32)

@export_group("Movement Feel")
@export var acceleration: float = 10.0
@export var linear_damping: float = 5.0

@export_group("Raid Stats")
@export var pillage_speed: int = 10 
@export var burn_renown: int = 10
@export var ai_component_scene: PackedScene
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0

@export_group("Social Stats")
@export var wergild_cost: int = 50

func load_scene() -> PackedScene:
	if scene_to_spawn:
		return scene_to_spawn
	if scene_path != "":
		return load(scene_path)
	return null
