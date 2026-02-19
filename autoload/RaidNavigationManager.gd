extends Node

## RaidNavigationManager
## Wraps NavigationServer2D for use during raids only.
## Does not interact with NavigationManager.gd (Settlement AStar).

var navigation_map: RID
var is_raid_active: bool = false

## Called when a raid scene loads.
## Gets the NavigationServer map RID from the NavigationRegion2D in the scene.
func initialize_raid_map(navigation_region: NavigationRegion2D) -> void:
	navigation_map = navigation_region.get_navigation_map()
	is_raid_active = true
	Loggie.msg("RaidNavigationManager: Map initialized.").domain("NAV").info()

## Called when raid scene unloads.
func cleanup_raid_map() -> void:
	is_raid_active = false
	navigation_map = RID()

## Finds a valid spawn position near a target using NavigationServer2D.
## Replaces NavigationManager.request_valid_spawn_point() during raids.
func request_valid_spawn_point(target_pos: Vector2, radius: float = 64.0) -> Vector2:
	if not is_raid_active or not navigation_map.is_valid(): return target_pos
	
	# Safety check: NavigationServer might not have synchronized yet
	if NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
		return target_pos

	# NavigationServer2D.map_get_closest_point returns the closest point on the navmesh.
	var closest = NavigationServer2D.map_get_closest_point(navigation_map, target_pos)
	return closest

## Not used directly — NavigationAgent2D handles path following per unit.
## This is a utility for debug purposes.
func get_next_path_position(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not is_raid_active: return PackedVector2Array()
	
	var query = NavigationPathQueryParameters2D.new()
	query.map = navigation_map
	query.start_position = from
	query.target_position = to
	
	var result = NavigationPathQueryResult2D.new()
	NavigationServer2D.query_path(query, result)
	
	return result.get_path()
