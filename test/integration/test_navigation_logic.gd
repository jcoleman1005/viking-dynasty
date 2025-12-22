extends GutTest

var _manager_ref

func before_all():
	# Ensure the Autoload is accessible or instantiate a local version for testing
	if has_node("/root/SettlementManager"):
		_manager_ref = get_node("/root/SettlementManager")
	else:
		_manager_ref = load("res://autoload/SettlementManager.gd").new()
		add_child_autofree(_manager_ref)
		_manager_ref._ready()

func test_isometric_math_sanity():
	# Verify that (0,0) World is (0,0) Grid
	var origin_grid = _manager_ref.world_to_grid(Vector2.ZERO)
	assert_eq(origin_grid, Vector2i.ZERO, "World Zero should be Grid Zero")

	# Test 1 Tile Right (Isometric)
	# In Iso: +X Grid is usually (+Width/2, +Height/2) in World
	var tile_width = _manager_ref.TILE_WIDTH
	var tile_height = _manager_ref.TILE_HEIGHT
	
	# Let's calculate where Grid (1, 0) should be in World pixels
	# Based on your formula: x = (gx - gy) * hw, y = (gx + gy) * hh
	# If gx=1, gy=0 -> x = hw, y = hh
	var expected_world_right = Vector2(tile_width * 0.5, tile_height * 0.5)
	
	var calculated_grid = _manager_ref.world_to_grid(expected_world_right)
	assert_eq(calculated_grid, Vector2i(1, 0), "World position should map to Grid (1,0)")

func test_pathfinding_returns_path():
	# 1. Setup a clean grid
	_manager_ref._init_grid()
	
	# 2. Define Start (0,0) and End (5,5)
	var start = Vector2.ZERO
	# Calculate world pos for 5,5
	var end_grid = Vector2i(5, 5)
	var end_world = _manager_ref.grid_to_world(end_grid)
	
	# 3. Request Path
	var path = _manager_ref.get_astar_path(start, end_world)
	
	# 4. Assert
	assert_gt(path.size(), 0, "Pathfinding returned empty array for valid clear path.")
	assert_eq(path[0], start, "Path should start at origin.")
	# Note: AStar path end might be slightly snapped to center of tile
	
func test_solid_obstacles():
	# 1. Block (1,0)
	var block_pos = Vector2i(1, 0)
	_manager_ref.set_astar_point_solid(block_pos, true)
	
	# 2. Try to path from (0,0) to (2,0)
	var start = Vector2.ZERO
	var end_grid = Vector2i(2, 0)
	var end_world = _manager_ref.grid_to_world(end_grid)
	
	var path = _manager_ref.get_astar_path(start, end_world)
	
	# 3. Assert path goes around (should not contain the blocked tile)
	var blocked_world = _manager_ref.grid_to_world(block_pos)
	
	# Convert path points back to grid to check
	var path_goes_through_wall = false
	for point in path:
		var grid_p = _manager_ref.world_to_grid(point)
		if grid_p == block_pos:
			path_goes_through_wall = true
			break
			
	assert_false(path_goes_through_wall, "Pathfinder walked through a solid wall!")
