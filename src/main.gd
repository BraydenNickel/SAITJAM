extends Control
## Title screen.

@onready var _new_run_button: Button = %NewRunButton
@onready var _quit_button: Button = %QuitButton
@onready var _sfx: SfxPlayer = %Sfx

func _ready() -> void:
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_new_run_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	%CodexButton.pressed.connect(_sfx.play_detached.bind(&"click"))
	%CodexButton.pressed.connect(func() -> void: Game.go_to(&"codex"))
	%SettingsButton.pressed.connect(_sfx.play.bind(&"click"))
	%SettingsButton.pressed.connect(%SettingsMenu.open)
	%SettingsMenu.closed.connect(%SettingsButton.grab_focus)

func _on_new_run_pressed() -> void:
	Game.new_run()
	Game.go_to(&"hub")

func _on_quit_pressed() -> void:
	get_tree().quit()
