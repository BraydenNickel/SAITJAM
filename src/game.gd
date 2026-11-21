extends Node
## Autoload "Game": owns the current RunState and screen navigation.

## Emitted whenever the run's gold changes.
signal gold_changed(new_gold: int)

const SCREENS: Dictionary = {
	&"title": "res://scenes/main_menu.tscn",
	&"hub": "res://src/screens/hub.tscn",
	&"roster": "res://src/screens/roster.tscn",
	&"formation": "res://src/screens/formation.tscn",
	&"bet": "res://src/screens/bet.tscn",
	&"battle": "res://src/battle/battle.tscn",
	&"run_end": "res://src/screens/run_end.tscn",
	&"lab": "res://src/screens/lab.tscn",
	&"shop": "res://src/screens/shop.tscn",
	&"reward": "res://src/screens/reward.tscn",
	&"incubator": "res://src/screens/incubator.tscn",
	&"codex": "res://src/screens/codex.tscn",
}
const HUMAN_PATH: String = "res://src/data/kinds/human.tres"
const MANTIS_ARM_PATH: String = "res://src/data/mutations/mantis_arm.tres"
const SCORPION_TAIL_PATH: String = "res://src/data/mutations/scorpion_tail.tres"
## complete_battle() `net` default: compute the net from the placed bets.
const NET_FROM_BETS: int = -2147483648

## The active run, or null before new_run()/ensure_run().
var run: RunState
## Run-wide RNG for the lab, shop and rewards. Seeded from run.rng_seed.
var rng: RandomNumberGenerator

# --- Transient battle setup (filled by prepare_battle(), bet screen) ---
## Enemy team for the upcoming battle.
var enemy_team: Array[MonsterData] = []
## Formation spot (0-5) of each enemy, parallel to enemy_team.
var enemy_spots: Array[int] = []
## Adaptive scaling bonus (extra enemy budget) of the upcoming battle; shown on
## the bet screen (design/balance/stage3-tuning.md §6).
var enemy_adapt: int = 0
## Placed bets: {claim: StringName, stake: int, mult: float, mvp_roster_idx: int}.
var bets: Array[Dictionary] = []
## Result dictionary of the last finished battle (see BattleSim.result()).
var last_result: Dictionary = {}
## Set when the run ends: true if the final battle was won.
var run_victory: bool = false
## Battles won in the current run (shown on the run-end screen).
var battles_cleared: int = 0
## Champion save file. Tests may point this elsewhere; the game uses the default.
var champion_path: String = ChampionStore.DEFAULT_PATH
## True if the upcoming battle's enemy is the saved champion (set by prepare_battle()).
var enemy_is_champion: bool = false
## Set at the end of a won run: true if this run beat a saved champion.
var beat_champion: bool = false
## Set at the end of a won run: true if the winning team was saved as champion.
var champion_saved: bool = false
## Codex save file snapshotted at new_run() for the run-end "New this run" list.
var codex_path: String = CodexStore.DEFAULT_PATH

func _ready() -> void:
	# Player audio volumes (user://settings.cfg) onto the buses, once per launch.
	GameSettings.load_settings()
	GameSettings.apply()

## Starts a fresh run with the starting roster and gold.
func new_run() -> void:
	run = RunState.new()
	run.rng_seed = randi()
	rng = RandomNumberGenerator.new()
	rng.seed = run.rng_seed
	enemy_team = []
	enemy_spots = []
	enemy_adapt = 0
	bets = []
	last_result = {}
	run_victory = false
	battles_cleared = 0
	enemy_is_champion = false
	beat_champion = false
	champion_saved = false
	run.gold = Tuning.START_GOLD
	run.codex_start = CodexStore.load_codex(codex_path)
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
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = run.rng_seed

## Adds (or subtracts, if negative) gold and notifies listeners.
func add_gold(amount: int) -> void:
	ensure_run()
	run.gold += amount
	gold_changed.emit(run.gold)

## Re-emits gold_changed. Call after logic code (LabLogic, ShopLogic,
## RewardLogic) that may have changed run.gold directly.
func notify_gold() -> void:
	ensure_run()
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
## Called when the formation screen opens, i.e. after the hub (shop, lab,
## incubator), so the adaptive power reflects the roster at fight time.
## Formation cannot change the roster, so the power stays valid through the bet.
func prepare_battle() -> void:
	ensure_run()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = battle_seed()
	# Final battle: the saved champion replaces Dr. Splice (handoff.md §2).
	var champion: Array[MonsterData] = []
	if run.battle_index == Tuning.BATTLES_PER_RUN - 1:
		champion = ChampionStore.load_team(champion_path)
	var gen: Dictionary = EnemyGen.generate_for_battle(run.battle_index, rng,
		EnemyGen.player_power(run.roster), champion)
	enemy_team.assign(gen[&"team"] as Array)
	enemy_spots.assign(gen[&"spots"] as Array)
	enemy_adapt = int(gen.get(&"adapt", 0))
	enemy_is_champion = bool(gen.get(&"champion", false))
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

## Ends the run as a loss outside a battle (the Incubator turned the last living
## monsters into mush) and shows the run-end screen, like a lost battle does.
func end_run_lost() -> void:
	ensure_run()
	bets = []
	run_victory = false
	go_to(&"run_end")

## Applies the end of a battle: logs it for the run-end summary, adds
## `gold_delta` (reward + bet payouts), then routes to the reward pick before the
## next battle, or to the run-end screen on a loss / after the final win.
## `net` = reward + payouts - stakes; left at NET_FROM_BETS it is computed from
## `bets` (still the placed bets at this point).
func complete_battle(won: bool, gold_delta: int, net: int = NET_FROM_BETS) -> void:
	ensure_run()
	if net == NET_FROM_BETS:
		net = RunSummary.net_from_bets(gold_delta, bets)
	run.battle_log.append(RunSummary.make_entry(run.battle_index + 1, won, net,
		last_result, run.roster))
	add_gold(gold_delta)
	bets = []
	if won:
		battles_cleared += 1
	if won and run.battle_index < Tuning.BATTLES_PER_RUN - 1:
		run.battle_index += 1
		go_to(&"reward")
	else:
		run_victory = won
		if won:
			_save_champion()
		go_to(&"run_end")

## Final battle won: remembers whether a champion was beaten and saves the
## battle-5 lineup (living monsters, max Tuning.MAX_TEAM) as the next champion,
## falling back to the living roster if the lineup is empty.
func _save_champion() -> void:
	beat_champion = enemy_is_champion
	var team: Array[MonsterData] = []
	team.assign(build_lineup()["team"] as Array)
	if team.is_empty():
		for m: MonsterData in run.roster:
			if m != null and not m.mushed:
				team.append(m)
	champion_saved = ChampionStore.save_team(team, champion_path)
