class_name ShopSlot
extends PanelContainer
## One shop offer (mutation, human or stabilizer): icon, name, rarity, stats,
## price and a Buy button. The screen decides whether it can be bought.

## Emitted when Buy is pressed. `index` is this slot's stock index.
signal buy_pressed(index: int)

## Index into RunState.shop_stock.
@export var index: int = 0
## Icon shown for the "human" offer.
@export var human_icon: Texture2D
## Text colour for non-mutation offers.
@export var plain_color: Color = Color(0.78, 0.95, 0.85, 1)
## Modulate applied once the offer is sold.
@export var sold_modulate: Color = Color(1, 1, 1, 0.4)

@onready var _name_label: Label = %NameLabel
@onready var _icon: TextureRect = %Icon
@onready var _stab_icon: Control = %StabIcon
@onready var _rarity_label: Label = %RarityLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _price_label: Label = %PriceLabel
@onready var _buy_button: Button = %BuyButton

func _ready() -> void:
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit(index))

## Shows a stock entry {kind, mutation, price, sold}. `block_reason` is
## ShopLogic.can_buy(): "" when buyable, else why not (used as the tooltip).
func setup(entry: Dictionary, block_reason: String) -> void:
	var kind: StringName = entry.get(&"kind", &"") as StringName
	var mutation: MutationData = entry.get(&"mutation") as MutationData
	var sold: bool = bool(entry.get(&"sold", false))
	_stab_icon.visible = kind == &"stabilizer"
	_icon.visible = kind != &"stabilizer"
	tooltip_text = ""
	match kind:
		&"mutation":
			if mutation != null:
				_name_label.text = mutation.display_name
				_icon.texture = mutation.sprite_front
				_rarity_label.text = "%s %s" % [InventoryItem.rarity_name(mutation.rarity),
					InventoryItem.socket_name(mutation.socket_type)]
				_rarity_label.add_theme_color_override(&"font_color",
					InventoryItem.rarity_color(mutation.rarity))
				_stats_label.text = InventoryItem.stat_summary(mutation)
				tooltip_text = mutation.description
		&"human":
			_name_label.text = "Fresh Subject"
			_icon.texture = human_icon
			_rarity_label.text = "Human"
			_rarity_label.add_theme_color_override(&"font_color", plain_color)
			_stats_label.text = "A new human for your roster."
		&"stabilizer":
			_name_label.text = "Stabilizer"
			_rarity_label.text = "Consumable"
			_rarity_label.add_theme_color_override(&"font_color", plain_color)
			_stats_label.text = "+%d%% success on one operation." % Tuning.STABILIZER_BONUS
	_price_label.text = "%dg" % int(entry.get(&"price", 0))
	_buy_button.text = "Sold" if sold else "Buy"
	_buy_button.disabled = sold or block_reason != ""
	_buy_button.tooltip_text = "" if sold else block_reason
	modulate = sold_modulate if sold else Color.WHITE

## The Buy button, for focus handling.
func buy_button() -> Button:
	return _buy_button
