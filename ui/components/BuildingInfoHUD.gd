#res://ui/components/BuildingInfoHUD.gd
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
	
	# --- NEW: Thin Styling ---
	health_bar.custom_minimum_size.y = 8
	health_bar.size.y = 8
	health_bar.show_percentage = false
	# -------------------------
	
	hide_progress()

func setup(display_name: String, size_pixels: Vector2) -> void:
	name_label.text = display_name
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = size_pixels
	size = size_pixels
	# Center the pivot for nice animations
	pivot_offset = size / 2.0
	
	# Adjust background size
	background.custom_minimum_size = size
	
	# --- NEW: Floating Position ---
	# Position the bar slightly above the building top
	health_bar.position.x = 0
	health_bar.position.y = -15 
	health_bar.size.x = size.x 
	# ------------------------------

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	
	# --- NEW: Smart Visibility ---
	# Only show if damaged
	if current < max_hp:
		health_bar.show()
	else:
		health_bar.hide()
	# -----------------------------
	
	# Green for Health
	if style_fill: style_fill.bg_color = Color(0.2, 0.8, 0.2)

func update_construction(current: int, required: int) -> void:
	health_bar.max_value = required
	health_bar.value = current
	health_bar.show() # Always show during construction
	
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
	# --- FIX: Removed forced show() here. let update_health decide. ---

func hide_progress() -> void:
	health_bar.hide()
