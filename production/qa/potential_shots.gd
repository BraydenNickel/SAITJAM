extends SceneTree
## Screenshots for the POTENTIAL menu button and showcase. Run windowed:
## godot --path . -s res://production/qa/potential_shots.gd

const OUT: String = "res://production/qa/evidence/%s.png"

func _initialize() -> void:
	_run.call_deferred()

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(OUT % name)
	print("saved ", name)

func _run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(0.8)
	(current_scene.get_node("%Potential") as Control).grab_focus()
	await _wait(0.4)
	_save("menu_potential")
	change_scene_to_file("res://src/screens/potential.tscn")
	await _wait(5.3)
	_save("potential_build")
	await _wait(5.5)
	_save("potential_ultimate")
	quit()
