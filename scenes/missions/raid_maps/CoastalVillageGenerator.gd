# res://scenes/missions/raid_maps/CoastalVillageGenerator.gd
class_name CoastalVillageGenerator
extends Node

@export_group("Map Dimensions")
@export var map_width: float = 3840.0
@export var map_height: float = 1920.0
@export var beach_depth: float = 480.0

@export_group("Building Counts")
@export var building_count_min: int = 8
@export var building_count_max: int = 12
@export var longhouse_count_min: int = 3
@export var longhouse_count_max: int = 4
@export var granary_count_min: int = 2
@export var granary_count_max: int = 3
@export var storehouse_count_min: int = 1
@export var storehouse_count_max: int = 2
@export var church_spawn_chance: float = 0.5

@export_group("Population")
@export var defender_count_min: int = 6
@export var defender_count_max: int = 8
@export var hall_defender_count: int = 3
@export var villager_count_min: int = 4
@export var villager_count_max: int = 6

@export_group("Building Resources")
@export var hall_data: BuildingData
@export var longhouse_data: BuildingData
@export var granary_data: BuildingData
@export var storehouse_data: BuildingData
@export var church_data: BuildingData

func generate(seed_val: int = -1) -> Dictionary:
	if seed_val == -1 or seed_val == 0:
		randomize()
	else:
		seed(seed_val)
	
	var beach_zone = Rect2(0, map_height - beach_depth, map_width, beach_depth)
	var village_zone = Rect2(0, 0, map_width, map_height - beach_depth)
	# Extraction zone centered at bottom of beach
	var extraction_zone = Rect2(map_width * 0.4, map_height - 150, map_width * 0.2, 150) 
	
	var village_center = village_zone.get_center()
	
	var building_placements = _place_buildings(village_zone)
	
	var defender_spawns = []
	var hall_defender_spawns = []
	var villager_spawns = []
	
	# Find hall position
	var hall_pos = village_center
	for b in building_placements:
		if b.type == "Hall":
			hall_pos = b.position
			break
	
	# Defender placement
	for i in range(hall_defender_count):
		var angle = randf() * TAU
		var dist = randf() * 150.0
		hall_defender_spawns.append(hall_pos + Vector2(cos(angle), sin(angle)) * dist)
	
	var num_defenders = randi_range(defender_count_min, defender_count_max)
	for i in range(num_defenders):
		var pos = _sample_village_zone_position(village_zone)
		# Keep away from beach
		while pos.y > village_zone.end.y - 100:
			pos = _sample_village_zone_position(village_zone)
		defender_spawns.append(pos)
		
	# Villager placement
	var num_villagers = randi_range(villager_count_min, villager_count_max)
	var all_defender_spawns = defender_spawns + hall_defender_spawns
	for i in range(num_villagers):
		var attempts = 0
		var pos = _sample_village_zone_position(village_zone)
		while not _is_position_clear(pos, all_defender_spawns, 80.0) and attempts < 20:
			pos = _sample_village_zone_position(village_zone)
			attempts += 1
		villager_spawns.append(pos)

	var fyrd_boundary = []
	# Top edge
	for i in range(10):
		fyrd_boundary.append(Vector2(randf() * map_width, randf() * 200.0))
	# Sides
	for i in range(5):
		fyrd_boundary.append(Vector2(randf() * 200.0, randf() * map_height))
		fyrd_boundary.append(Vector2(map_width - randf() * 200.0, randf() * map_height))

	return {
		"extraction_zone": extraction_zone,
		"buildings": building_placements,
		"defender_spawns": defender_spawns,
		"hall_defender_spawns": hall_defender_spawns,
		"villager_spawns": villager_spawns,
		"fyrd_boundary": fyrd_boundary,
		"navmesh_bounds": village_zone 
	}

func _place_buildings(village_zone: Rect2) -> Array:
	var placements = []
	var centers = []
	
	# 1. Hall
	var hall_pos = village_zone.get_center()
	placements.append({"type": "Hall", "position": hall_pos, "building_data": hall_data})
	centers.append(hall_pos)
	
	# 2. Church
	if randf() < church_spawn_chance:
		var church_pos = hall_pos + Vector2(randf_range(-300, 300), randf_range(-300, 300))
		if _is_position_clear(church_pos, centers, 150.0) and village_zone.has_point(church_pos):
			placements.append({"type": "Church", "position": church_pos, "building_data": church_data})
			centers.append(church_pos)

	# 3. Typed buildings
	var types = [
		{"type": "Longhouse", "data": longhouse_data, "min": longhouse_count_min, "max": longhouse_count_max},
		{"type": "Granary", "data": granary_data, "min": granary_count_min, "max": granary_count_max},
		{"type": "Storehouse", "data": storehouse_data, "min": storehouse_count_min, "max": storehouse_count_max}
	]
	
	for t in types:
		var count = randi_range(t.min, t.max)
		for i in range(count):
			var pos = _sample_village_zone_position(village_zone)
			var attempts = 0
			while not _is_position_clear(pos, centers, 120.0) and attempts < 20:
				pos = _sample_village_zone_position(village_zone)
				attempts += 1
			
			if attempts < 20:
				placements.append({"type": t.type, "position": pos, "building_data": t.data})
				centers.append(pos)
				
	return placements

func _sample_village_zone_position(village_zone: Rect2) -> Vector2:
	return Vector2(
		randf_range(village_zone.position.x + 100, village_zone.end.x - 100),
		randf_range(village_zone.position.y + 100, village_zone.end.y - 100)
	)

func _is_position_clear(pos: Vector2, existing_positions: Array, min_distance: float) -> bool:
	for p in existing_positions:
		if pos.distance_to(p) < min_distance:
			return false
	return true
