# res://scenes/world_map/WorldMap_Stub.gd
# World map interface for selecting raid targets
# GDD Ref: Phase 3 Task 6

extends Control

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
	get_tree().change_scene_to_file("res://scenes/missions/RaidMission.tscn")

func _on_back_pressed() -> void:
	"""Return to the settlement"""
	print("Returning to settlement...")
	get_tree().change_scene_to_file("res://scenes/levels/SettlementBridge.tscn")
