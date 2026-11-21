class_name RewardCard
extends Control
## One post-battle reward option (from RewardLogic.roll_options): a framed card
## with a specimen panel (mutation sprite or reward icon), title, type tag,
## stats and description. The frame colour comes from the reward type; hover or
## focus brightens it and lifts the card. Pressing the inner Card button picks it.
## The root is a plain Control so the Card can be tweened freely inside an
## HBoxContainer (containers reset their direct children's position).

## Emitted when the card is chosen.
signal chosen(option: Dictionary)

## Reward id -> icon texture path (mutations use their own sprite).
const ICONS: Dictionary = {
	&"stabilizers": "res://assets/sprites/icons/stabilizer.png",
	&"gold": "res://assets/sprites/icons/gold.png",
	&"free_human": "res://assets/sprites/icons/volunteer.png",
	&"cleanse": "res://assets/sprites/icons/cleanse.png",
	&"lucky_gene": "res://assets/sprites/icons/lucky_gene.png",
	&"insurance": "res://assets/sprites/icons/insurance.png",
	&"catalyst": "res://assets/sprites/icons/catalyst.png",
}
## Reward id -> frame colour for non-mutation rewards.
const TYPE_COLORS: Dictionary = {
	&"stabilizers": Color(0.45, 0.85, 1, 1),
	&"gold": Color(1, 0.8, 0.25, 1),
	&"free_human": Color(0.55, 1, 0.25, 1),
	&"cleanse": Color(0.35, 1, 0.7, 1),
	&"lucky_gene": Color(0.7, 1, 0.3, 1),
	&"insurance": Color(0.75, 0.5, 1, 1),
	&"catalyst": Color(1, 0.55, 0.25, 1),
}
## Reward id -> small type tag (mutations show rarity + socket instead).
const TAGS: Dictionary = {
	&"gold": "GOLD",
	&"free_human": "SUBJECT",
}

## Base frame style (duplicated and recoloured per card).
@export var frame_style: StyleBoxFlat
## Frame colour multiplier while idle (1 = full type colour).
@export var idle_dim: float = 0.6
## Pixels the card rises while hovered / focused.
@export var lift: float = 8.0
## Scale while hovered / focused.
@export var hover_scale: float = 1.0
## Seconds for the hover lift tween.
@export var hover_time: float = 0.1

@onready var _card: Button = %Card
@onready var _specimen: PanelContainer = %Specimen
@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %TitleLabel
@onready var _tag_label: Label = %TagLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _desc_label: Label = %DescLabel

var _option: Dictionary = {}
var _color: Color = Color(0.55, 1, 0.25, 1)
var _idle_style: StyleBoxFlat
var _hot_style: StyleBoxFlat
var _hover_tween: Tween
var _hot: bool = false
## True once picked or dismissed: hover no longer animates.
var _locked: bool = false

func _ready() -> void:
	_card.pressed.connect(func() -> void: chosen.emit(_option))
	_card.mouse_entered.connect(_set_hot.bind(true))
	_card.mouse_exited.connect(func() -> void: _set_hot(_card.has_focus()))
	_card.focus_entered.connect(_set_hot.bind(true))
	_card.focus_exited.connect(func() -> void: _set_hot(_card.is_hovered()))
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size * 0.5)
	_apply()

## Shows `option` {id, title, description, mutation|null}.
func setup(option: Dictionary) -> void:
	_option = option
	if is_node_ready():
		_apply()

## Gives keyboard / gamepad focus to the card button.
func focus() -> void:
	_card.grab_focus()

## The inner button (for focus neighbours and animation).
func card() -> Button:
	return _card

## Stops hover animation (after a pick).
func lock() -> void:
	_locked = true
	_card.disabled = true
	_card.focus_mode = Control.FOCUS_NONE

func _apply() -> void:
	if _option.is_empty():
		return
	var id: StringName = _option.get(&"id", &"") as StringName
	var mutation: MutationData = _option.get(&"mutation") as MutationData
	_title_label.text = String(_option.get(&"title", ""))
	_desc_label.text = String(_option.get(&"description", ""))
	if mutation != null:
		_color = InventoryItem.rarity_color(mutation.rarity)
		_icon.texture = mutation.sprite_front
		_tag_label.text = "%s %s" % [InventoryItem.rarity_name(mutation.rarity).to_upper(),
			InventoryItem.socket_name(mutation.socket_type)]
		_stats_label.text = InventoryItem.stat_summary(mutation)
	else:
		_color = TYPE_COLORS.get(id, _color) as Color
		var path: String = String(ICONS.get(id, ""))
		_icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
		_tag_label.text = String(TAGS.get(id, "CONSUMABLE"))
		_stats_label.text = ""
	_stats_label.visible = _stats_label.text != ""
	_tag_label.add_theme_color_override(&"font_color", _color)
	_build_styles()
	_set_hot(false, true)

func _build_styles() -> void:
	if frame_style == null:
		return
	_idle_style = frame_style.duplicate() as StyleBoxFlat
	_idle_style.border_color = _color * idle_dim
	_idle_style.border_color.a = 1.0
	_hot_style = frame_style.duplicate() as StyleBoxFlat
	_hot_style.border_color = _color.lightened(0.2)
	_hot_style.bg_color = frame_style.bg_color.lerp(_color, 0.08)
	_hot_style.shadow_color = Color(_color, 0.35)
	_hot_style.shadow_size = 6
	var specimen: StyleBoxFlat = _specimen.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	if specimen != null:
		specimen.border_color = (_color * 0.4)
		specimen.border_color.a = 1.0
		_specimen.add_theme_stylebox_override(&"panel", specimen)

func _set_hot(hot: bool, instant: bool = false) -> void:
	if _locked or (hot == _hot and not instant):
		return
	_hot = hot
	var style: StyleBoxFlat = _hot_style if hot else _idle_style
	if style != null:
		for state: StringName in [&"normal", &"hover", &"pressed"]:
			_card.add_theme_stylebox_override(state, style)
	if _hover_tween != null:
		_hover_tween.kill()
	var target_y: float = -lift if hot else 0.0
	var target_scale: Vector2 = Vector2.ONE * (hover_scale if hot else 1.0)
	if instant:
		return
	_hover_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_card, ^"position:y", target_y, hover_time)
	_hover_tween.tween_property(_card, ^"scale", target_scale, hover_time)
