class_name SettingsMenu
extends CanvasLayer
## Modal settings panel (audio volumes). Instance it hidden in a screen and
## call open()/toggle(). Slider changes apply live through GameSettings and are
## saved when the panel closes. Esc (ui_cancel) closes it.

## Emitted after the panel closes (settings already saved).
signal closed

@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _close_button: Button = %CloseButton
@onready var _sfx: SfxPlayer = %Sfx
@onready var _run_buttons: HBoxContainer = %RunButtons
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitButton

const TEXT_RESTART: String = "Restart Run"
const TEXT_RESTART_CONFIRM: String = "Confirm restart?"
const TEXT_QUIT: String = "Quit to Menu"
const TEXT_QUIT_CONFIRM: String = "Confirm quit?"

var _restart_armed: bool = false
var _quit_armed: bool = false

## Slider -> [bus, value label].
var _bindings: Dictionary = {}

func _ready() -> void:
	_bindings = {
		_master_slider: [GameSettings.BUS_MASTER, _master_value],
		_music_slider: [GameSettings.BUS_MUSIC, _music_value],
		_sfx_slider: [GameSettings.BUS_SFX, _sfx_value],
	}
	for slider: HSlider in _bindings.keys():
		slider.value_changed.connect(_on_slider_changed.bind(slider))
	# Audible preview of the effects volume when the player lets go.
	_sfx_slider.drag_ended.connect(func(_changed: bool) -> void: _sfx.play(&"click"))
	_close_button.pressed.connect(close)
	_close_button.pressed.connect(_sfx.play.bind(&"click"))
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

## Shows the panel with the current saved volumes.
func open() -> void:
	_reset_confirms()
	_run_buttons.visible = _in_run()
	for slider: HSlider in _bindings.keys():
		var bus: StringName = (_bindings[slider] as Array)[0]
		slider.set_value_no_signal(GameSettings.get_volume(bus))
		_update_label(slider)
	visible = true
	_master_slider.grab_focus()

## Hides the panel and saves the settings.
func close() -> void:
	if not visible:
		return
	visible = false
	_reset_confirms()
	GameSettings.save_settings()
	closed.emit()

## Opens the panel when hidden, closes it when shown.
func toggle() -> void:
	if visible:
		close()
	else:
		open()

## True while the panel is shown.
func is_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

## True when a run exists and the current scene is not the title screen (the run
## object can outlive a finished run while the title is showing).
func _in_run() -> bool:
	if Game.run == null:
		return false
	var scene: Node = get_tree().current_scene
	return scene == null or scene.scene_file_path != Game.SCREENS[&"title"]

func _reset_confirms() -> void:
	_restart_armed = false
	_quit_armed = false
	_restart_button.text = TEXT_RESTART
	_quit_button.text = TEXT_QUIT

func _on_restart_pressed() -> void:
	if not _restart_armed:
		_reset_confirms()
		_restart_armed = true
		_restart_button.text = TEXT_RESTART_CONFIRM
		_sfx.play(&"click")
		return
	_sfx.play_detached(&"click")
	close()
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.new_run()
	Game.go_to(&"hub")

func _on_quit_pressed() -> void:
	if not _quit_armed:
		_reset_confirms()
		_quit_armed = true
		_quit_button.text = TEXT_QUIT_CONFIRM
		_sfx.play(&"click")
		return
	_sfx.play_detached(&"click")
	close()
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.run = null
	Game.go_to(&"title")

func _on_slider_changed(value: float, slider: HSlider) -> void:
	GameSettings.set_volume((_bindings[slider] as Array)[0] as StringName, value)
	_update_label(slider)

func _update_label(slider: HSlider) -> void:
	((_bindings[slider] as Array)[1] as Label).text = "%d%%" % roundi(slider.value * 100.0)
