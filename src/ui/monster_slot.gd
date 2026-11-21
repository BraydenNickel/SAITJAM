class_name MonsterSlot
extends Button
## A clickable square showing one monster (side view) and its name. Used both
## for formation spots (empty slots show a "+") and roster chips. Supports
## Control drag and drop: the owning screen decides what a drop means through
## `drop_check` and the `dropped` signal, so the rules stay in the screen.

## Emitted when drag data accepted by `drop_check` is dropped on this slot.
signal dropped(drag_data: Dictionary)

const DRAG_PREVIEW_SCENE: PackedScene = preload("res://src/ui/drag_preview.tscn")

## Formation spot this slot represents (-1 when used as a roster chip).
@export var spot: int = -1
## Faces left (enemy preview) instead of right.
@export var mirrored: bool = false
## Shows a one-line HP/ATK summary under the name (roster chips).
@export var show_stats: bool = false

## The shown monster can be dragged away (formation spots and roster chips).
@export var drag_enabled: bool = false

## Set by the owning screen: (slot: MonsterSlot, drag_data: Dictionary) -> bool.
## An invalid Callable means the slot accepts no drops.
var drop_check: Callable
## Roster index of the shown monster, or -1.
var roster_index: int = -1
var data: MonsterData

@onready var _view: MonsterView = %MonsterView
@onready var _holder: Node2D = %Holder
@onready var _name_label: Label = %NameLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _tag_label: Label = %TagLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _drop_glow: Panel = %DropGlow

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

## Shows or hides the "valid drop target" outline used while dragging.
func set_drop_highlight(on: bool) -> void:
	_drop_glow.visible = on

## Drag payload for this slot's monster: {kind = &"monster", roster_index,
## from_spot} (from_spot = -1 for a roster chip). Empty when nothing to drag.
func drag_payload() -> Dictionary:
	if not drag_enabled or data == null or roster_index < 0:
		return {}
	return {&"kind": &"monster", &"roster_index": roster_index, &"from_spot": spot}

func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload: Dictionary = drag_payload()
	if payload.is_empty():
		return null
	var preview: DragPreview = DRAG_PREVIEW_SCENE.instantiate() as DragPreview
	preview.show_monster(data, mirrored)
	set_drag_preview(preview)
	return payload

func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if not drop_check.is_valid() or not drag_data is Dictionary:
		return false
	return bool(drop_check.call(self, drag_data))

func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	dropped.emit(drag_data as Dictionary)

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
