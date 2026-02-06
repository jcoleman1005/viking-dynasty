#res://test/unit/test_inventory_mechanics.gd
extends GutTestBase

var unit: BaseUnit
var unit_data: UnitData

func before_each():
	# Setup a mock unit with known capacity stats
	unit = BaseUnit.new()
	unit_data = UnitData.new()
	unit_data.max_loot_capacity = 100
	unit_data.encumbrance_speed_penalty = 0.5 # 50% slow at max load
	unit.data = unit_data

func after_each():
	unit.free()

func test_add_loot_under_cap():
	var added = unit.add_loot("gold", 50)
	assert_eq(added, 50, "Should add full amount when space exists")
	assert_eq(unit.current_loot_weight, 50, "Weight should update")
	assert_eq(unit.inventory["gold"], 50, "Inventory dictionary should update")

func test_add_loot_over_cap():
	unit.add_loot("gold", 80)
	var added = unit.add_loot("gold", 50) # Try adding 50 more (only 20 space left)
	
	assert_eq(added, 20, "Should only add what fits")
	assert_eq(unit.current_loot_weight, 100, "Should be capped at max")
	assert_eq(unit.inventory["gold"], 100, "Inventory should be capped")

func test_encumbrance_math():
	# 1. Empty = 1.0 speed multiplier
	assert_eq(unit.get_speed_multiplier(), 1.0, "Empty unit should have full speed")
	
	# 2. Half Full (50/100)
	# Logic: 50% load * 50% max_penalty = 25% total penalty -> 0.75 speed
	unit.add_loot("gold", 50)
	assert_eq(unit.get_speed_multiplier(), 0.75, "Half load should apply half penalty")
	
	# 3. Full (100/100)
	# Logic: 100% load * 50% max_penalty = 50% total penalty -> 0.5 speed
	unit.add_loot("gold", 50)
	assert_eq(unit.get_speed_multiplier(), 0.5, "Full load should apply max penalty")
