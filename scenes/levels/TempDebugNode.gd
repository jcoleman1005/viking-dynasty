extends Node

## TempDebugNode - Footprint System Tracing
## Traces signals and state for the gold footprint system.

func _ready() -> void:
	Loggie.msg("=== [FOOTPRINT TRACE V2] STARTING ===").domain(LogDomains.SYSTEM).info()
	_setup_tracers()
	_inspect_loop()

func _setup_tracers() -> void:
	if not EventBus:
		Loggie.msg("[TRACE] FAIL: EventBus missing").domain(LogDomains.SYSTEM).error()
		return

	EventBus.decree_authorized.connect(func(decree):
		var msg = "[TRACE] Event: decree_authorized RECEIVED | ID: %s | Pos: %s | Building: %s" % [decree.decree_id, decree.resolved_grid_pos, decree.building_data.display_name]
		Loggie.msg(msg).domain(LogDomains.SYSTEM).info()
		await get_tree().process_frame
		_inspect_building_cursor()
	)

func _inspect_loop() -> void:
	while true:
		await get_tree().create_timer(5.0).timeout
		_inspect_building_cursor()

func _inspect_building_cursor() -> void:
	var cursor = get_tree().root.find_child("BuildingCursor", true, false)
	if not cursor:
		Loggie.msg("[TRACE] BuildingCursor node NOT FOUND in tree!").domain(LogDomains.SYSTEM).warn()
		return
		
	var tree_dump = _dump_node_recursively(cursor)
	
	var msg = "[TRACE] BuildingCursor Inspection | Visible: %s | Z-Index: %d" % [cursor.visible, cursor.z_index]
	Loggie.msg(msg).domain(LogDomains.SYSTEM).info()
	Loggie.msg("[TRACE] Node Tree Dump:\n" + tree_dump).domain(LogDomains.SYSTEM).info()

func _dump_node_recursively(node: Node, indent: String = "") -> String:
	if not is_instance_valid(node):
		return indent + "[Invalid Node]\n"
		
	var s = indent + "> " + node.name + " (" + node.get_class() + ")"
	var details = []
	if node is CanvasItem:
		details.append("Visible: " + str(node.visible))
	if node is Node2D:
		details.append("Pos: " + str(node.global_position))
	if node is Line2D:
		details.append("Color: " + str(node.default_color))
		details.append("Width: " + str(node.width))
		details.append("Points: " + str(node.points.size()))
		
	if not details.is_empty():
		s += " | " + ", ".join(details)
	s += "\n"
	
	for child in node.get_children():
		s += _dump_node_recursively(child, indent + "  ")
		
	return s
