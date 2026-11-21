class_name BetOdds
extends RefCounted
## Bet odds from headless simulations of the real matchup (stage 2,
## design/jam-plan.md "CHOSEN DESIGN": mult = clamp(BET_EDGE / p, MIN, MAX)).

const CLAIMS: Array[StringName] = [&"victory", &"flawless", &"blitz", &"last_stand", &"mvp"]

## Runs `runs` headless sims (seeds base_seed + i) and returns claim probabilities:
## {victory, flawless, blitz, last_stand: float, mvp: Dictionary(roster_idx -> float)}.
static func estimate(player_team: Array[MonsterData], player_spots: Array[int], player_roster_idx: Array[int],
		enemy_team: Array[MonsterData], enemy_spots: Array[int], base_seed: int,
		runs: int = Tuning.SIM_RUNS) -> Dictionary:
	var counts: Dictionary = {&"victory": 0, &"flawless": 0, &"blitz": 0, &"last_stand": 0}
	var mvp: Dictionary = {}
	for r: int in player_roster_idx:
		mvp[r] = 0
	for i: int in runs:
		var res: Dictionary = BattleSim.new(player_team, player_spots, player_roster_idx,
			enemy_team, enemy_spots, base_seed + i, false).run_to_end()
		for claim: StringName in counts.keys():
			if claim_won(claim, res):
				counts[claim] += 1
		for r: int in player_roster_idx:
			if claim_won(&"mvp", res, r):
				mvp[r] += 1
	var n: float = maxf(1.0, float(runs))
	var out: Dictionary = {}
	for claim: StringName in counts.keys():
		out[claim] = counts[claim] / n
	for r: int in mvp.keys():
		mvp[r] = mvp[r] / n
	out[&"mvp"] = mvp
	return out

## Payout multiplier for probability p; 0.0 means the claim is unavailable.
static func payout_mult(p: float) -> float:
	if p <= 0.0:
		return 0.0
	return clampf(snappedf(Tuning.BET_EDGE / p, 0.1), Tuning.BET_MIN_MULT, Tuning.BET_MAX_MULT)

## True if `claim` is satisfied by a BattleSim.result(). MVP needs mvp_roster_idx
## (ties for top damage count as won).
static func claim_won(claim: StringName, result: Dictionary, mvp_roster_idx := -1) -> bool:
	var won: bool = int(result.get(&"winner", BattleSim.ENEMY)) == BattleSim.PLAYER
	match claim:
		&"victory":
			return won
		&"flawless":
			return won and int(result.get(&"player_deaths", 1)) == 0
		&"blitz":
			return won and float(result.get(&"time", INF)) < Tuning.BLITZ_TIME
		&"last_stand":
			return won and int(result.get(&"player_alive", 0)) == 1
		&"mvp":
			var dmg: Dictionary = result.get(&"damage_by_roster", {})
			if mvp_roster_idx < 0 or not dmg.has(mvp_roster_idx):
				return false
			var mine: int = int(dmg[mvp_roster_idx])
			for v: Variant in dmg.values():
				if int(v) > mine:
					return false
			return true
	return false
