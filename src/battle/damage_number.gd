class_name DamageNumber
extends Label
## Floating combat text: rises, fades, frees itself.

## Shows `message` centred on `world_pos`. `size_mult` > 1 makes it bigger (crits).
func show_text(message: String, world_pos: Vector2, color: Color, size_mult: float = 1.0) -> void:
	text = message
	add_theme_color_override("font_color", color)
	add_theme_font_size_override("font_size", roundi(10.0 * size_mult))
	position = world_pos - Vector2(custom_minimum_size.x * 0.5, custom_minimum_size.y * 0.5)
	var tween: Tween = create_tween().set_parallel(true)
	if size_mult > 1.0:
		scale = Vector2(1.5, 1.5)
		tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "position:y", position.y - Tuning.NUMBER_RISE, Tuning.NUMBER_TIME)
	tween.tween_property(self, "modulate:a", 0.0, Tuning.NUMBER_TIME * 0.4).set_delay(Tuning.NUMBER_TIME * 0.6)
	tween.chain().tween_callback(queue_free)
