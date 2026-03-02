# res://ui/components/LedgerRow.gd
# Three-column ledger row: Label | Value | Net
# Net column is colour-coded: positive → PROSPERITY, negative → DANGER, zero → TEXT_SECONDARY
class_name LedgerRow
extends HBoxContainer

const COLOR_POSITIVE  := Color("#7ab648")   # PROSPERITY
const COLOR_NEGATIVE  := Color("#c84040")   # DANGER
const COLOR_ZERO      := Color("#9a9080")   # TEXT_SECONDARY
const COLOR_LABEL     := Color("#9a9080")   # TEXT_SECONDARY
const COLOR_VALUE     := Color("#e8dfc0")   # TEXT_PRIMARY

@onready var label_col: Label = $LabelCol
@onready var value_col: Label = $ValueCol
@onready var net_col:   Label = $NetCol


# Populate all three columns at once.
func setup(row_label: String, value: String, net_value: int) -> void:
	label_col.text = row_label
	value_col.text = value
	set_net(net_value)


# Update only the net column value and colour.
func set_net(value: int) -> void:
	if value > 0:
		net_col.text = "+%d" % value
		net_col.add_theme_color_override("font_color", COLOR_POSITIVE)
	elif value < 0:
		net_col.text = "%d" % value
		net_col.add_theme_color_override("font_color", COLOR_NEGATIVE)
	else:
		net_col.text = "—"
		net_col.add_theme_color_override("font_color", COLOR_ZERO)
