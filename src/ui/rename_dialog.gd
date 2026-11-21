class_name RenameDialog
extends CanvasLayer
## Modal "Rename" popup for a monster. Instance it hidden in a screen, call
## open(monster), and listen to `name_saved`. Enter or Save keeps the new name,
## Esc or Cancel closes without changes. The name rule lives in clean_name().

## Emitted after Save changed `monster.display_name` to `new_name`.
signal name_saved(monster: MonsterData, new_name: String)
## Emitted whenever the dialog closes (saved or cancelled).
signal closed

## Longest allowed name (also the LineEdit's max_length in the scene).
const MAX_NAME_LENGTH: int = 14

@onready var _name_edit: LineEdit = %NameEdit
@onready var _save_button: Button = %SaveButton
@onready var _cancel_button: Button = %CancelButton
@onready var _sfx: SfxPlayer = %Sfx

var _monster: MonsterData

func _ready() -> void:
	_name_edit.max_length = MAX_NAME_LENGTH
	_name_edit.text_submitted.connect(func(_text: String) -> void: save())
	_save_button.pressed.connect(save)
	_cancel_button.pressed.connect(cancel)

## The name to keep: `raw` without surrounding whitespace, cut to
## MAX_NAME_LENGTH characters; `old_name` when nothing is left.
static func clean_name(raw: String, old_name: String) -> String:
	var trimmed: String = raw.strip_edges().left(MAX_NAME_LENGTH).strip_edges()
	return old_name if trimmed.is_empty() else trimmed

## Shows the dialog for `monster` with its current name selected.
func open(monster: MonsterData) -> void:
	if monster == null:
		return
	_monster = monster
	_name_edit.text = monster.display_name.left(MAX_NAME_LENGTH)
	visible = true
	_name_edit.grab_focus()
	_name_edit.select_all()

## Applies the typed name (see clean_name) and closes the dialog.
func save() -> void:
	if not visible or _monster == null:
		return
	var monster: MonsterData = _monster
	var new_name: String = clean_name(_name_edit.text, monster.display_name)
	_sfx.play(&"click")
	_close()
	if new_name != monster.display_name:
		monster.display_name = new_name
		name_saved.emit(monster, new_name)

## Closes the dialog without renaming.
func cancel() -> void:
	if not visible:
		return
	_sfx.play(&"click")
	_close()

## True while the dialog is shown.
func is_open() -> bool:
	return visible

func _close() -> void:
	visible = false
	_monster = null
	closed.emit()

# _input (not _unhandled_input): the focused LineEdit would eat Esc first.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
