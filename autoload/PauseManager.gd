# res://autoload/PauseManager.gd
#
# This is a global autoload script that listens for the 'ui_pause'
# input to pause the game.
# It is only responsible for *pausing* and instancing the menu.
# The menu itself is responsible for unpausing.

extends Node

# We will assign this scene in the Project Settings Autoload menu
@export var pause_menu_scene: PackedScene


func _unhandled_input(event: InputEvent) -> void:
	# We only listen for the pause input
	# We only pause if the game is NOT already paused
	if event.is_action_pressed("ui_pause") and not get_tree().paused:
		
		if not pause_menu_scene:
			push_error("PauseManager: 'pause_menu_scene' is not set in Project Settings!")
			return
		
		# Consume the event so nothing else (like the menu) can use it
		get_viewport().set_input_as_handled()
		
		# Pause the game
		get_tree().paused = true
		
		# Create the menu
		var menu = pause_menu_scene.instantiate()
		get_tree().root.add_child(menu)
