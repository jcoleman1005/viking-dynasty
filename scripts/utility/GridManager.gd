# res://scripts/utility/GridManager.gd
#
# Manages the AStarGrid2D and the Territory System (Flood Fill).
# --- MODIFIED: Phase 3.1 Territory Logic ---

extends Node

@export_group("Grid Configuration")
@export var grid_width: int = 60
@export var grid_height: int = 40
@export var cell_size: int = 32

var astar_grid: AStarGrid2D

# Phase 3: Territory Tracking
# Dictionary { Vector2i: true } containing all cells where players can build.
var buildable_cells: Dictionary = {}

func _ready() -> void:
	astar_grid = AStarGrid2D.new()
	var playable_rect := Rect2i(0, 0, grid_width, grid_height)
	astar_grid.region = playable_rect
	astar_grid.cell_size = Vector2(cell_size, cell_size)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()
	
	Loggie.msg("GridManager: Local grid initialized: %dx%d cells" % [grid_width, grid_height]).domain("BUILDING").info()


func recalculate_territory(placed_buildings: Array) -> void:
	"""
	Recalculates territory using a 'Wireless' propagation model.
	1. Hubs generate territory naturally.
	2. Connectors (Walls) extend territory if they are INSIDE an existing territory.
	3. This allows daisy-chaining without physical contact.
	"""
	buildable_cells.clear()
	
	# 1. Sort buildings into Hubs (Sources) and Connectors (Extenders)
	var active_sources: Array[Dictionary] = []
	var candidate_connectors: Array[Dictionary] = []
	
	for entry in placed_buildings:
		var pos = entry["grid_position"]
		# Normalize to Vector2
		var grid_pos = Vector2(pos.x, pos.y) if pos is Vector2i else pos
		
		var data = load(entry["resource_path"]) as BuildingData
		if not data: continue
		
		# Calculate center point for distance checks
		var center_pos = grid_pos + (Vector2(data.grid_size) / 2.0)
		
		var info = {
			"grid_pos": Vector2i(grid_pos),
			"center": center_pos,
			"data": data,
			"radius": data.territory_radius
		}
		
		if data.is_territory_hub:
			active_sources.append(info)
		elif data.extends_territory:
			candidate_connectors.append(info)

	# 2. Iterative Propagation (Daisy-Chaining)
	# We loop until we stop finding new powered connectors.
	var new_connection_found = true
	
	while new_connection_found:
		new_connection_found = false
		var next_candidates: Array[Dictionary] = []
		
		for connector in candidate_connectors:
			var is_powered = false
			
			# Check if this connector is inside the range of ANY active source
			for source in active_sources:
				var distance = source["center"].distance_to(connector["center"])
				# Use a forgiving check: if distance <= source radius + small buffer
				# We check if the connector is essentially "covered" by the source
				if distance <= source["radius"]:
					is_powered = true
					break
			
			if is_powered:
				active_sources.append(connector)
				new_connection_found = true
			else:
				next_candidates.append(connector)
		
		# Shrink the list of candidates to only those who haven't powered on yet
		candidate_connectors = next_candidates

	# 3. Rasterize (Draw) the Territory
	# Now that we know which buildings are active, apply their radius to the grid.
	for source in active_sources:
		_apply_territory_to_grid(source)

	Loggie.msg("GridManager: Territory recalculated (Wireless). %d valid build tiles." % buildable_cells.size()).domain("BUILDING").info()
	
	# Force visualizer update
	queue_redraw_visualizer()

func _apply_territory_to_grid(source_info: Dictionary) -> void:
	var center = Vector2i(source_info["grid_pos"]) + (source_info["data"].grid_size / 2)
	var r = source_info["radius"]
	
	# Draw a square radius (matches standard RTS logic best)
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var cell = center + Vector2i(x, y)
			
			# Check bounds
			if cell.x >= 0 and cell.x < grid_width and \
			   cell.y >= 0 and cell.y < grid_height:
				buildable_cells[cell] = true


func queue_redraw_visualizer() -> void:
	var visualizer = get_parent().get_node_or_null("GridVisualizer")
	if visualizer:
		visualizer.queue_redraw()

func is_cell_buildable(grid_pos: Vector2i) -> bool:
	return buildable_cells.has(grid_pos)
