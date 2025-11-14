# res://ui/PauseMenu.gd
#
# This script controls the pause menu itself.
# It runs while the game is paused (Process Mode = "When Paused").
# It is responsible for unpausing the game.

extends CanvasLayer

@onready var resume_button: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var save_button: Button = $PanelContainer/VBoxContainer/SaveButton
@onready var quit_button: Button = $PanelContainer/VBoxContainer/QuitButton


func _ready() -> void:
	# Connect signals in code
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	# Also allow 'Escape' to close the pause menu
	if event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled() # Consume the event
		_on_resume_pressed()


func _on_resume_pressed() -> void:
	"""Unpauses the game and removes the menu."""
	get_tree().paused = false
	queue_free() # Destroy the menu


func _on_save_pressed() -> void:
	"""Saves the game state via the SettlementManager."""
	if SettlementManager.has_current_settlement():
		SettlementManager.save_settlement()
		Loggie.msg("Game saved from pause menu.").domain("UI").info()
	else:
		Loggie.msg("Pause Menu: No settlement loaded, cannot save.").domain("UI").info()


func _on_quit_pressed() -> void:
	"""Quits the game."""
	get_tree().quit()
