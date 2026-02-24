# res://scenes/effects/FloatingText.gd
# TODO: Faint text — when you revisit visuals, a drop shadow or outline on the Label will fix readability
extends Label

func setup(text: String, color: Color) -> void:
	self.text = text
	self.modulate = color
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 60, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(queue_free)
