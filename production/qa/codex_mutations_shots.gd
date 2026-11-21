extends SceneTree
## Captures the Codex Mutations tab with a filter applied (Part: Arm, Rarity: All)
## after marking a few mutations as obtained. Run windowed:
## godot --path . -s res://production/qa/codex_mutations_shots.gd
##
## Backs up user://codex.json first and restores it at the end, so the player's
## real Codex is never changed by a QA run.

const OUT: String = "res://production/qa/evidence/codex_mutations%s.png"
const CODEX: String = "res://src/screens/codex.tscn"
const WAIT_FRAMES: int = 30
const OWNED_IDS: Array[StringName] = [&"mantis_arm", &"bone_plating", &"leech_maw",
	&"raptor_leg", &"scorpion_tail", &"spore_sacs", &"quartz_knuckle", &"toxin_claw",
	&"cinder_fist"]

func _initialize() -> void:
	_run.call_deferred()

func _shot(suffix: String) -> void:
	for i: int in 6:
		await process_frame
	root.get_texture().get_image().save_png(OUT % suffix)
	print("saved ", OUT % suffix)

func _run() -> void:
	var codex_path: String = CodexStore.DEFAULT_PATH
	var had_codex: bool = FileAccess.file_exists(codex_path)
	var backup: String = FileAccess.get_file_as_string(codex_path) if had_codex else ""
	root.gui_disable_input = true
	for id: StringName in OWNED_IDS:
		CodexStore.record_mutation(id)

	change_scene_to_file(CODEX)
	for i: int in WAIT_FRAMES:
		await process_frame
	var screen: Node = current_scene
	screen.call(&"set_filters", MutationData.SocketType.ARM, -1)
	await _shot("")
	screen.call(&"set_filters", -1, -1)
	await _shot("_all")

	if had_codex:
		var file: FileAccess = FileAccess.open(codex_path, FileAccess.WRITE)
		file.store_string(backup)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(codex_path))
	print("codex restored (existed before: ", had_codex, ")")
	quit()
