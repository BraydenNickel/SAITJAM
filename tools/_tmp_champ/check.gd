extends SceneTree
func _initialize() -> void:
	var game: Node = root.get_node("Game")
	game.champion_path = "user://tmp_champ_check.tres"
	ChampionStore.clear(game.champion_path)
	game.new_run()
	var mantis: MutationData = load("res://src/data/mutations/mantis_arm.tres")
	var raptor: MutationData = load("res://src/data/mutations/raptor_leg.tres")
	var fused: MutationData = FusionLogic.merge(mantis, load("res://src/data/mutations/mantis_arm.tres"))
	print("fused: ", fused, " ", fused.id if fused else "")
	var r0: MonsterData = game.run.roster[0]
	if fused: r0.apply_mutation(fused, &"ARM_L")
	game.run.battle_index = 4
	game.prepare_battle()
	print("no champ -> champion=", game.enemy_is_champion, " first=", game.enemy_team[0].display_name)
	game._save_champion()
	print("saved=", game.champion_saved, " beat=", game.beat_champion)
	print(FileAccess.get_file_as_string(game.champion_path).substr(0, 600))
	game.prepare_battle()
	print("champ -> champion=", game.enemy_is_champion, " names=", game.enemy_team.map(func(m): return m.display_name), " spots=", game.enemy_spots, " adapt=", game.enemy_adapt)
	for m: MonsterData in game.enemy_team:
		print("  ", m.display_name, " ", m.get_total_stats(), " slots=", m.slots.keys())
	var odds: Dictionary = BetOdds.estimate(game.build_lineup()["team"], game.build_lineup()["spots"], game.build_lineup()["roster_idx"], game.enemy_team, game.enemy_spots, game.battle_seed())
	print("odds victory=", odds.get(&"victory"))
	ChampionStore.clear(game.champion_path)
	quit()
