extends SceneTree
## Headless flow check: battle win -> reward screen -> pick -> hub; shop buy/reroll.
## Run: godot --headless --path . -s res://production/qa/stage3_flow_check.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	game.complete_battle(true, 10)
	for i: int in 5:
		await process_frame
	print("after win: ", current_scene.name, " battle_index=", game.run.battle_index)
	var row: Node = current_scene.get_node("%CardRow")
	print("options: ", row.get_child_count())
	(row.get_child(0) as RewardCard).pressed.emit()
	for i: int in 5:
		await process_frame
	print("after pick: ", current_scene.name, " gold=", game.run.gold, " stabs=", game.run.stabilizers,
		" inv=", game.run.inventory.size(), " lucky=", game.run.lucky_gene)
	game.go_to(&"shop")
	for i: int in 5:
		await process_frame
	var shop: Node = current_scene
	var g0: int = game.run.gold
	shop._on_buy_pressed(1)
	shop._on_reroll_pressed()
	print("shop: gold ", g0, " -> ", game.run.gold, " inv=", game.run.inventory.size(),
		" reroll label=", (shop.get_node("%RerollButton") as Button).text)
	quit()
