extends GutTest

# --- Mock Building Class ---
# [FIX] Must extend BaseBuilding to satisfy the return type contract.
class MockBuilding extends BaseBuilding:
	# We override _ready to stop the REAL BaseBuilding logic from running
	# and crashing because it can't find dependencies.
	func _ready():
		pass
		
	# We override set_state to do nothing, just in case.
	func set_state(_val): 
		pass

var _manager_ref
var _container

func before_all():
	# 1. Setup SettlementManager
	if has_node("/root/SettlementManager"):
		_manager_ref = get_node("/root/SettlementManager")
	else:
		_manager_ref = load("res://autoload/SettlementManager.gd").new()
		add_child_autofree(_manager_ref)
		_manager_ref._ready()
	
	# 2. Setup a Dummy Scene Container
	_container = Node2D.new()
	add_child_autofree(_container)
	_manager_ref.register_active_scene_nodes(_container)

func test_building_visual_alignment():
	# --- SETUP ---
	var mock_data = BuildingData.new()
	mock_data.grid_size = Vector2i(1, 1) # 1x1 Building
	mock_data.resource_path = "res://data/buildings/mock_hall.tres"
	
	# --- Create Mock Scene ---
	var mock_node = MockBuilding.new()
	
	var dummy_scene = PackedScene.new()
	dummy_scene.pack(mock_node)
	mock_data.scene_to_spawn = dummy_scene
	
	mock_node.free()
	
	# --- ACTION ---
	# Place at (5, 5).
	var target_grid = Vector2i(5, 5)
	
	# This instantiates MockBuilding (which is now a valid BaseBuilding subtype)
	var building_instance = _manager_ref.place_building(mock_data, target_grid)
	
	# --- ASSERTION ---
	var actual_pos = building_instance.global_position
	
	# Expected ISOMETRIC Position for (5,5) 1x1
	# X = 0, Y = 160 (Top) + 16 (Half Height) = 176
	var expected_x = 0.0
	var expected_y = 176.0 
	
	assert_almost_eq(actual_pos.x, expected_x, 1.0, 
		"X Position Mismatch! Got %s, Expected %s. (Using Orthogonal logic?)" % [actual_pos.x, expected_x])
		
	assert_almost_eq(actual_pos.y, expected_y, 1.0, 
		"Y Position Mismatch! Got %s, Expected %s." % [actual_pos.y, expected_y])

func after_all():
	if is_instance_valid(_manager_ref):
		_manager_ref.unregister_active_scene_nodes()
