extends Control
## POTENTIAL showcase (main menu): a plain human mutates part by part into a
## monster, then into an ULTRA form, holds, fades and loops. Needs no run.
## Timing and the mutation list are exported so they are tuned in the editor.

## Mutations added one per step, in order. Each goes into its first free slot.
@export var steps: Array[MutationData] = []
## ULTRA body override applied at the end (put into its socket's slot).
@export var ultimate: MutationData
## The plain starting body.
@export var base_monster: MonsterData = preload("res://src/data/kinds/human.tres")
## Seconds before the first mutation.
@export var start_delay := 0.8
## Seconds between mutations.
@export var step_time := 1.0
## Pause before the ultimate form.
@export var ultimate_delay := 0.6
## Seconds the ultimate form is held before fading out.
@export var hold_time := 4.0
## Fade out / in seconds when the loop restarts.
@export var fade_time := 0.5
## Scale pop on each new part (multiplier on the monster's base scale).
@export var pop_scale := 1.12
## Screen shake strength (px) and length for the ultimate.
@export var shake_px := 6.0
@export var shake_time := 0.45
## Size multiplier for the pixelfx bursts.
@export var fx_scale := 2.0
## Caption colour for the ultimate form.
@export var ultra_color := Color(1.0, 0.85, 0.3)

var _data: MonsterData
var _base_scale: Vector2
var _stage_home: Vector2
var _pulse: Tween
var _loop_id := 0

@onready var _stage: Node2D = %Stage
@onready var _monster: MonsterView = %Monster
@onready var _caption: Label = %Caption
@onready var _stats: Label = %Stats
@onready var _flash: ColorRect = %Flash
@onready var _fade: ColorRect = %Fade
@onready var _back: Button = %Back
@onready var _sfx: Node = %Sfx


func _ready() -> void:
	_base_scale = _monster.scale
	_stage_home = _stage.position
	_back.pressed.connect(_go_back)
	_back.grab_focus.call_deferred()
	_run_loop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	_loop_id += 1
	_sfx.play_detached(&"click")
	Game.go_to(&"title")


## Waits, then returns false if the screen left or the loop was cancelled.
func _wait(seconds: float) -> bool:
	var id := _loop_id
	await get_tree().create_timer(seconds).timeout
	return is_inside_tree() and id == _loop_id


func _run_loop() -> void:
	while is_inside_tree():
		_reset()
		create_tween().tween_property(_fade, "color:a", 0.0, fade_time)
		if not await _wait(start_delay):
			return
		for i in steps.size():
			_add_step(steps[i], i + 1)
			if not await _wait(step_time):
				return
		if not await _wait(ultimate_delay):
			return
		_go_ultimate()
		if not await _wait(hold_time):
			return
		create_tween().tween_property(_fade, "color:a", 1.0, fade_time)
		if not await _wait(fade_time):
			return


func _reset() -> void:
	if _pulse != null:
		_pulse.kill()
	_data = base_monster.clone()
	_monster.data = _data
	_monster.scale = _base_scale
	_caption.text = "A plain human..."
	_caption.modulate = Color.WHITE
	_caption.remove_theme_color_override(&"font_color")
	_update_stats(0)


func _add_step(mutation: MutationData, index: int) -> void:
	if mutation == null:
		return
	var free_slots: Array[StringName] = _data.slots_for(mutation)
	if free_slots.is_empty():
		return
	var slot: StringName = free_slots[0]
	_data.apply_mutation(mutation, slot)
	_monster.refresh()
	_burst(_fx_for(mutation), _socket_pos(slot))
	_sfx.play(&"mutate_success", 0.08)
	_pop(pop_scale)
	_caption.text = "+ " + mutation.display_name
	_caption.add_theme_color_override(&"font_color", InventoryItem.rarity_color(mutation.rarity))
	_update_stats(index)


func _go_ultimate() -> void:
	if ultimate == null:
		return
	for slot: StringName in MonsterData.SLOTS:
		if MonsterData.SLOT_SOCKET[slot] == ultimate.socket_type:
			_data.slots[slot] = ultimate
			break
	_monster.refresh()
	_burst(FxLibrary.event_fx(&"win_big"), _monster.global_position)
	_burst(FxLibrary.event_fx(&"frenzy"), _monster.global_position)
	_sfx.play(&"ultra_reveal")
	_pop(pop_scale * 1.15)
	_flash.color.a = 0.85
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	_shake()
	_caption.text = "ULTIMATE FORM: " + ultimate.display_name
	_caption.add_theme_color_override(&"font_color", ultra_color)
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_caption, "modulate:a", 0.45, 0.35)
	_pulse.tween_property(_caption, "modulate:a", 1.0, 0.35)
	_update_stats(steps.size() + 1)


func _fx_for(mutation: MutationData) -> String:
	if mutation.ability != null:
		var path: String = FxLibrary.ability_fx(mutation.ability.get_id())
		if not path.is_empty():
			return path
	return FxLibrary.event_fx(&"purchase")


func _socket_pos(slot: StringName) -> Vector2:
	var marker := _monster.get_node_or_null(NodePath("Sockets/" + String(slot))) as Node2D
	return marker.global_position if marker != null else _monster.global_position


func _burst(json_path: String, at: Vector2) -> void:
	if json_path.is_empty():
		return
	var fx: PixelFxPlayer = PixelFxPlayer.spawn(_stage, json_path, at)
	if fx != null:
		fx.z_index = 5
		fx.scale = Vector2(fx_scale, fx_scale)


func _pop(amount: float) -> void:
	var t := create_tween()
	t.tween_property(_monster, "scale", _base_scale * amount, 0.08)
	t.tween_property(_monster, "scale", _base_scale, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake() -> void:
	var t := create_tween()
	var n := 9
	for i in n:
		var k := 1.0 - float(i) / n
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_px * k
		t.tween_property(_stage, "position", _stage_home + off, shake_time / n)
	t.tween_property(_stage, "position", _stage_home, 0.05)


func _update_stats(step: int) -> void:
	var s: Dictionary = _data.get_total_stats()
	_stats.text = "STEP %d/%d    HP %d    ATK %d    DEF %d    SPD %.2fs" % [
		step, steps.size() + 1, int(s[&"hp"]), int(s[&"atk"]), int(s[&"defense"]),
		float(s[&"attack_interval"])]
