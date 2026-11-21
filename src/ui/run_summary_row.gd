class_name RunSummaryRow
extends HBoxContainer
## One battle line of the run-end summary: number, win/loss, net gold and the
## top damage dealer. Fed a RunSummary.make_entry() dictionary.

@export var color_win: Color = Color(0.55, 1, 0.25, 1)
@export var color_loss: Color = Color(1, 0.45, 0.4, 1)
@export var color_net_up: Color = Color(1, 0.85, 0.3, 1)
@export var color_net_down: Color = Color(1, 0.45, 0.4, 1)
@export var color_net_even: Color = Color(0.6, 0.65, 0.65, 1)

@onready var _battle_label: Label = %BattleLabel
@onready var _result_label: Label = %ResultLabel
@onready var _net_label: Label = %NetLabel
@onready var _top_label: Label = %TopLabel

var _entry: Dictionary = {}

func _ready() -> void:
	if not _entry.is_empty():
		_apply()

## Shows `entry` (RunSummary log entry). Safe to call before entering the tree.
func setup(entry: Dictionary) -> void:
	_entry = entry
	if is_node_ready():
		_apply()

func _apply() -> void:
	var won: bool = bool(_entry.get(&"won", false))
	var net: int = int(_entry.get(&"net", 0))
	_battle_label.text = "B%d" % int(_entry.get(&"battle", 0))
	_result_label.text = "WIN" if won else "LOSS"
	_result_label.add_theme_color_override(&"font_color", color_win if won else color_loss)
	_net_label.text = "%+dg" % net
	_net_label.add_theme_color_override(&"font_color",
		color_net_up if net > 0 else (color_net_down if net < 0 else color_net_even))
	var top_name: String = String(_entry.get(&"top_name", ""))
	_top_label.text = "MVP %s (%d)" % [top_name, int(_entry.get(&"top_damage", 0))] \
		if top_name != "" else "MVP -"
	_top_label.tooltip_text = _top_label.text
