# res://autoload/SettlementManager.gd
#
# Manages the AStarGrid2D object and all building placement.
#
# --- MODIFIED: Emits 'pathfinding_grid_updated' on build ---


extends Node

var astar_grid: AStarGrid2D
@onready var building_container: Node2D = $BuildingContainer

const TILE_SIZE: int = 32
const GRID_WIDTH: int = 50
const GRID_HEIGHT: int = 30

func _ready() -> void:
	astar_grid = AStarGrid2D.new()
	EventBus.build_request_made.connect(place_building, CONNECT_DEFERRED)
	_initialize_grid()

func _exit_tree() -> void:
	if EventBus.is_connected("build_request_made", place_building):
		EventBus.build_request_made.disconnect(place_building)

func _initialize_grid() -> void:
	print("Initializing Settlement Grid...")
	var playable_rect := Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	print("Settlement Grid Initialized: %d x %d" % [GRID_WIDTH, GRID_HEIGHT])

func place_building(building_data: BuildingData, grid_position: Vector2i) -> void:
	if not building_data or not building_data.scene_to_spawn:
		push_error("Build request failed: BuildingData or scene_to_spawn is null.")
		return

	# TODO: Add validation checks here (is_occupied, has_resources, etc.)

	print("Placing '%s' at grid position %s" % [building_data.display_name, grid_position])
	
	var new_building: BaseBuilding = building_data.scene_to_spawn.instantiate()
	new_building.data = building_data
	
	var world_pos_top_left: Vector2 = Vector2(grid_position) * astar_grid.cell_size
	var half_cell_offset: Vector2 = astar_grid.cell_size / 2.0
	new_building.global_position = world_pos_top_left + half_cell_offset
	
	building_container.add_child(new_building)
	
	if building_data.blocks_pathfinding:
		astar_grid.set_point_solid(grid_position, true)
		astar_grid.update()
		print("Updated A* grid. Point %s is now solid." % grid_position)
		
		# --- ADDED ---
		# Tell all listening units that the grid has changed.
		EventBus.pathfinding_grid_updated.emit(grid_position)


func get_astar_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var start_id: Vector2i = Vector2i(start_pos / astar_grid.cell_size)
	var end_id: Vector2i = Vector2i(end_pos / astar_grid.cell_size)
	
	var world_path: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	return world_path
