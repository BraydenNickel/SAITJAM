extends SceneTree
## Windowed QA shots for skill points: the main menu with SKILLS focused, the Skills
## screen with some ranks bought, and the run end with "+N skill points".
## Uses a temp skills file (never the real user://skills.json), removed afterwards.
## Run: Godot --path . -s res://production/qa/skills_shots.gd  (windowed, not headless)

const TMP_SKILLS: String = "user://qa_tmp_skills.json"
const OUT: String = "res://production/qa/evidence/"

func _initialize() -> void:
	_run.call_deferred()

func _wait(n: int) -> void:
	for i: int in n:
		await process_frame

func _shot(file: String) -> void:
	await _wait(30)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file)

func _run() -> void:
	var game: Node = root.get_node("Game")
	var real_path: String = game.skills_path
	game.skills_path = TMP_SKILLS
	SkillStore.save_data({"points": 4, "ranks": {"seed_money": 2, "stockpile": 2,
		"common_graft": 1, "thick_hide": 3, "adrenaline": 1}}, TMP_SKILLS)

	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(10)
	current_scene.get_node("%Skills").grab_focus()
	await _shot("skills_menu_button.png")

	change_scene_to_file("res://src/screens/skills.tscn")
	await _wait(10)
	# Press one affordable buy button so the status line and pop show.
	for row: Node in current_scene.find_children("*", "PanelContainer", true, false):
		if row.has_method("buy_button") and not row.call("buy_button").disabled:
			row.call("buy_button").pressed.emit()
			break
	await _wait(4)
	await _shot("skills_screen.png")
	current_scene.get_node("%RefundButton").pressed.emit()
	await _shot("skills_refund_confirm.png")

	game.new_run()
	game.battles_cleared = 3
	game.skill_points_earned = 3
	change_scene_to_file("res://src/screens/run_end.tscn")
	await _shot("run_end_skill_points.png")

	game.skills_path = real_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SKILLS))
	quit()
