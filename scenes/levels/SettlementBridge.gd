# res://scenes/levels/SettlementBridge.gd
#
# This is the "main" script for the settlement defense scene.
# It's responsible for handling player input and coordinating
# with the UI and the underlying managers.
#
# GDD Ref: 7.C.3.a

extends Node

# Pre-load the sample wall data. In a real build menu,
# the menu itself would hold this data.
var test_building_data: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")


func _unhandled_input(event: InputEvent) -> void:
	# Check if the input is a left-mouse click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		
		# We must have a valid resource to build
		if not test_building_data:
			push_error("Test data 'Bldg_Wall.tres' not found or invalid.")
			return

		# Get the mouse position in world space
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		
		# --- MODIFIED ---
		# Ask the SettlementManager to convert this world position
		# into a grid coordinate (e.g., (3, 5))
		# We do this by dividing the pixel position by the grid's cell size.
		var grid_pos: Vector2i = Vector2i(mouse_pos / SettlementManager.astar_grid.cell_size)
		
		# Now, we simply emit the global signal.
		# The SettlementManager is listening for this and will handle
		# all the logic for checking, paying, and placing the building.
		# Our input script doesn't need to know *how* it happens.
		EventBus.build_request_made.emit(test_building_data, grid_pos)
		
		# Mark the event as handled so it doesn't propagate
		get_viewport().set_input_as_handled()
