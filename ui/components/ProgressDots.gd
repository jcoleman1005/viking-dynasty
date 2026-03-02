# res://ui/components/ProgressDots.gd
# Four-dot progress indicator for the founding sequence.
# Dot states: "pending" (BORDER), "active" (RENOWN), "done" (GOLD_DIM)
class_name ProgressDots
extends HBoxContainer

const COLOR_PENDING := Color("#3d3828")
const COLOR_ACTIVE  := Color("#d4a843")
const COLOR_DONE    := Color("#7a6430")

const DOT_SIZE := Vector2(10, 10)

var _dots: Array[ColorRect] = []


func _ready() -> void:
	_build_dots()


func _build_dots() -> void:
	for child in get_children():
		child.queue_free()
	_dots.clear()

	for i in 4:
		var dot := ColorRect.new()
		dot.custom_minimum_size = DOT_SIZE
		dot.size_flags_horizontal = 0
		dot.color = COLOR_PENDING
		add_child(dot)
		_dots.append(dot)


# Sets dot states based on the current active step (0-indexed).
# Steps before active_index are "done", active_index is "active", rest are "pending".
func set_active_step(active_index: int) -> void:
	for i in _dots.size():
		if i < active_index:
			_dots[i].color = COLOR_DONE
		elif i == active_index:
			_dots[i].color = COLOR_ACTIVE
		else:
			_dots[i].color = COLOR_PENDING


# Marks all dots as done (call when sequence completes).
func set_all_done() -> void:
	for dot in _dots:
		dot.color = COLOR_DONE
