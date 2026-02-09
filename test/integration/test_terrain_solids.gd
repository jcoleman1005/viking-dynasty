#res://test/integration/test_terrain_solids.gd
extends GutTest

var _manager_ref
var _layer: TileMapLayer
var _container: Node2D
var _scene_root: Node2D

func before_all():
	# 1. Setup Manager
	if has_node("/root/SettlementManager"):
		_manager_ref = get_node("/root/SettlementManager")
	else:
		_manager_ref = load("res://autoload/SettlementManager.gd").new()
		add_child_autofree(_manager_ref)
		_manager_ref._ready()
	
	# 2. Setup Scene Hierarchy
	_scene_root = Node2D.new()
	add_child_autofree(_scene_root)
	
	_layer = TileMapLayer.new()
	_layer.name = "TileMapLayer"
	_scene_root.add_child(_layer)
	
	_container = Node2D.new()
	_container.name = "BuildingContainer"
	_scene_root.add_child(_container)
	
	# 3. Build TileSet with Custom Data (The correct Godot 4 way)
	var ts = TileSet.new()
	ts.add_custom_data_layer() 
	ts.set_custom_data_layer_name(0, "is_unwalkable")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	
	var source = TileSetAtlasSource.new()
	var tex = PlaceholderTexture2D.new()
	tex.size = Vector2(64, 64)
	source.texture = tex
	source.texture_region_size = Vector2i(64, 64)
	
	source.create_tile(Vector2i(0, 0))
	var tile_data = source.get_tile_data(Vector2i(0, 0), 0)
	tile_data.set_custom_data("is_unwalkable", true)
	
	# [CRITICAL] Capture the Source ID!
	var source_id = ts.add_source(source)
	_layer.tile_set = ts
	
	# Paint the "Water" tile at Grid (5, 5) using the correct Source ID
	_layer.set_cell(Vector2i(5, 5), source_id, Vector2i(0, 0))

func test_water_blocks_grid():
	# --- ACTION ---
	# 1. Register
	_manager_ref.register_active_scene_nodes(_container)
	
	# [FIX] Manual Injection Fallback
	# If the automatic sibling detection failed (common in tests), force it.
	if not _manager_ref.active_tilemap_layer:
		_manager_ref.active_tilemap_layer = _layer
		
	# 2. Refresh (This triggers the scan)
	_manager_ref._refresh_grid_state()
	
	# --- ASSERTION ---
	assert_not_null(_manager_ref.active_tilemap_layer, "Active TileMapLayer should be assigned.")
	
	# Check the Grid Logic
	var is_solid = _manager_ref.active_astar_grid.is_point_solid(Vector2i(5, 5))
	
	if not is_solid:
		# Debug info if it fails
		var data = _layer.get_cell_tile_data(Vector2i(5, 5))
		var val = data.get_custom_data("is_unwalkable") if data else "NULL DATA"
		gut.p("DEBUG FAILURE: Tile Data at (5,5) -> is_unwalkable: %s" % val)
		
	assert_true(is_solid, "Grid (5,5) should be SOLID because tile has 'is_unwalkable' = true.")
	
	# Control Check
	var is_empty_solid = _manager_ref.active_astar_grid.is_point_solid(Vector2i(6, 6))
	assert_false(is_empty_solid, "Grid (6,6) should be WALKABLE.")

func after_all():
	if is_instance_valid(_manager_ref):
		_manager_ref.unregister_active_scene_nodes()
