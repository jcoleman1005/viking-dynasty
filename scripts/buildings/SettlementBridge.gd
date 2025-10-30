# res://scripts/buildings/SettlementBridge.gd

extends Node

# --- Preloaded Assets ---
var test_building_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var raider_scene: PackedScene = preload("res://scenes/units/VikingRaider.tscn")
var home_base_data: SettlementData = preload("res://data/settlements/home_base.tres")
var welcome_popup_scene: PackedScene = preload("res://ui/WelcomeHome_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var restart_button: Button = $UI/RestartButton
@onready var start_attack_button: Button = $UI/StartAttackButton
@onready var storefront_ui: Control = $UI/Storefront_UI
var welcome_popup: PanelContainer

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
const RAIDER_SPAWN_POS: Vector2 = Vector2(50, 50)


func _ready() -> void:
	# --- Setup ---
	SettlementManager.load_settlement(home_base_data)
	_find_and_setup_great_hall()
	_instance_ui()
	
	# --- Connect Signals ---
	restart_button.pressed.connect(_on_restart_pressed)
	start_attack_button.pressed.connect(_on_start_attack_pressed)

	# --- Payout Logic ---
	var payout = SettlementManager.calculate_chunk_payout()
	if not payout.is_empty():
		welcome_popup.display_payout(payout)
		start_attack_button.disabled = true # Disable combat until payout is collected
		storefront_ui.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		SettlementManager.save_timestamp()

func _process(_delta: float) -> void:
	# Using _process as a more robust way to catch debug input
	if Input.is_action_just_pressed("debug_time_travel"):
		if game_is_over or welcome_popup.visible:
			return
		
		# Test Case 1: 1 hour ago
		SettlementManager.force_set_timestamp(3600) 
		# Test Case 2: 24 hours ago (uncomment to test cap)
		# SettlementManager.force_set_timestamp(86400)
		
		print("DEBUG: Time travel key pressed. Timestamp forced. Reload scene now.")
		get_viewport().set_input_as_handled() # Consume to be safe

func _input(event: InputEvent) -> void:
	# This runs BEFORE GUI input, so we can consume it.
	if event.is_action_pressed("ui_accept"):
		if game_is_over or welcome_popup.visible:
			return # Don't grant loot if game over screen or popup is visible
		
		var sample_loot = {"gold": 100, "wood": 50, "food": 25, "stone": 75}
		print("DEBUG: Granting sample loot via key press.")
		SettlementManager.deposit_loot(sample_loot)
		get_viewport().set_input_as_handled() # CRITICAL: Stop event from reaching buttons


func _unhandled_input(event: InputEvent) -> void:
	# This runs AFTER GUI input, so it's safe for non-UI actions like placing buildings.
	if game_is_over or welcome_popup.visible:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var grid_pos: Vector2i = Vector2i(mouse_pos / SettlementManager.astar_grid.cell_size)
		SettlementManager.place_building(test_building_data, grid_pos)
		get_viewport().set_input_as_handled()

func _instance_ui() -> void:
	welcome_popup = welcome_popup_scene.instantiate()
	ui_layer.add_child(welcome_popup)
	welcome_popup.collect_button_pressed.connect(_on_payout_collected)

func _on_payout_collected(payout: Dictionary) -> void:
	SettlementManager.deposit_loot(payout)
	start_attack_button.disabled = false # Re-enable combat
	storefront_ui.show()

func _find_and_setup_great_hall() -> void:
	for building in SettlementManager.building_container.get_children():
		if building is BaseBuilding and building.data.display_name == "Great Hall":
			great_hall_instance = building
			great_hall_instance.building_destroyed.connect(_on_great_hall_destroyed)
			print("Great Hall found and connected.")
			return
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
	var label : Label = $UI/Label
	label.text = "YOU HAVE BEEN SACKED."
	restart_button.show()
	_destroy_all_enemies()

func _destroy_all_enemies() -> void:
	for enemy in unit_container.get_children():
		enemy.queue_free()
	print("All surviving enemies have been removed.")

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_start_attack_pressed() -> void:
	print("Start Attack button pressed. Spawning raider.")
	SettlementManager.save_timestamp()
	_spawn_raider_for_test()
	start_attack_button.hide()
	storefront_ui.hide()
