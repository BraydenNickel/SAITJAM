extends SceneTree
## Windowed QA shots of the first-time hint banners on Hub, Bet and Lab.
## Uses a temp hints file (HintStore.path) so every banner shows and the real
## user://hints.cfg is untouched; the temp file is removed afterwards.

const TMP_HINTS: String = "user://qa_tmp_hints.cfg"
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
	HintStore.path = TMP_HINTS
	HintStore.clear()
	var game: Node = root.get_node("Game")
	game.new_run()
	change_scene_to_file("res://src/screens/hub.tscn")
	await _shot("hints_hub.png")
	game.prepare_battle()
	change_scene_to_file("res://src/screens/bet.tscn")
	await _shot("hints_bet.png")
	change_scene_to_file("res://src/screens/lab.tscn")
	await _shot("hints_lab.png")
	# Dismiss the lab banner and confirm it stays hidden on the next visit.
	current_scene.get_node("HintBanner").call("dismiss")
	print("lab seen after dismiss: ", HintStore.is_seen(&"lab"))
	change_scene_to_file("res://src/screens/lab.tscn")
	await _wait(10)
	print("lab banner visible on revisit: ", current_scene.get_node("HintBanner").visible)
	HintStore.clear()
	quit()
