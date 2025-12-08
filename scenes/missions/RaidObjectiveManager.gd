# res://scenes/missions/RaidObjectiveManager.gd
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
var enemy_units: Array[BaseUnit] = [] 
var is_initialized: bool = false
var mission_over: bool = false

# --- NEW: Performance Tracking ---
var battle_start_time: int = 0
var units_lost_count: int = 0
# ---------------------------------

# --- RETREAT STATE ---
var escaped_unit_count: int = 0

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
	# Connect to global unit death signal to track casualties
	EventBus.player_unit_died.connect(_on_player_unit_died)

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
	if is_initialized:
		Loggie.msg("RaidObjectiveManager: Already initialized, skipping.").domain(LogDomains.RTS).info()
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
	
	# --- NEW: Start Clock ---
	battle_start_time = Time.get_ticks_msec()
	# ------------------------
	
	Loggie.msg("RaidObjectiveManager: Initialized and tracking objectives.").domain(LogDomains.RTS).info()
	
	# Connect to all necessary signals
	if not is_defensive_mission:
		_connect_to_building_signals()
		_setup_mission_ui()
		fyrd_timer_active = true
		
	_setup_win_loss_conditions()
	is_initialized = true

# --- CASUALTY TRACKING ---
func _on_player_unit_died(unit: Node2D) -> void:
	if not mission_over:
		units_lost_count += 1
		
		# --- NEW: Log Identity ---
		var ident = "A Warrior"
		if "unit_identity" in unit:
			ident = unit.unit_identity
			
		Loggie.msg("⚔️ CASUALTY: %s has fallen!" % ident).domain(LogDomains.RAID).warn()
		# -------------------------

# --- UI SETUP ---

func _setup_mission_ui() -> void:
	var canvas = get_parent().get_node_or_null("CanvasLayer")
	if not canvas: return
	
	if not is_defensive_mission:
		# 1. Timer
		_setup_timer_ui()
		
		# 2. Retreat Button
		var retreat_btn = Button.new()
		retreat_btn.text = "RETREAT!"
		retreat_btn.modulate = Color(1, 0.5, 0.5)
		retreat_btn.add_theme_font_size_override("font_size", 20)
		retreat_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
		retreat_btn.position.y += 20
		retreat_btn.position.x -= 20
		retreat_btn.pressed.connect(_on_retreat_ordered)
		canvas.add_child(retreat_btn)

func _setup_timer_ui() -> void:
	var canvas = get_parent().get_node_or_null("CanvasLayer")
	if canvas:
		timer_label = Label.new()
		timer_label.add_theme_font_size_override("font_size", 24)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_constant_override("outline_size", 4)
		timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		
		timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		timer_label.position.y += 20
		canvas.add_child(timer_label)

# --- RETREAT LOGIC ---

func _on_retreat_ordered() -> void:
	Loggie.msg("Retreat Ordered! All units scrambling.").domain(LogDomains.RTS).warn()
	
	var spawn_marker = get_parent().get_node_or_null("PlayerStartPosition")
	if spawn_marker and rts_controller:
		rts_controller.command_scramble(spawn_marker.global_position)

func on_unit_evacuated(unit: BaseUnit) -> void:
	escaped_unit_count += 1
	if is_instance_valid(rts_controller):
		rts_controller.remove_unit(unit)

	var remaining = get_tree().get_nodes_in_group("player_units").size()
	Loggie.msg("Unit escaped. Remaining on field: %d" % remaining).domain(LogDomains.RTS).info()
	
	if remaining <= 0 and not mission_over:
		_end_mission_via_retreat()

func _end_mission_via_retreat() -> void:
	if mission_over: return
	mission_over = true
	
	var raw_gold = raid_loot.collected_loot.get("gold", 0)
	Loggie.msg("Retreat Complete. Loot secured: %d" % raw_gold).domain(LogDomains.RTS).info()
	
	var result = {
		"outcome": "retreat",
		"gold_looted": raw_gold,
		"victory_grade": "None"
	}
	DynastyManager.pending_raid_result = result
	
	_show_victory_message("RETREAT", "We escaped with what we could carry.")
	await get_tree().create_timer(3.0).timeout
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

# --- STANDARD OBJECTIVE LOGIC ---

func _connect_to_building_signals() -> void:
	# 1. Connect Objective (Great Hall)
	if is_instance_valid(objective_building):
		if objective_building.has_signal("building_destroyed"):
			if not objective_building.building_destroyed.is_connected(_on_enemy_hall_destroyed):
				objective_building.building_destroyed.connect(_on_enemy_hall_destroyed)

	# 2. Connect All Buildings (Farms, Markets, etc.)
	for building in building_container.get_children():
		if building is BaseBuilding:
			# A. Listen for Destruction (Burn -> Renown)
			if building.has_signal("building_destroyed"):
				if not building.building_destroyed.is_connected(_on_enemy_building_destroyed_for_loot):
					building.building_destroyed.connect(_on_enemy_building_destroyed_for_loot)
			
			# B. Listen for Pillage (Steal -> Gold/Food) <--- NEW CONNECTION
			if building.has_signal("loot_stolen"):
				if not building.loot_stolen.is_connected(_on_loot_stolen):
					building.loot_stolen.connect(_on_loot_stolen)

# --- NEW: Callback for Pillage ---
func _on_loot_stolen(type: String, amount: int) -> void:
	if mission_over: return
	
	# Add to the temporary raid stash
	raid_loot.add_loot(type, amount)
	
	# Note: raid_loot.add_loot already has a Loggie print, so we don't need another one here.

func _on_enemy_building_destroyed_for_loot(building: BaseBuilding) -> void:
	if mission_over: return
	var building_data = building.data as BuildingData
	if raid_loot and building_data:
		raid_loot.add_loot_from_building(building_data)
		Loggie.msg("Loot secured from %s" % building_data.display_name).domain(LogDomains.RTS).info()

func _setup_win_loss_conditions() -> void:
	if is_defensive_mission:
		if objective_building.has_signal("building_destroyed"):
			objective_building.building_destroyed.connect(_on_player_hall_destroyed)
		_check_defensive_win_condition()
	else:
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

	enemy_units = enemy_units.filter(func(unit): return is_instance_valid(unit))
	if enemy_units.is_empty():
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
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

func _on_mission_failed(reason: String) -> void:
	if mission_over: return
	mission_over = true
	Loggie.msg("Mission Failed! %s" % reason).domain(LogDomains.RTS).info()
	
	if is_defensive_mission:
		var report = DynastyManager.process_defensive_loss()
		var full_reason = reason + "\n\n" + report.get("summary_text", "")
		_show_failure_message(full_reason)
	else:
		_show_failure_message(reason + "\n\nYour raid failed. No loot was secured.")
	
	await get_tree().create_timer(6.0).timeout
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

# --- VICTORY GRADING LOGIC ---

func _on_enemy_hall_destroyed(_building: BaseBuilding = null) -> void:
	if mission_over: return
	mission_over = true
	
	var raw_gold = raid_loot.collected_loot.get("gold", 0)
	
	# 1. Calculate Grade
	var grade = "Standard"
	var duration_sec = (Time.get_ticks_msec() - battle_start_time) / 1000.0
	
	# Defaults (in case target data missing)
	var par_time = 300
	var casualty_limit = 2
	
	# Fetch Limits from Data
	# We access the Settlement Data, but we need the RaidTargetData for specific limits.
	# Since we don't have a direct ref to RaidTargetData here, we use Defaults or pass it in Initialize.
	# For Phase 5, we hardcode sensible defaults or check DynastyManager if we stored it.
	
	if duration_sec < par_time and units_lost_count <= casualty_limit:
		grade = "Decisive"
	elif units_lost_count > (casualty_limit * 2):
		grade = "Pyrrhic"
		
	Loggie.msg("Victory! Time: %ds, Casualties: %d. Grade: %s" % [duration_sec, units_lost_count, grade]).domain(LogDomains.RTS).info()
	
	var result = { 
		"outcome": "victory", 
		"gold_looted": raw_gold,
		"victory_grade": grade
	}
	DynastyManager.pending_raid_result = result
	
	var sub_text = "The settlement lies in ruins."
	if grade == "Decisive":
		sub_text = "A glorious, swift victory!"
	elif grade == "Pyrrhic":
		sub_text = "Victory, but at great cost."
		
	_show_victory_message("VICTORY (%s)" % grade, sub_text)
	await get_tree().create_timer(3.0).timeout
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

func _trigger_fyrd() -> void:
	fyrd_timer_active = false
	Loggie.msg("The Fyrd has arrived! Run!").domain(LogDomains.RTS).warn()
	if is_instance_valid(timer_label):
		timer_label.text = "THE FYRD IS HERE!"
	fyrd_arrived.emit()

# --- HELPERS ---
func _show_failure_message(reason: String) -> void:
	var popup = _create_popup_base()
	var label = Label.new()
	label.text = "DEFEAT\n\n" + reason
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.CRIMSON)
	popup.get_child(1).add_child(label)
	_add_popup_to_canvas(popup)

func _show_victory_message(title: String, subtitle: String) -> void:
	var popup = _create_popup_base()
	var label = Label.new()
	label.text = title + "\n\n" + subtitle
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.GOLD)
	popup.get_child(1).add_child(label)
	_add_popup_to_canvas(popup)

func _create_popup_base() -> Control:
	var popup = Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.theme = UI_THEME
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0,0,0,0.85)
	popup.add_child(bg)
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.add_child(container)
	return popup

func _add_popup_to_canvas(popup: Control) -> void:
	var canvas = get_parent().get_node_or_null("CanvasLayer")
	if canvas: canvas.add_child(popup)
	else: get_tree().current_scene.add_child(popup)
