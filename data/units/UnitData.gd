# res://data/units/UnitData.gd
class_name UnitData
extends Resource

@export var display_name: String = "New Unit"

# --- SOFT REFERENCE ---
# This uses the file system picker, preventing typos.
@export_file("*.tscn") var scene_path: String = ""
# ----------------------

@export var icon: Texture2D
@export var spawn_cost: Dictionary = {"food": 25}

@export_group("Combat Stats")
@export var max_health: int = 50
@export var move_speed: float = 75.0
@export var attack_damage: int = 8
@export var attack_range: float = 10.0
@export var attack_speed: float = 1.2

@export_group("Visuals")
@export var visual_texture: Texture2D
@export var target_pixel_size: Vector2 = Vector2(32, 32)

@export_group("Movement Feel")
@export var acceleration: float = 10.0
@export var linear_damping: float = 5.0

@export var ai_component_scene: PackedScene
@export var projectile_scene: PackedScene # Restoring this too just in case
@export var projectile_speed: float = 400.0

# --- ROBUST LOADER ---
# Instead of just load(), we verify the file exists.
func load_scene() -> PackedScene:
	if scene_path == "":
		Loggie.msg("UnitData Error: No scene path assigned for %s" % display_name).domain("SYSTEM").error()
		return null
		
	if not ResourceLoader.exists(scene_path):
		Loggie.msg("UnitData Error: File not found at %s" % scene_path).domain("SYSTEM").error()
		return null
		
	return load(scene_path)
