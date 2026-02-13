class_name SeasonalCard_UI
extends Control

## Individual Winter Court Card UI
## Handles visual representation and selection of seasonal choices.
## Implements Universal Input Handling for robust hover effects.

signal card_clicked(card_data: SeasonalCardResource)
signal card_denied(card_data: SeasonalCardResource, reason: String)
signal card_hovered(card_data: SeasonalCardResource)
signal card_exited()

@onready var select_button: Button = %SelectButton
@onready var title_label: Label = %TitleLabel 
@onready var description_label: Label = %DescriptionLabel
@onready var cost_label: Label = %CostLabel 

var _card_data: SeasonalCardResource
var _can_afford: bool = true
var _is_hovered: bool = false

func _ready() -> void:
	# 1. Connect the Button (for Clicks & Pass-through)
	if select_button:
		if not select_button.pressed.is_connected(_on_button_pressed):
			select_button.pressed.connect(_on_button_pressed)
		
		# CRITICAL: Allow mouse events to pass through the button to the Control root
		select_button.mouse_filter = Control.MOUSE_FILTER_PASS

	# 2. Connect the Root Control (For Universal Hover)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# 3. Ensure Pivot is Centered for Scaling
	call_deferred("_update_pivot")
	if not resized.is_connected(_update_pivot):
		resized.connect(_update_pivot)

func _update_pivot() -> void:
	pivot_offset = size / 2.0

func setup(card: SeasonalCardResource, can_afford: bool = true, denial_reason: String = "") -> void:
	_card_data = card
	_can_afford = can_afford
	
	# 1. Set Text Content
	if title_label: title_label.text = card.display_name
	if description_label: description_label.text = card.description
	
	# 2. Build Cost String
	var cost_text = ""
	if card.cost_ap > 0: cost_text += "%d AP " % card.cost_ap
	if card.cost_gold > 0: cost_text += "%d Gold " % card.cost_gold
	if card.cost_food > 0: cost_text += "%d Food " % card.cost_food
	
	if cost_text.is_empty():
		cost_text = "Free"
	
	# 3. Configure Button & Labels
	if select_button:
		select_button.disabled = false 
	
	if cost_label:
		cost_label.text = cost_text
		if not can_afford:
			cost_label.add_theme_color_override("font_color", Color.TOMATO)
		else:
			cost_label.remove_theme_color_override("font_color")
	
	# 4. Apply Visual State (Affordability)
	if not can_afford:
		modulate = Color(0.5, 0.5, 0.5, 0.9)
		tooltip_text = denial_reason # Set tooltip for greayed out cards
	else:
		modulate = Color.WHITE
		tooltip_text = ""

func _on_button_pressed() -> void:
	if not _card_data: return
	
	if _can_afford:
		card_clicked.emit(_card_data)
	else:
		_play_error_animation()
		card_denied.emit(_card_data, "Insufficient Resources")

func _play_error_animation() -> void:
	var tween = create_tween()
	var base_x = position.x
	tween.tween_property(self, "position:x", base_x + 5, 0.05)
	tween.tween_property(self, "position:x", base_x - 5, 0.05)
	tween.tween_property(self, "position:x", base_x, 0.05)

# --- HOVER LOGIC ---
func _on_mouse_entered() -> void:
	if _is_hovered: return 
	_is_hovered = true
	
	# Ensure the card renders On Top of neighbors during hover
	z_index = 10 
	
	# Scale Up
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if _card_data:
		card_hovered.emit(_card_data)

func _on_mouse_exited() -> void:
	# FLICKER FIX: Verify the mouse actually left the card's geometry.
	# If the mouse is still inside the Rect, it just entered a child node (like a label).
	# In that case, we ignore the exit signal.
	if get_global_rect().has_point(get_global_mouse_position()):
		return

	_is_hovered = false
	
	# Reset Z-Index
	z_index = 0
	
	# Reset Scale
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	card_exited.emit()
