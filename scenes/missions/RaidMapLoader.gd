class_name RaidMapLoader
extends Node

var building_container: Node2D

# [CHANGED] Setup now takes the enemy data directly
func setup(p_container: Node2D, enemy_data: SettlementData) -> void:
	building_container = p_container
	
	# 1. Take Authority: Tell Manager we are now viewing the Enemy Base
	SettlementManager.active_map_data = enemy_data
	
	# 2. Register container so place_building works
	SettlementManager.register_active_scene_nodes(p_container)
	
	# 3. Force a Refresh: This draws the enemy walls onto the shared AStarGrid
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
	
	var cell_size = SettlementManager.get_active_grid_cell_size()
	var center_offset = (Vector2(b_data.grid_size) * cell_size) / 2.0
	instance.global_position = (Vector2(grid_pos) * cell_size) + center_offset
	
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
