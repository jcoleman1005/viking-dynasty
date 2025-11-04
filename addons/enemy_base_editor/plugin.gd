@tool
extends EditorPlugin

var dock

func _enter_tree():
	# Create and add the custom dock
	dock = preload("res://addons/enemy_base_editor/EnemyBaseEditorDock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	
	# Also add the tool menu for backwards compatibility
	add_tool_menu_item("Enemy Base Layout Editor", _open_legacy_editor)

func _exit_tree():
	# Remove the dock and menu item
	if dock:
		remove_control_from_docks(dock)
		dock = null
	remove_tool_menu_item("Enemy Base Layout Editor")

func _open_legacy_editor():
	# Legacy function - redirect to dock
	if dock:
		dock.show_legacy_analysis()
	else:
		print("Enemy Base Editor dock not available")
