#res://scenes/missions/RaidObjectiveManager.gd
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
var dead_units_log: Array[UnitData] = []
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
	EventBus.raid_loot_secured.connect(_on_raid_loot_secured)

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
	
	var zones = get_tree().get_nodes_in_group("retreat_zone")
	if not zones.is_empty():
		var zone = zones[0]
		if not zone.unit_evacuated.is_connected(on_unit_evacuated):
			zone.unit_evacuated.connect(on_unit_evacuated)
			print("RaidObjectiveManager: Connected to Retreat Zone.")
	else:
		print("RaidObjectiveManager: WARNING - No Retreat Zone found to connect!")

	is_initialized = true

# --- CASUALTY TRACKING ---
func _on_player_unit_died(unit: Node2D) -> void:
	if not mission_over:
		# Capture the data before the node is deleted
		if "data" in unit and unit.data is UnitData:
			dead_units_log.append(unit.data)
		else:
			# Fallback if data is missing (shouldn't happen, but safe to add generic)
			# We insert a null or a placeholder to keep the count correct
			dead_units_log.append(null)
		# Flavor Log
		var ident = "A Warrior"
		if "unit_identity" in unit: ident = unit.unit_identity
		Loggie.msg("⚔️ CASUALTY: %s has fallen!" % ident).domain("RAID").warn()

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

	var remaining_units = get_tree().get_nodes_in_group("player_units")
	var living_count = 0
	
	for u in remaining_units:
		# Filter out dead or queued-for-deletion units just to be safe
		if is_instance_valid(u) and not u.is_queued_for_deletion():
			living_count += 1
			
	print("RaidObjectiveManager: Evacuated! Remaining: %d" % (living_count - 1))
	
	if unit is CivilianUnit:
		# Assuming CivilianUnit has a flag or we just count all evacuated civs as thralls
		if raid_loot:
			raid_loot.add_loot("thrall", 1)
			Loggie.msg("Thrall captured!").domain(LogDomains.RAID).info()
	
	if living_count <= 1:
		print("RaidObjectiveManager: All units evacuated. Ending Mission.")
		_end_mission_via_retreat()

func _end_mission_via_retreat() -> void:
	if mission_over: return
	mission_over = true
	
	Loggie.msg("Ending mission via Retreat").domain(LogDomains.RAID).info()
	
	var mission_result = RaidResultData.new()
	mission_result.outcome = "retreat"
	mission_result.victory_grade = "Tactical Withdrawal"
	mission_result.renown_earned = 0 
	
	# Populate Loot & Casualties (Cleaned up)
	mission_result.loot = raid_loot.collected_loot.duplicate() if raid_loot else {}
	mission_result.casualties = dead_units_log.duplicate()

	RaidManager.pending_raid_result = mission_result
	
	# Note: SettlementBridge will convert "retreat" outcome to "defeat" for history stats later,
	# so we don't strictly need to set last_raid_outcome here, but it doesn't hurt.
	RaidManager.last_raid_outcome = "retreat"
	
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

func _connect_to_building_signals() -> void:
	if not building_container: return
	
	for child in building_container.get_children():
		if child.has_signal("loot_stolen"):
			if not child.loot_stolen.is_connected(_on_loot_stolen):
				child.loot_stolen.connect(_on_loot_stolen)
				
		if child.has_signal("building_destroyed"):
			if not child.building_destroyed.is_connected(_on_enemy_building_destroyed_for_loot):
				child.building_destroyed.connect(_on_enemy_building_destroyed_for_loot)

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
	
	var duration_sec = (Time.get_ticks_msec() - battle_start_time) / 1000.0
	var grade = "Standard"
	var casualty_limit = 2
	var lost_count = dead_units_log.size()
	
	# Simple Grading Logic
	if lost_count == 0 and duration_sec < 300:
		grade = "Decisive"
	elif lost_count > casualty_limit:
		grade = "Pyrrhic"
		
	var mission_result = RaidResultData.new()
	mission_result.outcome = "victory"
	mission_result.victory_grade = grade
	
	# Calculate Loot (Base + Bonus)
	var final_loot = raid_loot.collected_loot if raid_loot else {}
	var total_loot = final_loot.duplicate()
	
	# Add Victory Bonus
	for key in victory_bonus_loot:
		var amount = victory_bonus_loot[key]
		var current = total_loot.get(key, 0)
		total_loot[key] = current + amount
	
	mission_result.loot = total_loot
	
	# Calculate Renown
	var difficulty = RaidManager.current_raid_difficulty
	# Base 200 + 50 per star
	mission_result.renown_earned = 200 + (difficulty * 50)
	
	mission_result.casualties = dead_units_log.duplicate()
	
	RaidManager.pending_raid_result = mission_result
	RaidManager.last_raid_outcome = "victory"
	
	Loggie.msg("Raid Victory!").domain(LogDomains.RAID).ctx("Grade", grade).info()
	_show_victory_message("Victory!", "The settlement lies in ruins.")

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

func _on_raid_loot_secured(type: String, amount: int) -> void:
	if not raid_loot:
		raid_loot = RaidLootData.new()
		
	raid_loot.add_loot(type, amount)
	
	# Visual Feedback
	var color = Color.GOLD if type == "gold" else Color.WHITE
	if type == "thrall": color = Color.CYAN
	
	# We can spawn floating text at the Retreat Zone center (approximate)
	# or just update a UI counter. For now, let's just log it.
	print("RaidObjectiveManager: Secured %d %s!" % [amount, type])
	
	# Trigger UI update if you have a Loot HUD
	# EventBus.ui_update_loot.emit(raid_loot.collected_loot)
