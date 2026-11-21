extends SceneTree
## Shows TAIL / BACK mutations (plus a few ULTRA body overrides) on the front and
## side monster views, to check they read clearly against the human body.
## Run windowed:
## godot --path . -s res://production/qa/tail_back_shots.gd -- <suffix>
## Saves production/qa/evidence/tail_back_<suffix>.png (default suffix "after").

const OUT: String = "res://production/qa/evidence/tail_back_%s.png"
const DIR: String = "res://src/data/mutations/%s.tres"
const FRONT: PackedScene = preload("res://src/monster/monster_front.tscn")
const SIDE: PackedScene = preload("res://src/monster/monster_side.tscn")
const SIZE: Vector2i = Vector2i(1600, 900)
const COLS: int = 4
const VIEW_SCALE: float = 2.5
## Each entry: list of [mutation id, slot].
const LOADOUTS: Array = [
	[[&"scorpion_tail", &"TAIL"], [&"spore_sacs", &"BACK"]],
	[[&"whip_tail", &"TAIL"], [&"razor_wings", &"BACK"]],
	[[&"flail_tail", &"TAIL"], [&"dusk_wings", &"BACK"]],
	[[&"lamprey_tail", &"TAIL"], [&"nectar_sacs", &"BACK"], [&"crab_pincer", &"ARM_L"]],
	[[&"long_night_tail", &"TAIL"], [&"quill_ridge", &"BACK"]],
	[[&"primordial_ooze_mantle", &"BACK"], [&"brimstone_tail", &"TAIL"]],
	[[&"obsidian_colossus_heart", &"TORSO"], [&"dorsal_fin", &"BACK"], [&"ice_mace_tail", &"TAIL"]],
	[[&"seedpod_rattle", &"TAIL"], [&"barnacle_shell", &"BACK"]],
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var suffix: String = "after"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		suffix = args[0]
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.16, 0.18, 0.22)
	bg.size = Vector2(SIZE)
	vp.add_child(bg)
	var cell: Vector2 = Vector2(SIZE.x / COLS, SIZE.y / 2)
	for i: int in LOADOUTS.size():
		var mon: MonsterData = MonsterData.new()
		var names: PackedStringArray = []
		for pair: Array in LOADOUTS[i]:
			var mut: MutationData = load(DIR % pair[0]) as MutationData
			if mut == null:
				print("MISSING ", pair[0])
				continue
			print(pair[0], " applied: ", mon.apply_mutation(mut, pair[1]))
			names.append(String(pair[0]))
		var origin: Vector2 = Vector2((i % COLS) * cell.x + cell.x * 0.5, (i / COLS) * cell.y + cell.y * 0.55)
		for v: int in 2:
			var view: MonsterView = (FRONT if v == 0 else SIDE).instantiate() as MonsterView
			view.position = origin + Vector2(-95.0 if v == 0 else 95.0, 0.0)
			view.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
			vp.add_child(view)
			view.data = mon
		var label: Label = Label.new()
		label.text = ", ".join(names)
		label.position = Vector2((i % COLS) * cell.x + 8.0, (i / COLS) * cell.y + 6.0)
		vp.add_child(label)
	for f: int in 20:
		await process_frame
	vp.get_texture().get_image().save_png(OUT % suffix)
	print("saved ", OUT % suffix)
	quit()
