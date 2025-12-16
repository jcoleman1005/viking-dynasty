class_name RaidMapLoader
extends Node

var building_container: Node2D

# Setup now takes the enemy data directly
func setup(p_container: Node2D, enemy_data: SettlementData) -> void:
	building_container = p_container
	
	# 1. Take Authority: Tell Manager we are now viewing the Enemy Base
	SettlementManager.active_map_data = enemy_data
	
	# 2. Register container so place_building works
	SettlementManager.register_active_scene_nodes(p_container)
	
	# --- TERRAIN GENERATION ---
	# Find the TileMapLayer (Assumes it is a sibling of the container in RaidMission.tscn)
	var parent_node = p_container.get_parent()
	var tile_map = parent_node.get_node_or_null("TileMapLayer")
	
	if tile_map:
		# If this is a fresh raid target with no Seed, generate one now.
		# This ensures the map is random, but stays consistent if we reload this specific raid.
		if enemy_data.map_seed == 0:
			enemy_data.map_seed = randi()
			
		TerrainGenerator.generate_base_terrain(
			tile_map,
			SettlementManager.GRID_WIDTH,
			SettlementManager.GRID_HEIGHT,
			enemy_data.map_seed
		)
	else:
		Loggie.msg("RaidMapLoader: Could not find 'TileMapLayer' to generate terrain.").domain("RAID").warn()
	# --------------------------
	
	# 3. Force a Refresh: This draws the enemy walls onto the shared AStarGrid
	SettlementManager._refresh_grid_state()

func load_base(data: SettlementData, is_player_owner: bool) -> BaseBuilding:
	var objective_ref: BaseBuilding = null
	
	# Spawn Placed Buildings
	for entry in data.placed_buildings:
		var building = _spawn_single_building_visual(entry)
		# Identify the "Boss" building (Great Hall / Monastery)
		if building and building.data.is_territory_hub and not is_player_owner:
			objective_ref = building 
			
	return objective_ref

func _spawn_single_building_visual(entry: Dictionary) -> BaseBuilding:
	var res_path = entry["resource_path"]
	var grid_pos = Vector2i(entry["grid_position"].x, entry["grid_position"].y)
	var b_data = load(res_path) as BuildingData
	
	if not b_data: return null
	
	var instance = b_data.scene_to_spawn.instantiate() as BaseBuilding
	
	# [FIX] Assign Data BEFORE adding to tree
	instance.data = b_data
	instance.grid_coordinate = grid_pos
	
	# --- ISOMETRIC POSITIONING ---
	var origin_pos = SettlementManager.grid_to_world(grid_pos)
	
	# Center the building on its footprint
	var half_size = SettlementManager.TILE_HALF_SIZE
	var size_offset_x = (b_data.grid_size.x - b_data.grid_size.y) * half_size.x * 0.5
	var size_offset_y = (b_data.grid_size.x + b_data.grid_size.y) * half_size.y * 0.5
	
	instance.global_position = origin_pos
	# -----------------------------
	
	building_container.add_child(instance) 
	
	# [FIX] Force Enemy Collision Layer
	instance.collision_layer = 1 | 8 
	instance.collision_mask = 0 
	
	if instance.has_node("Hitbox"):
		var hitbox = instance.get_node("Hitbox")
		hitbox.collision_layer = 8
		
	return instance
