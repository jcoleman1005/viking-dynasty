# res://scenes/world_map/WorldMap_Stub.gd
# World map interface for selecting raid targets
# GDD Ref: Phase 3 Task 6

extends Control

## The main raid mission scene to load (e.g., RaidMission.tscn)
@export var raid_mission_scene: PackedScene

## The scene to return to (e.g., SettlementBridge.tscn)
@export var settlement_bridge_scene: PackedScene

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
	
	# Transition to raid mission
	if raid_mission_scene:
		get_tree().change_scene_to_packed(raid_mission_scene)
	else:
		push_error("WorldMap_Stub: raid_mission_scene is not set! Cannot start raid.")

func _on_back_pressed() -> void:
	"""Return to the settlement"""
	print("Returning to settlement...")
	if settlement_bridge_scene:
		get_tree().change_scene_to_packed(settlement_bridge_scene)
	else:
		push_error("WorldMap_Stub: settlement_bridge_scene is not set! Cannot return.")
