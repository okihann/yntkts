extends Control

@onready var label = $Label

func setup(value, is_crit := false):
	label.text = str(value)

	if is_crit:
		label.add_theme_font_size_override("font_size", 16)
		label.modulate = Color.DARK_RED
	else:
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color.WHITE

	var t = create_tween()

	t.tween_property(self, "position:y", position.y - 40, 0.5)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.5)

	await t.finished
	queue_free()
