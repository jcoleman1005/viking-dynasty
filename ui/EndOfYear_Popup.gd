# res://ui/EndOfYear_Popup.gd
extends PanelContainer

signal collect_button_pressed(payout: Dictionary)

@onready var payout_label: Label = $MarginContainer/VBoxContainer/PayoutLabel
@onready var collect_button: Button = $MarginContainer/VBoxContainer/CollectButton

var _current_payout: Dictionary = {}

func _ready() -> void:
	collect_button.pressed.connect(_on_collect_pressed)
	
	# --- MODIFICATION ---
	# Update the button text as requested
	collect_button.text = "Collect and return to settlement"
	# --- END MODIFICATION ---
	
	hide()

func display_payout(payout: Dictionary, title: String = "Welcome home!") -> void:
	if payout.is_empty():
		# If there's no payout, just emit the signal and don't show
		collect_button_pressed.emit({})
		return

	_current_payout = payout
	
	# Use the new title parameter
	var payout_text: String = "%s\n\nResources gathered:\n" % title
	for resource_type in payout:
		payout_text += "- %s: %d\n" % [resource_type.capitalize(), payout[resource_type]]
	
	payout_label.text = payout_text
	show()

func _on_collect_pressed() -> void:
	collect_button_pressed.emit(_current_payout)
	hide()
