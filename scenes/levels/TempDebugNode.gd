extends Node2D

# Match your constants EXACTLY
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF = Vector2(32, 16)

func _ready():
	await get_tree().process_frame
	print("\n=== GRID MATH VERIFICATION ===")
	
	# 1. FIND THE MAP
	var map = _find_tilemap()
	if not map:
		print("❌ CRITICAL: No TileMapLayer found to verify against.")
		return

	# 2. CHECK SETTINGS
	print("Map Tile Set: ", map.tile_set.tile_shape) 
	print("EXPECTED: 1 (Isometric)")
	
	# 3. ROUND TRIP TEST (Grid -> World -> Grid)
	# We test a tile far from origin to magnify small errors
	var test_cell = Vector2i(10, 10) 
	
	# A. Ask the Map (The Visual Truth)
	var map_center = map.to_global(map.map_to_local(test_cell))
	
	# B. Ask the Manual Math (The Logical Truth)
	# (x - y) * w/2, (x + y) * h/2 + h/2
	var manual_x = (test_cell.x - test_cell.y) * TILE_HALF.x
	var manual_y = (test_cell.x + test_cell.y) * TILE_HALF.y + TILE_HALF.y
	var manual_center = Vector2(manual_x, manual_y)
	
	# C. Compare
	print("\n--- TEST CELL (10, 10) ---")
	print("Map Says Center is:    ", map_center)
	print("Math Says Center is:   ", manual_center)
	
	var diff = map_center.distance_to(manual_center)
	if diff < 1.0:
		print("✅ MATCH: Visuals and Logic define 'Center' identically.")
	else:
		print("❌ MISMATCH: Visuals and Logic disagree by %s pixels." % diff)
		print("   This causes buildings to float and pathfinding to clip walls.")

	# 4. CLICK TEST (Reverse Logic)
	# Does the Map agree that the center belongs to (10,10)?
	var derived_cell = map.local_to_map(map.to_local(manual_center))
	if derived_cell == test_cell:
		print("✅ REVERSE MATCH: World -> Grid is accurate.")
	else:
		print("❌ REVERSE FAIL: The math location registers as cell %s" % derived_cell)

func _find_tilemap() -> TileMapLayer:
	# Quick scan for the map
	if get_parent() is TileMapLayer: return get_parent()
	for child in get_tree().root.get_children():
		if child is TileMapLayer: return child
		for sub in child.get_children():
			if sub is TileMapLayer: return sub
	return null
