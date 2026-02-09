#res://ui/seasonal/SummerJobSlider.gd
extends PanelContainer
class_name JobRow_UI

## A generic row for assigning labor.
## Configured via the Inspector (Solution 1).

signal change_requested(amount: int) # +1 or -1

# --- Inspector Configuration ---
@export_group("Configuration")
@export var role_title: String = "Worker":
	set(value):
		role_title = value
		if label_role: label_role.text = value
@export var icon: Texture2D

@export_group("Internal Nodes")
@export var label_role: Label
@export var label_count: Label
@export var btn_minus: Button
@export var btn_plus: Button
@export var icon_rect: TextureRect

# State
var current_count: int = 0
var max_count: int = -1 

func _ready() -> void:
	# Solution 1: Apply the exported title immediately on load
	if label_role:
		label_role.text = role_title
	if icon_rect and icon: 
		icon_rect.texture = icon
	
	_connect_signals()

# Optional setup for dynamic overrides (still available if needed)
func setup(title_override: String, _icon: Texture2D = null) -> void:
	role_title = title_override
	if _icon: icon = _icon
	
	if label_role: label_role.text = role_title
	if icon_rect and icon: icon_rect.texture = icon

func _connect_signals() -> void:
	if btn_plus:
		btn_plus.pressed.connect(func(): change_requested.emit(1))
	if btn_minus:
		btn_minus.pressed.connect(func(): change_requested.emit(-1))

func update_display(count: int, _max: int = -1) -> void:
	current_count = count
	max_count = _max
	
	if label_count:
		label_count.text = str(current_count)
	
	_update_button_states()

func _update_button_states() -> void:
	if btn_minus:
		btn_minus.disabled = (current_count <= 0)
	
	if btn_plus and max_count != -1:
		btn_plus.disabled = (current_count >= max_count)

func set_plus_enabled(enabled: bool) -> void:
	if btn_plus:
		if max_count != -1 and current_count >= max_count:
			btn_plus.disabled = true
		else:
			btn_plus.disabled = !enabled
