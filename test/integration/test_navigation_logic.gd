# res://test/integration/test_navigation_logic.gd
extends GutTest

var _nav_manager = NavigationManager 
var _mock_tilemap: TileMapLayer

func before_each():
	# 1. Setup a Mock TileMapLayer for NavigationManager to use as source of truth
	_mock_tilemap = TileMapLayer.new()
	# In a real game, this would be on a node in the tree.
	# NavigationManager uses map_to_local/local_to_map.
	add_child(_mock_tilemap)
	
	# 2. Register the map with NavigationManager
	# We use a 10x10 grid for simple testing
	var rect = Rect2i(0, 0, 10, 10)
	_nav_manager.register_map(_mock_tilemap, rect)

func after_each():
	_nav_manager.unregister_grid()
	_mock_tilemap.free()

func test_isometric_coordinate_consistency():
	# Test that world_to_grid and grid_to_world are consistent
	var grid_pos = Vector2i(5, 5)
	var world_pos = _nav_manager._grid_to_world(grid_pos)
	var back_to_grid = _nav_manager._world_to_grid(world_pos)
	
	assert_eq(back_to_grid, grid_pos, "World and Grid conversions should be bidirectional")

func test_smoothing_removes_zigzag():
	# Start at (0,0) center
	var start_pos = _nav_manager.snap_to_grid_center(_nav_manager._grid_to_world(Vector2i(0, 0)))
	# End at (8,8) center
	var end_pos = _nav_manager.snap_to_grid_center(_nav_manager._grid_to_world(Vector2i(8, 8)))
	
	var path = _nav_manager.get_astar_path(start_pos, end_pos)
	
	assert_gt(path.size(), 0, "Path should not be empty")
	
	# Verify String Pulling (Should be 2 points for a straight diagonal in an empty field)
	# Isometric AStar with DIAGONAL_MODE_ALWAYS often produces 2 points for clear LOS.
	assert_lt(path.size(), 4, "Path should be smoothed! Actual size: %s" % path.size())
	
	# Verify Start (First point is adjusted to exact actor pos)
	assert_eq(path[0], start_pos, "Path must start at origin")
	
	# Verify End
	var last_point = path[path.size() - 1]
	assert_almost_eq(last_point.distance_to(end_pos), 0.0, 1.0, "Path must end at target")

func test_start_position_precision_fix():
	# Start at a slight offset from the center of (0,0)
	var center = _nav_manager.snap_to_grid_center(_nav_manager._grid_to_world(Vector2i(0, 0)))
	var exact_unit_pos = center + Vector2(5, 2)
	var target_pos = _nav_manager.snap_to_grid_center(_nav_manager._grid_to_world(Vector2i(5, 5)))
	
	var path = _nav_manager.get_astar_path(exact_unit_pos, target_pos)
	
	assert_gt(path.size(), 0)
	assert_eq(path[0], exact_unit_pos, "Path start point must match Unit Position, NOT Grid Center.")

func test_obstacle_avoidance_with_smoothing():
	var start_pos = _nav_manager.snap_to_grid_center(_nav_manager._grid_to_world(Vector2i(0, 0)))
	var end_pos = _nav_manager.snap_to_grid_center(_nav_manager._grid_to_world(Vector2i(4, 4)))
	
	# Block the middle diagonal (2,2)
	_nav_manager.set_point_solid(Vector2i(2, 2), true)
	
	var path = _nav_manager.get_astar_path(start_pos, end_pos)
	
	assert_gt(path.size(), 0, "Should find a path around the wall")
	
	var wall_center = _nav_manager.snap_to_grid_center(_nav_manager._grid_to_world(Vector2i(2, 2)))
	for point in path:
		var dist = point.distance_to(wall_center)
		# Should keep distance (half-width of tile in iso is 32, half-height is 16)
		# We check for at least 20 pixels to be safe
		assert_gt(dist, 20.0, "Path point %s is inside or too close to the solid wall!" % point)

	# If we smoothed perfectly through a wall, size would be 2. Since wall exists, it must be > 2.
	assert_gt(path.size(), 2, "Path should have added a corner waypoint to avoid the wall.")
