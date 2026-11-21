extends SceneTree
## Screenshots for the battle damage counter and the pause/settings menu. Run windowed:
## godot --path . -s res://production/qa/damage_pause_shots.gd

const OUT: String = "res://production/qa/evidence/battle_%s.png"

func _initialize() -> void:
	_run.call_deferred()

func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(OUT % name)
	print("saved ", name)

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	game.prepare_battle()
	change_scene_to_file("res://src/battle/battle.tscn")
	await _wait(9.0)
	_save("damage_counter")
	var sim: Variant = current_scene.get("_sim")
	var t_before: float = sim.time
	current_scene.call("_pause")
	await _wait(1.0)
	print("paused=", paused, " sim time frozen: ", is_equal_approx(sim.time, t_before))
	_save("paused_menu")
	current_scene.get_node("%SettingsMenu").call("close")
	await _wait(0.5)
	print("unpaused=", not paused, " sim advanced: ", sim.time > t_before)
	quit()
