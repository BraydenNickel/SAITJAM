class_name InventoryItem
extends Button
## Square icon button for one owned mutation (inventory strips in the Lab and
## Shop). Also hosts small static text/colour helpers shared by stage-3 UI.

## Text colour per MutationData.Rarity (COMMON, UNCOMMON, RARE).
const RARITY_COLORS: Array[Color] = [
	Color(0.78, 0.95, 0.85, 1), Color(0.4, 0.75, 1, 1), Color(1, 0.6, 0.95, 1),
]
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare"]

@onready var _icon: TextureRect = %Icon
@onready var _rarity_bar: ColorRect = %RarityBar

## The mutation shown, or null.
var mutation: MutationData
## Index of the mutation in RunState.inventory.
var inv_index: int = -1

func _ready() -> void:
	_apply()

## Shows `m` (inventory index `index`). Safe to call before entering the tree.
func setup(m: MutationData, index: int) -> void:
	mutation = m
	inv_index = index
	if is_node_ready():
		_apply()

func _apply() -> void:
	if mutation == null:
		return
	_icon.texture = mutation.sprite_front
	_rarity_bar.color = rarity_color(mutation.rarity)
	tooltip_text = "%s (%s, %s)\n%s\n%s" % [mutation.display_name, rarity_name(mutation.rarity),
		socket_name(mutation.socket_type), stat_summary(mutation), mutation.description]

## Display colour for a MutationData.Rarity value.
static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]

## Display name for a MutationData.Rarity value.
static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]

## Display name for a MutationData.SocketType value ("ARM", "HEAD", ...).
static func socket_name(socket_type: int) -> String:
	return String(MutationData.SocketType.find_key(socket_type))

## Short stat line, e.g. "+20 HP  +3 ATK  -0.2s".
static func stat_summary(m: MutationData) -> String:
	if m == null:
		return ""
	var parts: PackedStringArray = []
	if not is_zero_approx(m.hp_mod):
		parts.append("%+d HP" % roundi(m.hp_mod))
	if not is_zero_approx(m.atk_mod):
		parts.append("%+d ATK" % roundi(m.atk_mod))
	if not is_zero_approx(m.interval_mod):
		parts.append("%+.2fs SPD" % m.interval_mod)
	if not is_zero_approx(m.defense_mod):
		parts.append("%+d DEF" % roundi(m.defense_mod))
	if not is_zero_approx(m.crit_mod):
		parts.append("%+d%% CRIT" % roundi(m.crit_mod * 100.0))
	return "  ".join(parts) if not parts.is_empty() else "No stat change"
