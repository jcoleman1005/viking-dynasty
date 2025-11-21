# res://ui/PauseButton.gd
extends Button

func _ready():
	# Connect button signal
	pressed.connect(_on_pause_pressed)
	
	# Also listen for the ui_pause input action
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		_on_pause_pressed()
		get_viewport().set_input_as_handled()

func _on_pause_pressed():
	Loggie.info("Pause button pressed!", "PauseButton")
	
	# Try to access PauseManager if it exists
	if get_tree().has_group("pause_manager") or has_node("/root/PauseManager"):
		var pause_manager = get_node_or_null("/root/PauseManager")
		if pause_manager:
			Loggie.info("Found PauseManager autoload, calling request_pause()", "PauseButton")
			pause_manager.request_pause()
		else:
			Loggie.warn("PauseManager not found in autoload", "PauseButton")
	else:
		# Fallback: create a simple pause menu directly
		Loggie.info("PauseManager not available, creating simple pause overlay", "PauseButton")
		_create_simple_pause_menu()

func _create_simple_pause_menu():
	# Check if pause is already active
	if get_tree().paused:
		Loggie.info("Game already paused, unpausing instead", "PauseButton")
		get_tree().paused = false
		# Remove existing pause overlay
		var existing_overlay = get_tree().get_first_node_in_group("pause_overlay")
		if existing_overlay:
			existing_overlay.queue_free()
		return
	
	# Create a simple pause overlay
	var pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_to_group("pause_overlay")
	
	# Make it fullscreen
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create pause menu content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(200, 150)
	
	var title_label = Label.new()
	title_label.text = "GAME PAUSED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	
	var resume_button = Button.new()
	resume_button.text = "Resume (ESC)"
	resume_button.pressed.connect(_resume_game)
	
	var quit_button = Button.new()
	quit_button.text = "Quit to Menu"
	quit_button.pressed.connect(_quit_to_menu)
	
	# Add to hierarchy
	vbox.add_child(title_label)
	vbox.add_child(resume_button)
	vbox.add_child(quit_button)
	pause_overlay.add_child(vbox)
	
	# Add to scene tree (at root level to ensure it's on top)
	get_tree().root.add_child(pause_overlay)
	
	# Pause the game
	get_tree().paused = true
	Loggie.info("Simple pause menu created and game paused", "PauseButton")

func _resume_game():
	Loggie.info("Resuming game from simple pause menu", "PauseButton")
	get_tree().paused = false
	
	# Remove pause overlay
	var existing_overlay = get_tree().get_first_node_in_group("pause_overlay")
	if existing_overlay:
		existing_overlay.queue_free()

func _quit_to_menu():
	Loggie.info("Quit to menu requested from pause", "PauseButton")
	get_tree().paused = false
	# You can implement scene switching here if needed
	get_tree().quit()
