# res://scenes/world_map/MacroMap.gd
#
# Main controller for the Macro Map scene.
# Connects UI to the DynastyManager and handles region selection.
extends Node2D # [cite: 164]

# Scene paths for navigation (DEPRECATED, but kept to avoid breaking .tscn)
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"

# UI Node References
@onready var authority_label: Label = $UI/JarlInfo/VBoxContainer/AuthorityLabel # [cite: 164]
@onready var renown_label: Label = $UI/JarlInfo/VBoxContainer/RenownLabel # [cite: 164]
@onready var end_year_button: Button = $UI/Actions/VBoxContainer/EndYearButton # [cite: 164]
@onready var region_info_panel: PanelContainer = $UI/RegionInfo # [cite: 164]
@onready var region_name_label: Label = $UI/RegionInfo/VBoxContainer/RegionNameLabel # [cite: 164]
@onready var launch_raid_button: Button = $UI/RegionInfo/VBoxContainer/LaunchRaidButton # [cite: 164]
@onready var settlement_button: Button = $UI/Actions/VBoxContainer/SettlementButton # [cite: 164]
@onready var tooltip: PanelContainer = $UI/Tooltip # [cite: 164]
@onready var tooltip_label: Label = $UI/Tooltip/Label

@onready var regions_container: Node2D = $Regions # [cite: 165]

var selected_region_data: WorldRegionData # [cite: 165]
var selected_region_node: Region = null

func _ready() -> void:
	# Connect to the DynastyManager
	DynastyManager.jarl_stats_updated.connect(_update_jarl_ui) # [cite: 165]
	
	# Connect to all child regions [cite: 165]
	for region in regions_container.get_children():
		if region is Region:
			region.region_hovered.connect(_on_region_hovered)
			region.region_exited.connect(_on_region_exited)
			region.region_selected.connect(_on_region_selected)
			
	# Connect local UI buttons [cite: 165]
	launch_raid_button.pressed.connect(_on_launch_raid_pressed)
	end_year_button.pressed.connect(_on_end_year_pressed)
	settlement_button.pressed.connect(_on_settlement_pressed)
	
	# Initialize UI
	_update_jarl_ui(DynastyManager.get_current_jarl()) # [cite: 165]
	region_info_panel.hide()
	tooltip.hide()

func _update_jarl_ui(jarl: JarlData) -> void: # [cite: 165]
	if not jarl:
		return
		
	authority_label.text = "Authority: %d / %d" % [jarl.current_authority, jarl.max_authority] # [cite: 165]
	renown_label.text = "Renown: %d" % jarl.renown # [cite: 165]
	
	# Re-check if we can still afford the selected raid
	if selected_region_data:
		_on_region_selected(selected_region_data)

# --- Region Signal Handlers ---

func _on_region_hovered(data: WorldRegionData, _screen_position: Vector2) -> void: # [cite: 165]
	tooltip_label.text = data.display_name # [cite: 165]
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip.position = mouse_pos + Vector2(15, 15)
	tooltip.show()

func _on_region_exited() -> void: # [cite: 166]
	tooltip.hide() # [cite: 166]

func _on_region_selected(data: WorldRegionData) -> void: # [cite: 166]
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
			
	selected_region_data = data # [cite: 166]
	
	# Update the UI panel [cite: 166]
	region_name_label.text = data.display_name
	launch_raid_button.text = "Raid: %s (Cost: %d)" % [data.display_name, data.base_authority_cost] # [cite: 166]
	
	# Check if Jarl can afford this action [cite: 166]
	var can_afford = DynastyManager.can_spend_authority(data.base_authority_cost)
	launch_raid_button.disabled = not can_afford
	
	if not can_afford:
		launch_raid_button.text += "\nNot Enough Authority"
		
	region_info_panel.show()

# --- UI Button Handlers ---

func _on_launch_raid_pressed() -> void: # [cite: 167]
	if not selected_region_data:
		return
		
	# 1. Set the target for the RaidMission [cite: 167]
	DynastyManager.set_current_raid_target(selected_region_data.target_settlement_data)
	
	# 2. Spend the Authority [cite: 167]
	var success = DynastyManager.spend_authority(selected_region_data.base_authority_cost)
	
	# 3. Change scene 
	if success:
		# --- MODIFICATION ---
		EventBus.scene_change_requested.emit("raid_mission") # [cite: 167]
		# --- END MODIFICATION ---
	else:
		# This shouldn't happen if the button is disabled, but as a fallback:
		push_error("MacroMap: LaunchRaid button was pressed but authority check failed.")
		DynastyManager.set_current_raid_target(null) # Clear the target

func _on_end_year_pressed() -> void: # [cite: 167]
	DynastyManager.end_year() # [cite: 167]
	
	# Deselect region as actions may no longer be valid
	if is_instance_valid(selected_region_node):
		selected_region_node.is_selected = false
		selected_region_node.set_visual_state(false)
	
	selected_region_data = null
	selected_region_node = null
	region_info_panel.hide()

func _on_settlement_pressed() -> void: # [cite: 167]
	# --- MODIFICATION ---
	EventBus.scene_change_requested.emit("settlement") # [cite: 167]
	# --- END MODIFICATION ---

func _input(event: InputEvent) -> void: # [cite: 167]
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("MacroMap received click - this means nothing blocked it yet")
