extends Control
## Run-end screen: victory or defeat summary, per-battle log (RunState.battle_log)
## and the Codex entries discovered during the run.

## Row scene instanced into BattleRows, one per logged battle.
@export var row_scene: PackedScene

@onready var _title_label: Label = %TitleLabel
@onready var _cleared_label: Label = %ClearedLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _beat_champion_label: Label = %BeatChampionLabel
@onready var _champion_saved_label: Label = %ChampionSavedLabel
@onready var _new_run_button: Button = %NewRunButton
@onready var _title_button: Button = %TitleButton
@onready var _sfx: SfxPlayer = %Sfx
@onready var _battle_rows: VBoxContainer = %BattleRows
@onready var _no_battles_label: Label = %NoBattlesLabel
@onready var _new_label: Label = %NewLabel

func _ready() -> void:
	Game.ensure_run()
	_title_label.text = "VICTORY!" if Game.run_victory else "DEFEAT"
	_title_label.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.2) if Game.run_victory else Color(1.0, 0.45, 0.4))
	_cleared_label.text = "Battles cleared: %d/%d" % [Game.battles_cleared, Tuning.BATTLES_PER_RUN]
	_gold_label.text = "Final gold: %d" % Game.run.gold
	# Champion boss (handoff.md §2): texts live in run_end.tscn, shown on a won run.
	_champion_saved_label.visible = Game.run_victory and Game.champion_saved
	_beat_champion_label.visible = Game.run_victory and Game.beat_champion
	var slots: Array[MonsterSlot] = [%Team1, %Team2, %Team3, %Team4]
	var lineup: Dictionary = Game.build_lineup()
	var team: Array[MonsterData] = lineup["team"]
	for i: int in slots.size():
		slots[i].visible = i < team.size()
		if i < team.size():
			slots[i].set_monster(team[i])
	_fill_summary()
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_title_button.pressed.connect(func() -> void: Game.go_to(&"title"))
	_new_run_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_title_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_sfx.play(&"win_big" if Game.run_victory else &"lose")

## Battle rows from the run's log, then the "New this run" Codex names.
func _fill_summary() -> void:
	for child: Node in _battle_rows.get_children():
		child.queue_free()
	for entry: Dictionary in Game.run.battle_log:
		var row: RunSummaryRow = row_scene.instantiate() as RunSummaryRow
		row.setup(entry)
		_battle_rows.add_child(row)
	_no_battles_label.visible = Game.run.battle_log.is_empty()
	var now: Dictionary = CodexStore.load_codex(Game.codex_path)
	var names: Array[String] = RunSummary.new_codex_names(Game.run.codex_start, now)
	if names.is_empty():
		return  # NewLabel keeps its "nothing new" text from the scene.
	var shown: Array[String] = names.slice(0, Tuning.RUN_SUMMARY_MAX_NEW)
	var text: String = ", ".join(shown)
	if names.size() > shown.size():
		text += " +%d more" % (names.size() - shown.size())
	_new_label.text = text

func _on_new_run_pressed() -> void:
	Game.new_run()
	Game.go_to(&"hub")
