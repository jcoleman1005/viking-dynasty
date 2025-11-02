# res://scenes/missions/RaidMission.gd
# Raid Mission Controller for Phase 3
# GDD Ref: Phase 3 Task 7

extends Node2D

# --- Exported Mission Configuration ---
@export var enemy_base_data: SettlementData
@export var default_enemy_base_path: String = "res://data/settlements/monastery_base.tres"
@export var victory_bonus_loot: Dictionary = {"gold": 200}
@export var player_spawn_formation: Dictionary = {"units_per_row": 5, "spacing": 40}
@export var mission_difficulty: float = 1.0
@export var allow_retreat: bool = true

# Node references
@onready var player_spawn_pos: Marker2D = $PlayerStartPosition
var enemy_hall: Node2D = null
var rts_controller: Node = null

# Mission state
var player_units: Array[Node2D] = []
var raid_loot: RaidLootData = null

func _ready() -> void:
	print("RaidMission starting...")
	
	# Initialize loot tracking system
	raid_loot = RaidLootData.new()
	print("Raid loot system initialized")
	
	# Load default enemy base if none specified
	if not enemy_base_data:
		enemy_base_data = load("res://data/settlements/monastery_base.tres")
		if not enemy_base_data:
			push_error("Could not load enemy base data")
			return
	
	_load_enemy_base()
	_spawn_player_garrison()
	_setup_rts_controller()
	_setup_win_loss_conditions()

func _load_enemy_base() -> void:
	"""Load and instance the enemy's base from SettlementData"""
	print("Loading enemy base...")
	
	if not enemy_base_data:
		push_error("No enemy base data provided")
		return
	
	# Instance each building from the enemy's placed_buildings array
	for building_entry in enemy_base_data.placed_buildings:
		var building_res_path: String = building_entry["resource_path"]
		var grid_pos: Vector2i = building_entry["grid_position"]
		
		var building_data: BuildingData = load(building_res_path)
		if not building_data or not building_data.scene_to_spawn:
			push_error("Failed to load building: %s" % building_res_path)
			continue
		
		# Instance the building
		var building_instance: Node2D = building_data.scene_to_spawn.instantiate()
		building_instance.name = building_data.display_name + "_Enemy"
		
		# Set building data
		if building_instance.has_method("set_data") or "data" in building_instance:
			building_instance.data = building_data
		
		# Position the building (convert grid to world position)
		var world_pos: Vector2 = Vector2(grid_pos) * 32 + Vector2(16, 16) # 32 = tile size, add half tile offset
		building_instance.global_position = world_pos
		
		# Add to enemy groups for targeting
		building_instance.add_to_group("enemy_buildings")
		
		# Check if this is the Great Hall (main target)
		if building_data.display_name.to_lower().contains("hall") or building_data.display_name.to_lower().contains("great"):
			enemy_hall = building_instance
			print("Found enemy hall: %s" % building_data.display_name)
			# Connect to building destroyed signal for win condition
			if building_instance.has_signal("building_destroyed"):
				building_instance.building_destroyed.connect(_on_enemy_hall_destroyed)
		
		# Connect ALL buildings to loot collection system
		if building_instance.has_signal("building_destroyed"):
			building_instance.building_destroyed.connect(_on_enemy_building_destroyed.bind(building_data))
		
		# Add to scene
		add_child(building_instance)
		print("Spawned enemy building: %s at %s" % [building_data.display_name, world_pos])

func _spawn_player_garrison() -> void:
	"""Spawn player units from the garrison"""
	print("=== SPAWNING PLAYER GARRISON ===")
	print("SettlementManager status: %s" % SettlementManager.get_settlement_status())
	print("Current settlement exists: %s" % (SettlementManager.current_settlement != null))
	if SettlementManager.current_settlement:
		print("Garrison data: %s" % SettlementManager.current_settlement.garrisoned_units)
	
	if not SettlementManager.current_settlement:
		print("No current settlement found - spawning test units for demo")
		_spawn_test_units()
		return
	
	var garrison = SettlementManager.current_settlement.garrisoned_units
	if garrison.is_empty():
		print("No units in garrison to spawn")
		return
	
	var _spawn_offset: Vector2 = Vector2.ZERO  # Future use for formation spacing
	var units_per_row: int = 5
	var current_row: int = 0
	var current_col: int = 0
	
	# Spawn each unit type according to count
	for unit_path in garrison:
		var unit_count: int = garrison[unit_path]
		var unit_data: UnitData = load(unit_path)
		
		if not unit_data or not unit_data.scene_to_spawn:
			push_error("Failed to load unit data: %s" % unit_path)
			continue
		
		# Spawn the specified number of this unit type
		for i in range(unit_count):
			var unit_instance: Node2D = unit_data.scene_to_spawn.instantiate()
			unit_instance.name = unit_data.display_name + "_" + str(i)
			
			# Set unit data
			if "data" in unit_instance:
				unit_instance.data = unit_data
			
			# Calculate spawn position in formation
			var spawn_pos: Vector2 = player_spawn_pos.global_position
			spawn_pos.x += current_col * 40  # 40 pixels apart horizontally
			spawn_pos.y += current_row * 40  # 40 pixels apart vertically
			unit_instance.global_position = spawn_pos
			
			# Add to player group for RTS selection
			unit_instance.add_to_group("player_units")
			
			# Add to scene and track
			add_child(unit_instance)
			player_units.append(unit_instance)
			
			print("Spawned player unit: %s at %s" % [unit_data.display_name, spawn_pos])
			
			# Update formation position
			current_col += 1
			if current_col >= units_per_row:
				current_col = 0
				current_row += 1

func _spawn_test_units() -> void:
	"""Spawn test units for demonstration when no settlement is available"""
	print("Spawning test units for box selection demo...")
	
	# Create basic unit scene manually for testing
	var units_per_row: int = 3
	var current_row: int = 0
	var current_col: int = 0
	
	# Spawn 6 test units in formation
	for i in range(6):
		var test_unit = CharacterBody2D.new()
		test_unit.name = "TestUnit_" + str(i)
		
		# Add a visual sprite (simple colored square)
		var sprite = ColorRect.new()
		sprite.size = Vector2(20, 20)
		sprite.color = Color.BLUE
		sprite.position = Vector2(-10, -10)  # Center the square
		test_unit.add_child(sprite)
		
		# Add collision shape for physics detection
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(20, 20)
		collision.shape = shape
		test_unit.add_child(collision)
		
		# Calculate spawn position in formation
		var spawn_pos: Vector2 = player_spawn_pos.global_position
		spawn_pos.x += current_col * 60  # 60 pixels apart horizontally
		spawn_pos.y += current_row * 60  # 60 pixels apart vertically
		test_unit.global_position = spawn_pos
		
		# Add to player group for RTS selection
		test_unit.add_to_group("player_units")
		
		# Add basic selection and movement functionality 
		var script_source = """
extends CharacterBody2D

var is_selected: bool = false
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 100.0
var is_moving: bool = false

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()
	print('%s %s' % [name, 'selected' if selected else 'deselected'])

func _draw() -> void:
	if is_selected:
		var radius = 15.0
		var color = Color.YELLOW
		color.a = 0.8
		draw_circle(Vector2.ZERO, radius, color, false, 2.0)

func command_move_to(target_pos: Vector2) -> void:
	target_position = target_pos
	is_moving = true
	print('%s moving to %s' % [name, target_pos])

func command_attack(target: Node2D) -> void:
	print('%s received attack command on %s' % [name, target.name])

func set_target_position(pos: Vector2) -> void:
	target_position = pos
	is_moving = true

func _physics_process(delta: float) -> void:
	if is_moving and target_position != Vector2.ZERO:
		var direction = (target_position - global_position).normalized()
		var distance = global_position.distance_to(target_position)
		
		if distance < 5.0:
			is_moving = false
			velocity = Vector2.ZERO
		else:
			velocity = direction * move_speed
		
		move_and_slide()
"""
		var temp_script = GDScript.new()
		temp_script.source_code = script_source
		temp_script.reload()
		test_unit.set_script(temp_script)
		
		# Add to scene and track
		add_child(test_unit)
		player_units.append(test_unit)
		
		print("Spawned test unit: %s at %s" % [test_unit.name, spawn_pos])
		
		# Update formation position
		current_col += 1
		if current_col >= units_per_row:
			current_col = 0
			current_row += 1

func _setup_rts_controller() -> void:
	"""Create and setup the RTS controller"""
	print("Setting up RTS controller...")
	
	# Load and instance the RTS controller
	var rts_script = load("res://player/RTSController.gd")
	rts_controller = rts_script.new()
	rts_controller.name = "RTSController"
	
	# Add as child to access scene tree
	add_child(rts_controller)
	
	# Register all player units with the controller
	for unit in player_units:
		if rts_controller.has_method("add_unit_to_group"):
			rts_controller.add_unit_to_group(unit)
	
	print("RTS controller setup complete")

func _on_enemy_building_destroyed(building_data: BuildingData) -> void:
	"""Called when any enemy building is destroyed - collect loot"""
	if raid_loot:
		raid_loot.add_loot_from_building(building_data)
		print("Building destroyed: %s | %s" % [building_data.display_name, raid_loot.get_loot_summary()])

func _setup_win_loss_conditions() -> void:
	"""Setup win/loss condition monitoring"""
	# Start periodic check for loss condition (all player units destroyed)
	_check_loss_condition()

func _check_loss_condition() -> void:
	"""Check if all player units are destroyed (loss condition)"""
	# Check every 1 second for responsive feedback
	await get_tree().create_timer(1.0).timeout
	
	# Count remaining player units
	var remaining_units = 0
	for unit in player_units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			remaining_units += 1
	
	# Update the array to remove invalid units
	player_units = player_units.filter(func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion())
	
	print("Loss check: %d units remaining" % remaining_units)
	
	if remaining_units == 0:
		_on_mission_failed()
		return
	
	# Continue checking if mission is still active (enemy hall still exists)
	if is_instance_valid(enemy_hall):
		_check_loss_condition()
	else:
		print("Loss condition checking stopped - enemy hall destroyed or mission ended")

func _on_mission_failed() -> void:
	"""Called when all player units are destroyed"""
	print("Mission Failed! All units destroyed.")
	
	# Show failure message UI
	_show_failure_message()
	
	# Wait for UI display, then return to settlement
	await get_tree().create_timer(3.0).timeout
	
	# Return to settlement bridge with no loot gain
	get_tree().change_scene_to_file("res://scenes/levels/SettlementBridge.tscn")

func _show_failure_message() -> void:
	"""Display the mission failure message to the player"""
	# Create failure message UI
	var failure_popup = Control.new()
	failure_popup.name = "FailurePopup"
	failure_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Semi-transparent background
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.modulate = Color(0, 0, 0, 0.7)
	failure_popup.add_child(bg_panel)
	
	# Message container
	var message_container = VBoxContainer.new()
	message_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_container.position = Vector2(-150, -75)
	message_container.size = Vector2(300, 150)
	
	# Main message
	var failure_label = Label.new()
	failure_label.text = "RAID FAILED!"
	failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_label.add_theme_font_size_override("font_size", 32)
	failure_label.add_theme_color_override("font_color", Color.RED)
	message_container.add_child(failure_label)
	
	# Subtitle
	var subtitle_label = Label.new()
	subtitle_label.text = "All units destroyed"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color.WHITE)
	message_container.add_child(subtitle_label)
	
	# Return message
	var return_label = Label.new()
	return_label.text = "Returning to settlement..."
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_label.add_theme_font_size_override("font_size", 14)
	return_label.add_theme_color_override("font_color", Color.GRAY)
	message_container.add_child(return_label)
	
	failure_popup.add_child(message_container)
	
	# Add to scene as top layer
	add_child(failure_popup)
	
	print("Failure message displayed")

func _on_enemy_hall_destroyed() -> void:
	"""Called when the enemy's Great Hall is destroyed"""
	print("Enemy Hall destroyed! Mission success!")
	
	# Use the dynamic loot system
	var total_loot = raid_loot.get_total_loot()
	
	# Add bonus loot for completing the main objective
	raid_loot.add_loot("gold", 200)  # Bonus gold for victory
	total_loot = raid_loot.get_total_loot()
	
	# Deposit loot to player settlement
	SettlementManager.deposit_resources(total_loot)
	
	print("Mission Complete! %s" % raid_loot.get_loot_summary())
	
	# Wait a moment for effect, then return to settlement
	await get_tree().create_timer(2.0).timeout
	
	# Return to settlement bridge
	get_tree().change_scene_to_file("res://scenes/levels/SettlementBridge.tscn")
