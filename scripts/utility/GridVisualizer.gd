# res://scripts/utility/GridVisualizer.gd
#
# A simple visualizer that draws the AStarGrid lines and solid points
# for debugging purposes in scenes that use the GridManager.
class_name GridVisualizer
extends Node2D

const GRID_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.1) # White, 10% opacity
const SOLID_CELL_COLOR := Color(1.0, 0.0, 0.0, 0.4) # Red, 40% opacity
const LINE_WIDTH := 1.0
const SOLID_CELL_SIZE := 0.6 # Percentage of cell size for the red square

# Configuration populated in _ready()
var grid_width: int = 0
var grid_height: int = 0
var cell_size: int = 0
var astar_grid: AStarGrid2D = null


func _ready() -> void:
	# 1. Find the GridManager in the local scene tree
	var grid_manager = get_parent().get_node_or_null("GridManager")
	if not grid_manager:
		push_error("GridVisualizer: Could not find 'GridManager' child node.")
		queue_free()
		return

	# 2. Get configuration from the GridManager
	grid_width = grid_manager.grid_width
	grid_height = grid_manager.grid_height
	cell_size = grid_manager.cell_size
	
	# 3. Get the AStarGrid2D reference
	if "astar_grid" in grid_manager:
		astar_grid = grid_manager.astar_grid
	else:
		push_error("GridVisualizer: GridManager does not have 'astar_grid' property.")

	# 4. Connect to the event bus to update when the grid pathing changes
	EventBus.pathfinding_grid_updated.connect(_on_pathfinding_grid_updated)
	
	# Tell the engine we will be drawing every frame (only for debugging, turn off in production)
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	set_process(true)
	
	print("GridVisualizer initialized for %dx%d grid with %d cell size." % [grid_width, grid_height, cell_size])


func _exit_tree() -> void:
	if EventBus.is_connected("pathfinding_grid_updated", _on_pathfinding_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_pathfinding_grid_updated)

func _draw() -> void:
	if cell_size <= 0: return

	var map_width = grid_width * cell_size
	var map_height = grid_height * cell_size

	# Draw horizontal lines
	for i in range(grid_height + 1):
		var y = float(i) * cell_size
		draw_line(Vector2(0, y), Vector2(map_width, y), GRID_LINE_COLOR, LINE_WIDTH)

	# Draw vertical lines
	for j in range(grid_width + 1):
		var x = float(j) * cell_size
		draw_line(Vector2(x, 0), Vector2(x, map_height), GRID_LINE_COLOR, LINE_WIDTH)

	# Draw solid cells if AStarGrid is available
	if is_instance_valid(astar_grid) and astar_grid.is_connected:
		_draw_solid_cells()

func _draw_solid_cells() -> void:
	if not is_instance_valid(astar_grid): return

	var cell_draw_size = cell_size * SOLID_CELL_SIZE
	var cell_offset = cell_size * (1.0 - SOLID_CELL_SIZE) * 0.5
	
	for i in range(grid_width):
		for j in range(grid_height):
			var cell_pos = Vector2i(i, j)
			
			if astar_grid.is_point_solid(cell_pos):
				var rect_top_left = Vector2(float(i * cell_size) + cell_offset, float(j * cell_size) + cell_offset)
				var rect_size = Vector2(cell_draw_size, cell_draw_size)
				
				draw_rect(Rect2(rect_top_left, rect_size), SOLID_CELL_COLOR)

func _on_pathfinding_grid_updated(_grid_position: Vector2i) -> void:
	# A building was placed or destroyed, so redraw the grid to show the change.
	queue_redraw()
