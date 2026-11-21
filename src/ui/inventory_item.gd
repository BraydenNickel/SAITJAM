class_name InventoryItem
extends Button
## Square icon button for one owned mutation (inventory strips in the Lab and
## Shop). Also hosts small static text/colour helpers shared by stage-3 UI.
## With `draggable` on (Lab), the mutation can be dragged onto a drop target;
## the payload is {kind = &"mutation", inv_index}. The named variant scene
## (inventory_item_named.tscn) adds a NameLabel under the icon.

const DRAG_PREVIEW_SCENE: PackedScene = preload("res://src/ui/drag_preview.tscn")

## Text colour per MutationData.Rarity (COMMON, UNCOMMON, RARE, ULTRA).
## ULTRA is hot magenta #ff3df0.
const RARITY_COLORS: Array[Color] = [
	Color(0.78, 0.95, 0.85, 1), Color(0.4, 0.75, 1, 1), Color(1, 0.6, 0.95, 1),
	Color(1, 0.239, 0.941, 1),
]
const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Ultra"]
## Badge colours of fused parts (see fusion_tag_color()).
const FUSION_COLOR_SIGNATURE: Color = Color(1, 0.239, 0.941, 1)
const FUSION_COLOR_APEX: Color = Color(1, 0.82, 0.25, 1)
const FUSION_COLOR_HYBRID: Color = Color(0.4, 0.75, 1, 1)

@onready var _icon: TextureRect = %Icon
@onready var _rarity_bar: ColorRect = %RarityBar
## Optional (only in the named variant scene).
@onready var _name_label: Label = get_node_or_null(^"%NameLabel") as Label

## The mutation can be dragged out of this button (Lab).
@export var draggable: bool = false

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
	tooltip_text = mutation_tooltip(mutation)
	if _name_label != null:
		_name_label.text = mutation.display_name
		_name_label.add_theme_color_override(&"font_color", rarity_color(mutation.rarity))

## Drag payload for this item: {kind = &"mutation", inv_index}; empty when the
## item is not draggable or shows nothing.
func drag_payload() -> Dictionary:
	if not draggable or mutation == null or inv_index < 0:
		return {}
	return {&"kind": &"mutation", &"inv_index": inv_index}

func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload: Dictionary = drag_payload()
	if payload.is_empty():
		return null
	var preview: DragPreview = DRAG_PREVIEW_SCENE.instantiate() as DragPreview
	preview.show_mutation(mutation)
	set_drag_preview(preview)
	return payload

## Fusion badge of a mutation: "Signature", "Apex", "Twin", "Hybrid", or "" for a
## base mutation (design/fusion-contract.md section 1).
static func fusion_tag(m: MutationData) -> String:
	if m == null or m.merge_count <= 0:
		return ""
	if m.merge_count >= Tuning.FUSION_MAX_MERGES:
		return "Apex"
	if m.signature:
		return "Signature"
	if m.parent_ids.size() == 2 and m.parent_ids[0] == m.parent_ids[1]:
		return "Twin"
	return "Hybrid"

## Display colour of fusion_tag(): Ultra magenta for a signature, gold for an
## apex, blue for the rest.
static func fusion_tag_color(m: MutationData) -> Color:
	if m != null and m.signature and m.merge_count < Tuning.FUSION_MAX_MERGES:
		return FUSION_COLOR_SIGNATURE
	if m != null and m.merge_count >= Tuning.FUSION_MAX_MERGES:
		return FUSION_COLOR_APEX
	return FUSION_COLOR_HYBRID

## One sentence per ability of `m`: a fused part's stored ability_texts, or the
## last line of a base mutation's description.
static func ability_lines(m: MutationData) -> PackedStringArray:
	var lines: PackedStringArray = []
	if m == null:
		return lines
	if m.merge_count > 0:
		for text: String in m.ability_texts:
			if text != "":
				lines.append(text)
		return lines
	if m.ability != null:
		var own: PackedStringArray = m.description.strip_edges().split("\n", false)
		if not own.is_empty():
			lines.append(own[own.size() - 1].strip_edges())
	return lines

## Tooltip for any mutation. A fused part leads with its badge and lists its
## parents, stat line and every ability line (they are in its description).
static func mutation_tooltip(m: MutationData) -> String:
	if m == null:
		return ""
	var tag: String = fusion_tag(m)
	if tag == "":
		return "%s (%s, %s)\n%s\n%s" % [m.display_name, rarity_name(m.rarity),
			socket_name(m.socket_type), stat_summary(m), m.description]
	return "%s [%s] (%s, %s)\n%s" % [m.display_name, tag, rarity_name(m.rarity),
		socket_name(m.socket_type), m.description]

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
