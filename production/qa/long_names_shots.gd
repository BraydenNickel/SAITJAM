extends SceneTree
## Windowed QA shots: the longest mutation names and stat lines on every card
## type (shop, reward, lab inventory, incubator rows, codex).
## Usage: Godot --path . -s res://production/qa/long_names_shots.gd -- <tag>
## <tag> is "before" or "after" (file suffix); defaults to "after".

const OUT: String = "res://production/qa/evidence/"
const LONG_IDS: Array[String] = ["false_seraph_halo", "obsidian_colossus_heart",
	"amber_hive_crown", "void_moth_wings", "long_night_tail"]

var _tag: String = "after"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_tag = args[0]
	_run.call_deferred()

func _wait(n: int) -> void:
	for i: int in n:
		await process_frame

func _shot(screen: String) -> void:
	await _wait(40)
	var file: String = "long_names_%s_%s.png" % [_tag, screen]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file)

func _mut(id: String) -> Resource:
	return load("res://src/data/mutations/%s.tres" % id)

## A copy of a long-named mutation with every stat set (longest stat line).
func _all_stats(id: String) -> Resource:
	var m: Resource = _mut(id).duplicate()
	m.set(&"hp_mod", 120.0)
	m.set(&"atk_mod", -12.0)
	m.set(&"interval_mod", -0.25)
	m.set(&"defense_mod", 10.0)
	m.set(&"crit_mod", 0.15)
	return m

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.call("new_run")
	var run: Object = game.get("run")
	run.set("gold", 999)

	# --- Shop: five long-named mutation offers.
	var stock: Array[Dictionary] = []
	for i: int in LONG_IDS.size():
		var m: Resource = _all_stats(LONG_IDS[i]) if i % 2 == 0 else _mut(LONG_IDS[i])
		stock.append({&"kind": &"mutation", &"mutation": m, &"price": 88, &"sold": false})
	run.set("shop_stock", stock)
	run.set("shop_stock_battle", run.get("battle_index"))
	var inv: Array = run.get("inventory")
	inv.clear()
	for id: String in LONG_IDS:
		inv.append(_mut(id))
	var twin: Resource = _all_stats("false_seraph_halo")
	twin.set(&"display_name", "Twin Halo of the False Seraph")
	inv.append(twin)
	change_scene_to_file("res://src/screens/shop.tscn")
	await _shot("shop")

	# --- Lab inventory (named items).
	change_scene_to_file("res://src/screens/lab.tscn")
	await _shot("lab")

	# --- Reward: three free_mutation cards with the longest names.
	change_scene_to_file("res://src/screens/reward.tscn")
	await _wait(5)
	var cards: Array = current_scene.get("_cards")
	for i: int in cards.size():
		var m: Resource = _all_stats(LONG_IDS[i]) if i != 1 else _mut(LONG_IDS[i])
		var dn: String = String(m.get(&"display_name"))
		(cards[i] as Node).call("setup", {&"id": &"free_mutation", &"mutation": m,
			&"title": "Free %s" % dn,
			&"description": "Add %s (Ultra) to your inventory." % dn})
	await _shot("reward")

	# --- Incubator: two monsters sharing long-named parts (twin names).
	var roster: Array = run.get("roster")
	for k: int in mini(2, roster.size()):
		var mon: Resource = roster[k]
		mon.set(&"slots", {&"HEAD": _mut("false_seraph_halo"),
			&"TORSO": _all_stats("obsidian_colossus_heart") if k == 0 else _mut("obsidian_colossus_heart"),
			&"BACK": _mut("void_moth_wings"), &"TAIL": _mut("long_night_tail")})
	change_scene_to_file("res://src/screens/incubator.tscn")
	await _shot("incubator")

	# --- Codex: Ultra mutations + a long fused part name.
	change_scene_to_file("res://src/screens/codex.tscn")
	await _wait(5)
	current_scene.call("set_filters", -1, 3)
	await _shot("codex")
	var fusions_tab: Button = current_scene.get_node("%FusionsTab") as Button
	fusions_tab.button_pressed = true
	var grid: Node = current_scene.get_node("%PartGrid")
	(grid as CanvasItem).visible = true
	for n: String in ["Twin Halo of the False Seraph", "Apex Obsidian Colossus Heart",
			"Hybrid Crown of the Amber Hive"]:
		current_scene.call("_add_entry", grid, null, n, "TWIN", Color(0.5, 1, 0.5), true, n)
	await _shot("codex_fusions")
	quit()
