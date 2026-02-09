#res://scripts/utility/UnitPathDrawer.gd
class_name UnitPathDrawer
extends Node2D

# Opt #1: Cache unit references to avoid get_nodes_in_group every frame
var _cached_units: Array[Node] = []
var _cache_timer: float = 0.0

func _ready() -> void:
	# Ensure this doesn't run in editor to save resources
	if Engine.is_editor_hint():
		set_process(false)
		return
	
	_refresh_unit_cache()
	
	# Optional: If you have a signal for units spawning/dying, connect it here
	# EventBus.unit_list_changed.connect(_refresh_unit_cache)

func _process(delta: float) -> void:
	# Periodically refresh cache (every 1 second) if no signals are available
	_cache_timer += delta
	if _cache_timer > 1.0:
		_refresh_unit_cache()
		_cache_timer = 0.0
		
	queue_redraw()

func _refresh_unit_cache() -> void:
	_cached_units = get_tree().get_nodes_in_group("player_units")

func _draw() -> void:
	# Opt #1: Iterate over cached array instead of SceneTree
	for unit in _cached_units:
		if is_instance_valid(unit) and unit.get("fsm"):
			# Check size directly on the PackedVector2Array
			if unit.fsm.path.size() > 0:
				# FIX: Initialize PackedArray with start point, then append the path array
				var points = PackedVector2Array([unit.global_position])
				points.append_array(unit.fsm.path)
				
				if points.size() > 1:
					draw_polyline(points, Color.CYAN, 2.0)
					# Draw destination dot
					draw_circle(unit.fsm.target_position, 4.0, Color.BLUE)
