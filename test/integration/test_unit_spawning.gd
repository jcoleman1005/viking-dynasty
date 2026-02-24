# test/integration/test_unit_spawning.gd
extends "res://test/base/GutTestBase.gd"

var unit_container: Node2D
var rts_controller: Node
var unit_spawner: UnitSpawner
var _spawned_units: Array = []

func before_each() -> void:
	super.before_each()
	NavigationManager.unregister_grid()
	_spawned_units.clear()
	unit_container = Node2D.new()
	add_child_autoqfree(unit_container)
	rts_controller = load("res://player/RTSController.gd").new()
	add_child_autoqfree(rts_controller)
	unit_spawner = UnitSpawner.new()
	unit_spawner.unit_container = unit_container
	unit_spawner.rts_controller = rts_controller
	add_child_autoqfree(unit_spawner)

func after_each() -> void:
	for unit in _spawned_units:
		if is_instance_valid(unit):
			unit.queue_free()
	_spawned_units.clear()

func _spawn_and_wait(is_player: bool) -> BaseUnit:
	var warband = create_mock_warband()
	var unit = unit_spawner._spawn_unit_core(warband, Vector2(0, 0), is_player)
	await wait_seconds(0.5)
	if is_instance_valid(unit):
		_spawned_units.append(unit)
	return unit

func test_spawned_player_unit_has_nav_agent() -> void:
	var unit = await _spawn_and_wait(true)
	assert_not_null(unit, "Unit should spawn successfully")
	if not is_instance_valid(unit): return
	assert_true(unit.has_node("NavAgent"), "Spawned player unit must have NavAgent")

func test_spawned_player_unit_has_unit_visualizer() -> void:
	var unit = await _spawn_and_wait(true)
	assert_not_null(unit, "Unit should spawn successfully")
	if not is_instance_valid(unit): return
	assert_true(unit.has_node("UnitVisualizer"), "Spawned player unit must have UnitVisualizer")

func test_spawned_player_unit_has_correct_script() -> void:
	var unit = await _spawn_and_wait(true)
	assert_not_null(unit, "Unit should spawn successfully")
	if not is_instance_valid(unit): return
	var expected_script = load("res://scripts/units/SquadLeader.gd")
	assert_eq(unit.get_script(), expected_script, "Player unit must use SquadLeader.gd")

func test_spawned_player_unit_is_in_player_units_group() -> void:
	var unit = await _spawn_and_wait(true)
	assert_not_null(unit, "Unit should spawn successfully")
	if not is_instance_valid(unit): return
	assert_true(unit.is_in_group("player_units"), "Player unit must be in player_units group")

func test_spawned_enemy_unit_has_nav_agent() -> void:
	var unit = await _spawn_and_wait(false)
	assert_not_null(unit, "Enemy unit should spawn successfully")
	if not is_instance_valid(unit): return
	assert_true(unit.has_node("NavAgent"), "Spawned enemy unit must have NavAgent")
