# res://scenes/missions/RaidMapLoader.gd
class_name RaidMapLoader
extends Node

# References needed to build the map
var building_container: Node2D
var grid_manager: Node

func setup(p_container: Node2D, p_grid_manager: Node) -> void:
	building_container = p_container
	grid_manager = p_grid_manager

func load_base(data: SettlementData, is_player_owner: bool) -> BaseBuilding:
	"""
	Loads a settlement layout into the scene.
	Returns the 'Objective Building' (Great Hall) if found.
	"""
	if not data: return null
	
	var objective_ref: BaseBuilding = null
	
	# 1. Load Placed Buildings
	for entry in data.placed_buildings:
		var building = _spawn_single_building(entry, is_player_owner)
		if building:
			if building.data.display_name.to_lower().contains("hall"):
				objective_ref = building

	# 2. Load Blueprints (Only for Player Defense)
	if is_player_owner:
		for entry in data.pending_construction_buildings:
			var building = _spawn_single_building(entry, true)
			if building:
				building.set_state(BaseBuilding.BuildingState.BLUEPRINT)
	
	return objective_ref

func _spawn_single_building(entry: Dictionary, is_player: bool) -> BaseBuilding:
	var res_path = entry["resource_path"]
	var grid_pos = Vector2i(entry["grid_position"])
	
	var b_data = load(res_path) as BuildingData
	if not b_data or not b_data.scene_to_spawn: return null
	
	# Instantiate
	var instance = b_data.scene_to_spawn.instantiate() as BaseBuilding
	instance.data = b_data
	
	# Positioning
	var cell_size = Vector2(32, 32)
	if grid_manager: cell_size = Vector2(grid_manager.cell_size, grid_manager.cell_size)
	
	var world_pos = Vector2(grid_pos) * cell_size
	var center_offset = (Vector2(b_data.grid_size) * cell_size) / 2.0
	instance.global_position = world_pos + center_offset
	
	# Naming & Layers
	if is_player:
		instance.name = b_data.display_name + "_Player"
		# Layer 1 (Environment) for Player buildings
		instance.set_collision_layer(1) 
	else:
		instance.name = b_data.display_name + "_Enemy"
		# Layer 4 (Enemy Buildings) for AI targeting
		instance.add_to_group("enemy_buildings")
		instance.set_collision_layer(1 << 3) 

	instance.set_collision_mask(0) # Static
	
	# Add to Scene
	building_container.add_child(instance)
	
	# Pathfinding Update
	_apply_to_grid(instance, grid_pos)
	
	return instance

func _apply_to_grid(building: BaseBuilding, grid_pos: Vector2i) -> void:
	if not building.data.blocks_pathfinding: return
	
	for x in range(building.data.grid_size.x):
		for y in range(building.data.grid_size.y):
			var cell = grid_pos + Vector2i(x, y)
			# Call the manager to update A*
			SettlementManager.set_astar_point_solid(cell, true)
	
	if grid_manager and "astar_grid" in grid_manager:
		grid_manager.astar_grid.update()
