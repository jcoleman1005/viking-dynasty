# res://ui/EndOfYear_Popup.gd
extends PanelContainer

signal collect_button_pressed(payout: Dictionary)

@onready var payout_label: RichTextLabel = $MarginContainer/VBoxContainer/PayoutLabel
@onready var collect_button: Button = $MarginContainer/VBoxContainer/CollectButton

var _current_payout: Dictionary = {}

func _ready() -> void:
	collect_button.pressed.connect(_on_collect_pressed)
	collect_button.text = "Collect and return to settlement"
	hide()

func display_payout(payout: Dictionary, title: String = "Welcome home!") -> void:
	_current_payout = payout
	
	var text: String = "[b]%s[/b]\n\n" % title
	
	# 1. Warnings / Events
	if payout.has("_messages") and not payout["_messages"].is_empty():
		text += "[b]Incidents:[/b]\n"
		for msg in payout["_messages"]:
			text += "%s\n" % msg
		text += "\n"
	
	# 2. Population News
	if payout.has("population_growth"):
		text += "[b]Demographics:[/b]\n"
		text += "%s\n\n" % payout["population_growth"]
	
	# 3. Resources
	text += "[b]Treasury Changes:[/b]\n"
	var found_resources = false
	
	for key in payout:
		# Skip special keys
		if key.begins_with("_") or key == "population_growth": continue
		
		var val = payout[key]
		var color_tag = ""
		if val > 0: color_tag = "[color=green]+"
		elif val < 0: color_tag = "[color=red]"
		
		if val != 0:
			text += "- %s: %s%d[/color]\n" % [key.capitalize(), color_tag, val]
			found_resources = true
			
	if not found_resources:
		text += "(No changes)\n"
	
	payout_label.text = text
	show()

func _on_collect_pressed() -> void:
	collect_button_pressed.emit(_current_payout)
	hide()
