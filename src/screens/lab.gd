extends Control
## Lab screen. Operate mode: pick a living subject, a mutation from the
## inventory and a free body slot, then gamble on the success chance (a fail
## turns the subject into MUSH). Purge mode: pick an applied slot and pay to
## remove that mutation. All rules live in LabLogic; this screen only displays
## and forwards choices.

enum Mode { OPERATE, PURGE }

const SUBJECT_SCENE: PackedScene = preload("res://src/ui/subject_button.tscn")
const ITEM_SCENE: PackedScene = preload("res://src/ui/inventory_item.tscn")

## Seconds for the full-screen flash after an operation.
@export var flash_time: float = 0.45
## Peak alpha of that flash.
@export var flash_alpha: float = 0.45
## Success % at or above this shows green.
@export var chance_good: int = 70
## Success % at or above this (and below chance_good) shows yellow; below is red.
@export var chance_ok: int = 40
@export var color_good: Color = Color(0.55, 1, 0.25, 1)
@export var color_ok: Color = Color(1, 0.85, 0.3, 1)
@export var color_bad: Color = Color(1, 0.4, 0.35, 1)
@export var color_mush: Color = Color(0.7, 0.4, 0.9, 1)

@onready var _gold_label: Label = %GoldLabel
@onready var _stab_label: Label = %StabLabel
@onready var _buffs_label: Label = %BuffsLabel
@onready var _subject_list: VBoxContainer = %SubjectList
@onready var _preview_view: MonsterView = %PreviewView
@onready var _ghost_part: Sprite2D = %GhostPart
@onready var _no_subject_label: Label = %NoSubjectLabel
@onready var _slot_grid: GridContainer = %SlotGrid
@onready var _selection_label: Label = %SelectionLabel
@onready var _operate_mode_button: Button = %OperateModeButton
@onready var _purge_mode_button: Button = %PurgeModeButton
@onready var _inv_title: Label = %InvTitle
@onready var _inv_scroll: ScrollContainer = %InvScroll
@onready var _inventory_row: HBoxContainer = %InventoryRow
@onready var _inv_empty_label: Label = %InvEmptyLabel
@onready var _chance_box: Control = %ChanceBox
@onready var _chance_label: Label = %ChanceLabel
@onready var _breakdown_names: Label = %BreakdownNames
@onready var _breakdown_values: Label = %BreakdownValues
@onready var _stab_spin: SpinBox = %StabSpin
@onready var _purge_info_label: Label = %PurgeInfoLabel
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _flash: ColorRect = %Flash
@onready var _result_layer: Control = %ResultLayer
@onready var _result_title: Label = %ResultTitle
@onready var _result_jar: TextureRect = %ResultJar
@onready var _result_holder: Node2D = %ResultHolder
@onready var _result_monster: MonsterView = %ResultMonster
@onready var _result_body: Label = %ResultBody
@onready var _result_ok_button: Button = %ResultOkButton

var _mode: Mode = Mode.OPERATE
## Selected roster index (-1 = none).
var _roster_idx: int = -1
## Selected inventory index (-1 = none).
var _inv_idx: int = -1
## Selected body slot (&"" = none).
var _slot: StringName = &""
## Slot name -> its Button in SlotGrid.
var _slot_buttons: Dictionary = {}
var _subject_group: ButtonGroup = ButtonGroup.new()
var _inv_group: ButtonGroup = ButtonGroup.new()

func _ready() -> void:
	Game.ensure_run()
	for child: Node in _slot_grid.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var slot: StringName = StringName(button.name)
		_slot_buttons[slot] = button
		button.toggled.connect(_on_slot_toggled.bind(slot))
	_operate_mode_button.pressed.connect(_set_mode.bind(Mode.OPERATE))
	_purge_mode_button.pressed.connect(_set_mode.bind(Mode.PURGE))
	_stab_spin.value_changed.connect(func(_v: float) -> void: _refresh())
	_back_button.pressed.connect(func() -> void: Game.go_to(&"hub"))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_result_ok_button.pressed.connect(_on_result_ok_pressed)
	Game.gold_changed.connect(func(_g: int) -> void: _refresh_header())
	_result_layer.visible = false
	_flash.color.a = 0.0
	_status_label.text = ""
	_rebuild_subjects()
	_rebuild_inventory()
	_refresh()
	_back_button.grab_focus()

# --- Lists ------------------------------------------------------------------

func _rebuild_subjects() -> void:
	for child: Node in _subject_list.get_children():
		_subject_list.remove_child(child)
		child.queue_free()
	var roster: Array[MonsterData] = Game.run.roster
	if _roster_idx < 0 or _roster_idx >= roster.size() or roster[_roster_idx].mushed:
		_roster_idx = -1
	for i: int in roster.size():
		var monster: MonsterData = roster[i]
		if monster.mushed:
			continue
		if _roster_idx < 0:
			_roster_idx = i
		var button: SubjectButton = SUBJECT_SCENE.instantiate() as SubjectButton
		button.button_group = _subject_group
		_subject_list.add_child(button)
		button.setup(monster, i)
		button.set_pressed_no_signal(i == _roster_idx)
		button.pressed.connect(_on_subject_pressed.bind(i))

func _rebuild_inventory() -> void:
	for child: Node in _inventory_row.get_children():
		_inventory_row.remove_child(child)
		child.queue_free()
	var inventory: Array[MutationData] = Game.run.inventory
	if _inv_idx >= inventory.size():
		_inv_idx = -1
	for i: int in inventory.size():
		var item: InventoryItem = ITEM_SCENE.instantiate() as InventoryItem
		item.toggle_mode = true
		item.button_group = _inv_group
		_inventory_row.add_child(item)
		item.setup(inventory[i], i)
		item.set_pressed_no_signal(i == _inv_idx)
		item.pressed.connect(_on_inventory_pressed.bind(i))

func _refresh_subject_buttons() -> void:
	for child: Node in _subject_list.get_children():
		var button: SubjectButton = child as SubjectButton
		if button != null:
			button.refresh()

# --- Input --------------------------------------------------------------------

func _set_mode(mode: Mode) -> void:
	if _mode == mode:
		return
	_mode = mode
	_slot = &""
	_status_label.text = ""
	_refresh()

func _on_subject_pressed(roster_idx: int) -> void:
	_roster_idx = roster_idx
	_slot = &""
	_status_label.text = ""
	_auto_pick_slot()
	_refresh()

func _on_inventory_pressed(inv_idx: int) -> void:
	_inv_idx = inv_idx
	_slot = &""
	_status_label.text = ""
	_auto_pick_slot()
	_refresh()

func _on_slot_toggled(on: bool, slot: StringName) -> void:
	if on:
		_slot = slot
	elif _slot == slot:
		_slot = &""
	_status_label.text = ""
	_refresh()

## In operate mode, pre-selects the first free slot that fits the mutation.
func _auto_pick_slot() -> void:
	if _mode != Mode.OPERATE:
		return
	var valid: Array[StringName] = _valid_slots()
	if not valid.is_empty():
		_slot = valid[0]

func _on_confirm_pressed() -> void:
	var monster: MonsterData = _selected_monster()
	if monster == null or _slot == &"":
		return
	if _mode == Mode.PURGE:
		var purged: MutationData = monster.slots.get(_slot) as MutationData
		if LabLogic.purge(Game.run, _roster_idx, _slot):
			Game.notify_gold()
			_status_label.text = "Purged %s. It is back in your inventory." % (
				purged.display_name if purged != null else "the mutation")
			_slot = &""
			_rebuild_inventory()
			_refresh_subject_buttons()
		else:
			_status_label.text = "Purge failed."
		_refresh()
		return
	var mutation: MutationData = _selected_mutation()
	if mutation == null:
		return
	var result: Dictionary = LabLogic.operate(Game.run, _roster_idx, _inv_idx, _slot,
		int(_stab_spin.value), Game.rng)
	Game.notify_gold()
	if not bool(result.get(&"ok", false)):
		_status_label.text = String(result.get(&"reason", "The operation could not start."))
		_refresh()
		return
	_inv_idx = -1
	_slot = &""
	_show_result(result, monster, mutation)

func _on_result_ok_pressed() -> void:
	_result_layer.visible = false
	_rebuild_subjects()
	_rebuild_inventory()
	_auto_pick_slot()
	_refresh()
	_confirm_button.grab_focus()

# --- Result -----------------------------------------------------------------

func _show_result(result: Dictionary, monster: MonsterData, mutation: MutationData) -> void:
	var chance: int = int(result.get(&"chance", 0))
	var roll: int = int(result.get(&"roll", 0))
	var refund: int = int(result.get(&"refund", 0))
	var roll_text: String = "Chance %d%%, rolled %d." % [chance, roll]
	var mushed: bool = bool(result.get(&"mushed", false))
	_result_jar.visible = mushed
	_result_holder.visible = not mushed
	_result_monster.data = monster
	_result_monster.refresh()
	var flash_color: Color = color_good
	if bool(result.get(&"success", false)):
		_result_title.text = "SUCCESS!"
		_result_title.add_theme_color_override(&"font_color", color_good)
		_result_body.text = "%s now has %s.\n%s" % [monster.display_name,
			mutation.display_name, roll_text]
	elif mushed:
		flash_color = color_mush
		_result_title.text = "MUSH!"
		_result_title.add_theme_color_override(&"font_color", color_mush)
		_result_body.text = "%s dissolved into mush and is retired.\n%s\nRefund +%dg   +%d%% Mush Memory on your next operation." % [
			monster.display_name, roll_text, refund, Tuning.MUSH_MEMORY_BONUS]
	else:
		flash_color = color_ok
		_result_title.text = "FAILED, BUT INSURED"
		_result_title.add_theme_color_override(&"font_color", color_ok)
		var refund_text: String = "\nRefund +%dg" % refund if refund > 0 else ""
		_result_body.text = "Insurance kept %s from turning to mush.\n%s%s" % [
			monster.display_name, roll_text, refund_text]
	_result_layer.visible = true
	_result_ok_button.grab_focus()
	_play_flash(flash_color)
	_refresh_header()

func _play_flash(color: Color) -> void:
	var start: Color = color
	start.a = flash_alpha
	_flash.color = start
	var end: Color = color
	end.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color", end, flash_time)

# --- Display ----------------------------------------------------------------

func _selected_monster() -> MonsterData:
	var roster: Array[MonsterData] = Game.run.roster
	if _roster_idx < 0 or _roster_idx >= roster.size():
		return null
	var monster: MonsterData = roster[_roster_idx]
	return null if monster.mushed else monster

func _selected_mutation() -> MutationData:
	var inventory: Array[MutationData] = Game.run.inventory
	if _inv_idx < 0 or _inv_idx >= inventory.size():
		return null
	return inventory[_inv_idx]

func _valid_slots() -> Array[StringName]:
	var monster: MonsterData = _selected_monster()
	var mutation: MutationData = _selected_mutation()
	if monster == null or mutation == null:
		return []
	return monster.slots_for(mutation)

func _refresh_header() -> void:
	_gold_label.text = "Gold: %d" % Game.run.gold
	_stab_label.text = "Stabilizers: %d" % Game.run.stabilizers
	var buffs: PackedStringArray = []
	if Game.run.lucky_gene:
		buffs.append("Lucky Gene")
	if Game.run.insurance:
		buffs.append("Insurance")
	if Game.run.catalyst:
		buffs.append("Catalyst")
	if Game.run.mush_memory > 0:
		buffs.append("Mush Memory +%d%%" % Game.run.mush_memory)
	_buffs_label.text = "Next operation: " + ", ".join(buffs) if not buffs.is_empty() else ""

func _refresh() -> void:
	_refresh_header()
	var monster: MonsterData = _selected_monster()
	var mutation: MutationData = _selected_mutation()
	var operate: bool = _mode == Mode.OPERATE
	_operate_mode_button.set_pressed_no_signal(operate)
	_purge_mode_button.set_pressed_no_signal(not operate)
	# Preview
	_no_subject_label.visible = monster == null
	_preview_view.visible = monster != null
	_preview_view.data = monster
	# Inventory (operate only)
	var has_inventory: bool = not Game.run.inventory.is_empty()
	_inv_title.visible = operate
	_inv_scroll.visible = operate and has_inventory
	_inv_empty_label.visible = operate and not has_inventory
	_chance_box.visible = operate
	_purge_info_label.visible = not operate
	# Slots
	var valid: Array[StringName] = _valid_slots()
	if operate and _slot != &"" and not valid.has(_slot):
		_slot = &""
	if not operate and (monster == null or monster.slots.get(_slot) == null):
		_slot = &""
	for key: Variant in _slot_buttons.keys():
		var slot: StringName = key as StringName
		var button: Button = _slot_buttons[slot] as Button
		var occupant: MutationData = monster.slots.get(slot) as MutationData if monster != null else null
		button.disabled = not valid.has(slot) if operate else occupant == null
		button.set_pressed_no_signal(slot == _slot)
		button.tooltip_text = occupant.display_name if occupant != null else "Empty"
	_refresh_ghost(mutation if operate else null)
	if operate:
		_refresh_operate(monster, mutation, valid)
	else:
		_refresh_purge(monster)

func _refresh_ghost(mutation: MutationData) -> void:
	var marker: Marker2D = null
	if mutation != null and _slot != &"":
		marker = _preview_view.get_node_or_null(NodePath("Sockets/" + String(_slot))) as Marker2D
	_ghost_part.visible = marker != null and _preview_view.visible
	if marker == null:
		return
	_ghost_part.texture = mutation.sprite_front
	_ghost_part.position = _preview_view.position + marker.position
	_ghost_part.z_index = marker.z_index
	_ghost_part.flip_h = String(_slot).ends_with("_R")

func _refresh_operate(monster: MonsterData, mutation: MutationData,
		valid: Array[StringName]) -> void:
	var max_stabs: int = mini(Tuning.STABILIZER_MAX, Game.run.stabilizers)
	_stab_spin.max_value = max_stabs
	_stab_spin.editable = max_stabs > 0
	if _stab_spin.value > max_stabs:
		_stab_spin.set_value_no_signal(max_stabs)
	var can_operate: bool = monster != null and mutation != null and _slot != &""
	_confirm_button.disabled = not can_operate
	if mutation == null:
		_selection_label.text = "Pick a mutation from your inventory." if monster != null else ""
	elif valid.is_empty():
		_selection_label.text = "%s (%s) has no free %s slot on %s." % [mutation.display_name,
			InventoryItem.socket_name(mutation.socket_type),
			InventoryItem.socket_name(mutation.socket_type), monster.display_name]
	else:
		_selection_label.text = "%s -> %s\n%s\n+%d instability on success" % [
			mutation.display_name, String(_slot).replace("_", " ") if _slot != &"" else "?",
			InventoryItem.stat_summary(mutation),
			Tuning.INSTABILITY_PER_RARITY[mutation.rarity]]
	if not can_operate:
		_chance_label.text = "--"
		_chance_label.add_theme_color_override(&"font_color", color_ok)
		_breakdown_names.text = ""
		_breakdown_values.text = ""
		_confirm_button.text = "Operate"
		return
	var stabs: int = int(_stab_spin.value)
	var chance: int = LabLogic.success_chance(Game.run, monster, mutation, stabs)
	_chance_label.text = "%d%%" % chance
	_chance_label.add_theme_color_override(&"font_color", _chance_color(chance))
	_confirm_button.text = "Operate (%d%%)" % chance
	var names: PackedStringArray = []
	var values: PackedStringArray = []
	for row: Dictionary in LabLogic.chance_breakdown(Game.run, monster, mutation, stabs):
		names.append(String(row.get(&"label", "")))
		values.append("%+d" % int(row.get(&"value", 0)))
	_breakdown_names.text = "\n".join(names)
	_breakdown_values.text = "\n".join(values)

func _refresh_purge(monster: MonsterData) -> void:
	var occupant: MutationData = null
	if monster != null and _slot != &"":
		occupant = monster.slots.get(_slot) as MutationData
	_selection_label.text = ""
	if monster == null:
		_purge_info_label.text = "No living subjects."
	elif monster.slots.is_empty():
		_purge_info_label.text = "%s has no mutations to purge." % monster.display_name
	elif occupant == null:
		_purge_info_label.text = "Pick an applied body slot to purge.\n\nCost: %dg\nInstability -%d\nThe mutation goes back to your inventory." % [
			Tuning.PURGE_COST, Tuning.PURGE_INSTABILITY]
	else:
		_purge_info_label.text = "Purge %s from %s?\n\nCost: %dg\nInstability -%d\nThe mutation goes back to your inventory." % [
			occupant.display_name, String(_slot).replace("_", " "),
			Tuning.PURGE_COST, Tuning.PURGE_INSTABILITY]
	var affordable: bool = Game.run.gold >= Tuning.PURGE_COST
	_confirm_button.disabled = occupant == null or not affordable
	_confirm_button.text = "Purge (%dg)" % Tuning.PURGE_COST
	_confirm_button.tooltip_text = "" if affordable else "Not enough gold"

func _chance_color(chance: int) -> Color:
	if chance >= chance_good:
		return color_good
	if chance >= chance_ok:
		return color_ok
	return color_bad
