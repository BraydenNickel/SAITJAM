class_name MonsterSlot
extends Button
## A clickable square showing one monster (side view) and its name. Used both
## for formation spots (empty slots show a "+") and roster chips.

## Formation spot this slot represents (-1 when used as a roster chip).
@export var spot: int = -1
## Faces left (enemy preview) instead of right.
@export var mirrored: bool = false
## Shows a one-line HP/ATK summary under the name (roster chips).
@export var show_stats: bool = false

## Roster index of the shown monster, or -1.
var roster_index: int = -1
var data: MonsterData

@onready var _view: MonsterView = %MonsterView
@onready var _holder: Node2D = %Holder
@onready var _name_label: Label = %NameLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _tag_label: Label = %TagLabel
@onready var _stats_label: Label = %StatsLabel

func _ready() -> void:
	_view.scale.x = -1.0 if mirrored else 1.0
	_refresh()

## Shows `monster` (null = empty slot). `index` is its roster index.
func set_monster(monster: MonsterData, index: int = -1) -> void:
	data = monster
	roster_index = index if monster != null else -1
	if is_node_ready():
		_refresh()

## Highlights the slot as selected.
func set_selected(selected: bool) -> void:
	self_modulate = Color(1.0, 1.0, 0.45) if selected else Color.WHITE

## Shows a small tag in the corner (e.g. "SET"); empty string hides it.
func set_tag(text: String) -> void:
	_tag_label.text = text
	_tag_label.visible = text != ""

func _refresh() -> void:
	_view.data = data
	_holder.visible = data != null
	_empty_label.visible = data == null and not mirrored
	_name_label.text = data.display_name if data != null else ""
	_stats_label.visible = show_stats and data != null
	if data != null:
		var stats: Dictionary = data.get_total_stats()
		_stats_label.text = "%d/%d" % [roundi(stats[&"hp"] as float), roundi(stats[&"atk"] as float)]
		tooltip_text = data.title
