extends SceneTree
## Full-run balance simulator for MUTANT LAB (Stage 3 balance pass).
##
## Plays N complete runs per policy with the real logic classes (ShopLogic,
## LabLogic, RewardLogic, EnemyGen) and the real headless BattleSim. No scenes,
## no Game autoload: Game.new_run() is replicated inline. Deterministic: run i of
## every policy uses run seed (seed + i), and the run RNG / battle seeds follow
## the game exactly (Game.rng for shop/lab/rewards, hash([rng_seed, battle_index])
## for enemy generation and the fight). Policy decisions use their own RNG, so
## they never shift the game's random streams.
##
## Usage (from the project folder):
##   "<godot>" --headless --path . -s res://tools/balance/run_sim.gd -- runs=500 policy=all
## Args (all optional):
##   runs=N        runs per policy (default 500)
##   policy=NAME   greedy | cautious | random | build | all (default all)
##   seed=N        base run seed (default 1)
##   odds=N        BetOdds sims per fight to record P(win) of the actual matchup (default 10, 0 = off)
##   out=PATH      markdown report path (default res://reports/balance_baseline.md, "none" = skip)
##                 (a per-mutation CSV is written next to it as <out>_mutations.csv)
##   bodies=0|1|2  1 = greedy / cautious / build buy a human before parts while they
##                 have fewer than 3 living monsters; 2 = greedy / cautious do so
##                 from battle 2 on; 0 = only after parts (default 0)
##   mode=fusion   fused-part power check (see _fusion_arena()): fights=N (default 100),
##                 out=PATH (default res://reports/arena_fusion.md, CSV next to it)
##   mode=arena    per-mutation power ranking instead of full runs (see _arena()):
##                 fights=N per configuration (default 200), out=PATH (default
##                 res://reports/arena.md, CSV next to it)

const POLICIES: Array[String] = ["greedy", "cautious", "random", "build"]
const HUMAN_PATH: String = "res://src/data/kinds/human.tres"
const MANTIS_ARM_PATH: String = "res://src/data/mutations/mantis_arm.tres"
const SCORPION_TAIL_PATH: String = "res://src/data/mutations/scorpion_tail.tres"

## Reward preference per policy (first available wins). "random" picks at random.
const REWARD_PREF: Dictionary = {
	"greedy": [&"free_mutation", &"stabilizers", &"gold", &"free_human", &"catalyst",
		&"lucky_gene", &"insurance", &"cleanse"],
	"cautious": [&"stabilizers", &"free_mutation", &"insurance", &"lucky_gene", &"cleanse",
		&"gold", &"free_human", &"catalyst"],
}
## Lab thresholds per policy: [use stabilizers while chance < this, operate only if chance >= this].
const LAB_RULES: Dictionary = {
	"greedy": [70, 50],
	"cautious": [80, 80],
}
## Living-monster count under which a policy buys a human.
const HUMAN_BELOW: int = 3

# --- "build" policy (design/balance/stage4-balance.md) ---
# Role-driven, no mutation ids: every piece gets a value in "power points" for
# the role of the monster that would wear it (carry / tank / support).
# 1 point = +40 HP = +1.5 ATK = -0.1 s interval = +2 DEF = +8% crit (the guide
# in tools/mutation_table.py); an ability is worth BASE + PER_RARITY * rarity
# points times the role weight of its kind.
const ROLE_CARRY: int = 0
const ROLE_TANK: int = 1
const ROLE_SUPPORT: int = 2
const KIND_OFFENSE: int = 0
const KIND_DEFENSE: int = 1
const KIND_TEAM: int = 2
const KIND_RANGED: int = 3
## Ability id -> kind. Offense = on own basic hits, defense = keeps the wearer
## alive, team = helps allies, ranged = damage that does not need the wearer to hit.
const ABILITY_KIND: Dictionary = {
	&"double_strike": KIND_OFFENSE, &"venom": KIND_OFFENSE, &"execute": KIND_OFFENSE,
	&"cleave": KIND_OFFENSE, &"chain": KIND_OFFENSE, &"momentum": KIND_OFFENSE,
	&"burn": KIND_OFFENSE, &"corrode": KIND_OFFENSE, &"stun": KIND_OFFENSE,
	&"chill": KIND_OFFENSE, &"lifesteal": KIND_OFFENSE,
	&"reflect": KIND_DEFENSE, &"regen": KIND_DEFENSE, &"thorns": KIND_DEFENSE,
	&"shield": KIND_DEFENSE, &"rage": KIND_DEFENSE, &"berserk": KIND_DEFENSE,
	&"second_wind": KIND_DEFENSE, &"dodge": KIND_DEFENSE, &"titan": KIND_DEFENSE,
	&"phase": KIND_DEFENSE,
	&"war_cry": KIND_TEAM, &"mend": KIND_TEAM, &"vengeance": KIND_TEAM,
	&"snipe": KIND_RANGED, &"spore_pulse": KIND_RANGED, &"swarm": KIND_RANGED,
	&"ambush": KIND_RANGED,
}
## Abilities that do nothing in a 1v1 (arena score uses the 2v2 only).
const ARENA_TEAM_ONLY: Array[StringName] = [&"war_cry", &"mend", &"vengeance", &"cleave", &"chain"]
## [offence stat weight, defence stat weight] per role.
const BUILD_STAT_WEIGHT: Array = [[1.0, 0.3], [0.4, 1.0], [0.8, 0.2]]
## Ability weight per role, indexed by kind (offense, defense, team, ranged).
const BUILD_ABILITY_WEIGHT: Array = [[1.0, 0.5, 0.4, 0.8], [0.4, 1.0, 0.6, 0.6], [0.4, 0.2, 1.0, 1.0]]
const BUILD_ABILITY_BASE: float = 1.0
const BUILD_ABILITY_PER_RARITY: float = 0.75
## Added when the wearer already has two pieces sharing a tag with the new one.
const BUILD_ARCHETYPE_BONUS: float = 0.75
## A shop piece is "on plan" when its value for its best wearer is at least this (by rarity).
const BUILD_MIN_VALUE: Array[float] = [1.0, 1.8, 2.6, 4.0]
## Spare gold (>= BUILD_OFFPLAN_GOLD) and free rewards accept this fraction of BUILD_MIN_VALUE.
const BUILD_SPARE_FRACTION: float = 0.5
## Stabilize each planned op up to this success %.
const BUILD_TARGET_CHANCE: int = 90
## Operate only at or above this success %.
const BUILD_MIN_CHANCE: int = 85
const BUILD_MAX_REROLLS: int = 2
## Reroll only if gold >= reroll cost + this.
const BUILD_REROLL_RESERVE: int = 18
## Bodies beyond the second (up to BUILD_MAX_BODIES) only if gold >= PRICE_HUMAN + this.
const BUILD_HUMAN_RESERVE: int = 10
const BUILD_MAX_BODIES: int = 4
## Below this many living monsters a body is bought before any part.
const BUILD_BODIES_FIRST: int = 3
## Below-threshold pieces only if gold >= this.
const BUILD_OFFPLAN_GOLD: int = 25
## Take Catalyst when the carry's instability is at least this.
const BUILD_CATALYST_INSTABILITY: float = 40.0
## Tank spot (front), carry spot (middle row) and spots for other non-carry monsters.
const BUILD_TANK_SPOT: int = 0
const BUILD_CARRY_SPOT: int = 2
const BUILD_OTHER_SPOTS: Array[int] = [1, 3, 4, 5]
## Spot order for monsters wearing a team / ranged ability (back row first).
const BUILD_SUPPORT_SPOTS: Array[int] = [4, 5, 3, 1]
const RARITY_NAMES: Array[String] = ["common", "uncommon", "rare", "ultra"]
## Minimum owning runs for a mutation to appear in the console outlier list.
const REPORT_MIN_N: int = 15

# --- arena mode ---
## Power points a piece of each rarity is meant to be worth: 1.5 x the guide in
## tools/mutation_table.py (pass 2: a common part must matter next to a body). The "par" dummy is a
## plain human with this many points of plain stats, half HP and half ATK.
const ARENA_PAR: Array[float] = [2.25, 3.75, 6.0, 9.75]
const ARENA_PAR_HP_PER_POINT: float = 20.0
const ARENA_PAR_ATK_PER_POINT: float = 0.75
## Win-point distance from the rarity median that is flagged as an outlier.
const ARENA_OUTLIER: float = 15.0

var _human: MonsterData
var _mantis: MutationData
var _scorpion: MutationData
var _odds_runs: int = 10
## build policy: roster index of the current carry (-1 = pick again).
var _carry: int = -1
## Per-run flags for the mutation / ULTRA report (reset in _play_run).
var _flags: Dictionary = {}
## bodies=1: greedy / cautious / build buy a third body before parts.
var _bodies_first: bool = false
## bodies=2: greedy / cautious do so from battle 2 on (battle 1 is played as bought).
var _bodies_late: bool = false

func _initialize() -> void:
	var args: Dictionary = _parse_args()
	var runs: int = int(args.get("runs", "500"))
	var base_seed: int = int(args.get("seed", "1"))
	_odds_runs = int(args.get("odds", "10"))
	var policy_arg: String = args.get("policy", "all")
	var out_path: String = args.get("out", "res://reports/balance_baseline.md")
	_human = load(HUMAN_PATH) as MonsterData
	_mantis = load(MANTIS_ARM_PATH) as MutationData
	_scorpion = load(SCORPION_TAIL_PATH) as MutationData
	_bodies_first = int(args.get("bodies", "0")) == 1
	_bodies_late = int(args.get("bodies", "0")) == 2
	if args.get("mode", "run") == "arena":
		_arena(args)
		quit()
		return
	if args.get("mode", "run") == "fusion":
		_fusion_arena(args)
		quit()
		return

	var policies: Array[String] = []
	if policy_arg == "all":
		policies = POLICIES.duplicate()
	elif POLICIES.has(policy_arg):
		policies = [policy_arg]
	else:
		printerr("Unknown policy '%s' (use %s or all)" % [policy_arg, ", ".join(POLICIES)])
		quit(1)
		return

	var cmd: String = '"C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . ' \
		+ "-s res://tools/balance/run_sim.gd -- runs=%d policy=%s seed=%d odds=%d bodies=%d" % [
			runs, policy_arg, base_seed, _odds_runs, 1 if _bodies_first else (2 if _bodies_late else 0)]
	var results: Array[Dictionary] = []
	var t0: int = Time.get_ticks_msec()
	for p: String in policies:
		var tp: int = Time.get_ticks_msec()
		var st: Dictionary = _new_stats(p, runs)
		for i: int in runs:
			_play_run(p, base_seed + i, st)
		st["elapsed_ms"] = Time.get_ticks_msec() - tp
		results.append(st)
		print(_text_table(st))
	print("Total sim time: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if out_path != "none":
		var md: String = _markdown(results, cmd)
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if f == null:
			printerr("Could not write %s (error %d)" % [out_path, FileAccess.get_open_error()])
		else:
			f.store_string(md)
			f.close()
			print("Wrote %s" % ProjectSettings.globalize_path(out_path))
		var cf: FileAccess = FileAccess.open(out_path.get_basename() + "_mutations.csv", FileAccess.WRITE)
		if cf != null:
			cf.store_string(_mutation_csv(results))
			cf.close()
	print(_mutation_console(results))
	quit()

func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", false, 1)
		if kv.size() == 2:
			out[kv[0]] = kv[1]
	return out

# --- One run -----------------------------------------------------------------

func _play_run(policy: String, run_seed: int, st: Dictionary) -> void:
	var B: int = Tuning.BATTLES_PER_RUN
	# Replicates Game.new_run().
	var run: RunState = RunState.new()
	run.rng_seed = run_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed
	var prng: RandomNumberGenerator = RandomNumberGenerator.new()
	prng.seed = hash([run_seed, "policy", policy])
	run.gold = Tuning.START_GOLD
	_carry = 1
	for i: int in Tuning.START_HUMANS:
		var m: MonsterData = _human.clone()
		m.display_name = "Subject %02d" % (i + 1)
		run.roster.append(m)
		run.formation[i] = i
	if run.roster.size() > 1:
		run.roster[1].apply_mutation(_mantis, &"ARM_R")
		run.roster[1].apply_mutation(_scorpion, &"TAIL")
	_flags = {"ultra_seen": false, "ultra_bought": false, "early": {}}
	var wins: int = _run_loop(policy, run, rng, prng, st)
	_record_run(run, st, wins)

## Plays the battles of one run. Returns the number of battles won.
func _run_loop(policy: String, run: RunState, rng: RandomNumberGenerator,
		prng: RandomNumberGenerator, st: Dictionary) -> int:
	var B: int = Tuning.BATTLES_PER_RUN
	while true:
		var b: int = run.battle_index
		# Hub: sponsor grant once per visit when broke (hub.gd).
		if run.gold < Tuning.SPONSOR_THRESHOLD:
			run.gold += Tuning.SPONSOR_GRANT
			st["sponsor"][b] += 1
		st["hub_visits"][b] += 1
		st["gold_hub"][b] += run.gold
		# Shop -> lab.
		ShopLogic.ensure_stock(run, rng)
		_note_stock(run)
		_shop(policy, run, rng, prng, st)
		_lab(policy, run, rng, prng, st)
		st["gold_after_spend"][b] += run.gold
		st["inv_left"][b] += run.inventory.size()
		if run.living_count() == 0:
			st["end_no_living"][b] += 1
			return b
		if b == 0:
			_flags["early"] = _owned(run)[0]
		# Formation + enemy (Game.prepare_battle / build_lineup).
		var lineup: Dictionary = _formation_build(run) if policy == "build" else _formation(run)
		var team: Array[MonsterData] = lineup["team"]
		var spots: Array[int] = lineup["spots"]
		var ridx: Array[int] = lineup["roster_idx"]
		var bseed: int = hash([run.rng_seed, b])
		var erng: RandomNumberGenerator = RandomNumberGenerator.new()
		erng.seed = bseed
		# Adaptive scaling: whole living roster at fight time, like Game.prepare_battle().
		var power: int = EnemyGen.player_power(run.roster)
		var gen: Dictionary = EnemyGen.generate(b, erng, power)
		st["power"][b] += power
		st["adapt"][b] += int(gen[&"adapt"])
		if int(gen[&"adapt"]) > 0:
			st["adapt_on"][b] += 1
		var eteam: Array[MonsterData] = []
		eteam.assign(gen["team"] as Array)
		var espots: Array[int] = []
		espots.assign(gen["spots"] as Array)

		st["reached"][b] += 1
		st["team_size"][b] += team.size()
		var living: int = 0
		var muts: int = 0
		for m: MonsterData in run.roster:
			if not m.mushed:
				living += 1
				muts += m.slots.size()
		st["living"][b] += living
		st["muts_per_living"][b] += float(muts) / maxf(1.0, float(living))
		var pp: Array[float] = _power(team)
		var ep: Array[float] = _power(eteam)
		st["p_hp"][b] += pp[0]
		st["p_dps"][b] += pp[1]
		st["e_hp"][b] += ep[0]
		st["e_dps"][b] += ep[1]

		if _odds_runs > 0:
			var odds: Dictionary = BetOdds.estimate(team, spots, ridx, eteam, espots, bseed, _odds_runs)
			st["pwin"][b] += float(odds[&"victory"])

		var sim: BattleSim = BattleSim.new(team, spots, ridx, eteam, espots, bseed, false)
		var res: Dictionary = sim.run_to_end()
		var t: float = float(res[&"time"])
		(st["dur"][b] as Array).append(t)
		if t >= Tuning.HARD_CAP:
			st["timeouts"][b] += 1
		elif t > Tuning.FRENZY_START:
			st["frenzy"][b] += 1
		var won: bool = int(res[&"winner"]) == BattleSim.PLAYER
		if not won:
			st["lost"][b] += 1
			return b
		st["won"][b] += 1
		(st["dur_win"][b] as Array).append(t)
		st["margin"][b] += _hp_left_frac(sim, BattleSim.PLAYER)
		st["deaths_win"][b] += int(res[&"player_deaths"])
		if b >= B - 1:
			return B
		# Win: battle reward (battle.gd), next battle, reward pick (reward.gd).
		run.gold += Tuning.BATTLE_REWARD[b]
		run.battle_index += 1
		var options: Array[Dictionary] = RewardLogic.roll_options(run, rng)
		for o: Dictionary in options:
			var om: MutationData = o.get(&"mutation") as MutationData
			if om != null and int(om.rarity) == MutationData.Rarity.ULTRA:
				_flags["ultra_seen"] = true
		if not options.is_empty():
			var pick: Dictionary = _pick_reward_build(run, options) if policy == "build" \
				else _pick_reward(policy, options, prng)
			var rid: StringName = pick[&"id"]
			st["rewards"][rid] = int(st["rewards"].get(rid, 0)) + 1
			RewardLogic.apply(run, pick)
	return 0

## Marks the run as having seen an ULTRA if the current shop stock holds one.
func _note_stock(run: RunState) -> void:
	for e: Dictionary in run.shop_stock:
		var m: MutationData = e.get(&"mutation") as MutationData
		if m != null and int(m.rarity) == MutationData.Rarity.ULTRA:
			_flags["ultra_seen"] = true

## [ids, ability ids, rarity names] (dictionaries used as sets, String keys)
## of every mutation installed on a living monster.
func _owned(run: RunState) -> Array[Dictionary]:
	var ids: Dictionary = {}
	var abs_: Dictionary = {}
	var rars: Dictionary = {}
	for mon: MonsterData in run.roster:
		if mon.mushed:
			continue
		for v: Variant in mon.slots.values():
			var m: MutationData = v as MutationData
			if m == null:
				continue
			ids[String(m.id)] = true
			rars[RARITY_NAMES[int(m.rarity)]] = true
			abs_[_ability_name(m)] = true
	return [ids, abs_, rars]

func _ability_name(m: MutationData) -> String:
	return String(m.ability.get_id()) if m.ability != null else "(none)"

func _bump(table: Dictionary, keys: Array, won: bool, wins: int) -> void:
	for k: Variant in keys:
		if not table.has(k):
			table[k] = [0, 0, 0]
		var a: Array = table[k]
		a[0] += 1
		a[1] += 1 if won else 0
		a[2] += wins

## End-of-run bookkeeping for the per-mutation / ability / rarity / ULTRA report.
func _record_run(run: RunState, st: Dictionary, wins: int) -> void:
	var won: bool = wins >= Tuning.BATTLES_PER_RUN
	var own: Array[Dictionary] = _owned(run)
	_bump(st["tot"], ["all"], won, wins)
	_bump(st["mut"], own[0].keys(), won, wins)
	_bump(st["ab"], own[1].keys(), won, wins)
	_bump(st["rar"], own[2].keys(), won, wins)
	_bump(st["mut_early"], (_flags["early"] as Dictionary).keys(), won, wins)
	if bool(_flags["ultra_seen"]):
		_bump(st["ultra"], ["seen"], won, wins)
	if bool(_flags["ultra_bought"]):
		_bump(st["ultra"], ["bought"], won, wins)

# --- Policies ----------------------------------------------------------------

func _shop(policy: String, run: RunState, rng: RandomNumberGenerator, prng: RandomNumberGenerator,
		st: Dictionary) -> void:
	if policy == "build":
		_shop_build(run, rng, st)
		return
	if policy == "random":
		var order: Array = range(run.shop_stock.size())
		_shuffle(order, prng)
		for idx: int in order:
			if prng.randf() < 0.5 and ShopLogic.can_buy(run, idx) == "":
				_buy(run, idx, st)
		return
	# bodies=1: a third body before parts.
	if (_bodies_first or (_bodies_late and run.battle_index >= 1)) and run.living_count() < HUMAN_BELOW:
		_buy_kind(run, ShopLogic.KIND_HUMAN, st)
	if policy == "cautious":
		_buy_kind(run, ShopLogic.KIND_STABILIZER, st)
	# Mutations, highest rarity first, only if some living monster has a free socket.
	var muts: Array[int] = []
	for idx: int in run.shop_stock.size():
		if run.shop_stock[idx][&"kind"] == ShopLogic.KIND_MUTATION:
			muts.append(idx)
	muts.sort_custom(func(a: int, c: int) -> bool:
		return int((run.shop_stock[a][&"mutation"] as MutationData).rarity) \
			> int((run.shop_stock[c][&"mutation"] as MutationData).rarity))
	for idx: int in muts:
		var m: MutationData = run.shop_stock[idx][&"mutation"]
		if ShopLogic.can_buy(run, idx) == "" and _fits_someone(run, m):
			_buy(run, idx, st)
	if run.living_count() < HUMAN_BELOW:
		_buy_kind(run, ShopLogic.KIND_HUMAN, st)

func _buy_kind(run: RunState, kind: StringName, st: Dictionary) -> bool:
	for idx: int in run.shop_stock.size():
		if run.shop_stock[idx][&"kind"] == kind and ShopLogic.can_buy(run, idx) == "":
			_buy(run, idx, st)
			return true
	return false

func _buy(run: RunState, idx: int, st: Dictionary) -> void:
	var e: Dictionary = run.shop_stock[idx]
	var price: int = int(e[&"price"])
	if ShopLogic.buy(run, idx):
		st["spent"] += price
		var key: String = String(e[&"kind"])
		if e[&"kind"] == ShopLogic.KIND_MUTATION:
			var r: int = int((e[&"mutation"] as MutationData).rarity)
			key = "mutation_" + RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]
			if r == MutationData.Rarity.ULTRA:
				_flags["ultra_bought"] = true
		st["buys"][key] = int(st["buys"].get(key, 0)) + 1

## True if `m` fits a free slot on some living monster (counting inventory already
## queued for that socket type is not attempted; this is a cheap filter).
func _fits_someone(run: RunState, m: MutationData) -> bool:
	for mon: MonsterData in run.roster:
		if not mon.mushed and not mon.slots_for(m).is_empty():
			return true
	return false

func _lab(policy: String, run: RunState, rng: RandomNumberGenerator, prng: RandomNumberGenerator,
		st: Dictionary) -> void:
	if policy == "random":
		_lab_random(run, rng, prng, st)
		return
	if policy == "build":
		_lab_build(run, rng, st)
		return
	var stab_target: int = LAB_RULES[policy][0]
	var min_chance: int = LAB_RULES[policy][1]
	var progress: bool = true
	while progress:
		progress = false
		var order: Array = range(run.inventory.size())
		order.sort_custom(func(a: int, c: int) -> bool:
			return int(run.inventory[a].rarity) > int(run.inventory[c].rarity))
		for inv_idx: int in order:
			var mut: MutationData = run.inventory[inv_idx]
			var best: Array = _best_target(run, mut)
			if best.is_empty():
				continue
			var mon: MonsterData = run.roster[int(best[0])]
			var stabs: int = 0
			var chance: int = LabLogic.success_chance(run, mon, mut, 0)
			while chance < stab_target and stabs < mini(run.stabilizers, Tuning.STABILIZER_MAX):
				stabs += 1
				chance = LabLogic.success_chance(run, mon, mut, stabs)
			if chance < min_chance:
				continue
			_operate(run, int(best[0]), inv_idx, best[1] as StringName, stabs, rng, st)
			progress = true
			break

## [roster_idx, slot] with the highest success chance (no stabilizers) for `mut`, or [].
func _best_target(run: RunState, mut: MutationData) -> Array:
	var best: Array = []
	var best_chance: int = -1
	for ri: int in run.roster.size():
		var mon: MonsterData = run.roster[ri]
		if mon.mushed:
			continue
		var free: Array[StringName] = mon.slots_for(mut)
		if free.is_empty():
			continue
		var c: int = LabLogic.success_chance(run, mon, mut, 0)
		if c > best_chance:
			best_chance = c
			best = [ri, free[0]]
	return best

func _lab_random(run: RunState, rng: RandomNumberGenerator, prng: RandomNumberGenerator,
		st: Dictionary) -> void:
	var i: int = run.inventory.size() - 1
	while i >= 0:
		if i < run.inventory.size() and prng.randf() < 0.5:
			var mut: MutationData = run.inventory[i]
			var options: Array = []
			for ri: int in run.roster.size():
				var mon: MonsterData = run.roster[ri]
				if mon.mushed:
					continue
				for slot: StringName in mon.slots_for(mut):
					options.append([ri, slot])
			if not options.is_empty():
				var o: Array = options[prng.randi_range(0, options.size() - 1)]
				var stabs: int = prng.randi_range(0, mini(run.stabilizers, Tuning.STABILIZER_MAX))
				_operate(run, int(o[0]), i, o[1] as StringName, stabs, rng, st)
		i -= 1

func _operate(run: RunState, ri: int, inv_idx: int, slot: StringName, stabs: int,
		rng: RandomNumberGenerator, st: Dictionary) -> void:
	var b: int = run.battle_index
	var r: Dictionary = LabLogic.operate(run, ri, inv_idx, slot, stabs, rng)
	if not bool(r[&"ok"]):
		push_warning("operate refused: %s" % r.get(&"reason", "?"))
		return
	st["ops"][b] += 1
	st["ops_total"] += 1
	st["chance_sum"] += int(r[&"chance"])
	st["stabs_used"] += stabs
	if bool(r[&"success"]):
		st["op_success"] += 1
	elif bool(r[&"insured"]):
		st["op_insured"] += 1
	if bool(r[&"mushed"]):
		st["mush"][b] += 1
		st["mush_total"] += 1

func _pick_reward(policy: String, options: Array[Dictionary], prng: RandomNumberGenerator) -> Dictionary:
	if policy == "random" or not REWARD_PREF.has(policy):
		return options[prng.randi_range(0, options.size() - 1)]
	for id: StringName in REWARD_PREF[policy]:
		for o: Dictionary in options:
			if o[&"id"] == id:
				return o
	return options[0]

## Living monsters, highest max HP first (ties: higher ATK, then roster order),
## placed into spots 0.. (front row first), up to MAX_TEAM. Also rewrites run.formation.
func _formation(run: RunState) -> Dictionary:
	var idx: Array[int] = []
	for ri: int in run.roster.size():
		if not run.roster[ri].mushed:
			idx.append(ri)
	var stats: Dictionary = {}
	for ri: int in idx:
		stats[ri] = run.roster[ri].get_total_stats()
	idx.sort_custom(func(a: int, c: int) -> bool:
		var sa: Dictionary = stats[a]
		var sc: Dictionary = stats[c]
		if float(sa[&"hp"]) != float(sc[&"hp"]):
			return float(sa[&"hp"]) > float(sc[&"hp"])
		if float(sa[&"atk"]) != float(sc[&"atk"]):
			return float(sa[&"atk"]) > float(sc[&"atk"])
		return a < c)
	var team: Array[MonsterData] = []
	var spots: Array[int] = []
	var ridx: Array[int] = []
	run.formation = {}
	for k: int in mini(idx.size(), Tuning.MAX_TEAM):
		team.append(run.roster[idx[k]])
		spots.append(k)
		ridx.append(idx[k])
		run.formation[k] = idx[k]
	return {"team": team, "spots": spots, "roster_idx": ridx}

# --- "build" policy (stage3-tuning.md §3) -------------------------------------

## [carry, tank] roster indices (-1 if none). Carry = Subject 02 while it lives,
## else the living monster with the most mutations. Tank = the other living
## monster with the highest max HP.
func _build_roles(run: RunState) -> Array[int]:
	if _carry < 0 or _carry >= run.roster.size() or run.roster[_carry].mushed:
		_carry = -1
		var most: int = -1
		for ri: int in run.roster.size():
			var m: MonsterData = run.roster[ri]
			if not m.mushed and m.slots.size() > most:
				most = m.slots.size()
				_carry = ri
	var tank: int = -1
	var best_hp: float = -1.0
	for ri: int in run.roster.size():
		var m: MonsterData = run.roster[ri]
		if ri == _carry or m.mushed:
			continue
		var hp: float = float(m.get_total_stats()[&"hp"])
		if hp > best_hp:
			best_hp = hp
			tank = ri
	return [_carry, tank]

func _role_of(ri: int, roles: Array[int]) -> int:
	if ri == roles[0]:
		return ROLE_CARRY
	return ROLE_TANK if ri == roles[1] else ROLE_SUPPORT

## Power points of `m` for a monster in `role` (see the consts above).
func _piece_value(m: MutationData, role: int) -> float:
	var off: float = m.atk_mod / 1.5 - m.interval_mod / 0.1 + m.crit_mod / 0.08
	var def: float = m.hp_mod / 40.0 + m.defense_mod / 2.0
	var v: float = off * float(BUILD_STAT_WEIGHT[role][0]) + def * float(BUILD_STAT_WEIGHT[role][1])
	if m.ability != null:
		var kind: int = int(ABILITY_KIND.get(m.ability.get_id(), KIND_OFFENSE))
		v += (BUILD_ABILITY_BASE + BUILD_ABILITY_PER_RARITY * float(int(m.rarity))) \
			* float(BUILD_ABILITY_WEIGHT[role][kind])
	return v

## True if `mon` already wears at least two pieces that share one tag with `m`.
func _archetype_match(mon: MonsterData, m: MutationData) -> bool:
	for tag: StringName in m.tags:
		var n: int = 0
		for v: Variant in mon.slots.values():
			var o: MutationData = v as MutationData
			if o != null and o.tags.has(tag):
				n += 1
		if n >= 2:
			return true
	return false

## Plans who wears each item (inventory, then `extra`), in order. Returns
## {targets: Array[int] (roster index, -1 = nobody), values: Array[float],
## need: int (stabilizers still to buy to bring every planned op to
## BUILD_TARGET_CHANCE; can be negative)}. A monster is skipped when even
## STABILIZER_MAX stabilizers cannot reach BUILD_MIN_CHANCE.
func _build_plan(run: RunState, roles: Array[int], extra: Array[MutationData]) -> Dictionary:
	var items: Array[MutationData] = []
	items.append_array(run.inventory)
	items.append_array(extra)
	var used: Dictionary = {}
	var inst: Dictionary = {}
	var targets: Array[int] = []
	var values: Array[float] = []
	var stabs: int = 0
	for m: MutationData in items:
		var r: int = int(m.rarity)
		var sock: int = int(m.socket_type)
		var best: int = -1
		var best_v: float = 0.0
		for ri: int in run.roster.size():
			var mon: MonsterData = run.roster[ri]
			if mon.mushed:
				continue
			var key: int = ri * 16 + sock
			if mon.slots_for(m).size() - int(used.get(key, 0)) <= 0:
				continue
			var pi: float = float(inst.get(ri, mon.instability))
			if 100.0 - pi - Tuning.RISK_PER_RARITY[r] \
					+ Tuning.STABILIZER_BONUS * Tuning.STABILIZER_MAX < BUILD_MIN_CHANCE:
				continue
			var v: float = _piece_value(m, _role_of(ri, roles))
			if _archetype_match(mon, m):
				v += BUILD_ARCHETYPE_BONUS
			if v > best_v:
				best_v = v
				best = ri
		targets.append(best)
		values.append(best_v)
		if best >= 0:
			var k2: int = best * 16 + sock
			used[k2] = int(used.get(k2, 0)) + 1
			var pi2: float = float(inst.get(best, run.roster[best].instability))
			var chance: float = 100.0 - pi2 - Tuning.RISK_PER_RARITY[r]
			stabs += clampi(ceili((BUILD_TARGET_CHANCE - chance) / float(Tuning.STABILIZER_BONUS)),
				0, Tuning.STABILIZER_MAX)
			inst[best] = pi2 + Tuning.INSTABILITY_PER_RARITY[r]
	return {"targets": targets, "values": values, "need": stabs - run.stabilizers}

## Unsold shop mutations worth at least `fraction` of BUILD_MIN_VALUE for some
## wearer: [stock idx, value per gold, price, stabilizers needed with it], best value per gold first.
func _build_candidates(run: RunState, roles: Array[int], fraction: float) -> Array:
	var cands: Array = []
	for idx: int in run.shop_stock.size():
		var e: Dictionary = run.shop_stock[idx]
		if e[&"kind"] != ShopLogic.KIND_MUTATION or bool(e[&"sold"]) or e[&"mutation"] == null:
			continue
		var m: MutationData = e[&"mutation"]
		var extra: Array[MutationData] = [m]
		var plan: Dictionary = _build_plan(run, roles, extra)
		var t: Array[int] = plan["targets"]
		var v: Array[float] = plan["values"]
		if t[t.size() - 1] >= 0 and v[v.size() - 1] >= fraction * BUILD_MIN_VALUE[int(m.rarity)]:
			var price: int = int(e[&"price"])
			cands.append([idx, v[v.size() - 1] / maxf(1.0, float(price)), price, int(plan["need"])])
	cands.sort_custom(func(x: Array, y: Array) -> bool:
		return float(x[1]) > float(y[1]) if x[1] != y[1] else int(x[0]) < int(y[0]))
	return cands

## Buys the best affordable candidate that leaves gold for its stabilizers. True if one was bought.
func _build_buy_best(run: RunState, cands: Array, st: Dictionary) -> bool:
	for c: Array in cands:
		if ShopLogic.can_buy(run, int(c[0])) == "" \
				and run.gold - int(c[2]) >= maxi(0, int(c[3])) * Tuning.PRICE_STABILIZER:
			_buy(run, int(c[0]), st)
			return true
	return false

func _shop_build(run: RunState, rng: RandomNumberGenerator, st: Dictionary) -> void:
	var none: Array[MutationData] = []
	# a. A third body before parts (with the flattened pool it is worth more than three commons).
	if _bodies_first and run.living_count() < BUILD_BODIES_FIRST:
		_buy_kind(run, ShopLogic.KIND_HUMAN, st)
	var rerolls: int = 0
	while true:
		var onplan_seen: bool = false
		# b. On-plan pieces, best value per gold first, keeping gold for their stabilizers.
		var progress: bool = true
		while progress:
			var cands: Array = _build_candidates(run, _build_roles(run), 1.0)
			if not cands.is_empty():
				onplan_seen = true
			progress = _build_buy_best(run, cands, st)
		# c. Stabilizers up to need.
		var need: int = int(_build_plan(run, _build_roles(run), none)["need"])
		while need > 0 and _buy_kind(run, ShopLogic.KIND_STABILIZER, st):
			need -= 1
		# d. Reroll when nothing on-plan was in stock.
		if not onplan_seen and rerolls < BUILD_MAX_REROLLS \
				and run.gold >= ShopLogic.reroll_cost(run) + BUILD_REROLL_RESERVE:
			var cost: int = ShopLogic.reroll_cost(run)
			if ShopLogic.reroll(run, rng):
				_note_stock(run)
				st["spent"] += cost
				st["rerolls"] += 1
				rerolls += 1
				continue
		break
	# e. Bodies.
	var living: int = run.living_count()
	if living < 2 or (living < BUILD_MAX_BODIES and run.gold >= Tuning.PRICE_HUMAN + BUILD_HUMAN_RESERVE):
		_buy_kind(run, ShopLogic.KIND_HUMAN, st)
	# f. Spare gold: pieces a little under the on-plan threshold.
	while run.gold >= BUILD_OFFPLAN_GOLD:
		if not _build_buy_best(run, _build_candidates(run, _build_roles(run), BUILD_SPARE_FRACTION), st):
			break

func _lab_build(run: RunState, rng: RandomNumberGenerator, st: Dictionary) -> void:
	var none: Array[MutationData] = []
	var skip: Dictionary = {}
	var progress: bool = true
	while progress:
		progress = false
		var roles: Array[int] = _build_roles(run)
		var assign: Array[int] = _build_plan(run, roles, none)["targets"]
		for inv_idx: int in run.inventory.size():
			var mut: MutationData = run.inventory[inv_idx]
			var ri: int = assign[inv_idx]
			if ri < 0 or skip.has(inv_idx):
				continue
			var mon: MonsterData = run.roster[ri]
			var free: Array[StringName] = mon.slots_for(mut)
			if free.is_empty():
				continue
			var stabs: int = 0
			var chance: int = LabLogic.success_chance(run, mon, mut, 0)
			while chance < BUILD_TARGET_CHANCE and stabs < mini(run.stabilizers, Tuning.STABILIZER_MAX):
				stabs += 1
				chance = LabLogic.success_chance(run, mon, mut, stabs)
			if chance < BUILD_MIN_CHANCE or (run.living_count() == 1 and chance < 100):
				skip[inv_idx] = true
				continue
			_operate(run, ri, inv_idx, free[0], stabs, rng, st)
			skip.clear()
			progress = true
			break

## True if `mon` wears a team or ranged ability (it does its job from the back row).
func _is_support(mon: MonsterData) -> bool:
	for v: Variant in mon.slots.values():
		var m: MutationData = v as MutationData
		if m != null and m.ability != null:
			var kind: int = int(ABILITY_KIND.get(m.ability.get_id(), KIND_OFFENSE))
			if kind == KIND_TEAM or kind == KIND_RANGED:
				return true
	return false

## Tank in front (spot 0), carry in the middle row (spot 2), or in spot 0 when it
## has no tank; other monsters by HP in BUILD_OTHER_SPOTS, or back row first
## (BUILD_SUPPORT_SPOTS) when they wear a team / ranged ability.
func _formation_build(run: RunState) -> Dictionary:
	var roles: Array[int] = _build_roles(run)
	var carry: int = roles[0]
	var tank: int = roles[1]
	var others: Array[int] = []
	for ri: int in run.roster.size():
		if not run.roster[ri].mushed and ri != carry and ri != tank:
			others.append(ri)
	others.sort_custom(func(a: int, c: int) -> bool:
		var ha: float = float(run.roster[a].get_total_stats()[&"hp"])
		var hc: float = float(run.roster[c].get_total_stats()[&"hp"])
		return ha > hc if ha != hc else a < c)
	var place: Dictionary = {}
	if tank >= 0:
		place[BUILD_TANK_SPOT] = tank
	if carry >= 0:
		place[BUILD_CARRY_SPOT if tank >= 0 else BUILD_TANK_SPOT] = carry
	for ri: int in others:
		var order: Array[int] = BUILD_SUPPORT_SPOTS if _is_support(run.roster[ri]) else BUILD_OTHER_SPOTS
		for s: int in order:
			if not place.has(s):
				place[s] = ri
				break
	var spots_sorted: Array = place.keys()
	spots_sorted.sort()
	var team: Array[MonsterData] = []
	var spots: Array[int] = []
	var ridx: Array[int] = []
	run.formation = {}
	for s: int in spots_sorted:
		if team.size() >= Tuning.MAX_TEAM:
			break
		var ri: int = place[s]
		team.append(run.roster[ri])
		spots.append(s)
		ridx.append(ri)
		run.formation[s] = ri
	return {"team": team, "spots": spots, "roster_idx": ridx}

func _pick_reward_build(run: RunState, options: Array[Dictionary]) -> Dictionary:
	var roles: Array[int] = _build_roles(run)
	var by_id: Dictionary = {}
	for o: Dictionary in options:
		by_id[o[&"id"]] = o
	if by_id.has(&"free_mutation"):
		var m: MutationData = (by_id[&"free_mutation"] as Dictionary)[&"mutation"] as MutationData
		if m != null:
			var extra: Array[MutationData] = [m]
			var plan: Dictionary = _build_plan(run, roles, extra)
			var t: Array[int] = plan["targets"]
			var v: Array[float] = plan["values"]
			if t[t.size() - 1] >= 0 \
					and v[v.size() - 1] >= BUILD_SPARE_FRACTION * BUILD_MIN_VALUE[int(m.rarity)]:
				return by_id[&"free_mutation"]
	var none: Array[MutationData] = []
	if by_id.has(&"stabilizers") and int(_build_plan(run, roles, none)["need"]) > 0:
		return by_id[&"stabilizers"]
	if by_id.has(&"catalyst") and roles[0] >= 0 \
			and run.roster[roles[0]].instability >= BUILD_CATALYST_INSTABILITY:
		return by_id[&"catalyst"]
	if by_id.has(&"free_human") and run.living_count() < BUILD_MAX_BODIES:
		return by_id[&"free_human"]
	for id: StringName in [&"gold", &"lucky_gene", &"insurance", &"cleanse"]:
		if by_id.has(id):
			return by_id[id]
	return options[0]

# --- Helpers -----------------------------------------------------------------

## [total max HP, total base DPS (atk / interval, before DEF and abilities)].
func _power(team: Array[MonsterData]) -> Array[float]:
	var hp: float = 0.0
	var dps: float = 0.0
	for m: MonsterData in team:
		var s: Dictionary = m.get_total_stats()
		hp += float(s[&"hp"])
		dps += float(s[&"atk"]) * (1.0 + float(s[&"crit"]) * (Tuning.CRIT_MULT - 1.0)) \
			/ float(s[&"attack_interval"])
	return [hp, dps]

func _hp_left_frac(sim: BattleSim, side: int) -> float:
	var hp: float = 0.0
	var mx: float = 0.0
	for u: UnitState in sim.units:
		if u.side == side:
			mx += u.max_hp
			if u.alive:
				hp += u.hp
	return hp / mx if mx > 0.0 else 0.0

func _shuffle(a: Array, prng: RandomNumberGenerator) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = prng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp

func _zeros(n: int) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(0)
	return a

func _new_stats(policy: String, runs: int) -> Dictionary:
	var B: int = Tuning.BATTLES_PER_RUN
	var st: Dictionary = {"policy": policy, "runs": runs, "rewards": {}, "buys": {},
		"spent": 0, "ops_total": 0, "mush_total": 0, "op_success": 0, "op_insured": 0,
		"chance_sum": 0, "stabs_used": 0, "rerolls": 0,
		"tot": {}, "mut": {}, "mut_early": {}, "ab": {}, "rar": {}, "ultra": {}}
	for k: String in ["reached", "won", "lost", "end_no_living", "sponsor", "hub_visits",
			"gold_hub", "gold_after_spend", "inv_left", "team_size", "living", "muts_per_living",
			"p_hp", "p_dps", "e_hp", "e_dps", "pwin", "timeouts", "frenzy", "margin",
			"deaths_win", "ops", "mush", "power", "adapt", "adapt_on"]:
		st[k] = _zeros(B)
	for k: String in ["muts_per_living", "p_hp", "p_dps", "e_hp", "e_dps", "pwin", "margin"]:
		for i: int in B:
			st[k][i] = 0.0
	st["dur"] = []
	st["dur_win"] = []
	for i: int in B:
		(st["dur"] as Array).append([])
		(st["dur_win"] as Array).append([])
	return st

func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return NAN
	var s: Array = a.duplicate()
	s.sort()
	return float(s[clampi(int(floor(p * (s.size() - 1) + 0.5)), 0, s.size() - 1)])

func _mean(a: Array) -> float:
	if a.is_empty():
		return NAN
	var t: float = 0.0
	for v: Variant in a:
		t += float(v)
	return t / a.size()

func _div(a: float, b: float) -> float:
	return a / b if b > 0.0 else NAN

func _f(v: float, digits: int = 1) -> String:
	if is_nan(v):
		return "-"
	return ("%." + str(digits) + "f") % v

## Rows of the per-battle table: [label, [value per battle]] (strings).
func _rows(st: Dictionary) -> Array:
	var B: int = Tuning.BATTLES_PER_RUN
	var n: float = float(st["runs"])
	var rows: Array = []
	var cols: Dictionary = {}
	var names: Array[String] = ["Reached (% of runs)", "Won given reached (%)", "Lost here (% of runs)",
		"Ended: no living monster (% of runs)",
		"Sim P(win) of actual matchup (mean)", "Duration mean (s)", "Duration p10/p50/p90 (s)",
		"Duration of wins, mean (s)", "Went to frenzy >45s (% of fights)", "Hit 60s cap (% of fights)",
		"Win margin: player HP left (% on wins)", "Player deaths on wins (mean)",
		"Gold at hub (mean, after sponsor)", "Sponsor grant (% of hub visits)",
		"Gold left after shop+lab (mean)", "Unused inventory at fight (mean)",
		"Living monsters (mean)", "Team size fielded (mean)", "Mutations per living monster (mean)",
		"Player team HP / enemy team HP", "Player DPS / enemy DPS (raw)",
		"Lab operations per visit (mean)", "Mush per operation (%)",
		"Player power at fight (mean)", "Adapt bonus (mean) / fights with bonus (%)"]
	for nm: String in names:
		cols[nm] = []
	for b: int in B:
		var reached: float = float(st["reached"][b])
		var visits: float = float(st["hub_visits"][b])
		var dur: Array = st["dur"][b]
		var won: float = float(st["won"][b])
		cols["Reached (% of runs)"].append(_f(100.0 * reached / n))
		cols["Won given reached (%)"].append(_f(100.0 * _div(won, reached)))
		cols["Lost here (% of runs)"].append(_f(100.0 * float(st["lost"][b]) / n))
		cols["Ended: no living monster (% of runs)"].append(_f(100.0 * float(st["end_no_living"][b]) / n))
		cols["Sim P(win) of actual matchup (mean)"].append(
			_f(100.0 * _div(st["pwin"][b], reached)) + "%" if _odds_runs > 0 else "off")
		cols["Duration mean (s)"].append(_f(_mean(dur)))
		cols["Duration p10/p50/p90 (s)"].append("%s/%s/%s" % [_f(_pct(dur, 0.1)), _f(_pct(dur, 0.5)),
			_f(_pct(dur, 0.9))])
		cols["Duration of wins, mean (s)"].append(_f(_mean(st["dur_win"][b])))
		cols["Went to frenzy >45s (% of fights)"].append(_f(100.0 * _div(st["frenzy"][b], reached)))
		cols["Hit 60s cap (% of fights)"].append(_f(100.0 * _div(st["timeouts"][b], reached)))
		cols["Win margin: player HP left (% on wins)"].append(_f(100.0 * _div(st["margin"][b], won)))
		cols["Player deaths on wins (mean)"].append(_f(_div(st["deaths_win"][b], won), 2))
		cols["Gold at hub (mean, after sponsor)"].append(_f(_div(st["gold_hub"][b], visits)))
		cols["Sponsor grant (% of hub visits)"].append(_f(100.0 * _div(st["sponsor"][b], visits)))
		cols["Gold left after shop+lab (mean)"].append(_f(_div(st["gold_after_spend"][b], visits)))
		cols["Unused inventory at fight (mean)"].append(_f(_div(st["inv_left"][b], visits), 2))
		cols["Living monsters (mean)"].append(_f(_div(st["living"][b], reached), 2))
		cols["Team size fielded (mean)"].append(_f(_div(st["team_size"][b], reached), 2))
		cols["Mutations per living monster (mean)"].append(_f(_div(st["muts_per_living"][b], reached), 2))
		cols["Player team HP / enemy team HP"].append("%s / %s" % [_f(_div(st["p_hp"][b], reached), 0),
			_f(_div(st["e_hp"][b], reached), 0)])
		cols["Player DPS / enemy DPS (raw)"].append("%s / %s" % [_f(_div(st["p_dps"][b], reached)),
			_f(_div(st["e_dps"][b], reached))])
		cols["Lab operations per visit (mean)"].append(_f(_div(st["ops"][b], visits), 2))
		cols["Mush per operation (%)"].append(_f(100.0 * _div(st["mush"][b], st["ops"][b])))
		cols["Player power at fight (mean)"].append(_f(_div(st["power"][b], reached)))
		cols["Adapt bonus (mean) / fights with bonus (%)"].append("%s / %s" % [
			_f(_div(st["adapt"][b], reached), 2), _f(100.0 * _div(st["adapt_on"][b], reached))])
	for nm: String in names:
		rows.append([nm, cols[nm]])
	return rows

func _summary_lines(st: Dictionary) -> Array[String]:
	var B: int = Tuning.BATTLES_PER_RUN
	var n: float = float(st["runs"])
	var out: Array[String] = []
	var reach: Array[String] = []
	for b: int in range(1, B):
		reach.append("B%d %s%%" % [b + 1, _f(100.0 * float(st["reached"][b]) / n)])
	out.append("Reach: " + ", ".join(reach) + ", win B%d (run won): %s%%" % [B,
		_f(100.0 * float(st["won"][B - 1]) / n)])
	var worst: int = 0
	var worst_n: int = -1
	for b: int in B:
		var ends: int = int(st["lost"][b]) + int(st["end_no_living"][b])
		if ends > worst_n:
			worst_n = ends
			worst = b
	out.append("Most common run end: battle %d (%s%% of runs end there)" % [worst + 1,
		_f(100.0 * worst_n / n)])
	var ops: float = float(st["ops_total"])
	out.append("Lab: %d operations, mush %s%%, success %s%%, insured %d, mean chance %s%%, stabilizers used %d" % [
		int(ops), _f(100.0 * _div(st["mush_total"], ops)), _f(100.0 * _div(st["op_success"], ops)),
		int(st["op_insured"]), _f(_div(st["chance_sum"], ops)), int(st["stabs_used"])])
	var buys: Array[String] = []
	for k: Variant in st["buys"].keys():
		buys.append("%s %d" % [k, int(st["buys"][k])])
	buys.sort()
	out.append("Shop buys (total over runs): %s; rerolls %d; gold spent per run %s" % [", ".join(buys),
		int(st["rerolls"]), _f(float(st["spent"]) / n)])
	var rw: Array[String] = []
	for k: Variant in st["rewards"].keys():
		rw.append("%s %d" % [k, int(st["rewards"][k])])
	rw.sort()
	out.append("Rewards picked: %s" % ", ".join(rw))
	out.append("Sim time: %.1f s" % (float(st["elapsed_ms"]) / 1000.0))
	return out

func _text_table(st: Dictionary) -> String:
	var B: int = Tuning.BATTLES_PER_RUN
	var s: String = "\n=== policy: %s (%d runs) ===\n" % [st["policy"], st["runs"]]
	var head: String = "%-40s" % "metric"
	for b: int in B:
		head += "%16s" % ("B%d" % (b + 1))
	s += head + "\n"
	for row: Array in _rows(st):
		var line: String = "%-40s" % String(row[0]).left(40)
		for v: Variant in row[1]:
			line += "%16s" % String(v)
		s += line + "\n"
	for l: String in _summary_lines(st):
		s += l + "\n"
	return s

func _markdown(results: Array[Dictionary], cmd: String) -> String:
	var B: int = Tuning.BATTLES_PER_RUN
	var s: String = "# Balance report: full-run simulator\n\n"
	s += "Generated by `tools/balance/run_sim.gd` on %s. Re-run (from the project folder):\n\n" % \
		Time.get_datetime_string_from_system(false, true)
	s += "```\n%s\n```\n\n" % cmd
	s += "Each run replicates `Game.new_run()` (%dg, %d humans, Subject 02 has Mantis Arm + Scorpion Tail, as in the game), " % [
		Tuning.START_GOLD, Tuning.START_HUMANS]
	s += "then per battle: hub sponsor rule, `ShopLogic.ensure_stock` + policy buys, policy lab operations " \
		+ "(`LabLogic.operate`), formation (living monsters, highest HP front, up to %d), " % Tuning.MAX_TEAM \
		+ "`EnemyGen.generate` with `EnemyGen.player_power(roster)` (adaptive scaling, as `Game.prepare_battle`), one headless `BattleSim` fight with `hash([rng_seed, battle_index])` " \
		+ "(the same seed the game uses). Win: `BATTLE_REWARD`, reward pick. Loss ends the run. No betting. " \
		+ "P(win) is `BetOdds.estimate` with %d sims of the actual matchup (`odds=0` turns it off).\n\n" % _odds_runs
	s += "## Tuning snapshot\n\n"
	s += "| Knob | Value |\n|---|---|\n"
	var knobs: Array = [
		["BASE_HP / BASE_ATK / BASE_INTERVAL", "%s / %s / %s" % [Tuning.BASE_HP, Tuning.BASE_ATK, Tuning.BASE_INTERVAL]],
		["START_GOLD / START_HUMANS", "%d / %d" % [Tuning.START_GOLD, Tuning.START_HUMANS]],
		["BATTLE_REWARD", str(Tuning.BATTLE_REWARD)],
		["ENEMY_BUDGET / ENEMY_TEAM_SIZE", "%s / %s" % [Tuning.ENEMY_BUDGET, Tuning.ENEMY_TEAM_SIZE]],
		["ENEMY_HP_MULT", str(Tuning.ENEMY_HP_MULT)],
		["ADAPT_EXPECTED / RATE / MAX", "%s / %s / %s" % [Tuning.ADAPT_EXPECTED, Tuning.ADAPT_RATE, Tuning.ADAPT_MAX]],
		["ADAPT_BODY_POWER / HP_PER_POINT", "%d / %s" % [Tuning.ADAPT_BODY_POWER, Tuning.ADAPT_HP_PER_POINT]],
		["BLITZ_TIME", str(Tuning.BLITZ_TIME)],
		["BUDGET_COST / ULTRA_ENEMY_MIN_BATTLE", "%s / %d" % [Tuning.BUDGET_COST, Tuning.ULTRA_ENEMY_MIN_BATTLE]],
		["PRICE_BY_RARITY / HUMAN / STABILIZER", "%s / %d / %d" % [Tuning.PRICE_BY_RARITY, Tuning.PRICE_HUMAN, Tuning.PRICE_STABILIZER]],
		["RARITY_WEIGHTS (+rare per battle)", "%s (+%d)" % [Tuning.RARITY_WEIGHTS, Tuning.RARE_WEIGHT_PER_BATTLE]],
		["INSTABILITY_PER_RARITY / RISK_PER_RARITY", "%s / %s" % [Tuning.INSTABILITY_PER_RARITY, Tuning.RISK_PER_RARITY]],
		["STABILIZER_BONUS x MAX", "%d x %d" % [Tuning.STABILIZER_BONUS, Tuning.STABILIZER_MAX]],
		["SPONSOR_THRESHOLD / GRANT", "%d / %d" % [Tuning.SPONSOR_THRESHOLD, Tuning.SPONSOR_GRANT]],
		["FRENZY_START / HARD_CAP", "%s / %s" % [Tuning.FRENZY_START, Tuning.HARD_CAP]],
	]
	for k: Array in knobs:
		s += "| %s | %s |\n" % [k[0], k[1]]
	s += "\n## Policies\n\n"
	s += "- **greedy**: with bodies=1 (or bodies=2 from battle 2 on) first a human if living < %d and affordable, then affordable mutations highest rarity first (only ones that fit a free socket on " \
		+ "a living monster), then a human if living < %d. Lab: each inventory mutation goes to the " % HUMAN_BELOW \
		+ "monster with the highest success chance; stabilizers are added while chance < %d%%; operates if chance >= %d%%. " % LAB_RULES["greedy"] \
		+ "Reward: %s.\n" % ", ".join(REWARD_PREF["greedy"])
	s += "- **cautious**: buys the stabilizer first, then the same as greedy. Stabilizers while chance < %d%%; operates only if chance >= %d%%. " % LAB_RULES["cautious"] \
		+ "Reward: %s.\n" % ", ".join(REWARD_PREF["cautious"])
	s += "- **random**: each shop item bought with 50% chance (if affordable), each inventory item operated " \
		+ "with 50% chance on a random legal monster/slot with a random stabilizer count, random reward.\n"
	s += "- **build** (design/balance/stage4-balance.md): role-driven, no mutation ids. Carry = Subject 02 " \
		+ "while it lives, tank = other living monster with the most HP, the rest are support. Every piece is " \
		+ "valued in power points for the role of its best wearer (stats + ability kind, +%s when the wearer " % BUILD_ARCHETYPE_BONUS \
		+ "already has two pieces sharing a tag). Buys pieces worth >= %s points (by rarity), best value per gold " % str(BUILD_MIN_VALUE) \
		+ "first, keeping gold for the stabilizers to reach %d%%, then stabilizers, " % BUILD_TARGET_CHANCE \
		+ "rerolls up to %d times if nothing on-plan was in stock, a human if living < 2 " % BUILD_MAX_REROLLS \
		+ "(or < %d with spare gold), weaker pieces if gold >= %d. Operates at >= %d%%. " % [BUILD_MAX_BODIES, BUILD_OFFPLAN_GOLD, BUILD_MIN_CHANCE] \
		+ "Formation: tank spot 0, carry spot 2, team / ranged wearers in the back row. Reward: useful free " \
		+ "mutation > stabilizers if needed > catalyst > human > gold.\n\n"
	s += "Targets (design): ~60% of runs reach battle 3; good builds win by a clear margin; battles last 35-50 s.\n\n"
	for st: Dictionary in results:
		s += "## Policy: %s (%d runs)\n\n" % [st["policy"], st["runs"]]
		s += "| Metric |"
		for b: int in B:
			s += " B%d |" % (b + 1)
		s += "\n|---|" + "---|".repeat(B) + "\n"
		for row: Array in _rows(st):
			s += "| %s |" % row[0]
			for v: Variant in row[1]:
				s += " %s |" % v
			s += "\n"
		s += "\n"
		for l: String in _summary_lines(st):
			s += "- %s\n" % l
		s += "\n"
	s += _mutation_markdown(results)
	s += "Notes: \"Reached\" counts fights started. \"Gold at hub\" is on hub entry after the sponsor grant. " \
		+ "\"Mutations per living monster\" is averaged per run over its living roster at fight time. " \
		+ "Raw DPS = atk x (1 + crit) / interval, before DEF and abilities. B5 pays no battle reward.\n"
	return s

# --- Mutation / ability / rarity / ULTRA report ---------------------------------

## Sums one [n, wins, battles] table of every policy in `results`.
func _merged(results: Array[Dictionary], key: String) -> Dictionary:
	var out: Dictionary = {}
	for st: Dictionary in results:
		var t: Dictionary = st[key]
		for k: Variant in t.keys():
			if not out.has(k):
				out[k] = [0, 0, 0]
			for i: int in 3:
				out[k][i] += int(t[k][i])
	return out

## [n, win% with, win% without, lift, battles won with, battles won without].
func _with_without(table: Dictionary, key: Variant, tot: Array) -> Array:
	var a: Array = table.get(key, [0, 0, 0])
	var n: float = float(a[0])
	var rest: float = float(tot[0]) - n
	var w: float = 100.0 * _div(float(a[1]), n)
	var wo: float = 100.0 * _div(float(tot[1]) - float(a[1]), rest)
	return [int(n), w, wo, w - wo, _div(float(a[2]), n), _div(float(tot[2]) - float(a[2]), rest)]

## Rows [key, n, win with, win without, lift, bw with, bw without], highest lift
## first (keys never owned last). `keys` adds rows for keys missing from `table`.
func _lift_rows(table: Dictionary, tot: Array, keys: Array) -> Array:
	var all_keys: Dictionary = {}
	for k: Variant in keys:
		all_keys[k] = true
	for k: Variant in table.keys():
		all_keys[k] = true
	var rows: Array = []
	for k: Variant in all_keys.keys():
		var r: Array = [k]
		r.append_array(_with_without(table, k, tot))
		rows.append(r)
	rows.sort_custom(func(x: Array, y: Array) -> bool:
		var lx: float = -1e9 if is_nan(float(x[4])) else float(x[4])
		var ly: float = -1e9 if is_nan(float(y[4])) else float(y[4])
		return lx > ly if lx != ly else String(x[0]) < String(y[0]))
	return rows

func _mutation_index() -> Dictionary:
	var idx: Dictionary = {}
	for m: MutationData in EnemyGen.all_mutations():
		idx[String(m.id)] = m
	return idx

## [label, tot, mut, mut_early, ab, rar, ultra] for the pooled policies and for each one.
func _report_groups(results: Array[Dictionary]) -> Array:
	var groups: Array = []
	if results.size() > 1:
		groups.append(["pooled", _merged(results, "tot").get("all", [0, 0, 0]), _merged(results, "mut"),
			_merged(results, "mut_early"), _merged(results, "ab"), _merged(results, "rar"),
			_merged(results, "ultra")])
	for st: Dictionary in results:
		groups.append([st["policy"], (st["tot"] as Dictionary).get("all", [0, 0, 0]), st["mut"],
			st["mut_early"], st["ab"], st["rar"], st["ultra"]])
	return groups

func _mutation_markdown(results: Array[Dictionary]) -> String:
	var idx: Dictionary = _mutation_index()
	var s: String = "## Mutation report\n\n"
	s += "\"Owned\" = installed on a living monster when the run ended. With / without compare runs that " \
		+ "owned it with runs that did not. **Survivorship warning:** runs that live longer visit more shops, " \
		+ "so almost every piece shows a positive lift; compare a piece with the others of its rarity, not " \
		+ "with zero. \"Early\" = installed before battle 1 (no survivorship, small samples). " \
		+ "Mantis Arm and Scorpion Tail are on Subject 02 in every run.\n\n"
	for g: Array in _report_groups(results):
		var tot: Array = g[1]
		s += "### %s (%d runs, run win %s%%, mean battles won %s)\n\n" % [g[0], int(tot[0]),
			_f(100.0 * _div(float(tot[1]), float(tot[0]))), _f(_div(float(tot[2]), float(tot[0])), 2)]
		s += "| Rarity | Runs owning one | Win% with | Win% without | Lift | Battles won with | without |\n|---|---|---|---|---|---|---|\n"
		for r: Array in _lift_rows(g[5], tot, RARITY_NAMES):
			s += "| %s | %d | %s | %s | %s | %s | %s |\n" % [r[0], r[1], _f(r[2]), _f(r[3]), _f(r[4]),
				_f(r[5], 2), _f(r[6], 2)]
		var u: Dictionary = g[6]
		for key: String in ["seen", "bought"]:
			var w: Array = _with_without(u, key, tot)
			s += "\nULTRA %s (shop stock, rerolls and reward offers): %s%% of runs (%d); run win %s%% vs %s%% for the others." % [
				key, _f(100.0 * _div(float(w[0]), float(tot[0]))), w[0], _f(w[1]), _f(w[2])]
		s += "\n\n| Ability | Runs owning one | Win% with | Win% without | Lift | Battles won with | without |\n|---|---|---|---|---|---|---|\n"
		for r: Array in _lift_rows(g[4], tot, []):
			s += "| %s | %d | %s | %s | %s | %s | %s |\n" % [r[0], r[1], _f(r[2]), _f(r[3]), _f(r[4]),
				_f(r[5], 2), _f(r[6], 2)]
		if g[0] != "pooled" and g[0] != "build":
			s += "\n"
			continue
		s += "\n| Mutation | Rarity | Ability | Owned (runs) | Win% with | Win% without | Lift | Battles won with | without | Early n | Early win% with | Early without |\n"
		s += "|---|---|---|---|---|---|---|---|---|---|---|---|\n"
		for r: Array in _lift_rows(g[2], tot, idx.keys()):
			var m: MutationData = idx.get(r[0]) as MutationData
			var e: Array = _with_without(g[3], r[0], tot)
			s += "| %s | %s | %s | %d | %s | %s | %s | %s | %s | %d | %s | %s |\n" % [r[0],
				RARITY_NAMES[int(m.rarity)] if m != null else "?", _ability_name(m) if m != null else "?",
				r[1], _f(r[2]), _f(r[3]), _f(r[4]), _f(r[5], 2), _f(r[6], 2), e[0], _f(e[1]), _f(e[2])]
		s += "\n"
	return s

func _mutation_csv(results: Array[Dictionary]) -> String:
	var idx: Dictionary = _mutation_index()
	var s: String = "policy,id,rarity,socket,ability,owned,win_with,win_without,lift,battles_with,battles_without,early_n,early_win_with,early_win_without\n"
	for g: Array in _report_groups(results):
		for r: Array in _lift_rows(g[2], g[1], idx.keys()):
			var m: MutationData = idx.get(r[0]) as MutationData
			var e: Array = _with_without(g[3], r[0], g[1])
			s += "%s,%s,%s,%s,%s,%d,%s,%s,%s,%s,%s,%d,%s,%s\n" % [g[0], r[0],
				RARITY_NAMES[int(m.rarity)] if m != null else "?",
				MutationData.SocketType.keys()[int(m.socket_type)] if m != null else "?",
				_ability_name(m) if m != null else "?", r[1], _f(r[2]), _f(r[3]), _f(r[4]),
				_f(r[5], 2), _f(r[6], 2), e[0], _f(e[1]), _f(e[2])]
	return s

## Short console digest: one SUMMARY line per policy, rarity lift, ULTRA odds, outliers.
func _mutation_console(results: Array[Dictionary]) -> String:
	var B: int = Tuning.BATTLES_PER_RUN
	var s: String = "\n"
	for st: Dictionary in results:
		var n: float = float(st["runs"])
		var lo: float = INF
		var hi: float = -INF
		for b: int in B:
			var d: float = _mean(st["dur"][b])
			if not is_nan(d):
				lo = minf(lo, d)
				hi = maxf(hi, d)
		s += "SUMMARY %-8s win %5s%%  reachB3 %5s%%  fight %s-%s s  B1odds %s  goldB5 %s  spent/run %s\n" % [
			st["policy"], _f(100.0 * float(st["won"][B - 1]) / n), _f(100.0 * float(st["reached"][2]) / n),
			_f(lo, 0), _f(hi, 0),
			_f(100.0 * _div(st["pwin"][0], float(st["reached"][0]))) + "%" if _odds_runs > 0 else "off",
			_f(_div(st["gold_hub"][B - 1], float(st["hub_visits"][B - 1]))), _f(float(st["spent"]) / n)]
	for g: Array in _report_groups(results):
		var tot: Array = g[1]
		var line: String = "RARITY %-8s" % g[0]
		for r: Array in _lift_rows(g[5], tot, RARITY_NAMES):
			line += "  %s n=%d %s%%/%s%%" % [r[0], r[1], _f(r[2]), _f(r[3])]
		var seen: Array = _with_without(g[6], "seen", tot)
		var bought: Array = _with_without(g[6], "bought", tot)
		line += "  | ULTRA seen %s%% of runs (win %s%% vs %s%%), bought %s%%" % [
			_f(100.0 * _div(float(seen[0]), float(tot[0]))), _f(seen[1]), _f(seen[2]),
			_f(100.0 * _div(float(bought[0]), float(tot[0])))]
		s += line + "\n"
	var groups: Array = _report_groups(results)
	if not groups.is_empty():
		var g0: Array = groups[0]
		var idx: Dictionary = _mutation_index()
		var rows: Array = []
		for r: Array in _lift_rows(g0[2], g0[1], []):
			if int(r[1]) >= REPORT_MIN_N and int(r[1]) < int(g0[1][0]):
				rows.append(r)
		s += "LIFT (%s, n >= %d): top / bottom 8\n" % [g0[0], REPORT_MIN_N]
		for k: int in rows.size():
			if k < 8 or k >= rows.size() - 8:
				var r: Array = rows[k]
				var m: MutationData = idx.get(r[0]) as MutationData
				s += "  %-26s %-8s %-13s n=%4d  win %5s%% vs %5s%%  lift %6s\n" % [r[0],
					RARITY_NAMES[int(m.rarity)] if m != null else "?", _ability_name(m) if m != null else "?",
					r[1], _f(r[2]), _f(r[3]), _f(r[4])]
	return s

# --- Arena mode ---------------------------------------------------------------------

## Power ranking independent of the shop. For every mutation (and, for ARM / LEG,
## two copies) a human wearing only that mutation fights:
##   plain 2v2: with one plain ally against two plain humans of equal base stats
##              (HP-fraction margin = raw power, used to compare rarities);
##   ladder:    1v1 and 2v2 against a "dummy" = a plain human with extra plain
##              stats. The dummy climbs a ladder from 0 to 2 x ARENA_PAR[rarity]
##              (x copies) power points over the fights, so the win% is graded:
##              a piece worth exactly its rarity's par wins about 50%, a piece
##              worth nothing about 0%, one worth twice par about 100%.
## Sides alternate every fight (the player side acts first). Fights that reach
## HARD_CAP are decided by the HP fraction left, as in the game. Score = mean of
## the ladder 1v1 and 2v2 win% (2v2 only for abilities that need a team).
func _arena(args: Dictionary) -> void:
	var fights: int = int(args.get("fights", "200"))
	var base_seed: int = int(args.get("seed", "1"))
	var out_path: String = args.get("out", "res://reports/arena.md")
	var t0: int = Time.get_ticks_msec()
	var rows: Array = []
	for m: MutationData in EnemyGen.all_mutations():
		var copies_list: Array[int] = [1]
		if m.socket_type == MutationData.SocketType.ARM or m.socket_type == MutationData.SocketType.LEG:
			copies_list.append(2)
		for copies: int in copies_list:
			var row: Dictionary = {"id": String(m.id), "rarity": int(m.rarity),
				"socket": String(MutationData.SocketType.keys()[int(m.socket_type)]),
				"ability": _ability_name(m), "copies": copies}
			row["plain2"] = _arena_cfg(m, copies, 2, false, fights, base_seed)
			row["lad1"] = _arena_cfg(m, copies, 1, true, fights, base_seed)
			row["lad2"] = _arena_cfg(m, copies, 2, true, fights, base_seed)
			var team_only: bool = m.ability != null and ARENA_TEAM_ONLY.has(m.ability.get_id())
			row["score"] = float(row["lad2"][0]) if team_only \
				else 0.5 * (float(row["lad1"][0]) + float(row["lad2"][0]))
			rows.append(row)
	# Medians per rarity over the single-copy rows.
	var med: Array = []
	for r: int in RARITY_NAMES.size():
		var sc: Array = []
		var m2: Array = []
		for row: Dictionary in rows:
			if int(row["rarity"]) == r and int(row["copies"]) == 1:
				sc.append(row["score"])
				m2.append(row["plain2"][1])
		med.append([_pct(sc, 0.5), _pct(m2, 0.5), sc.size(), _pct(sc, 0.0), _pct(sc, 1.0)])
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["rarity"] != y["rarity"]:
			return int(x["rarity"]) < int(y["rarity"])
		if x["score"] != y["score"]:
			return float(x["score"]) > float(y["score"])
		return String(x["id"]) + str(x["copies"]) < String(y["id"]) + str(y["copies"]))
	var md: String = "# Arena report: per-mutation power\n\n"
	md += "Generated by `tools/balance/run_sim.gd mode=arena fights=%d seed=%d` on %s.\n\n" % [fights, base_seed,
		Time.get_datetime_string_from_system(false, true)]
	md += "A human wearing only the mutation (x2 = both arms / legs), %d seeded fights per column, sides " % fights \
		+ "alternating. **Plain 2v2** = with one plain ally against two plain humans; margin = own HP " \
		+ "fraction left minus the opponents' (points). **Ladder** = against a dummy (a plain human with " \
		+ "+%s HP and +%s ATK per power point) " % [ARENA_PAR_HP_PER_POINT, ARENA_PAR_ATK_PER_POINT] \
		+ "that climbs from 0 to 2 x par over the fights; par by rarity = %s points (x copies). " % str(ARENA_PAR) \
		+ "A piece worth exactly par wins about 50, worth nothing about 0, worth twice par about 100. " \
		+ "Score = mean of the 1v1 and 2v2 ladder (2v2 only for %s). " % ", ".join(ARENA_TEAM_ONLY) \
		+ "Delta = score minus the rarity median; more than %s away is flagged.\n\n" % ARENA_OUTLIER
	md += "| Rarity | Pieces | Median score | Lowest | Highest | Median margin, plain 2v2 |\n|---|---|---|---|---|---|\n"
	var con: String = ""
	for r: int in RARITY_NAMES.size():
		md += "| %s | %d | %s | %s | %s | %s |\n" % [RARITY_NAMES[r], med[r][2], _f(med[r][0]),
			_f(med[r][3]), _f(med[r][4]), _f(100.0 * float(med[r][1]))]
		con += "ARENA %-8s n=%d  median score %s (min %s, max %s)  plain 2v2 margin %s\n" % [
			RARITY_NAMES[r], med[r][2], _f(med[r][0]), _f(med[r][3]), _f(med[r][4]),
			_f(100.0 * float(med[r][1]))]
	var csv: String = "id,rarity,socket,ability,copies,score,delta,lad1,lad2,plain2_win,plain2_margin,plain2_time\n"
	var last_r: int = -1
	var outliers: int = 0
	for row: Dictionary in rows:
		var r: int = int(row["rarity"])
		if r != last_r:
			last_r = r
			md += "\n## %s\n\n" % RARITY_NAMES[r].capitalize()
			md += "| Mutation | Slot | Ability | Score | Delta | Ladder 1v1 | Ladder 2v2 | Plain 2v2 margin | Plain 2v2 time (s) |\n|---|---|---|---|---|---|---|---|---|\n"
		var delta: float = float(row["score"]) - float(med[r][0])
		var flag: String = " **!**" if absf(delta) > ARENA_OUTLIER else ""
		var nm: String = String(row["id"]) + (" x2" if int(row["copies"]) == 2 else "")
		var p2: Array = row["plain2"]
		md += "| %s | %s | %s | %s | %s%s | %s | %s | %s | %s |\n" % [nm, row["socket"],
			row["ability"], _f(row["score"]), _f(delta), flag, _f(row["lad1"][0]), _f(row["lad2"][0]),
			_f(100.0 * float(p2[1])), _f(p2[2])]
		csv += "%s,%s,%s,%s,%d,%s,%s,%s,%s,%s,%s,%s\n" % [row["id"], RARITY_NAMES[r], row["socket"],
			row["ability"], row["copies"], _f(row["score"]), _f(delta), _f(row["lad1"][0]),
			_f(row["lad2"][0]), _f(p2[0]), _f(100.0 * float(p2[1])), _f(p2[2])]
		if absf(delta) > ARENA_OUTLIER:
			outliers += 1
	con += "ARENA outliers (more than %s from the rarity median): %d of %d rows\n" % [ARENA_OUTLIER, outliers, rows.size()]
	print(con)
	print("Arena time: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if out_path != "none":
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
			f.close()
		var cf: FileAccess = FileAccess.open(out_path.get_basename() + ".csv", FileAccess.WRITE)
		if cf != null:
			cf.store_string(csv)
			cf.close()
		print("Wrote %s (+ .csv)" % ProjectSettings.globalize_path(out_path))

## One arena configuration: [win% of the mutant's side, mean HP-fraction margin,
## mean fight time]. `ladder` = the opponent is the climbing dummy (see _arena()).
func _arena_cfg(m: MutationData, copies: int, team: int, ladder: bool, fights: int, base_seed: int) -> Array:
	var mutant: MonsterData = _human.clone()
	for c: int in copies:
		var free: Array[StringName] = mutant.slots_for(m)
		if free.is_empty():
			break
		mutant.apply_mutation(m, free[0])
	var top: float = 2.0 * ARENA_PAR[int(m.rarity)] * float(copies) if ladder else 0.0
	return _arena_fights(mutant, team, top, fights, "%d|%s|%d|%s" % [base_seed, m.id, copies, ladder])

## `fights` fights of `mutant` (plus team - 1 plain allies, front row) against a
## dummy (plus team - 1 plain humans). The dummy climbs from 0 to `ladder_top`
## power points over the fights (0 = a plain human every time). Sides alternate.
## Returns [win% of the mutant's side, mean HP-fraction margin, mean fight time].
func _arena_fights(mutant: MonsterData, team: int, ladder_top: float, fights: int, seed_key: String) -> Array:
	var foe: MonsterData = _human.clone()
	var a: Array[MonsterData] = [mutant]
	var b: Array[MonsterData] = [foe]
	var spots: Array[int] = [0]
	var ridx: Array[int] = [0]
	for i: int in team - 1:
		a.append(_human.clone())
		b.append(_human.clone())
		spots.append(i + 1)
		ridx.append(i + 1)
	var rungs: float = maxf(1.0, ceilf(fights / 2.0))
	var wins: int = 0
	var margin: float = 0.0
	var time: float = 0.0
	for k: int in fights:
		if ladder_top > 0.0:
			@warning_ignore("integer_division")
			var pts: float = ladder_top * (float(k / 2) + 0.5) / rungs
			foe.base_hp = Tuning.BASE_HP + pts * ARENA_PAR_HP_PER_POINT
			foe.base_atk = Tuning.BASE_ATK + pts * ARENA_PAR_ATK_PER_POINT
		var sd: int = hash([seed_key, team, k])
		var a_player: bool = k % 2 == 0
		var sim: BattleSim = BattleSim.new(a if a_player else b, spots, ridx, b if a_player else a,
			spots, sd, false)
		var res: Dictionary = sim.run_to_end()
		var side: int = BattleSim.PLAYER if a_player else BattleSim.ENEMY
		if int(res[&"winner"]) == side:
			wins += 1
		margin += _hp_left_frac(sim, side) - _hp_left_frac(sim, 1 - side)
		time += float(res[&"time"])
	var n: float = maxf(1.0, float(fights))
	return [100.0 * wins / n, margin / n, time / n]

# --- Fusion arena -------------------------------------------------------------------

## Ladder top of the fusion check, in multiples of ARENA_PAR of the fused part's rarity.
const FUSION_LADDER_PAR: float = 5.0
## Hybrids sampled per rarity, and apex parts built from the first hybrids.
const FUSION_SAMPLE_PER_RARITY: int = 8
const FUSION_APEX_SAMPLE: int = 8
## Twins whose ability fires on a timer (empowered() also shortens the interval).
const FUSION_TICK_ABILITIES: Array[StringName] = [&"regen", &"mend", &"snipe", &"spore_pulse", &"swarm", &"titan"]

## Power in ladder points of a human wearing `parts` (each on its first free slot):
## the dummy climbs from 0 to `top` points, so power = win fraction x top (mean of
## the 1v1 and 2v2 ladders; 2v2 only when `team_only`). Comparable only between
## rows measured with the same `top`.
func _fusion_power(parts: Array[MutationData], top: float, team_only: bool, fights: int, key: String) -> float:
	var mutant: MonsterData = _human.clone()
	for m: MutationData in parts:
		var free: Array[StringName] = mutant.slots_for(m)
		if not free.is_empty():
			mutant.apply_mutation(m, free[0])
	var w2: float = float(_arena_fights(mutant, 2, top, fights, key)[0])
	if team_only:
		return w2 / 100.0 * top
	var w1: float = float(_arena_fights(mutant, 1, top, fights, key)[0])
	return 0.5 * (w1 + w2) / 100.0 * top

func _needs_team(m: MutationData) -> bool:
	for ab: AbilityData in _abilities_of(m):
		if ARENA_TEAM_ONLY.has(ab.get_id()):
			return true
	return false

## Every ability of a base or fused mutation.
func _abilities_of(m: MutationData) -> Array[AbilityData]:
	var out: Array[AbilityData] = []
	if m.ability != null:
		out.append(m.ability)
	var extra: Variant = m.get(&"extra_abilities")
	if extra is Array:
		for ab: Variant in extra:
			if ab is AbilityData:
				out.append(ab)
	return out

## One fused row: the fused part against its stronger parent (same ladder), and
## for ARM / LEG also against both parents worn side by side.
func _fusion_row(kind: String, a: MutationData, b: MutationData, fused: MutationData, fights: int,
		base_seed: int) -> Dictionary:
	var top: float = FUSION_LADDER_PAR * ARENA_PAR[int(fused.rarity)]
	var team_only: bool = _needs_team(fused)
	var key: String = "%d|%s|%s" % [base_seed, kind, fused.id]
	var pf: float = _fusion_power([fused], top, team_only, fights, key + "|f")
	var pa: float = _fusion_power([a], top, team_only, fights, key + "|a")
	var pb: float = pa if a == b else _fusion_power([b], top, team_only, fights, key + "|b")
	var best: float = maxf(pa, pb)
	var row: Dictionary = {"kind": kind, "key": String(fused.id), "name": fused.display_name,
		"rarity": int(fused.rarity), "socket": String(MutationData.SocketType.keys()[int(fused.socket_type)]),
		"abilities": ", ".join(PackedStringArray(_abilities_of(fused).map(
			func(x: AbilityData) -> String: return String(x.get_id())))),
		"fused": pf, "parent": best, "ratio": _div(pf, best), "both": NAN, "ratio_both": NAN,
		"top": top}
	if a.socket_type == MutationData.SocketType.ARM or a.socket_type == MutationData.SocketType.LEG:
		var pair: Array[MutationData] = [a, b]
		var both: float = _fusion_power(pair, top, team_only, fights, key + "|ab")
		row["both"] = both
		row["ratio_both"] = _div(pf, both)
	return row

## Fused-part power check (design/fusion-contract.md): every signature pair, a
## sample of plain hybrids per rarity, one twin per ability, and a few apex parts.
## Ratio = fused power / stronger parent's power on the same ladder (for apex:
## / the hybrid it was built from). Targets: hybrid and twin 1.3-1.6, signature
## clearly higher but not above about 2, apex above hybrid.
func _fusion_arena(args: Dictionary) -> void:
	var fights: int = int(args.get("fights", "100"))
	var base_seed: int = int(args.get("seed", "1"))
	var out_path: String = args.get("out", "res://reports/arena_fusion.md")
	var t0: int = Time.get_ticks_msec()
	var idx: Dictionary = _mutation_index()
	var rows: Array = []
	var sig_keys: Dictionary = FusionLogic.index().get("signatures", {})
	var keys: Array = sig_keys.keys()
	keys.sort()
	for key: Variant in keys:
		var ids: PackedStringArray = String(key).split(FusionLogic.KEY_SEPARATOR)
		if ids.size() != 2 or not idx.has(ids[0]) or not idx.has(ids[1]):
			continue
		var a: MutationData = idx[ids[0]]
		var b: MutationData = idx[ids[1]]
		var f: MutationData = FusionLogic.merge(a, b)
		if f != null:
			rows.append(_fusion_row("signature", a, b, f, fights, base_seed))
	# Plain hybrids: consecutive same-socket, same-rarity pairs in id order.
	var hybrids: Array = []
	var pool: Array[MutationData] = EnemyGen.all_mutations()
	for r: int in RARITY_NAMES.size():
		var taken: int = 0
		for i: int in pool.size():
			if taken >= FUSION_SAMPLE_PER_RARITY:
				break
			var a: MutationData = pool[i]
			if int(a.rarity) != r:
				continue
			for j: int in range(i + 1, pool.size()):
				var b: MutationData = pool[j]
				if int(b.rarity) != r or b.socket_type != a.socket_type:
					continue
				if sig_keys.has(FusionLogic.pair_key(a, b)):
					continue
				var f: MutationData = FusionLogic.merge(a, b)
				if f != null:
					rows.append(_fusion_row("hybrid", a, b, f, fights, base_seed))
					hybrids.append([f, a, b])
					taken += 1
				break
	# Twins: the first mutation carrying each ability.
	var seen_ab: Dictionary = {}
	for m: MutationData in pool:
		if m.ability == null or seen_ab.has(m.ability.get_id()):
			continue
		seen_ab[m.ability.get_id()] = true
		var f: MutationData = FusionLogic.merge(m, m)
		if f != null:
			var kind: String = "twin (tick)" if FUSION_TICK_ABILITIES.has(m.ability.get_id()) else "twin"
			rows.append(_fusion_row(kind, m, m, f, fights, base_seed))
	# Apex: a hybrid merged with one more part of its socket; ratio against the hybrid.
	var apex_done: int = 0
	for h: Array in hybrids:
		if apex_done >= FUSION_APEX_SAMPLE:
			break
		var hy: MutationData = h[0]
		for m: MutationData in pool:
			if m.socket_type != hy.socket_type or m == h[1] or m == h[2] or int(m.rarity) > int(hy.rarity):
				continue
			var f: MutationData = FusionLogic.merge(hy, m)
			if f == null:
				continue
			rows.append(_fusion_row("apex", hy, m, f, fights, base_seed))
			apex_done += 1
			break
	# Summary per kind.
	var kinds: Array[String] = ["hybrid", "twin", "twin (tick)", "signature", "apex"]
	var md: String = "# Fusion arena report\n\n"
	md += "Generated by `tools/balance/run_sim.gd mode=fusion fights=%d seed=%d` on %s.\n\n" % [fights, base_seed,
		Time.get_datetime_string_from_system(false, true)]
	md += "Power = win fraction on a dummy ladder from 0 to %s x the rarity par, times the ladder top " % FUSION_LADDER_PAR \
		+ "(mean of 1v1 and 2v2; 2v2 only for team abilities). Ratio = fused power / the stronger parent " \
		+ "on the same ladder (apex: / the hybrid it was built from). \"Both\" = the two parents worn " \
		+ "side by side (ARM / LEG only). FUSION_PART_STAT_MULT %s, FUSION_SIGNATURE_STAT_MULT %s, FUSION_TWIN_POWER %s.\n\n" % [
			str(Tuning.FUSION_PART_STAT_MULT), Tuning.FUSION_SIGNATURE_STAT_MULT, Tuning.FUSION_TWIN_POWER]
	md += "| Kind | Rows | Median ratio | Lowest | Highest |\n|---|---|---|---|---|\n"
	var con: String = ""
	for kind: String in kinds:
		var rs: Array = []
		for row: Dictionary in rows:
			if row["kind"] == kind and not is_nan(float(row["ratio"])):
				rs.append(row["ratio"])
		md += "| %s | %d | %s | %s | %s |\n" % [kind, rs.size(), _f(_pct(rs, 0.5), 2), _f(_pct(rs, 0.0), 2), _f(_pct(rs, 1.0), 2)]
		con += "FUSION %-12s n=%d  median ratio %s (min %s, max %s)\n" % [kind, rs.size(), _f(_pct(rs, 0.5), 2),
			_f(_pct(rs, 0.0), 2), _f(_pct(rs, 1.0), 2)]
	md += "\n| Kind | Fused part | Slot | Rarity | Abilities | Fused power | Stronger parent | Ratio | Both parents | Ratio vs both |\n"
	md += "|---|---|---|---|---|---|---|---|---|---|\n"
	var csv: String = "kind,key,socket,rarity,abilities,fused,parent,ratio,both,ratio_both\n"
	for row: Dictionary in rows:
		md += "| %s | %s (%s) | %s | %s | %s | %s | %s | %s | %s | %s |\n" % [row["kind"], row["name"], row["key"],
			row["socket"], RARITY_NAMES[int(row["rarity"])], row["abilities"], _f(row["fused"], 2),
			_f(row["parent"], 2), _f(row["ratio"], 2), _f(row["both"], 2), _f(row["ratio_both"], 2)]
		csv += "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" % [row["kind"], row["key"], row["socket"],
			RARITY_NAMES[int(row["rarity"])], String(row["abilities"]).replace(", ", "/"), _f(row["fused"], 2),
			_f(row["parent"], 2), _f(row["ratio"], 2), _f(row["both"], 2), _f(row["ratio_both"], 2)]
	print(con)
	print("Fusion arena time: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if out_path != "none":
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(md)
			f.close()
		var cf: FileAccess = FileAccess.open(out_path.get_basename() + ".csv", FileAccess.WRITE)
		if cf != null:
			cf.store_string(csv)
			cf.close()
		print("Wrote %s (+ .csv)" % ProjectSettings.globalize_path(out_path))
