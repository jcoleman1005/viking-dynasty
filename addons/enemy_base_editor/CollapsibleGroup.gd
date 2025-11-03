@tool
extends VBoxContainer
class_name CollapsibleGroup

var title: String = "Group"
var expanded: bool = true

var header_button: Button
var content_container: VBoxContainer

func _init():
	setup_ui()

func setup_ui():
	# Header button
	header_button = Button.new()
	header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_button.pressed.connect(_on_header_pressed)
	super.add_child(header_button)
	
	# Content container
	content_container = VBoxContainer.new()
	super.add_child(content_container)
	
	_update_header()

func _update_header():
	var arrow = "▼ " if expanded else "▶ "
	header_button.text = arrow + title
	content_container.visible = expanded

func _on_header_pressed():
	expanded = !expanded
	_update_header()

func add_child(node, force_readable_name: bool = false, internal: int = INTERNAL_MODE_DISABLED):
	if content_container and node != header_button and node != content_container:
		content_container.add_child(node, force_readable_name, internal)
	else:
		super.add_child(node, force_readable_name, internal)