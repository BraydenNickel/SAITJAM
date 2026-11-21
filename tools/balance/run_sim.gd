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

# --- "build" policy (design/balance/stage3-tuning.md §3) ---
## Carry plan: socket order = priority. Already-installed parts count against it.
const BUILD_CARRY_PLAN: Array[StringName] = [&"mantis_arm", &"raptor_leg", &"raptor_leg",
	&"leech_maw", &"mantis_arm", &"bone_plating"]
const BUILD_TANK_PLAN: Array[StringName] = [&"bone_plating", &"leech_maw", &"spore_sacs",
	&"raptor_leg"]
## Stabilize each planned op up to this success %.
const BUILD_TARGET_CHANCE: int = 90
## Operate only at or above this success %.
const BUILD_MIN_CHANCE: int = 85
const BUILD_MAX_REROLLS: int = 2
## Reroll only if gold >= reroll cost + this.
const BUILD_REROLL_RESERVE: int = 18
## Third human only if gold >= PRICE_HUMAN + this.
const BUILD_HUMAN_RESERVE: int = 10
## Off-plan commons only if gold >= this.
const BUILD_OFFPLAN_GOLD: int = 25
## Take Catalyst when the carry's instability is at least this.
const BUILD_CATALYST_INSTABILITY: float = 40.0
## Tank spot (front), carry spot (middle row) and spots for other non-carry monsters.
const BUILD_TANK_SPOT: int = 0
const BUILD_CARRY_SPOT: int = 2
const BUILD_OTHER_SPOTS: Array[int] = [1, 3, 4, 5]

var _human: MonsterData
var _mantis: MutationData
var _scorpion: MutationData
var _odds_runs: int = 10
## build policy: roster index of the current carry (-1 = pick again).
var _carry: int = -1

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
		+ "-s res://tools/balance/run_sim.gd -- runs=%d policy=%s seed=%d odds=%d" % [
			runs, policy_arg, base_seed, _odds_runs]
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
		_shop(policy, run, rng, prng, st)
		_lab(policy, run, rng, prng, st)
		st["gold_after_spend"][b] += run.gold
		st["inv_left"][b] += run.inventory.size()
		if run.living_count() == 0:
			st["end_no_living"][b] += 1
			return
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
			return
		st["won"][b] += 1
		(st["dur_win"][b] as Array).append(t)
		st["margin"][b] += _hp_left_frac(sim, BattleSim.PLAYER)
		st["deaths_win"][b] += int(res[&"player_deaths"])
		if b >= B - 1:
			return
		# Win: battle reward (battle.gd), next battle, reward pick (reward.gd).
		run.gold += Tuning.BATTLE_REWARD[b]
		run.battle_index += 1
		var options: Array[Dictionary] = RewardLogic.roll_options(run, rng)
		if not options.is_empty():
			var pick: Dictionary = _pick_reward_build(run, options) if policy == "build" \
				else _pick_reward(policy, options, prng)
			var rid: StringName = pick[&"id"]
			st["rewards"][rid] = int(st["rewards"].get(rid, 0)) + 1
			RewardLogic.apply(run, pick)

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
			key = "mutation_" + ["common", "uncommon", "rare"][int((e[&"mutation"] as MutationData).rarity)]
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

## Plan list minus parts already installed on `mon`.
func _build_wants(mon: MonsterData, plan: Array[StringName]) -> Array[StringName]:
	var w: Array[StringName] = plan.duplicate()
	for v: Variant in mon.slots.values():
		var m: MutationData = v as MutationData
		if m != null:
			var k: int = w.find(m.id)
			if k >= 0:
				w.remove_at(k)
	return w

## Assigns inventory (then `extra`) to plan targets, carry first. Returns the
## roster index per item (-1 = off-plan), inventory items first.
func _build_assign(run: RunState, roles: Array[int], extra: Array[MutationData]) -> Array[int]:
	var targets: Array[int] = []
	var wants: Dictionary = {}
	var free: Dictionary = {}
	for k: int in 2:
		var ri: int = roles[k]
		if ri < 0:
			continue
		targets.append(ri)
		wants[ri] = _build_wants(run.roster[ri], BUILD_CARRY_PLAN if k == 0 else BUILD_TANK_PLAN)
		free[ri] = {}
	var items: Array[MutationData] = []
	items.append_array(run.inventory)
	items.append_array(extra)
	var out: Array[int] = []
	for m: MutationData in items:
		var to: int = -1
		for ri: int in targets:
			var w: Array[StringName] = wants[ri]
			var fr: Dictionary = free[ri]
			var sock: int = int(m.socket_type)
			if not fr.has(sock):
				fr[sock] = run.roster[ri].slots_for(m).size()
			if w.has(m.id) and int(fr[sock]) > 0:
				w.erase(m.id)
				fr[sock] = int(fr[sock]) - 1
				to = ri
				break
		out.append(to)
	return out

## Plan target roster index for `m` if it were bought now, or -1 (off-plan).
func _build_target(run: RunState, roles: Array[int], m: MutationData) -> int:
	var a: Array[int] = _build_assign(run, roles, [m])
	return a[a.size() - 1]

## Stabilizers needed to bring every planned op (inventory + `extra`) to
## BUILD_TARGET_CHANCE (max STABILIZER_MAX per op), minus those owned. Can be negative.
func _build_need(run: RunState, roles: Array[int], extra: Array[MutationData]) -> int:
	var items: Array[MutationData] = []
	items.append_array(run.inventory)
	items.append_array(extra)
	var a: Array[int] = _build_assign(run, roles, extra)
	var inst: Dictionary = {}
	var total: int = 0
	for i: int in items.size():
		var ri: int = a[i]
		if ri < 0:
			continue
		if not inst.has(ri):
			inst[ri] = run.roster[ri].instability
		var r: int = int(items[i].rarity)
		var chance: float = 100.0 - float(inst[ri]) - Tuning.RISK_PER_RARITY[r]
		total += clampi(ceili((BUILD_TARGET_CHANCE - chance) / float(Tuning.STABILIZER_BONUS)),
			0, Tuning.STABILIZER_MAX)
		inst[ri] = float(inst[ri]) + Tuning.INSTABILITY_PER_RARITY[r]
	return total - run.stabilizers

func _shop_build(run: RunState, rng: RandomNumberGenerator, st: Dictionary) -> void:
	var rerolls: int = 0
	while true:
		var onplan_seen: bool = false
		# b. On-plan mutations, carry first, cheapest first, keeping gold for their stabilizers.
		var progress: bool = true
		while progress:
			progress = false
			var roles: Array[int] = _build_roles(run)
			var cands: Array = []
			for idx: int in run.shop_stock.size():
				var e: Dictionary = run.shop_stock[idx]
				if e[&"kind"] != ShopLogic.KIND_MUTATION or bool(e[&"sold"]) or e[&"mutation"] == null:
					continue
				var to: int = _build_target(run, roles, e[&"mutation"] as MutationData)
				if to >= 0:
					onplan_seen = true
					cands.append([idx, 0 if to == roles[0] else 1, int(e[&"price"])])
			cands.sort_custom(func(x: Array, y: Array) -> bool:
				return int(x[1]) < int(y[1]) if x[1] != y[1] else int(x[2]) < int(y[2]))
			for c: Array in cands:
				var idx: int = c[0]
				var m: MutationData = run.shop_stock[idx][&"mutation"]
				var need_with: int = maxi(0, _build_need(run, roles, [m]))
				if ShopLogic.can_buy(run, idx) == "" \
						and run.gold - int(c[2]) >= need_with * Tuning.PRICE_STABILIZER:
					_buy(run, idx, st)
					progress = true
					break
		# c. Stabilizers up to need.
		var need: int = _build_need(run, _build_roles(run), [])
		while need > 0 and _buy_kind(run, ShopLogic.KIND_STABILIZER, st):
			need -= 1
		# d. Reroll when nothing on-plan was in stock.
		if not onplan_seen and rerolls < BUILD_MAX_REROLLS \
				and run.gold >= ShopLogic.reroll_cost(run) + BUILD_REROLL_RESERVE:
			var cost: int = ShopLogic.reroll_cost(run)
			if ShopLogic.reroll(run, rng):
				st["spent"] += cost
				st["rerolls"] += 1
				rerolls += 1
				continue
		break
	# e. Bodies.
	var living: int = run.living_count()
	if living < 2 or (living < 3 and run.gold >= Tuning.PRICE_HUMAN + BUILD_HUMAN_RESERVE):
		_buy_kind(run, ShopLogic.KIND_HUMAN, st)
	# f. Off-plan commons for non-carry monsters.
	var roles2: Array[int] = _build_roles(run)
	for idx: int in run.shop_stock.size():
		if run.gold < BUILD_OFFPLAN_GOLD:
			break
		var e: Dictionary = run.shop_stock[idx]
		if e[&"kind"] != ShopLogic.KIND_MUTATION or bool(e[&"sold"]) or e[&"mutation"] == null:
			continue
		var m: MutationData = e[&"mutation"]
		if int(m.rarity) != MutationData.Rarity.COMMON or _build_target(run, roles2, m) >= 0:
			continue
		if _build_offplan_target(run, roles2, m) >= 0 and ShopLogic.can_buy(run, idx) == "":
			_buy(run, idx, st)

## Lowest-instability living non-carry monster with a free socket for `m`, or -1.
func _build_offplan_target(run: RunState, roles: Array[int], m: MutationData) -> int:
	var best: int = -1
	for ri: int in run.roster.size():
		var mon: MonsterData = run.roster[ri]
		if ri == roles[0] or mon.mushed or mon.slots_for(m).is_empty():
			continue
		if best < 0 or mon.instability < run.roster[best].instability:
			best = ri
	return best

func _lab_build(run: RunState, rng: RandomNumberGenerator, st: Dictionary) -> void:
	var progress: bool = true
	while progress:
		progress = false
		var roles: Array[int] = _build_roles(run)
		var assign: Array[int] = _build_assign(run, roles, [])
		for inv_idx: int in run.inventory.size():
			var mut: MutationData = run.inventory[inv_idx]
			var ri: int = assign[inv_idx]
			if ri < 0:
				ri = _build_offplan_target(run, roles, mut)
			if ri < 0:
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
			if chance < BUILD_MIN_CHANCE:
				continue
			if run.living_count() == 1 and chance < 100:
				continue
			_operate(run, ri, inv_idx, free[0], stabs, rng, st)
			progress = true
			break

## Tank in front (spot 0), other non-carry monsters by HP in BUILD_OTHER_SPOTS,
## carry in the middle row (spot 2), or in spot 0 when it has no tank.
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
	for k: int in mini(others.size(), BUILD_OTHER_SPOTS.size()):
		place[BUILD_OTHER_SPOTS[k]] = others[k]
	if carry >= 0:
		place[BUILD_CARRY_SPOT if tank >= 0 else BUILD_TANK_SPOT] = carry
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
		if m != null and _build_target(run, roles, m) >= 0:
			return by_id[&"free_mutation"]
	if by_id.has(&"stabilizers") and _build_need(run, roles, []) > 0:
		return by_id[&"stabilizers"]
	if by_id.has(&"catalyst") and roles[0] >= 0 \
			and run.roster[roles[0]].instability >= BUILD_CATALYST_INSTABILITY:
		return by_id[&"catalyst"]
	if by_id.has(&"free_human") and run.living_count() < 3:
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
		"chance_sum": 0, "stabs_used": 0, "rerolls": 0}
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
	s += "Each run replicates `Game.new_run()` (%dg, %d humans, Subject 02 has Mantis Arm + Scorpion Tail), " % [
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
	s += "- **greedy**: buys affordable mutations highest rarity first (only ones that fit a free socket on " \
		+ "a living monster), then a human if living < %d. Lab: each inventory mutation goes to the " % HUMAN_BELOW \
		+ "monster with the highest success chance; stabilizers are added while chance < %d%%; operates if chance >= %d%%. " % LAB_RULES["greedy"] \
		+ "Reward: %s.\n" % ", ".join(REWARD_PREF["greedy"])
	s += "- **cautious**: buys the stabilizer first, then the same as greedy. Stabilizers while chance < %d%%; operates only if chance >= %d%%. " % LAB_RULES["cautious"] \
		+ "Reward: %s.\n" % ", ".join(REWARD_PREF["cautious"])
	s += "- **random**: each shop item bought with 50% chance (if affordable), each inventory item operated " \
		+ "with 50% chance on a random legal monster/slot with a random stabilizer count, random reward.\n"
	s += "- **build** (design/balance/stage3-tuning.md §3): carry = Subject 02 (plan %s), " % ", ".join(BUILD_CARRY_PLAN) \
		+ "tank = other living monster with the most HP (plan %s). Buys on-plan parts (carry first, " % ", ".join(BUILD_TANK_PLAN) \
		+ "cheapest first) keeping gold for the stabilizers to reach %d%%, then stabilizers, " % BUILD_TARGET_CHANCE \
		+ "rerolls up to %d times if nothing on-plan was in stock, a human if living < 2 " % BUILD_MAX_REROLLS \
		+ "(or < 3 with spare gold), off-plan commons if gold >= %d. Operates at >= %d%%. " % [BUILD_OFFPLAN_GOLD, BUILD_MIN_CHANCE] \
		+ "Formation: tank spot 0, carry spot 2. Reward: on-plan free mutation > stabilizers if needed " \
		+ "> catalyst > human > gold.\n\n"
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
	s += "Notes: \"Reached\" counts fights started. \"Gold at hub\" is on hub entry after the sponsor grant. " \
		+ "\"Mutations per living monster\" is averaged per run over its living roster at fight time. " \
		+ "Raw DPS = atk x (1 + crit) / interval, before DEF and abilities. B5 pays no battle reward.\n"
	return s
