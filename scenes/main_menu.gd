extends Control
## Main menu: the mad scientist cackles, slime drips off the MUTANT title onto the breathing heap
## of flesh under a flickering overhead lamp, and the buttons glow neon green on hover or focus.

## Emitted when CODEX is pressed (then opens the Codex screen).
signal codex_pressed
## Emitted when POTENTIAL is pressed (then opens the mutation showcase).
signal potential_pressed
## Emitted when SETTINGS is pressed (then opens the settings overlay).
signal settings_pressed
## Emitted when NEW RUN is pressed, before a run is started.
signal new_run_pressed

# Tuning
const TITLE_FPS := 8.0
const SCIENTIST_FPS := 11.0
const MOUND_FPS := 3.0
const MENU_MUSIC_DB := -8.0
const HOVER_SFX_DB := -10.0
const CLICK_SFX_DB := -6.0
const DROP_SFX_DB := -18.0
## Drip tips on the title above the flesh heap: [spawn point, landing y].
const DROP_POINTS := [
	[Vector2(194, 169), 329.0], [Vector2(210, 172), 316.0], [Vector2(240, 171), 295.0],
	[Vector2(320, 166), 299.0], [Vector2(342, 163), 319.0],
]
const DROP_EVERY := [1.4, 3.2]
const DROP_GRAVITY := 600.0
const DROP_PINCH_TIME := 0.18
const SPLAT_FRAME_TIME := 0.06
const FLINCH_SCALE := Vector2(1.04, 0.95)
const FLINCH_TIME := 0.3
const FLICKER_EVERY := [4.0, 9.0]
const FLICKER_PATTERN := [0.05, 0.06, 0.1, 0.04, 0.07]   ## alternating off/on seconds
const FLICKER_DIM := 0.45
const DROP_TEXTURE := preload("res://assets/sprites/menu/drop.png")
const SPLAT_TEXTURE := preload("res://assets/sprites/menu/splat_sheet.png")
const SPLAT_FRAMES := 5

## Start a run (Game.new_run(), then the hub) when NEW RUN is pressed. Turn off to handle new_run_pressed yourself.
@export var start_run_on_new_run := true

var _time := 0.0
var _rng := RandomNumberGenerator.new()

@onready var _title: Sprite2D = $Title
@onready var _mound: Sprite2D = $Mound
@onready var _scientist: Sprite2D = $Scientist
@onready var _drops: Node2D = $Drops
@onready var _cone: Sprite2D = $LampCone
@onready var _dim: ColorRect = $Dim
@onready var _music: AudioStreamPlayer = $Music
@onready var _sfx: AudioStreamPlayer = $Sfx
@onready var _new_run: TextureButton = %NewRun
@onready var _codex: TextureButton = %Codex
@onready var _potential: TextureButton = %Potential
@onready var _settings: TextureButton = %Settings
@onready var _quit: TextureButton = %Quit
@onready var _settings_menu: CanvasLayer = %SettingsMenu


func _ready() -> void:
	_rng.randomize()
	for button: TextureButton in [_new_run, _codex, _potential, _settings, _quit]:
		button.mouse_entered.connect(button.grab_focus)   # hover and keyboard focus look the same
	_new_run.pressed.connect(_on_new_run)
	_codex.pressed.connect(_on_pressed.bind(codex_pressed))
	_potential.pressed.connect(_on_pressed.bind(potential_pressed))
	_settings.pressed.connect(_on_pressed.bind(settings_pressed))
	_quit.pressed.connect(_on_quit)
	codex_pressed.connect(Game.go_to.bind(&"codex"))
	potential_pressed.connect(Game.go_to.bind(&"potential"))
	settings_pressed.connect(_settings_menu.open)
	_settings_menu.closed.connect(_settings.grab_focus)
	_start_music()
	_new_run.grab_focus.call_deferred()
	_connect_hover_sfx.call_deferred()   # after the first focus, so opening the menu is silent
	_drop_loop()
	_flicker_loop()


func _process(delta: float) -> void:
	_time += delta
	_title.frame = int(_time * TITLE_FPS) % _title.hframes
	_scientist.frame = int(_time * SCIENTIST_FPS) % _scientist.hframes
	_mound.frame = int(_time * MOUND_FPS) % _mound.hframes


func _connect_hover_sfx() -> void:
	for button: TextureButton in [_new_run, _codex, _potential, _settings, _quit]:
		button.focus_entered.connect(_play_sfx.bind(preload("res://assets/audio/ui_hover.wav"), HOVER_SFX_DB))


func _start_music() -> void:
	var wav := _music.stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_music.volume_db = MENU_MUSIC_DB
	_music.play()


func _play_sfx(stream: AudioStream, volume_db: float, pitch := 1.0) -> void:
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.pitch_scale = pitch
	_sfx.play()


func _on_pressed(sig: Signal) -> void:
	_play_sfx(preload("res://assets/audio/ui_click.wav"), CLICK_SFX_DB)
	sig.emit()


func _on_new_run() -> void:
	_on_pressed(new_run_pressed)
	if start_run_on_new_run:
		Game.new_run()
		Game.go_to(&"hub")


func _on_quit() -> void:
	_play_sfx(preload("res://assets/audio/ui_click.wav"), CLICK_SFX_DB)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


# ---------------- slime dripping onto the heap ----------------
func _drop_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(_rng.randf_range(DROP_EVERY[0], DROP_EVERY[1])).timeout
		_drop(DROP_POINTS[_rng.randi() % DROP_POINTS.size()])


func _drop(point: Array) -> void:
	var start: Vector2 = point[0]
	var land_y: float = point[1]
	var drop := Sprite2D.new()
	drop.texture = DROP_TEXTURE
	drop.position = start
	drop.scale = Vector2(1, 0.4)
	_drops.add_child(drop)
	var fall_time := sqrt(2.0 * (land_y - start.y) / DROP_GRAVITY)
	var t := create_tween()
	t.tween_property(drop, "scale", Vector2.ONE, DROP_PINCH_TIME)   # swells off the drip
	t.tween_property(drop, "position:y", land_y, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	drop.queue_free()
	_splat(Vector2(start.x, land_y))


func _splat(at: Vector2) -> void:
	var splat := Sprite2D.new()
	splat.texture = SPLAT_TEXTURE
	splat.hframes = SPLAT_FRAMES
	splat.centered = false
	splat.offset = Vector2(-SPLAT_TEXTURE.get_width() / SPLAT_FRAMES / 2.0, -SPLAT_TEXTURE.get_height())
	splat.position = at
	_drops.add_child(splat)
	_play_sfx(preload("res://assets/audio/ui_hover.wav"), DROP_SFX_DB, _rng.randf_range(0.7, 1.2))
	var flinch := create_tween()
	flinch.tween_property(_mound, "scale", FLINCH_SCALE, FLINCH_TIME * 0.3)
	flinch.tween_property(_mound, "scale", Vector2.ONE, FLINCH_TIME * 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for f in SPLAT_FRAMES:
		splat.frame = f
		await get_tree().create_timer(SPLAT_FRAME_TIME).timeout
	splat.queue_free()


# ---------------- lamp flicker ----------------
func _flicker_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(_rng.randf_range(FLICKER_EVERY[0], FLICKER_EVERY[1])).timeout
		var off := true
		for duration: float in FLICKER_PATTERN:
			_cone.visible = not off
			_dim.color.a = FLICKER_DIM if off else 0.0
			await get_tree().create_timer(duration).timeout
			off = not off
		_cone.visible = true
		_dim.color.a = 0.0
