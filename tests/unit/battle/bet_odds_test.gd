class_name BetOddsTest
extends GdUnitTestSuite
## Unit tests for BetOdds and EnemyGen (stage 2).

func _res(winner: int, time: float, deaths: int, alive: int, dmg: Dictionary) -> Dictionary:
	return {&"winner": winner, &"time": time, &"player_deaths": deaths,
		&"player_alive": alive, &"damage_by_roster": dmg}

func test_payout_mult_bounds() -> void:
	assert_float(BetOdds.payout_mult(0.0)).is_equal(0.0)
	assert_float(BetOdds.payout_mult(-1.0)).is_equal(0.0)
	assert_float(BetOdds.payout_mult(1.0)).is_equal(Tuning.BET_MIN_MULT)
	assert_float(BetOdds.payout_mult(0.001)).is_equal(Tuning.BET_MAX_MULT)
	assert_float(BetOdds.payout_mult(0.3)).is_equal_approx(3.0, 0.001)

func test_claim_won_cases() -> void:
	var win: Dictionary = _res(0, 20.0, 0, 2, {0: 50, 1: 30})
	assert_bool(BetOdds.claim_won(&"victory", win)).is_true()
	assert_bool(BetOdds.claim_won(&"flawless", win)).is_true()
	assert_bool(BetOdds.claim_won(&"blitz", win)).is_true()
	assert_bool(BetOdds.claim_won(&"last_stand", win)).is_false()
	assert_bool(BetOdds.claim_won(&"mvp", win, 0)).is_true()
	assert_bool(BetOdds.claim_won(&"mvp", win, 1)).is_false()
	assert_bool(BetOdds.claim_won(&"mvp", win)).is_false()
	var slow: Dictionary = _res(0, Tuning.BLITZ_TIME, 1, 1, {0: 10, 1: 10})
	assert_bool(BetOdds.claim_won(&"blitz", slow)).is_false()
	assert_bool(BetOdds.claim_won(&"flawless", slow)).is_false()
	assert_bool(BetOdds.claim_won(&"last_stand", slow)).is_true()
	assert_bool(BetOdds.claim_won(&"mvp", slow, 1)).is_true()
	var loss: Dictionary = _res(1, 10.0, 2, 0, {0: 10})
	assert_bool(BetOdds.claim_won(&"victory", loss)).is_false()
	assert_bool(BetOdds.claim_won(&"blitz", loss)).is_false()

func test_estimate_returns_probabilities_and_is_deterministic() -> void:
	var p: Array[MonsterData] = [MonsterData.new(), MonsterData.new()]
	var e: Array[MonsterData] = [MonsterData.new()]
	var spots: Array[int] = [0, 1]
	var ridx: Array[int] = [0, 1]
	var es: Array[int] = [0]
	var a: Dictionary = BetOdds.estimate(p, spots, ridx, e, es, 100, 20)
	var b: Dictionary = BetOdds.estimate(p, spots, ridx, e, es, 100, 20)
	assert_dict(a).is_equal(b)
	assert_float(a[&"victory"] as float).is_greater(0.5)
	assert_bool((a[&"mvp"] as Dictionary).has(1)).is_true()
	for k: StringName in [&"victory", &"flawless", &"blitz", &"last_stand"]:
		assert_float(a[k] as float).is_between(0.0, 1.0)

func test_enemy_gen_respects_budget_and_sockets() -> void:
	for battle: int in Tuning.BATTLES_PER_RUN:
		for s: int in 10:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = battle * 100 + s
			var g: Dictionary = EnemyGen.generate(battle, rng)
			var team: Array = g[&"team"]
			var spots: Array = g[&"spots"]
			assert_int(team.size()).is_equal(Tuning.ENEMY_TEAM_SIZE[battle])
			assert_int(spots.size()).is_equal(team.size())
			var seen: Dictionary = {}
			for sp: Variant in spots:
				assert_int(int(sp)).is_between(0, 5)
				assert_bool(seen.has(sp)).is_false()
				seen[sp] = true
			var spent: int = 0
			for m: Variant in team:
				var md: MonsterData = m as MonsterData
				for slot: StringName in md.slots.keys():
					var mut: MutationData = md.slots[slot]
					assert_int(int(MonsterData.SLOT_SOCKET[slot])).is_equal(int(mut.socket_type))
					spent += EnemyGen.cost_of(mut)
			assert_int(spent).is_less_equal(Tuning.ENEMY_BUDGET[battle])
			assert_int(spent).is_equal(Tuning.ENEMY_BUDGET[battle])

func test_enemy_gen_is_deterministic_and_boss_named() -> void:
	var r1: RandomNumberGenerator = RandomNumberGenerator.new()
	r1.seed = 5
	var r2: RandomNumberGenerator = RandomNumberGenerator.new()
	r2.seed = 5
	var a: Dictionary = EnemyGen.generate(4, r1)
	var b: Dictionary = EnemyGen.generate(4, r2)
	assert_array(a[&"spots"] as Array).is_equal(b[&"spots"] as Array)
	assert_str((a[&"team"][0] as MonsterData).display_name).is_equal(Tuning.BOSS_NAME)

func test_payout_mult_old_signature_unchanged() -> void:
	# tools/balance/run_sim.gd and older callers still use payout_mult(p).
	assert_float(BetOdds.payout_mult(0.0)).is_equal(0.0)
	assert_float(BetOdds.payout_mult(0.5)).is_equal_approx(1.8, 0.001)

func test_offered_mult_longshot_pays_max() -> void:
	assert_float(BetOdds.offered_mult(0.0, true)).is_equal(Tuning.BET_MAX_MULT)
	assert_bool(BetOdds.is_longshot(0.0, true)).is_true()
	assert_bool(BetOdds.is_longshot(0.01, true)).is_false()

func test_offered_mult_impossible_is_zero() -> void:
	assert_float(BetOdds.offered_mult(0.0, false)).is_equal(0.0)
	assert_float(BetOdds.offered_mult(0.7, false)).is_equal(0.0)
	assert_bool(BetOdds.is_longshot(0.0, false)).is_false()

func test_offered_mult_matches_payout_mult_when_p_positive() -> void:
	for p: float in [0.01, 0.1, 0.3, 0.5, 0.87, 1.0]:
		assert_float(BetOdds.offered_mult(p, true)).is_equal(BetOdds.payout_mult(p))

func test_claim_possible_rules() -> void:
	for claim: StringName in BetOdds.CLAIMS:
		assert_bool(BetOdds.claim_possible(claim, 0)).is_false()
		assert_bool(BetOdds.claim_possible(claim, 2)).is_true()
	assert_bool(BetOdds.claim_possible(&"last_stand", 1)).is_false()
	for claim: StringName in [&"victory", &"flawless", &"blitz", &"mvp"]:
		assert_bool(BetOdds.claim_possible(claim, 1)).is_true()
	assert_bool(BetOdds.claim_possible(&"nonsense", 3)).is_false()

func test_longshot_bet_settles_at_offered_mult() -> void:
	# Battle settlement: payout = roundi(stake * bet.mult) when the claim is won.
	var mult: float = BetOdds.offered_mult(0.0, true)
	var win: Dictionary = _res(0, 5.0, 1, 1, {0: 10, 1: 5})
	assert_bool(BetOdds.claim_won(&"last_stand", win)).is_true()
	assert_int(roundi(10 * mult)).is_equal(roundi(10 * Tuning.BET_MAX_MULT))
	assert_int(BetText.net_win(10, mult)).is_equal(roundi(10 * Tuning.BET_MAX_MULT) - 10)

func test_bet_text_odds_words() -> void:
	assert_str(BetText.odds_text(0.87)).is_equal("Likely 87%")
	assert_str(BetText.odds_text(0.3)).is_equal("Risky 30%")
	assert_str(BetText.odds_text(0.0)).is_equal("Longshot <1%")
	assert_str(BetText.odds_text(0.004)).is_equal("Longshot <1%")
	assert_str(BetText.odds_word(0.5)).is_equal("Even")
