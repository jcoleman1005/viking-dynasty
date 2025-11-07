# res://scripts/utility/GridManager.gd
#
# A reusable scene that creates and manages an AStarGrid2D object.
# This encapsulates grid logic so scenes like SettlementBridge
# and RaidMission don't have to duplicate code.

extends Node

@export_group("Grid Configuration")
@export var grid_width: int = 60
@export var grid_height: int = 40
@export var cell_size: int = 32

## The AStarGrid2D object this manager creates and configures.
var astar_grid: AStarGrid2D

func _ready() -> void:
	# Create and configure the grid object
	astar_grid = AStarGrid2D.new()
		
	var playable_rect := Rect2i(0, 0, grid_width, grid_height)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(cell_size, cell_size)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	
	print("GridManager: Local grid initialized: %dx%d cells" % [grid_width, grid_height])
