extends Node

func _ready():
	await get_tree().create_timer(1.0).timeout
	_test_serialization()
	queue_free()

func _test_serialization():
	Loggie.msg("=== SERIALIZATION TEST (Safe Persistence Check) ===").domain(LogDomains.SYSTEM).info()
	
	if not SettlementManager.current_settlement:
		Loggie.msg("FAIL: No settlement loaded.").domain(LogDomains.SYSTEM).error()
		return

	# 1. Setup specific test state
	SettlementManager.reconcile_households()
	var house = SettlementManager.current_settlement.households[0]
	
	var test_name = "TEST_UNIQUE_NAME"
	house.head_of_household.given_name = test_name
	house.head_of_household.generation = 99
	house.head_of_household.ancestors.assign(["Oldest", "Newer", test_name])
	
	Loggie.msg("Pre-serialization: %s Gen %d" % [test_name, 99]).domain(LogDomains.SYSTEM).info()

	# 2. Simulate Save/Load using Buffer (The core of Godot's persistence)
	# This converts the resource to a byte array and back, verifying serialization.
	var buffer = var_to_bytes_with_objects(SettlementManager.current_settlement)
	var reloaded_settlement = bytes_to_var_with_objects(buffer) as SettlementData
	
	# 3. Assert
	if not reloaded_settlement:
		Loggie.msg("FAIL: Serialization failed to return a SettlementData object.").domain(LogDomains.SYSTEM).error()
		return
		
	var reloaded_house = reloaded_settlement.households[0]
	if not reloaded_house.head_of_household:
		Loggie.msg("FAIL: Reloaded head is null.").domain(LogDomains.SYSTEM).error()
		return
		
	var reloaded_name = reloaded_house.head_of_household.given_name
	var reloaded_gen = reloaded_house.head_of_household.generation
	var reloaded_ancestors = reloaded_house.head_of_household.ancestors.size()
	
	if reloaded_name == test_name and reloaded_gen == 99 and reloaded_ancestors == 3:
		Loggie.msg("PASS: Nested HouseholdHead resources correctly serialized and recovered.").domain(LogDomains.SYSTEM).info()
	else:
		Loggie.msg("FAIL: Serialization mismatch. Name: %s, Gen: %d, Ancestors: %d" % [reloaded_name, reloaded_gen, reloaded_ancestors]).domain(LogDomains.SYSTEM).error()
