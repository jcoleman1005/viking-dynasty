# res://autoload/SceneManager.gd
extends Node

@export var settlement_scene: PackedScene
@export var world_map_scene: PackedScene
@export var raid_mission_scene: PackedScene

func _ready() -> void:
	EventBus.scene_change_requested.connect(_on_scene_change_requested)

func _on_scene_change_requested(scene_key: String) -> void:
	if scene_key.is_empty():
		Loggie.msg("scene_change_requested received an empty key.").domain("SCENE").error()
		return

	var target_scene: PackedScene = null
	match scene_key.to_lower():
		"settlement": target_scene = settlement_scene
		"world_map": target_scene = world_map_scene
		"raid_mission": target_scene = raid_mission_scene
		_:
			Loggie.msg("Unknown scene key '%s'." % scene_key).domain("SCENE").error()
			return

	if not target_scene:
		Loggie.msg("Scene key '%s' is valid, but PackedScene is missing!" % scene_key).domain("SCENE").error()
		return

	Loggie.msg("Changing to scene: %s (Key: %s)" % [target_scene.resource_path, scene_key]).domain("SCENE").info()
	var error = get_tree().change_scene_to_packed(target_scene)
	if error != OK:
		Loggie.msg("Failed to change scene. Error code: %s" % error).domain("SCENE").error()
