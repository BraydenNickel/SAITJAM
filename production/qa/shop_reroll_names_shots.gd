extends SceneTree
## Regression shots: shop names must re-fit after a reroll changes a slot's text
## without changing its size. Run windowed:
## godot --path . -s res://production/qa/shop_reroll_names_shots.gd

const OUT: String = "res://production/qa/evidence/shop_reroll_%d.png"
const LONG_IDS: Array[String] = ["false_seraph_halo", "obsidian_colossus_heart",
	"amber_hive_crown", "void_moth_wings", "long_night_tail"]

func _initialize() -> void:
	_run.call_deferred()

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.call("new_run")
	var run: Object = game.get("run")
	run.set("gold", 999)
	change_scene_to_file("res://src/screens/shop.tscn")
	await _wait(0.6)
	for round_i: int in 4:
		# Mix long and short names so each slot's text changes between rounds.
		var stock: Array[Dictionary] = []
		for i: int in 5:
			var long_name: bool = (i + round_i) % 2 == 0
			var path: String = "res://src/data/mutations/%s.tres" % (LONG_IDS[(i + round_i) % LONG_IDS.size()] if long_name else "mantis_arm")
			stock.append({&"kind": &"mutation", &"mutation": load(path), &"price": 10, &"sold": false})
		run.set("shop_stock", stock)
		current_scene.call("_refresh")
		await _wait(0.3)
		root.get_texture().get_image().save_png(OUT % round_i)
		print("saved round ", round_i)
	quit()
