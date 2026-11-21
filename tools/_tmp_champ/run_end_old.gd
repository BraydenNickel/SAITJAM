extends Control
## Run-end screen: victory or defeat summary.

@onready var _title_label: Label = %TitleLabel
@onready var _cleared_label: Label = %ClearedLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _new_run_button: Button = %NewRunButton
@onready var _title_button: Button = %TitleButton
@onready var _sfx: SfxPlayer = %Sfx

func _ready() -> void:
	Game.ensure_run()
	_title_label.text = "VICTORY!" if Game.run_victory else "DEFEAT"
	_title_label.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.2) if Game.run_victory else Color(1.0, 0.45, 0.4))
	_cleared_label.text = "Battles cleared: %d/%d" % [Game.battles_cleared, Tuning.BATTLES_PER_RUN]
	_gold_label.text = "Final gold: %d" % Game.run.gold
	var slots: Array[MonsterSlot] = [%Team1, %Team2, %Team3, %Team4]
	var lineup: Dictionary = Game.build_lineup()
	var team: Array[MonsterData] = lineup["team"]
	for i: int in slots.size():
		slots[i].visible = i < team.size()
		if i < team.size():
			slots[i].set_monster(team[i])
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_title_button.pressed.connect(func() -> void: Game.go_to(&"title"))
	_new_run_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_title_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_sfx.play(&"win_big" if Game.run_victory else &"lose")

func _on_new_run_pressed() -> void:
	Game.new_run()
	Game.go_to(&"hub")
