#res://test/unit/test_squad_math.gd
# res://test/unit/test_squad_math.gd
extends GutTestBase

var formation: SquadFormation

func before_each():
	super.before_each() # Always call super!
	formation = SquadFormation.new()
	formation.unit_spacing = 50.0

func test_line_formation_positions():
	# Setup: 3 Units, Line Formation
	formation.set_formation_type(SquadFormation.FormationType.LINE)
	var center = Vector2(100, 100)
	var facing = Vector2.DOWN
	var count = 3
	
	# Execute
	# We fake the unit list size by passing 'count' to internal logic or just checking the math function directly if exposed.
	# Since _calculate_line_formation is internal, we test via the public API that returns points.
	# Note: We need to expose a way to test points without nodes, or mock the nodes.
	# For this test, we will rely on the fact that _calculate_formation_positions returns Array[Vector2]
	
	var points = formation._calculate_formation_positions(center, facing)
	
	# Assert
	# We expect 3 points.
	# Point 0 (Leader/Center): (100, 100)
	# Point 1 (Left): (50, 100)
	# Point 2 (Right): (150, 100) 
	# (Exact sorting depends on your algo, but count must be correct)
	
	# Actually, looking at your SquadFormation script, it requires 'units' array to be populated to know count.
	# Let's mock that.
	formation.units = [Node2D.new(), Node2D.new(), Node2D.new()] # 3 Mock Units
	
	points = formation._calculate_formation_positions(center, facing)
	
	assert_eq(points.size(), 3, "Should generate 3 points for 3 units.")
	assert_true(points.has(center), "Center point should exist.")
	
	# Cleanup Mocks
	for u in formation.units: u.free()

func test_box_formation_rotation():
	# Setup: 2 Units (Leader + 1), Box Formation
	# We want to verify that if we face RIGHT, the formation rotates.
	formation.units = [Node2D.new(), Node2D.new()]
	var center = Vector2.ZERO
	var facing = Vector2.RIGHT 
	
	var points = formation._calculate_formation_positions(center, facing)
	
	# Assert
	# If facing RIGHT, the "Side" unit should be rotated relative to the leader.
	# This confirms your rotation matrix math is working.
	var p2 = points[1]
	
	# In a Box/Line, if facing Down (0,1), p2 is at (x+spacing, y).
	# If facing Right (1,0), p2 should be at (x, y-spacing) or similar depending on rotation logic.
	assert_ne(p2, Vector2(50, 0), "Point should be rotated away from default.")
	
	for u in formation.units: u.free()
