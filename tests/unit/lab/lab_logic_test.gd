class_name LabLogicTest
extends GdUnitTestSuite
## Unit tests for LabLogic (stage 3 lab operations).

const MUT_DIR: String = "res://src/data/mutations/"

func _mut(id: String) -> MutationData:
	return load(MUT_DIR + id + ".tres") as MutationData

func _run(n: int = 2) -> RunState:
	var r: RunState = RunState.new()
	for i: int in n:
		var m: MonsterData = MonsterData.new()
		m.display_name = "Subject %02d" % (i + 1)
		r.roster.append(m)
		r.formation[i] = i
	return r

## RNG whose first randi_range(1, 100) is above `threshold` (above=true) or <= it.
func _rng_roll(threshold: int, above: bool) -> RandomNumberGenerator:
	for s: int in range(1, 1000):
		var probe: RandomNumberGenerator = RandomNumberGenerator.new()
		probe.seed = s
		var roll: int = probe.randi_range(1, 100)
		if (roll > threshold) == above:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = s
			return rng
	return null

func test_price_of_uses_rarity() -> void:
	assert_int(LabLogic.price_of(_mut("mantis_arm"))).is_equal(Tuning.PRICE_BY_RARITY[0])
	assert_int(LabLogic.price_of(_mut("scorpion_tail"))).is_equal(Tuning.PRICE_BY_RARITY[2])

func test_success_chance_formula() -> void:
	var r: RunState = _run(1)
	var m: MonsterData = r.roster[0]
	m.instability = 30.0
	var rare: MutationData = _mut("scorpion_tail")
	var expected: int = 100 - 30 - Tuning.RISK_PER_RARITY[2] + Tuning.STABILIZER_BONUS
	assert_int(LabLogic.success_chance(r, m, rare, 1)).is_equal(expected)
	var capped: int = 100 - 30 - Tuning.RISK_PER_RARITY[2] \
		+ Tuning.STABILIZER_MAX * Tuning.STABILIZER_BONUS
	assert_int(LabLogic.success_chance(r, m, rare, Tuning.STABILIZER_MAX + 3)) \
		.is_equal(mini(capped, Tuning.MAX_SUCCESS))

func test_success_chance_clamps() -> void:
	var r: RunState = _run(1)
	var m: MonsterData = r.roster[0]
	m.instability = 100.0
	assert_int(LabLogic.success_chance(r, m, _mut("scorpion_tail"), 0)).is_equal(Tuning.MIN_SUCCESS)
	m.instability = 0.0
	r.mush_memory = Tuning.MUSH_MEMORY_BONUS
	r.lucky_gene = true
	assert_int(LabLogic.success_chance(r, m, _mut("mantis_arm"), 2)).is_equal(Tuning.MAX_SUCCESS)

func test_breakdown_omits_zero_rows() -> void:
	var r: RunState = _run(1)
	var rows: Array[Dictionary] = LabLogic.chance_breakdown(r, r.roster[0], _mut("mantis_arm"), 0)
	assert_int(rows.size()).is_equal(1)
	assert_str(rows[0][&"label"] as String).is_equal("Base")
	r.roster[0].instability = 20.0
	r.lucky_gene = true
	r.mush_memory = 15
	rows = LabLogic.chance_breakdown(r, r.roster[0], _mut("scorpion_tail"), 1)
	var labels: Array = rows.map(func(d: Dictionary) -> String: return d[&"label"])
	assert_array(labels).contains_exactly(["Base", "Instability", "Rarity risk", "Stabilizers",
		"Mush Memory", "Lucky Gene"])
	assert_int(int(rows[1][&"value"])).is_equal(-20)

func test_operate_success() -> void:
	var r: RunState = _run(1)
	r.inventory.append(_mut("mantis_arm"))
	r.mush_memory = 15
	r.lucky_gene = true
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"ARM_L", 0, _rng_roll(100, false))
	assert_bool(res[&"ok"] as bool).is_true()
	assert_bool(res[&"success"] as bool).is_true()
	assert_int(res[&"chance"] as int).is_equal(100)
	assert_object(r.roster[0].slots[&"ARM_L"]).is_same(_mut("mantis_arm"))
	assert_float(r.roster[0].instability).is_equal(float(Tuning.INSTABILITY_PER_RARITY[0]))
	assert_bool(r.codex.has(&"mantis_arm")).is_true()
	assert_int(r.inventory.size()).is_equal(0)
	assert_int(r.mush_memory).is_equal(0)
	assert_bool(r.lucky_gene).is_false()

func test_operate_success_with_catalyst_adds_no_instability() -> void:
	var r: RunState = _run(1)
	r.inventory.append(_mut("mantis_arm"))
	r.catalyst = true
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"ARM_R", 0, _rng_roll(100, false))
	assert_bool(res[&"success"] as bool).is_true()
	assert_float(r.roster[0].instability).is_equal(0.0)
	assert_bool(r.catalyst).is_false()

func test_instability_clamped_to_100() -> void:
	var r: RunState = _run(1)
	r.roster[0].instability = 95.0
	r.stabilizers = 2
	r.lucky_gene = true
	r.mush_memory = 100
	r.inventory.append(_mut("scorpion_tail"))
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"TAIL", 2, _rng_roll(100, false))
	assert_bool(res[&"success"] as bool).is_true()
	assert_float(r.roster[0].instability).is_equal(100.0)
	assert_int(r.stabilizers).is_equal(0)

func test_operate_fail_mushes_refunds_and_clears_formation() -> void:
	var r: RunState = _run(2)
	r.formation[3] = 0 # a second spot pointing at the same monster
	r.roster[0].instability = 100.0
	r.gold = 0
	r.inventory.append(_mut("scorpion_tail"))
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"TAIL", 0, _rng_roll(Tuning.MIN_SUCCESS, true))
	assert_bool(res[&"success"] as bool).is_false()
	assert_bool(res[&"mushed"] as bool).is_true()
	var refund: int = roundi(Tuning.PRICE_BY_RARITY[2] * Tuning.MUSH_REFUND)
	assert_int(res[&"refund"] as int).is_equal(refund)
	assert_int(r.gold).is_equal(refund)
	assert_bool(r.roster[0].mushed).is_true()
	assert_int(r.mush_memory).is_equal(Tuning.MUSH_MEMORY_BONUS)
	assert_bool(r.formation.has(0)).is_false()
	assert_bool(r.formation.has(3)).is_false()
	assert_int(int(r.formation[1])).is_equal(1)
	assert_int(r.living_count()).is_equal(1)
	assert_int(r.inventory.size()).is_equal(0)

func test_operate_fail_with_insurance() -> void:
	var r: RunState = _run(1)
	r.roster[0].instability = 100.0
	r.insurance = true
	r.inventory.append(_mut("scorpion_tail"))
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"TAIL", 0, _rng_roll(Tuning.MIN_SUCCESS, true))
	assert_bool(res[&"insured"] as bool).is_true()
	assert_bool(res[&"mushed"] as bool).is_false()
	assert_bool(r.roster[0].mushed).is_false()
	assert_bool(r.insurance).is_false()
	assert_int(r.inventory.size()).is_equal(0)
	assert_bool(r.roster[0].slots.has(&"TAIL")).is_false()
	assert_int(r.mush_memory).is_equal(0)

func test_operate_invalid_inputs() -> void:
	var r: RunState = _run(2)
	r.inventory.append(_mut("mantis_arm"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_bool(LabLogic.operate(r, 0, 0, &"HEAD", 0, rng)[&"ok"] as bool).is_false()
	assert_bool(LabLogic.operate(r, 0, 0, &"ARM_L", 1, rng)[&"ok"] as bool).is_false()
	assert_bool(LabLogic.operate(r, 5, 0, &"ARM_L", 0, rng)[&"ok"] as bool).is_false()
	assert_bool(LabLogic.operate(r, 0, 3, &"ARM_L", 0, rng)[&"ok"] as bool).is_false()
	r.roster[1].mushed = true
	var res: Dictionary = LabLogic.operate(r, 1, 0, &"ARM_L", 0, rng)
	assert_bool(res[&"ok"] as bool).is_false()
	assert_str(res[&"reason"] as String).is_not_empty()
	assert_int(r.inventory.size()).is_equal(1)

func test_purge() -> void:
	var r: RunState = _run(1)
	var m: MonsterData = r.roster[0]
	m.apply_mutation(_mut("mantis_arm"), &"ARM_L")
	m.instability = 10.0
	r.gold = Tuning.PURGE_COST - 1
	assert_bool(LabLogic.purge(r, 0, &"ARM_L")).is_false()
	r.gold = Tuning.PURGE_COST
	assert_bool(LabLogic.purge(r, 0, &"HEAD")).is_false()
	assert_bool(LabLogic.purge(r, 0, &"ARM_L")).is_true()
	assert_int(r.gold).is_equal(0)
	assert_bool(m.slots.has(&"ARM_L")).is_false()
	assert_int(r.inventory.size()).is_equal(1)
	assert_float(m.instability).is_equal(maxf(0.0, 10.0 - Tuning.PURGE_INSTABILITY))
