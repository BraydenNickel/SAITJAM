class_name RewardCard
extends Button
## One post-battle reward option (from RewardLogic.roll_options): title, icon
## (the mutation sprite, if any) and description. Pressing it picks it.

## Emitted when the card is chosen.
signal chosen(option: Dictionary)

@onready var _title_label: Label = %TitleLabel
@onready var _icon_box: Control = %IconBox
@onready var _icon: TextureRect = %Icon
@onready var _rarity_label: Label = %RarityLabel
@onready var _desc_label: Label = %DescLabel

var _option: Dictionary = {}

func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(_option))
	_apply()

## Shows `option` {id, title, description, mutation|null}.
func setup(option: Dictionary) -> void:
	_option = option
	if is_node_ready():
		_apply()

func _apply() -> void:
	if _option.is_empty():
		return
	var mutation: MutationData = _option.get(&"mutation") as MutationData
	_title_label.text = String(_option.get(&"title", ""))
	_desc_label.text = String(_option.get(&"description", ""))
	_icon.texture = mutation.sprite_front if mutation != null else null
	_icon_box.visible = mutation != null
	_rarity_label.visible = mutation != null
	if mutation != null:
		_rarity_label.text = "%s %s\n%s" % [InventoryItem.rarity_name(mutation.rarity),
			InventoryItem.socket_name(mutation.socket_type), InventoryItem.stat_summary(mutation)]
		_rarity_label.add_theme_color_override(&"font_color",
			InventoryItem.rarity_color(mutation.rarity))
