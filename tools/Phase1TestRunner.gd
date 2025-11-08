# res://tools/Phase1_TestRunner.gd
#
# This is an automated integration test for our Phase 1 SceneManager refactor.
# It runs AS AN AUTOLOAD.
#
# To run:
# 1. Add this SCRIPT to Project > Project Settings > Autoload.
# 2. Set the "Main Scene" to "res://scenes/levels/SettlementBridge.tscn".
# 3. Press F5 to run the project.
# 4. Watch the console output. The game will quit automatically on pass/fail.

extends Node

func _ready() -> void:
	# Wait one frame for the main scene (SettlementBridge) to finish loading
	await get_tree().create_timer(0.2).timeout
	
	# Start the test flow
	call_deferred("run_test_flow")

func run_test_flow() -> void:
	print("--- STARTING PHASE 1 TRANSITION TEST ---")
	
	# ---
	# TEST 1: (Settlement -> Map)
	# ---
	print("\nTEST 1/4: Settlement -> Map")
	
	# --- MODIFICATION ---
	# First, verify we are on the correct starting scene (no await)
	if not check_current_scene("res://scenes/levels/SettlementBridge.tscn", "SettlementBridge"):
		return
	# --- END MODIFICATION ---
	
	if not await simulate_button_press("UI/StartRaidButton"):
		fail_test("Failed to press 'World Map' button from Settlement.")
		return
		
	if not await assert_scene_changed("res://scenes/world_map/MacroMap.tscn", "MacroMap"):
		return
	print("...PASS")

	# ---
	# TEST 2: (Map -> Settlement)
	# ---
	print("\nTEST 2/4: Map -> Settlement")
	if not await simulate_button_press("UI/Actions/VBoxContainer/SettlementButton"):
		fail_test("Failed to press 'Return to Settlement' button from Map.")
		return
		
	if not await assert_scene_changed("res://scenes/levels/SettlementBridge.tscn", "SettlementBridge (from Map)"):
		return
	print("...PASS")
	
	# ---
	# TEST 3: (Map -> Raid)
	# ---
	print("\nTEST 3/4: Map -> Raid")
	# Go back to the map first
	EventBus.scene_change_requested.emit("world_map")
	if not await assert_scene_changed("res://scenes/world_map/MacroMap.tscn", "MacroMap (Re-load)"):
		return
	
	# This is a complex click, we must simulate selecting a region first
	if not await simulate_map_to_raid():
		fail_test("Failed to simulate map-to-raid sequence.")
		return
		
	if not await assert_scene_changed("res://scenes/missions/RaidMission.tscn", "RaidMission"):
		return
	print("...PASS")
	
	# ---
	# TEST 4: (Raid -> Settlement)
	# ---
	print("\nTEST 4/4: Raid -> Settlement")
	if not await simulate_raid_end():
		fail_test("Failed to simulate raid end.")
		return
		
	if not await assert_scene_changed("res://scenes/levels/SettlementBridge.tscn", "SettlementBridge (from Raid)"):
		return
	print("...PASS")
	
	# ---
	# COMPLETE
	# ---
	print("\n--- ALL TESTS PASSED ---")
	print("Remember to remove 'Phase1_TestRunner.gd' from Autoload.")
	get_tree().quit()


# --- TEST HELPER FUNCTIONS ---

func simulate_button_press(button_path: String) -> bool:
	# Wait one frame for scene to be fully ready
	await get_tree().create_timer(0.1).timeout 
	
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		print("  ERROR: Current scene is not valid.")
		return false
		
	var button = scene.get_node_or_null(button_path)
	
	if not is_instance_valid(button):
		print("  ERROR: Could not find button at path: %s in scene %s" % [button_path, scene.scene_file_path])
		return false
		
	if button.disabled:
		print("  ERROR: Button '%s' is disabled, cannot press." % button_path)
		return false
	
	button.emit_signal("pressed")
	return true

func simulate_map_to_raid() -> bool:
	await get_tree().create_timer(0.1).timeout
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		print("  ERROR: Current scene is not valid for map-to-raid sim.")
		return false
		
	# 1. Get the region (assuming only one, "Region")
	var region = scene.get_node_or_null("Regions/Region")
	if not is_instance_valid(region):
		print("  ERROR: Could not find node 'Regions/Region' in MacroMap.")
		return false
	
	# 2. Simulate selecting it
	region.emit_signal("region_selected", region.data)
	
	# 3. Press the launch button
	return await simulate_button_press("UI/RegionInfo/VBoxContainer/LaunchRaidButton")

func simulate_raid_end() -> bool:
	await get_tree().create_timer(0.1).timeout
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		print("  ERROR: Current scene is not valid for raid-end sim.")
		return false
		
	var objective_manager = scene.get_node_or_null("RaidObjectiveManager")
	if not is_instance_valid(objective_manager):
		print("  ERROR: Could not find 'RaidObjectiveManager' in RaidMission.")
		return false
	
	# 4. Force a mission end
	# We call _on_mission_failed as it's the quickest way to trigger the scene change
	objective_manager._on_mission_failed()
	return true

# --- NEW FUNCTION ---
func check_current_scene(expected_path: String, step_name: String) -> bool:
	"""Checks the CURRENTLY loaded scene without awaiting a change."""
	var scene = get_tree().current_scene
	if not is_instance_valid(scene) or not scene.scene_file_path == expected_path:
		print("  ERROR: Failed pre-check for test '%s'" % step_name)
		print("    Expected scene: %s" % expected_path)
		if is_instance_valid(scene):
			print("    Got scene: %s" % scene.scene_file_path)
		else:
			print("    Got: <invalid_scene>")
		get_tree().quit()
		return false
	print("  Pre-check PASSED: Currently on %s" % scene.scene_file_path)
	return true

# --- RENAMED FUNCTION ---
func assert_scene_changed(expected_path: String, step_name: String) -> bool:
	"""Waits for a scene change, THEN asserts the new scene is correct."""
	var scene = get_tree().current_scene
	
	# Wait for the scene change to fully complete
	await get_tree().scene_changed
	
	# Get the new scene reference
	scene = get_tree().current_scene
	
	if not is_instance_valid(scene) or not scene.scene_file_path == expected_path:
		print("  ERROR: Failed test '%s'" % step_name)
		print("    Expected: %s" % expected_path)
		if is_instance_valid(scene):
			print("    Got: %s" % scene.scene_file_path)
		else:
			print("    Got: <invalid_scene>")
		get_tree().quit()
		return false
	return true

func fail_test(reason: String) -> void:
	print("\n--- TEST FAILED ---")
	print(reason)
	print("-------------------")
	get_tree().quit()
