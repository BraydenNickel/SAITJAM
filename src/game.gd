extends Node
## Autoload "Game": owns the current RunState and screen navigation.

## Emitted whenever the run's gold changes.
signal gold_changed(new_gold: int)

const SCREENS: Dictionary = {
	&"title": "res://src/main.tscn",
	&"hub": "res://src/screens/hub.tscn",
	&"roster": "res://src/screens/roster.tscn",
	&"formation": "res://src/screens/formation.tscn",
	&"bet": "res://src/screens/bet.tscn",
	&"battle": "res://src/battle/battle.tscn",
	&"run_end": "res://src/screens/run_end.tscn",
}
const HUMAN_PATH: String = "res://src/data/kinds/human.tres"
const MANTIS_ARM_PATH: String = "res://src/data/mutations/mantis_arm.tres"
const SCORPION_TAIL_PATH: String = "res://src/data/mutations/scorpion_tail.tres"

## The active run, or null before new_run()/ensure_run().
var run: RunState

# --- Transient battle setup (filled by prepare_battle(), bet screen) ---
## Enemy team for the upcoming battle.
var enemy_team: Array[MonsterData] = []
## Formation spot (0-5) of each enemy, parallel to enemy_team.
var enemy_spots: Array[int] = []
## Placed bets: {claim: StringName, stake: int, mult: float, mvp_roster_idx: int}.
var bets: Array[Dictionary] = []
## Result dictionary of the last finished battle (see BattleSim.result()).
var last_result: Dictionary = {}
## Set when the run ends: true if the final battle was won.
var run_victory: bool = false
## Battles won in the current run (shown on the run-end screen).
var battles_cleared: int = 0

## Starts a fresh run with the starting roster and gold.
func new_run() -> void:
	run = RunState.new()
	run.rng_seed = randi()
	enemy_team = []
	enemy_spots = []
	bets = []
	last_result = {}
	run_victory = false
	battles_cleared = 0
	run.gold = Tuning.START_GOLD
	var human: MonsterData = load(HUMAN_PATH) as MonsterData
	for i: int in Tuning.START_HUMANS:
		var m: MonsterData = human.clone()
		m.display_name = "Subject %02d" % (i + 1)
		run.roster.append(m)
		run.formation[i] = i
	# Stage-1 visibility: give Subject 02 a couple of mutations.
	if run.roster.size() > 1:
		run.roster[1].apply_mutation(load(MANTIS_ARM_PATH) as MutationData, &"ARM_R")
		run.roster[1].apply_mutation(load(SCORPION_TAIL_PATH) as MutationData, &"TAIL")
	gold_changed.emit(run.gold)

## Makes sure a run exists (lets any screen be run alone with F6).
func ensure_run() -> void:
	if run == null:
		new_run()

## Adds (or subtracts, if negative) gold and notifies listeners.
func add_gold(amount: int) -> void:
	ensure_run()
	run.gold += amount
	gold_changed.emit(run.gold)

## Switches to a screen registered in SCREENS.
func go_to(screen_id: StringName) -> void:
	if not SCREENS.has(screen_id):
		push_error("Game.go_to: unknown screen '%s'" % screen_id)
		return
	get_tree().change_scene_to_file(SCREENS[screen_id] as String)

## Deterministic seed for the current battle (run seed + battle index).
func battle_seed() -> int:
	ensure_run()
	return hash([run.rng_seed, run.battle_index])

## Generates the enemy team for the current battle and clears old bets.
func prepare_battle() -> void:
	ensure_run()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = battle_seed()
	var gen: Dictionary = EnemyGen.generate(run.battle_index, rng)
	enemy_team.assign(gen["team"] as Array)
	enemy_spots.assign(gen["spots"] as Array)
	bets = []
	last_result = {}

## The player's lineup from RunState.formation, ordered by spot. Skips invalid
## and mushed entries. Keys: "team" (Array[MonsterData]), "spots" (Array[int]),
## "roster_idx" (Array[int]); all parallel.
func build_lineup() -> Dictionary:
	ensure_run()
	var spot_list: Array[int] = []
	for key: Variant in run.formation.keys():
		spot_list.append(int(key))
	spot_list.sort()
	var team: Array[MonsterData] = []
	var spots: Array[int] = []
	var roster_idx: Array[int] = []
	for spot: int in spot_list:
		var ri: int = int(run.formation[spot])
		if ri < 0 or ri >= run.roster.size() or run.roster[ri].mushed:
			continue
		team.append(run.roster[ri])
		spots.append(spot)
		roster_idx.append(ri)
	return {"team": team, "spots": spots, "roster_idx": roster_idx}

## Applies the end of a battle: adds `gold_delta`, then routes to the hub for
## the next battle, or to the run-end screen on a loss / after the final win.
func complete_battle(won: bool, gold_delta: int) -> void:
	ensure_run()
	add_gold(gold_delta)
	bets = []
	if won:
		battles_cleared += 1
	if won and run.battle_index < Tuning.BATTLES_PER_RUN - 1:
		run.battle_index += 1
		# TODO(stage 3): reward pick (1 of 3) before returning to the hub.
		go_to(&"hub")
	else:
		run_victory = won
		go_to(&"run_end")
