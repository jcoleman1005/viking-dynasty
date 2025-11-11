# res://scenes/world_map/MacroMap.gd
# --- MODIFIED: Removed Button, Kept Idle Check ---

extends Node2D

# ... (Keep existing exports/onready) ...
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var end_year_popup_scene: PackedScene
@export var enemy_raid_chance: float = 0.25

@onready var authority_label: Label = $UI/JarlInfo/VBoxContainer/AuthorityLabel
@onready var renown_label: Label = $UI/JarlInfo/VBoxContainer/RenownLabel
@onready var end_year_button: Button = $UI/Actions/VBoxContainer/EndYearButton
@onready var region_info_panel: PanelContainer = $UI/RegionInfo
@onready var region_name_label: Label = $UI/RegionInfo/VBoxContainer/RegionNameLabel
@onready var launch_raid_button: Button = $UI/RegionInfo/VBoxContainer/LaunchRaidButton
@onready var settlement_button: Button = $UI/Actions/VBoxContainer/SettlementButton
@onready var tooltip: PanelContainer = $UI/Tooltip
@onready var tooltip_label: Label = $UI/Tooltip/Label
@onready var subjugate_button: Button = $UI/RegionInfo/VBoxContainer/SubjugateButton
@onready var dynasty_button: Button = $UI/Actions/VBoxContainer/DynastyButton
@onready var dynasty_ui: DynastyUI = $UI/Dynasty_UI
@onready var marry_button: Button = $UI/RegionInfo/VBoxContainer/MarryButton

const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer

# --- NEW: Only keep Dialog ---
var idle_warning_dialog: ConfirmationDialog
# ---------------------------

@onready var regions_container: Node2D = $Regions
var end_year_popup: PanelContainer
var selected_region_data: WorldRegionData
var selected_region_node: Region = null
var calculated_raid_cost: int = 1
var calculated_subjugate_cost: int = 5 

func _ready() -> void:
	DynastyManager.jarl_stats_updated.connect(_update_jarl_ui)
	
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
	
	# Load UI for fallback (when Idle Warning "Cancel" is clicked)
	if ResourceLoader.exists(WORK_ASSIGNMENT_SCENE_PATH):
		var scene = load(WORK_ASSIGNMENT_SCENE_PATH)
		if scene:
			work_assignment_ui = scene.instantiate()
			add_child(work_assignment_ui)
			if work_assignment_ui.has_signal("assignments_confirmed"):
				work_assignment_ui.assignments_confirmed.connect(_on_worker_assignments_confirmed)
	
	# --- IDLE WARNING DIALOG ---
	idle_warning_dialog = ConfirmationDialog.new()
	idle_warning_dialog.title = "Idle Villagers"
	idle_warning_dialog.ok_button_text = "End Year Anyway"
	idle_warning_dialog.cancel_button_text = "Manage Workers"
	idle_warning_dialog.confirmed.connect(_start_end_year_sequence)
	idle_warning_dialog.canceled.connect(_on_open_worker_ui) 
	add_child(idle_warning_dialog)
	# ---------------------------
	
	EventBus.event_system_finished.connect(_on_event_system_finished)
	_update_jarl_ui(DynastyManager.get_current_jarl())
	region_info_panel.hide()
	tooltip.hide()

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
		
	# 1. Check for Idle Villagers
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

# ... (Keep remaining functions: _update_jarl_ui, region handlers, raid buttons, etc. unchanged) ...
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
	var is_conquered = DynastyManager.has_conquered_region(data.resource_path)
	var is_allied = DynastyManager.is_allied_region(data.resource_path)
	if is_conquered:
		launch_raid_button.disabled = true
		launch_raid_button.text = "Raid (Conquered)"
		subjugate_button.disabled = true
		subjugate_button.text = "Subjugate (Conquered)"
		marry_button.disabled = true
		marry_button.text = "Marry (Conquered)"
		region_info_panel.show()
		return
	calculated_raid_cost = max(1, data.base_authority_cost) 
	launch_raid_button.text = "Launch Raid (Cost: %d Auth)" % calculated_raid_cost
	var can_afford_raid = DynastyManager.can_spend_authority(calculated_raid_cost)
	launch_raid_button.disabled = (not can_afford_raid) or is_allied
	if is_allied: launch_raid_button.text = "Raid (Allied)"
	elif not can_afford_raid: launch_raid_button.text += "\nNot Enough Authority"
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
	marry_button.text = "Marry for Alliance (Cost: 1 Heir)"
	var has_heir = DynastyManager.get_available_heir_count() > 0
	marry_button.disabled = is_allied or (not has_heir)
	if is_allied: marry_button.text = "Marry (Allied)"
	elif not has_heir: marry_button.text += "\n(No Available Heir)"
	region_info_panel.show()

func _on_launch_raid_pressed() -> void:
	if not selected_region_data: return
	DynastyManager.set_current_raid_target(selected_region_data.target_settlement_data)
	var success = DynastyManager.spend_authority(calculated_raid_cost)
	if success: EventBus.scene_change_requested.emit("raid_mission")
	else: DynastyManager.set_current_raid_target(null)

func _on_subjugate_pressed() -> void:
	if not selected_region_data: return
	var success = DynastyManager.spend_authority(calculated_subjugate_cost)
	if success:
		DynastyManager.add_conquered_region(selected_region_data.resource_path)
		var jarl = DynastyManager.get_current_jarl()
		jarl.legitimacy = min(100, jarl.legitimacy + 5) 
		DynastyManager.jarl_stats_updated.emit(jarl) 
		print("Region %s successfully subjugated." % selected_region_data.display_name)

func _on_marry_pressed() -> void:
	if not selected_region_data: return
	var success = DynastyManager.marry_heir_for_alliance(selected_region_data.resource_path)
	if success: print("MacroMap: Alliance with %s successful." % selected_region_data.display_name)
	else: print("MacroMap: Alliance failed (no available heir).")

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
