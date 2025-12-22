class_name RaidMapLoader
extends Node

var building_container: Node2D

# [CHANGED] Setup now takes the enemy data directly
func setup(p_container: Node2D, enemy_data: SettlementData) -> void:
	building_container = p_container
	
	# 1. Take Authority
	SettlementManager.active_map_data = enemy_data
	SettlementManager.register_active_scene_nodes(p_container)
	
	# --- TERRAIN GENERATION (NEW) ---
	# We assume the RaidMission scene has a "TileMapLayer" as a sibling to the BuildingContainer
	var root_node = p_container.get_parent() 
	var tile_map = root_node.get_node_or_null("TileMapLayer")
	
	if tile_map:
		# Safety: Ensure the enemy has a seed. If not, generate one now.
		if enemy_data.map_seed == 0:
			enemy_data.map_seed = randi()
			# Note: We don't save this permanently to disk for temporary raid targets, 
			# but it keeps the map stable for the duration of this mission.
			
		TerrainGenerator.generate_base_terrain(
			tile_map,
			SettlementManager.GRID_WIDTH,  # 60
			SettlementManager.GRID_HEIGHT, # 60
			enemy_data.map_seed
		)
		
		# Optional: Spawn trees/rocks for the raid too!
		# You'll need to reference your ResourceSpawner node here if you added one.
	else:
		printerr("RaidMapLoader: Could not find TileMapLayer in Raid Scene!")
	# -------------------------------
	
	# 2. Refresh Grid for Pathfinding
	SettlementManager._refresh_grid_state()

func load_base(data: SettlementData, is_player_owner: bool) -> BaseBuilding:
	var objective_ref: BaseBuilding = null
	
	# Spawn Placed
	for entry in data.placed_buildings:
		var building = _spawn_single_building_visual(entry)
		if building and building.data.is_territory_hub and not is_player_owner:
			objective_ref = building # Assume Main Hall is hub
			
	return objective_ref

func _spawn_single_building_visual(entry: Dictionary) -> BaseBuilding:
	var res_path = entry["resource_path"]
	var grid_pos = Vector2i(entry["grid_position"].x, entry["grid_position"].y)
	var b_data = load(res_path) as BuildingData
	
	if not b_data: return null
	
	var instance = b_data.scene_to_spawn.instantiate() as BaseBuilding
	
	# [FIX] Assign Data BEFORE adding to tree
	instance.data = b_data
	
	# --- FIX: ISOMETRIC POSITIONING ---
	# 1. Calculate the logical center of the building on the grid
	#    (e.g., A 2x2 building at (0,0) has a center at (1.0, 1.0))
	var center_grid_x = float(grid_pos.x) + (float(b_data.grid_size.x) / 2.0)
	var center_grid_y = float(grid_pos.y) + (float(b_data.grid_size.y) / 2.0)
	
	# 2. Convert Grid Center -> World Pixels (Isometric Formula)
	#    Formula matches SettlementManager.place_building logic
	var final_x = (center_grid_x - center_grid_y) * SettlementManager.TILE_HALF_SIZE.x
	var final_y = (center_grid_x + center_grid_y) * SettlementManager.TILE_HALF_SIZE.y
	
	instance.global_position = Vector2(final_x, final_y)
	# ----------------------------------
	
	building_container.add_child(instance) # Triggers _ready
	
	# [FIX] Force Enemy Collision Layer
	# Layer 1 = Environment, Layer 2 = Player, Layer 4 = Enemy Unit, Layer 8 = Enemy Building
	# We set it to 8 so Player AI (Attack) targets it.
	# We also keep Layer 1 on so it still blocks movement (Pathfinding solids handle logic, this handles physics).
	instance.collision_layer = 1 | 8 
	instance.collision_mask = 0 # Buildings usually don't need to scan for things
	
	# [FIX] Ensure the Hitbox (Area2D) also matches if it exists
	if instance.has_node("Hitbox"):
		var hitbox = instance.get_node("Hitbox")
		hitbox.collision_layer = 8
		
	return instance
