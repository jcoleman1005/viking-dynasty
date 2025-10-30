# res://scenes/levels/SettlementBridge.gd
#
# Main script for the settlement defense scene, now including unit spawning.
#
# --- MODIFIED: Added raider spawning logic ---

extends Node

# Pre-load resources needed for testing
var test_building_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var raider_scene: PackedScene = preload("res://scenes/units/VikingRaider.tscn")

@onready var defensive_micro: Node2D = $DefensiveMicro # Reference to the level instance

func _ready() -> void:
	spawn_raider_for_test()

func spawn_raider_for_test() -> void:
	# Spawn the raider near the top-left corner
	var raider_instance = raider_scene.instantiate()
	raider_instance.global_position = Vector2(50, 50) 
	
	# Add the unit instance to the DefensiveMicro scene instance
	# This keeps the world logic encapsulated in the level scene
	defensive_micro.add_child(raider_instance)
	print("TEST: Spawned Viking Raider at (50, 50).")

func _unhandled_input(event: InputEvent) -> void:
	# Left-click building placement test (from Task 3)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		
		if not test_building_data:
			push_error("Test data 'Bldg_Wall.tres' not found or invalid.")
			return

		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var grid_pos: Vector2i = Vector2i(mouse_pos / SettlementManager.astar_grid.cell_size)
		
		# Emit the signal to place the wall
		EventBus.build_request_made.emit(test_building_data, grid_pos)
		
		get_viewport().set_input_as_handled()
