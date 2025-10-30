# res://scripts/buildings/SettlementBridge.gd
#
# This is the "main" script for the settlement defense scene.
#
# --- THIS IS THE CORRECT SCRIPT FOR THE TASK 5 "SACKED" LOOP ---

extends Node

# --- Preloaded Test Assets ---
var test_building_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var raider_scene: PackedScene = preload("res://scenes/units/VikingRaider.tscn")
var hall_data: BuildingData = preload("res://data/buildings/Bldg_GreatHall.tres")

# --- Scene Node References ---
@onready var defensive_micro: Node2D = $DefensiveMicro
@onready var unit_container: Node2D = $UnitContainer
@onready var label: Label = $UI/Label

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false

# --- Provisional Spawn Points ---
const HALL_GRID_POS: Vector2i = Vector2i(25, 15)
const RAIDER_SPAWN_POS: Vector2 = Vector2(50, 50)


func _ready() -> void:
	_spawn_great_hall()
	_spawn_raider_for_test()

func _spawn_great_hall() -> void:
	"""
	Spawns the Great Hall and connects to its destruction signal.
	"""
	if not hall_data:
		push_error("Great Hall data not found!")
		return
		
	# Use the SettlementManager to place the hall
	SettlementManager.place_building(hall_data, HALL_GRID_POS)
	
	# The manager just placed it, so we can get it from the container.
	# We get the last child added.
	great_hall_instance = SettlementManager.building_container.get_child(
		SettlementManager.building_container.get_child_count() - 1
	)
	
	# --- This is the GDD's "connect" logic ---
	if great_hall_instance:
		great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)
		print("Great Hall spawned. Listening for its destruction.")
	else:
		push_error("Failed to get Great Hall instance after spawn.")

func _spawn_raider_for_test() -> void:
	if not great_hall_instance:
		push_error("Cannot spawn raider: Great Hall does not exist.")
		return
		
	var raider_instance: BaseUnit = raider_scene.instantiate()
	
	# Add unit to the UnitContainer
	unit_container.add_child(raider_instance)
	
	# Set position *after* adding to scene
	raider_instance.global_position = RAIDER_SPAWN_POS
	
	# --- THIS IS THE FIX ---
	# Tell the raider what to attack
	raider_instance.set_attack_target(great_hall_instance)

# --- Main "Sacked" Loop Logic ---

func _on_great_hall_destroyed(building: BaseBuilding) -> void:
	"""
	This is the "Sacked" state. It's called when the Hall's
	'building_destroyed' signal is emitted.
	"""
	print("GAME OVER: The Great Hall has been destroyed!")
	game_is_over = true
	
	# 1. Update the UI
	label.text = "YOU HAVE BEEN SACKED."
	
	# 2. Update the SettlementManager as per GDD
	SettlementManager.update_building_status(HALL_GRID_POS, "Destroyed")
	
	# 3. End the "battle"
	_destroy_all_enemies()

func _destroy_all_enemies() -> void:
	"""
	Cleans up all active enemy units.
	"""
	for enemy in unit_container.get_children():
		enemy.queue_free()
	print("All surviving enemies have been removed.")

# --- Player Input (for placing walls) ---

func _unhandled_input(event: InputEvent) -> void:
	# Don't allow building if game is over
	if game_is_over:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		
		if not test_building_data:
			return

		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var grid_pos: Vector2i = Vector2i(mouse_pos / SettlementManager.astar_grid.cell_size)
		
		EventBus.build_request_made.emit(test_building_data, grid_pos)
		get_viewport().set_input_as_handled()
