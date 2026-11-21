extends SceneTree
## Captures stage-5 screenshots of a battle with effects on screen. Run windowed:
## godot --path . -s res://production/qa/stage5_shots.gd

const OUT: String = "res://production/qa/evidence/stage5_battle_fx_%d.png"
## Frames to wait after the first effect appears before each capture.
const WAITS: Array[int] = [6, 45]
## Give up after this many frames without an effect.
const MAX_FRAMES: int = 900

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	game.prepare_battle()
	change_scene_to_file("res://src/battle/battle.tscn")
	for i: int in 4:
		await process_frame
	var battle: Node = current_scene
	var fx_layer: Node = battle.get_node("%FxLayer")
	var waited: int = 0
	while waited < MAX_FRAMES and _fx_count(fx_layer) == 0:
		await process_frame
		waited += 1
	print("first fx after frames: ", waited)
	for shot: int in WAITS.size():
		for i: int in WAITS[shot]:
			await process_frame
		# Wait for a frame that actually has an effect on it.
		var extra: int = 0
		while extra < MAX_FRAMES and _fx_count(fx_layer) == 0:
			await process_frame
			extra += 1
		root.get_texture().get_image().save_png(OUT % (shot + 1))
		print("saved shot ", shot + 1, " fx alive: ", _fx_count(fx_layer))
	quit()

func _fx_count(layer: Node) -> int:
	var count: int = 0
	for child: Node in layer.get_children():
		if child is PixelFxPlayer:
			count += 1
	return count
