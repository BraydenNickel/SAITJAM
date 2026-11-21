extends Node2D
## Battle scene: runs a BattleSim on the player's lineup vs Game.enemy_team and
## animates its events (lunges, numbers, pixelfx effects, sounds, screen shake).
## Speed is applied through Engine.time_scale so tweens stay in step with the
## simulation; throttles and the shake use real time so they behave the same at
## every speed.

const UNIT_SCENE: PackedScene = preload("res://src/battle/battle_unit.tscn")
const NUMBER_SCENE: PackedScene = preload("res://src/battle/damage_number.tscn")
const DAMAGE_ROW_SCENE: PackedScene = preload("res://src/battle/damage_row.tscn")

const COLOR_DAMAGE: Color = Color(1.0, 1.0, 1.0)
const COLOR_CRIT: Color = Color(1.0, 0.9, 0.2)
const COLOR_VENOM: Color = Color(0.4, 1.0, 0.35)
const COLOR_HOOK: Color = Color(0.8, 0.45, 1.0)
const COLOR_HEAL: Color = Color(0.4, 1.0, 0.55)
const COLOR_DODGE: Color = Color(0.75, 0.85, 1.0)
const COLOR_ABILITY: Color = Color(1.0, 0.8, 0.5)
const COLOR_LOSS: Color = Color(1.0, 0.45, 0.4)

## Event fx / sfx key per celebration tier (index matches Tuning.CELEBRATE_NET).
const CELEBRATE_KEYS: Array[StringName] = [&"win_small", &"win_medium", &"win_big"]

@onready var _player_spots: Node2D = %PlayerSpots
@onready var _enemy_spots: Node2D = %EnemySpots
@onready var _units_root: Node2D = %Units
@onready var _fx_layer: Node2D = %FxLayer
@onready var _camera: Camera2D = %ShakeCamera
@onready var _frenzy_spot: Marker2D = %FrenzySpot
@onready var _arena: Node2D = %Arena
@onready var _sfx: SfxPlayer = %Sfx
@onready var _timer_label: Label = %TimerLabel
@onready var _bet_label: Label = %BetLabel
@onready var _speed_button: Button = %SpeedButton
@onready var _pause_button: Button = %PauseButton
@onready var _settings_menu: SettingsMenu = %SettingsMenu
@onready var _damage_rows: VBoxContainer = %DamageRows
@onready var _intro_label: Label = %IntroLabel
@onready var _frenzy_banner: Label = %FrenzyBanner
@onready var _celebration: CPUParticles2D = %Celebration
@onready var _result_fx: Node2D = %ResultFx
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _reward_label: Label = %RewardLabel
@onready var _bet_lines: Array[Label] = [%BetLine1, %BetLine2]
@onready var _net_label: Label = %NetLabel
@onready var _continue_button: Button = %ContinueButton

var _sim: BattleSim
var _views: Dictionary = {}
var _intro_left: float = 0.0
var _speed_index: int = 0
var _ended: bool = false
var _won: bool = false
var _gold_delta: int = 0
## Net gold of this battle (reward + payouts - stakes), for the run summary.
var _net: int = 0
## PixelFxPlayer nodes currently alive (capped by Tuning.FX_MAX_ALIVE).
var _fx_alive: int = 0
## Throttle key -> Time.get_ticks_msec() of the last effect shown for it.
var _fx_last: Dictionary = {}
## Peak offset in px of the running shake (0 = none).
var _shake_amplitude: float = 0.0
## Time.get_ticks_msec() at which the running shake ends.
var _shake_end_msec: int = 0
## Player UnitStates shown in the damage counter, and their DamageRow views.
var _damage_units: Array[UnitState] = []
var _damage_row_views: Array[DamageRow] = []

func _ready() -> void:
	Game.ensure_run()
	if Game.enemy_team.is_empty():
		Game.prepare_battle()
	var lineup: Dictionary = Game.build_lineup()
	var team: Array[MonsterData] = lineup["team"]
	var spots: Array[int] = lineup["spots"]
	var roster_idx: Array[int] = lineup["roster_idx"]
	_sim = BattleSim.new(team, spots, roster_idx, Game.enemy_team, Game.enemy_spots, Game.battle_seed())
	for unit: UnitState in _sim.units:
		var view: BattleUnit = UNIT_SCENE.instantiate() as BattleUnit
		var is_enemy: bool = unit.side == 1
		var marker: Marker2D = (_enemy_spots if is_enemy else _player_spots).get_node_or_null("Spot%d" % unit.spot) as Marker2D
		_units_root.add_child(view)
		view.global_position = marker.global_position if marker != null else Vector2(320, 200)
		view.setup(unit, is_enemy)
		_views[unit.index] = view
		if not is_enemy:
			_damage_units.append(unit)
			var row: DamageRow = DAMAGE_ROW_SCENE.instantiate() as DamageRow
			_damage_rows.add_child(row)
			_damage_row_views.append(row)
	_sim.event.connect(_on_sim_event)
	_speed_button.pressed.connect(_on_speed_pressed)
	_pause_button.pressed.connect(_pause)
	_settings_menu.closed.connect(_unpause)
	_continue_button.pressed.connect(_on_continue_pressed)
	_bet_label.text = _bet_summary()
	_update_hud()
	_hook_arena_intro()

## The arena intro (lights flicker on, FIGHT splat) gates the match: units fade in with the
## lights and the sim starts on match_started. Without an intro, fall back to the timed label.
func _hook_arena_intro() -> void:
	var intro: Node = _arena.get_node_or_null("ArenaIntro") if _arena != null else null
	if intro == null or not intro.has_signal("match_started"):
		_intro_left = Tuning.BATTLE_INTRO_TIME
		return
	_intro_label.visible = false
	_intro_left = INF
	for layer: CanvasItem in [_units_root, _player_spots, _enemy_spots]:
		layer.modulate.a = 0.0
	intro.lights_on.connect(_on_arena_lights_on)
	intro.match_started.connect(func() -> void: _intro_left = 0.0)

func _on_arena_lights_on() -> void:
	var fade := create_tween().set_parallel()
	for layer: CanvasItem in [_units_root, _player_spots, _enemy_spots]:
		fade.tween_property(layer, "modulate:a", 1.0, Tuning.ARENA_UNIT_FADE_TIME)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

func _process(delta: float) -> void:
	_update_shake()
	if _ended:
		return
	if _intro_left > 0.0:
		if is_inf(_intro_left):
			return  # waiting for the arena intro's match_started
		_intro_left -= delta
		if _intro_left <= 0.0:
			_intro_label.visible = false
		return
	_sim.step(delta)
	_update_hud()

func _update_hud() -> void:
	_timer_label.text = "Time %.1fs" % _sim.time
	for unit: UnitState in _sim.units:
		var view: BattleUnit = _views[unit.index] as BattleUnit
		view.set_hp(float(unit.hp), float(unit.max_hp))
	_update_damage_counter()

## Player units sorted by damage dealt this round; the leader is marked MVP.
func _update_damage_counter() -> void:
	var sorted: Array[UnitState] = _damage_units.duplicate()
	sorted.sort_custom(func(a: UnitState, b: UnitState) -> bool:
		return a.damage_dealt > b.damage_dealt if a.damage_dealt != b.damage_dealt else a.index < b.index)
	var top: int = sorted[0].damage_dealt if not sorted.is_empty() else 0
	for i: int in sorted.size():
		var unit: UnitState = sorted[i]
		_damage_row_views[i].set_values(unit.data.display_name, unit.damage_dealt, top, i == 0 and top > 0)

# --- Pause ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _settings_menu.is_open() and not _ended:
		get_viewport().set_input_as_handled()
		_pause()

## Freezes the fight (tree pause) and opens the settings menu, which keeps running.
func _pause() -> void:
	if _ended or _settings_menu.is_open():
		return
	_sfx.play(&"click")
	get_tree().paused = true
	_settings_menu.open()

func _unpause() -> void:
	get_tree().paused = false

func _bet_summary() -> String:
	if Game.bets.is_empty():
		return "No bets"
	var parts: PackedStringArray = []
	for bet: Dictionary in Game.bets:
		parts.append("%s %dg x%.1f" % [BetText.name_of(bet[&"claim"] as StringName),
			int(bet[&"stake"]), float(bet[&"mult"])])
	return "Bets: " + ", ".join(parts)

func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % Tuning.BATTLE_SPEEDS.size()
	var speed: float = Tuning.BATTLE_SPEEDS[_speed_index]
	Engine.time_scale = speed
	_speed_button.text = "Speed %dx" % roundi(speed)
	_sfx.play(&"click")

# --- Sim event handlers -----------------------------------------------------

func _on_sim_event(kind: StringName, info: Dictionary) -> void:
	match kind:
		&"attack":
			var src: BattleUnit = _view_of(info.get(&"src", -1))
			var dst: BattleUnit = _view_of(info.get(&"dst", -1))
			if src != null and dst != null:
				src.lunge(dst.global_position)
				_sfx.play(&"attack", Tuning.SFX_PITCH_JITTER)
		&"damage":
			_on_damage(info)
		&"heal":
			var dst: BattleUnit = _view_of(info.get(&"dst", -1))
			if dst != null:
				_spawn_number("+%d" % int(info.get(&"amount", 0)), dst, COLOR_HEAL, 1.0)
				if _throttle_ok("heal:%d" % int(info.get(&"dst", -1)), Tuning.FX_REPEAT_INTERVAL):
					_unit_fx(dst, FxLibrary.event_fx(&"heal"), false)
					_sfx.play(&"heal", Tuning.SFX_PITCH_JITTER)
		&"dodge":
			var dst: BattleUnit = _view_of(info.get(&"dst", -1))
			if dst != null:
				_spawn_number("DODGE", dst, COLOR_DODGE, 1.0)
				_unit_fx(dst, FxLibrary.event_fx(&"dodge"), dst.facing_left)
				_sfx.play(&"dodge", Tuning.SFX_PITCH_JITTER)
		&"ability":
			var unit: BattleUnit = _view_of(info.get(&"unit", -1))
			if unit != null:
				var ability_id: StringName = StringName(info.get(&"ability_id", &""))
				_spawn_number(_ability_name(ability_id), unit, COLOR_ABILITY, 0.8, -14.0)
				if _throttle_ok("ab:%d:%s" % [int(info.get(&"unit", -1)), ability_id], _fx_interval(ability_id)):
					_unit_fx(unit, FxLibrary.ability_fx(ability_id), unit.facing_left)
					_sfx.play(&"ability", Tuning.SFX_PITCH_JITTER)
		&"death":
			var unit: BattleUnit = _view_of(info.get(&"unit", -1))
			if unit != null:
				unit.die()
				_unit_fx(unit, FxLibrary.event_fx(&"death"), false)
				_sfx.play(&"death")
				_shake(Tuning.SHAKE_DEATH_AMPLITUDE)
		&"frenzy":
			_frenzy_banner.visible = true
			_spawn_fx(FxLibrary.event_fx(&"frenzy"), _frenzy_spot.global_position, false)
			_sfx.play(&"frenzy")
		&"end":
			_on_battle_end(int(info.get(&"winner", 1)))

## Number, flash, effect, sound and shake for one `damage` event.
func _on_damage(info: Dictionary) -> void:
	var dst_index: int = int(info.get(&"dst", -1))
	var dst: BattleUnit = _view_of(dst_index)
	if dst == null:
		return
	dst.flash()
	var crit: bool = bool(info.get(&"crit", false))
	var from_hook: bool = bool(info.get(&"from_hook", false))
	var ability_id: StringName = StringName(info.get(&"ability_id", &""))
	var color: Color = COLOR_DAMAGE
	if from_hook:
		color = COLOR_VENOM if ability_id == &"venom" else COLOR_HOOK
	if crit:
		color = COLOR_CRIT
	_spawn_number(str(int(info.get(&"amount", 0))), dst, color, 1.5 if crit else 1.0)
	# The hit comes from the other side, so player-side targets mirror the effect.
	var flip: bool = not dst.facing_left
	var ability_json: String = FxLibrary.ability_fx(ability_id) if from_hook else ""
	if not ability_json.is_empty():
		# Ability damage (venom, burn, thorns ...): the ability's own effect,
		# throttled per unit so damage-over-time does not flood the screen.
		if _throttle_ok("hook:%d:%s" % [dst_index, ability_id], _fx_interval(ability_id)):
			var tick: bool = Tuning.FX_TICK_ABILITIES.has(ability_id)
			_unit_fx(dst, ability_json, flip, Tuning.FX_TICK_SCALE if tick else 1.0)
			_sfx.play(&"hit", Tuning.SFX_PITCH_JITTER)
	elif crit:
		_unit_fx(dst, FxLibrary.event_fx(&"crit"), flip)
		_sfx.play(&"crit", Tuning.SFX_PITCH_JITTER)
	else:
		_unit_fx(dst, FxLibrary.event_fx(&"hit"), flip)
		_sfx.play(&"hit", Tuning.SFX_PITCH_JITTER)
	if crit:
		_shake(Tuning.SHAKE_CRIT_AMPLITUDE)

func _view_of(index: Variant) -> BattleUnit:
	return _views.get(int(index)) as BattleUnit

func _spawn_number(message: String, view: BattleUnit, color: Color, size_mult: float, y_offset: float = 0.0) -> void:
	var number: DamageNumber = NUMBER_SCENE.instantiate() as DamageNumber
	_fx_layer.add_child(number)
	var jitter: float = randf_range(-8.0, 8.0)
	number.show_text(message, view.global_position + Vector2(jitter, -30.0 + y_offset), color, size_mult)

## "double_strike" -> "Double Strike".
func _ability_name(ability_id: StringName) -> String:
	return String(ability_id).replace("_", " ").capitalize()

# --- Effects ----------------------------------------------------------------

## Minimum real seconds between two effects of the same ability on one unit.
func _fx_interval(ability_id: StringName) -> float:
	return Tuning.FX_TICK_INTERVAL if Tuning.FX_TICK_ABILITIES.has(ability_id) else Tuning.FX_REPEAT_INTERVAL

## True (and records the time) when `key` has not shown an effect for
## `interval` real seconds.
func _throttle_ok(key: String, interval: float) -> bool:
	var now: int = Time.get_ticks_msec()
	if _fx_last.has(key) and now - int(_fx_last[key]) < int(interval * 1000.0):
		return false
	_fx_last[key] = now
	return true

## Spawns a one-shot effect in the FxLayer. Returns null when the sheet is
## missing or Tuning.FX_MAX_ALIVE effects are already playing.
func _spawn_fx(json_path: String, at: Vector2, flip: bool, fx_scale: float = 1.0) -> PixelFxPlayer:
	if json_path.is_empty() or _fx_alive >= Tuning.FX_MAX_ALIVE:
		return null
	var fx: PixelFxPlayer = PixelFxPlayer.spawn(_fx_layer, json_path, at, flip)
	if fx == null:
		return null
	_fx_alive += 1
	fx.tree_exited.connect(_on_fx_exited)
	fx.scale = Vector2(fx_scale, fx_scale)
	return fx

func _on_fx_exited() -> void:
	_fx_alive -= 1

## Plays an effect on a unit. Sheets whose pivot is near the bottom of the
## frame are drawn standing on the ground, so they anchor at the unit's feet;
## the rest anchor at the body centre.
func _unit_fx(view: BattleUnit, json_path: String, flip: bool, fx_scale: float = 1.0) -> void:
	var fx: PixelFxPlayer = _spawn_fx(json_path, view.fx_center(), flip, fx_scale)
	if fx == null:
		return
	var frame: Texture2D = fx.sprite_frames.get_frame_texture(fx.animation, 0)
	if frame == null or frame.get_height() <= 0:
		return
	var feet: Vector2 = view.fx_feet()
	var pivot_ratio: float = -fx.offset.y / float(frame.get_height())
	if pivot_ratio >= Tuning.FX_GROUND_PIVOT_RATIO:
		# A scaled-down effect keeps its base on the ground.
		fx.global_position = feet
	else:
		fx.global_position = view.fx_center()

# --- Screen shake -----------------------------------------------------------

## Starts (or strengthens) a camera shake. Only the world moves: the HUD is on
## its own CanvasLayer.
func _shake(amplitude: float) -> void:
	if amplitude < _shake_amplitude:
		return
	_shake_amplitude = amplitude
	_shake_end_msec = Time.get_ticks_msec() + int(Tuning.SHAKE_DURATION * 1000.0)

## Real-time linear decay, independent of Engine.time_scale; ends at exactly zero.
func _update_shake() -> void:
	if _shake_amplitude <= 0.0:
		return
	var left: float = float(_shake_end_msec - Time.get_ticks_msec()) / 1000.0
	if left <= 0.0:
		_shake_amplitude = 0.0
		_camera.offset = Vector2.ZERO
		return
	var strength: float = _shake_amplitude * left / Tuning.SHAKE_DURATION
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).round() * roundf(strength)

# --- End of battle ----------------------------------------------------------

func _on_battle_end(winner: int) -> void:
	if _ended:
		return
	_ended = true
	_won = winner == 0
	_pause_button.disabled = true
	Engine.time_scale = 1.0
	_update_hud()
	# Real-time wait (ignores time_scale) so the last hit is visible.
	await get_tree().create_timer(Tuning.BATTLE_END_DELAY, true, false, true).timeout
	_show_result()

func _show_result() -> void:
	var result: Dictionary = _sim.result()
	Game.last_result = result
	var reward: int = Tuning.BATTLE_REWARD[Game.run.battle_index] if _won else 0
	var payouts: int = 0
	var stakes: int = 0
	for i: int in _bet_lines.size():
		var line: Label = _bet_lines[i]
		line.visible = i < Game.bets.size()
		if not line.visible:
			continue
		var bet: Dictionary = Game.bets[i]
		var stake: int = int(bet[&"stake"])
		var claim: StringName = bet[&"claim"] as StringName
		var won_bet: bool = BetOdds.claim_won(claim, result, int(bet.get(&"mvp_roster_idx", -1)))
		var payout: int = roundi(stake * float(bet[&"mult"])) if won_bet else 0
		stakes += stake
		payouts += payout
		line.text = "%s: WON %+dg" % [BetText.name_of(claim), payout - stake] if won_bet \
			else "%s: LOST -%dg" % [BetText.name_of(claim), stake]
		line.add_theme_color_override("font_color", COLOR_HEAL if won_bet else COLOR_LOSS)
	_gold_delta = reward + payouts
	var net: int = _gold_delta - stakes
	_net = net
	_result_title.text = "VICTORY" if _won else "DEFEAT"
	_result_title.add_theme_color_override("font_color", COLOR_CRIT if _won else COLOR_LOSS)
	_reward_label.text = "Battle reward: +%dg" % reward if _won else "No reward - the run ends."
	_net_label.text = "Net: %+dg" % net
	_net_label.add_theme_color_override("font_color", COLOR_CRIT if net > 0 else (COLOR_LOSS if net < 0 else COLOR_DODGE))
	_result_panel.visible = true
	if not _won:
		_sfx.play(&"lose")
	_celebrate(net)

## Celebration scales with net gold; none on a net loss or break-even. A lost
## battle with a positive net (won bets) still shows the effect, but its sound
## stays the defeat sound.
func _celebrate(net: int) -> void:
	var tier: int = -1
	for i: int in Tuning.CELEBRATE_NET.size():
		if net >= Tuning.CELEBRATE_NET[i]:
			tier = i
	if tier < 0:
		return
	_celebration.amount = Tuning.CELEBRATE_PARTICLES[tier]
	_celebration.restart()
	_celebration.emitting = true
	var key: StringName = CELEBRATE_KEYS[mini(tier, CELEBRATE_KEYS.size() - 1)]
	for child: Node in _result_fx.get_children():
		var spot: Marker2D = child as Marker2D
		if spot != null:
			PixelFxPlayer.spawn(_result_fx, FxLibrary.event_fx(key), spot.global_position)
	if _won:
		_sfx.play(key)
	_net_label.pivot_offset = _net_label.size * 0.5
	var pop: float = 1.2 + 0.25 * tier
	var tween: Tween = create_tween()
	tween.tween_property(_net_label, "scale", Vector2(pop, pop), 0.15)
	tween.tween_property(_net_label, "scale", Vector2.ONE, 0.2)

func _on_continue_pressed() -> void:
	_continue_button.disabled = true
	_sfx.play_detached(&"click")
	Game.complete_battle(_won, _gold_delta, _net)
