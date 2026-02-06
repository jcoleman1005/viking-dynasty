#res://test/integration/test_escort_cycle.gd
extends GutTestBase

var leader: SquadLeader
var soldier: SquadSoldier
var civilian: CivilianUnit
var retreat_zone: Area2D

func before_each():
	# 1. Specific Environment Setup
	retreat_zone = Area2D.new()
	retreat_zone.add_to_group("retreat_zone")
	retreat_zone.position = Vector2(1000, 1000) 
	add_child_autofree(retreat_zone)
	
	# 2. Use Factory for Units (Auto-adds to tree because we pass 'self')
	leader = TestUtils.create_mock_unit(SquadLeader, self)
	soldier = TestUtils.create_mock_unit(SquadSoldier, self)
	civilian = TestUtils.create_mock_unit(CivilianUnit, self)
	
	# 3. Connect Logic
	leader.squad_soldiers.append(soldier)
	soldier.leader = leader
	soldier.global_position = Vector2(100, 100) 
	
	# Auto-free handled by parent_node logic in TestUtils? 
	# No, TestUtils adds child but doesn't register autofree.
	# We should manually autofree them to be safe, or update TestUtils.
	# For now, let's explicit autofree to be safe.
	autofree(leader)
	autofree(soldier)
	autofree(civilian)

func test_civilian_surrender_signal():
	watch_signals(civilian)
	civilian.current_health = 10
	civilian.surrender_hp_threshold = 5
	civilian.take_damage(8, leader)
	assert_signal_emitted(civilian, "surrender_requested")
	assert_eq(civilian.current_health, 1)

func test_leader_finds_volunteer():
	civilian.global_position = Vector2(150, 150) 
	leader.request_escort_for(civilian)
	assert_eq(soldier.fsm.current_state, UnitAIConstants.State.COLLECTING)
	assert_eq(soldier.fsm.objective_target, civilian)

func test_soldier_collects_prisoner():
	soldier.assign_escort_task(civilian)
	soldier.global_position = civilian.global_position
	soldier.process_collecting_logic(0.1)
	assert_true(civilian in soldier.escorted_prisoners)
	assert_eq(soldier.fsm.current_state, UnitAIConstants.State.ESCORTING)

func test_escort_completion():
	soldier.escorted_prisoners.append(civilian)
	soldier.fsm.change_state(UnitAIConstants.State.ESCORTING)
	soldier.fsm.objective_target = retreat_zone
	soldier.global_position = retreat_zone.global_position
	soldier.complete_escort()
	assert_true(civilian.is_queued_for_deletion())
	assert_eq(soldier.escorted_prisoners.size(), 0)
	assert_eq(soldier.fsm.current_state, UnitAIConstants.State.REGROUPING)

func test_batching_logic():
	# Use Factory for quick instances
	var civ1 = TestUtils.create_mock_unit(CivilianUnit, self)
	var civ2 = TestUtils.create_mock_unit(CivilianUnit, self)
	autofree(civ1)
	autofree(civ2)
	
	soldier.assign_escort_task(civ1)
	soldier.assign_escort_task(civ2)
	assert_true(civ2 in soldier.pending_prisoners)
	
	soldier.global_position = civ1.global_position
	soldier.process_collecting_logic(0.1)
	
	assert_eq(soldier.fsm.current_state, UnitAIConstants.State.COLLECTING)
	assert_eq(soldier.fsm.objective_target, civ2)
