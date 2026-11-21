class_name BetOdds
extends RefCounted
## Bet odds from headless simulations of the real matchup (stage 2,
## design/jam-plan.md "CHOSEN DESIGN": mult = clamp(BET_EDGE / p, MIN, MAX)).

const CLAIMS: Array[StringName] = [&"victory", &"flawless", &"blitz", &"last_stand", &"mvp"]

## Runs `runs` headless sims (seeds base_seed + i) and returns claim probabilities:
## {victory, flawless, blitz, last_stand: float, mvp: Dictionary(roster_idx -> float)}.
## `player_mods` is passed to BattleSim unchanged (player skill bonuses), so the
## odds match the real battle.
static func estimate(player_team: Array[MonsterData], player_spots: Array[int], player_roster_idx: Array[int],
		enemy_team: Array[MonsterData], enemy_spots: Array[int], base_seed: int,
		runs: int = Tuning.SIM_RUNS, player_mods: Dictionary = {}) -> Dictionary:
	var counts: Dictionary = {&"victory": 0, &"flawless": 0, &"blitz": 0, &"last_stand": 0}
	var mvp: Dictionary = {}
	for r: int in player_roster_idx:
		mvp[r] = 0
	for i: int in runs:
		var res: Dictionary = BattleSim.new(player_team, player_spots, player_roster_idx,
			enemy_team, enemy_spots, base_seed + i, false, player_mods).run_to_end()
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

## True if `claim` can be won at all with `placed_count` player monsters,
## judged from claim_won() alone (no simulation):
## - nothing is winnable with 0 placed monsters;
## - Last Stand needs 2+ placed monsters: with 1, every win leaves exactly one
##   monster standing, so it would be a duplicate of Victory at a worse price;
## - Victory, Flawless, Blitz and MVP are always possible.
static func claim_possible(claim: StringName, placed_count: int) -> bool:
	if placed_count <= 0 or not CLAIMS.has(claim):
		return false
	if claim == &"last_stand":
		return placed_count >= 2
	return true

## Multiplier offered on the bet screen and stored in the bet (battle settles
## with exactly this value). A possible claim that won 0 of the simulated
## fights is a longshot and pays Tuning.BET_MAX_MULT; an impossible claim
## returns 0.0 (not bettable). Otherwise identical to payout_mult(p).
static func offered_mult(p: float, possible: bool) -> float:
	if not possible:
		return 0.0
	if p <= 0.0:
		return Tuning.BET_MAX_MULT
	return payout_mult(p)

## True for a possible claim that no simulated fight produced (shown as "<1%").
static func is_longshot(p: float, possible: bool) -> bool:
	return possible and p <= 0.0

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
