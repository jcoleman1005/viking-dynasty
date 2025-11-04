# Test script for Phase 3 functionality
extends Node

func _ready():
	print("=== PHASE 3 TEST STARTING ===")
	test_garrison_system()
	test_raid_system()

func test_garrison_system():
	print("\n--- Testing Garrison System (Pillar 1) ---")
	if SettlementManager.current_settlement:
		print("Current treasury: %s" % SettlementManager.current_settlement.treasury)
		print("Current garrison: %s" % SettlementManager.current_settlement.garrisoned_units)
		
		# Test unit recruitment
		var player_unit_data = load("res://data/units/Unit_PlayerRaider.tres") as UnitData
		if player_unit_data:
			print("Found player unit data: %s" % player_unit_data.display_name)
			print("Unit spawn cost: %s" % player_unit_data.spawn_cost)
			
			# Try to recruit one unit
			if SettlementManager.attempt_purchase(player_unit_data.spawn_cost):
				SettlementManager.recruit_unit(player_unit_data)
				print("Successfully recruited %s!" % player_unit_data.display_name)
			else:
				print("Cannot afford to recruit %s" % player_unit_data.display_name)
		else:
			print("ERROR: Could not load player unit data")
	else:
		print("ERROR: No settlement loaded")

func test_raid_system():
	print("\n--- Testing Raid System (Pillar 3) ---")
	if SettlementManager.current_settlement:
		var garrison = SettlementManager.current_settlement.garrisoned_units
		if not garrison.is_empty():
			print("Garrison ready for raid with %d unit types" % garrison.size())
			var total_units = 0
			for unit_path in garrison:
				total_units += garrison[unit_path]
			print("Total units available: %d" % total_units)
			print("Phase 3 raid system ready!")
		else:
			print("No units in garrison - cannot start raid")
	else:
		print("ERROR: No settlement loaded")
	
	print("\n=== PHASE 3 TEST COMPLETE ===")
