# res://ui/Event_UI.gd
#
# Controller script for the modal event window (Event_UI.tscn).
# This scene is responsible for displaying an EventData resource
# and returning the player's choice.
class_name EventUI
extends CanvasLayer

## Emitted when the player clicks a choice button.
## Passes the EventData and the chosen EventChoice.
signal choice_made(event: EventData, choice: EventChoice)

# Node References
@onready var title_label: Label = $PanelContainer/Margin/VBox/TitleLabel
@onready var description_label: Label = $PanelContainer/Margin/VBox/HBox/DescriptionLabel
@onready var portrait: TextureRect = %Portrait
@onready var choice_buttons_container: VBoxContainer = $PanelContainer/Margin/VBox/ChoiceButtonsContainer

var current_event: EventData

func _ready() -> void:
	# Start hidden. The EventManager will show this UI.
	hide()
	
	# Set process mode to "When Paused" so it works even if
	# the EventManager pauses the game to show the event.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func display_event(event_data: EventData) -> void:
	"""
	Configures and displays the event window based on an EventData resource.
	"""
	if not event_data:
		push_error("EventUI: Cannot display a null EventData resource.")
		return
		
	current_event = event_data
	
	# 1. Populate Text
	title_label.text = event_data.title
	description_label.text = event_data.description
	
	# 2. Populate Portrait
	if event_data.portrait:
		portrait.texture = event_data.portrait
		portrait.show()
	else:
		portrait.texture = null
		portrait.hide()
		
	# 3. Clear and Create Choice Buttons
	for child in choice_buttons_container.get_children():
		child.queue_free()
		
	if event_data.choices.is_empty():
		# Create a default "OK" button if no choices are provided
		var ok_button = Button.new()
		ok_button.text = "OK"
		ok_button.pressed.connect(_on_choice_button_pressed.bind(null))
		choice_buttons_container.add_child(ok_button)
	else:
		# Create a button for each choice
		for choice in event_data.choices:
			var choice_button = Button.new()
			choice_button.text = choice.choice_text
			choice_button.tooltip_text = choice.tooltip_text
			choice_button.pressed.connect(_on_choice_button_pressed.bind(choice))
			choice_buttons_container.add_child(choice_button)
			
	# 4. Show the UI
	show()
	
	# Grab focus so gamepad/keyboard input works
	# A CanvasLayer can't grab focus, so we focus the first button
	var first_button = choice_buttons_container.get_child(0) as Button
	if first_button:
		first_button.grab_focus()

func _on_choice_button_pressed(choice: EventChoice) -> void:
	"""
	Called when any choice button is pressed.
	Emits the signal and hides the window.
	"""
	hide()
	choice_made.emit(current_event, choice)
	current_event = null
