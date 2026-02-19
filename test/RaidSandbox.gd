extends Node2D

## RaidSandbox
## Standalone testing scene for Raid Mechanics.
## Sets up mock Jarl, Raid Force, and Target before initializing RaidMission.

@onready var raid_mission = $RaidMission
var debug_label: Label

func _ready() -> void:
	Loggie.msg("=== Raid Sandbox: Starting Setup ===").domain(LogDomains.RAID).info()
	
	_setup_mock_jarl()
	_setup_mock_raid_force()
	_setup_mock_target()
	_setup_debug_overlay()
	
	if EventBus:
		EventBus.scene_change_requested.connect(_on_mission_end_requested)
	
	Loggie.msg("=== Raid Sandbox: Setup Complete ===").domain(LogDomains.RAID).info()

func _setup_debug_overlay() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	debug_label = Label.new()
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.position = Vector2(20, 20)
	canvas.add_child(debug_label)

func _process(_delta: float) -> void:
	if is_instance_valid(debug_label):
		var text = "--- RAID SANDBOX DEBUG ---\n"
		
		# 1. Raid Active (Mocked or checked via Managers)
		var raid_active = false
		if is_instance_valid(raid_mission):
			var obj_mgr = raid_mission.get_node_or_null("RaidObjectiveManager")
			if obj_mgr: raid_active = obj_mgr.is_initialized and not obj_mgr.mission_over
		text += "Raid Active: %s\n" % str(raid_active)
		
		# 2. Player Unit Count
		var units = get_tree().get_nodes_in_group("player_units")
		text += "Player Units: %d\n" % units.size()
		
		# 3. Smoke Signal (Checked via Objective Manager timer activity)
		var smoke_active = false
		if is_instance_valid(raid_mission):
			var obj_mgr = raid_mission.get_node_or_null("RaidObjectiveManager")
			if obj_mgr: smoke_active = obj_mgr.fyrd_timer_active
		text += "Smoke Signal: %s\n" % str(smoke_active)
		
		# 4. Timer / Day (If applicable)
		if is_instance_valid(raid_mission):
			var obj_mgr = raid_mission.get_node_or_null("RaidObjectiveManager")
			if obj_mgr and obj_mgr.fyrd_timer_active:
				text += "Fyrd Timer: %.1fs\n" % obj_mgr.time_remaining
		
		debug_label.text = text

func _on_mission_end_requested(scene_path: String) -> void:
	Loggie.msg("Raid Sandbox: Mission End Requested -> " + scene_path).domain(LogDomains.RAID).info()
	if RaidManager.pending_raid_result:
		var res = RaidManager.pending_raid_result
		Loggie.msg("FINAL RESULT: " + res.outcome + " (" + res.victory_grade + ")").domain(LogDomains.RAID).info()
		Loggie.msg("LOOT: " + str(res.loot)).domain(LogDomains.RAID).info()
		Loggie.msg("CASUALTIES: " + str(res.casualties.size())).domain(LogDomains.RAID).info()
	else:
		Loggie.msg("FINAL RESULT: No result data found in RaidManager.").domain(LogDomains.RAID).warn()
	
	# Instead of changing scene, we just log it in the sandbox.
	Loggie.msg("Sandbox: Scene change suppressed. Press 'R' to restart.").domain(LogDomains.RAID).info()

func _setup_mock_jarl() -> void:
	if not DynastyManager.current_jarl:
		var mock_jarl = JarlData.new()
		mock_jarl.display_name = "Test Jarl"
		mock_jarl.command = 15
		mock_jarl.prowess = 15
		DynastyManager.current_jarl = mock_jarl
		Loggie.msg("Mock Jarl Created.").domain(LogDomains.RAID).info()

func _setup_mock_raid_force() -> void:
	RaidManager.reset_raid_state()
	
	# Correct path for Player Raiders
	var warrior_data = load("res://data/units/Unit_PlayerRaider.tres")
	if not warrior_data:
		# Fallback if specific file missing, try generic
		warrior_data = load("res://data/units/EnemyVikingRaider_Data.tres")
	if warrior_data:
		var warband = WarbandData.new(warrior_data)
		warband.custom_name = "Sandbox Veterans"
		warband.current_manpower = 10
			
			# Encapsulation: Inject directly into mission to bypass global manager if desired
		if is_instance_valid(raid_mission):
				var force: Array[WarbandData] = [warband]
				raid_mission.force_warbands = force		
		RaidManager.prepare_raid_force([warband], 2) # Provision level 2
		Loggie.msg("Mock Raid Force Prepared (10 Warriors).").domain(LogDomains.RAID).info()
	else:
		push_error("RaidSandbox: Could not find Unit_PlayerRaider.tres or fallback.")

func _setup_mock_target() -> void:
	# Try to find an existing settlement file or use procedural
	var target_path = "res://data/settlements/monastery_base.tres"
	var target_data: SettlementData
	
	if ResourceLoader.exists(target_path):
		target_data = load(target_path)
		Loggie.msg("Loaded Target from disk: " + target_path).domain(LogDomains.RAID).info()
	else:
		# Generate a procedural one
		target_data = MapDataGenerator._generate_procedural_settlement("Monastery", 1.0)
		target_data.map_seed = randi()
		Loggie.msg("Generated Procedural Target.").domain(LogDomains.RAID).info()
	
	# Encapsulation: Inject directly into mission
	if is_instance_valid(raid_mission):
		raid_mission.force_enemy_settlement = target_data

	RaidManager.set_current_raid_target(target_data)
	RaidManager.current_raid_difficulty = 2

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			Loggie.msg("Raid Sandbox: Reloading Scene...").domain(LogDomains.RAID).info()
			get_tree().reload_current_scene()
