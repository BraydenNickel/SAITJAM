class_name DragPreview
extends Control
## Small floating preview shown under the cursor while dragging (Control drag
## and drop): either a monster (side view) or a mutation icon. Instanced by the
## drag source and handed to Control.set_drag_preview().

@onready var _holder: Node2D = %Holder
@onready var _view: MonsterView = %MonsterView
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel

var _monster: MonsterData
var _mutation: MutationData
var _mirrored: bool = false

func _ready() -> void:
	_apply()

## Shows `monster` (side view, facing left when `mirrored`).
func show_monster(monster: MonsterData, mirrored: bool = false) -> void:
	_monster = monster
	_mutation = null
	_mirrored = mirrored
	if is_node_ready():
		_apply()

## Shows the front sprite and name of `mutation`.
func show_mutation(mutation: MutationData) -> void:
	_mutation = mutation
	_monster = null
	if is_node_ready():
		_apply()

func _apply() -> void:
	_holder.visible = _monster != null
	_icon.visible = _mutation != null
	if _monster != null:
		_view.scale.x = -1.0 if _mirrored else 1.0
		_view.data = _monster
		_name_label.text = _monster.display_name
	elif _mutation != null:
		_icon.texture = _mutation.sprite_front
		_name_label.text = _mutation.display_name
		_name_label.add_theme_color_override(&"font_color",
			InventoryItem.rarity_color(_mutation.rarity))
