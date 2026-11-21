extends SceneTree
## Captures the UI-pass screenshots (hub, bet, settings, title). Run windowed:
## godot --path . -s res://production/qa/ui_pass_shots_a.gd

const OUT: String = "res://production/qa/evidence/ui_%s.png"

func _initialize() -> void:
	_run.call_deferred()

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(OUT % name)
	print("saved ", name)

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _shot(scene_path: String, name: String, frames: int = 12) -> Node:
	change_scene_to_file(scene_path)
	await _frames(frames)
	_save(name)
	return current_scene

func _run() -> void:
	var game: Node = root.get_node("Game")
	await _shot("res://src/main.tscn", "title")
	game.new_run()
	var run: RunState = game.run
	run.gold = 80
	run.stabilizers = 2
	# A few mutations so odds vary.
	var muts: Array[MutationData] = EnemyGen.all_mutations()
	var applied: int = 0
	for m: MutationData in muts:
		if applied >= 3:
			break
		var slots: Array[StringName] = run.roster[0].slots_for(m)
		if not slots.is_empty():
			run.roster[0].apply_mutation(m, slots[0])
			applied += 1
	run.roster[0].instability = 35.0
	run.roster[1].instability = 20.0
	var hub: Node = await _shot("res://src/screens/hub.tscn", "hub")
	hub.get_node("%SettingsMenu").open()
	await _frames(6)
	_save("settings")
	game.prepare_battle()
	var bet: Node = await _shot("res://src/screens/bet.tscn", "bet", 40)
	var picked: int = 0
	for row: BetRow in bet._rows:
		if picked < 2 and row.is_available():
			row.set_active(true)
			picked += 1
	await _frames(6)
	_save("bet_two_picked")
	quit()
