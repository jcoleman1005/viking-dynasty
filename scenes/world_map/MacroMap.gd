# res://scenes/world_map/MacroMap.gd
#
# Main controller for the Macro Map scene.
# Connects UI to the DynastyManager and handles region selection.
extends Node2D

# Scene paths for navigation (DEPRECATED, but kept to avoid breaking .tscn)
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"

# --- NEW: Popup Scene ---
@export var end_year_popup_scene: PackedScene
var end_year_popup: PanelContainer
# ----------------------

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

@onready var regions_container: Node2D = $Regions

var selected_region_data: WorldRegionData
var selected_region_node: Region = null

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
	end_year_button.pressed.connect(_on_end_year_pressed)
	settlement_button.pressed.connect(_on_settlement_pressed)
	
	# --- NEW: Setup Payout Popup ---
	if end_year_popup_scene:
		end_year_popup = end_year_popup_scene.instantiate()
		add_child(end_year_popup) # Add to MacroMap, not $UI (CanvasLayer)
		end_year_popup.collect_button_pressed.connect(_on_end_year_payout_collected)
		end_year_popup.hide()
	else:
		push_warning("MacroMap: 'end_year_popup_scene' is not set in the Inspector!")
	# -----------------------------
	
	# Initialize UI
	_update_jarl_ui(DynastyManager.get_current_jarl())
	region_info_panel.hide()
	tooltip.hide()

func _update_jarl_ui(jarl: JarlData) -> void:
	if not jarl:
		return
		
	authority_label.text = "Authority: %d / %d" % [jarl.current_authority, jarl.max_authority]
	renown_label.text = "Renown: %d" % jarl.renown
	
	# Re-check if we can still afford the selected raid
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
			selected_region_node.set_visual_state(false) # Update visual state (hover will be false)
			break
			
	selected_region_data = data
	
	# Update the UI panel
	region_name_label.text = data.display_name
	launch_raid_button.text = "Raid: %s (Cost: %d)" % [data.display_name, data.base_authority_cost]
	
	# Check if Jarl can afford this action
	var can_afford = DynastyManager.can_spend_authority(data.base_authority_cost)
	launch_raid_button.disabled = not can_afford
	
	if not can_afford:
		launch_raid_button.text += "\nNot Enough Authority"
		
	region_info_panel.show()

# --- UI Button Handlers ---

func _on_launch_raid_pressed() -> void:
	if not selected_region_data:
		return
		
	# 1. Set the target for the RaidMission
	DynastyManager.set_current_raid_target(selected_region_data.target_settlement_data)
	
	# 2. Spend the Authority
	var success = DynastyManager.spend_authority(selected_region_data.base_authority_cost)
	
	# 3. Change scene 
	if success:
		EventBus.scene_change_requested.emit("raid_mission")
	else:
		# This shouldn't happen if the button is disabled, but as a fallback:
		push_error("MacroMap: LaunchRaid button was pressed but authority check failed.")
		DynastyManager.set_current_raid_target(null) # Clear the target

# --- MODIFIED: End Year Payout Logic ---
func _on_end_year_pressed() -> void:
	if not is_instance_valid(end_year_popup):
		push_error("MacroMap: End year popup not instanced. Ending year without payout.")
		_process_end_year_logic({}) # Process with no payout
		return
	
	# 1. Calculate payout
	var payout = SettlementManager.calculate_payout()
	
	# 2. Display payout popup (it will emit signal when "Collect" is pressed)
	#    The popup will auto-emit if the payout is empty, skipping the UI
	end_year_popup.display_payout(payout, "End of Year Payout")

func _on_end_year_payout_collected(payout: Dictionary) -> void:
	# This is now the main logic, called *after* the user clicks "Collect"
	_process_end_year_logic(payout)
	
	# --- MODIFICATION ---
	# Add the scene change *after* processing the year
	EventBus.scene_change_requested.emit("settlement")
	# --- END MODIFICATION ---

func _process_end_year_logic(payout: Dictionary) -> void:
	# 1. Deposit resources
	if not payout.is_empty():
		SettlementManager.deposit_resources(payout)
	
	# 2. Process the end of year for the Jarl
	DynastyManager.end_year()
	
	# 3. Deselect region as actions may no longer be valid
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	
	selected_region_data = null
	selected_region_node = null
	region_info_panel.hide()
# --- END MODIFICATION ---

func _on_settlement_pressed() -> void:
	EventBus.scene_change_requested.emit("settlement")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("MacroMap received click - this means nothing blocked it yet")
