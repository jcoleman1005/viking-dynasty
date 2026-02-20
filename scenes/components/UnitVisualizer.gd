# res://scenes/components/UnitVisualizer.gd
class_name UnitVisualizer
extends Node2D

@export var enabled: bool = true
@export var show_health_bar: bool = true
@export var show_facing_arrow: bool = true
@export var show_selection_ring: bool = true

var unit_data: UnitData
var current_health_ratio: float = 1.0
var is_selected: bool = false
var facing_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	var parent = get_parent()
	if parent and "data" in parent:
		unit_data = parent.data
	
	if parent.has_signal("health_changed"):
		parent.connect("health_changed", _on_health_changed)
	
	# Initial draw
	queue_redraw()

func _process(_delta: float) -> void:
	if not enabled: return
	
	var parent = get_parent()
	if parent:
		# Update facing direction from velocity if moving
		if parent.velocity.length_squared() > 1.0:
			facing_direction = parent.velocity.normalized()
		
		# Update selection state
		if "is_selected" in parent:
			if is_selected != parent.is_selected:
				is_selected = parent.is_selected
				queue_redraw()
		
		# Update health ratio if parent has it
		if "current_health" in parent and unit_data:
			var new_ratio = float(parent.current_health) / float(unit_data.max_health)
			if abs(new_ratio - current_health_ratio) > 0.01:
				current_health_ratio = new_ratio
				queue_redraw()
		
		# Constant redraw if facing changes or always for now to keep it simple
		queue_redraw()

func _draw() -> void:
	if not enabled or not unit_data: return
	
	# 1. Draw Shape
	var r = unit_data.visual_radius
	match unit_data.debug_shape:
		"square":
			draw_rect(Rect2(-r, -r, r * 2, r * 2), unit_data.debug_color)
		"circle":
			draw_circle(Vector2.ZERO, r, unit_data.debug_color)
		"triangle":
			var pts = PackedVector2Array([
				Vector2(0, -r),
				Vector2(r, r),
				Vector2(-r, r)
			])
			draw_colored_polygon(pts, unit_data.debug_color)
		"diamond":
			var pts = PackedVector2Array([
				Vector2(0, -r),
				Vector2(r, 0),
				Vector2(0, r),
				Vector2(-r, 0)
			])
			draw_colored_polygon(pts, unit_data.debug_color)
	
	# 2. Selection Ring
	if is_selected and show_selection_ring:
		draw_arc(Vector2.ZERO, r + 4, 0, TAU, 32, Color.WHITE, 1.5)
	
	# 3. Facing Arrow
	if show_facing_arrow:
		var arrow_len = unit_data.facing_arrow_length
		draw_line(Vector2.ZERO, facing_direction * arrow_len, Color.WHITE, 2.0)
	
	# 4. Health Bar
	if show_health_bar:
		_draw_health_bar()

func _draw_health_bar() -> void:
	var bar_width = unit_data.visual_radius * 2.0
	var bar_height = 4.0
	var bar_pos = Vector2(-bar_width / 2.0, -unit_data.visual_radius - 10.0)
	
	# Background
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color.BLACK)
	
	# Fill
	var fill_color = Color.GREEN.lerp(Color.RED, 1.0 - current_health_ratio)
	draw_rect(Rect2(bar_pos, Vector2(bar_width * current_health_ratio, bar_height)), fill_color)

func _on_health_changed(new_health: int, max_health: int) -> void:
	current_health_ratio = float(new_health) / float(max_health)
	queue_redraw()

func refresh() -> void:
	queue_redraw()
