class_name FusionSlotRow
extends PanelContainer
## One body slot of an Incubator preview: what the slot becomes when two
## monsters are incubated (carried over / merged / the player chooses), with the
## controls for the player's choice. Display only: it reports the choice through
## `choice_changed` and the Incubator screen owns the choices dictionary.
## Also hosts the small keep-toggle helpers shared with the Lab splice UI.

## The player changed this slot's choice: an int (0 = parent A's part, 1 = B's)
## for a choose slot, an Array[int] of kept ability indices for a merge slot.
signal choice_changed(slot: StringName, value: Variant)

@export var color_carry: Color = Color(0.65, 0.82, 0.72, 1)
@export var color_merge: Color = Color(0.55, 1, 0.25, 1)
@export var color_choose: Color = Color(1, 0.85, 0.3, 1)
@export var color_name: Color = Color(0.9, 1, 0.92, 1)

@onready var _slot_label: Label = %SlotLabel
@onready var _kind_label: Label = %KindLabel
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _tag_label: Label = %TagLabel
@onready var _stat_label: Label = %StatLabel
@onready var _ability_label: Label = %AbilityLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _choose_row: HBoxContainer = %ChooseRow
@onready var _choose_a: Button = %ChooseA
@onready var _choose_b: Button = %ChooseB
@onready var _keep_row: HBoxContainer = %KeepRow

## Body slot this row describes.
var slot: StringName = &""
var _row: Dictionary = {}
var _choice: Variant = null
var _keep: Array[int] = []
var _keep_buttons: Array[Button] = []

func _ready() -> void:
	_keep_buttons.assign([%Keep0, %Keep1, %Keep2, %Keep3])
	for i: int in _keep_buttons.size():
		_keep_buttons[i].pressed.connect(_on_keep_pressed.bind(i))
	_choose_a.pressed.connect(_on_choose_pressed.bind(0))
	_choose_b.pressed.connect(_on_choose_pressed.bind(1))
	_apply()

## Shows one entry of FusionLogic.incubate_preview()[&"slots"] for `slot_name`.
## `choice` is the current entry of the choices dictionary for that slot (null =
## default). Safe to call before entering the tree.
func setup(slot_name: StringName, row: Dictionary, choice: Variant) -> void:
	slot = slot_name
	_row = row
	_choice = choice
	if is_node_ready():
		_apply()

# --- Shared helpers ---------------------------------------------------------------

## The default kept ability indices when `count` abilities are offered: the first
## Tuning.FUSION_MAX_ABILITIES (same default as FusionLogic.merge).
static func default_keep(count: int) -> Array[int]:
	var keep: Array[int] = []
	for i: int in mini(count, Tuning.FUSION_MAX_ABILITIES):
		keep.append(i)
	return keep

## `value` as a valid keep list for `count` offered abilities, or the default.
static func keep_from(value: Variant, count: int) -> Array[int]:
	var keep: Array[int] = []
	if value is Array:
		for v: Variant in value as Array:
			if (v is int or v is float) and int(v) >= 0 and int(v) < count \
					and not keep.has(int(v)) and keep.size() < Tuning.FUSION_MAX_ABILITIES:
				keep.append(int(v))
	if keep.size() < mini(count, Tuning.FUSION_MAX_ABILITIES):
		return default_keep(count)
	return keep

## The keep list after the player presses ability `index`: an already kept
## ability stays, a new one replaces the oldest pick.
static func toggled_keep(keep: Array[int], index: int) -> Array[int]:
	var result: Array[int] = keep.duplicate()
	if result.has(index):
		return result
	while result.size() >= Tuning.FUSION_MAX_ABILITIES and not result.is_empty():
		result.remove_at(0)
	result.append(index)
	return result

## Short button label for an ability ("Double Strike").
static func ability_label(ability: AbilityData) -> String:
	if ability == null:
		return "?"
	var id: String = String(ability.get_id())
	return id.capitalize() if id != "" else "Ability"

# --- Display ----------------------------------------------------------------------

func _apply() -> void:
	if _row.is_empty():
		return
	var kind: StringName = _row.get(&"kind", &"carry") as StringName
	var result: MutationData = _row.get(&"result") as MutationData
	var options: Array = _row.get(&"options", []) as Array
	_slot_label.text = String(slot).replace("_", " ")
	_choose_row.visible = kind == &"choose"
	_reason_label.visible = kind == &"choose"
	_keep_row.visible = false
	match kind:
		&"merge":
			_kind_label.text = "MERGE"
			_kind_label.add_theme_color_override(&"font_color", color_merge)
		&"choose":
			_kind_label.text = "CHOOSE"
			_kind_label.add_theme_color_override(&"font_color", color_choose)
		_:
			_kind_label.text = "CARRIED"
			_kind_label.add_theme_color_override(&"font_color", color_carry)
	if result != null:
		_icon.texture = result.sprite_front
		_name_label.text = result.display_name
		var tag: String = InventoryItem.fusion_tag(result)
		_tag_label.text = tag.to_upper()
		_tag_label.visible = tag != ""
		var tag_color: Color = InventoryItem.fusion_tag_color(result)
		_tag_label.add_theme_color_override(&"font_color", tag_color)
		_name_label.add_theme_color_override(&"font_color",
			tag_color if result.signature else color_name)
		_stat_label.text = FusionLogic.stat_line(result) if result.merge_count > 0 \
			else InventoryItem.stat_summary(result)
		var lines: PackedStringArray = InventoryItem.ability_lines(result)
		_ability_label.text = "\n".join(lines)
		_ability_label.visible = not lines.is_empty()
		tooltip_text = InventoryItem.mutation_tooltip(result)
	if kind == &"merge" and options.size() >= 2:
		_stat_label.text = "%s + %s\n%s" % [(options[0] as MutationData).display_name,
			(options[1] as MutationData).display_name, _stat_label.text]
		var offered: Array = _row.get(&"abilities", []) as Array
		if bool(_row.get(&"need_keep", false)):
			_keep = keep_from(_choice, offered.size())
			_keep_row.visible = true
			for i: int in _keep_buttons.size():
				_keep_buttons[i].visible = i < offered.size()
				if i < offered.size():
					_keep_buttons[i].text = ability_label(offered[i] as AbilityData)
					_keep_buttons[i].set_pressed_no_signal(_keep.has(i))
	elif kind == &"choose" and options.size() >= 2:
		var a: MutationData = options[0] as MutationData
		var b: MutationData = options[1] as MutationData
		var pick: int = 1 if (_choice is int or _choice is float) and int(_choice) == 1 else 0
		_choose_a.text = "A: %s" % a.display_name
		_choose_b.text = "B: %s" % b.display_name
		_choose_a.tooltip_text = InventoryItem.mutation_tooltip(a)
		_choose_b.tooltip_text = InventoryItem.mutation_tooltip(b)
		_choose_a.set_pressed_no_signal(pick == 0)
		_choose_b.set_pressed_no_signal(pick == 1)
		_reason_label.text = "Cannot merge: %s. Pick one to keep." % FusionLogic.block_reason(a, b)

func _on_choose_pressed(pick: int) -> void:
	_choose_a.set_pressed_no_signal(pick == 0)
	_choose_b.set_pressed_no_signal(pick == 1)
	choice_changed.emit(slot, pick)

func _on_keep_pressed(index: int) -> void:
	_keep = toggled_keep(_keep, index)
	for i: int in _keep_buttons.size():
		_keep_buttons[i].set_pressed_no_signal(_keep.has(i))
	choice_changed.emit(slot, _keep.duplicate())
