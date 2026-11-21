extends Control
## Lab screen. Operate mode: pick a living subject, a mutation from the
## inventory and a free body slot, then gamble on the success chance (a fail
## turns the subject into MUSH). Purge mode: pick an applied slot and pay to
## remove that mutation. All rules live in LabLogic; this screen only displays
## and forwards choices.

enum Mode { OPERATE, PURGE }

const SUBJECT_SCENE: PackedScene = preload("res://src/ui/subject_button.tscn")
const ITEM_SCENE: PackedScene = preload("res://src/ui/inventory_item.tscn")
const LAST_MONSTER_WARNING: String = "Failure ends the run: this is your last monster."

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
@onready var _result_fx: Node2D = %ResultFx
@onready var _sfx: SfxPlayer = %Sfx
@onready var _keep_row: HBoxContainer = %KeepRow
@onready var _result_part: TextureRect = %ResultPart

## Font colour of a slot button whose part the picked mutation would SPLICE into.
@export var color_splice: Color = Color(0.85, 0.6, 1, 1)

## Line spacing of the selection text while it shows a splice preview.
@export var splice_line_spacing: int = -4

## Kept ability indices for a splice that offers more abilities than allowed
## (FusionLogic.ability_choices order); empty = default.
var _keep: Array[int] = []
var _keep_buttons: Array[Button] = []
## True after a failure mushed the last living monster: OK then ends the run.
var _run_over: bool = false
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
	_keep_buttons.assign([%Keep0, %Keep1, %Keep2, %Keep3])
	for i: int in _keep_buttons.size():
		_keep_buttons[i].pressed.connect(_on_keep_pressed.bind(i))
	_operate_mode_button.pressed.connect(_set_mode.bind(Mode.OPERATE))
	_purge_mode_button.pressed.connect(_set_mode.bind(Mode.PURGE))
	_stab_spin.value_changed.connect(func(_v: float) -> void: _refresh())
	_back_button.pressed.connect(func() -> void: Game.go_to(&"hub"))
	_back_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_operate_mode_button.pressed.connect(_sfx.play.bind(&"click"))
	_purge_mode_button.pressed.connect(_sfx.play.bind(&"click"))
	_result_ok_button.pressed.connect(_sfx.play.bind(&"click"))
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
	_keep = []
	_status_label.text = ""
	_refresh()

func _on_subject_pressed(roster_idx: int) -> void:
	_roster_idx = roster_idx
	_slot = &""
	_keep = []
	_status_label.text = ""
	_auto_pick_slot()
	_refresh()

func _on_inventory_pressed(inv_idx: int) -> void:
	_inv_idx = inv_idx
	_slot = &""
	_keep = []
	_status_label.text = ""
	_auto_pick_slot()
	_refresh()

func _on_slot_toggled(on: bool, slot: StringName) -> void:
	if on:
		_slot = slot
	elif _slot == slot:
		# Pressing another slot un-presses this one first: that button is already
		# down and its own signal follows, so the selection must not be cleared
		# (a refresh here would un-press the new button again).
		var taking_over: BaseButton = (_slot_buttons[slot] as Button).button_group.get_pressed_button()
		if taking_over != null and taking_over != _slot_buttons[slot]:
			return
		_slot = &""
	_keep = []
	_status_label.text = ""
	_refresh()

func _on_keep_pressed(index: int) -> void:
	_keep = FusionSlotRow.toggled_keep(_keep, index)
	_sfx.play(&"click")
	_refresh()

## In operate mode, pre-selects the first free slot that fits the mutation; a
## splice slot is only pre-selected when no free slot fits.
func _auto_pick_slot() -> void:
	if _mode != Mode.OPERATE:
		return
	var monster: MonsterData = _selected_monster()
	var mutation: MutationData = _selected_mutation()
	if monster != null and mutation != null:
		var free: Array[StringName] = monster.slots_for(mutation)
		if not free.is_empty():
			_slot = free[0]
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
			_sfx.play(&"purchase")
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
		int(_stab_spin.value), Game.rng, _keep)
	Game.notify_gold()
	if not bool(result.get(&"ok", false)):
		_status_label.text = String(result.get(&"reason", "The operation could not start."))
		_refresh()
		return
	_inv_idx = -1
	_slot = &""
	_keep = []
	_show_result(result, monster, mutation)

func _on_result_ok_pressed() -> void:
	if _run_over:
		_sfx.play_detached(&"click")
		Game.end_run_lost()
		return
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
	# A successful splice leaves a fused part in the slot; first-ever
	# discoveries go to the persistent Codex.
	var fused: MutationData = null
	if bool(result.get(&"spliced", false)):
		fused = result.get(&"result") as MutationData
	var fresh: Array[Dictionary] = CodexStore.record(result.get(&"new_codex", []) as Array)
	_result_part.visible = false
	if bool(result.get(&"success", false)):
		_play_result_fx(&"mutate_success")
		if mutation.rarity == MutationData.Rarity.ULTRA \
				or (fused != null and (fused.signature or not fresh.is_empty())):
			_play_result_fx(&"ultra_reveal")
		_result_title.text = "SUCCESS!"
		_result_title.add_theme_color_override(&"font_color", color_good)
		_result_body.text = "%s now has %s.\n%s" % [monster.display_name,
			mutation.display_name, roll_text]
		if fused != null:
			_result_part.texture = fused.sprite_front
			_result_part.tooltip_text = InventoryItem.mutation_tooltip(fused)
			_result_part.visible = true
			_result_title.text = "SPLICED!"
			_result_title.add_theme_color_override(&"font_color",
				InventoryItem.fusion_tag_color(fused) if fused.signature else color_good)
			var lines: PackedStringArray = ["%s grew %s [%s].%s" % [monster.display_name,
				fused.display_name, InventoryItem.fusion_tag(fused).to_upper(),
				"  NEW in the Codex!" if not fresh.is_empty() else ""],
				FusionLogic.stat_line(fused)]
			lines.append_array(InventoryItem.ability_lines(fused))
			lines.append(roll_text)
			_result_body.text = "\n".join(lines)
	elif mushed:
		flash_color = color_mush
		_play_result_fx(&"mush")
		_result_title.text = "MUSH!"
		_result_title.add_theme_color_override(&"font_color", color_mush)
		_result_body.text = "%s dissolved into mush and is retired.\n%s\nRefund +%dg   +%d%% Mush Memory on your next operation." % [
			monster.display_name, roll_text, refund, Tuning.MUSH_MEMORY_BONUS]
		# Nobody left to fight with: the run is lost, like a lost battle.
		if Game.run.living_count() <= 0:
			_run_over = true
			_result_body.text = "%s dissolved into mush.
%s
No living monster is left. The run is over." % [
				monster.display_name, roll_text]
			_result_ok_button.text = "End run"
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

## Plays the event effect `key` on the result subject (the ResultFx anchor in
## the scene) together with the sound of the same name.
func _play_result_fx(key: StringName) -> void:
	PixelFxPlayer.spawn(_result_fx, FxLibrary.event_fx(key), _result_fx.global_position)
	_sfx.play(key)

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
	return LabLogic.operable_slots(monster, mutation)

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
		var splice: bool = operate and LabLogic.can_splice(monster, mutation, slot)
		for color_name: StringName in [&"font_color", &"font_hover_color",
				&"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
			if splice:
				button.add_theme_color_override(color_name, color_splice)
			else:
				button.remove_theme_color_override(color_name)
		if occupant == null:
			button.tooltip_text = "Empty"
		elif splice:
			button.tooltip_text = "SPLICE with %s" % occupant.display_name
		else:
			var tag: String = InventoryItem.fusion_tag(occupant)
			button.tooltip_text = occupant.display_name + (" [%s]" % tag if tag != "" else "")
			if operate and mutation != null \
					and MonsterData.SLOT_SOCKET[slot] == mutation.socket_type:
				button.tooltip_text += "\nCannot splice: %s" % LabLogic.slot_block_reason(
					monster, mutation, slot)
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
	# A splice previews the fused part it would leave in the slot.
	var fused: MutationData = LabLogic.splice_preview(_selected_monster(), mutation, _slot, _keep)
	_ghost_part.texture = fused.sprite_front if fused != null else mutation.sprite_front
	# Follow the socket where it really is: a body override scales and shifts
	# the sockets, and the view sits on its own z layer.
	var holder: Node2D = _ghost_part.get_parent() as Node2D
	_ghost_part.position = holder.to_local(marker.global_position)
	_ghost_part.z_index = _preview_view.z_index + marker.z_index
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
	# Splice: the slot is occupied and the two parts merge into a fused one.
	var existing: MutationData = null
	var fused: MutationData = null
	var offered: Array[AbilityData] = []
	if can_operate and LabLogic.can_splice(monster, mutation, _slot):
		existing = monster.slots.get(_slot) as MutationData
		offered = FusionLogic.ability_choices(existing, mutation)
	var need_keep: bool = offered.size() > Tuning.FUSION_MAX_ABILITIES
	_keep_row.visible = need_keep
	# The keep row sits under the breakdown: tighten the rows so six still fit.
	for label: Label in [_breakdown_names, _breakdown_values]:
		if need_keep:
			label.add_theme_constant_override(&"line_spacing", splice_line_spacing)
		else:
			label.remove_theme_constant_override(&"line_spacing")
	if need_keep:
		_keep = FusionSlotRow.keep_from(_keep, offered.size())
		for i: int in _keep_buttons.size():
			_keep_buttons[i].visible = i < offered.size()
			if i < offered.size():
				_keep_buttons[i].text = FusionSlotRow.ability_label(offered[i])
				_keep_buttons[i].set_pressed_no_signal(_keep.has(i))
	else:
		_keep = []
	if existing != null:
		fused = LabLogic.splice_preview(monster, mutation, _slot, _keep)
	_selection_label.tooltip_text = InventoryItem.mutation_tooltip(fused)
	# The splice text has five lines: tighten them so they fit above the buttons.
	if fused != null:
		_selection_label.add_theme_constant_override(&"line_spacing", splice_line_spacing)
	else:
		_selection_label.remove_theme_constant_override(&"line_spacing")
	if fused != null and fused.signature:
		_selection_label.add_theme_color_override(&"font_color",
			InventoryItem.fusion_tag_color(fused))
	else:
		_selection_label.remove_theme_color_override(&"font_color")
	if mutation == null:
		_selection_label.text = "Pick a mutation from your inventory." if monster != null else ""
	elif valid.is_empty():
		_selection_label.text = "%s (%s) has no free %s slot on %s." % [mutation.display_name,
			InventoryItem.socket_name(mutation.socket_type),
			InventoryItem.socket_name(mutation.socket_type), monster.display_name]
		for slot: StringName in MonsterData.SLOTS:
			var why: String = LabLogic.slot_block_reason(monster, mutation, slot)
			if MonsterData.SLOT_SOCKET[slot] == mutation.socket_type and why != "":
				_selection_label.text += "\n%s: %s." % [String(slot).replace("_", " "), why]
	elif fused != null:
		_selection_label.text = "SPLICE into %s  (+%d instability)\n%s + %s\n= %s  [%s]\n%s\n%s" % [
			String(_slot).replace("_", " "), Tuning.INSTABILITY_PER_RARITY[mutation.rarity],
			existing.display_name, mutation.display_name, fused.display_name,
			InventoryItem.fusion_tag(fused).to_upper(), FusionLogic.stat_line(fused),
			" | ".join(InventoryItem.ability_lines(fused))]
	else:
		_selection_label.text = "%s -> %s\n%s\n+%d instability on success" % [
			mutation.display_name, String(_slot).replace("_", " ") if _slot != &"" else "?",
			InventoryItem.stat_summary(mutation),
			Tuning.INSTABILITY_PER_RARITY[mutation.rarity]]
	if _status_label.text == LAST_MONSTER_WARNING:
		_status_label.text = ""
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
	_confirm_button.text = ("Splice (%d%%)" if fused != null else "Operate (%d%%)") % chance
	# A failure mushes the subject: warn when it is the last one alive.
	if Game.run.living_count() <= 1 and not Game.run.insurance and chance < Tuning.MAX_SUCCESS:
		_status_label.text = LAST_MONSTER_WARNING
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
