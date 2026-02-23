#res://scenes/missions/RaidMapLoader.gd
class_name RaidMapLoader
extends Node

const GRID_WIDTH = 60
const GRID_HEIGHT = 60

var building_container: Node2D
var last_map_data: Dictionary = {}

@export_group("Procedural Generation")
@export var hall_data: BuildingData
@export var longhouse_data: BuildingData
@export var granary_data: BuildingData
@export var storehouse_data: BuildingData
@export var church_data: BuildingData

func setup(p_container: Node2D, enemy_data: SettlementData) -> void:
	Loggie.msg("[DIAGNOSTIC] RaidMapLoader: Beginning Setup Sequence.").domain("RAID").info()
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
			
		Loggie.msg("[DIAGNOSTIC] RaidMapLoader: Generating Terrain with Seed: %d" % enemy_data.map_seed).domain("RAID").info()
		TerrainGenerator.generate_base_terrain(
			tile_map,
			GRID_WIDTH, 
			GRID_HEIGHT, 
			enemy_data.map_seed
		)
		
		# NEW — procedural village generation
		var generator = CoastalVillageGenerator.new()
		add_child(generator)
		
		# Pass exported data to generator
		generator.hall_data = hall_data
		generator.longhouse_data = longhouse_data
		generator.granary_data = granary_data
		generator.storehouse_data = storehouse_data
		generator.church_data = church_data
		
		var map_data = generator.generate(enemy_data.map_seed)
		
		# Store map_data for RaidMission to consume
		last_map_data = map_data
		
		Loggie.msg("MapLoader: Generation complete. map_data keys=%s" % str(last_map_data.keys())).domain("RAID").info()
		
		# --- Procedural Building Spawning ---
		var buildings = last_map_data.get("buildings", [])
		for i in buildings.size():
			var entry = buildings[i]
			var b_data = entry.get("building_data", null)
			if not b_data:
				Loggie.msg("Building %d missing building_data" % i).domain("RAID").warn()
				continue
			var scene = b_data.scene_to_spawn
			if not scene:
				Loggie.msg("Building %d missing scene_to_spawn" % i).domain("RAID").warn()
				continue
			var building = scene.instantiate()
			building.data = b_data
			building.global_position = entry["position"]
			building_container.add_child(building)
			
			building.collision_layer = 1 | 8
			building.collision_mask = 0
			
			if building.has_node("Hitbox"):
				var hitbox = building.get_node("Hitbox")
				hitbox.collision_layer = 8
				
			buildings[i]["node"] = building
			Loggie.msg("Spawned: %s at %s" % [str(entry.get("type")), str(entry.get("position"))]).domain("RAID").info()
		# ------------------------------------
		
		# [CRITICAL] Register the new map with NavigationManager
		if NavigationManager:
			NavigationManager.register_map(tile_map, Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT))
	else:
		Loggie.msg("RaidMapLoader: Could not find TileMapLayer!").domain("RAID").error()

	Loggie.msg("[DIAGNOSTIC] RaidMapLoader: Setup Complete.").domain("RAID").info()

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
