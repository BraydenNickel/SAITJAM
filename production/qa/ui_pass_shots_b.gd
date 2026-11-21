extends SceneTree
## UI pass B: Lab and Formation drag and drop. Calls the drop functions directly
## with the payload the drag sources return, then repeats one drag per screen
## with real mouse events. Prints PASS/FAIL lines and saves screenshots.
## Run windowed:
## godot --path . -s res://production/qa/ui_pass_shots_b.gd

const OUT: String = "res://production/qa/evidence/%s.png"

var _fails: int = 0
var _passes: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
		print("PASS ", what)
	else:
		_fails += 1
		print("FAIL ", what)

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(OUT % name)
	print("saved ", name)

func _open(scene_path: String) -> Node:
	change_scene_to_file(scene_path)
	await _frames(12)
	return current_scene

## Centre of a Control in viewport coordinates.
func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

## Drags with real mouse events from `from` to `to` (viewport coordinates),
## saving `shot` while the drag is in flight.
func _mouse_drag(from: Vector2, to: Vector2, shot: String) -> void:
	var xf: Transform2D = root.get_final_transform()
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	down.position = xf * from
	down.global_position = down.position
	Input.parse_input_event(down)
	await _frames(2)
	var last: Vector2 = xf * from
	for i: int in range(1, 13):
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = xf * from.lerp(to, float(i) / 12.0)
		motion.global_position = motion.position
		motion.relative = motion.position - last
		last = motion.position
		Input.parse_input_event(motion)
		await _frames(1)
	await _frames(3)
	if shot != "":
		_save(shot)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = xf * to
	up.global_position = up.position
	Input.parse_input_event(up)
	await _frames(4)

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	var run: RunState = game.run
	# A few mutations of different sockets, plus a 3rd-5th subject for the
	# formation team limit.
	var muts: Array[MutationData] = EnemyGen.all_mutations()
	var seen: Dictionary = {}
	for m: MutationData in muts:
		if m.rarity == MutationData.Rarity.ULTRA or seen.has(m.socket_type):
			continue
		seen[m.socket_type] = true
		run.inventory.append(m)
		if run.inventory.size() >= 5:
			break
	run.stabilizers = 2
	run.gold = 80
	for i: int in 3:
		var extra: MonsterData = run.roster[0].duplicate(true) as MonsterData
		extra.display_name = "Subject %02d" % (run.roster.size() + 1)
		run.roster.append(extra)
	await _lab_checks(run)
	await _formation_checks(game, run)
	print("RESULT %d PASS, %d FAIL" % [_passes, _fails])
	quit()

# --- Lab ------------------------------------------------------------------------

func _lab_checks(run: RunState) -> void:
	var lab: Node = await _open("res://src/screens/lab.tscn")
	_save("ui_lab")
	var monster: MonsterData = run.roster[0]
	var items: Array[InventoryItem] = []
	for child: Node in lab._inventory_row.get_children():
		items.append(child as InventoryItem)
	_check(items.size() == run.inventory.size(), "lab shows every inventory item")
	var item: InventoryItem = items[0]
	var payload: Dictionary = item.drag_payload()
	_check(payload.get(&"kind") == &"mutation" and int(payload.get(&"inv_index", -1)) == 0,
		"inventory payload = {kind=mutation, inv_index=0}")
	var mutation: MutationData = run.inventory[0]
	var valid: Array[StringName] = LabLogic.operable_slots(monster, mutation)
	var invalid: StringName = &""
	for slot: StringName in MonsterData.SLOTS:
		if not valid.has(slot):
			invalid = slot
			break
	_check(not valid.is_empty(), "mutation 0 has a valid slot")
	_check(not bool(lab._can_drop_on_slot(Vector2.ZERO, payload, invalid)),
		"slot %s rejects %s" % [invalid, mutation.display_name])
	var target: StringName = valid[valid.size() - 1]
	_check(bool(lab._can_drop_on_slot(Vector2.ZERO, payload, target)),
		"slot %s accepts %s" % [target, mutation.display_name])
	_check(not bool(lab._can_drop_on_slot(Vector2.ZERO, {&"kind": &"monster"}, target)),
		"slot rejects a non-mutation payload")
	lab._drop_on_slot(Vector2.ZERO, payload, target)
	await _frames(4)
	_check(lab._inv_idx == 0 and lab._slot == target, "drop on slot selects mutation + slot")
	_check(item.button_pressed, "dropped item shows as pressed")
	_check(lab._ghost_part.visible, "ghost preview visible after drop")
	_check(not lab._confirm_button.disabled, "Operate enabled after drop")
	# Preview drop: second mutation, auto-picks its first valid slot.
	var payload2: Dictionary = items[1].drag_payload()
	var valid2: Array[StringName] = LabLogic.operable_slots(monster, run.inventory[1])
	_check(bool(lab._can_drop_on_preview(Vector2.ZERO, payload2)) == not valid2.is_empty(),
		"preview accepts a mutation with a valid slot")
	lab._drop_on_preview(Vector2.ZERO, payload2)
	await _frames(4)
	_check(lab._inv_idx == 1 and lab._slot == valid2[0],
		"drop on preview selects mutation + first slot (%s)" % lab._slot)
	_check(items[1].button_pressed and not item.button_pressed, "pressed state follows the drop")
	# Purge mode refuses drops.
	lab._set_mode(1)
	_check(not bool(lab._can_drop_on_preview(Vector2.ZERO, payload2)), "purge mode rejects drops")
	lab._set_mode(0)
	# Real mouse drag: item 2 onto its first valid slot button.
	var m3: MutationData = run.inventory[2]
	var valid3: Array[StringName] = LabLogic.operable_slots(monster, m3)
	var button: Button = lab._slot_buttons[valid3[0]] as Button
	await _mouse_drag(_center(items[2]), _center(button), "ui_lab_dragging")
	_check(lab._inv_idx == 2 and lab._slot == valid3[0],
		"real mouse drag item -> %s button (inv %d, slot %s)" % [valid3[0], lab._inv_idx, lab._slot])
	lab._stab_spin.value = 1
	await _frames(4)
	_save("ui_lab_dropped")

# --- Formation ---------------------------------------------------------------------

func _formation_checks(game: Node, run: RunState) -> void:
	run.formation = {0: 0}
	var form: Node = await _open("res://src/screens/formation.tscn")
	var spots: Dictionary = form._spot_slots
	var chips: Dictionary = form._chips
	var chip1: MonsterSlot = chips[1] as MonsterSlot
	var payload: Dictionary = chip1.drag_payload()
	_check(payload.get(&"kind") == &"monster" and int(payload.get(&"roster_index", -1)) == 1
		and int(payload.get(&"from_spot", 0)) == -1, "roster payload = {monster, 1, from -1}")
	var spot2: MonsterSlot = spots[2] as MonsterSlot
	_check(spot2._can_drop_data(Vector2.ZERO, payload), "empty spot 2 accepts roster card")
	_check(not chips[0]._can_drop_data(Vector2.ZERO, payload), "roster chip rejects roster card")
	_check(not form._can_drop_data(Vector2.ZERO, payload), "background rejects roster card")
	spot2._drop_data(Vector2.ZERO, payload)
	await _frames(2)
	_check(int(run.formation.get(2, -1)) == 1, "roster -> spot: formation[2] = 1")
	# Spot -> spot (swap with the occupant of spot 0).
	var from2: Dictionary = spot2.drag_payload()
	_check(int(from2.get(&"from_spot", -1)) == 2, "placed payload from_spot = 2")
	_check(not spot2._can_drop_data(Vector2.ZERO, from2), "spot rejects its own monster")
	var spot0: MonsterSlot = spots[0] as MonsterSlot
	_check(spot0._can_drop_data(Vector2.ZERO, from2), "occupied spot 0 accepts a swap")
	spot0._drop_data(Vector2.ZERO, from2)
	await _frames(2)
	_check(int(run.formation.get(0, -1)) == 1 and int(run.formation.get(2, -1)) == 0,
		"spot -> spot swaps: formation {0:1, 2:0}")
	# Spot -> roster removes.
	var from0: Dictionary = spot0.drag_payload()
	var chip0: MonsterSlot = chips[0] as MonsterSlot
	_check(chip0._can_drop_data(Vector2.ZERO, from0), "roster chip accepts a placed monster")
	chip0._drop_data(Vector2.ZERO, from0)
	await _frames(2)
	_check(not run.formation.has(0) and run.formation.size() == 1, "spot -> roster removes it")
	# Spot -> background removes.
	var from2b: Dictionary = (spots[2] as MonsterSlot).drag_payload()
	_check(form._can_drop_data(Vector2.ZERO, from2b), "background accepts a placed monster")
	form._drop_data(Vector2.ZERO, from2b)
	await _frames(2)
	_check(run.formation.is_empty() and form._continue_button.disabled,
		"spot -> off grid removes it (Continue disabled)")
	# Team limit: fill 4, the 5th may only replace.
	for i: int in 4:
		(spots[i] as MonsterSlot)._drop_data(Vector2.ZERO, (chips[i] as MonsterSlot).drag_payload())
	await _frames(2)
	_check(run.formation.size() == 4, "four placed")
	var p5: Dictionary = (chips[4] as MonsterSlot).drag_payload()
	_check(not spots[4]._can_drop_data(Vector2.ZERO, p5), "5th monster rejected on empty spot")
	_check(spots[3]._can_drop_data(Vector2.ZERO, p5), "5th monster may replace an occupant")
	(spots[3] as MonsterSlot)._drop_data(Vector2.ZERO, p5)
	await _frames(2)
	_check(int(run.formation.get(3, -1)) == 4 and run.formation.size() == 4,
		"replace keeps the team at 4")
	# Click fallback still works: click placed spot 3 removes it.
	form._on_spot_pressed(3)
	await _frames(2)
	_check(not run.formation.has(3), "click on placed spot removes it")
	# Real mouse drag: chip 3 -> empty spot 5.
	await _mouse_drag(_center(chips[3] as Control), _center(spots[5] as Control),
		"ui_formation_dragging")
	_check(int(run.formation.get(5, -1)) == 3, "real mouse drag chip -> spot 5 (%s)" % str(run.formation))
	await _frames(4)
	_save("ui_formation")
