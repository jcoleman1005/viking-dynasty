# res://ui/WelcomeHomePopup.gd
extends PanelContainer

signal collect_button_pressed(payout: Dictionary)

@onready var payout_label: Label = $MarginContainer/VBoxContainer/PayoutLabel
@onready var collect_button: Button = $MarginContainer/VBoxContainer/CollectButton

var _current_payout: Dictionary = {}

func _ready() -> void:
	collect_button.pressed.connect(_on_collect_pressed)
	hide()

func display_payout(payout: Dictionary) -> void:
	if payout.is_empty():
		return

	_current_payout = payout
	var payout_text: String = "Welcome home!\n\nResources gathered:\n"
	for resource_type in payout:
		payout_text += "- %s: %d\n" % [resource_type.capitalize(), payout[resource_type]]
	
	payout_label.text = payout_text
	show()

func _on_collect_pressed() -> void:
	collect_button_pressed.emit(_current_payout)
	hide()
