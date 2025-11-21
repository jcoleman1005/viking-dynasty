# res://scripts/ui/PauseMenu.gd
extends CanvasLayer

# --- Main Menu References ---
@onready var main_container: VBoxContainer = $PanelContainer/MainMenuContainer
@onready var resume_button: Button = $PanelContainer/MainMenuContainer/ResumeButton
@onready var save_button: Button = $PanelContainer/MainMenuContainer/SaveButton
@onready var debug_button: Button = $PanelContainer/MainMenuContainer/DebugButton # New
@onready var new_game_button: Button = $PanelContainer/MainMenuContainer/NewGameButton
@onready var quit_button: Button = $PanelContainer/MainMenuContainer/QuitButton

# --- Debug Menu References ---
@onready var debug_container: VBoxContainer = $PanelContainer/DebugMenuContainer
@onready var btn_add_gold: Button = $PanelContainer/DebugMenuContainer/Btn_AddGold
@onready var btn_add_renown: Button = $PanelContainer/DebugMenuContainer/Btn_AddRenown
@onready var btn_unlock_legacy: Button = $PanelContainer/DebugMenuContainer/Btn_UnlockLegacy
@onready var btn_trigger_raid: Button = $PanelContainer/DebugMenuContainer/Btn_TriggerRaid
@onready var btn_kill_jarl: Button = $PanelContainer/DebugMenuContainer/Btn_KillJarl
@onready var btn_back: Button = $PanelContainer/DebugMenuContainer/Btn_Back

func _ready() -> void:
	# Ensure correct visibility on start
	main_container.show()
	if debug_container: debug_container.hide()
	
	# --- Main Menu Connections ---
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	if debug_button:
		debug_button.pressed.connect(_on_debug_menu_pressed)
	
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
		
	quit_button.pressed.connect(_on_quit_pressed)
	
	# --- Debug Connections ---
	if debug_container:
		btn_add_gold.pressed.connect(_cheat_add_gold)
		btn_add_renown.pressed.connect(_cheat_add_renown)
		btn_unlock_legacy.pressed.connect(_cheat_unlock_legacy)
		btn_trigger_raid.pressed.connect(_cheat_trigger_raid)
		btn_kill_jarl.pressed.connect(_cheat_kill_jarl)
		btn_back.pressed.connect(_on_back_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

# --- Navigation ---
func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_debug_menu_pressed() -> void:
	main_container.hide()
	debug_container.show()

func _on_back_pressed() -> void:
	debug_container.hide()
	main_container.show()

# --- Standard Actions ---
func _on_save_pressed() -> void:
	if SettlementManager.has_current_settlement():
		SettlementManager.save_settlement()
		Loggie.msg("Game saved from pause menu.").domain("UI").info()

func _on_new_game_pressed() -> void:
	SettlementManager.delete_save_file()
	if is_instance_valid(DynastyManager):
		DynastyManager.reset_dynasty(true)
	get_tree().paused = false
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)
	queue_free()

func _on_quit_pressed() -> void:
	get_tree().quit()

# --- CHEATS ---

func _cheat_add_gold() -> void:
	if SettlementManager.has_current_settlement():
		SettlementManager.deposit_resources({"gold": 1000, "wood": 1000})
		Loggie.msg("CHEAT: Added 1000 Gold/Wood").domain("SYSTEM").warn()

func _cheat_add_renown() -> void:
	if DynastyManager.current_jarl:
		DynastyManager.award_renown(500)
		Loggie.msg("CHEAT: Added 500 Renown").domain("SYSTEM").warn()

func _cheat_unlock_legacy() -> void:
	if not DynastyManager.has_purchased_upgrade("UPG_TRAINING_GROUNDS"):
		DynastyManager.purchase_legacy_upgrade("UPG_TRAINING_GROUNDS")
		Loggie.msg("CHEAT: Training Grounds Unlocked").domain("SYSTEM").warn()
		
		# Refresh UI if open behind pause menu
		if DynastyManager.current_jarl:
			DynastyManager.jarl_stats_updated.emit(DynastyManager.current_jarl)

func _cheat_trigger_raid() -> void:
	DynastyManager.is_defensive_raid = true
	EventBus.scene_change_requested.emit("raid_mission")
	get_tree().paused = false
	queue_free()

func _cheat_kill_jarl() -> void:
	Loggie.msg("CHEAT: Assassinating Jarl...").domain("SYSTEM").warn()
	DynastyManager.debug_kill_jarl()
	get_tree().paused = false
	queue_free()
