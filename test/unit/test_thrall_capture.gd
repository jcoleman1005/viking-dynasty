extends GutTestBase

var leader: SquadLeader
var soldier: SquadSoldier
var civilian: CivilianUnit
var dummy_data: UnitData # [NEW] Shared data for mocks

func before_each():
	# 1. Setup Mock Data
	dummy_data = UnitData.new()
	dummy_data.max_loot_capacity = 100
	dummy_data.move_speed = 100.0
	dummy_data.encumbrance_speed_penalty = 0.5

	# 2. Setup Leader
	leader = SquadLeader.new()
	leader.data = dummy_data # [FIX] Assign Data
	leader.add_to_group("player_units")
	
	# 3. Setup Soldier
	soldier = SquadSoldier.new()
	soldier.data = dummy_data # [FIX] Assign Data
	soldier.add_to_group("player_units")
	soldier.leader = leader
	
	# 4. Setup Civilian
	civilian = CivilianUnit.new()
	civilian.data = dummy_data # [FIX] Assign Data
	
	# 5. Setup Mock Thrall Scene
	var t = ThrallUnit.new()
	t.data = dummy_data # [FIX] Ensure the packed thrall has data
	var packed = PackedScene.new()
	var result = packed.pack(t)
	if result != OK:
		push_error("Failed to pack mock thrall")
	civilian.thrall_unit_scene = packed
	t.free()

	# 6. Add to Tree (Triggers _ready)
	add_child_autofree(leader)
	add_child_autofree(soldier)
	add_child_autofree(civilian)

func test_surrender_to_leader():
	# Simulate leader hitting civilian
	civilian.take_damage(10, leader)
	
	# Assertions
	assert_true(civilian.is_queued_for_deletion(), "Civilian should despawn")
	assert_eq(leader.attached_thralls.size(), 1, "Leader should gain 1 thrall")
	
	if leader.attached_thralls.size() > 0:
		var new_thrall = leader.attached_thralls[0]
		assert_eq(new_thrall.assigned_leader, leader, "Thrall should know its master")

func test_surrender_to_soldier():
	# Simulate soldier hitting civilian
	civilian.take_damage(10, soldier)
	
	# Assertions
	assert_true(civilian.is_queued_for_deletion(), "Civilian should despawn")
	# When a soldier captures, the thrall goes to the Soldier's Leader
	assert_eq(leader.attached_thralls.size(), 1, "Soldier's Leader should gain the thrall")
