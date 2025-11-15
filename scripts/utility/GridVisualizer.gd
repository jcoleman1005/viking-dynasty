# res://scripts/utility/GridVisualizer.gd
class_name GridVisualizer
extends Node2D

const GRID_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.05)
const SOLID_CELL_COLOR := Color(1.0, 0.0, 0.0, 0.3) # Red for blocked
const TERRITORY_COLOR := Color(0.0, 1.0, 0.0, 0.1) # Light Green for territory

# --- NEW: Border Settings ---
@export_group("Border Settings")
@export var show_border: bool = true
# ----------------------------

# Configuration populated in _ready()
var grid_width: int = 0
var grid_height: int = 0
var cell_size: int = 0
var astar_grid: AStarGrid2D = null
var grid_manager: Node = null

# --- NEW: Node Reference ---
@onready var reference_rect: ReferenceRect = get_node_or_null("ReferenceRect")

func _ready() -> void:
	grid_manager = get_parent().get_node_or_null("GridManager")
	if not grid_manager:
		queue_free()
		return

	grid_width = grid_manager.grid_width
	grid_height = grid_manager.grid_height
	cell_size = grid_manager.cell_size
	
	if "astar_grid" in grid_manager:
		astar_grid = grid_manager.astar_grid
	
	# --- NEW: Sync ReferenceRect ---
	if reference_rect:
		var total_width = grid_width * cell_size
		var total_height = grid_height * cell_size
		reference_rect.size = Vector2(total_width, total_height)
		reference_rect.position = Vector2.ZERO
		reference_rect.visible = show_border
	# -------------------------------

	EventBus.pathfinding_grid_updated.connect(_on_pathfinding_grid_updated)
	
	set_process_mode(Node.PROCESS_MODE_ALWAYS) # Draw even when paused
	queue_redraw()

func _exit_tree() -> void:
	if EventBus.is_connected("pathfinding_grid_updated", _on_pathfinding_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_pathfinding_grid_updated)

func _draw() -> void:
	if cell_size <= 0: return

	# --- 1. Draw Territory (Green) ---
	if grid_manager and "buildable_cells" in grid_manager:
		var buildable = grid_manager.buildable_cells
		for cell in buildable:
			var rect = Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size)
			draw_rect(rect, TERRITORY_COLOR)

	# Calculate Map Dimensions
	var map_width = grid_width * cell_size
	var map_height = grid_height * cell_size

	# --- 2. Draw Grid Lines ---
	for i in range(grid_height + 1):
		var y = float(i) * cell_size
		draw_line(Vector2(0, y), Vector2(map_width, y), GRID_LINE_COLOR, 1.0)

	for j in range(grid_width + 1):
		var x = float(j) * cell_size
		draw_line(Vector2(x, 0), Vector2(x, map_height), GRID_LINE_COLOR, 1.0)

	# --- 3. Draw Blocked Cells (Red) ---
	if is_instance_valid(astar_grid):
		var cell_draw_size = cell_size * 0.6
		var cell_offset = cell_size * 0.2
		
		for i in range(grid_width):
			for j in range(grid_height):
				if astar_grid.is_point_solid(Vector2i(i, j)):
					var rect_top_left = Vector2(float(i * cell_size) + cell_offset, float(j * cell_size) + cell_offset)
					draw_rect(Rect2(rect_top_left, Vector2(cell_draw_size, cell_draw_size)), SOLID_CELL_COLOR)

func _on_pathfinding_grid_updated(_grid_position: Vector2i) -> void:
	queue_redraw()
