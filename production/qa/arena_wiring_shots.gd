extends SceneTree
## Screenshots for the main menu + arena wiring. Run windowed:
## godot --path . -s res://production/qa/arena_wiring_shots.gd

const OUT: String = "res://production/qa/evidence/wiring_%s.png"

func _initialize() -> void:
	_run.call_deferred()

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(OUT % name)
	print("saved ", name)

func _run() -> void:
	var game: Node = root.get_node("Game")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(1.0)
	_save("main_menu")
	game.new_run()
	for level: int in [1, 3, 5]:
		game.run.battle_index = level - 1
		game.enemy_team.clear()
		change_scene_to_file("res://src/screens/formation.tscn")
		await _wait(0.6)
		_save("formation_l%d" % level)
		game.prepare_battle()
		change_scene_to_file("res://src/battle/battle.tscn")
		await _wait(0.4)
		_save("battle_l%d_intro" % level)
		await _wait(4.5)
		var sim: Variant = current_scene.get("_sim")
		print("level %d sim time after intro: %.2f" % [level, sim.time if sim != null else -1.0])
		_save("battle_l%d_fight" % level)
	Engine.time_scale = 1.0
	quit()
