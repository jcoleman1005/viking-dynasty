#res://scripts/utility/RTSInputHandler.gd
# res://scripts/input/RTSInputHandler.gd
class_name RTSInputHandler
extends Node

# We can toggle this if we open a menu and want to stop RTS hotkeys
var input_enabled: bool = true

func _ready() -> void:
	# Listen for UI blocking requests (e.g. opening the Dynasty Tree)
	EventBus.camera_input_lock_requested.connect(func(locked): input_enabled = !locked)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled: return
	
	if event is InputEventKey and event.is_pressed():
		_handle_control_groups(event)
		_handle_formations(event)

func _handle_control_groups(event: InputEventKey) -> void:
	# Keys 0-9
	if event.keycode >= KEY_0 and event.keycode <= KEY_9:
		var group_index = event.keycode - KEY_0
		
		# CTRL+Number = Assign, Number = Select
		# We emit the intent, we don't do the logic here.
		EventBus.control_group_command.emit(group_index, event.ctrl_pressed)
		get_viewport().set_input_as_handled()

func _handle_formations(event: InputEventKey) -> void:
	# Map Keys to SquadFormation.FormationType Integers
	# LINE=0, COLUMN=1, WEDGE=2, BOX=3, CIRCLE=4
	match event.keycode:
		KEY_F1: 
			EventBus.formation_change_command.emit(0) # LINE
			get_viewport().set_input_as_handled()
		KEY_F2:
			EventBus.formation_change_command.emit(1) # COLUMN
			get_viewport().set_input_as_handled()
		KEY_F3:
			EventBus.formation_change_command.emit(2) # WEDGE
			get_viewport().set_input_as_handled()
		KEY_F4:
			EventBus.formation_change_command.emit(3) # BOX
			get_viewport().set_input_as_handled()
		KEY_F5:
			EventBus.formation_change_command.emit(4) # CIRCLE
			get_viewport().set_input_as_handled()
