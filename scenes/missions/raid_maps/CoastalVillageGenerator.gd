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

func _to_isometric(normalized_pos: Vector2) -> Vector2:
	var u = normalized_pos.x
	var v = normalized_pos.y
	return Vector2(
		(u - v) * 1920.0,
		(u + v) * 960.0
	)

func generate(seed_val: int = -1) -> Dictionary:
	Loggie.msg("Generator: Starting. seed=%d" % seed_val).domain("RAID").info()
	
	if seed_val == -1 or seed_val == 0:
		randomize()
	else:
		seed(seed_val)
	
	# In normalized space, beach = v > 0.75
	var village_center = _to_isometric(Vector2(0.5, 0.35))
	
	# Extraction zone: bottom of diamond
	var ext_center = _to_isometric(Vector2(0.5, 0.9))
	var extraction_zone = Rect2(
		ext_center - Vector2(200, 75),
		Vector2(400, 150)
	)
	
	var building_placements = _place_buildings()
	
	var has_hall = false
	var has_church = false
	for b in building_placements:
		if b.type == "Hall": has_hall = true
		if b.type == "Church": has_church = true
		
	Loggie.msg("Generator: Placed %d buildings. hall=%s church=%s" % [building_placements.size(), str(has_hall), str(has_church)]).domain("RAID").info()
	
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
		var pos = _sample_village_zone_position()
		defender_spawns.append(pos)
		
	# Villager placement
	var num_villagers = randi_range(villager_count_min, villager_count_max)
	var all_defender_spawns = defender_spawns + hall_defender_spawns
	for i in range(num_villagers):
		var attempts = 0
		var pos = _sample_village_zone_position()
		while not _is_position_clear(pos, all_defender_spawns, 80.0) and attempts < 20:
			pos = _sample_village_zone_position()
			attempts += 1
		villager_spawns.append(pos)

	var fyrd_boundary = []
	# Top edge of diamond (low u+v values)
	for i in range(10):
		var u = randf_range(0.05, 0.95)
		var v = randf_range(0.0, 0.08)
		fyrd_boundary.append(_to_isometric(Vector2(u, v)))
	# Left edge
	for i in range(5):
		var v = randf_range(0.1, 0.8)
		fyrd_boundary.append(_to_isometric(Vector2(0.02, v)))
	# Right edge
	for i in range(5):
		var v = randf_range(0.1, 0.8)
		fyrd_boundary.append(_to_isometric(Vector2(0.98, v)))

	var result = {
		"extraction_zone": extraction_zone,
		"buildings": building_placements,
		"defender_spawns": defender_spawns,
		"hall_defender_spawns": hall_defender_spawns,
		"villager_spawns": villager_spawns,
		"fyrd_boundary": fyrd_boundary,
		"navmesh_bounds": Rect2(-1920, 0, 3840, 1920)
	}
	
	Loggie.msg("Generator: Complete. extraction_zone=%s" % str(result.has("extraction_zone"))).domain("RAID").info()
	
	return result

func _place_buildings() -> Array:
	var placements = []
	var centers = []
	
	# 1. Hall
	var hall_pos = _to_isometric(Vector2(0.5, 0.35))
	placements.append({"type": "Hall", "position": hall_pos, "building_data": hall_data})
	centers.append(hall_pos)
	
	# 2. Church
	if randf() < church_spawn_chance:
		var cu = 0.5 + randf_range(-0.1, 0.1)
		var cv = 0.35 + randf_range(-0.1, 0.1)
		var church_pos = _to_isometric(Vector2(cu, cv))
		if _is_position_clear(church_pos, centers, 150.0):
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
			var pos = _sample_village_zone_position()
			var attempts = 0
			while not _is_position_clear(pos, centers, 120.0) and attempts < 20:
				pos = _sample_village_zone_position()
				attempts += 1
			
			if attempts < 20:
				placements.append({"type": t.type, "position": pos, "building_data": t.data})
				centers.append(pos)
				
	return placements

func _sample_village_zone_position(_unused_rect: Rect2 = Rect2()) -> Vector2:
	# Sample in normalized space (0.05..0.95 for margin)
	var u = randf_range(0.05, 0.95)
	var v = randf_range(0.05, 0.7)  # Keep out of bottom 30% (beach)
	return _to_isometric(Vector2(u, v))

func _is_position_clear(pos: Vector2, existing_positions: Array, min_distance: float) -> bool:
	for p in existing_positions:
		if pos.distance_to(p) < min_distance:
			return false
	return true
