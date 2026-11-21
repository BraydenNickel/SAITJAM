extends Control
## Bet screen: odds come from simulating the real matchup once on open.

@onready var _rows_box: VBoxContainer = %RowsBox
@onready var _sim_label: Label = %SimLabel
@onready var _hint_label: Label = %HintLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _total_label: Label = %TotalLabel
@onready var _adapt_label: Label = %AdaptLabel
@onready var _back_button: Button = %BackButton
@onready var _skip_button: Button = %SkipButton
@onready var _fight_button: Button = %FightButton
@onready var _sfx: SfxPlayer = %Sfx

var _rows: Array[BetRow] = []

func _ready() -> void:
	Game.ensure_run()
	if Game.enemy_team.is_empty():
		Game.prepare_battle()
	for child: Node in _rows_box.get_children():
		var row: BetRow = child as BetRow
		if row != null:
			_rows.append(row)
			row.changed.connect(_on_row_changed)
	_back_button.pressed.connect(func() -> void: Game.go_to(&"formation"))
	_skip_button.pressed.connect(_on_skip_pressed)
	_fight_button.pressed.connect(_on_fight_pressed)
	for button: Button in [_back_button, _skip_button, _fight_button]:
		button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_rows_box.visible = false
	_fight_button.disabled = true
	_skip_button.disabled = true
	_gold_label.text = "Gold: %d" % Game.run.gold
	_hint_label.text = "Max %d claims. Odds come from %d simulated fights." % [
		Tuning.BET_MAX_CLAIMS, Tuning.SIM_RUNS]
	_sim_label.visible = true
	_show_adapt()
	# Let "Simulating..." render for a frame before the blocking estimate.
	await get_tree().process_frame
	await get_tree().process_frame
	_run_estimate()

## Adaptive scaling is shown, never hidden (design/balance/stage3-tuning.md §6).
## The odds below already simulate the adapted enemy team.
func _show_adapt() -> void:
	_adapt_label.visible = Game.enemy_adapt > 0
	if Game.enemy_adapt > 0:
		_adapt_label.text = "Enemies adapt to your lab: +%d power" % Game.enemy_adapt

func _run_estimate() -> void:
	var lineup: Dictionary = Game.build_lineup()
	var team: Array[MonsterData] = lineup["team"]
	var spots: Array[int] = lineup["spots"]
	var roster_idx: Array[int] = lineup["roster_idx"]
	var odds: Dictionary = BetOdds.estimate(team, spots, roster_idx,
		Game.enemy_team, Game.enemy_spots, Game.battle_seed())
	var max_stake: int = floori(Game.run.gold * Tuning.BET_STAKE_CAP)
	var names: Dictionary = {}
	for ri: int in roster_idx:
		names[ri] = Game.run.roster[ri].display_name
	for row: BetRow in _rows:
		if row.claim == &"mvp":
			row.setup_mvp(odds.get(&"mvp", {}) as Dictionary, names, max_stake)
		else:
			row.setup(float(odds.get(row.claim, 0.0)), max_stake)
	_sim_label.visible = false
	_rows_box.visible = true
	_fight_button.disabled = false
	_skip_button.disabled = false
	_update_total()

func _active_rows() -> Array[BetRow]:
	var out: Array[BetRow] = []
	for row: BetRow in _rows:
		if row.is_active():
			out.append(row)
	return out

func _on_row_changed(row: BetRow) -> void:
	var active: Array[BetRow] = _active_rows()
	if active.size() > Tuning.BET_MAX_CLAIMS and row.is_active():
		row.set_active(false)  # re-enters this handler with the toggle off
		return
	_update_total()

func _update_total() -> void:
	var total: int = 0
	var count: int = 0
	for row: BetRow in _active_rows():
		total += row.stake()
		count += 1
	_total_label.text = "Claims: %d/%d   Total stake: %dg   Gold after: %dg" % [
		count, Tuning.BET_MAX_CLAIMS, total, Game.run.gold - total]

func _on_skip_pressed() -> void:
	Game.bets = []
	Game.go_to(&"battle")

func _on_fight_pressed() -> void:
	var placed: Array[Dictionary] = []
	var total: int = 0
	for row: BetRow in _active_rows():
		placed.append(row.to_bet())
		total += row.stake()
	if total > Game.run.gold:
		return  # cannot happen with the per-claim cap, but never go negative
	Game.add_gold(-total)
	Game.bets = placed
	Game.go_to(&"battle")
