# res://ui/components/BuildingInfoHUD.gd
extends Control
class_name BuildingInfoHUD

@onready var name_label: Label = $Background/MarginContainer/NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var background: PanelContainer = $Background
@onready var status_icon: TextureRect = $StatusIcon

# Store the styleboxes so we can tween colors
var style_fill: StyleBoxFlat

func _ready() -> void:
	# Cache the stylebox for dynamic coloring
	if health_bar.has_theme_stylebox("fill"):
		style_fill = health_bar.get_theme_stylebox("fill").duplicate()
		health_bar.add_theme_stylebox_override("fill", style_fill)
	
	hide_progress()

func setup(display_name: String, size_pixels: Vector2) -> void:
	name_label.text = display_name
	custom_minimum_size = size_pixels
	size = size_pixels
	# Center the pivot for nice animations
	pivot_offset = size / 2.0
	
	# Adjust background size
	background.custom_minimum_size = size

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	health_bar.show()
	
	# Green for Health
	if style_fill: style_fill.bg_color = Color(0.2, 0.8, 0.2)

func update_construction(current: int, required: int) -> void:
	health_bar.max_value = required
	health_bar.value = current
	health_bar.show()
	
	# Blue for Construction
	if style_fill: style_fill.bg_color = Color(0.2, 0.6, 1.0)
	
	var percent = int((float(current) / required) * 100)
	name_label.text = "Constructing\n%d%%" % percent

func set_blueprint_mode() -> void:
	modulate = Color(1, 1, 1, 0.6) # Ghostly
	name_label.text = "(Blueprint)"
	health_bar.hide()

func set_active_mode(display_name: String) -> void:
	modulate = Color.WHITE
	name_label.text = display_name
	# Health bar usually hides when full in RTS, but for now we keep logic simple
	health_bar.show()

func hide_progress() -> void:
	health_bar.hide()
