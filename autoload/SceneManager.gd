# res://autoload/SceneManager.gd
#
# A global Singleton (Autoload) that handles all scene transitions.
# It listens for a signal on the EventBus and performs the change.
# This decouples all scenes from each other, preventing circular dependencies.
extends Node

# --- Phase 1 Refactor: PackedScene Exports ---
# Assign these in the Godot Editor (Project > Project Settings > Autoload > SceneManager)
@export var settlement_scene: PackedScene
@export var world_map_scene: PackedScene
@export var raid_mission_scene: PackedScene
# ---------------------------------------------

func _ready() -> void:
	# Connect to the EventBus signal that all other scenes will use 
	EventBus.scene_change_requested.connect(_on_scene_change_requested)

func _on_scene_change_requested(scene_key: String) -> void:
	if scene_key.is_empty():
		push_error("SceneManager: scene_change_requested received an empty key.")
		return

	var target_scene: PackedScene = null
	
	# Match the string key to the exported PackedScene
	match scene_key.to_lower():
		"settlement":
			target_scene = settlement_scene
		"world_map":
			target_scene = world_map_scene
		"raid_mission":
			target_scene = raid_mission_scene
		_:
			push_error("SceneManager: Unknown scene key '%s'. No scene transition will occur." % scene_key)
			return

	if not target_scene:
		push_error("SceneManager: Scene key '%s' is valid, but its PackedScene is not assigned in the Inspector!" % scene_key)
		return

	print("SceneManager: Changing to scene: %s (Key: %s)" % [target_scene.resource_path, scene_key])
	var error = get_tree().change_scene_to_packed(target_scene)
	
	if error != OK:
		push_error("SceneManager: Failed to change to scene '%s'. Error code: %s" % [target_scene.resource_path, error])
