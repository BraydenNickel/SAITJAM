extends Node2D
## Arena intro: the room starts dark, the ceiling lamps flicker on, slime "FIGHT"
## splats into the middle of the screen, then [signal match_started] fires.
## Add this scene as the LAST child of an arena so it draws over everything.

## Emitted once the FIGHT text has gone; start the match from here.
signal match_started
## Emitted when the lamps are on and the room has faded up (level hazards start here).
signal lights_on

# Tuning lives here (not src/data/tuning.gd) while the main scene is being worked on.
const DARK_ALPHA := 0.93
const DARK_LIFT_PER_LAMP := 0.12
const START_DELAY := 0.7
const LAMP_ON_ALPHA := 0.85
const LAMP_SETTLED_ALPHA := 0.55
const LAMP_TINT := Color(0.75, 1.0, 0.95)
## Flicker patterns: alternating on/off durations in seconds; the final 0.0 leaves the lamp on.
const FLICKER_LEFT := [0.05, 0.10, 0.04, 0.30, 0.07, 0.12, 0.0]
const FLICKER_RIGHT := [0.06, 0.18, 0.05, 0.08, 0.04, 0.22, 0.0]
const RIGHT_LAMP_DELAY := 0.35
const ROOM_FADE_TIME := 0.6
const FIGHT_SCALE := 2.0
const FIGHT_FRAME_TIME := 0.08
const FIGHT_HOLD := 1.1
const FIGHT_OUT_TIME := 0.3
const SHAKE_PX := 4.0
const DRIP_FRAMES := 8
const IDLE_SEQUENCE := [8, 9, 10, 11, 10, 9]
const MUSIC_VOLUME_DB := -6.0

## Start the intro as soon as the scene is ready. Turn off to call [method play] yourself.
@export var autoplay := true
## Fight music: starts on the FIGHT splat and loops through the match. Leave empty for none.
@export var music: AudioStream = preload("res://assets/audio/fight_theme.wav")

var _idle_time := -1.0
var _lamps_on := {}
var _music_player: AudioStreamPlayer
## Arena Light2D nodes driven by each intro lamp (lamp Sprite2D -> Array of Light2D).
var _arena_lights := {}

@onready var _darkness: ColorRect = $Darkness
@onready var _lamp_left: Sprite2D = $LampLeft
@onready var _lamp_right: Sprite2D = $LampRight
@onready var _fight: Sprite2D = $UI/Fight


func _ready() -> void:
	_darkness.color.a = DARK_ALPHA
	for lamp: Sprite2D in [_lamp_left, _lamp_right]:
		lamp.modulate = Color(LAMP_TINT, 0.0)
	_collect_arena_lights()
	_fight.visible = false
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "FightMusic"
	_music_player.bus = GameSettings.BUS_MUSIC
	add_child(_music_player)
	if autoplay:
		play()


## Fades the fight music out. Call it when the match ends.
func stop_music(fade_time := 1.0) -> void:
	if not _music_player.playing:
		return
	var fade := create_tween()
	fade.tween_property(_music_player, "volume_db", -60.0, fade_time)
	await fade.finished
	_music_player.stop()


func _start_music() -> void:
	if music == null:
		return
	if music is AudioStreamWAV:
		var wav := music as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_music_player.stream = music
	_music_player.volume_db = MUSIC_VOLUME_DB
	_music_player.play()


func _process(delta: float) -> void:
	if _idle_time < 0.0:
		return
	_idle_time += delta
	var i := int(_idle_time / FIGHT_FRAME_TIME) % IDLE_SEQUENCE.size()
	_fight.frame = IDLE_SEQUENCE[i]


## Runs the whole intro once. Await it, or listen for [signal match_started].
func play() -> void:
	await _wait(START_DELAY)
	_flicker(_lamp_left, FLICKER_LEFT)  # not awaited: runs alongside the right lamp
	await _wait(RIGHT_LAMP_DELAY)
	await _flicker(_lamp_right, FLICKER_RIGHT)
	var room := create_tween().set_parallel()
	room.tween_property(_darkness, "color:a", 0.0, ROOM_FADE_TIME)
	room.tween_property(_lamp_left, "modulate:a", LAMP_SETTLED_ALPHA, ROOM_FADE_TIME)
	room.tween_property(_lamp_right, "modulate:a", LAMP_SETTLED_ALPHA, ROOM_FADE_TIME)
	await room.finished
	lights_on.emit()
	await _show_fight()
	match_started.emit()


## Sets how dark the room is (0 = fully lit, 1 = black), e.g. for flickers and blackouts.
func set_darkness(alpha: float) -> void:
	_darkness.color.a = clampf(alpha, 0.0, 1.0)


func _flicker(lamp: Sprite2D, pattern: Array) -> void:
	var on := true
	for duration: float in pattern:
		_set_lamp(lamp, on)
		if duration > 0.0:
			await _wait(duration)
		on = not on


## If the arena has its own Light2D nodes, the intro flickers those (each with the
## nearest lamp) and hides its built-in lamp sprites so the light isn't doubled.
func _collect_arena_lights() -> void:
	var arena := get_parent()
	if arena == null:
		return
	for child in arena.get_children():
		var light := child as Light2D
		if light == null:
			continue
		var nearest := _lamp_left
		if _lamp_centre(_lamp_right).distance_to(light.global_position) \
				< _lamp_centre(_lamp_left).distance_to(light.global_position):
			nearest = _lamp_right
		if not _arena_lights.has(nearest):
			_arena_lights[nearest] = []
		_arena_lights[nearest].append(light)
		light.enabled = false
	if not _arena_lights.is_empty():
		_lamp_left.visible = false
		_lamp_right.visible = false


func _lamp_centre(lamp: Sprite2D) -> Vector2:
	return lamp.global_position + lamp.texture.get_size() / 2.0


func _set_lamp(lamp: Sprite2D, on: bool) -> void:
	lamp.modulate.a = LAMP_ON_ALPHA if on else 0.0
	for light: Light2D in _arena_lights.get(lamp, []):
		light.enabled = on
	_lamps_on[lamp] = on
	_darkness.color.a = DARK_ALPHA - DARK_LIFT_PER_LAMP * _lamps_on.values().count(true)


func _show_fight() -> void:
	_fight.frame = 0
	_fight.modulate.a = 1.0
	_fight.visible = true
	_fight.scale = Vector2(FIGHT_SCALE * 1.8, FIGHT_SCALE * 0.15)
	var pop := create_tween()
	pop.tween_property(_fight, "scale", Vector2(FIGHT_SCALE * 0.8, FIGHT_SCALE * 1.25), 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(_fight, "scale", Vector2(FIGHT_SCALE * 1.1, FIGHT_SCALE * 0.92), 0.08)
	pop.tween_property(_fight, "scale", Vector2.ONE * FIGHT_SCALE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake()
	_start_music()
	var drip := create_tween()
	drip.tween_property(_fight, "frame", DRIP_FRAMES - 1, FIGHT_FRAME_TIME * (DRIP_FRAMES - 1))
	await drip.finished
	_idle_time = 0.0
	await _wait(FIGHT_HOLD)
	var out := create_tween().set_parallel()
	out.tween_property(_fight, "modulate:a", 0.0, FIGHT_OUT_TIME)
	out.tween_property(_fight, "scale", Vector2(FIGHT_SCALE * 1.15, FIGHT_SCALE * 0.6), FIGHT_OUT_TIME) \
		.set_ease(Tween.EASE_IN)
	await out.finished
	_idle_time = -1.0
	_fight.visible = false


## Shakes the arena this intro sits in (or itself when it has no Node2D parent).
func _shake() -> void:
	var target := get_parent() as Node2D
	if target == null:
		target = self
	var origin := target.position
	var t := create_tween()
	for i in 6:
		var amp := SHAKE_PX * (1.0 - i / 6.0)
		t.tween_property(target, "position", origin + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.03)
	t.tween_property(target, "position", origin, 0.03)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
