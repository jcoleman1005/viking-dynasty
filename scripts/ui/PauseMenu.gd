# res://scripts/ui/PauseMenu.gd
#
# This script controls the pause menu itself.
# It runs while the game is paused (Process Mode = "When Paused").
# It is responsible for unpausing the game.

extends CanvasLayer

@onready var resume_button: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var save_button: Button = $PanelContainer/VBoxContainer/SaveButton
@onready var new_game_button: Button = $PanelContainer/VBoxContainer/NewGameButton
@onready var quit_button: Button = $PanelContainer/VBoxContainer/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect signals in code
	
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	else:
		push_warning("PauseMenu: NewGameButton node not found!")
		
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


func _on_new_game_pressed() -> void:
	"""Wipes the save file and restarts the game."""
	Loggie.msg("Pause Menu: New Game requested. Wiping save...").domain("UI").warn()
	
	# 1. Delete Save (Settlement + Map) and reset manager state
	SettlementManager.delete_save_file()
	
	# 2. FULL CAMPAIGN WIPE: Reset Dynasty (Jarl, heirs, renown, upgrades, regions)
	if is_instance_valid(DynastyManager):
		DynastyManager.reset_dynasty(true)
	
	# 3. Unpause (Critical for scene reload to work properly)
	get_tree().paused = false
	
	# 4. Request Transition to Settlement Scene
	# This ensures that if we are in a Raid, we go home.
	# If we are at home, it effectively reloads the scene.
	EventBus.scene_change_requested.emit("settlement")
	
	# 5. Close menu
	queue_free()


func _on_quit_pressed() -> void:
	"""Quits the game."""
	get_tree().quit()
