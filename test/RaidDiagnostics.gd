# res://test/RaidDiagnostics.gd
extends Node

## Standalone diagnostic script for RaidSandbox coordinate and visibility analysis.
## Answers 5 key questions about the simulation environment.

var raid_mission: Node2D = null
var building_container: Node2D = null
var tilemap: TileMapLayer = null

func _ready() -> void:
	# Wait for mission to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	raid_mission = get_parent()
	if not raid_mission or not raid_mission.name == "RaidSandbox":
		# Try to find it if we were attached elsewhere
		raid_mission = _find_node_recursive(get_tree().root, "RaidSandbox")
	
	if not raid_mission:
		Loggie.msg("DIAG: Could not find RaidSandbox!").domain("RAID").error()
		return

	_run_diagnostics()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = raid_mission.get_global_mouse_position()
		Loggie.msg("DIAG: Mouse Click at Global Position: %s" % str(mouse_pos)).domain("RAID").warn()

func _run_diagnostics() -> void:
	Loggie.msg("--- RAID COORDINATE DIAGNOSTICS ---").domain("RAID").warn()
	
	# 1. TileMap Corners (Calculated)
	# Grid is 60x60, TILE_HALF_SIZE is (32, 16)
	# Formula: x = (grid_x - grid_y) * 32, y = (grid_x + grid_y) * 16
	var corners = {
		"TOP (0,0)": Vector2(0, 0),
		"RIGHT (60,0)": Vector2(60 * 32, 60 * 16),
		"BOTTOM (60,60)": Vector2(0, 120 * 16),
		"LEFT (0,60)": Vector2(-60 * 32, 60 * 16)
	}
	Loggie.msg("1. CALCULATED TILEMAP CORNERS (Diamond Bounds):").domain("RAID").info()
	for key in corners:
		Loggie.msg("   %s: %s" % [key, str(corners[key])]).domain("RAID").info()

	# 2. Hall Spawn Position
	var hall_node = null
	building_container = raid_mission.get_node_or_null("RaidMission/BuildingContainer")
	if building_container:
		for child in building_container.get_children():
			if "Hall" in child.name or (child.get("data") and "Hall" in child.data.display_name):
				hall_node = child
				break
	
	if hall_node:
		Loggie.msg("2. Hall spawned at: %s (Global: %s)" % [str(hall_node.position), str(hall_node.global_position)]).domain("RAID").info()
	else:
		Loggie.msg("2. Hall NOT FOUND in BuildingContainer!").domain("RAID").error()

	# 3. Villager Spawn Positions
	var villagers = get_tree().get_nodes_in_group("civilians")
	Loggie.msg("3. Villager Spawn Positions (found %d):" % villagers.size()).domain("RAID").info()
	for i in range(min(villagers.size(), 5)):
		var v = villagers[i]
		Loggie.msg("   Villager %d: %s" % [i, str(v.global_position)]).domain("RAID").info()

	# 4. Visibility Check
	var building_count = building_container.get_child_count() if building_container else 0
	Loggie.msg("4. Map Visibility:").domain("RAID").info()
	Loggie.msg("   Total Buildings in Container: %d" % building_count).domain("RAID").info()
	if building_count > 0:
		var first_b = building_container.get_child(0)
		Loggie.msg("   Example Building (%s) visible: %s, position: %s" % [first_b.name, str(first_b.visible), str(first_b.global_position)]).domain("RAID").info()
	else:
		Loggie.msg("   MAP IS EMPTY (No buildings found in container)").domain("RAID").warn()

	# 5. TileMapLayer Transform
	tilemap = _find_node_recursive(raid_mission, "TileMapLayer")
	if tilemap:
		Loggie.msg("5. TileMapLayer Metadata:").domain("RAID").info()
		Loggie.msg("   Position: %s" % str(tilemap.position)).domain("RAID").info()
		Loggie.msg("   Global Position: %s" % str(tilemap.global_position)).domain("RAID").info()
		Loggie.msg("   Scale: %s" % str(tilemap.scale)).domain("RAID").info()
	else:
		Loggie.msg("5. TileMapLayer NOT FOUND in scene tree!").domain("RAID").error()

	Loggie.msg("--- DIAGNOSTICS COMPLETE ---").domain("RAID").warn()
	Loggie.msg("TIP: Click anywhere on the map to log its coordinates.").domain("RAID").info()

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	return null
