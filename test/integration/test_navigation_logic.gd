#res://test/integration/test_navigation_logic.gd
extends GutTest

var _grid: AStarGrid2D
var _nav_manager = NavigationManager 

func before_each():
	# 1. Setup a clean 100x100 Grid
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, 100, 100)
	_grid.cell_size = Vector2(32, 32)
	
	# --- THE FIX: Center the points! ---
	# Without this, points are at Top-Left (0,0).
	# With this, points are at Center (16,16).
	_grid.offset = _grid.cell_size / 2 
	# -----------------------------------
	
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_grid.update()
	
	_nav_manager.register_grid(_grid, self)

func after_each():
	_nav_manager.unregister_grid()
	_grid = null

func test_smoothing_removes_zigzag():
	# Start at (0,0) center -> (16, 16)
	var start_pos = Vector2(16, 16) 
	# End at (10,10) center -> (336, 336)
	var end_pos = Vector2(336, 336) 
	
	var path = _nav_manager.get_astar_path(start_pos, end_pos)
	
	assert_gt(path.size(), 0, "Path should not be empty")
	
	# Verify String Pulling (Should be 2 points for a straight diagonal)
	assert_lt(path.size(), 5, "Path should be smoothed! Zig-zag detected if size > 5. Actual: %s" % path.size())
	
	# Verify Start
	assert_eq(path[0], start_pos, "Path must start at origin")
	
	# Verify End
	# Now that the grid is offset, the last point should match our centered target
	var last_point = path[path.size() - 1]
	assert_almost_eq(last_point.distance_to(end_pos), 0.0, 1.0, "Path must end at target")

func test_start_position_precision_fix():
	# Start at (5,5) (Top-left of first tile)
	var exact_unit_pos = Vector2(5, 5)
	var target_pos = Vector2(100, 100)
	
	var path = _nav_manager.get_astar_path(exact_unit_pos, target_pos)
	
	assert_gt(path.size(), 0)
	assert_eq(path[0], exact_unit_pos, "Path start point must match Unit Position, NOT Grid Center.")

func test_obstacle_avoidance_with_smoothing():
	var start_pos = Vector2(16, 16)   # 0,0
	var end_pos = Vector2(80, 80)     # 2,2
	
	# Block the middle diagonal (1,1)
	_grid.set_point_solid(Vector2i(1, 1), true)
	
	var path = _nav_manager.get_astar_path(start_pos, end_pos)
	
	assert_gt(path.size(), 0, "Should find a path around the wall")
	
	var wall_center = Vector2(48, 48) # Center of 1,1
	for point in path:
		var dist = point.distance_to(wall_center)
		# Should keep distance (radius 16)
		assert_gt(dist, 16.0, "Path point %s is inside the solid wall!" % point)

	# If we smoothed perfectly through a wall, size would be 2. Since wall exists, it must be > 2.
	assert_gt(path.size(), 2, "Path should have added a corner waypoint to avoid the wall.")

func test_out_of_bounds_handling():
	var start = Vector2(16, 16)
	var waaaay_out = Vector2(99999, 99999)
	
	var path = _nav_manager.get_astar_path(start, waaaay_out)
	
	assert_gt(path.size(), 0, "Should clamp target and return valid path")
	
	var last_point = path[path.size() - 1]
	# Max bounds is 100 * 32 = 3200 + offset 16 = 3216
	# We allow a little tolerance
	assert_lt(last_point.x, 3250.0, "Target should be clamped within bounds")
