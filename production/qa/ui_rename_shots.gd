extends SceneTree
## Captures rename-feature screenshots and checks the name really changes.
## Run windowed: godot --path . -s res://production/qa/ui_rename_shots.gd

const OUT: String = "res://production/qa/evidence/ui_rename_%s.png"
const NEW_NAME: String = "Gloop"

func _initialize() -> void:
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i: int in frames:
		await process_frame

func _save(shot: String) -> void:
	root.get_texture().get_image().save_png(OUT % shot)
	print("saved ", shot)

func _run() -> void:
	var game: Node = root.get_node("Game")
	game.new_run()
	var run: RunState = game.run
	var monster: MonsterData = run.roster[0]
	var old_name: String = monster.display_name
	change_scene_to_file("res://src/screens/hub.tscn")
	await _wait(12)
	var hub: Node = current_scene
	var card: MonsterCard = hub.get_node("%Card1") as MonsterCard
	var dialog: RenameDialog = hub.get_node("%RenameDialog") as RenameDialog
	# Click path: the card's name button emits rename_requested -> dialog opens.
	(card.get_node("%NameButton") as Button).pressed.emit()
	await _wait(6)
	var opened: bool = dialog.is_open()
	await _save("dialog")
	# Save path: type a padded name and press Save.
	(dialog.get_node("%NameEdit") as LineEdit).text = "  " + NEW_NAME + "  "
	dialog.save()
	var closed_after_save: bool = not dialog.is_open()
	await _wait(6)
	await _save("hub")
	var card_text: String = (card.get_node("%NameButton") as Button).text
	# Widest legal name must not stretch the 4-card hub row.
	var card2: MonsterCard = hub.get_node("%Card2") as MonsterCard
	var width_before: float = card2.size.x
	(card2.get_node("%NameButton") as Button).pressed.emit()
	await _wait(2)
	(dialog.get_node("%NameEdit") as LineEdit).text = "W".repeat(RenameDialog.MAX_NAME_LENGTH + 3)
	dialog.save()
	await _wait(6)
	await _save("long")
	var long_ok: bool = (run.roster[1].display_name.length() == RenameDialog.MAX_NAME_LENGTH
		and is_equal_approx(card2.size.x, width_before))
	print("long name width before=%.0f after=%.0f -> %s" % [width_before, card2.size.x,
		"PASS" if long_ok else "FAIL"])
	change_scene_to_file("res://src/screens/roster.tscn")
	await _wait(12)
	await _save("roster")
	var ok: bool = (opened and monster.display_name == NEW_NAME
		and run.roster[0].display_name == NEW_NAME and card_text == NEW_NAME
		and closed_after_save and long_ok)
	print("old=%s new=%s card=%s opened=%s" % [old_name, monster.display_name, card_text, opened])
	print("RENAME CHECK: ", "PASS" if ok else "FAIL")
	quit()
