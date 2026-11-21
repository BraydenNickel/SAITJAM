extends SceneTree
## Captures stage-3 screenshots. Run windowed:
## godot --path . -s res://production/qa/stage3_shots.gd

const OUT: String = "res://production/qa/evidence/stage3_%s.png"

func _initialize() -> void:
	_run.call_deferred()

func _game() -> Node:
	return root.get_node("Game")

func _shot(scene_path: String, name: String, frames: int = 12) -> Node:
	change_scene_to_file(scene_path)
	for i: int in frames:
		await process_frame
	root.get_texture().get_image().save_png(OUT % name)
	print("saved ", name)
	return current_scene

func _run() -> void:
	var game: Node = _game()
	game.new_run()
	var run: RunState = game.run
	var muts: Array[MutationData] = EnemyGen.all_mutations()
	for i: int in mini(4, muts.size()):
		run.inventory.append(muts[i])
	run.stabilizers = 3
	run.lucky_gene = true
	run.insurance = false
	run.gold = 80
	# Lab: select first subject + first inventory item that fits.
	var lab: Node = await _shot("res://src/screens/lab.tscn", "lab_empty")
	var subject: int = 0
	for inv: int in run.inventory.size():
		if not run.roster[subject].slots_for(run.inventory[inv]).is_empty():
			lab._on_inventory_pressed(inv)
			break
	lab._stab_spin.value = 1
	for i: int in 6:
		await process_frame
	root.get_texture().get_image().save_png(OUT % "lab")
	print("saved lab")
	# Force a mush: drop chance by making the subject very unstable, no buffs.
	run.lucky_gene = false
	run.roster[0].instability = 100.0
	lab._stab_spin.value = 0
	lab._refresh()
	var rng: RandomNumberGenerator = game.rng
	rng.seed = 1  # chance is clamped to MIN_SUCCESS; roll 1-100 almost surely fails
	lab._on_confirm_pressed()
	for i: int in 12:
		await process_frame
	root.get_texture().get_image().save_png(OUT % "lab_mush")
	print("saved lab_mush")
	# Purge mode on Subject 02 (has mutations).
	lab._on_result_ok_pressed()
	lab._set_mode(1)
	lab._on_subject_pressed(1)
	lab._on_slot_toggled(true, &"ARM_R")
	for i: int in 6:
		await process_frame
	root.get_texture().get_image().save_png(OUT % "lab_purge")
	print("saved lab_purge")
	await _shot("res://src/screens/shop.tscn", "shop")
	await _shot("res://src/screens/reward.tscn", "reward")
	await _shot("res://src/screens/hub.tscn", "hub")
	await _shot("res://src/screens/roster.tscn", "roster_mush")
	quit()
