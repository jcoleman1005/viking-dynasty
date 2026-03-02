# res://ui/components/SpringOathCard.gd
# Individual oath card for the Spring phase.
# Five sections: oath · condition · reward · consequence · confirm button.
# States: idle, hovered, selected, locked.
class_name SpringOathCard
extends PanelContainer

signal card_selected(card_node: SpringOathCard)
signal card_confirmed(card: SpringCardData)

const COLOR_BORDER_DEFAULT  := Color("#3d3828")
const COLOR_BORDER_HOVER    := Color("#7a6430")
const COLOR_BORDER_SELECTED := Color("#d4a843")

enum CardState { IDLE, HOVERED, SELECTED, LOCKED }

var card_data: SpringCardData
var _state: CardState = CardState.IDLE
var _style_normal:  StyleBoxFlat
var _style_hover:   StyleBoxFlat
var _style_select:  StyleBoxFlat

@onready var oath_label:        RichTextLabel = $Inner/OathLabel
@onready var condition_label:   Label         = $Inner/ConditionLabel
@onready var reward_label:      Label         = $Inner/RewardLabel
@onready var consequence_label: Label         = $Inner/ConsequenceLabel
@onready var confirm_btn:       Button        = $Inner/ConfirmBtn


func _ready() -> void:
	_build_styles()
	confirm_btn.visible = false
	confirm_btn.pressed.connect(_on_confirm_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_apply_style(CardState.IDLE)


func setup(card: SpringCardData, jarl: JarlData) -> void:
	card_data = card
	oath_label.text = "[i]%s[/i]" % (card.selected_phrasing if card.selected_phrasing else "(no phrasing)")
	condition_label.text = _fill_template(card.condition_template, card, jarl)
	reward_label.text    = card.reward_mechanical.replace("_", " ")
	consequence_label.text = "If broken: %s" % card.consequence_mechanical.replace("_", " ")


func set_selected(selected: bool) -> void:
	_set_state(CardState.SELECTED if selected else CardState.IDLE)


func lock() -> void:
	_set_state(CardState.LOCKED)


# --- Internal ---

func _fill_template(tmpl: String, card: SpringCardData, jarl: JarlData) -> String:
	var out := tmpl
	out = out.replace("{jarl_name}", jarl.display_name if jarl else "The Jarl")
	out = out.replace("{threshold}", str(card.calculated_threshold))
	return out


func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color("#16140f")
	_style_normal.set_border_width_all(1)
	_style_normal.border_color = COLOR_BORDER_DEFAULT
	_style_normal.set_content_margin_all(12.0)

	_style_hover = _style_normal.duplicate()
	_style_hover.border_color = COLOR_BORDER_HOVER
	_style_hover.set_border_width_all(2)

	_style_select = _style_normal.duplicate()
	_style_select.border_color = COLOR_BORDER_SELECTED
	_style_select.set_border_width_all(2)


func _set_state(new_state: CardState) -> void:
	_state = new_state
	_apply_style(new_state)
	confirm_btn.visible = (new_state == CardState.SELECTED)
	modulate.a = 0.4 if new_state == CardState.LOCKED else 1.0


func _apply_style(s: CardState) -> void:
	match s:
		CardState.IDLE:     add_theme_stylebox_override("panel", _style_normal)
		CardState.HOVERED:  add_theme_stylebox_override("panel", _style_hover)
		CardState.SELECTED: add_theme_stylebox_override("panel", _style_select)
		CardState.LOCKED:   add_theme_stylebox_override("panel", _style_normal)


func _on_mouse_entered() -> void:
	if _state == CardState.IDLE:
		_apply_style(CardState.HOVERED)


func _on_mouse_exited() -> void:
	if _state == CardState.IDLE:
		_apply_style(CardState.IDLE)


func _on_gui_input(event: InputEvent) -> void:
	if _state == CardState.LOCKED:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_selected.emit(self)


func _on_confirm_pressed() -> void:
	if card_data:
		card_confirmed.emit(card_data)
