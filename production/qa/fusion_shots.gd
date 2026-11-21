extends SceneTree
## Captures the fusion screens: Incubator preview and result, Lab splice preview
## (signature and apex with keep toggles), Codex, and an Apex part with its glow.
## Run windowed:
## godot --path . -s res://production/qa/fusion_shots.gd
##
## The screens save discoveries to user://codex.json. This script backs that
## file up first and restores it at the end, so the player's real Codex is
## never changed by a QA run.

const OUT: String = "res://production/qa/evidence/fusion_%s.png"
const DIR: String = "res://src/data/mutations/%s.tres"
const INCUBATOR: String = "res://src/screens/incubator.tscn"
const LAB: String = "res://src/screens/lab.tscn"
const CODEX: String = "res://src/screens/codex.tscn"
const WAIT_FRAMES: int = 40
## Parent loadouts: HEAD and ARM_L make signatures, TORSO a twin, BACK a hybrid,
## TAIL and LEG_L are carried over.
const PARENT_A: Array = [[&"frost_crest", &"HEAD"], [&"mantis_arm", &"ARM_L"],
	[&"bone_plating", &"TORSO"], [&"spore_sacs", &"BACK"], [&"scorpion_tail", &"TAIL"]]
const PARENT_B: Array = [[&"snapping_beak", &"HEAD"], [&"quartz_knuckle", &"ARM_L"],
	[&"bone_plating", &"TORSO"], [&"razor_wings", &"BACK"], [&"raptor_leg", &"LEG_L"]]
## Lab preview panel, cropped and enlarged for the glow shot.
const GLOW_CROP: Rect2i = Rect2i(174, 42, 220, 158)
const GLOW_ZOOM: int = 3

var _game: Node

func _initialize() -> void:
	_run.call_deferred()

func _mut(id: StringName) -> MutationData:
	var m: MutationData = load(DIR % id) as MutationData
	if m == null:
		print("MISSING ", id)
	return m

func _equip(mon: MonsterData, loadout: Array) -> void:
	mon.slots.clear()
	mon.mushed = false
	for pair: Array in loadout:
		print(pair[0], " applied: ", mon.apply_mutation(_mut(pair[0]), pair[1]))

func _open(scene: String, frames: int = WAIT_FRAMES) -> Node:
	change_scene_to_file(scene)
	for i: int in frames:
		await process_frame
	return current_scene

func _shot(name: String) -> void:
	for i: int in 4:
		await process_frame
	root.get_texture().get_image().save_png(OUT % name)
	print("saved ", OUT % name)

func _run() -> void:
	var codex_path: String = CodexStore.DEFAULT_PATH
	var had_codex: bool = FileAccess.file_exists(codex_path)
	var codex_backup: String = FileAccess.get_file_as_string(codex_path) if had_codex else ""
	_game = root.get_node("Game")
	# No hover tooltips from wherever the mouse happens to be.
	root.gui_disable_input = true

	# 1. Incubator preview.
	_game.new_run()
	_game.run.gold = 120
	_game.run.stabilizers = 2
	_equip(_game.run.roster[0], PARENT_A)
	_equip(_game.run.roster[1], PARENT_B)
	var screen: Node = await _open(INCUBATOR)
	await _shot("incubator_preview")

	# 2. Incubator result: two stabilizers and a seed whose first roll succeeds.
	screen.get_node("%StabSpin").value = 2
	var chance: int = FusionLogic.incubate_chance(_game.run, _game.run.roster[0],
		_game.run.roster[1], 2)
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	for s: int in 1000:
		probe.seed = s
		if probe.randi_range(1, 100) <= chance:
			_game.rng.seed = s
			break
	screen.call(&"_on_confirm_pressed")
	for i: int in 20:
		await process_frame
	await _shot("incubator_result")

	# 3. Codex, with what the incubation just discovered.
	await _open(CODEX)
	await _shot("codex")
	await _open("res://src/screens/hub.tscn")
	await _shot("hub")
	await _open("res://src/main.tscn")
	await _shot("title")

	# 4. Lab splice preview: Quartz Knuckle onto a Mantis Arm (signature).
	_game.new_run()
	_equip(_game.run.roster[0], [[&"mantis_arm", &"ARM_L"], [&"frost_crest", &"HEAD"]])
	_game.run.roster[0].slots[&"ARM_R"] = FusionLogic.merge(_mut(&"mantis_arm"),
		_mut(&"toxin_claw"))
	_game.run.inventory.assign([_mut(&"quartz_knuckle"), _mut(&"cinder_fist"),
		_mut(&"snapping_beak")])
	screen = await _open(LAB)
	screen.call(&"_on_inventory_pressed", 0)
	screen.call(&"_on_slot_toggled", true, &"ARM_L")
	await _shot("lab_splice")

	# 5. Lab splice into a hybrid: an Apex with ability keep toggles.
	screen.call(&"_on_inventory_pressed", 1)
	screen.call(&"_on_slot_toggled", true, &"ARM_R")
	await _shot("lab_splice_apex")

	# 6. Apex glow: a monster wearing two Apex parts, plus an enlarged crop.
	_game.new_run()
	var hybrid_arm: MutationData = FusionLogic.merge(_mut(&"mantis_arm"), _mut(&"toxin_claw"))
	var hybrid_head: MutationData = FusionLogic.merge(_mut(&"frost_crest"), _mut(&"snapping_beak"))
	var mon: MonsterData = _game.run.roster[0]
	mon.slots.clear()
	mon.slots[&"ARM_L"] = FusionLogic.merge(hybrid_arm, _mut(&"cinder_fist"))
	mon.slots[&"ARM_R"] = hybrid_arm
	mon.slots[&"HEAD"] = FusionLogic.merge(hybrid_head, _mut(&"ember_horns"))
	_game.run.inventory.clear()
	await _open(LAB)
	await _shot("apex_glow")
	var crop: Image = root.get_texture().get_image().get_region(GLOW_CROP)
	crop.resize(GLOW_CROP.size.x * GLOW_ZOOM, GLOW_CROP.size.y * GLOW_ZOOM,
		Image.INTERPOLATE_NEAREST)
	crop.save_png(OUT % "apex_glow_3x")

	# Put the player's real Codex back.
	if had_codex:
		var file: FileAccess = FileAccess.open(codex_path, FileAccess.WRITE)
		file.store_string(codex_backup)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(codex_path))
	print("codex restored (existed before: ", had_codex, ")")
	quit()
