# res://ui/EndOfYear_Popup.gd
extends PanelContainer

signal collect_button_pressed(payout: Dictionary)

@onready var payout_label: RichTextLabel = $MarginContainer/VBoxContainer/PayoutLabel
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
	_current_payout = payout
	
	var text: String = "[b]%s[/b]\n\n" % title
	
	# 1. Add Warnings first (High Priority)
	if payout.has("_messages"):
		var messages = payout["_messages"]
		text += "[b]Incidents:[/b]\n"
		for msg in messages:
			text += "%s\n" % msg
		text += "\n"
	
	# 2. Add Resources
	text += "[b]Resources gathered:[/b]\n"
	var found_resources = false
	
	for key in payout:
		if key.begins_with("_"): continue
		text += "- %s: %d\n" % [key.capitalize(), payout[key]]
		found_resources = true
		
	if not found_resources:
		text += "(None)\n"
	
	# Assign to label
	# IMPORTANT: If your PayoutLabel is a standard Label, you need to
	# check 'Use Custom Formatting' or similar if available, or swap to RichTextLabel.
	# Assuming you swap it or use a RichTextLabel:
	payout_label.text = text
	
	show()

func _on_collect_pressed() -> void:
	collect_button_pressed.emit(_current_payout)
	hide()
