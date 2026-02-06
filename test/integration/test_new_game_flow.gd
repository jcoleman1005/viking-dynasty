#res://test/integration/test_new_game_flow.gd
# res://test/integration/test_new_game_flow.gd
extends GutTest

const USER_SAVE_PATH = "user://savegame_dynasty.tres"

func before_each():
	# Clean slate: Remove existing save file to ensure we test generation, not loading
	if FileAccess.file_exists(USER_SAVE_PATH):
		DirAccess.remove_absolute(USER_SAVE_PATH)
	
	# Reset Manager
	if DynastyManager:
		DynastyManager.current_jarl = null

func after_all():
	# Cleanup: Remove the test save file
	if FileAccess.file_exists(USER_SAVE_PATH):
		DirAccess.remove_absolute(USER_SAVE_PATH)

func test_generator_produces_valid_jarl():
	# 1. Generate
	var jarl = DynastyGenerator.generate_random_dynasty()
	
	# 2. Verify Basic Stats
	assert_not_null(jarl, "Jarl should not be null")
	assert_gt(jarl.age, 16, "Jarl should be an adult")
	assert_gt(jarl.display_name.length(), 0, "Jarl should have a name")
	
	# 3. Verify Stats Ranges (Based on Generator logic 8-15)
	assert_between(jarl.command, 8, 15, "Command within range")
	assert_between(jarl.stewardship, 8, 15, "Stewardship within range")
	
	# 4. Verify Heirs
	assert_gt(jarl.heirs.size(), 0, "Should generate at least 1 heir")
	var designated_found = false
	for heir in jarl.heirs:
		if heir.is_designated_heir:
			designated_found = true
	assert_true(designated_found, "One heir should be auto-designated")

func test_heir_age_logic():
	var jarl = DynastyGenerator.generate_random_dynasty()
	
	for heir in jarl.heirs:
		# Logic: Parent must be at least 16 when child born
		var max_possible_age = jarl.age - 16
		assert_lt(heir.age, jarl.age, "Heir must be younger than parent")
		assert_lte(heir.age, max_possible_age, "Heir age valid relative to parent maturity")

func test_start_new_campaign_flow():
	# 1. Setup Signal Watcher
	watch_signals(DynastyManager)
	
	# 2. Execute Action
	DynastyManager.start_new_campaign()
	
	# 3. Verify Signal Emission
	assert_signal_emitted(DynastyManager, "jarl_stats_updated", "UI should be notified of new Jarl")
	
	# 4. Verify Manager State
	var current = DynastyManager.current_jarl
	assert_not_null(current, "Manager should hold new Jarl")
	assert_eq(current.resource_path, USER_SAVE_PATH, "Resource path should be bound to user save")
	
	# 5. Verify Persistence
	# FIX: assert_file_exists only accepts the path, no custom message
	assert_file_exists(USER_SAVE_PATH)

func test_persistence_loading():
	# 1. Generate and Save
	DynastyManager.start_new_campaign()
	var original_name = DynastyManager.current_jarl.display_name
	
	# 2. Nuke memory to simulate restart
	DynastyManager.current_jarl = null
	
	# 3. Trigger Load (via getter or private method)
	# We use get_current_jarl() which triggers _load_game_data if null
	var loaded_jarl = DynastyManager.get_current_jarl()
	
	# 4. Verify
	assert_not_null(loaded_jarl, "Should load from disk")
	assert_eq(loaded_jarl.display_name, original_name, "Name should match saved data")
