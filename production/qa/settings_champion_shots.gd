extends SceneTree
## Windowed QA shots: hub settings with Restart/Quit buttons, and the battle-5
## bet screen against a saved champion (temp champion file, removed afterwards).

const TMP_CHAMP: String = "user://qa_tmp_champion.tres"
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
	game.new_run()
	change_scene_to_file("res://src/screens/hub.tscn")
	await _wait(10)
	var hub: Node = current_scene
	hub.get_node("%SettingsMenu").call("open")
	await _shot("settings_run_buttons.png")

	# Battle 5 against a champion made from this run's roster.
	ChampionStore.save_team(game.run.roster, TMP_CHAMP)
	game.champion_path = TMP_CHAMP
	game.run.battle_index = Tuning.BATTLES_PER_RUN - 1
	game.prepare_battle()
	print("champion enemy: ", game.enemy_is_champion)
	change_scene_to_file("res://src/screens/formation.tscn")
	await _shot("champion_formation.png")
	change_scene_to_file("res://src/screens/bet.tscn")
	await _shot("champion_bet.png")
	ChampionStore.clear(TMP_CHAMP)
	quit()
