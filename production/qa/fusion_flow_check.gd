extends SceneTree
## Flow check for the fusion screens. Drives the real buttons / handlers with
## seeded rolls and prints one PASS/FAIL line per assertion:
## (a) Incubator failure with a third monster alive, (b) failure that ends the
## run, (c) CHOOSE row, (d) keep toggles, (e) Lab splice + second splice to an
## Apex, (f) hub -> formation -> bet -> battle with the chimera, (g) what a Lab
## failure on the last living monster leaves behind, (h) Lab keep row with a
## six-row chance breakdown.
## Run windowed (it saves screenshots):
## godot --path . -s res://production/qa/fusion_flow_check.gd
##
## user://codex.json is backed up first and restored at the end.

const OUT: String = "res://production/qa/evidence/fusion_%s.png"
const DIR: String = "res://src/data/mutations/%s.tres"
const INCUBATOR: String = "res://src/screens/incubator.tscn"
const LAB: String = "res://src/screens/lab.tscn"
const HUB: String = "res://src/screens/hub.tscn"
const FORMATION: String = "res://src/screens/formation.tscn"
const WAIT_FRAMES: int = 30
const BATTLE_FRAMES: int = 200
const PARENT_A: Array = [[&"frost_crest", &"HEAD"], [&"mantis_arm", &"ARM_L"],
	[&"bone_plating", &"TORSO"]]
const PARENT_B: Array = [[&"snapping_beak", &"HEAD"], [&"quartz_knuckle", &"ARM_L"],
	[&"raptor_leg", &"LEG_L"]]

var _game: Node
var _fails: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok:
		_fails += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, str(detail)])

func _mut(id: StringName) -> MutationData:
	return load(DIR % id) as MutationData

func _equip(mon: MonsterData, loadout: Array) -> void:
	mon.slots.clear()
	mon.mushed = false
	for pair: Array in loadout:
		mon.apply_mutation(_mut(pair[0]), pair[1])

func _wait(frames: int = WAIT_FRAMES) -> void:
	for i: int in frames:
		await process_frame

func _open(scene: String) -> Node:
	change_scene_to_file(scene)
	await _wait()
	return current_scene

func _shot(name: String) -> void:
	await _wait(4)
	root.get_texture().get_image().save_png(OUT % name)

## Seeds Game.rng so its next 1..100 roll succeeds / fails against `chance`.
func _force(chance: int, success: bool) -> bool:
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	for s: int in 5000:
		probe.seed = s
		if (probe.randi_range(1, 100) <= chance) == success:
			_game.rng.seed = s
			return true
	return false

func _press(node: Node) -> void:
	(node as BaseButton).pressed.emit()

func _row(screen: Node, slot: StringName) -> FusionSlotRow:
	for child: Node in screen.get_node("%SlotList").get_children():
		if (child as FusionSlotRow).slot == slot and not child.is_queued_for_deletion():
			return child as FusionSlotRow
	return null

func _ability_ids(list: Array) -> Array:
	var ids: Array = []
	for ab: Variant in list:
		ids.append((ab as AbilityData).get_id())
	return ids

func _formation_valid() -> bool:
	for value: Variant in _game.run.formation.values():
		var idx: int = int(value)
		if idx < 0 or idx >= _game.run.roster.size() or _game.run.roster[idx].mushed:
			return false
	return true

func _run() -> void:
	var codex_path: String = CodexStore.DEFAULT_PATH
	var had_codex: bool = FileAccess.file_exists(codex_path)
	var codex_backup: String = FileAccess.get_file_as_string(codex_path) if had_codex else ""
	_game = root.get_node("Game")
	root.gui_disable_input = true
	await _path_a()
	await _path_b()
	await _path_cd_f()
	await _path_e()
	await _path_g()
	await _path_h()
	if had_codex:
		var file: FileAccess = FileAccess.open(codex_path, FileAccess.WRITE)
		file.store_string(codex_backup)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(codex_path))
	print("codex restored; FAIL count = ", _fails)
	quit()

func _fail_setup(extra_monster: bool) -> Node:
	_game.new_run()
	_game.run.gold = 100
	_equip(_game.run.roster[0], PARENT_A)
	_equip(_game.run.roster[1], PARENT_B)
	_game.run.roster[0].instability = 100.0
	_game.run.roster[1].instability = 100.0
	if extra_monster:
		ShopLogic.add_human(_game.run)
	var screen: Node = await _open(INCUBATOR)
	var chance: int = FusionLogic.incubate_chance(_game.run, _game.run.roster[0],
		_game.run.roster[1], 0)
	_check("setup: failing seed found (chance %d)" % chance, _force(chance, false))
	return screen

func _path_a() -> void:
	print("--- (a) Incubator failure, third monster alive")
	var screen: Node = await _fail_setup(true)
	_check("a: no run-over warning with a third monster",
		not (screen.get_node("%WarningLabel") as Control).visible)
	_press(screen.get_node("%ConfirmButton"))
	await _wait(20)
	_check("a: result panel shown", (screen.get_node("%ResultLayer") as Control).visible)
	_check("a: both jars shown", (screen.get_node("%ResultJarA") as Control).visible
		and (screen.get_node("%ResultJarB") as Control).visible)
	_check("a: title MUSH!", (screen.get_node("%ResultTitle") as Label).text == "MUSH!")
	_check("a: both parents mushed, one alive", _game.run.roster[0].mushed
		and _game.run.roster[1].mushed and _game.run.living_count() == 1)
	_check("a: OK button says OK", (screen.get_node("%ResultOkButton") as Button).text == "OK")
	_check("a: gold spent", _game.run.gold == 100 - Tuning.FUSION_COST, _game.run.gold)
	await _shot("incubator_fail")
	_press(screen.get_node("%ResultOkButton"))
	await _wait(5)
	_check("a: result panel closed", not (screen.get_node("%ResultLayer") as Control).visible)
	_check("a: incubate disabled with one monster left",
		(screen.get_node("%ConfirmButton") as Button).disabled,
		(screen.get_node("%StatusLabel") as Label).text)
	_press(screen.get_node("%BackButton"))
	await _wait()
	_check("a: back to hub", current_scene.name == "Hub", current_scene.name)
	_check("a: formation valid", _formation_valid(), _game.run.formation)
	_check("a: roster size 3", _game.run.roster.size() == 3)
	await _open(FORMATION)
	_check("a: formation screen opens", current_scene.name == "Formation")

func _path_b() -> void:
	print("--- (b) Incubator failure that ends the run")
	var screen: Node = await _fail_setup(false)
	_check("b: warning shown before confirming",
		(screen.get_node("%WarningLabel") as Control).visible)
	_press(screen.get_node("%ConfirmButton"))
	await _wait(20)
	_check("b: nobody alive", _game.run.living_count() == 0)
	_check("b: OK button says End run",
		(screen.get_node("%ResultOkButton") as Button).text == "End run")
	_press(screen.get_node("%ResultOkButton"))
	await _wait()
	_check("b: run-end screen", current_scene.name == "RunEnd", current_scene.name)
	_check("b: shown as a lost run", not _game.run_victory
		and (current_scene.get_node("%TitleLabel") as Label).text == "DEFEAT")
	await _shot("run_end_after_fail")

func _path_cd_f() -> void:
	print("--- (c) CHOOSE row and (d) keep toggles")
	_game.new_run()
	_game.run.gold = 100
	_game.run.stabilizers = 2
	var a: MonsterData = _game.run.roster[0]
	var b: MonsterData = _game.run.roster[1]
	_equip(a, [[&"bone_plating", &"TORSO"]])
	a.slots[&"HEAD"] = FusionLogic.merge(
		FusionLogic.merge(_mut(&"frost_crest"), _mut(&"snapping_beak")), _mut(&"ember_horns"))
	a.slots[&"ARM_L"] = FusionLogic.merge(_mut(&"mantis_arm"), _mut(&"toxin_claw"))
	_equip(b, [[&"thick_skull", &"HEAD"], [&"cinder_fist", &"ARM_L"], [&"scorpion_tail", &"TAIL"]])
	var screen: Node = await _open(INCUBATOR)
	var head: FusionSlotRow = _row(screen, &"HEAD")
	_check("c: HEAD is a CHOOSE row", head != null
		and (head.get_node("%KindLabel") as Label).text == "CHOOSE"
		and (head.get_node("%ChooseRow") as Control).visible)
	_check("c: block reason shown", (head.get_node("%ReasonLabel") as Label).visible,
		(head.get_node("%ReasonLabel") as Label).text)
	_press(head.get_node("%ChooseB"))
	await _wait(4)
	head = _row(screen, &"HEAD")
	_check("c: B stays picked after the refresh",
		(head.get_node("%ChooseB") as Button).button_pressed
		and not (head.get_node("%ChooseA") as Button).button_pressed)
	_check("c: row shows B's part", (head.get_node("%NameLabel") as Label).text == "Thick Skull",
		(head.get_node("%NameLabel") as Label).text)

	var arm: FusionSlotRow = _row(screen, &"ARM_L")
	_check("d: ARM_L offers keep toggles", arm != null
		and (arm.get_node("%KeepRow") as Control).visible)
	for press: int in [2, 0, 2]:
		arm = _row(screen, &"ARM_L")
		_press(arm.get_node("%%Keep%d" % press))
		await _wait(4)
		arm = _row(screen, &"ARM_L")
		var keep: Array = (screen.get("_choices") as Dictionary).get(&"ARM_L", []) as Array
		var shown: Array = []
		for i: int in 4:
			var button: Button = arm.get_node("%%Keep%d" % i) as Button
			if button.visible and button.button_pressed:
				shown.append(i)
		var sorted_keep: Array = keep.duplicate()
		sorted_keep.sort()
		_check("d: after pressing %d exactly %d kept, buttons match" % [press,
			Tuning.FUSION_MAX_ABILITIES], keep.size() == Tuning.FUSION_MAX_ABILITIES
			and shown == sorted_keep, [keep, shown])
	var choices: Dictionary = screen.get("_choices") as Dictionary
	var preview: Dictionary = FusionLogic.incubate_preview(a, b, choices)
	var arm_row: Dictionary = (preview[&"slots"] as Dictionary)[&"ARM_L"] as Dictionary
	var offered: Array = _ability_ids(arm_row[&"abilities"] as Array)
	var kept_sorted: Array = (choices[&"ARM_L"] as Array).duplicate()
	kept_sorted.sort()
	var expected: Array = []
	for i: Variant in kept_sorted:
		expected.append(offered[int(i)])
	print("offered ", offered, " keep ", kept_sorted, " expected ", expected)
	await _shot("incubator_choose_keep")

	(screen.get_node("%StabSpin") as SpinBox).value = 2
	var chance: int = FusionLogic.incubate_chance(_game.run, a, b, 2)
	_force(chance, true)
	_press(screen.get_node("%ConfirmButton"))
	await _wait(20)
	var fused: MonsterData = _game.run.roster[0]
	_check("c/d: incubation succeeded", fused.fused and _game.run.roster.size() == 1)
	_check("c: result HEAD is B's part",
		(fused.slots.get(&"HEAD") as MutationData).id == &"thick_skull",
		(fused.slots.get(&"HEAD") as MutationData).id)
	var arm_part: MutationData = fused.slots.get(&"ARM_L") as MutationData
	var got: Array = _ability_ids(arm_part.all_abilities())
	_check("d: result ARM_L is an Apex with the two kept abilities",
		arm_part.merge_count == 2 and got == expected, got)
	_check("c/d: result title shown",
		(screen.get_node("%ResultSubtitle") as Label).text == fused.title, fused.title)
	_press(screen.get_node("%ResultOkButton"))
	await _wait(5)

	print("--- (f) hub -> formation -> bet -> battle with the chimera")
	await _open(HUB)
	_check("f: hub opens", current_scene.name == "Hub")
	var formation: Node = await _open(FORMATION)
	_check("f: formation valid", _formation_valid(), _game.run.formation)
	_press(formation.get_node("%ContinueButton"))
	await _wait(60)
	_check("f: bet screen", current_scene.name == "Bet", current_scene.name)
	_press(current_scene.get_node("%SkipButton"))
	await _wait(5)
	_check("f: battle screen", current_scene.name == "Battle", current_scene.name)
	var counts: Dictionary = {}
	var abilities: Dictionary = {}
	var sim: BattleSim = current_scene.get("_sim") as BattleSim
	sim.event.connect(func(kind: StringName, info: Dictionary) -> void:
		counts[kind] = int(counts.get(kind, 0)) + 1
		if kind == &"ability":
			abilities[StringName(info.get(&"ability_id", &"?"))] = int(abilities.get(StringName(info.get(&"ability_id", &"?")), 0)) + 1)
	var in_lineup: bool = false
	for unit: UnitState in sim.units:
		if unit.side == 0 and unit.data == fused:
			in_lineup = true
			var ids: Array = []
			for entry: Variant in unit.abilities:
				ids.append((entry as Array)[3])
			print("f: chimera abilities registered ", ids)
			_check("f: every fused ability registered",
				ids.has(&"double_strike") and ids.has(&"burn"), ids)
	_check("f: chimera in the lineup", in_lineup)
	_press(current_scene.get_node("%SpeedButton"))
	_press(current_scene.get_node("%SpeedButton"))
	await _wait(BATTLE_FRAMES)
	print("f: sim time ", sim.time, " events ", counts, " abilities ", abilities)
	_check("f: battle ran", sim.time > 1.0 or bool(current_scene.get("_ended")))
	var fired: bool = false
	for key: Variant in abilities.keys():
		if key in [&"double_strike", &"burn", &"venom", &"reflect"]:
			fired = true
	_check("f: a fused-part ability fired", fired, abilities)
	await _shot("battle_chimera")
	Engine.time_scale = 1.0

func _path_e() -> void:
	print("--- (e) Lab splice, then a second splice to an Apex")
	_game.new_run()
	_game.run.stabilizers = 4
	var mon: MonsterData = _game.run.roster[0]
	_equip(mon, [[&"mantis_arm", &"ARM_L"]])
	_game.run.inventory.assign([_mut(&"quartz_knuckle"), _mut(&"cinder_fist")])
	var screen: Node = await _open(LAB)
	var key: String = "mantis_arm+quartz_knuckle"
	for step: int in 2:
		_press(screen.get_node("%InventoryRow").get_child(0))
		await _wait(3)
		(screen.get_node("%SlotGrid").get_node("ARM_L") as Button).button_pressed = true
		await _wait(3)
		_check("e%d: confirm button says Splice" % step,
			(screen.get_node("%ConfirmButton") as Button).text.begins_with("Splice"),
			(screen.get_node("%ConfirmButton") as Button).text)
		(screen.get_node("%StabSpin") as SpinBox).value = 2
		var chance: int = LabLogic.success_chance(_game.run, mon, _game.run.inventory[0], 2)
		_force(chance, true)
		_press(screen.get_node("%ConfirmButton"))
		await _wait(20)
		var part: MutationData = mon.slots.get(&"ARM_L") as MutationData
		_check("e%d: SPLICED! panel with the fused part" % step,
			(screen.get_node("%ResultLayer") as Control).visible
			and (screen.get_node("%ResultTitle") as Label).text == "SPLICED!"
			and (screen.get_node("%ResultPart") as TextureRect).visible
			and (screen.get_node("%ResultPart") as TextureRect).texture == part.sprite_front)
		_check("e%d: slot holds merge_count %d" % [step, step + 1],
			part.merge_count == step + 1, part.display_name)
		_check("e%d: Codex recorded %s" % [step, String(part.id)],
			CodexStore.has_part(CodexStore.load_codex(), String(part.id)))
		print((screen.get_node("%ResultBody") as Label).text)
		await _shot("lab_spliced" if step == 0 else "lab_spliced_apex")
		_press(screen.get_node("%ResultOkButton"))
		await _wait(5)
		var marker: Node = screen.get_node("%PreviewView").get_node("Sockets/ARM_L")
		var sprite: Sprite2D = null
		for child: Node in marker.get_children():
			if child is Sprite2D and not child.is_queued_for_deletion():
				sprite = child as Sprite2D
		_check("e%d: monster shows the fused sprite" % step,
			sprite != null and sprite.texture == part.sprite_front)
		_check("e%d: apex glow material %s" % [step, "on" if step == 1 else "off"],
			sprite != null and (sprite.material == MonsterView.apex_material()) == (step == 1))
	_check("e: signature key recorded", CodexStore.has_part(CodexStore.load_codex(), key))
	await _shot("lab_after_apex_splice")

func _path_g() -> void:
	print("--- (g) Lab failure on the last living monster")
	_game.new_run()
	_game.run.roster[1].mushed = true
	_game.run.formation.erase(1)
	var mon: MonsterData = _game.run.roster[0]
	mon.slots.clear()
	mon.instability = 100.0
	_game.run.inventory.assign([_mut(&"mantis_arm")])
	var screen: Node = await _open(LAB)
	_press(screen.get_node("%InventoryRow").get_child(0))
	await _wait(3)
	_check("g: last-monster warning shown before confirming",
		(screen.get_node("%StatusLabel") as Label).text.begins_with("Failure ends the run"),
		(screen.get_node("%StatusLabel") as Label).text)
	_force(LabLogic.success_chance(_game.run, mon, _game.run.inventory[0], 0), false)
	_press(screen.get_node("%ConfirmButton"))
	await _wait(20)
	_check("g: nobody alive, End run offered", _game.run.living_count() == 0
		and (screen.get_node("%ResultOkButton") as Button).text == "End run")
	await _shot("lab_last_monster_mush")
	_press(screen.get_node("%ResultOkButton"))
	await _wait()
	_check("g: run-end screen as a lost run", current_scene.name == "RunEnd"
		and not _game.run_victory, current_scene.name)

func _path_h() -> void:
	print("--- (h) Lab keep row with a six-row breakdown")
	_game.new_run()
	_game.run.stabilizers = 2
	_game.run.lucky_gene = true
	_game.run.mush_memory = Tuning.MUSH_MEMORY_BONUS
	var mon: MonsterData = _game.run.roster[0]
	mon.slots.clear()
	mon.instability = 40.0
	mon.slots[&"ARM_L"] = FusionLogic.merge(_mut(&"mantis_arm"), _mut(&"toxin_claw"))
	_game.run.inventory.assign([_mut(&"cinder_fist")])
	var screen: Node = await _open(LAB)
	_press(screen.get_node("%InventoryRow").get_child(0))
	await _wait(3)
	(screen.get_node("%SlotGrid").get_node("ARM_L") as Button).button_pressed = true
	(screen.get_node("%StabSpin") as SpinBox).value = 2
	await _wait(5)
	var names: Label = screen.get_node("%BreakdownNames") as Label
	var keep_row: Control = screen.get_node("%KeepRow") as Control
	var text_bottom: float = names.global_position.y + names.get_minimum_size().y
	_check("h: breakdown (%d rows) ends above the keep row" % names.get_line_count(),
		keep_row.visible and text_bottom <= keep_row.global_position.y,
		[text_bottom, keep_row.global_position.y])
	await _shot("lab_keep_breakdown")
