class_name CodexEntry
extends PanelContainer
## One tile of the Codex screen: a fused part's or base mutation's icon, name and
## badge. An undiscovered entry is a dark silhouette named "???"; a dimmed one
## (base mutation never obtained) keeps its name and badge but greys its icon.

## Icon modulate of an undiscovered entry.
@export var color_silhouette: Color = Color(0.02, 0.03, 0.04, 1)
## Name colour of an undiscovered entry.
@export var color_unknown: Color = Color(0.45, 0.55, 0.5, 1)
## Icon modulate of a dimmed (not yet obtained) entry.
@export var color_dimmed: Color = Color(0.3, 0.3, 0.34, 0.75)
## How far a dimmed entry's badge colour is darkened (0..1).
@export_range(0.0, 1.0) var dim_badge_amount: float = 0.45

## Base mutation shown by this tile (Mutations tab), or null. Used for filtering.
var mutation: MutationData

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _tag_label: Label = %TagLabel

var _texture: Texture2D
var _name: String = ""
var _tag: String = ""
var _tag_color: Color = Color.WHITE
var _known: bool = true
var _tip: String = ""
var _dim: bool = false

func _ready() -> void:
	_apply()

## Shows an entry: `icon`, `entry_name`, the badge text `tag` in `tag_color`, and
## the tooltip `tip`. `known` = false draws the icon as a silhouette, unless
## `dim_unknown` is true: then the icon is only greyed and the badge keeps a
## darkened `tag_color`. Safe to call before entering the tree.
func setup(icon: Texture2D, entry_name: String, tag: String, tag_color: Color, known: bool,
		tip: String = "", dim_unknown: bool = false) -> void:
	_texture = icon
	_name = entry_name
	_tag = tag
	_tag_color = tag_color
	_known = known
	_tip = tip
	_dim = dim_unknown
	if is_node_ready():
		_apply()

func _apply() -> void:
	_icon.texture = _texture
	_name_label.text = _name
	_tag_label.text = _tag
	tooltip_text = _tip
	if _known:
		_icon.modulate = Color.WHITE
		_name_label.remove_theme_color_override(&"font_color")
		_tag_label.add_theme_color_override(&"font_color", _tag_color)
		return
	_icon.modulate = color_dimmed if _dim else color_silhouette
	_name_label.add_theme_color_override(&"font_color", color_unknown)
	_tag_label.add_theme_color_override(&"font_color",
		_tag_color.darkened(dim_badge_amount) if _dim else color_unknown)
