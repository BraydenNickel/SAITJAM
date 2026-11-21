extends SceneTree
## Windowed QA shot: run-end screen with a fake 3-battle log (2 wins, then a
## loss) and fake "New this run" Codex entries (temp codex file, removed after).

const TMP_CODEX: String = "user://qa_tmp_run_summary_codex.json"
const OUT: String = "res://production/qa/evidence/"

func _initialize() -> void:
	_run.call_deferred()

func _wait(n: int) -> void:
	for i: int in n:
		await process_frame

func _shot(file: String) -> void:
	await _wait(30)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file)

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.codex_path = TMP_CODEX
	CodexStore.save_codex({"parts": {}, "titles": [], "mutations": ["mantis_arm"]}, TMP_CODEX)
	game.new_run()
	var roster: Array = game.run.roster
	var log: Array[Dictionary] = []
	log.append({&"battle": 1, &"won": true, &"net": 45,
		&"top_name": roster[1].display_name, &"top_damage": 212})
	log.append({&"battle": 2, &"won": true, &"net": -15,
		&"top_name": roster[0].display_name, &"top_damage": 158})
	log.append({&"battle": 3, &"won": false, &"net": -60,
		&"top_name": roster[0].display_name, &"top_damage": 97})
	game.run.battle_log = log
	game.battles_cleared = 2
	game.run_victory = false
	CodexStore.save_codex({"parts": {}, "titles": ["Gutripper Prime"],
		"mutations": ["mantis_arm", "scorpion_tail", "leech_maw", "bone_plating"]}, TMP_CODEX)
	change_scene_to_file("res://src/screens/run_end.tscn")
	await _shot("run_summary.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_CODEX))
	quit()
