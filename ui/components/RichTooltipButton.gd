# res://ui/components/RichTooltipButton.gd
extends Button

# Preload your new visual scene
const TOOLTIP_SCENE = preload("res://ui/components/RichTooltip.tscn")

func _make_custom_tooltip(for_text: String) -> Control:
	# 1. Instantiate the visual scene
	var tooltip_instance = TOOLTIP_SCENE.instantiate()
	
	# 2. Find the Label (safely)
	# We assume the structure is Panel -> Margin -> RichTextLabel
	# You can also use a unique name %Label in the scene if you set it up.
	var label = tooltip_instance.find_child("RichTextLabel", true, false)
	
	if label:
		label.text = for_text
	
	return tooltip_instance
