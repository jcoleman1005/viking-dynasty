# res://autoload/SettlementManager.gd
#
# A global Singleton (Autoload) responsible for managing the
# "Settlement" or "Defensive" layer of the game.
#
# Its primary jobs are:
# 1. Managing the AStarGrid2D for pathfinding.
# 2. Handling the placement (instancing) of buildings.
#
# GDD Ref: 7.C.2


extends Node

# This is no longer an @onready var. It's now just a
# class variable that will hold our AStarGrid2D *object*.
var astar_grid: AStarGrid2D

# This node is still in the scene, so @onready is correct.
@onready var building_container: Node2D = $BuildingContainer

# Grid constants, as specified in the GDD
const TILE_SIZE: int = 32 # 32x32 pixel tiles
const GRID_WIDTH: int = 50 # 50 tiles wide
const GRID_HEIGHT: int = 30 # 30 tiles high

func _ready() -> void:
	# Here we create the AStarGrid2D object in code.
	astar_grid = AStarGrid2D.new()
	
	# Connect to the global signal.
	EventBus.build_request_made.connect(place_building, CONNECT_DEFERRED)
	
	_initialize_grid()

func _exit_tree() -> void:
	# Always disconnect signals on exit to prevent errors.
	if EventBus.is_connected("build_request_made", place_building):
		EventBus.build_request_made.disconnect(place_building)


# GDD Ref: 7.C.2.a
func _initialize_grid() -> void:
	"""
	Sets up the AStarGrid2D with the GDD's specified properties.
	"""
	print("Initializing Settlement Grid...")
	
	# 1. Define the playable area
	var playable_rect := Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.region = playable_rect
	
	# 2. Set grid properties
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER # No diagonal movement
	
	# 3. This calculates all the grid points.
	astar_grid.update()
	print("Settlement Grid Initialized: %d x %d" % [GRID_WIDTH, GRID_HEIGHT])


# GDD Ref: 7.C.2.b
func place_building(building_data: BuildingData, grid_position: Vector2i) -> void:
	"""
	Handles a request to place a building on the grid.
	"""
	if not building_data or not building_data.scene_to_spawn:
		push_error("Build request failed: BuildingData or scene_to_spawn is null.")
		return

	# TODO: Check if position is valid (e.g., inside grid, not occupied)
	# TODO: Check if player has enough resources

	print("Placing '%s' at grid position %s" % [building_data.display_name, grid_position])
	
	# Instantiate the building scene
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	
	# Set its data resource
	new_building.data = building_data
	
	# We must manually convert the 'grid_position' (Vector2i)
	# to a 'Vector2' before multiplying by 'cell_size' (Vector2).
	var world_pos_top_left: Vector2 = Vector2(grid_position) * astar_grid.cell_size
	var half_cell_offset: Vector2 = astar_grid.cell_size / 2.0
	new_building.global_position = world_pos_top_left + half_cell_offset
	
	# Add it to the building container
	building_container.add_child(new_building)
	
	# If the building blocks pathfinding, update the A* grid
	if building_data.blocks_pathfinding:
		astar_grid.set_point_solid(grid_position, true)
		astar_grid.update()
		print("Updated A* grid. Point %s is now solid." % grid_position)


func get_astar_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	"""
	Public function for other systems (like AI) to get a path.
	Converts world positions to grid IDs and returns a path.
	"""
	# Convert world coordinates (pixels) to grid coordinates (cells)
	var start_id: Vector2i = Vector2i(start_pos / astar_grid.cell_size)
	var end_id: Vector2i = Vector2i(end_pos / astar_grid.cell_size)
	
	# --- MODIFIED ---
	# We will use get_point_path() instead of get_id_path().
	# This directly returns a PackedVector2Array of world-space
	# coordinates, which is simpler and avoids the type error.
	var world_path: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
		
	return world_path
