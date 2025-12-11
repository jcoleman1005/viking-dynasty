class_name GridVisualizer
extends Node2D

const GRID_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.05)
const SOLID_CELL_COLOR := Color(1.0, 0.0, 0.0, 0.3) 
const TERRITORY_COLOR := Color(0.0, 1.0, 0.0, 0.1) 

@export_group("Border Settings")
@export var show_border: bool = true

var cell_size: int = 32
@onready var reference_rect: ReferenceRect = get_node_or_null("ReferenceRect")

func _ready() -> void:
	var grid_width = SettlementManager.GRID_WIDTH
	var grid_height = SettlementManager.GRID_HEIGHT
	var s = SettlementManager.get_active_grid_cell_size()
	cell_size = int(s.x)
	
	# Setup Reference Rect for Editor/Debug
	if reference_rect:
		var grid_w = SettlementManager.GRID_WIDTH
		var grid_h = SettlementManager.GRID_HEIGHT
		reference_rect.size = Vector2(grid_w * cell_size, grid_h * cell_size)
		reference_rect.visible = show_border
		reference_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.pathfinding_grid_updated.connect(_on_grid_updated)
	queue_redraw()

func _exit_tree() -> void:
	if EventBus.pathfinding_grid_updated.is_connected(_on_grid_updated):
		EventBus.pathfinding_grid_updated.disconnect(_on_grid_updated)

func _on_grid_updated(_pos):
	queue_redraw()

func _draw() -> void:
	# 1. Draw Buildable Cells (Territory)
	var buildable = SettlementManager.buildable_cells
	for cell in buildable:
		var rect = Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size)
		draw_rect(rect, TERRITORY_COLOR)

	# 2. Draw Solids (Red)
	var grid = SettlementManager.active_astar_grid
	if grid:
		var region = grid.region
		for x in range(region.position.x, region.end.x):
			for y in range(region.position.y, region.end.y):
				var cell = Vector2i(x, y)
				if grid.is_point_solid(cell):
					var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
					draw_rect(rect, SOLID_CELL_COLOR)
