# res://scripts/buildings/SettlementBridge.gd

extends Node

# --- Preloaded Test Assets ---
var test_building_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var raider_scene: PackedScene = preload("res://scenes/units/VikingRaider.tscn")
var home_base_data: SettlementData = preload("res://data/settlements/home_base.tres")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var label: Label = $UI/Label

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false

# --- Provisional Spawn Points ---
const RAIDER_SPAWN_POS: Vector2 = Vector2(50, 50)


func _ready() -> void:
	# Load the settlement from the resource file
	SettlementManager.load_settlement(home_base_data)
	
	# After loading, find the Great Hall to connect signals and for the AI to target
	_find_and_setup_great_hall()
	
	# The rest of the MVP logic remains
	_spawn_raider_for_test()

	# Placeholder for payout logic from Task 6
	var payout = SettlementManager.calculate_chunk_payout()
	if not payout.is_empty():
		# This is where the "Welcome Home" popup would be triggered.
		# For now, just print.
		print("Payout calculated on load: %s" % payout)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		SettlementManager.save_timestamp()

func _find_and_setup_great_hall() -> void:
	# Find the Great Hall instance, which was spawned by the SettlementManager
	for building in SettlementManager.building_container.get_children():
		if building is BaseBuilding and building.data.display_name == "Great Hall":
			great_hall_instance = building
			break
	
	if great_hall_instance:
		great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)
		print("Great Hall found and connected.")
	else:
		push_error("SettlementBridge: Could not find Great Hall instance after loading settlement.")


func _spawn_raider_for_test() -> void:
	if not great_hall_instance:
		push_error("Cannot spawn raider: Great Hall does not exist.")
		return
		
	var raider_instance: BaseUnit = raider_scene.instantiate()
	unit_container.add_child(raider_instance)
	raider_instance.global_position = RAIDER_SPAWN_POS
	raider_instance.set_attack_target(great_hall_instance)


func _on_great_hall_destroyed(_building: BaseBuilding) -> void:
	print("GAME OVER: The Great Hall has been destroyed!")
	game_is_over = true
	label.text = "YOU HAVE BEEN SACKED."
	_destroy_all_enemies()

func _destroy_all_enemies() -> void:
	for enemy in unit_container.get_children():
		enemy.queue_free()
	print("All surviving enemies have been removed.")


func _unhandled_input(event: InputEvent) -> void:
	if game_is_over:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if not test_building_data:
			return

		# NOTE: This part will need to be updated in Task 3 to use the new purchase flow
		# For now, it bypasses the treasury for testing purposes.
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var grid_pos: Vector2i = Vector2i(mouse_pos / SettlementManager.astar_grid.cell_size)
		SettlementManager.place_building(test_building_data, grid_pos)
		
		get_viewport().set_input_as_handled()
