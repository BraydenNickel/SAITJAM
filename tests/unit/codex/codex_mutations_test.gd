class_name CodexMutationsTest
extends GdUnitTestSuite
## Unit tests for the obtained-mutation list in CodexStore. Uses a temp file so
## the player's real user://codex.json is never touched.

const CODEX_PATH: String = "user://test_codex_mutations.json"

func before_test() -> void:
	_remove_file()

func after_test() -> void:
	_remove_file()

func _remove_file() -> void:
	if FileAccess.file_exists(CODEX_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CODEX_PATH))

func test_load_missing_file_has_empty_mutation_list() -> void:
	var data: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_array(data[CodexStore.KEY_MUTATIONS] as Array).is_empty()
	assert_bool(CodexStore.has_mutation(data, &"mantis_arm")).is_false()

func test_record_mutation_first_time_returns_true_and_persists() -> void:
	var fresh: bool = CodexStore.record_mutation(&"mantis_arm", CODEX_PATH)
	var data: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_bool(fresh).is_true()
	assert_bool(CodexStore.has_mutation(data, &"mantis_arm")).is_true()
	assert_bool(CodexStore.has_mutation(data, &"bone_plating")).is_false()

func test_record_mutation_twice_returns_false_and_stores_once() -> void:
	CodexStore.record_mutation(&"mantis_arm", CODEX_PATH)
	var again: bool = CodexStore.record_mutation(&"mantis_arm", CODEX_PATH)
	var data: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_bool(again).is_false()
	assert_array(data[CodexStore.KEY_MUTATIONS] as Array).contains_exactly(["mantis_arm"])

func test_record_empty_id_is_ignored() -> void:
	assert_bool(CodexStore.record_mutation(&"", CODEX_PATH)).is_false()
	assert_bool(FileAccess.file_exists(CODEX_PATH)).is_false()

func test_record_mutation_keeps_fusion_parts_and_titles() -> void:
	CodexStore.record([{&"kind": &"title", &"key": "Ember-Bone Chimera"},
		{&"kind": &"part", &"key": "a+b", &"name": "Ab", &"signature": false}], CODEX_PATH)
	CodexStore.record_mutation(&"leech_maw", CODEX_PATH)
	var data: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_bool(CodexStore.has_part(data, "a+b")).is_true()
	assert_array(data[CodexStore.KEY_TITLES] as Array).contains_exactly(["Ember-Bone Chimera"])
	assert_bool(CodexStore.has_mutation(data, &"leech_maw")).is_true()

func test_old_file_without_mutations_key_loads() -> void:
	CodexStore.save_codex({"parts": {"a+b": {"name": "Ab", "signature": false}},
		"titles": []}, CODEX_PATH)
	var data: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_array(data[CodexStore.KEY_MUTATIONS] as Array).is_empty()
	assert_bool(CodexStore.has_part(data, "a+b")).is_true()

func test_fusion_record_preserves_obtained_mutations() -> void:
	CodexStore.record_mutation(&"raptor_leg", CODEX_PATH)
	CodexStore.record([{&"kind": &"part", &"key": "c+d", &"name": "Cd"}], CODEX_PATH)
	var data: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_bool(CodexStore.has_mutation(data, &"raptor_leg")).is_true()
