# res://ui/components/RichTooltipButton.gd
class_name RichTooltipButton
extends Button

func _make_custom_tooltip(for_text: String) -> Object:
	# DEBUG: Check the Output console to see if this runs when you hover
	print("RichTooltipButton: Generating tooltip for ", name)
	
	# 1. Create the container
	var panel = PanelContainer.new()
	
	# CRITICAL: Force the theme to match your game theme
	# Otherwise it uses Godot's default grey theme
	if theme:
		panel.theme = theme
	else:
		# Walk up the parent chain to find a Control with a theme
		var ui_node: Node = self
		while ui_node and not (ui_node is Control and ui_node.theme):
			ui_node = ui_node.get_parent()
		
		if ui_node and ui_node is Control and ui_node.theme:
			panel.theme = ui_node.theme
		# If nothing is found, panel keeps default theme
	
	# Optional: Use your specific "TooltipPanel" style from the theme
	panel.theme_type_variation = "TooltipPanel" 
	
	# 2. Create the RichTextLabel
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = for_text
	
	# 3. Layout Settings (Crucial for visibility)
	rtl.fit_content = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block mouse
	
	# Apply Theme Colors specifically to the text logic
	# (Ensures text isn't invisible)
	rtl.add_theme_color_override("default_color", Color.WHITE) 
	
	panel.add_child(rtl)
	return panel
