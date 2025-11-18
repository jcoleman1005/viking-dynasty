# res://scenes/missions/RaidObjectiveManager.gd
#
# Manages all mission-specific logic for a raid, including
# loot, win conditions, and loss conditions.
extends Node
class_name RaidObjectiveManager

# --- Mission Configuration ---
@export var victory_bonus_loot: Dictionary = {"gold": 200}
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var is_defensive_mission: bool = false

# --- Internal State ---
var raid_loot: RaidLootData
var rts_controller: RTSController
var objective_building: BaseBuilding
var building_container: Node2D
var enemy_units: Array[BaseUnit] = [] # For defensive win condition
var is_initialized: bool = false
var mission_over: bool = false

# --- FYRD TIMER STATE ---
const FYRD_ARRIVAL_TIME: float = 120.0 # 2 Minutes
var time_remaining: float = FYRD_ARRIVAL_TIME
var fyrd_timer_active: bool = false
var timer_label: Label

signal fyrd_arrived()

# --- UI Theme ---
const UI_THEME = preload("res://ui/themes/VikingDynastyTheme.tres")

func _ready() -> void:
	raid_loot = RaidLootData.new()

func _process(delta: float) -> void:
	if fyrd_timer_active and not mission_over:
		time_remaining -= delta
		
		# Update UI
		if is_instance_valid(timer_label):
			var minutes = int(time_remaining / 60)
			var seconds = int(time_remaining) % 60
			timer_label.text = "FYRD ARRIVAL: %02d:%02d" % [minutes, seconds]
			
			if time_remaining < 30:
				timer_label.modulate = Color.RED # Panic color
		
		if time_remaining <= 0:
			_trigger_fyrd()

func initialize(
	p_rts_controller: RTSController, 
	p_objective_building: BaseBuilding, 
	p_building_container: Node2D,
	p_enemy_units: Array[BaseUnit] = []
) -> void:
	"""
	Called by RaidMission.gd after the level is loaded
	to pass in all necessary scene references.
	"""
	if is_initialized:
		Loggie.msg("RaidObjectiveManager: Already initialized, skipping.").domain("RTS").info()
		return
		
	self.rts_controller = p_rts_controller
	self.objective_building = p_objective_building
	self.building_container = p_building_container
	self.enemy_units = p_enemy_units
	
	if not is_instance_valid(rts_controller) or \
	   not is_instance_valid(objective_building) or \
	   not is_instance_valid(building_container):
		push_error("RaidObjectiveManager: Failed to initialize. Received invalid node references.")
		return
	
	Loggie.msg("RaidObjectiveManager: Initialized and tracking objectives.").domain("RTS").info()
	
	# Connect to all necessary signals
	if not is_defensive_mission:
		_connect_to_building_signals()
		# Start Fyrd Timer for offensive missions
		_setup_timer_ui()
		fyrd_timer_active = true
		
	_setup_win_loss_conditions()
	
	# Mark as initialized
	is_initialized = true


func _connect_to_building_signals() -> void:
	# Connect to the Great Hall for the win condition
	if objective_building.has_signal("building_destroyed"):
		if not objective_building.building_destroyed.is_connected(_on_enemy_hall_destroyed):
			objective_building.building_destroyed.connect(_on_enemy_hall_destroyed)
	
	# Connect to *all* buildings for loot collection
	for building in building_container.get_children():
		if building is BaseBuilding and building.has_signal("building_destroyed"):
			if not building.building_destroyed.is_connected(_on_enemy_building_destroyed_for_loot):
				building.building_destroyed.connect(_on_enemy_building_destroyed_for_loot)

# --- Objective Logic ---

func _on_enemy_building_destroyed_for_loot(building: BaseBuilding) -> void:
	if mission_over: return
	
	var building_data = building.data as BuildingData
	
	if raid_loot and building_data:
		raid_loot.add_loot_from_building(building_data)
		Loggie.msg("RaidObjectiveManager: Building destroyed: %s" % building_data.display_name).domain("RTS").info()

func _setup_win_loss_conditions() -> void:
	if is_defensive_mission:
		# Lose if Hall is destroyed
		if objective_building.has_signal("building_destroyed"):
			objective_building.building_destroyed.connect(_on_player_hall_destroyed)
		# Win if all enemies are defeated
		_check_defensive_win_condition()
	else:
		# Lose if all player units are destroyed
		_check_loss_condition()


func _check_loss_condition() -> void:
	if mission_over: return
	await get_tree().create_timer(1.0).timeout
	
	var remaining_units = 0
	if is_instance_valid(rts_controller):
		remaining_units = rts_controller.controllable_units.size()
	
	if remaining_units == 0:
		_on_mission_failed("All units destroyed")
		return 
	
	_check_loss_condition()

func _check_defensive_win_condition() -> void:
	if mission_over: return
	await get_tree().create_timer(1.0).timeout

	# Prune dead/invalid units
	enemy_units = enemy_units.filter(func(unit): return is_instance_valid(unit))
	var remaining_enemies = enemy_units.size()
	
	if remaining_enemies == 0:
		_on_defensive_mission_won()
		return

	_check_defensive_win_condition()

func _on_player_hall_destroyed(_building: BaseBuilding) -> void:
	if mission_over: return
	_on_mission_failed("Your Great Hall was destroyed!")

func _on_defensive_mission_won() -> void:
	if mission_over: return
	mission_over = true
	_show_victory_message("VICTORY!", "All attackers have been defeated.")
	await get_tree().create_timer(3.0).timeout
	EventBus.scene_change_requested.emit("settlement")

func _on_mission_failed(reason: String) -> void:
	if mission_over: return
	mission_over = true
	
	Loggie.msg("Mission Failed! %s" % reason).domain("RTS").info()
	
	if is_defensive_mission:
		var report = DynastyManager.process_defensive_loss()
		var full_reason = reason + "\n\n" + report.get("summary_text", "")
		_show_failure_message(full_reason)
	else:
		_show_failure_message(reason + "\n\nYour raid failed. No loot was secured.")
	
	await get_tree().create_timer(6.0).timeout
	EventBus.scene_change_requested.emit("settlement")

func _show_failure_message(reason: String) -> void:
	var failure_popup = Control.new()
	failure_popup.name = "FailurePopup"
	failure_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	failure_popup.theme = UI_THEME
	
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.modulate = Color(0, 0, 0, 0.85)
	failure_popup.add_child(bg_panel)
	
	var message_container = VBoxContainer.new()
	message_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	message_container.custom_minimum_size.x = 600 
	
	var failure_label = Label.new()
	failure_label.text = "DEFEAT"
	failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_label.add_theme_font_size_override("font_size", 42)
	failure_label.add_theme_color_override("font_color", Color.CRIMSON)
	message_container.add_child(failure_label)
	
	var subtitle_label = RichTextLabel.new()
	subtitle_label.text = reason
	subtitle_label.fit_content = true
	subtitle_label.bbcode_enabled = true
	subtitle_label.custom_minimum_size = Vector2(600, 0)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_container.add_child(subtitle_label)
	
	var return_label = Label.new()
	return_label.text = "\nReturning to settlement..."
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_label.modulate = Color(1, 1, 1, 0.6)
	message_container.add_child(return_label)
	
	failure_popup.add_child(message_container)
	
	var canvas = get_parent().get_node_or_null("CanvasLayer")
	if canvas:
		canvas.add_child(failure_popup)
	else:
		get_tree().current_scene.add_child(failure_popup)

func _show_victory_message(title: String, subtitle: String) -> void:
	var victory_popup = Control.new()
	victory_popup.name = "VictoryPopup"
	victory_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_popup.theme = UI_THEME
	
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.modulate = Color(0.1, 0.1, 0.1, 0.7)
	victory_popup.add_child(bg_panel)
	
	var message_container = VBoxContainer.new()
	message_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_container.add_child(title_label)
	
	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_container.add_child(subtitle_label)
	
	var return_label = Label.new()
	return_label.text = "Returning to settlement..."
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_container.add_child(return_label)
	
	victory_popup.add_child(message_container)
	
	var canvas = get_parent().get_node_or_null("CanvasLayer")
	if canvas:
		canvas.add_child(victory_popup)
	else:
		get_tree().current_scene.add_child(victory_popup)


func _on_enemy_hall_destroyed(_building: BaseBuilding = null) -> void:
	"""Called when the enemy's Great Hall is destroyed (OFFENSIVE win condition)"""
	if mission_over: return
	mission_over = true
	
	Loggie.msg("RaidObjectiveManager: Enemy Hall destroyed! Victory!").domain("RTS").info()
	
	var raw_gold = raid_loot.collected_loot.get("gold", 0)
	var result = {
		"outcome": "victory",
		"gold_looted": raw_gold,
	}
	DynastyManager.pending_raid_result = result
	
	_show_victory_message("VICTORY!", "The settlement lies in ruins.\nReturning to ships...")
	await get_tree().create_timer(3.0).timeout
	EventBus.scene_change_requested.emit("settlement")

# --- FYRD LOGIC ---

func _setup_timer_ui() -> void:
	var canvas = get_parent().get_node_or_null("CanvasLayer")
	if canvas:
		timer_label = Label.new()
		timer_label.add_theme_font_size_override("font_size", 24)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_constant_override("outline_size", 4)
		timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		
		# Top Center positioning
		timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		timer_label.position.y += 20
		canvas.add_child(timer_label)

func _trigger_fyrd() -> void:
	fyrd_timer_active = false
	Loggie.msg("The Fyrd has arrived! Run!").domain("RTS").warn()
	if is_instance_valid(timer_label):
		timer_label.text = "THE FYRD IS HERE!"
	fyrd_arrived.emit()
