# res://scenes/world_map/WorldMap_Stub.gd
# World map interface for selecting raid targets
# GDD Ref: Phase 3 Task 6

extends Control

# --- MODIFIED: Use String paths, not PackedScene ---
## The main raid mission scene to load (e.g., RaidMission.tscn)
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"

## The scene to return to (e.g., SettlementBridge.tscn)
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
# --- END MODIFICATION ---

@onready var raid_monastery_button: Button = $ButtonContainer/RaidMonasteryButton
@onready var back_button: Button = $ButtonContainer/BackButton

func _ready() -> void:
	raid_monastery_button.pressed.connect(_on_raid_monastery_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Validate that we can actually raid (have settlement & units)
	_validate_raid_capability()

func _validate_raid_capability() -> void:
	"""Ensure the player can actually start a raid"""
	if not SettlementManager.current_settlement:
		raid_monastery_button.disabled = true
		raid_monastery_button.text = "No Settlement Loaded"
		return
	
	if SettlementManager.current_settlement.garrisoned_units.is_empty():
		raid_monastery_button.disabled = true
		raid_monastery_button.text = "No Units Available"
		return
	
	raid_monastery_button.disabled = false

func _on_raid_monastery_pressed() -> void:
	"""Launch the raid mission"""
	print("Starting raid on nearby monastery...")
	
	# Additional validation before starting raid
	if not SettlementManager.current_settlement:
		push_error("Cannot start raid: No settlement loaded")
		return
	
	# --- MODIFIED: Emit signal ---
	if not raid_mission_scene_path.is_empty():
		EventBus.scene_change_requested.emit(raid_mission_scene_path)
	else:
		push_error("WorldMap_Stub: raid_mission_scene_path is not set! Cannot start raid.")
	# --- END MODIFICATION ---

func _on_back_pressed() -> void:
	"""Return to the settlement"""
	print("Returning to settlement...")
	
	# --- MODIFIED: Emit signal ---
	if not settlement_bridge_scene_path.is_empty():
		EventBus.scene_change_requested.emit(settlement_bridge_scene_path)
	else:
		push_error("WorldMap_Stub: settlement_bridge_scene_path is not set! Cannot return.")
	# --- END MODIFICATION ---
