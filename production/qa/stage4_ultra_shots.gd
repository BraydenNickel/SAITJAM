extends SceneTree
## Captures ULTRA body transformations (aura, scaled body, BACK / TAIL parts) in
## the roster, formation, lab and battle screens, for two loadouts so four ultra
## styles appear. Run windowed:
## godot --path . -s res://production/qa/stage4_ultra_shots.gd

const OUT: String = "res://production/qa/evidence/stage4_ultra_%s.png"
const DIR: String = "res://src/data/mutations/%s.tres"
## File suffix -> roster index -> [mutation id, slot] installed before the shots.
## The first loadout keeps the original file names (no suffix).
const LOADOUTS: Dictionary = {
	"": [
		[[&"obsidian_colossus_heart", &"TORSO"], [&"ember_horns", &"HEAD"],
			[&"brimstone_tail", &"TAIL"], [&"razor_wings", &"BACK"]],
		[[&"void_moth_wings", &"BACK"], [&"scorpion_tail", &"TAIL"]],
	],
	"_b": [
		[[&"primordial_ooze_mantle", &"BACK"], [&"whip_tail", &"TAIL"]],
		[[&"amber_hive_crown", &"HEAD"], [&"dusk_wings", &"BACK"], [&"flail_tail", &"TAIL"]],
	],
}
## Screen name -> [scene path, frames to wait before the shot].
const SCREENS: Dictionary = {
	"hub": ["res://src/screens/hub.tscn", 40],
	"roster": ["res://src/screens/roster.tscn", 40],
	"formation": ["res://src/screens/formation.tscn", 40],
	"lab": ["res://src/screens/lab.tscn", 40],
	"battle": ["res://src/battle/battle.tscn", 100],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	for suffix: String in LOADOUTS:
		var loadout: Array = LOADOUTS[suffix]
		for i: int in loadout.size():
			var mon: MonsterData = game.run.roster[i]
			mon.slots.clear()
			for pair: Array in loadout[i]:
				var mut: MutationData = load(DIR % pair[0]) as MutationData
				if mut == null:
					print("MISSING ", pair[0])
					continue
				print(pair[0], " applied: ", mon.apply_mutation(mut, pair[1]))
			mon.mushed = false
		game.prepare_battle()
		for screen: String in SCREENS:
			change_scene_to_file(SCREENS[screen][0])
			for i: int in int(SCREENS[screen][1]):
				await process_frame
			root.get_texture().get_image().save_png(OUT % (screen + suffix))
	quit()
