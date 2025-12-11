# res://scripts/ui/PauseMenu.gd
extends CanvasLayer

# --- Main Menu References ---
@onready var main_container: VBoxContainer = $PanelContainer/MainMenuContainer
@onready var resume_button: Button = $PanelContainer/MainMenuContainer/ResumeButton
@onready var save_button: Button = $PanelContainer/MainMenuContainer/SaveButton
@onready var debug_button: Button = $PanelContainer/MainMenuContainer/DebugButton
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
	main_container.show()
	if debug_container: debug_container.hide()
	
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	if debug_button:
		debug_button.pressed.connect(_on_debug_menu_pressed)
	
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
		
	quit_button.pressed.connect(_on_quit_pressed)
	
	if debug_container:
		btn_add_gold.pressed.connect(_cheat_add_gold)
		btn_add_renown.pressed.connect(_cheat_add_renown)
		btn_unlock_legacy.pressed.connect(_cheat_unlock_legacy)
		btn_trigger_raid.pressed.connect(_cheat_trigger_raid)
		btn_kill_jarl.pressed.connect(_cheat_kill_jarl)
		btn_back.pressed.connect(_on_back_pressed)
	var container = find_child("VBoxContainer", true, false) # Adjust if your layout is named differently
	if container:
		var debug_raid_btn = Button.new()
		debug_raid_btn.text = "DEBUG: Instant Raid"
		debug_raid_btn.name = "Btn_DebugRaid"
		debug_raid_btn.pressed.connect(_on_debug_raid_pressed)
		
		# Add a separator for cleanliness
		container.add_child(HSeparator.new()) 
		container.add_child(debug_raid_btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

func _on_debug_raid_pressed() -> void:
	print("[DEBUG] Launching Instant Raid Sequence...")
	
	# 1. Setup Mock Target Data (Prevent "Null Target" crash)
	var debug_target = RaidTargetData.new()
	debug_target.display_name = "Debug Monastery"
	debug_target.raid_cost_authority = 0
	
	# Load a valid enemy base to prevent "Ghost Wall" bugs
	# Ensure this path matches your project structure
	var base_path = "res://data/settlements/monastery_base.tres"
	if ResourceLoader.exists(base_path):
		debug_target.settlement_data = load(base_path)
	
	DynastyManager.set_current_raid_target(debug_target)
	
	# 2. Setup Mock Army
	# If we have a settlement, send all current warbands.
	# If not (e.g. testing from title screen), create a dummy squad.
	var army: Array[WarbandData] = []
	
	if SettlementManager.has_current_settlement():
		army = SettlementManager.current_settlement.warbands.duplicate()
	
	if army.is_empty():
		# Fallback: Spawn 1 generic raider squad
		var unit_data = load("res://data/units/Unit_PlayerRaider.tres") # Check path!
		if unit_data:
			var wb = WarbandData.new(unit_data)
			wb.custom_name = "Debug Raiders"
			army.append(wb)
	
	DynastyManager.outbound_raid_force = army
	
	# 3. Unpause and Switch Scene
	get_tree().paused = false
	EventBus.scene_change_requested.emit(GameScenes.RAID_MISSION)
	
	# Close the menu
	queue_free()

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
	# 1. Wipe old save data
	SettlementManager.delete_save_file()
	
	# 2. Generate new Dynasty & Campaign State
	if is_instance_valid(DynastyManager):
		# --- FIX: Call the new method, not the old one ---
		DynastyManager.start_new_campaign()
		# -------------------------------------------------
		
	# 3. Unpause and go to Settlement view
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
