# res://autoload/SceneManager.gd
#
# A global Singleton (Autoload) that handles all scene transitions.
# It listens for a signal on the EventBus and performs the change.
# This decouples all scenes from each other, preventing circular dependencies.

extends Node

func _ready() -> void:
	# Connect to the EventBus signal that all other scenes will use 
	EventBus.scene_change_requested.connect(_on_scene_change_requested)

func _on_scene_change_requested(scene_path: String) -> void:
	if scene_path.is_empty():
		push_error("SceneManager: scene_change_requested received an empty path.")
		return
	
	print("SceneManager: Changing to scene: %s" % scene_path)
	var error = get_tree().change_scene_to_file(scene_path)
	
	if error != OK:
		push_error("SceneManager: Failed to change to scene '%s'. Error code: %s" % [scene_path, error])
