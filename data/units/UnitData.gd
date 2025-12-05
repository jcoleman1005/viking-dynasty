# res://data/units/UnitData.gd
class_name UnitData
extends Resource

@export var display_name: String = "New Unit"
@export_file("*.tscn") var scene_path: String = ""
@export var scene_to_spawn: PackedScene # Hard reference fallback

@export var icon: Texture2D
@export var spawn_cost: Dictionary = {"food": 25}

@export_group("Combat Stats")
@export var max_health: int = 50
@export var move_speed: float = 75.0
@export var attack_damage: int = 8
@export var attack_speed: float = 1.2
## Distance to attack other units (keep small, e.g. 15)
@export var attack_range: float = 15.0 


@export_group("Visuals")
@export var visual_texture: Texture2D
@export var target_pixel_size: Vector2 = Vector2(32, 32)

@export_group("Movement Feel")
@export var acceleration: float = 10.0
@export var linear_damping: float = 5.0

@export var ai_component_scene: PackedScene
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0

func load_scene() -> PackedScene:
	# 1. Try Hard Reference (Fastest & Safest)
	if scene_to_spawn:
		return scene_to_spawn
		
	# 2. Try Soft Reference (Path)
	if scene_path == "":
		push_error("UnitData '%s': No scene_path AND no scene_to_spawn assigned!" % display_name)
		return null
		
	# 3. Handle UID vs Res paths
	# ResourceLoader.exists sometimes fails with UIDs, so we skip check if it's a UID
	if not scene_path.begins_with("uid://"):
		if not ResourceLoader.exists(scene_path):
			push_error("UnitData '%s': File not found at '%s'" % [display_name, scene_path])
			return null
		
	var scene = load(scene_path)
	if not scene:
		push_error("UnitData '%s': Failed to load resource at '%s'" % [display_name, scene_path])
		
	return scene
