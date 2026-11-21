class_name RewardLogicTest
extends GdUnitTestSuite
## Unit tests for RewardLogic (stage 3 post-battle rewards).

func _run(n: int = 2) -> RunState:
	var r: RunState = RunState.new()
	for i: int in n:
		r.roster.append(MonsterData.new())
		r.formation[i] = i
	return r

func _rng(s: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = s
	return rng

func _ids_seen(r: RunState) -> Array[StringName]:
	var seen: Array[StringName] = []
	for s: int in 60:
		for o: Dictionary in RewardLogic.roll_options(r, _rng(s)):
			if not seen.has(o[&"id"]):
				seen.append(o[&"id"])
	return seen

func _ids(opts: Array[Dictionary]) -> Array:
	return opts.map(func(o: Dictionary) -> StringName: return o[&"id"])

func test_roll_options_distinct_and_complete() -> void:
	var r: RunState = _run()
	for s: int in 30:
		var opts: Array[Dictionary] = RewardLogic.roll_options(r, _rng(s))
		assert_int(opts.size()).is_equal(Tuning.REWARD_CHOICES)
		var ids: Array = []
		for o: Dictionary in opts:
			assert_bool(ids.has(o[&"id"])).is_false()
			ids.append(o[&"id"])
			assert_str(o[&"title"] as String).is_not_empty()
			assert_str(o[&"description"] as String).is_not_empty()
			if o[&"id"] == &"free_mutation":
				var m: MutationData = o[&"mutation"] as MutationData
				assert_object(m).is_not_null()
				assert_str(o[&"title"] as String).contains(m.display_name)
			else:
				assert_object(o[&"mutation"]).is_null()

func test_roll_options_deterministic() -> void:
	var r: RunState = _run()
	assert_array(_ids(RewardLogic.roll_options(r, _rng(7)))) \
		.is_equal(_ids(RewardLogic.roll_options(r, _rng(7))))

func test_exclusions() -> void:
	var r: RunState = _run(Tuning.ROSTER_MAX)
	r.lucky_gene = true
	r.insurance = true
	r.catalyst = true
	var seen: Array[StringName] = _ids_seen(r)
	for bad: StringName in [&"free_human", &"cleanse", &"lucky_gene", &"insurance", &"catalyst"]:
		assert_bool(seen.has(bad)).is_false()
	assert_int(seen.size()).is_equal(3)

func test_inclusions_when_valid() -> void:
	var r: RunState = _run(2)
	r.roster[1].instability = 20.0
	assert_int(_ids_seen(r).size()).is_equal(RewardLogic.IDS.size())

func test_cleanse_ignores_mush_instability() -> void:
	var r: RunState = _run(2)
	r.roster[0].instability = 50.0
	r.roster[0].mushed = true
	assert_bool(_ids_seen(r).has(&"cleanse")).is_false()

func test_apply_each() -> void:
	var r: RunState = _run(2)
	r.roster[0].instability = 20.0
	r.roster[1].instability = 40.0
	RewardLogic.apply(r, {&"id": &"stabilizers"})
	assert_int(r.stabilizers).is_equal(Tuning.REWARD_STABILIZERS)
	RewardLogic.apply(r, {&"id": &"gold"})
	assert_int(r.gold).is_equal(Tuning.REWARD_GOLD)
	RewardLogic.apply(r, {&"id": &"cleanse"})
	assert_float(r.roster[1].instability).is_equal(maxf(0.0, 40.0 - Tuning.CLEANSE_AMOUNT))
	assert_float(r.roster[0].instability).is_equal(20.0)
	RewardLogic.apply(r, {&"id": &"free_human"})
	assert_int(r.roster.size()).is_equal(3)
	assert_str(r.roster[2].display_name).is_equal("Subject 03")
	assert_int(int(r.formation[2])).is_equal(2)
	var m: MutationData = EnemyGen.all_mutations()[0]
	RewardLogic.apply(r, {&"id": &"free_mutation", &"mutation": m})
	assert_object(r.inventory[0]).is_same(m)
	for id: StringName in [&"lucky_gene", &"insurance", &"catalyst"]:
		RewardLogic.apply(r, {&"id": id})
	assert_bool(r.lucky_gene and r.insurance and r.catalyst).is_true()
