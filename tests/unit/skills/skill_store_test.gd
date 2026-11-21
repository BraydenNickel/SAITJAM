class_name SkillStoreTest
extends GdUnitTestSuite
## Unit tests for SkillStore (persistent skill points and ranks;
## docs/superpowers/specs/2026-11-21-skill-points-design.md). Uses a temp file so
## the player's real user://skills.json is never touched.

const SKILLS_PATH: String = "user://test_skills_store.json"

func before_test() -> void:
	_remove_file()

func after_test() -> void:
	_remove_file()

func _remove_file() -> void:
	if FileAccess.file_exists(SKILLS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SKILLS_PATH))

func test_missing_file_loads_empty() -> void:
	var data: Dictionary = SkillStore.load_data(SKILLS_PATH)
	assert_int(int(data["points"])).is_equal(0)
	assert_dict(data["ranks"] as Dictionary).is_empty()
	assert_int(SkillStore.points(SKILLS_PATH)).is_equal(0)
	assert_dict(SkillStore.ranks(SKILLS_PATH)).is_empty()

func test_corrupt_file_loads_empty() -> void:
	var file: FileAccess = FileAccess.open(SKILLS_PATH, FileAccess.WRITE)
	file.store_string("{not json at all")
	file.close()
	var data: Dictionary = SkillStore.load_data(SKILLS_PATH)
	assert_int(int(data["points"])).is_equal(0)
	assert_dict(data["ranks"] as Dictionary).is_empty()

func test_buy_spends_rising_cost() -> void:
	SkillStore.add_points(3, SKILLS_PATH)
	assert_int(SkillStore.next_cost(&"seed_money", SKILLS_PATH)).is_equal(1)
	assert_bool(SkillStore.buy(&"seed_money", SKILLS_PATH)).is_true()
	assert_int(SkillStore.next_cost(&"seed_money", SKILLS_PATH)).is_equal(2)
	assert_bool(SkillStore.buy(&"seed_money", SKILLS_PATH)).is_true()
	assert_int(SkillStore.rank(&"seed_money", SKILLS_PATH)).is_equal(2)
	assert_int(SkillStore.points(SKILLS_PATH)).is_equal(0)
	assert_int(SkillStore.next_cost(&"seed_money", SKILLS_PATH)).is_equal(3)

func test_buy_without_points_fails() -> void:
	assert_bool(SkillStore.can_buy(&"bounty", SKILLS_PATH)).is_false()
	assert_bool(SkillStore.buy(&"bounty", SKILLS_PATH)).is_false()
	assert_int(SkillStore.rank(&"bounty", SKILLS_PATH)).is_equal(0)
	assert_int(SkillStore.points(SKILLS_PATH)).is_equal(0)

func test_buy_maxed_fails() -> void:
	SkillStore.add_points(10, SKILLS_PATH)
	assert_bool(SkillStore.buy(&"stockpile", SKILLS_PATH)).is_true()
	assert_bool(SkillStore.buy(&"stockpile", SKILLS_PATH)).is_true()
	var before: int = SkillStore.points(SKILLS_PATH)
	assert_int(SkillStore.next_cost(&"stockpile", SKILLS_PATH)).is_equal(0)
	assert_bool(SkillStore.can_buy(&"stockpile", SKILLS_PATH)).is_false()
	assert_bool(SkillStore.buy(&"stockpile", SKILLS_PATH)).is_false()
	assert_int(SkillStore.rank(&"stockpile", SKILLS_PATH)).is_equal(2)
	assert_int(SkillStore.points(SKILLS_PATH)).is_equal(before)

func test_buy_unknown_skill_fails() -> void:
	SkillStore.add_points(5, SKILLS_PATH)
	assert_bool(SkillStore.buy(&"no_such_skill", SKILLS_PATH)).is_false()
	assert_int(SkillStore.points(SKILLS_PATH)).is_equal(5)

func test_refund_all_returns_spent() -> void:
	SkillStore.add_points(3, SKILLS_PATH)
	SkillStore.buy(&"seed_money", SKILLS_PATH)
	SkillStore.buy(&"seed_money", SKILLS_PATH)
	var refunded: int = SkillStore.refund_all(SKILLS_PATH)
	assert_int(refunded).is_equal(3)
	assert_int(SkillStore.points(SKILLS_PATH)).is_equal(3)
	assert_dict(SkillStore.ranks(SKILLS_PATH)).is_empty()

func test_ranks_use_string_name_keys() -> void:
	SkillStore.add_points(1, SKILLS_PATH)
	SkillStore.buy(&"bounty", SKILLS_PATH)
	var r: Dictionary = SkillStore.ranks(SKILLS_PATH)
	assert_bool(r.has(&"bounty")).is_true()
	assert_int(typeof(r.keys()[0])).is_equal(TYPE_STRING_NAME)
	assert_int(int(r[&"bounty"])).is_equal(1)
