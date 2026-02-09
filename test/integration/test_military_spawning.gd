#res://test/integration/test_military_spawning.gd
# res://test/integration/test_military_spawning.gd
extends GutTestBase

var spawner: UnitSpawner
var unit_container: Node2D
var rts_controller: RTSController

const RAIDER_DATA_PATH = "res://data/units/Unit_PlayerRaider.tres"

func before_each():
	super.before_each()
	unit_container = autoqfree(Node2D.new())
	unit_container.name = "UnitContainer"
	add_child(unit_container)
	
	rts_controller = autoqfree(RTSController.new())
	rts_controller.name = "RTSController"
	add_child(rts_controller)
	
	spawner = autoqfree(UnitSpawner.new())
	spawner.name = "UnitSpawner"
	spawner.unit_container = unit_container
	spawner.rts_controller = rts_controller
	add_child(spawner)

func test_spawn_full_strength_squad():
	var unit_data = load(RAIDER_DATA_PATH)
	if not unit_data:
		pending("Skipping test: Unit_PlayerRaider.tres not found.")
		return

	var warband = create_mock_warband(unit_data)
	warband.current_manpower = 5 
	
	spawner.spawn_garrison([warband], Vector2.ZERO)
	
	# --- FIX: Wait for deferred spawn logic to execute ---
	await wait_seconds(0.2) 
	# -----------------------------------------------------
	
	var child_count = unit_container.get_child_count()
	assert_eq(child_count, 5, "Should spawn 5 total units (1 Leader + 4 Soldiers)")
	
	var leaders = get_nodes_by_class(unit_container, "SquadLeader")
	assert_eq(leaders.size(), 1, "Exactly one SquadLeader should exist")
	
	if leaders.size() > 0:
		var leader = leaders[0] as SquadLeader
		assert_eq(leader.warband_ref, warband, "Leader should link to the correct Warband Data")
		assert_eq(leader.squad_soldiers.size(), 4, "Leader should track 4 soldiers")

	var minions = get_nodes_by_class(unit_container, "SquadSoldier")
	assert_eq(minions.size(), 4, "Exactly four SquadSoldiers should exist")
	
	if leaders.size() > 0:
		for minion in minions:
			assert_eq(minion.leader, leaders[0], "Minion should know its Leader")

func test_wounded_warband_skipped():
	var unit_data = load(RAIDER_DATA_PATH)
	var warband = create_mock_warband(unit_data)
	warband.is_wounded = true 
	
	spawner.spawn_garrison([warband], Vector2.ZERO)
	
	# Wait briefly to ensure nothing happens
	await wait_seconds(0.1)
	
	assert_eq(unit_container.get_child_count(), 0, "Wounded warbands should NOT spawn units")

func test_multiple_squad_offset():
	var unit_data = load(RAIDER_DATA_PATH)
	var wb1 = create_mock_warband(unit_data)
	var wb2 = create_mock_warband(unit_data)
	
	spawner.spawn_garrison([wb1, wb2], Vector2(1000, 1000))
	
	# --- FIX: Wait for deferred spawn ---
	await wait_seconds(0.2)
	# ------------------------------------
	
	var leaders = get_nodes_by_class(unit_container, "SquadLeader")
	assert_eq(leaders.size(), 2, "Should spawn 2 leaders")
	
	if leaders.size() >= 2:
		var l1 = leaders[0]
		var l2 = leaders[1]
		assert_ne(l1.global_position, l2.global_position, "Squads should spawn at different positions")
		var dist = l1.global_position.distance_to(Vector2(1000, 1000))
		assert_lt(dist, 500.0, "Squads should spawn near the target origin")

func get_nodes_by_class(parent: Node, class_name_str: String) -> Array:
	var result = []
	for child in parent.get_children():
		if child.get_script().resource_path.contains(class_name_str):
			result.append(child)
	return result
