extends GutTest

var _manager_ref
var _grid_width = 10
var _grid_height = 10

func before_all():
	# 1. Setup a Mock SettlementManager
	if has_node("/root/SettlementManager"):
		_manager_ref = get_node("/root/SettlementManager")
	else:
		_manager_ref = load("res://autoload/SettlementManager.gd").new()
		add_child_autofree(_manager_ref)
		
	# 2. Force Initialize the AStarGrid
	_manager_ref.active_astar_grid = AStarGrid2D.new()
	_manager_ref.active_astar_grid.region = Rect2i(0, 0, _grid_width, _grid_height)
	_manager_ref.active_astar_grid.cell_size = Vector2(64, 32)
	_manager_ref.active_astar_grid.update()
	
	# 3. FILL MAP WITH WATER (Make everything Solid)
	# We simulate a map that is 100% water initially
	for x in range(_grid_width):
		for y in range(_grid_height):
			_manager_ref.active_astar_grid.set_point_solid(Vector2i(x, y), true)

	# 4. Create a Tiny Island at (5,5)
	# Only (5,5) is walkable.
	_manager_ref.active_astar_grid.set_point_solid(Vector2i(5, 5), false)

func test_spawn_safety_check():
	# --- SCENARIO 1: Spawn in Deep Water (0,0) ---
	# There is no land nearby. Should return INF (Failure).
	var water_pos = _manager_ref.grid_to_world(Vector2i(0, 0))
	var result = _manager_ref.request_valid_spawn_point(water_pos, 2) # Check radius 2
	
	assert_eq(result, Vector2.INF, "Deep water spawn should fail (return INF).")

	# --- SCENARIO 2: Spawn Near Shore (5,4) ---
	# (5,4) is Water, but (5,5) is Land. Radius 1 should find it.
	var shore_water_pos = _manager_ref.grid_to_world(Vector2i(5, 4))
	var shore_result = _manager_ref.request_valid_spawn_point(shore_water_pos, 2)
	
	assert_ne(shore_result, Vector2.INF, "Shore spawn should find nearby land.")
	
	var result_grid = _manager_ref.world_to_grid(shore_result)
	assert_eq(result_grid, Vector2i(5, 5), "Should snap to the only valid land tile (5,5).")

func test_spawn_on_valid_land():
	# --- SCENARIO 3: Spawn on Land (5,5) ---
	# Already safe. Should return original position.
	var land_pos = _manager_ref.grid_to_world(Vector2i(5, 5))
	var result = _manager_ref.request_valid_spawn_point(land_pos, 2)
	
	# Note: It might snap to center, so distance should be near 0
	assert_almost_eq(result.x, land_pos.x, 1.0, "Valid land spawn should remain unchanged.")
	assert_almost_eq(result.y, land_pos.y, 1.0, "Valid land spawn should remain unchanged.")
