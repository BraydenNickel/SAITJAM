class_name ArenaHazards
extends Node2D
## Live hazards for one arena level: lamp flickers and blackouts, wires that arc and spit sparks,
## a pulsing alarm light and (on the last level) a sweeping red emergency light.
## Created by arena.gd with a level [member config]; call [method start] once the lights are on.

const ZAP_FX := "res://assets/fx/zap-hit.json"
const SPARK_FX := "res://assets/fx/hit-spark.json"
const ZAP_DROP := 34.0              ## how far below the wire end the arc lands on the wall
const ZAP_SCALE := 0.6
const SPARK_SCALE := 0.5
const SPARK_STUTTER_CHANCE := 0.4   ## chance a spark also makes the nearest lamp stutter
const FLASH_COLOR := Color(0.7, 0.85, 1.0)
const FLASH_ENERGY := 1.6
const FLASH_TIME := 0.25
## Alternating off/on durations of one lamp flicker (starts off, ends back on).
const FLICKER_PATTERN := [0.06, 0.05, 0.12, 0.04, 0.08]
const FLICKER_DIM := 0.15           ## lamp energy multiplier while "off"
const FLICKER_DARKNESS := 0.3
const BLACKOUT_DARKNESS := 0.8
const BLACKOUT_TIME := [0.35, 0.7]
const ALARM_POS := Vector2(319, 51)
const ALARM_COLOR := Color(1.0, 0.15, 0.1)
## Alarm pulse per alarm level: [low energy, high energy, half-period seconds].
const ALARM_PULSE := {1: [0.2, 1.1, 1.2], 2: [0.2, 2.0, 0.45]}
const ALARM_SCALE := 1.6
const SWEEP_Y := 70.0
const SWEEP_X := [140.0, 500.0]
const SWEEP_TIME := 1.4
const SWEEP_ENERGY := 1.4
const SWEEP_SCALE := 2.5

## One entry of arena.gd's LEVELS table.
var config: Dictionary = {}
## The arena's lamps (Light2D nodes) to flicker.
var lights: Array[Light2D] = []
## The ArenaIntro node, used to darken the room during flickers (optional).
var intro: Node = null

var _base_energy := {}
var _running := false
var _radial: GradientTexture2D


## Starts every hazard for this level. Safe to call more than once.
func start() -> void:
	if _running:
		return
	_running = true
	_radial = _make_radial_texture(128)
	for light in lights:
		_base_energy[light] = light.energy
	_flicker_loop()
	if not config.get("sparks", []).is_empty():
		_spark_loop()
	if config.get("alarm", 0) > 0:
		_start_alarm(config["alarm"])
	if config.get("sweep", false):
		_start_sweep()


func _flicker_loop() -> void:
	var every: Array = config["flicker"]
	while is_inside_tree():
		await _wait(randf_range(every[0], every[1]))
		if randf() < config.get("blackout_chance", 0.0):
			await _blackout()
		elif not lights.is_empty():
			await _flicker(lights.pick_random())


func _flicker(light: Light2D) -> void:
	var off := true
	for duration: float in FLICKER_PATTERN:
		_set_light(light, not off)
		_darken(FLICKER_DARKNESS if off else 0.0)
		await _wait(duration)
		off = not off
	_set_light(light, true)
	_darken(0.0)


func _blackout() -> void:
	for light in lights:
		_set_light(light, false)
	_darken(BLACKOUT_DARKNESS)
	await _wait(randf_range(BLACKOUT_TIME[0], BLACKOUT_TIME[1]))
	for light in lights:
		_set_light(light, true)
	_darken(0.0)
	if not lights.is_empty():
		await _flicker(lights.pick_random())


func _spark_loop() -> void:
	var every: Array = config["spark_every"]
	while is_inside_tree():
		await _wait(randf_range(every[0], every[1]))
		_spark(config["sparks"].pick_random())


func _spark(at: Vector2) -> void:
	var zap := PixelFxPlayer.spawn(self, ZAP_FX, at + Vector2(0, ZAP_DROP))
	if zap != null:
		zap.rotation = PI / 2  # the arc comes in from above instead of from the left
		zap.scale = Vector2.ONE * ZAP_SCALE
	var sparks := PixelFxPlayer.spawn(self, SPARK_FX, at)
	if sparks != null:
		sparks.rotation = PI / 2
		sparks.scale = Vector2.ONE * SPARK_SCALE
	var flash := PointLight2D.new()
	flash.texture = _radial
	flash.color = FLASH_COLOR
	flash.energy = FLASH_ENERGY
	flash.position = at
	add_child(flash)
	var fade := create_tween()
	fade.tween_property(flash, "energy", 0.0, FLASH_TIME)
	fade.tween_callback(flash.queue_free)
	if not lights.is_empty() and randf() < SPARK_STUTTER_CHANCE:
		_flicker(_nearest_light(at))


func _start_alarm(level: int) -> void:
	var pulse: Array = ALARM_PULSE.get(level, ALARM_PULSE[1])
	var alarm := PointLight2D.new()
	alarm.texture = _radial
	alarm.color = ALARM_COLOR
	alarm.texture_scale = ALARM_SCALE
	alarm.position = ALARM_POS
	alarm.energy = pulse[0]
	add_child(alarm)
	var t := create_tween().set_loops()
	t.tween_property(alarm, "energy", pulse[1], pulse[2]).set_trans(Tween.TRANS_SINE)
	t.tween_property(alarm, "energy", pulse[0], pulse[2]).set_trans(Tween.TRANS_SINE)


func _start_sweep() -> void:
	var beam := PointLight2D.new()
	beam.texture = _radial
	beam.texture_scale = SWEEP_SCALE
	beam.color = ALARM_COLOR
	beam.energy = SWEEP_ENERGY
	beam.position = Vector2(SWEEP_X[0], SWEEP_Y)
	add_child(beam)
	var t := create_tween().set_loops()
	t.tween_property(beam, "position:x", SWEEP_X[1], SWEEP_TIME).set_trans(Tween.TRANS_SINE)
	t.tween_property(beam, "position:x", SWEEP_X[0], SWEEP_TIME).set_trans(Tween.TRANS_SINE)


func _set_light(light: Light2D, on: bool) -> void:
	if light == null:
		return
	var base: float = _base_energy.get(light, light.energy)
	light.energy = base if on else base * FLICKER_DIM


func _darken(alpha: float) -> void:
	if intro != null and intro.has_method("set_darkness"):
		intro.set_darkness(alpha)


func _nearest_light(at: Vector2) -> Light2D:
	var best: Light2D = lights[0]
	for light in lights:
		if light.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = light
	return best


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


static func _make_radial_texture(size: int) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
