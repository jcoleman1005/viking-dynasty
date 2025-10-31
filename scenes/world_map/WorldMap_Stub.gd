# res://scenes/world_map/WorldMap_Stub.gd
# Simple world map stub for Phase 3
# GDD Ref: Phase 3 Task 6

extends Control

@onready var raid_button: Button = $RaidButton

func _ready() -> void:
	raid_button.pressed.connect(_on_raid_button_pressed)

func _on_raid_button_pressed() -> void:
	print("Starting raid mission...")
	# Change to the raid mission scene
	get_tree().change_scene_to_file("res://scenes/levels/DefensiveMicro.tscn")
