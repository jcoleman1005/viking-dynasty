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
@export var projectile_scene: PackedScene 
@export var projectile_speed: float = 400.0

# --- ROBUST LOADER ---
func load_scene() -> PackedScene:
	# 1. Check for empty string (The issue we just faced)
	if scene_path == "":
		var msg = "UnitData CRITICAL: Unit '%s' has NO 'scene_path' assigned! Please fix in Inspector." % display_name
		
		# Log to Loggie for history
		Loggie.msg(msg).domain("SYSTEM").error()
		
		# Push to Godot Debugger (Red Error)
		push_error(msg) 
		return null
		
	# 2. Check if file actually exists on disk
	if not ResourceLoader.exists(scene_path):
		var msg = "UnitData CRITICAL: File not found at '%s' for unit '%s'. Has it been moved?" % [scene_path, display_name]
		Loggie.msg(msg).domain("SYSTEM").error()
		push_error(msg)
		return null
		
	# 3. Attempt load
	var scene = load(scene_path)
	if not scene:
		var msg = "UnitData CRITICAL: Failed to load resource at '%s'. File may be corrupt." % scene_path
		Loggie.msg(msg).domain("SYSTEM").error()
		push_error(msg)
		return null
		
	# 4. Success
	return scene
