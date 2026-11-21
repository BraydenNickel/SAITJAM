extends SceneTree
## Captures the bet screen with an adaptive-scaling bonus > 0. Run windowed:
## "C:/Godot/Godot_v4.7.2-stable_win64.exe" --path . -s res://production/qa/stage3_adapt_shot.gd

const OUT: String = "res://production/qa/evidence/stage3_bet_adapt.png"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	var run: RunState = game.run
	# A strong lab: fill free slots on both subjects so power beats ADAPT_EXPECTED[0].
	for mon: MonsterData in run.roster:
		for mut: MutationData in EnemyGen.all_mutations():
			var free: Array[StringName] = mon.slots_for(mut)
			if not free.is_empty():
				mon.apply_mutation(mut, free[0])
	run.gold = 60
	game.prepare_battle()
	print("power=", EnemyGen.player_power(run.roster), " adapt=", game.enemy_adapt)
	change_scene_to_file("res://src/screens/bet.tscn")
	for i: int in 30:
		await process_frame
	root.get_texture().get_image().save_png(OUT)
	print("saved ", OUT)
	quit()
