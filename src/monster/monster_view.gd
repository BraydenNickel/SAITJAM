@tool
class_name MonsterView
extends Node2D
## Shows a MonsterData by placing each slot's mutation sprite on the matching
## Marker2D under Sockets (marker name == slot name). Works in the editor.
## Part sprites are created at runtime WITHOUT an owner, so they are never saved
## into the scene; only those are ever freed.

enum View { FRONT, SIDE }

const PART_SCENE: PackedScene = preload("res://src/monster/part_sprite.tscn")
const PART_META: StringName = &"_monster_view_part"

## The monster to display. Null shows the plain human torso.
@export var data: MonsterData:
	set(value):
		if Engine.is_editor_hint() and data != null and data.changed.is_connected(refresh):
			data.changed.disconnect(refresh)
		data = value
		if Engine.is_editor_hint() and data != null and not data.changed.is_connected(refresh):
			data.changed.connect(refresh)
		refresh()
## Which art set to use.
@export var view: View = View.FRONT:
	set(value):
		view = value
		refresh()

func _ready() -> void:
	refresh()

## Rebuilds the part sprites. Call after mutating `data` at runtime.
func refresh() -> void:
	if not is_node_ready():
		return
	var sockets: Node = get_node_or_null("Sockets")
	if sockets == null:
		return
	for child: Node in sockets.get_children():
		var marker: Marker2D = child as Marker2D
		if marker == null:
			continue
		_clear_parts(marker)
		if data == null:
			continue
		var mutation: MutationData = data.slots.get(marker.name) as MutationData
		if mutation == null:
			continue
		var tex: Texture2D = mutation.sprite_front if view == View.FRONT else mutation.sprite_side
		if tex == null:
			continue
		var part: Sprite2D = PART_SCENE.instantiate() as Sprite2D
		part.texture = tex
		part.flip_h = view == View.FRONT and String(marker.name).ends_with("_R")
		part.set_meta(PART_META, true)
		marker.add_child(part)

func _clear_parts(marker: Marker2D) -> void:
	for child: Node in marker.get_children():
		if child.has_meta(PART_META):
			marker.remove_child(child)
			child.queue_free()
