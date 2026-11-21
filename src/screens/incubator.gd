extends Control
## Incubator screen: pick two living monsters (parent A and parent B), see what
## every body slot becomes (carried over / merged / pick one), tune the odds with
## stabilizers, then gamble on the success chance. A fail turns BOTH parents into
## mush. All rules live in FusionLogic; this screen only displays and forwards
## choices (design/fusion-contract.md).

const SUBJECT_SCENE: PackedScene = preload("res://src/ui/subject_button.tscn")
const ROW_SCENE: PackedScene = preload("res://src/ui/fusion_slot_row.tscn")

## Seconds for the full-screen flash after an incubation.
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
@onready var _a_list: VBoxContainer = %AList
@onready var _b_list: VBoxContainer = %BList
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _slots_empty_label: Label = %SlotsEmptyLabel
@onready var _parent_a_view: MonsterView = %ParentAView
@onready var _parent_b_view: MonsterView = %ParentBView
@onready var _preview_view: MonsterView = %PreviewView
@onready var _preview_title: Label = %PreviewTitle
@onready var _preview_stats: Label = %PreviewStats
@onready var _chance_label: Label = %ChanceLabel
@onready var _breakdown_names: Label = %BreakdownNames
@onready var _breakdown_values: Label = %BreakdownValues
@onready var _stab_spin: SpinBox = %StabSpin
@onready var _cost_label: Label = %CostLabel
@onready var _warning_label: Label = %WarningLabel
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _flash: ColorRect = %Flash
@onready var _result_layer: Control = %ResultLayer
@onready var _result_title: Label = %ResultTitle
@onready var _result_subtitle: Label = %ResultSubtitle
@onready var _result_jar_a: TextureRect = %ResultJarA
@onready var _result_jar_b: TextureRect = %ResultJarB
@onready var _result_holder: Node2D = %ResultHolder
@onready var _result_monster: MonsterView = %ResultMonster
@onready var _result_new: Label = %ResultNew
@onready var _result_body: Label = %ResultBody
@onready var _result_ok_button: Button = %ResultOkButton
@onready var _result_fx: Node2D = %ResultFx
@onready var _sfx: SfxPlayer = %Sfx

## Roster index of parent A (-1 = none). The fused monster takes A's place.
var _a_idx: int = -1
## Roster index of parent B (-1 = none).
var _b_idx: int = -1
## Slot -> the player's choice, as FusionLogic.incubate() takes it.
var _choices: Dictionary = {}
## True after a failure left no living monster: OK then ends the run.
var _run_over: bool = false
var _a_group: ButtonGroup = ButtonGroup.new()
var _b_group: ButtonGroup = ButtonGroup.new()

func _ready() -> void:
	Game.ensure_run()
	_stab_spin.value_changed.connect(func(_v: float) -> void: _refresh())
	_back_button.pressed.connect(func() -> void: Game.go_to(&"hub"))
	_back_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_result_ok_button.pressed.connect(_on_result_ok_pressed)
	Game.gold_changed.connect(func(_g: int) -> void: _refresh_header())
	_result_layer.visible = false
	_flash.color.a = 0.0
	_status_label.text = ""
	_pick_defaults()
	_rebuild_parents()
	_refresh()
	_back_button.grab_focus()

# --- Parents ------------------------------------------------------------------

func _living_indices() -> Array[int]:
	var result: Array[int] = []
	for i: int in Game.run.roster.size():
		if not Game.run.roster[i].mushed:
			result.append(i)
	return result

## Keeps valid picks and fills empty ones with the first living monsters.
func _pick_defaults() -> void:
	var living: Array[int] = _living_indices()
	if not living.has(_a_idx):
		_a_idx = -1
	if not living.has(_b_idx) or _b_idx == _a_idx:
		_b_idx = -1
	for i: int in living:
		if _a_idx < 0 and i != _b_idx:
			_a_idx = i
		elif _b_idx < 0 and i != _a_idx:
			_b_idx = i

func _rebuild_parents() -> void:
	_fill_list(_a_list, _a_group, _a_idx, _b_idx, _on_parent_a_pressed)
	_fill_list(_b_list, _b_group, _b_idx, _a_idx, _on_parent_b_pressed)

func _fill_list(list: VBoxContainer, group: ButtonGroup, picked: int, taken: int,
		handler: Callable) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for i: int in _living_indices():
		var button: SubjectButton = SUBJECT_SCENE.instantiate() as SubjectButton
		button.button_group = group
		list.add_child(button)
		button.setup(Game.run.roster[i], i)
		button.set_pressed_no_signal(i == picked)
		button.disabled = i == taken
		button.tooltip_text = "Already picked as the other parent" if i == taken else ""
		button.pressed.connect(handler.bind(i))

func _on_parent_a_pressed(roster_idx: int) -> void:
	_a_idx = roster_idx
	_parents_changed()

func _on_parent_b_pressed(roster_idx: int) -> void:
	_b_idx = roster_idx
	_parents_changed()

func _parents_changed() -> void:
	_choices = {}
	_status_label.text = ""
	_sfx.play(&"click")
	_rebuild_parents.call_deferred()
	_refresh.call_deferred()

func _monster_at(idx: int) -> MonsterData:
	var roster: Array[MonsterData] = Game.run.roster
	if idx < 0 or idx >= roster.size() or roster[idx].mushed:
		return null
	return roster[idx]

# --- Input --------------------------------------------------------------------

func _on_row_choice_changed(slot: StringName, value: Variant) -> void:
	_choices[slot] = value
	_sfx.play(&"click")
	_refresh.call_deferred()

func _on_confirm_pressed() -> void:
	var a: MonsterData = _monster_at(_a_idx)
	var b: MonsterData = _monster_at(_b_idx)
	if a == null or b == null:
		return
	var result: Dictionary = FusionLogic.incubate(Game.run, _a_idx, _b_idx, _choices,
		Game.rng, int(_stab_spin.value))
	Game.notify_gold()
	if not bool(result.get(&"ok", false)):
		_status_label.text = String(result.get(&"reason", "The incubation could not start."))
		_refresh()
		return
	_choices = {}
	_show_result(result, a, b)

func _on_result_ok_pressed() -> void:
	if _run_over:
		_sfx.play_detached(&"click")
		Game.end_run_lost()
		return
	_sfx.play(&"click")
	_result_layer.visible = false
	_pick_defaults()
	_rebuild_parents()
	_refresh()
	_back_button.grab_focus()

# --- Result -----------------------------------------------------------------

func _show_result(result: Dictionary, a: MonsterData, b: MonsterData) -> void:
	var roll_text: String = "Chance %d%%, rolled %d." % [int(result.get(&"chance", 0)),
		int(result.get(&"roll", 0))]
	var success: bool = bool(result.get(&"success", false))
	var mushed: bool = bool(result.get(&"mushed", false))
	var fresh: Array[Dictionary] = CodexStore.record(result.get(&"new_codex", []) as Array)
	_result_jar_a.visible = mushed
	_result_jar_b.visible = mushed
	_result_holder.visible = success
	_result_subtitle.text = ""
	_result_new.text = ""
	_result_new.visible = false
	var flash_color: Color = color_good
	if success:
		var monster: MonsterData = result.get(&"monster") as MonsterData
		_a_idx = int(result.get(&"roster_index", -1))
		_b_idx = -1
		_result_monster.data = monster
		_result_monster.refresh()
		var has_signature: bool = false
		for value: Variant in monster.slots.values():
			var part: MutationData = value as MutationData
			if part != null and part.signature:
				has_signature = true
		_play_result_fx(&"mutate_success")
		if has_signature or not fresh.is_empty():
			_play_result_fx(&"ultra_reveal")
		_result_title.text = "IT LIVES!"
		_result_title.add_theme_color_override(&"font_color", color_good)
		_result_subtitle.text = monster.title
		var news: PackedStringArray = []
		for entry: Dictionary in fresh:
			var kind: String = "title" if entry.get(&"kind", &"part") == &"title" else (
				"SIGNATURE" if bool(entry.get(&"signature", false)) else "fusion")
			news.append("NEW %s: %s" % [kind, String(entry.get(&"name", ""))])
		_result_new.text = "\n".join(news)
		_result_new.visible = not news.is_empty()
		_result_body.text = "%s and %s became %s.\n%s" % [a.display_name, b.display_name,
			monster.display_name, roll_text]
	elif mushed:
		flash_color = color_mush
		_play_result_fx(&"mush")
		_result_title.text = "MUSH!"
		_result_title.add_theme_color_override(&"font_color", color_mush)
		_result_body.text = "%s and %s dissolved into mush and are retired.\n%s\n+%d%% Mush Memory on your next operation." % [
			a.display_name, b.display_name, roll_text, Tuning.MUSH_MEMORY_BONUS]
		if Game.run.living_count() <= 0:
			_run_over = true
			_result_body.text += "\nNo living monster is left. The run is over."
	else:
		flash_color = color_ok
		_result_title.text = "FAILED, BUT INSURED"
		_result_title.add_theme_color_override(&"font_color", color_ok)
		_result_body.text = "Insurance kept %s and %s from turning to mush.\n%s" % [
			a.display_name, b.display_name, roll_text]
	_result_ok_button.text = "End run" if _run_over else "OK"
	_result_layer.visible = true
	_result_ok_button.grab_focus()
	_play_flash(flash_color)
	_refresh_header()

## Plays the event effect `key` on the result art (the ResultFx anchor in the
## scene) together with the sound of the same name.
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

func _refresh_header() -> void:
	_gold_label.text = "Gold: %d" % Game.run.gold
	_stab_label.text = "Stabilizers: %d" % Game.run.stabilizers

func _refresh() -> void:
	_refresh_header()
	var a: MonsterData = _monster_at(_a_idx)
	var b: MonsterData = _monster_at(_b_idx)
	var preview: Dictionary = FusionLogic.incubate_preview(a, b, _choices)
	var slots: Dictionary = preview.get(&"slots", {}) as Dictionary
	_rebuild_rows(slots)
	_parent_a_view.visible = a != null
	_parent_a_view.data = a
	_parent_b_view.visible = b != null
	_parent_b_view.data = b
	var both: bool = a != null and b != null
	_preview_view.visible = both
	_slots_empty_label.visible = slots.is_empty()
	_slots_empty_label.text = "These two have no mutations to combine." if both \
		else "Pick two living monsters.\nEach needs %d mutations." % Tuning.FUSION_MIN_MUTATIONS
	if both:
		var fused: MonsterData = _preview_monster(a, b, slots)
		_preview_view.data = fused
		_preview_title.text = FusionLogic.fused_title(fused.slots)
		var stats: Dictionary = fused.get_total_stats()
		_preview_stats.text = "HP %d  ATK %d  DEF %d\nSPD %.2fs  CRIT %d%%" % [
			roundi(stats[&"hp"] as float), roundi(stats[&"atk"] as float),
			roundi(stats[&"defense"] as float), stats[&"attack_interval"] as float,
			roundi((stats[&"crit"] as float) * 100.0)]
	else:
		_preview_title.text = ""
		_preview_stats.text = ""
	# Stabilizers
	var max_stabs: int = mini(Tuning.STABILIZER_MAX, Game.run.stabilizers)
	_stab_spin.max_value = max_stabs
	_stab_spin.editable = max_stabs > 0
	if _stab_spin.value > max_stabs:
		_stab_spin.set_value_no_signal(max_stabs)
	var stabs: int = int(_stab_spin.value)
	# Odds: always shown before committing.
	var cost: int = int(preview.get(&"cost", Tuning.FUSION_COST))
	_cost_label.text = "Cost: %dg" % cost
	var reason: String = String(preview.get(&"reason", ""))
	if reason == "" and Game.run.gold < cost:
		reason = "Not enough gold (%dg needed)" % cost
	var names: PackedStringArray = []
	var values: PackedStringArray = []
	if both:
		var chance: int = FusionLogic.incubate_chance(Game.run, a, b, stabs)
		_chance_label.text = "%d%%" % chance
		_chance_label.add_theme_color_override(&"font_color", _chance_color(chance))
		_confirm_button.text = "Incubate (%d%%, %dg)" % [chance, cost]
		for row: Dictionary in FusionLogic.incubate_breakdown(Game.run, a, b, stabs):
			names.append(String(row.get(&"label", "")))
			values.append("%+d" % int(row.get(&"value", 0)))
	else:
		_chance_label.text = "--"
		_chance_label.add_theme_color_override(&"font_color", color_ok)
		_confirm_button.text = "Incubate"
	_breakdown_names.text = "\n".join(names)
	_breakdown_values.text = "\n".join(values)
	_confirm_button.disabled = reason != ""
	_confirm_button.tooltip_text = reason
	if reason != "":
		_status_label.text = reason
	elif _status_label.text != "":
		_status_label.text = ""
	# A failure mushes both parents: warn when nothing else is alive.
	_warning_label.visible = both and reason == "" and Game.run.living_count() <= 2 \
		and not Game.run.insurance

func _rebuild_rows(slots: Dictionary) -> void:
	for child: Node in _slot_list.get_children():
		_slot_list.remove_child(child)
		child.queue_free()
	for slot: StringName in MonsterData.SLOTS:
		if not slots.has(slot):
			continue
		var row: FusionSlotRow = ROW_SCENE.instantiate() as FusionSlotRow
		_slot_list.add_child(row)
		row.setup(slot, slots[slot] as Dictionary, _choices.get(slot))
		row.choice_changed.connect(_on_row_choice_changed)

## A display-only monster with the previewed parts and the fused base stats
## (same formula as FusionLogic: FUSION_STAT_MULT x (A + B) x FUSION_BOOST).
func _preview_monster(a: MonsterData, b: MonsterData, slots: Dictionary) -> MonsterData:
	var m: MonsterData = a.clone()
	var k: float = Tuning.FUSION_STAT_MULT * Tuning.FUSION_BOOST
	m.base_hp = k * (a.base_hp + b.base_hp)
	m.base_atk = k * (a.base_atk + b.base_atk)
	m.base_defense = k * (a.base_defense + b.base_defense)
	m.base_crit = k * (a.base_crit + b.base_crit)
	m.base_interval = (a.base_interval + b.base_interval) / 2.0
	var parts: Dictionary = {}
	for slot: StringName in MonsterData.SLOTS:
		if slots.has(slot):
			var part: MutationData = (slots[slot] as Dictionary).get(&"result") as MutationData
			if part != null:
				parts[slot] = part
	m.slots = parts
	return m

func _chance_color(chance: int) -> Color:
	if chance >= chance_good:
		return color_good
	if chance >= chance_ok:
		return color_ok
	return color_bad
