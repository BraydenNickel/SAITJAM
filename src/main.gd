extends Control
## Title screen.

@onready var _new_run_button: Button = %NewRunButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _on_new_run_pressed() -> void:
	Game.new_run()
	Game.go_to(&"hub")

func _on_quit_pressed() -> void:
	get_tree().quit()
