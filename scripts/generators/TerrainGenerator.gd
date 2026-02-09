#res://scripts/generators/TerrainGenerator.gd
class_name TerrainGenerator
extends RefCounted

const TERRAIN_SET_ID = 0 
const TERRAIN_BEACH = 0
const TERRAIN_SHALLOW = 1
const TERRAIN_DEEP = 2
const TERRAIN_GRASS = 3

# Map Settings (60x60)
const LEVEL_BEACH_START = 50   # Land goes much further down now
const LEVEL_SHALLOW_START = 55
const LEVEL_DEEP_START = 58

static func generate_base_terrain(tile_layer: TileMapLayer, width: int, height: int, map_seed: int) -> void:
	if not tile_layer: return
	tile_layer.clear()
	
	var rng = RandomNumberGenerator.new()
	if map_seed == 0: rng.randomize()
	else: rng.seed = map_seed
	
	print("TerrainGenerator: Carving Fjord with Seed: %d" % rng.seed)
	
	# 1. Prepare Arrays
	# We use a Dictionary for fast lookups: cells[Vector2i(x,y)] = TERRAIN_TYPE
	# This lets us overwrite "Grass" with "Water" easily before painting.
	var terrain_map = {}
	
	# 2. Fill Base Gradient (Mostly Land)
	for x in range(-5, width + 5): # Add buffer for autotiler
		for y in range(-5, height + 5):
			var grid_pos = Vector2i(x, y)
			
			# Base horizontal noise
			var noise = rng.randi_range(-1, 1)
			var effective_y = y + noise
			
			if effective_y >= LEVEL_DEEP_START:
				terrain_map[grid_pos] = TERRAIN_DEEP
			elif effective_y >= LEVEL_SHALLOW_START:
				terrain_map[grid_pos] = TERRAIN_SHALLOW
			elif effective_y >= LEVEL_BEACH_START:
				terrain_map[grid_pos] = TERRAIN_BEACH
			else:
				terrain_map[grid_pos] = TERRAIN_GRASS

	# 3. CARVE THE FJORD
	# We pass the dictionary by reference to modify it
	_carve_fjord(terrain_map, width, height, rng)
	
	# 4. Convert Dictionary to Arrays for Godot
	var cells_grass: Array[Vector2i] = []
	var cells_beach: Array[Vector2i] = []
	var cells_shallow: Array[Vector2i] = []
	var cells_deep: Array[Vector2i] = []
	
	for pos in terrain_map:
		var type = terrain_map[pos]
		match type:
			TERRAIN_GRASS: cells_grass.append(pos)
			TERRAIN_BEACH: cells_beach.append(pos)
			TERRAIN_SHALLOW: cells_shallow.append(pos)
			TERRAIN_DEEP: cells_deep.append(pos)
			
	# 5. Paint
	tile_layer.set_cells_terrain_connect(cells_deep, TERRAIN_SET_ID, TERRAIN_DEEP, false)
	tile_layer.set_cells_terrain_connect(cells_shallow, TERRAIN_SET_ID, TERRAIN_SHALLOW, false)
	tile_layer.set_cells_terrain_connect(cells_beach, TERRAIN_SET_ID, TERRAIN_BEACH, false)
	tile_layer.set_cells_terrain_connect(cells_grass, TERRAIN_SET_ID, TERRAIN_GRASS, false)

# --- THE FJORD LOGIC ---
static func _carve_fjord(terrain_map: Dictionary, width: int, height: int, rng: RandomNumberGenerator) -> void:
	# 1. Start at the bottom center-ish
	var current_x = rng.randi_range(20, 40) # Middle of map
	var current_y = height + 2 # Start off-screen at bottom
	
	# 2. Decide how far up it goes (Stop at row 15, keeping top area safe for base)
	var end_y = rng.randi_range(10, 20)
	
	# 3. Walk the path
	while current_y > end_y:
		# Wiggle the path left/right
		current_x += rng.randi_range(-2, 2)
		current_x = clampi(current_x, 10, width - 10) # Keep in bounds
		
		# Move Up
		current_y -= 1
		
		# Determine Width (Wider at bottom, narrow at top)
		var progress = float(current_y) / float(height) # 0.0 (top) to 1.0 (bottom)
		var fjord_width = int(lerp(2.0, 8.0, progress)) # 2 tiles wide at tip, 8 at mouth
		
		# 4. Dig the hole (Circle Brush)
		for x in range(current_x - fjord_width, current_x + fjord_width):
			for y in range(current_y - 1, current_y + 2): # Slight vertical brush
				var pos = Vector2i(x, y)
				
				# Check distance to center of river (make it round)
				if Vector2(x, y).distance_to(Vector2(current_x, current_y)) <= fjord_width:
					# Force Deep Water
					terrain_map[pos] = TERRAIN_DEEP
					
					# Add Coastline (optional: turn neighbors into Beach)
					_add_coastline_around(terrain_map, pos)

static func _add_coastline_around(terrain_map: Dictionary, water_pos: Vector2i) -> void:
	# Look at neighbors
	var neighbors = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)
	]
	
	for n in neighbors:
		var check_pos = water_pos + n
		if terrain_map.has(check_pos):
			# If the neighbor is GRASS, turn it into BEACH or SHALLOW
			# This prevents "Grass touching Deep Water" directly
			if terrain_map[check_pos] == TERRAIN_GRASS:
				terrain_map[check_pos] = TERRAIN_BEACH
