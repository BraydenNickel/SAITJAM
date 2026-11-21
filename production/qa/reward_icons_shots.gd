extends SceneTree
## Windowed QA shots: reward cards (settled + mid-hover), lab icons, shop icons.

const OUT: String = "res://production/qa/evidence/"

func _initialize() -> void:
	_run.call_deferred()

func _wait(n: int) -> void:
	for i: int in n:
		await process_frame

func _shot(file: String, frames: int = 50) -> void:
	await _wait(frames)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file)

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	game.run.battle_index = 1
	game.run.stabilizers = 3
	game.run.lucky_gene = true
	game.run.insurance = true
	game.run.catalyst = true
	change_scene_to_file("res://src/screens/reward.tscn")
	await _shot("reward_cards.png")
	# Hover the second card (focus drives the same lift as the mouse).
	var row: Node = current_scene.get_node("%CardRow")
	if row.get_child_count() > 1:
		row.get_child(1).call("focus")
	await _shot("reward_cards_hover.png", 20)
	change_scene_to_file("res://src/screens/lab.tscn")
	await _shot("lab_icons.png")
	change_scene_to_file("res://src/screens/shop.tscn")
	await _shot("shop_icons.png")
	quit()
