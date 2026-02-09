#res://scenes/world_map/MacroMap.gd
# res://scenes/world_map/MacroMap.gd
extends Node2D

# --- Scene Configuration ---
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var enemy_raid_chance: float = 0.25

# --- NEW: Raid Prep UI ---
@export var raid_prep_window_scene: PackedScene = preload("res://ui/RaidPrepWindow.tscn")

# --- Geography Anchor ---
@export var player_home_marker_path: NodePath = "PlayerHomeMarker"
@onready var player_home_marker: Marker2D = get_node_or_null(player_home_marker_path)
@onready var macro_camera: MacroCamera = $MacroCamera

# --- UI References ---
@onready var authority_label: Label = $UI/JarlInfo/VBoxContainer/AuthorityLabel
@onready var renown_label: Label = $UI/JarlInfo/VBoxContainer/RenownLabel
@onready var region_info_panel: PanelContainer = $UI/RegionInfo
@onready var region_name_label: Label = $UI/RegionInfo/VBoxContainer/RegionNameLabel
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
var raid_prep_window: RaidPrepWindow
var journey_report_dialog: AcceptDialog

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
	if launch_raid_button: launch_raid_button.hide()
	
	DynastyManager.jarl_stats_updated.connect(_update_jarl_ui)
	DynastyManager.jarl_stats_updated.connect(func(_j): queue_redraw())
	
	for region in regions_container.get_children():
		if region is Region:
			region.region_hovered.connect(_on_region_hovered)
			region.region_exited.connect(_on_region_exited)
			region.region_selected.connect(_on_region_selected)
			
	settlement_button.pressed.connect(_on_settlement_pressed)
	subjugate_button.pressed.connect(_on_subjugate_pressed)
	dynasty_button.pressed.connect(_on_dynasty_pressed)
	marry_button.pressed.connect(_on_marry_pressed)
	
	# 4. Raid Prep UI
	if raid_prep_window_scene:
		raid_prep_window = raid_prep_window_scene.instantiate()
		$UI.add_child(raid_prep_window) 
		raid_prep_window.raid_launched.connect(_finalize_raid_launch)
		
	journey_report_dialog = AcceptDialog.new()
	journey_report_dialog.title = "Journey Report"
	journey_report_dialog.confirmed.connect(_transition_to_raid_scene)
	add_child(journey_report_dialog)
	
	# 5. Event System
	EventBus.event_system_finished.connect(_on_event_system_finished)
	
	# 6. Final Cleanup
	_update_jarl_ui(DynastyManager.get_current_jarl())
	region_info_panel.hide()
	tooltip.hide()
	queue_redraw()

# --- Raid Preparation Logic ---

func _initiate_raid(target: RaidTargetData) -> void:
	if not raid_prep_window:
		Loggie.msg("MacroMap: RaidPrepWindow scene not assigned!").domain(LogDomains.MAP).error()
		return
		
	# 1. Hide Region Panel to declutter
	region_info_panel.hide()
	
	# 2. Setup and Show Prep Window
	raid_prep_window.setup(target)

func _finalize_raid_launch(target: RaidTargetData, warbands: Array[WarbandData], provision_level: int) -> void:
	# 1. Deduct Authority (Stays in DynastyManager)
	var cost = target.raid_cost_authority
	if target.authority_cost_override > -1: cost = target.authority_cost_override
	
	if not DynastyManager.spend_authority(cost):
		Loggie.msg("MacroMap: Failed to spend authority at last second!").domain(LogDomains.MAP).error()
		return

	# 2. Commit Data to RaidManager (FIXED)
	RaidManager.set_current_raid_target(target.settlement_data)
	RaidManager.current_raid_difficulty = target.difficulty_rating
	RaidManager.prepare_raid_force(warbands, provision_level)
	
	# 3. Calculate Journey Attrition (FIXED)
	var dist = 0.0
	if player_home_marker and is_instance_valid(selected_region_node):
		dist = player_home_marker.global_position.distance_to(selected_region_node.get_global_center())
		
	var report = RaidManager.calculate_journey_attrition(dist)
	
	# 4. Show Journey Report
	journey_report_dialog.title = report.get("title", "Journey")
	journey_report_dialog.dialog_text = report.get("description", "...")
	journey_report_dialog.popup_centered()

func _transition_to_raid_scene() -> void:
	Loggie.msg("MacroMap: Transitioning to Raid...").domain(LogDomains.MAP).info()
	EventBus.scene_change_requested.emit(GameScenes.RAID_MISSION)

# --- Visuals & Data Logic ---

func _draw() -> void:
	if not player_home_marker: return
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return
	
	var safe_r = jarl.get_safe_range()
	
	draw_circle(player_home_marker.position, safe_r, SAFE_COLOR)
	draw_arc(player_home_marker.position, safe_r, 0, TAU, 64, Color.GREEN, 2.0)
	draw_arc(player_home_marker.position, safe_r + 500, 0, TAU, 64, Color.RED, 1.0)

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
		var dist = player_home_marker.global_position.distance_to(region.get_global_center())
		var tier = 1
		if dist <= safe_range: tier = 1
		elif dist <= safe_range * 1.5: tier = 2
		else: tier = 3
		
		# --- FIX: Preserve Historical Name ---
		var current_name = ""
		if region.data:
			current_name = region.data.display_name
		# -------------------------------------
			
		# Pass the name into the generator
		var data = MapDataGenerator.generate_region_data(tier, current_name)
		
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
	if error != OK: push_error("MacroMap: Failed to save map state!")


func _on_region_selected(data: WorldRegionData) -> void:
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	
	# Reset selection
	selected_region_node = null
	
	for region in regions_container.get_children():
		if region is Region and region.data == data:
			selected_region_node = region
			selected_region_node.is_selected = true
			selected_region_node.set_visual_state(false)
			break
			
	selected_region_data = data
	region_name_label.text = data.display_name
	
	# Close other UI
	if raid_prep_window: raid_prep_window.hide()
	
	var jarl = DynastyManager.get_current_jarl()
	if not jarl: return
	
	current_attrition_risk = 0.0
	if player_home_marker and is_instance_valid(selected_region_node):
		var dist = player_home_marker.global_position.distance_to(selected_region_node.get_global_center())
		var safe_range = jarl.get_safe_range()
		if dist > safe_range:
			var overage = dist - safe_range
			current_attrition_risk = (overage / 100.0) * jarl.attrition_per_100px
			current_attrition_risk = min(current_attrition_risk, 1.0)

	var is_conquered = DynastyManager.has_conquered_region(data.resource_path)
	var is_allied = DynastyManager.is_allied_region(data.resource_path)
	
	# --- NEW: Check Home Status ---
	var is_home = false
	if selected_region_node and "is_home" in selected_region_node:
		is_home = selected_region_node.is_home
	# ------------------------------
	
	_populate_raid_targets(data, is_conquered, is_allied, is_home)
	_update_diplomacy_buttons(data, is_conquered, is_allied, is_home)
	
	region_info_panel.show()


func _populate_raid_targets(data: WorldRegionData, is_conquered: bool, is_allied: bool, is_home: bool) -> void:
	for child in target_list_container.get_children(): child.queue_free()
	
	# --- NEW: Home Check ---
	if is_home:
		var label = Label.new()
		label.text = "Home Region (Safe)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color.CORNFLOWER_BLUE)
		target_list_container.add_child(label)
		return
	# -----------------------

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

	for target in data.raid_targets:
		if not target: continue

		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var risk_text = ""
		var btn_color = Color.WHITE
		
		if current_attrition_risk > 0.0:
			risk_text = " (%d%% Risk)" % int(current_attrition_risk * 100)
			if current_attrition_risk > 0.3: btn_color = Color(1.0, 0.4, 0.4)
			else: btn_color = Color(1.0, 0.9, 0.4)
		
		if is_allied:
			btn.text = "%s (Allied)" % target.display_name
			btn.disabled = true
		else:
			var treasury = target.settlement_data.treasury
			var loot_type = "Mixed"
			if treasury.get("food", 0) > 300: loot_type = "FOOD"
			elif treasury.get("gold", 0) > 300: loot_type = "GOLD"
			elif treasury.get("wood", 0) > 300: loot_type = "WOOD"
			
			if loot_type == "GOLD": btn.add_theme_color_override("font_color", Color.GOLD)
			elif loot_type == "FOOD": btn.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			else: btn.add_theme_color_override("font_color", btn_color)

			var auth_cost = target.raid_cost_authority
			if target.authority_cost_override > -1: auth_cost = target.authority_cost_override
			
			btn.text = "%s [%s] (Cost: %d Auth%s)" % [target.display_name, loot_type, auth_cost, risk_text]
			
			var can_afford = DynastyManager.can_spend_authority(auth_cost)
			if not can_afford:
				btn.disabled = true
				btn.text += " (Low Auth)"
			else:
				btn.pressed.connect(_initiate_raid.bind(target))
		
		target_list_container.add_child(btn)

func _update_diplomacy_buttons(_data: WorldRegionData, is_conquered: bool, is_allied: bool, is_home: bool) -> void:
	# --- NEW: Home Check ---
	if is_home:
		subjugate_button.disabled = true
		subjugate_button.text = "Home Territory"
		marry_button.disabled = true
		marry_button.text = "Dynasty Seat"
		return
	# -----------------------

	if is_conquered:
		subjugate_button.disabled = true
		subjugate_button.text = "Subjugate (Conquered)"
		marry_button.disabled = true
		marry_button.text = "Marry (Conquered)"
		return

	var base_cost = 5
	var ally_mod = 0
	if is_allied: ally_mod = 2
	calculated_subjugate_cost = max(1, base_cost - ally_mod)
	
	subjugate_button.text = "Subjugate (Cost: %d)" % calculated_subjugate_cost
	subjugate_button.disabled = not DynastyManager.can_spend_authority(calculated_subjugate_cost)
	
	marry_button.text = "Marry (Cost: 1 Heir)"
	var has_heir = DynastyManager.get_available_heir_count() > 0
	marry_button.disabled = is_allied or not has_heir
	if is_allied: marry_button.text = "Marry (Allied)"

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

func close_all_ui() -> void:
	var ui_closed = false
	if dynasty_ui and dynasty_ui.visible:
		dynasty_ui.hide()
		ui_closed = true
	if region_info_panel and region_info_panel.visible:
		region_info_panel.hide()
		ui_closed = true
	if raid_prep_window and raid_prep_window.visible:
		raid_prep_window.hide()
		ui_closed = true
		
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	selected_region_data = null
	selected_region_node = null
	
	if ui_closed: Loggie.msg("MacroMap: All UI closed for year transition").domain("MAP").info()

func _on_event_system_finished() -> void:
	if randf() < enemy_raid_chance:
		Loggie.msg("--- ENEMY RAID TRIGGERED ---").domain("MAP").info()
		
		# FIX: Use RaidManager for defensive state
		RaidManager.is_defensive_raid = true
		
		EventBus.scene_change_requested.emit(GameScenes.RAID_MISSION)
	else:
		Loggie.msg("No enemy raid this year.").domain("MAP").info()
		EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)

func _update_jarl_ui(jarl: JarlData) -> void:
	if not jarl: return
	authority_label.text = "Authority: %d / %d" % [jarl.current_authority, jarl.max_authority]
	renown_label.text = "Renown: %d" % jarl.renown
	_update_region_status_visuals()
	if selected_region_data: _on_region_selected(selected_region_data)

func _update_region_status_visuals() -> void:
	if not player_home_marker: return
	
	var closest_dist = INF
	var home_region: Region = null
	
	for region in regions_container.get_children():
		if not region is Region: continue
		
		# 1. Check Alliance
		if region.data and DynastyManager.is_allied_region(region.data.resource_path):
			region.is_allied = true
		else:
			region.is_allied = false
		
		# 2. Find Home (Closest to Marker)
		var dist = player_home_marker.global_position.distance_to(region.get_global_center())
		if dist < closest_dist:
			closest_dist = dist
			home_region = region
			
		# Reset home flag for now (winner takes it below)
		region.is_home = false
		
		# Refresh visual state (if not currently hovered/selected)
		if not region.is_selected:
			region.set_visual_state(false)

	# 3. Apply Home
	if home_region:
		home_region.is_home = true
		if not home_region.is_selected:
			home_region.set_visual_state(false)

func _on_region_hovered(data: WorldRegionData, _screen_position: Vector2) -> void:
	tooltip_label.text = data.display_name
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip.position = mouse_pos + Vector2(15, 15)
	tooltip.show()

func _on_region_exited() -> void: tooltip.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_deselect_current_region()

func _deselect_current_region() -> void:
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	selected_region_node = null
	selected_region_data = null
	if region_info_panel: region_info_panel.hide()
	if raid_prep_window: raid_prep_window.hide()
