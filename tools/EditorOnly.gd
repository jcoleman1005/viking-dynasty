# res://tools/EditorOnly.gd
@tool
extends CanvasItem 
# Inherits CanvasItem so it works on both Control (UI) and Node2D nodes

func _ready() -> void:
	if not Engine.is_editor_hint():
		# If the game is actually running, destroy this node immediately.
		queue_free()
	else:
		# If in editor, ensure it is visible (optional safeguard)
		show()
