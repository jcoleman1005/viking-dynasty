# res://data/units/UnitData.gd
class_name UnitData
extends Resource

@export var display_name: String = "New Unit"

# --- SOFT REFERENCE (Preferred) ---
@export_file("*.tscn") var scene_path: String = ""

# --- HARD REFERENCE (Legacy/Fallback) ---
@export var scene_to_spawn: PackedScene
# ----------------------------------------

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
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0

# --- ROBUST LOADER ---
func load_scene() -> PackedScene:
	# 1. Try Loading from Path (Preferred)
	if scene_path != "":
		if ResourceLoader.exists(scene_path):
			return load(scene_path)
		else:
			Loggie.msg("UnitData Error: File not found at %s" % scene_path).domain("SYSTEM").error()
	
	# 2. Fallback to Hard Reference (Legacy support)
	if scene_to_spawn:
		return scene_to_spawn
		
	# 3. Failure
	Loggie.msg("UnitData Error: No scene assigned for %s" % display_name).domain("SYSTEM").error()
	return null
