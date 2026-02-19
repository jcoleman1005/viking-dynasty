#res://scenes/missions/RaidMapLoader.gd
class_name RaidMapLoader
extends Node

const GRID_WIDTH = 60
const GRID_HEIGHT = 60

var building_container: Node2D

func setup(p_container: Node2D, enemy_data: SettlementData) -> void:
	print("[DIAGNOSTIC] RaidMapLoader: Beginning Setup Sequence.")
	building_container = p_container
	
	# 1. Register Nodes (So Manager knows WHO to scan, but doesn't scan yet)
	SettlementManager.active_map_data = enemy_data
	SettlementManager.register_active_scene_nodes(p_container)
	
	# 2. GENERATE TERRAIN (Critical: Must happen BEFORE grid refresh)
	var root_node = p_container.get_parent() 
	var tile_map = root_node.get_node_or_null("TileMapLayer")
	
	if tile_map:
		if enemy_data.map_seed == 0:
			enemy_data.map_seed = randi()
			
		print("[DIAGNOSTIC] RaidMapLoader: Generating Terrain with Seed: ", enemy_data.map_seed)
		TerrainGenerator.generate_base_terrain(
			tile_map,
			GRID_WIDTH, 
			GRID_HEIGHT, 
			enemy_data.map_seed
		)
		
		# [CRITICAL] Register the new map with NavigationManager
		if NavigationManager:
			NavigationManager.register_map(tile_map, Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT))
	else:
		printerr("RaidMapLoader: Could not find TileMapLayer!")

	print("[DIAGNOSTIC] RaidMapLoader: Setup Complete.")

func load_base(data: SettlementData, is_player_owner: bool) -> BaseBuilding:
	var objective_ref: BaseBuilding = null
	
	for entry in data.placed_buildings:
		var building = _spawn_single_building_visual(entry)
		if building and building.data.is_territory_hub and not is_player_owner:
			objective_ref = building 
			
	return objective_ref

func _spawn_single_building_visual(entry: Dictionary) -> BaseBuilding:
	var res_path = entry["resource_path"]
	var original_pos = Vector2i(entry["grid_position"].x, entry["grid_position"].y)
	
	if not ResourceLoader.exists(res_path): return null
	var b_data = load(res_path) as BuildingData
	if not b_data: return null
	
	# --- NEW: SAFETY CHECK ---
	# Ensure we don't spawn on water.
	var final_grid_pos = original_pos
	if SettlementManager.has_method("get_nearest_valid_spawn_point"):
		final_grid_pos = SettlementManager.get_nearest_valid_spawn_point(original_pos)
	
	if final_grid_pos != original_pos:
		Loggie.msg("RaidMapLoader: Repositioned %s to nearest land." % b_data.display_name).domain(LogDomains.GAMEPLAY).info()
			
	# Update the entry so the data matches the visual reality
	entry["grid_position"] = final_grid_pos
	# -------------------------

	var instance = b_data.scene_to_spawn.instantiate() as BaseBuilding
	instance.data = b_data
	
	# Isometric Positioning (using the new safe Grid Coordinates)
	var center_grid_x = float(final_grid_pos.x) + (float(b_data.grid_size.x) / 2.0)
	var center_grid_y = float(final_grid_pos.y) + (float(b_data.grid_size.y) / 2.0)
	
	var final_x = (center_grid_x - center_grid_y) * SettlementManager.TILE_HALF_SIZE.x
	var final_y = (center_grid_x + center_grid_y) * SettlementManager.TILE_HALF_SIZE.y
	
	instance.global_position = Vector2(final_x, final_y)
	
	building_container.add_child(instance) 
	
	instance.collision_layer = 1 | 8 
	instance.collision_mask = 0 
	
	if instance.has_node("Hitbox"):
		var hitbox = instance.get_node("Hitbox")
		hitbox.collision_layer = 8
		
	return instance
