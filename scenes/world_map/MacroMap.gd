# res://scenes/world_map/MacroMap.gd
#
# Main controller for the MacroMap scene.
# Connects UI to the DynastyManager and handles region selection.
extends Node2D

# Scene paths for navigation
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var end_year_popup_scene: PackedScene

# Raid Chance
@export var enemy_raid_chance: float = 0.25 # 25% chance

# UI Node References
@onready var authority_label: Label = $UI/JarlInfo/VBoxContainer/AuthorityLabel
@onready var renown_label: Label = $UI/JarlInfo/VBoxContainer/RenownLabel
@onready var end_year_button: Button = $UI/Actions/VBoxContainer/EndYearButton
@onready var region_info_panel: PanelContainer = $UI/RegionInfo
@onready var region_name_label: Label = $UI/RegionInfo/VBoxContainer/RegionNameLabel
@onready var launch_raid_button: Button = $UI/RegionInfo/VBoxContainer/LaunchRaidButton
@onready var settlement_button: Button = $UI/Actions/VBoxContainer/SettlementButton
@onready var tooltip: PanelContainer = $UI/Tooltip
@onready var tooltip_label: Label = $UI/Tooltip/Label

# --- Phase 2 UI ---
@onready var subjugate_button: Button = $UI/RegionInfo/VBoxContainer/SubjugateButton

# --- Phase 3a UI ---
@onready var dynasty_button: Button = $UI/Actions/VBoxContainer/DynastyButton
@onready var dynasty_ui: DynastyUI = $UI/Dynasty_UI
@onready var marry_button: Button = $UI/RegionInfo/VBoxContainer/MarryButton
# --- END ---

@onready var regions_container: Node2D = $Regions

var end_year_popup: PanelContainer
var selected_region_data: WorldRegionData
var selected_region_node: Region = null

# Stores the calculated cost after applying Jarl stats
var calculated_raid_cost: int = 1
var calculated_subjugate_cost: int = 5 # Base cost from proposal

func _ready() -> void:
	# Connect to the DynastyManager
	DynastyManager.jarl_stats_updated.connect(_update_jarl_ui)
	
	# Connect to all child regions
	for region in regions_container.get_children():
		if region is Region:
			region.region_hovered.connect(_on_region_hovered)
			region.region_exited.connect(_on_region_exited)
			region.region_selected.connect(_on_region_selected)
			
	# Connect local UI buttons
	launch_raid_button.pressed.connect(_on_launch_raid_pressed)
	settlement_button.pressed.connect(_on_settlement_pressed)
	subjugate_button.pressed.connect(_on_subjugate_pressed)
	end_year_button.pressed.connect(_on_end_year_pressed)
	
	# --- Phase 3a Connection ---
	dynasty_button.pressed.connect(_on_dynasty_pressed)
	marry_button.pressed.connect(_on_marry_pressed)
	# --- END ---
	
	# --- Setup Payout Popup ---
	if end_year_popup_scene:
		end_year_popup = end_year_popup_scene.instantiate()
		add_child(end_year_popup) 
		if end_year_popup.has_signal("collect_button_pressed"):
			end_year_popup.collect_button_pressed.connect(_on_end_year_payout_collected)
		else:
			push_error("EndOfYear_Popup scene is missing 'collect_button_pressed' signal.")
		end_year_popup.hide()
	else:
		push_warning("MacroMap: 'end_year_popup_scene' is not set in the Inspector!")
	
	# Connect to the EventManager's "all-clear" signal
	EventBus.event_system_finished.connect(_on_event_system_finished)
	
	# Initialize UI
	_update_jarl_ui(DynastyManager.get_current_jarl())
	region_info_panel.hide()
	tooltip.hide()

func _update_jarl_ui(jarl: JarlData) -> void:
	if not jarl:
		return
		
	authority_label.text = "Authority: %d / %d" % [jarl.current_authority, jarl.max_authority]
	renown_label.text = "Renown: %d" % jarl.renown
	
	if selected_region_data:
		_on_region_selected(selected_region_data)

# --- Region Signal Handlers ---

func _on_region_hovered(data: WorldRegionData, _screen_position: Vector2) -> void:
	tooltip_label.text = data.display_name
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip.position = mouse_pos + Vector2(15, 15)
	tooltip.show()

func _on_region_exited() -> void:
	tooltip.hide()

func _on_region_selected(data: WorldRegionData) -> void:
	# De-select the previously selected region, if any
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
		
	# Find the new region node
	for region in regions_container.get_children():
		if region is Region and region.data == data:
			selected_region_node = region
			selected_region_node.is_selected = true
			selected_region_node.set_visual_state(false)
			break
			
	selected_region_data = data
	region_name_label.text = data.display_name
	
	var jarl = DynastyManager.get_current_jarl()
	if not jarl:
		push_error("MacroMap: Cannot get Jarl from DynastyManager!")
		return

	# --- CHECK IF CONQUERED OR ALLIED ---
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
	
	# --- 1. CALCULATE RAID COST ---
	calculated_raid_cost = max(1, data.base_authority_cost) # Placeholder for now
	launch_raid_button.text = "Launch Raid (Cost: %d Auth)" % calculated_raid_cost
	var can_afford_raid = DynastyManager.can_spend_authority(calculated_raid_cost)
	launch_raid_button.disabled = (not can_afford_raid) or is_allied
	if is_allied:
		launch_raid_button.text = "Raid (Allied)"
	elif not can_afford_raid:
		launch_raid_button.text += "\nNot Enough Authority"
		
	# --- 2. CALCULATE SUBJUGATE COST ---
	var base_subjugate_cost = 5
	var trait_penalty = 0
	var alliance_discount = 0
	var penalty_text = ""
	var discount_text = ""
	
	# "Soft-Guide" Trait Penalty
	if jarl.has_trait("Pious") and data.region_type_tag == "Monastery":
		trait_penalty = 3
		penalty_text = " (+3 Pious)"
	
	# "Marry for Alliance" Bonus
	if is_allied:
		alliance_discount = 2 # Example discount
		discount_text = " (-2 Alliance)"
	
	calculated_subjugate_cost = max(1, base_subjugate_cost + trait_penalty - alliance_discount)
	
	subjugate_button.text = "Subjugate (Cost: %d Auth%s%s)" % [calculated_subjugate_cost, penalty_text, discount_text]
	var can_afford_subjugate = DynastyManager.can_spend_authority(calculated_subjugate_cost)
	subjugate_button.disabled = not can_afford_subjugate
	if not can_afford_subjugate:
		subjugate_button.text += "\nNot Enough Authority"

	# --- 3. CALCULATE MARRIAGE COST ---
	marry_button.text = "Marry for Alliance (Cost: 1 Heir)"
	var has_heir = DynastyManager.get_available_heir_count() > 0
	marry_button.disabled = is_allied or (not has_heir)
	
	if is_allied:
		marry_button.text = "Marry (Allied)"
	elif not has_heir:
		marry_button.text += "\n(No Available Heir)"
		
	region_info_panel.show()

# --- UI Button Handlers ---

func _on_launch_raid_pressed() -> void:
	if not selected_region_data:
		return
		
	DynastyManager.set_current_raid_target(selected_region_data.target_settlement_data)
	var success = DynastyManager.spend_authority(calculated_raid_cost)
	
	if success:
		EventBus.scene_change_requested.emit("raid_mission")
	else:
		push_error("MacroMap: LaunchRaid button was pressed but authority check failed.")
		DynastyManager.set_current_raid_target(null)

func _on_subjugate_pressed() -> void:
	if not selected_region_data:
		return
		
	var success = DynastyManager.spend_authority(calculated_subjugate_cost)
	
	if success:
		DynastyManager.add_conquered_region(selected_region_data.resource_path)
		
		# --- NEW: Add Legitimacy Boost ---
		var jarl = DynastyManager.get_current_jarl()
		jarl.legitimacy = min(100, jarl.legitimacy + 5) # +5 Legitimacy
		DynastyManager.jarl_stats_updated.emit(jarl) # Force UI/data refresh
		# --- END NEW ---
		
		print("Region %s successfully subjugated." % selected_region_data.display_name)
	else:
		push_error("MacroMap: Subjugate button was pressed but authority check failed.")

func _on_marry_pressed() -> void:
	"""Handles the 'Marry for Alliance' button press."""
	if not selected_region_data:
		return
		
	var success = DynastyManager.marry_heir_for_alliance(selected_region_data.resource_path)
	
	if success:
		print("MacroMap: Alliance with %s successful." % selected_region_data.display_name)
		# The UI will refresh automatically via the jarl_stats_updated signal.
	else:
		print("MacroMap: Alliance failed (no available heir).")

func _on_dynasty_pressed() -> void:
	"""Shows the Dynasty UI panel."""
	if is_instance_valid(dynasty_ui):
		dynasty_ui.show()

# --- End Year Payout Logic ---
func _on_end_year_pressed() -> void:
	if not is_instance_valid(end_year_popup):
		push_error("MacroMap: End year popup not instanced. Ending year without payout.")
		_process_end_year_logic({})
		return
	
	var payout = SettlementManager.calculate_payout()
	end_year_popup.display_payout(payout, "End of Year Payout")

func _on_end_year_payout_collected(payout: Dictionary) -> void:
	# This function's ONLY job is to process the end of year logic.
	# The scene change is now handled by _on_event_system_finished.
	_process_end_year_logic(payout)

func _on_event_system_finished() -> void:
	# This is the "all-clear" signal.
	# NOW we check for raids and change the scene.
	if randf() < enemy_raid_chance:
		print("--- ENEMY RAID TRIGGERED ---")
		DynastyManager.is_defensive_raid = true
		EventBus.scene_change_requested.emit("raid_mission")
	else:
		print("No enemy raid this year.")
		EventBus.scene_change_requested.emit("settlement")

func _process_end_year_logic(payout: Dictionary) -> void:
	if not payout.is_empty():
		SettlementManager.deposit_resources(payout)
	
	# This call is what triggers the EventManager's logic
	DynastyManager.end_year()
	
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	
	selected_region_data = null
	selected_region_node = null
	region_info_panel.hide()

func _on_settlement_pressed() -> void:
	EventBus.scene_change_requested.emit("settlement")

func _unhandled_input(event: InputEvent) -> void:
	pass
