class_name RunSummaryLogTest
extends GdUnitTestSuite
## Run-end summary: RunSummary log entries, net-from-bets and the Codex diff,
## plus Game.complete_battle() appending to RunState.battle_log. Never touches
## the real user:// save files.

const HUMAN_PATH: String = "res://src/data/kinds/human.tres"
const TMP_CODEX: String = "user://test_run_summary_codex.json"
const TMP_CHAMP: String = "user://test_run_summary_champion.tres"

func _roster(names: Array[String]) -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for n: String in names:
		var m: MonsterData = (load(HUMAN_PATH) as MonsterData).clone()
		m.display_name = n
		out.append(m)
	return out

func test_make_entry_picks_top_damage_dealer() -> void:
	# Arrange
	var roster: Array[MonsterData] = _roster(["A", "B", "C"])
	var result: Dictionary = {&"damage_by_roster": {0: 40, 2: 95, 1: 60}}
	# Act
	var e: Dictionary = RunSummary.make_entry(2, true, 35, result, roster)
	# Assert
	assert_int(int(e[&"battle"])).is_equal(2)
	assert_bool(bool(e[&"won"])).is_true()
	assert_int(int(e[&"net"])).is_equal(35)
	assert_str(String(e[&"top_name"])).is_equal("C")
	assert_int(int(e[&"top_damage"])).is_equal(95)

func test_make_entry_tie_goes_to_lower_index() -> void:
	var roster: Array[MonsterData] = _roster(["A", "B"])
	var e: Dictionary = RunSummary.make_entry(1, false, -10,
		{&"damage_by_roster": {1: 50, 0: 50}}, roster)
	assert_str(String(e[&"top_name"])).is_equal("A")

func test_make_entry_no_damage_has_no_mvp() -> void:
	var roster: Array[MonsterData] = _roster(["A"])
	var e: Dictionary = RunSummary.make_entry(1, false, 0, {}, roster)
	assert_str(String(e[&"top_name"])).is_equal("")
	assert_int(int(e[&"top_damage"])).is_equal(0)

func test_net_from_bets_subtracts_stakes() -> void:
	var bets: Array[Dictionary] = [{&"stake": 20, &"mult": 2.0}, {&"stake": 15, &"mult": 3.0}]
	assert_int(RunSummary.net_from_bets(100, bets)).is_equal(65)
	assert_int(RunSummary.net_from_bets(0, [] as Array[Dictionary])).is_equal(0)

func test_new_codex_names_lists_only_new_entries() -> void:
	# Arrange
	var start: Dictionary = {"parts": {}, "titles": ["Old Title"], "mutations": ["mantis_arm"]}
	var now: Dictionary = {"parts": {}, "titles": ["Old Title", "New Beast"],
		"mutations": ["mantis_arm", "scorpion_tail", "no_such_mutation"]}
	var tail: MutationData = load("res://src/data/mutations/scorpion_tail.tres") as MutationData
	# Act
	var names: Array[String] = RunSummary.new_codex_names(start, now)
	# Assert: mutation display names first (id fallback), then titles.
	assert_array(names).is_equal([tail.display_name, "no_such_mutation", "New Beast"])

func test_new_codex_names_empty_when_nothing_new() -> void:
	var data: Dictionary = {"parts": {}, "titles": ["T"], "mutations": ["mantis_arm"]}
	assert_int(RunSummary.new_codex_names(data, data).size()).is_equal(0)
