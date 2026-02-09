#res://autoload/PauseManager.gd
# res://autoload/PauseManager.gd
#
# This is a global autoload script that listens for the 'ui_pause'
# input to pause the game.
# It is only responsible for *pausing* and instancing the menu.
# The menu itself is responsible for unpausing.

extends Node

# We will assign this scene in the Project Settings Autoload menu
@export var pause_menu_scene: PackedScene

func _ready() -> void:
	Loggie.info("PauseManager initialized", "PauseManager")
	if pause_menu_scene:
		Loggie.debug("Pause menu scene loaded: %s" % pause_menu_scene.resource_path, "PauseManager")
	else:
		Loggie.warn("Pause menu scene not assigned in PauseManager", "PauseManager")

func _unhandled_input(event: InputEvent) -> void:
	# We only listen for the pause input
	# We only pause if the game is NOT already paused
	if event.is_action_pressed("ui_pause"):
		Loggie.debug("Pause input detected (ui_pause pressed)", "PauseManager")
		
		var current_pause_state := get_tree().paused
		Loggie.debug("Current pause state: %s" % ("PAUSED" if current_pause_state else "UNPAUSED"), "PauseManager")
		
		if not current_pause_state:
			Loggie.info("Attempting to pause game", "PauseManager")
			_pause_game()
		else:
			Loggie.debug("Game already paused - ignoring pause input", "PauseManager")
	
func _pause_game() -> void:
	if not pause_menu_scene:
		var error_msg := "PauseManager: 'pause_menu_scene' is not set in Project Settings!"
		Loggie.error(error_msg, "PauseManager")
		push_error(error_msg)
		return
	
	Loggie.debug("Pause menu scene validated: %s" % pause_menu_scene.resource_path, "PauseManager")
	
	# Consume the event so nothing else (like the menu) can use it
	get_viewport().set_input_as_handled()
	Loggie.debug("Input event consumed to prevent propagation", "PauseManager")
	
	# Pause the game
	get_tree().paused = true
	Loggie.info("Game paused - SceneTree.paused = true", "PauseManager")
	
	# Create the menu
	Loggie.debug("Instantiating pause menu from scene", "PauseManager")
	var menu := pause_menu_scene.instantiate()
	
	if menu:
		get_tree().root.add_child(menu)
		Loggie.info("Pause menu instantiated and added to scene tree", "PauseManager")
		Loggie.debug("Pause menu node name: %s, type: %s" % [menu.name, menu.get_class()], "PauseManager")
		
		# Log the current children count for debugging
		var root_children := get_tree().root.get_children()
		Loggie.debug("Root node now has %d children" % root_children.size(), "PauseManager")
	else:
		Loggie.error("Failed to instantiate pause menu scene", "PauseManager")

# Public method for external pause requests (e.g., from other systems)
func request_pause() -> void:
	Loggie.info("External pause request received", "PauseManager")
	if not get_tree().paused:
		_pause_game()
	else:
		Loggie.warn("External pause request ignored - game already paused", "PauseManager")

# Public method to check pause state
func is_game_paused() -> bool:
	var paused := get_tree().paused
	Loggie.debug("Pause state query: %s" % ("PAUSED" if paused else "UNPAUSED"), "PauseManager")
	return paused

# Called when pause menu unpauses the game
func on_game_unpaused() -> void:
	Loggie.info("Game unpaused notification received", "PauseManager")
	if get_tree().paused:
		Loggie.warn("Game reported as unpaused but SceneTree.paused is still true", "PauseManager")
	else:
		Loggie.debug("Game successfully unpaused - SceneTree.paused = false", "PauseManager")
