# res://scenes/missions/RaidObjectiveManager.gd
#
# Manages all mission-specific logic for a raid, including
# loot, win conditions, and loss conditions.
# Decoupled from RaidMission.gd (which is now just a level loader).
extends Node

# --- Mission Configuration ---
# These will be set in the Inspector on this node.
@export var victory_bonus_loot: Dictionary = {"gold": 200}
# MODIFIED: This is no longer used, but we leave it to avoid breaking the .tscn file
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var is_defensive_mission: bool = false

# --- Internal State ---
var raid_loot: RaidLootData
var rts_controller: RTSController
var enemy_hall: BaseBuilding
var building_container: Node2D

func _ready() -> void:
	raid_loot = RaidLootData.new()

func initialize(
	p_rts_controller: RTSController, 
	p_enemy_hall: BaseBuilding, 
	p_building_container: Node2D
) -> void:
	"""
	Called by RaidMission.gd after the level is loaded
	to pass in all necessary scene references.
	"""
	self.rts_controller = p_rts_controller
	self.enemy_hall = p_enemy_hall
	self.building_container = p_building_container
	
	if not is_instance_valid(rts_controller) or \
	   not is_instance_valid(enemy_hall) or \
	   not is_instance_valid(building_container):
		push_error("RaidObjectiveManager: Failed to initialize. Received invalid node references.")
		return
	
	print("RaidObjectiveManager: Initialized and tracking objectives.")
	
	# Connect to all necessary signals
	_connect_to_building_signals()
	_setup_win_loss_conditions()


func _connect_to_building_signals() -> void:
	# Connect to the Great Hall for the win condition
	if enemy_hall.has_signal("building_destroyed"):
		enemy_hall.building_destroyed.connect(_on_enemy_hall_destroyed)
	
	# Connect to *all* buildings for loot collection
	for building in building_container.get_children():
		if building is BaseBuilding and building.has_signal("building_destroyed"):
			building.building_destroyed.connect(_on_enemy_building_destroyed_for_loot)

# --- Objective Logic ---

func _on_enemy_building_destroyed_for_loot(building: BaseBuilding) -> void:
	"""Called when any enemy building is destroyed - collect loot."""
	var building_data = building.data as BuildingData
	
	if raid_loot and building_data:
		raid_loot.add_loot_from_building(building_data)
		print("RaidObjectiveManager: Building destroyed: %s | %s" % [building_data.display_name, raid_loot.get_loot_summary()])
	
	# Count remaining buildings for mission tracking
	var remaining_buildings = building_container.get_children().size() - 1 # -1 for the one just destroyed
	print("RaidObjectiveManager: Buildings remaining: %d" % remaining_buildings)

func _setup_win_loss_conditions() -> void:
	"""Setup win/loss condition monitoring"""
	if not is_defensive_mission:
		# Start periodic check for loss condition
		_check_loss_condition()
	else:
		print("RaidObjectiveManager: Skipping 'all units destroyed' loss check for defensive mission.")

func _check_loss_condition() -> void:
	"""Check if all player units are destroyed (loss condition)"""
	await get_tree().create_timer(1.0).timeout
	
	var remaining_units = 0
	if is_instance_valid(rts_controller):
		remaining_units = rts_controller.controllable_units.size()
	
	print("Loss check: %d units remaining" % remaining_units)
	
	if remaining_units == 0:
		_on_mission_failed()
		return # Stop the loop
	
	# Continue checking if mission is still active
	if is_instance_valid(enemy_hall):
		_check_loss_condition()
	else:
		print("Loss condition checking stopped - enemy hall destroyed")

func _on_mission_failed() -> void:
	"""Called when all player units are destroyed"""
	print("Mission Failed! All units destroyed.")
	
	_show_failure_message()
	
	await get_tree().create_timer(3.0).timeout
	
	# --- MODIFICATION ---
	EventBus.scene_change_requested.emit("settlement")
	# --- END MODIFICATION ---


func _show_failure_message() -> void:
	"""Display the mission failure message to the player"""
	var failure_popup = Control.new()
	failure_popup.name = "FailurePopup"
	failure_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.modulate = Color(0, 0, 0, 0.7)
	failure_popup.add_child(bg_panel)
	
	var message_container = VBoxContainer.new()
	message_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	var failure_label = Label.new()
	failure_label.text = "RAID FAILED!"
	failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_container.add_child(failure_label)
	
	var subtitle_label = Label.new()
	subtitle_label.text = "All units destroyed"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_container.add_child(subtitle_label)
	
	var return_label = Label.new()
	return_label.text = "Returning to settlement..."
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_container.add_child(return_label)
	
	failure_popup.add_child(message_container)
	# Add to the root of the scene tree to ensure it's visible
	get_tree().current_scene.add_child(failure_popup)
	print("Failure message displayed")

func _on_enemy_hall_destroyed(_building: BaseBuilding = null) -> void:
	"""Called when the enemy's Great Hall is destroyed"""
	print("Enemy Hall destroyed! Mission success!")
	
	# Add bonus loot
	raid_loot.add_loot("gold", victory_bonus_loot.get("gold", 200))
	var total_loot = raid_loot.get_total_loot()
	
	SettlementManager.deposit_resources(total_loot)
	print("Mission Complete! %s" % raid_loot.get_loot_summary())
	
	await get_tree().create_timer(2.0).timeout
	
	# --- MODIFICATION ---
	EventBus.scene_change_requested.emit("settlement")
	# --- END MODIFICATION ---
