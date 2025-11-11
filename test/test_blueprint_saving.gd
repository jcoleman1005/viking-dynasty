# Test script to verify blueprint saving functionality

extends EditorScript
# Test function to place a blueprint and verify it's saved
func test_blueprint_saving():
	print("=== Testing Blueprint Saving ===")
	
	if not SettlementManager.has_current_settlement():
		print("ERROR: No settlement loaded for testing")
		return false
	
	# Test building placement
	var building_data: BuildingData = load("res://data/buildings/Bldg_Wall.tres")
	if not building_data:
		print("ERROR: Could not load test building data")
		return false
	
	print("1. Initial pending buildings: %d" % SettlementManager.get_pending_construction_buildings().size())
	
	# Place a new blueprint
	var grid_pos = Vector2i(5, 5)  # Choose a safe position
	var new_building = SettlementManager.place_building(building_data, grid_pos, true)
	
	if new_building:
		print("2. Building placed successfully at %s" % grid_pos)
		print("   - Building state: %s" % new_building.current_state)
		print("   - Is active: %s" % new_building.is_active())
		
		# Check if it's in pending buildings
		var pending = SettlementManager.get_pending_construction_buildings()
		print("3. Pending buildings after placement: %d" % pending.size())
		for entry in pending:
			print("   - Entry: %s" % entry)
		
		# Wait a frame for save to complete
		await get_tree().process_frame
		
		# Reload the settlement and check if blueprint was saved
		if SettlementManager.current_settlement and SettlementManager.current_settlement.resource_path:
			var reloaded_settlement = load(SettlementManager.current_settlement.resource_path)
			if reloaded_settlement:
				print("4. Reloaded settlement - Pending buildings: %d" % reloaded_settlement.pending_construction_buildings.size())
				for i in range(reloaded_settlement.pending_construction_buildings.size()):
					var entry = reloaded_settlement.pending_construction_buildings[i]
					print("   - Saved Entry [%d]: %s" % [i, entry])
				
				if reloaded_settlement.pending_construction_buildings.size() > 0:
					print("✅ SUCCESS: Blueprint saved successfully!")
					return true
				else:
					print("❌ FAILED: Blueprint was not saved to file")
					return false
		else:
			print("ERROR: Could not reload settlement for verification")
			return false
	else:
		print("ERROR: Failed to place building")
		return false

func _ready():
	# Auto-run test if this script is attached to a node
	call_deferred("run_test")

func run_test():
	await get_tree().process_frame  # Wait for scene to be ready
	var result = await test_blueprint_saving()
	if result:
		print("🎉 Blueprint saving test PASSED!")
	else:
		print("💥 Blueprint saving test FAILED!")
