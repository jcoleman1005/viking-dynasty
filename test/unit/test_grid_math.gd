extends GutTestBase

func test_origin_alignment():
	var result = GridUtils.grid_to_iso(Vector2i(0, 0))
	assert_eq(result, Vector2(0, 0), "Origin (0,0) should map to World (0,0)")

func test_step_check():
	# Moving 1 X in grid (Down-Right in Iso)
	# x = (1 - 0) * 32 = 32
	# y = (1 + 0) * 16 = 16
	var result = GridUtils.grid_to_iso(Vector2i(1, 0))
	assert_eq(result, Vector2(32, 16), "Grid(1,0) should map to World(32, 16)")
	
	# Moving 1 Y in grid (Down-Left in Iso)
	# x = (0 - 1) * 32 = -32
	# y = (0 + 1) * 16 = 16
	result = GridUtils.grid_to_iso(Vector2i(0, 1))
	assert_eq(result, Vector2(-32, 16), "Grid(0,1) should map to World(-32, 16)")

func test_round_trip():
	var start_grid = Vector2i(5, 7)
	var world_pos = GridUtils.grid_to_iso(start_grid)
	var end_grid = GridUtils.iso_to_grid(world_pos)
	assert_eq(end_grid, start_grid, "Round trip conversion should match exactly")

func test_snap_to_grid():
	# Pixel perfect center is (32, 16) for (1,0)
	# We test a point slightly off-center: (33, 17)
	var input = Vector2(33, 17)
	var snapped = GridUtils.snap_to_grid(input)
	assert_eq(snapped, Vector2(32, 16), "Should snap 33,17 to the center 32,16")
	
func test_bounds_check():
	var grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 10, 10)
	
	assert_true(GridUtils.is_within_bounds(grid, Vector2i(5, 5)), "5,5 is inside")
	assert_false(GridUtils.is_within_bounds(grid, Vector2i(10, 10)), "10,10 is out of bounds (max is inclusive-exclusive)")
	assert_false(GridUtils.is_within_bounds(grid, Vector2i(-1, 0)), "-1 is out of bounds")
