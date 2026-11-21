class_name ChampionTest
extends GdUnitTestSuite
## Champion boss (handoff.md §2 "Champion"): ChampionStore save/load and
## EnemyGen.generate_for_battle / generate_champion. Uses a temp path only;
## never touches the real user://champion.tres.

const TEST_PATH: String = "user://test_champion_unit.tres"
const HUMAN_PATH: String = "res://src/data/kinds/human.tres"
const MANTIS_PATH: String = "res://src/data/mutations/mantis_arm.tres"
const SCORPION_PATH: String = "res://src/data/mutations/scorpion_tail.tres"
const LEECH_PATH: String = "res://src/data/mutations/leech_maw.tres"
const BONE_PATH: String = "res://src/data/mutations/bone_plating.tres"
const FINAL: int = Tuning.BATTLES_PER_RUN - 1

func before_test() -> void:
	ChampionStore.clear(TEST_PATH)

func after_test() -> void:
	ChampionStore.clear(TEST_PATH)

func _human(label: String) -> MonsterData:
	var m: MonsterData = (load(HUMAN_PATH) as MonsterData).clone()
	m.display_name = label
	return m

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r

## A mutated human: mantis arm + scorpion tail (+ leech maw + bone plating if `heavy`).
func _mutant(label: String, heavy: bool) -> MonsterData:
	var m: MonsterData = _human(label)
	m.apply_mutation(load(MANTIS_PATH) as MutationData, &"ARM_R")
	m.apply_mutation(load(SCORPION_PATH) as MutationData, &"TAIL")
	if heavy:
		m.apply_mutation(load(LEECH_PATH) as MutationData, &"HEAD")
		m.apply_mutation(load(BONE_PATH) as MutationData, &"TORSO")
	return m

func _team(names: Array[String], heavy: bool) -> Array[MonsterData]:
	var team: Array[MonsterData] = []
	for n: String in names:
		team.append(_mutant(n, heavy))
	return team

func test_save_load_roundtrip() -> void:
	var team: Array[MonsterData] = _team(["Alpha", "Beta"], false)
	team[0].instability = 42.0
	assert_bool(ChampionStore.save_team(team, TEST_PATH)).is_true()
	assert_bool(ChampionStore.has_champion(TEST_PATH)).is_true()
	var loaded: Array[MonsterData] = ChampionStore.load_team(TEST_PATH)
	assert_int(loaded.size()).is_equal(2)
	assert_str(loaded[0].display_name).is_equal("Alpha")
	assert_str(loaded[1].display_name).is_equal("Beta")
	assert_float(loaded[0].instability).is_equal(42.0)
	assert_str(String((loaded[0].slots[&"ARM_R"] as MutationData).id)).is_equal("mantis_arm")
	assert_str(String((loaded[0].slots[&"TAIL"] as MutationData).id)).is_equal("scorpion_tail")
	# Saved copies are independent of the live roster.
	assert_object(loaded[0]).is_not_same(team[0])
	# Overwrites the previous champion.
	assert_bool(ChampionStore.save_team(_team(["Gamma"], false), TEST_PATH)).is_true()
	loaded = ChampionStore.load_team(TEST_PATH)
	assert_int(loaded.size()).is_equal(1)
	assert_str(loaded[0].display_name).is_equal("Gamma")

func test_no_file_means_no_champion() -> void:
	assert_bool(ChampionStore.has_champion(TEST_PATH)).is_false()
	assert_int(ChampionStore.load_team(TEST_PATH).size()).is_equal(0)

func test_mush_excluded_and_capped_at_max_team() -> void:
	var team: Array[MonsterData] = _team(["A", "B", "C", "D", "E", "F"], false)
	team[1].mushed = true
	assert_bool(ChampionStore.save_team(team, TEST_PATH)).is_true()
	var loaded: Array[MonsterData] = ChampionStore.load_team(TEST_PATH)
	assert_int(loaded.size()).is_equal(Tuning.MAX_TEAM)
	for m: MonsterData in loaded:
		assert_bool(m.mushed).is_false()
		assert_str(m.display_name).is_not_equal("B")

func test_all_mush_saves_nothing() -> void:
	var team: Array[MonsterData] = _team(["A"], false)
	team[0].mushed = true
	assert_bool(ChampionStore.save_team(team, TEST_PATH)).is_false()
	assert_bool(ChampionStore.has_champion(TEST_PATH)).is_false()

func test_no_champion_gives_dr_splice() -> void:
	var empty: Array[MonsterData] = []
	var gen: Dictionary = EnemyGen.generate_for_battle(FINAL, _rng(7), 0, empty)
	assert_bool(bool(gen[&"champion"])).is_false()
	var team: Array = gen[&"team"]
	assert_str((team[0] as MonsterData).display_name).is_equal(Tuning.BOSS_NAME)
	assert_int(team.size()).is_equal(Tuning.ENEMY_TEAM_SIZE[FINAL])

func test_champion_only_replaces_final_battle() -> void:
	var champ: Array[MonsterData] = _team(["A", "B"], false)
	var gen: Dictionary = EnemyGen.generate_for_battle(FINAL - 1, _rng(7), 0, champ)
	assert_bool(bool(gen[&"champion"])).is_false()

func test_champion_replaces_boss_and_is_labelled() -> void:
	var champ: Array[MonsterData] = _team(["A", "B", "C"], false)
	var gen: Dictionary = EnemyGen.generate_for_battle(FINAL, _rng(7), 999, champ)
	assert_bool(bool(gen[&"champion"])).is_true()
	assert_int(int(gen[&"adapt"])).is_equal(0)
	var team: Array = gen[&"team"]
	assert_int(team.size()).is_equal(3)
	for i: int in team.size():
		var m: MonsterData = team[i]
		assert_str(m.display_name).is_equal(Tuning.CHAMPION_UNIT_PREFIX + champ[i].display_name)
		assert_object(m).is_not_same(champ[i])
	# Input is untouched.
	assert_str(champ[0].display_name).is_equal("A")
	# Distinct spots 0-5.
	var spots: Array = gen[&"spots"]
	assert_int(spots.size()).is_equal(3)
	for s: Variant in spots:
		assert_int(int(s)).is_between(0, Tuning.FORMATION_ROWS * Tuning.FORMATION_COLS - 1)
		assert_int(spots.count(s)).is_equal(1)

func test_champion_is_deterministic() -> void:
	var champ: Array[MonsterData] = _team(["A", "B", "C", "D"], true)
	var a: Dictionary = EnemyGen.generate_champion(champ, _rng(11))
	var b: Dictionary = EnemyGen.generate_champion(champ, _rng(11))
	assert_str(str(a[&"spots"])).is_equal(str(b[&"spots"]))
	assert_float(float(a[&"scale"])).is_equal(float(b[&"scale"]))

func test_normalization_keeps_power_in_band() -> void:
	var budget: float = float(Tuning.ENEMY_BUDGET[FINAL])
	var lo: float = Tuning.CHAMPION_NORM_MIN * budget
	var hi: float = Tuning.CHAMPION_NORM_MAX * budget
	# Strong team (above the band), weak team (below), and 1-mutation team.
	var weak: Array[MonsterData] = [_human("W")]
	weak[0].apply_mutation(load(MANTIS_PATH) as MutationData, &"ARM_R")
	var cases: Array = [_team(["A", "B", "C", "D"], true), _team(["A"], false), weak]
	for champ: Array[MonsterData] in cases:
		var gen: Dictionary = EnemyGen.generate_champion(champ, _rng(3))
		var power: float = float(gen[&"power"])
		var scale: float = float(gen[&"scale"])
		if scale > Tuning.CHAMPION_SCALE_MIN and scale < Tuning.CHAMPION_SCALE_MAX:
			assert_float(power).is_between(lo - 0.001, hi + 0.001)
		# HP and ATK totals are scaled by exactly `scale`.
		var src_stats: Dictionary = champ[0].get_total_stats()
		var out_stats: Dictionary = (gen[&"team"][0] as MonsterData).get_total_stats()
		assert_float(float(out_stats[&"hp"])).is_equal_approx(
			float(src_stats[&"hp"]) * scale, 0.01)
		assert_float(float(out_stats[&"atk"])).is_equal_approx(
			float(src_stats[&"atk"]) * scale, 0.01)
	# A team already inside the band is not changed.
	var inside: float = EnemyGen.champion_scale(roundi(budget))
	assert_float(inside).is_equal(1.0)

func test_champion_skips_hp_mult() -> void:
	# Arrange: a team whose power is inside the band, so the scale is exactly 1.
	var champ: Array[MonsterData] = _team(["A", "B"], false)
	champ[0].apply_mutation(load(LEECH_PATH) as MutationData, &"HEAD")
	assert_float(EnemyGen.champion_scale(EnemyGen.team_power(champ))).is_equal(1.0)
	# Act
	var gen: Dictionary = EnemyGen.generate_champion(champ, _rng(5))
	# Assert: base HP is the player's body, not BASE_HP x ENEMY_HP_MULT[final].
	for m: MonsterData in gen[&"team"]:
		assert_float(m.base_hp).is_equal(Tuning.BASE_HP)
		assert_bool(is_equal_approx(m.base_hp,
			Tuning.BASE_HP * Tuning.ENEMY_HP_MULT[FINAL])).is_false()
