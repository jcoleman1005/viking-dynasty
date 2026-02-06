#res://test/unit/test_RaidManager.gd
extends GutTest

var raid_manager
var mock_jarl

func before_each():
	# 1. Get the Autoload
	raid_manager = RaidManager
	
	# 2. Create a Mock Jarl
	# We need to manually set this on DynastyManager because the game isn't running normally
	mock_jarl = JarlData.new()
	mock_jarl.display_name = "Test Jarl"
	mock_jarl.command = 5
	# Base Jarl stats usually default to safe_range ~200 + (command * 50)
	
	DynastyManager.current_jarl = mock_jarl

func after_each():
	raid_manager.reset_raid_state()
	DynastyManager.current_jarl = null

func test_initial_state():
	assert_eq(raid_manager.raid_provisions_level, 1, "Default provisions should be 1")
	assert_eq(raid_manager.outbound_raid_force.size(), 0, "Force should be empty")

func test_prepare_raid_force():
	var warband = WarbandData.new()
	
	# FIX: Explicitly type the array so it matches the function signature
	var force: Array[WarbandData] = [warband]
	
	raid_manager.prepare_raid_force(force, 2)
	
	assert_eq(raid_manager.outbound_raid_force.size(), 1)
	assert_eq(raid_manager.raid_provisions_level, 2)

func test_attrition_safe_range():
	# Setup Jarl to have a known safe range
	mock_jarl.command = 20 # Should result in huge safe range
	
	var result = raid_manager.calculate_journey_attrition(10.0)
	
	assert_eq(result["modifier"], 1.0, "Should be no damage for short range")
	# Check title only if it exists, to be safe against RNG
	if result.has("title") and raid_manager.raid_provisions_level == 1:
		assert_eq(result["title"], "Uneventful Journey")

func test_attrition_risky_range():
	# Force a very difficult journey
	mock_jarl.command = 0
	
	# Distance 5000 is likely way beyond safe range
	var result = raid_manager.calculate_journey_attrition(5000.0)
	
	assert_has(result, "modifier")
	assert_has(result, "title")
	assert_has(result, "description")

func test_defensive_loss_renoun():
	mock_jarl.renown = 1000
	
	# NOTE: This test assumes EconomyManager handles a null Settlement safely.
	# If EconomyManager crashes, we may need to mock SettlementManager here too.
	var result = raid_manager.process_defensive_loss()
	
	assert_lt(mock_jarl.renown, 1000, "Renown should decrease after defeat")
	assert_has(result, "summary_text")
