# res://scripts/levels/LevelBase.gd
class_name LevelBase
extends Node2D

# This function handles the "delicate dance" of initializing the grid
# so your actual level scripts don't have to worry about timing.
func setup_level_navigation(tilemap_layer: TileMapLayer, width: int, height: int) -> void:
	# 1. Wait for Godot to catch up visually/physically
	await get_tree().process_frame
	
	# 2. Initialize the Navigation Manager
	Loggie.msg("Initializing Navigation Grid for Level...").domain("SYSTEM").info()
	
	NavigationManager.initialize_grid_from_tilemap(
		tilemap_layer,
		Vector2i(width, height),
		Vector2i(64, 32) # Your standard tile size
	)
	
	Loggie.msg("Navigation Ready.").domain("SYSTEM").info()
