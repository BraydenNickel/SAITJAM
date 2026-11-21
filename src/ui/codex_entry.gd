class_name CodexEntry
extends PanelContainer
## One tile of the Codex screen: a fused part's icon, name and badge. An
## undiscovered entry is a dark silhouette named "???".

## Icon modulate of an undiscovered entry.
@export var color_silhouette: Color = Color(0.02, 0.03, 0.04, 1)
## Name colour of an undiscovered entry.
@export var color_unknown: Color = Color(0.45, 0.55, 0.5, 1)

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _tag_label: Label = %TagLabel

var _texture: Texture2D
var _name: String = ""
var _tag: String = ""
var _tag_color: Color = Color.WHITE
var _known: bool = true
var _tip: String = ""

func _ready() -> void:
	_apply()

## Shows an entry: `icon`, `entry_name`, the badge text `tag` in `tag_color`, and
## the tooltip `tip`. `known` = false draws the icon as a silhouette. Safe to
## call before entering the tree.
func setup(icon: Texture2D, entry_name: String, tag: String, tag_color: Color, known: bool,
		tip: String = "") -> void:
	_texture = icon
	_name = entry_name
	_tag = tag
	_tag_color = tag_color
	_known = known
	_tip = tip
	if is_node_ready():
		_apply()

func _apply() -> void:
	_icon.texture = _texture
	_icon.modulate = Color.WHITE if _known else color_silhouette
	_name_label.text = _name
	if _known:
		_name_label.remove_theme_color_override(&"font_color")
	else:
		_name_label.add_theme_color_override(&"font_color", color_unknown)
	_tag_label.text = _tag
	_tag_label.add_theme_color_override(&"font_color", _tag_color if _known else color_unknown)
	tooltip_text = _tip
