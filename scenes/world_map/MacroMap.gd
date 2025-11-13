# res://scenes/world_map/MacroMap.gd
extends Node2D

@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var end_year_popup_scene: PackedScene
@export var enemy_raid_chance: float = 0.25

# --- NEW: Phase 5.1 Geography Anchor ---
@export var player_home_marker_path: NodePath = "PlayerHomeMarker"
@onready var player_home_marker: Marker2D = get_node_or_null(player_home_marker_path)
# ---------------------------------------

@onready var authority_label: Label = $UI/JarlInfo/VBoxContainer/AuthorityLabel
@onready var renown_label: Label = $UI/JarlInfo/VBoxContainer/RenownLabel
@onready var end_year_button: Button = $UI/Actions/VBoxContainer/EndYearButton
@onready var region_info_panel: PanelContainer = $UI/RegionInfo
@onready var region_name_label: Label = $UI/RegionInfo/VBoxContainer/RegionNameLabel
@onready var launch_raid_button: Button = $UI/RegionInfo/VBoxContainer/LaunchRaidButton
@onready var settlement_button: Button = $UI/Actions/VBoxContainer/SettlementButton
@onready var subjugate_button: Button = $UI/RegionInfo/VBoxContainer/SubjugateButton
@onready var dynasty_button: Button = $UI/Actions/VBoxContainer/DynastyButton
@onready var dynasty_ui: DynastyUI = $UI/Dynasty_UI
@onready var marry_button: Button = $UI/RegionInfo/VBoxContainer/MarryButton
@onready var tooltip: PanelContainer = $UI/Tooltip
@onready var tooltip_label: Label = $UI/Tooltip/Label
@onready var regions_container: Node2D = $Regions
@onready var macro_camera: MacroCamera = $MacroCamera

const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer
var idle_warning_dialog: ConfirmationDialog

var end_year_popup: PanelContainer
var selected_region_data: WorldRegionData
var selected_region_node: Region = null
var calculated_raid_cost: int = 1
var calculated_subjugate_cost: int = 5 

# --- NEW: Attrition Visuals ---
const SAFE_COLOR := Color(0.2, 0.8, 0.2, 0.1)   # Green
const RISK_COLOR := Color(1.0, 0.6, 0.0, 0.1)   # Orange
const HIGH_RISK_COLOR := Color(1.0, 0.0, 0.0, 0.1) # Red
# --- NEW: Persistence Variables ---
const SAVE_PATH = "user://campaign_map.tres"
var map_state: MapState

func _ready() -> void:
	# --- NEW: Snap Camera to Home ---
	if player_home_marker and macro_camera:
		print("MacroMap: Snapping camera to %s" % player_home_marker.global_position)
		macro_camera.snap_to_target(player_home_marker.global_position)
	elif not macro_camera:
		push_warning("MacroMap: MacroCamera node not found (ensure it is named 'MacroCamera').")
	# --------------------------------	
	# --- NEW: Anchor Validation ---
	if not player_home_marker:
		push_error("MacroMap: 'PlayerHomeMarker' missing! Distance calculations will fail.")
	else:
		print("MacroMap: Geography Anchor set at %s" % player_home_marker.global_position)
	
	# Trigger a redraw when stats change (e.g. range upgrade)
	DynastyManager.jarl_stats_updated.connect(func(_j): queue_redraw())
	# ------------------------------
	
	DynastyManager.jarl_stats_updated.connect(_update_jarl_ui)
	# --- NEW: Initialize World Data ---
	_initialize_world_data()
	
	for region in regions_container.get_children():
		if region is Region:
			region.region_hovered.connect(_on_region_hovered)
			region.region_exited.connect(_on_region_exited)
			region.region_selected.connect(_on_region_selected)
			
	launch_raid_button.pressed.connect(_on_launch_raid_pressed)
	settlement_button.pressed.connect(_on_settlement_pressed)
	subjugate_button.pressed.connect(_on_subjugate_pressed)
	end_year_button.pressed.connect(_on_end_year_pressed)
	dynasty_button.pressed.connect(_on_dynasty_pressed)
	marry_button.pressed.connect(_on_marry_pressed)
	
	if end_year_popup_scene:
		end_year_popup = end_year_popup_scene.instantiate()
		add_child(end_year_popup) 
		if end_year_popup.has_signal("collect_button_pressed"):
			end_year_popup.collect_button_pressed.connect(_on_end_year_payout_collected)
		end_year_popup.hide()
	
	if ResourceLoader.exists(WORK_ASSIGNMENT_SCENE_PATH):
		var scene = load(WORK_ASSIGNMENT_SCENE_PATH)
		if scene:
			work_assignment_ui = scene.instantiate()
			add_child(work_assignment_ui)
			if work_assignment_ui.has_signal("assignments_confirmed"):
				work_assignment_ui.assignments_confirmed.connect(_on_worker_assignments_confirmed)
	
	idle_warning_dialog = ConfirmationDialog.new()
	idle_warning_dialog.title = "Idle Villagers"
	idle_warning_dialog.ok_button_text = "End Year Anyway"
	idle_warning_dialog.cancel_button_text = "Manage Workers"
	idle_warning_dialog.confirmed.connect(_start_end_year_sequence)
	idle_warning_dialog.canceled.connect(_on_open_worker_ui) 
	add_child(idle_warning_dialog)
	
	EventBus.event_system_finished.connect(_on_event_system_finished)
	_update_jarl_ui(DynastyManager.get_current_jarl())
	region_info_panel.hide()
	tooltip.hide()
	
	# Initial draw
	queue_redraw()

# --- NEW: Visualizing the Range ---
func _draw() -> void:
	if not player_home_marker: return
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return
	
	var safe_r = jarl.get_safe_range()
	
	# Draw Safe Zone
	draw_circle(player_home_marker.position, safe_r, SAFE_COLOR)
	draw_arc(player_home_marker.position, safe_r, 0, TAU, 64, Color.GREEN, 2.0)
	
	# Draw Visual "Risk" Gradient (Arbitrary visual limit, e.g., +500px)
	draw_arc(player_home_marker.position, safe_r + 500, 0, TAU, 64, Color.RED, 1.0)
# ----------------------------------

func _on_open_worker_ui() -> void:
	if not SettlementManager.has_current_settlement(): return
	if work_assignment_ui:
		work_assignment_ui.setup(SettlementManager.current_settlement)

func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
	print("MacroMap: Work assignments saved.")
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.worker_assignments = assignments
		SettlementManager.save_settlement()

func _on_end_year_pressed() -> void:
	if not SettlementManager.has_current_settlement():
		return
		
	var settlement = SettlementManager.current_settlement
	var total_pop = settlement.population_total
	var assigned_pop = 0
	
	for key in settlement.worker_assignments:
		assigned_pop += settlement.worker_assignments[key]
	
	var idle_count = total_pop - assigned_pop
	
	if idle_count > 0:
		idle_warning_dialog.dialog_text = "You have %d idle villagers.\nEnd year anyway?" % idle_count
		idle_warning_dialog.popup_centered()
	else:
		_start_end_year_sequence()

func _start_end_year_sequence() -> void:
	if not is_instance_valid(end_year_popup):
		_process_end_year_logic({})
		return
	
	var payout = SettlementManager.calculate_payout()
	end_year_popup.display_payout(payout, "End of Year Report")

func _update_jarl_ui(jarl: JarlData) -> void:
	if not jarl: return
	authority_label.text = "Authority: %d / %d" % [jarl.current_authority, jarl.max_authority]
	renown_label.text = "Renown: %d" % jarl.renown
	if selected_region_data: _on_region_selected(selected_region_data)

func _on_region_hovered(data: WorldRegionData, _screen_position: Vector2) -> void:
	tooltip_label.text = data.display_name
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip.position = mouse_pos + Vector2(15, 15)
	tooltip.show()

func _on_region_exited() -> void: tooltip.hide()

func _on_region_selected(data: WorldRegionData) -> void:
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	for region in regions_container.get_children():
		if region is Region and region.data == data:
			selected_region_node = region
			selected_region_node.is_selected = true
			selected_region_node.set_visual_state(false)
			break
	selected_region_data = data
	region_name_label.text = data.display_name
	
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return
	
# --- NEW: Attrition & Distance Logic ---
	var attrition_chance = 0.0
	if player_home_marker and is_instance_valid(selected_region_node):
		# --- FIX: Use get_global_center() ---
		var dist = player_home_marker.global_position.distance_to(selected_region_node.get_global_center())
		# ------------------------------------
		var safe_range = jarl.get_safe_range()
		
		if dist > safe_range:
			var overage = dist - safe_range
			attrition_chance = (overage / 100.0) * jarl.attrition_per_100px
			attrition_chance = min(attrition_chance, 1.0)
	
	var is_conquered = DynastyManager.has_conquered_region(data.resource_path)
	var is_allied = DynastyManager.is_allied_region(data.resource_path)
	
	if is_conquered:
		launch_raid_button.disabled = true
		launch_raid_button.text = "Raid (Conquered)"
		launch_raid_button.modulate = Color.WHITE
		subjugate_button.disabled = true
		subjugate_button.text = "Subjugate (Conquered)"
		marry_button.disabled = true
		marry_button.text = "Marry (Conquered)"
		region_info_panel.show()
		return
	
	# Raid Button Logic with Attrition
	calculated_raid_cost = max(1, data.base_authority_cost) 
	var can_afford_raid = DynastyManager.can_spend_authority(calculated_raid_cost)
	
	launch_raid_button.disabled = (not can_afford_raid) or is_allied
	
	if is_allied:
		launch_raid_button.text = "Raid (Allied)"
		launch_raid_button.modulate = Color.WHITE
	elif not can_afford_raid:
		launch_raid_button.text = "Launch Raid\n(Not Enough Auth)"
		launch_raid_button.modulate = Color.WHITE
	elif attrition_chance > 0.0:
		# Show Risk!
		var percent_str = "%d%%" % int(attrition_chance * 100)
		launch_raid_button.text = "Launch Raid\n(ATTRITION RISK: %s)" % percent_str
		
		if attrition_chance < 0.3:
			launch_raid_button.modulate = Color.YELLOW
		else:
			launch_raid_button.modulate = Color.RED
	else:
		# Safe
		launch_raid_button.text = "Launch Raid\n(Safe Travel)"
		launch_raid_button.modulate = Color.WHITE

	# Subjugate Button
	var base_subjugate_cost = 5
	var trait_penalty = 0
	var alliance_discount = 0
	var penalty_text = ""
	var discount_text = ""
	if jarl.has_trait("Pious") and data.region_type_tag == "Monastery":
		trait_penalty = 3
		penalty_text = " (+3 Pious)"
	if is_allied:
		alliance_discount = 2 
		discount_text = " (-2 Alliance)"
	calculated_subjugate_cost = max(1, base_subjugate_cost + trait_penalty - alliance_discount)
	subjugate_button.text = "Subjugate (Cost: %d Auth%s%s)" % [calculated_subjugate_cost, penalty_text, discount_text]
	var can_afford_subjugate = DynastyManager.can_spend_authority(calculated_subjugate_cost)
	subjugate_button.disabled = not can_afford_subjugate
	if not can_afford_subjugate: subjugate_button.text += "\nNot Enough Authority"
	
	# Marry Button
	marry_button.text = "Marry for Alliance (Cost: 1 Heir)"
	var has_heir = DynastyManager.get_available_heir_count() > 0
	marry_button.disabled = is_allied or (not has_heir)
	if is_allied: marry_button.text = "Marry (Allied)"
	elif not has_heir: marry_button.text += "\n(No Available Heir)"
	
	region_info_panel.show()

func _on_launch_raid_pressed() -> void:
	if not selected_region_data: return
	
	# --- NEW: Apply Attrition Check before Scene Change ---
	var jarl = DynastyManager.get_current_jarl()
	var risk_chance = 0.0
	
	if player_home_marker and is_instance_valid(selected_region_node):
		var dist = player_home_marker.global_position.distance_to(selected_region_node.get_global_center())
		var safe_range = jarl.get_safe_range()
		
		if dist > safe_range:
			var overage = dist - safe_range
			risk_chance = (overage / 100.0) * jarl.attrition_per_100px
			risk_chance = min(risk_chance, 1.0)
			
	if risk_chance > 0.0:
		_apply_attrition(risk_chance)
	# ------------------------------------------------------
	
	DynastyManager.set_current_raid_target(selected_region_data.target_settlement_data)
	var success = DynastyManager.spend_authority(calculated_raid_cost)
	if success: EventBus.scene_change_requested.emit("raid_mission")
	else: DynastyManager.set_current_raid_target(null)

func _apply_attrition(risk_chance: float) -> void:
	"""Rolls dice for every unit in the garrison."""
	if not SettlementManager.has_current_settlement(): return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	var units_lost = 0
	var units_to_remove: Array[String] = []
	
	print("Applying Attrition Risk: %.2f" % risk_chance)
	
	for unit_path in garrison.keys():
		var count = garrison[unit_path]
		var surviving_count = 0
		
		for i in range(count):
			# Roll the dice (0.0 to 1.0)
			if randf() > risk_chance:
				surviving_count += 1
			else:
				units_lost += 1
		
		if surviving_count > 0:
			garrison[unit_path] = surviving_count
		else:
			units_to_remove.append(unit_path)
			
	for path in units_to_remove:
		garrison.erase(path)
		
	SettlementManager.save_settlement()
	
	if units_lost > 0:
		print("ATTRITION: Lost %d units to the sea!" % units_lost)
		# In a polished version, we would popup a dialog here.

func _on_subjugate_pressed() -> void:
	if not selected_region_data: return
	var success = DynastyManager.spend_authority(calculated_subjugate_cost)
	if success:
		DynastyManager.add_conquered_region(selected_region_data.resource_path)
		var jarl = DynastyManager.get_current_jarl()
		jarl.legitimacy = min(100, jarl.legitimacy + 5) 
		DynastyManager.jarl_stats_updated.emit(jarl) 
		print("Region %s successfully subjugated." % selected_region_data.display_name)
		_on_region_selected(selected_region_data) # Refresh UI

func _on_marry_pressed() -> void:
	if not selected_region_data: return
	var success = DynastyManager.marry_heir_for_alliance(selected_region_data.resource_path)
	if success: 
		print("MacroMap: Alliance with %s successful." % selected_region_data.display_name)
		_on_region_selected(selected_region_data) # Refresh UI
	else: 
		print("MacroMap: Alliance failed (no available heir).")

func _on_dynasty_pressed() -> void:
	if is_instance_valid(dynasty_ui): dynasty_ui.show()

func _on_end_year_payout_collected(payout: Dictionary) -> void:
	_process_end_year_logic(payout)

func _on_event_system_finished() -> void:
	if randf() < enemy_raid_chance:
		print("--- ENEMY RAID TRIGGERED ---")
		DynastyManager.is_defensive_raid = true
		EventBus.scene_change_requested.emit("raid_mission")
	else:
		print("No enemy raid this year.")
		EventBus.scene_change_requested.emit("settlement")

func _process_end_year_logic(payout: Dictionary) -> void:
	if not payout.is_empty(): SettlementManager.deposit_resources(payout)
	DynastyManager.end_year()
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	selected_region_data = null
	selected_region_node = null
	region_info_panel.hide()

func _on_settlement_pressed() -> void: EventBus.scene_change_requested.emit("settlement")
func _unhandled_input(_event: InputEvent) -> void: pass
# --- NEW: Generation & Loading Logic ---
func _initialize_world_data() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		print("MacroMap: Loading existing campaign state...")
		map_state = load(SAVE_PATH)
		_apply_state_to_regions()
	else:
		print("MacroMap: New Campaign detected. Generating world...")
		map_state = MapState.new()
		_generate_new_world()
		_save_map_state()

func _generate_new_world() -> void:
	if not player_home_marker: return
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return
	
	var safe_range = jarl.get_safe_range()
	
	for region in regions_container.get_children():
		if not region is Region: continue
		
		# --- FIX: Use the polygon center, not the node origin ---
		var dist = player_home_marker.global_position.distance_to(region.get_global_center())
		# -------------------------------------------------------
		
		var tier = 1
		
		if dist <= safe_range:
			tier = 1 # Safe Zone
		elif dist <= safe_range * 1.5:
			tier = 2 # Moderate Risk
		else:
			tier = 3 # High Risk (Deep Ocean)
			
		# (Rest of function remains the same...)
		var data = MapDataGenerator.generate_region_data(tier)
		region.data = data
		map_state.region_data_map[region.name] = data
		
		print("Generated %s (Tier %d) at dist %.0f" % [data.display_name, tier, dist])

func _apply_state_to_regions() -> void:
	for region in regions_container.get_children():
		if not region is Region: continue
		
		# Look up data by Node Name
		if map_state.region_data_map.has(region.name):
			region.data = map_state.region_data_map[region.name]
		else:
			push_warning("MacroMap: Load Mismatch. No data found for region '%s'" % region.name)

func _save_map_state() -> void:
	var error = ResourceSaver.save(map_state, SAVE_PATH)
	if error != OK:
		push_error("MacroMap: Failed to save map state!")
# ---------------------------------------
