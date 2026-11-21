class_name EnemyScalingTest
extends GdUnitTestSuite
## Unit tests for adaptive enemy scaling (design/balance/stage3-tuning.md §6):
## EnemyGen.player_power, EnemyGen.adapt_bonus and generate() with a power.

const HUMAN_PATH: String = "res://src/data/kinds/human.tres"
const MANTIS_PATH: String = "res://src/data/mutations/mantis_arm.tres"
const SCORPION_PATH: String = "res://src/data/mutations/scorpion_tail.tres"
const LEECH_PATH: String = "res://src/data/mutations/leech_maw.tres"

func _human() -> MonsterData:
	return (load(HUMAN_PATH) as MonsterData).clone()

func _mut(path: String) -> MutationData:
	return load(path) as MutationData

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r

## Sum of the budget cost of every mutation across a generated team.
func _spent(team: Array) -> int:
	var total: int = 0
	for m: MonsterData in team:
		for v: Variant in m.slots.values():
			total += EnemyGen.cost_of(v as MutationData)
	return total

func _signature(gen: Dictionary) -> String:
	var parts: Array[String] = []
	for m: MonsterData in gen[&"team"]:
		var keys: Array = m.slots.keys()
		keys.sort()
		var ids: Array[String] = []
		for k: Variant in keys:
			ids.append("%s:%s" % [k, (m.slots[k] as MutationData).id])
		parts.append("%s|%s|%s" % [m.display_name, m.base_hp, ",".join(ids)])
	return "%s#%s#%s" % [";".join(parts), str(gen[&"spots"]), str(gen[&"archetypes"])]

func test_power_counts_only_living_mutations_plus_extra_bodies() -> void:
	var a: MonsterData = _human()
	a.apply_mutation(_mut(MANTIS_PATH), &"ARM_R")       # common
	a.apply_mutation(_mut(SCORPION_PATH), &"TAIL")      # rare
	var b: MonsterData = _human()
	b.apply_mutation(_mut(LEECH_PATH), &"HEAD")         # uncommon
	var dead: MonsterData = _human()
	dead.apply_mutation(_mut(SCORPION_PATH), &"TAIL")
	dead.mushed = true
	var muts_power: int = EnemyGen.cost_of(_mut(MANTIS_PATH)) \
		+ EnemyGen.cost_of(_mut(SCORPION_PATH)) + EnemyGen.cost_of(_mut(LEECH_PATH))
	var roster: Array[MonsterData] = [a, b, dead]
	# 2 living = START_HUMANS: no body power; the mushed monster adds nothing.
	assert_int(EnemyGen.player_power(roster)).is_equal(muts_power)
	# 3 extra living bodies beyond START_HUMANS.
	roster.append(_human())
	roster.append(_human())
	roster.append(_human())
	var extra: int = 2 + 3 - Tuning.START_HUMANS
	assert_int(EnemyGen.player_power(roster)).is_equal(muts_power + extra * Tuning.ADAPT_BODY_POWER)
	var empty: Array[MonsterData] = []
	assert_int(EnemyGen.player_power(empty)).is_equal(0)

func test_bonus_zero_at_or_below_expected() -> void:
	for i: int in Tuning.BATTLES_PER_RUN:
		var e: int = Tuning.ADAPT_EXPECTED[i]
		assert_int(EnemyGen.adapt_bonus(i, e)).is_equal(0)
		assert_int(EnemyGen.adapt_bonus(i, e - 5)).is_equal(0)
		assert_int(EnemyGen.adapt_bonus(i, 0)).is_equal(0)

func test_bonus_formula_and_clamp() -> void:
	for i: int in Tuning.BATTLES_PER_RUN:
		var e: int = Tuning.ADAPT_EXPECTED[i]
		var want: int = clampi(roundi(Tuning.ADAPT_RATE * 1.0), 0, Tuning.ADAPT_MAX[i])
		assert_int(EnemyGen.adapt_bonus(i, e + 1)).is_equal(want)
		assert_int(EnemyGen.adapt_bonus(i, e + 1000)).is_equal(Tuning.ADAPT_MAX[i])

func test_power_zero_matches_default_generation() -> void:
	for battle: int in Tuning.BATTLES_PER_RUN:
		var old: Dictionary = EnemyGen.generate(battle, _rng(42 + battle))
		var zero: Dictionary = EnemyGen.generate(battle, _rng(42 + battle), 0)
		assert_str(_signature(zero)).is_equal(_signature(old))
		assert_int(int(zero[&"adapt"])).is_equal(0)
		for m: MonsterData in zero[&"team"]:
			assert_float(m.base_hp).is_equal_approx(Tuning.BASE_HP * Tuning.ENEMY_HP_MULT[battle], 0.001)

func test_bonus_spends_more_budget_or_adds_hp() -> void:
	for battle: int in Tuning.BATTLES_PER_RUN:
		var base: Dictionary = EnemyGen.generate(battle, _rng(7))
		var power: int = Tuning.ADAPT_EXPECTED[battle] + 1000
		var hard: Dictionary = EnemyGen.generate(battle, _rng(7), power)
		var bonus: int = int(hard[&"adapt"])
		assert_int(bonus).is_equal(Tuning.ADAPT_MAX[battle])
		var base_hp: float = Tuning.BASE_HP * Tuning.ENEMY_HP_MULT[battle]
		var extra_hp: float = (hard[&"team"][0] as MonsterData).base_hp - base_hp
		var leftover: float = extra_hp / (base_hp * maxf(Tuning.ADAPT_HP_PER_POINT, 0.000001))
		# Every bonus point is either spent on mutations or turned into HP.
		var spent_extra: int = _spent(hard[&"team"]) - _spent(base[&"team"])
		assert_int(spent_extra + roundi(leftover)).is_equal(bonus)
		assert_bool(spent_extra > 0 or extra_hp > 0.0).is_true()

func test_max_bonus_leftover_budget_becomes_hp() -> void:
	# Whatever the round-robin could not spend shows up as base HP on every enemy.
	for battle: int in Tuning.BATTLES_PER_RUN:
		var gen: Dictionary = EnemyGen.generate(battle, _rng(3), 100000)
		var team: Array = gen[&"team"]
		var base_hp: float = Tuning.BASE_HP * Tuning.ENEMY_HP_MULT[battle]
		var leftover: int = Tuning.ENEMY_BUDGET[battle] + int(gen[&"adapt"]) - _spent(team)
		assert_int(leftover).is_greater_equal(0)
		var want: float = base_hp * (1.0 + Tuning.ADAPT_HP_PER_POINT * leftover)
		for m: MonsterData in team:
			assert_float(m.base_hp).is_equal_approx(want, 0.001)

func test_same_seed_same_power_is_deterministic() -> void:
	for battle: int in Tuning.BATTLES_PER_RUN:
		var power: int = Tuning.ADAPT_EXPECTED[battle] + 2
		var a: Dictionary = EnemyGen.generate(battle, _rng(99), power)
		var b: Dictionary = EnemyGen.generate(battle, _rng(99), power)
		assert_str(_signature(a)).is_equal(_signature(b))
		assert_int(int(a[&"adapt"])).is_equal(int(b[&"adapt"]))
