class_name DamageRow
extends HBoxContainer
## One line of the battle damage counter: unit name, a bar relative to the
## top dealer, and the damage total. The top dealer's name is highlighted.

const COLOR_NAME: Color = Color(0.85, 1.0, 0.85)
const COLOR_MVP: Color = Color(1.0, 0.9, 0.2)

@onready var _name_label: Label = %NameLabel
@onready var _bar: ProgressBar = %Bar
@onready var _value_label: Label = %ValueLabel

## Shows `damage` for `unit_name`; the bar fills relative to `top_damage`.
func set_values(unit_name: String, damage: int, top_damage: int, is_mvp: bool) -> void:
	_name_label.text = ("* " if is_mvp else "") + unit_name
	_name_label.add_theme_color_override("font_color", COLOR_MVP if is_mvp else COLOR_NAME)
	_bar.max_value = maxf(1.0, float(top_damage))
	_bar.value = float(damage)
	_value_label.text = str(damage)
