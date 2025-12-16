class_name TerrainGenerator
extends RefCounted

# --- CONFIGURATION (Keep your existing constants) ---
const SOURCE_ID = 1  
const TILES_GRASS = [
	Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
	Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6)
]
const TILES_BEACH = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const TILES_WATER = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]
const TRANS_GRASS_TO_BEACH = Vector2i(2, 7)
const TRANS_BEACH_TO_WATER = Vector2i(4, 8) 

const ROW_BEACH_START = 28
const ROW_WATER_START = 34 

# --- UPDATED FUNCTION: Accepts a Seed ---
static func generate_base_terrain(tile_layer: TileMapLayer, width: int, height: int, map_seed: int) -> void:
	if not tile_layer: return
	tile_layer.clear()
	
	# 1. Initialize the Controlled RNG
	var rng = RandomNumberGenerator.new()
	if map_seed == 0:
		rng.randomize() # Generate a fresh one if none exists
	else:
		rng.seed = map_seed # Lock it to the saved seed
		
	print("TerrainGenerator: Painting map with Seed: %d" % rng.seed)
	
	for x in range(width):
		for y in range(height):
			var grid_pos = Vector2i(x, y)
			var tile_to_use = Vector2i(0, 0)
			
			# --- STRIPED LOGIC ---
			if y > ROW_WATER_START:
				# Use rng.randi() % size instead of pick_random()
				var idx = rng.randi() % TILES_WATER.size()
				tile_to_use = TILES_WATER[idx]
				
			elif y == ROW_WATER_START:
				tile_to_use = TRANS_BEACH_TO_WATER
				
			elif y > ROW_BEACH_START:
				var idx = rng.randi() % TILES_BEACH.size()
				tile_to_use = TILES_BEACH[idx]
				
			elif y == ROW_BEACH_START:
				tile_to_use = TRANS_GRASS_TO_BEACH
				
			else:
				var idx = rng.randi() % TILES_GRASS.size()
				tile_to_use = TILES_GRASS[idx]
			
			# --- PAINT ---
			tile_layer.set_cell(grid_pos, SOURCE_ID, tile_to_use, 0)
