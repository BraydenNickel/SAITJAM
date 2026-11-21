class_name ChampionGrowthTest
extends GdUnitTestSuite
## Champion growth: the saved champion gets a little harder with every run the
## player wins (Tuning.CHAMPION_GROWTH_PER_WIN, capped by CHAMPION_GROWTH_MAX).
## Uses a temp path only; never touches the real user://champion.tres.

const TEST_PATH: String = "user://test_champion_growth.tres"
const HUMAN_PATH: String = "res://src/data/kinds/human.tres"
const MANTIS_PATH: String = "res://src/data/mutations/mantis_arm.tres"
const SCORPION_PATH: String = "res://src/data/mutations/scorpion_tail.tres"

func before_test() -> void:
	ChampionStore.clear(TEST_PATH)

func after_test() -> void:
	ChampionStore.clear(TEST_PATH)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _team() -> Array[MonsterData]:
	var m: MonsterData = (load(HUMAN_PATH) as MonsterData).clone()
	m.display_name = "Alpha"
	m.apply_mutation(load(MANTIS_PATH) as MutationData, &"ARM_R")
	m.apply_mutation(load(SCORPION_PATH) as MutationData, &"TAIL")
	var team: Array[MonsterData] = [m]
	return team

func test_growth_first_win_is_unchanged() -> void:
	assert_float(EnemyGen.champion_growth(1)).is_equal_approx(1.0, 0.0001)
	assert_float(EnemyGen.champion_growth(0)).is_equal_approx(1.0, 0.0001)

func test_growth_four_wins_is_fifteen_percent() -> void:
	assert_float(EnemyGen.champion_growth(4)).is_equal_approx(1.15, 0.0001)

func test_growth_is_capped() -> void:
	assert_float(EnemyGen.champion_growth(50)).is_equal_approx(1.30, 0.0001)

func test_wins_counter_increments_across_saves() -> void:
	assert_int(ChampionStore.wins(TEST_PATH)).is_equal(0)
	assert_bool(ChampionStore.save_team(_team(), TEST_PATH)).is_true()
	assert_int(ChampionStore.wins(TEST_PATH)).is_equal(1)
	assert_bool(ChampionStore.save_team(_team(), TEST_PATH)).is_true()
	assert_int(ChampionStore.wins(TEST_PATH)).is_equal(2)
	assert_int(ChampionStore.load_team(TEST_PATH).size()).is_equal(1)

func test_generate_champion_growth_raises_hp() -> void:
	var plain: Dictionary = EnemyGen.generate_champion(_team(), _rng(3))
	var grown: Dictionary = EnemyGen.generate_champion(_team(), _rng(3), 1.1)
	var hp_plain: float = ((plain[&"team"] as Array)[0] as MonsterData).get_total_stats()[&"hp"] as float
	var hp_grown: float = ((grown[&"team"] as Array)[0] as MonsterData).get_total_stats()[&"hp"] as float
	assert_float(hp_grown).is_equal_approx(hp_plain * 1.1, 0.01)
	assert_float(grown[&"growth"] as float).is_equal_approx(1.1, 0.0001)
	assert_float(plain[&"growth"] as float).is_equal_approx(1.0, 0.0001)

func test_generate_for_battle_passes_growth_to_champion_only() -> void:
	var final_idx: int = Tuning.BATTLES_PER_RUN - 1
	var champ: Dictionary = EnemyGen.generate_for_battle(final_idx, _rng(1), 0, _team(), 1.2)
	assert_float(champ[&"growth"] as float).is_equal_approx(1.2, 0.0001)
	var none: Array[MonsterData] = []
	var splice: Dictionary = EnemyGen.generate_for_battle(final_idx, _rng(1), 0, none, 1.2)
	assert_bool(splice[&"champion"] as bool).is_false()
	assert_bool(splice.has(&"growth")).is_false()

func test_growth_label_text() -> void:
	assert_str(EnemyGen.champion_growth_text(1.0, 1)).is_empty()
	assert_str(EnemyGen.champion_growth_text(1.15, 4)).is_equal(" (+15% after 4 wins)")
