# res://scripts/buildings/SettlementBridge.gd

extends Node

# --- Exported Resources ---
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var welcome_popup_scene: PackedScene

# --- Default Assets (fallback) ---
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var default_raider_scene: PackedScene = preload("res://scenes/units/VikingRaider.tscn")
var default_welcome_popup: PackedScene = preload("res://ui/WelcomeHome_Popup.tscn")

# --- Scene Node References ---
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var restart_button: Button = $UI/RestartButton
@onready var start_attack_button: Button = $UI/StartAttackButton
@onready var start_raid_button: Button = $UI/StartRaidButton
@onready var storefront_ui: Control = $UI/Storefront_UI
var welcome_popup: PanelContainer

# --- State Variables ---
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
const RAIDER_SPAWN_POS: Vector2 = Vector2(50, 50)


func _ready() -> void:
	# --- Deferred Setup ---
	await get_tree().process_frame
	
	# Setup fallback resources if not set in inspector
	if not test_building_data:
		test_building_data = default_test_building
	if not raider_scene:
		raider_scene = default_raider_scene
	if not welcome_popup_scene:
		welcome_popup_scene = default_welcome_popup
	
	# Use inspector data if available, otherwise create default
	if not home_base_data:
		home_base_data = SettlementData.new()
		home_base_data.treasury = {"gold": 1000, "wood": 500, "food": 100, "stone": 200}
		home_base_data.placed_buildings = []
		home_base_data.garrisoned_units = {}
		print("DEBUG: Created default settlement data")
	else:
		print("DEBUG: Using inspector settlement data")
	
	SettlementManager.load_settlement(home_base_data)
	print("DEBUG: SettlementManager.current_settlement is: ", SettlementManager.current_settlement)
	_find_and_setup_great_hall()
	_instance_ui()
	
	# --- Connect Signals ---
	restart_button.pressed.connect(_on_restart_pressed)
	start_attack_button.pressed.connect(_on_start_attack_pressed)
	start_raid_button.pressed.connect(_on_start_raid_pressed)

	# --- Payout Logic ---
	# This now happens when the scene loads, simulating the return from an attack.
	var payout = SettlementManager.calculate_payout()
	if not payout.is_empty():
		welcome_popup.display_payout(payout)
		start_attack_button.disabled = true # Disable combat until payout is collected
		storefront_ui.hide()


func _input(event: InputEvent) -> void:
	# This runs BEFORE GUI input, so we can consume it.
	if event.is_action_pressed("ui_accept"):
		if game_is_over or welcome_popup.visible:
			return # Don't grant loot if game over screen or popup is visible
		
		print("DEBUG: SettlementManager.current_settlement before deposit: ", SettlementManager.current_settlement)
		var sample_loot = {"gold": 100, "wood": 50, "food": 25, "stone": 75}
		print("DEBUG: Granting sample loot via key press.")
		SettlementManager.deposit_resources(sample_loot)
		
		# DEBUG: Ensure storefront UI is visible to see the update
		if not storefront_ui.visible:
			storefront_ui.show()
			print("DEBUG: Showed storefront UI to display updated treasury")
		
		get_viewport().set_input_as_handled() # CRITICAL: Stop event from reaching buttons


func _unhandled_input(event: InputEvent) -> void:
	# This runs AFTER GUI input, so it's safe for non-UI actions like placing buildings.
	if game_is_over or (welcome_popup and welcome_popup.visible):
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
	SettlementManager.deposit_resources(payout)
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
	# Timestamps are no longer needed for a fixed-payout system.
	_spawn_raider_for_test()
	start_attack_button.hide()
	storefront_ui.hide()

func _on_start_raid_pressed() -> void:
	"""Navigate to the world map to select targets"""
	print("Opening world map...")
	
	# Validate that we have a settlement loaded
	if not SettlementManager.current_settlement:
		push_error("Cannot open world map: No settlement loaded")
		return
	
	# Ensure we have some units in the garrison for raiding
	if SettlementManager.current_settlement.garrisoned_units.is_empty():
		print("Warning: No units in garrison. Adding test unit.")
		# Add a test unit so raids can proceed
		var test_unit_path = "res://data/units/Unit_Raider.tres"
		SettlementManager.current_settlement.garrisoned_units[test_unit_path] = 2
		SettlementManager.save_settlement()
	
	print("Settlement loaded with garrison: %s" % SettlementManager.current_settlement.garrisoned_units)
	
	# Navigate to world map instead of direct raid
	get_tree().change_scene_to_file("res://scenes/world_map/WorldMap_Stub.tscn")
