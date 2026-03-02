extends CanvasLayer
class_name EventUI

signal choice_made(event: EventData, choice: EventChoice)

@onready var title_label: Label = $PanelContainer/Margin/VBox/TitleLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var portrait: TextureRect = %Portrait
@onready var choice_buttons_container: VBoxContainer = $PanelContainer/Margin/VBox/ChoiceButtonsContainer

var current_event: EventData

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func display_event(event_data: EventData) -> void:
	if not event_data:
		Loggie.msg("EventUI: Cannot display a null EventData resource.").domain("UI").error()
		return
		
	current_event = event_data
	
	title_label.text = event_data.title
	description_label.text = "[i]" + event_data.description + "[/i]"
	
	if event_data.portrait:
		portrait.texture = event_data.portrait
		portrait.show()
	else:
		portrait.texture = null
		portrait.hide()
		
	for child in choice_buttons_container.get_children():
		child.queue_free()
		
	if event_data.choices.is_empty():
		var ok_button = Button.new()
		ok_button.text = "OK"
		ok_button.theme_type_variation = &"AdvanceButton"
		ok_button.pressed.connect(_on_choice_button_pressed.bind(null))
		choice_buttons_container.add_child(ok_button)
	else:
		for choice in event_data.choices:
			var choice_panel = PanelContainer.new()
			choice_panel.theme_type_variation = &"PanelContainerCard"
			choice_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 10)
			margin.add_theme_constant_override("margin_top", 10)
			margin.add_theme_constant_override("margin_right", 10)
			margin.add_theme_constant_override("margin_bottom", 10)
			choice_panel.add_child(margin)
			
			var vbox = VBoxContainer.new()
			margin.add_child(vbox)
			
			var title = Label.new()
			title.text = choice.choice_text
			vbox.add_child(title)
			
			if choice.tooltip_text != "":
				var consequence = Label.new()
				consequence.text = choice.tooltip_text
				consequence.theme_type_variation = &"SeasonLabel"
				consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(consequence)
			
			# Invisible button overlay to capture clicks and hover
			var btn_overlay = Button.new()
			btn_overlay.flat = true
			btn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn_overlay.pressed.connect(_on_choice_button_pressed.bind(choice))
			choice_panel.add_child(btn_overlay)
			
			choice_buttons_container.add_child(choice_panel)
			
	show()
	
	if choice_buttons_container.get_child_count() > 0:
		var first_child = choice_buttons_container.get_child(0)
		if first_child is Button:
			first_child.grab_focus()
		elif first_child.get_child_count() > 0:
			for c in first_child.get_children():
				if c is Button:
					c.grab_focus()
					break

func _on_choice_button_pressed(choice: EventChoice) -> void:
	hide()
	choice_made.emit(current_event, choice)
	current_event = null
