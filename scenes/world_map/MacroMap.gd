# res://scenes/world_map/MacroMap.gd
extends Node2D

# --- Scene Configuration ---
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var end_year_popup_scene: PackedScene
@export var enemy_raid_chance: float = 0.25

# --- Phase 5.1: Geography Anchor ---
@export var player_home_marker_path: NodePath = "PlayerHomeMarker"
@onready var player_home_marker: Marker2D = get_node_or_null(player_home_marker_path)
@onready var macro_camera: MacroCamera = $MacroCamera

# --- UI References ---
@onready var authority_label: Label = $UI/JarlInfo/VBoxContainer/AuthorityLabel
@onready var renown_label: Label = $UI/JarlInfo/VBoxContainer/RenownLabel
@onready var end_year_button: Button = $UI/Actions/VBoxContainer/EndYearButton
@onready var region_info_panel: PanelContainer = $UI/RegionInfo
@onready var region_name_label: Label = $UI/RegionInfo/VBoxContainer/RegionNameLabel
# Old button is deprecated/hidden, we use the container now:
@onready var launch_raid_button: Button = $UI/RegionInfo/VBoxContainer/LaunchRaidButton 
@onready var target_list_container: VBoxContainer = $UI/RegionInfo/VBoxContainer/TargetList

@onready var settlement_button: Button = $UI/Actions/VBoxContainer/SettlementButton
@onready var subjugate_button: Button = $UI/RegionInfo/VBoxContainer/SubjugateButton
@onready var dynasty_button: Button = $UI/Actions/VBoxContainer/DynastyButton
@onready var dynasty_ui: DynastyUI = $UI/Dynasty_UI
@onready var marry_button: Button = $UI/RegionInfo/VBoxContainer/MarryButton
@onready var tooltip: PanelContainer = $UI/Tooltip
@onready var tooltip_label: Label = $UI/Tooltip/Label
@onready var regions_container: Node2D = $Regions

# --- Systems & State ---
const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer
var idle_warning_dialog: ConfirmationDialog
var end_year_popup: PanelContainer

# Persistence
const SAVE_PATH = "user://campaign_map.tres"
var map_state: MapState

# Selection State
var selected_region_data: WorldRegionData
var selected_region_node: Region = null
var calculated_subjugate_cost: int = 5 
var current_attrition_risk: float = 0.0

# Visual Constants
const SAFE_COLOR := Color(0.2, 0.8, 0.2, 0.1)   # Green
const RISK_COLOR := Color(1.0, 0.6, 0.0, 0.1)   # Orange
const HIGH_RISK_COLOR := Color(1.0, 0.0, 0.0, 0.1) # Red

func _ready() -> void:
	# 1. Anchor & Camera Setup
	if not player_home_marker:
		push_error("MacroMap: 'PlayerHomeMarker' missing! Distance calculations will fail.")
	else:
		Loggie.msg("MacroMap: Geography Anchor set at %s" % player_home_marker.global_position).domain("MAP").info()
		if macro_camera:
			Loggie.msg("MacroMap: Snapping camera to home.").domain("MAP").info()
			macro_camera.snap_to_target(player_home_marker.global_position)

	# 2. Data Initialization
	_initialize_world_data()
	
	# 3. UI & Signal Connections
	if launch_raid_button: launch_raid_button.hide() # Hide old button
	
	DynastyManager.jarl_stats_updated.connect(_update_jarl_ui)
	# Redraw map circles when stats (range) change
	DynastyManager.jarl_stats_updated.connect(func(_j): queue_redraw())
	
	for region in regions_container.get_children():
		if region is Region:
			region.region_hovered.connect(_on_region_hovered)
			region.region_exited.connect(_on_region_exited)
			region.region_selected.connect(_on_region_selected)
			
	settlement_button.pressed.connect(_on_settlement_pressed)
	subjugate_button.pressed.connect(_on_subjugate_pressed)
	end_year_button.pressed.connect(_on_end_year_pressed)
	dynasty_button.pressed.connect(_on_dynasty_pressed)
	marry_button.pressed.connect(_on_marry_pressed)
	
	# 4. Popups Setup
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
	
	# 5. Final Cleanup
	_update_jarl_ui(DynastyManager.get_current_jarl())
	region_info_panel.hide()
	tooltip.hide()
	queue_redraw()

# --- Phase 5.3: Visualizing Range ---
func _draw() -> void:
	if not player_home_marker: return
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return
	
	var safe_r = jarl.get_safe_range()
	
	# Draw Safe Zone
	draw_circle(player_home_marker.position, safe_r, SAFE_COLOR)
	draw_arc(player_home_marker.position, safe_r, 0, TAU, 64, Color.GREEN, 2.0)
	
	# Draw Visual "Risk" Gradient
	draw_arc(player_home_marker.position, safe_r + 500, 0, TAU, 64, Color.RED, 1.0)

# --- Phase 5.2: Data Generation & Persistence ---
func _initialize_world_data() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		Loggie.msg("MacroMap: Loading existing campaign state...").domain("MAP").info()
		map_state = load(SAVE_PATH)
		_apply_state_to_regions()
	else:
		Loggie.msg("MacroMap: New Campaign detected. Generating world...").domain("MAP").info()
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
		
		# FIX: Use polygon center for accurate distance
		var dist = player_home_marker.global_position.distance_to(region.get_global_center())
		var tier = 1
		
		if dist <= safe_range:
			tier = 1
		elif dist <= safe_range * 1.5:
			tier = 2
		else:
			tier = 3
			
		var data = MapDataGenerator.generate_region_data(tier)
		region.data = data
		map_state.region_data_map[region.name] = data
		
		Loggie.msg("Generated %s (Tier %d) at dist %.0f" % [data.display_name, tier, dist]).domain("MAP").info()

func _apply_state_to_regions() -> void:
	for region in regions_container.get_children():
		if not region is Region: continue
		if map_state.region_data_map.has(region.name):
			region.data = map_state.region_data_map[region.name]

func _save_map_state() -> void:
	var error = ResourceSaver.save(map_state, SAVE_PATH)
	if error != OK:
		push_error("MacroMap: Failed to save map state!")

# --- Phase 5.4: Selection & UI Logic ---

func _on_region_selected(data: WorldRegionData) -> void:
	# 1. Deselect previous visual state
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	
	# 2. Find and select the new node
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
	
	# 3. Calculate Attrition Risk (Phase 5.3)
	current_attrition_risk = 0.0
	if player_home_marker and is_instance_valid(selected_region_node):
		var dist = player_home_marker.global_position.distance_to(selected_region_node.get_global_center())
		var safe_range = jarl.get_safe_range()
		
		if dist > safe_range:
			var overage = dist - safe_range
			current_attrition_risk = (overage / 100.0) * jarl.attrition_per_100px
			current_attrition_risk = min(current_attrition_risk, 1.0) # Cap at 100%

	# 4. Check Political Status
	var is_conquered = DynastyManager.has_conquered_region(data.resource_path)
	var is_allied = DynastyManager.is_allied_region(data.resource_path)
	
	# 5. Update UI Elements (Phase 5.4)
	_populate_raid_targets(data, is_conquered, is_allied)
	_update_diplomacy_buttons(data, is_conquered, is_allied)
	
	# 6. Reveal the Panel
	region_info_panel.show()

func _populate_raid_targets(data: WorldRegionData, is_conquered: bool, is_allied: bool) -> void:
	# Clear list
	for child in target_list_container.get_children():
		child.queue_free()
		
	if is_conquered:
		var label = Label.new()
		label.text = "Region Conquered"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_list_container.add_child(label)
		return

	if data.raid_targets.is_empty():
		var label = Label.new()
		label.text = "No Valid Targets"
		target_list_container.add_child(label)
		return

	# Generate Buttons
	for target in data.raid_targets:
		# --- FIX: Safety Check for Corrupt Data ---
		if not target: 
			continue
		# ------------------------------------------

		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var risk_text = ""
		var btn_color = Color.WHITE # Default styling
		
		# Re-calculate attrition for display
		if current_attrition_risk > 0.0:
			risk_text = " (%d%% Risk)" % int(current_attrition_risk * 100)
			if current_attrition_risk > 0.3:
				btn_color = Color(1.0, 0.4, 0.4) # Reddish tint
			else:
				btn_color = Color(1.0, 0.9, 0.4) # Yellowish tint
		
		if is_allied:
			btn.text = "%s (Allied)" % target.display_name
			btn.disabled = true
		else:
			btn.text = "%s - Cost: %d Auth%s" % [target.display_name, target.raid_cost_authority, risk_text]
			btn.modulate = btn_color
			
			var can_afford = DynastyManager.can_spend_authority(target.raid_cost_authority)
			if not can_afford:
				btn.disabled = true
				btn.text += " (Low Auth)"
			else:
				btn.pressed.connect(_initiate_raid.bind(target))
		
		target_list_container.add_child(btn)
		
func _initiate_raid(target: RaidTargetData) -> void:
	# 1. Apply Attrition Gamble
	if current_attrition_risk > 0.0:
		_apply_attrition(current_attrition_risk)
	
	# 2. Set Data
	DynastyManager.set_current_raid_target(target.settlement_data)
	
	# 3. Set Difficulty Context (Phase 5.5)
	DynastyManager.current_raid_difficulty = target.difficulty_rating
	
	# 4. Spend Cost & Launch
	DynastyManager.spend_authority(target.raid_cost_authority)
	Loggie.msg("Launching raid on: %s (Diff: %d)" % [target.display_name, target.difficulty_rating]).domain("MAP").info()
	EventBus.scene_change_requested.emit(GameScenes.RAID_MISSION)

func _apply_attrition(risk_chance: float) -> void:
	if not SettlementManager.has_current_settlement(): return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	var units_lost = 0
	var units_to_remove: Array[String] = []
	
	Loggie.msg("Applying Attrition Risk: %.2f" % risk_chance).domain("MAP").info()
	
	for unit_path in garrison.keys():
		var count = garrison[unit_path]
		var surviving_count = 0
		for i in range(count):
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
		Loggie.msg("ATTRITION: Lost %d units to the sea!" % units_lost).domain("MAP").info()

func _update_diplomacy_buttons(data: WorldRegionData, is_conquered: bool, is_allied: bool) -> void:
	if is_conquered:
		subjugate_button.disabled = true
		subjugate_button.text = "Subjugate (Conquered)"
		marry_button.disabled = true
		marry_button.text = "Marry (Conquered)"
		return

	# Subjugate
	var base_cost = 5
	var ally_mod = 0
	if is_allied: ally_mod = 2
	calculated_subjugate_cost = max(1, base_cost - ally_mod)
	
	subjugate_button.text = "Subjugate (Cost: %d)" % calculated_subjugate_cost
	subjugate_button.disabled = not DynastyManager.can_spend_authority(calculated_subjugate_cost)
	
	# Marry
	marry_button.text = "Marry (Cost: 1 Heir)"
	var has_heir = DynastyManager.get_available_heir_count() > 0
	marry_button.disabled = is_allied or not has_heir
	if is_allied: marry_button.text = "Marry (Allied)"

# --- Standard Action Handlers ---
func _on_subjugate_pressed() -> void:
	if not selected_region_data: return
	var success = DynastyManager.spend_authority(calculated_subjugate_cost)
	if success:
		DynastyManager.add_conquered_region(selected_region_data.resource_path)
		var jarl = DynastyManager.get_current_jarl()
		jarl.legitimacy = min(100, jarl.legitimacy + 5) 
		DynastyManager.jarl_stats_updated.emit(jarl) 
		Loggie.msg("Region %s successfully subjugated." % selected_region_data.display_name).domain("MAP").info()
		_on_region_selected(selected_region_data)

func _on_marry_pressed() -> void:
	if not selected_region_data: return
	var success = DynastyManager.marry_heir_for_alliance(selected_region_data.resource_path)
	if success: 
		Loggie.msg("Alliance with %s successful." % selected_region_data.display_name).domain("MAP").info()
		_on_region_selected(selected_region_data)

func _on_settlement_pressed() -> void: EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)
func _on_dynasty_pressed() -> void: if dynasty_ui: dynasty_ui.show()

# --- UI Management ---

func close_all_ui() -> void:
	"""Closes all open UI windows for clean year transition."""
	var ui_closed = false
	
	# Close Dynasty UI
	if dynasty_ui and dynasty_ui.visible:
		dynasty_ui.hide()
		ui_closed = true
		
	# Close Region Info Panel  
	if region_info_panel and region_info_panel.visible:
		region_info_panel.hide()
		ui_closed = true
		
	# Close Work Assignment UI
	if work_assignment_ui and work_assignment_ui.visible:
		work_assignment_ui.hide()
		ui_closed = true
		
	# Clear region selection
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	selected_region_data = null
	selected_region_node = null
	
	if ui_closed:
		Loggie.msg("MacroMap: All UI closed for year transition").domain("MAP").info()

# --- End Year Logic ---
func _on_end_year_pressed() -> void:
	if not SettlementManager.has_current_settlement(): return
	var settlement = SettlementManager.current_settlement
	var total_pop = settlement.population_peasants
	var assigned_pop = 0
	for key in settlement.worker_assignments:
		assigned_pop += settlement.worker_assignments[key]
	
	if (total_pop - assigned_pop) > 0:
		idle_warning_dialog.dialog_text = "You have %d idle villagers.\nEnd year anyway?" % (total_pop - assigned_pop)
		idle_warning_dialog.popup_centered()
	else:
		_start_end_year_sequence()

func _start_end_year_sequence() -> void:
	# Close all UI before starting year transition
	close_all_ui()
	
	if not is_instance_valid(end_year_popup):
		_process_end_year_logic({})
		return
	var payout = SettlementManager.calculate_payout()
	end_year_popup.display_payout(payout, "End of Year Report")

func _on_end_year_payout_collected(payout: Dictionary) -> void:
	_process_end_year_logic(payout)

func _process_end_year_logic(payout: Dictionary) -> void:
	if not payout.is_empty(): SettlementManager.deposit_resources(payout)
	DynastyManager.end_year()
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	selected_region_data = null
	selected_region_node = null
	region_info_panel.hide()

func _on_event_system_finished() -> void:
	if randf() < enemy_raid_chance:
		Loggie.msg("--- ENEMY RAID TRIGGERED ---").domain("MAP").info()
		DynastyManager.is_defensive_raid = true
		EventBus.scene_change_requested.emit(GameScenes.RAID_MISSION)
	else:
		Loggie.msg("No enemy raid this year.").domain("MAP").info()
		EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

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

func _on_open_worker_ui() -> void:
	# 1. Set the flag so the next scene knows what to do
	SettlementManager.pending_management_open = true
	
	# 2. Go to the settlement
	Loggie.msg("Redirecting to Settlement for worker management...").domain("MAP").info()
	EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)
		
		
func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
	if SettlementManager.current_settlement:
		SettlementManager.current_settlement.worker_assignments = assignments
		SettlementManager.save_settlement()
		
func _unhandled_input(event: InputEvent) -> void:
	# Detect clicks on the "Ocean" (Background)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_deselect_current_region()

func _deselect_current_region() -> void:
	# 1. Reset Visuals on the old node
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	
	# 2. Clear Selection Data
	selected_region_node = null
	selected_region_data = null
	
	# 3. Hide the Side Panel
	if region_info_panel:
		region_info_panel.hide()
