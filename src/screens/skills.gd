extends Control
## Skills screen (main menu -> SKILLS): spend permanent skill points on ranked
## bonuses in three columns (Tuning.SKILL_COLUMNS). One skill_row.tscn per
## Tuning.SKILLS entry is added to its column; everything else is laid out in
## skills.tscn. Points and ranks live in SkillStore at Game.skills_path.

## Row scene instanced into Rows0/1/2, one per Tuning.SKILLS entry.
@export var row_scene: PackedScene
## Where on a buy button (fraction of its size) the purchase pop appears.
@export var buy_fx_anchor: Vector2 = Vector2(0.5, 0.5)

const TEXT_POINTS: String = "Skill points: %d"
const TEXT_REFUND: String = "Refund all"
const TEXT_REFUND_CONFIRM: String = "Confirm refund?"
const TEXT_REFUNDED: String = "Refunded %d points."
const TEXT_BOUGHT: String = "%s upgraded."

var _rows: Array[SkillRow] = []
var _refund_armed: bool = false

@onready var _points_label: Label = %PointsLabel
@onready var _status_label: Label = %StatusLabel
@onready var _refund_button: Button = %RefundButton
@onready var _back_button: Button = %BackButton
@onready var _fx_layer: Node2D = %FxLayer
@onready var _sfx: SfxPlayer = %Sfx


func _ready() -> void:
	var headers: Array[Label] = [%Header0, %Header1, %Header2]
	var columns: Array[VBoxContainer] = [%Rows0, %Rows1, %Rows2]
	for i: int in mini(headers.size(), Tuning.SKILL_COLUMNS.size()):
		headers[i].text = Tuning.SKILL_COLUMNS[i]
	for def: Dictionary in Tuning.SKILLS:
		var row: SkillRow = row_scene.instantiate() as SkillRow
		columns[clampi(int(def[&"column"]), 0, columns.size() - 1)].add_child(row)
		row.setup(def, Game.skills_path)
		row.bought.connect(_on_bought.bind(row))
		_rows.append(row)
	_refund_button.pressed.connect(_on_refund_pressed)
	_back_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	_back_button.pressed.connect(Game.go_to.bind(&"title"))
	_refresh()
	_focus_first()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back_button.pressed.emit()


## Updates the points readout, every row and the refund button from the store.
func _refresh() -> void:
	_points_label.text = TEXT_POINTS % SkillStore.points(Game.skills_path)
	for row: SkillRow in _rows:
		row.refresh()
	_refund_button.disabled = not _has_ranks()


func _has_ranks() -> bool:
	for rank: int in SkillStore.ranks(Game.skills_path).values():
		if rank > 0:
			return true
	return false


## Focus goes to the first buy button that can be pressed, else Back.
func _focus_first() -> void:
	for row: SkillRow in _rows:
		if not row.buy_button().disabled:
			row.buy_button().grab_focus()
			return
	_back_button.grab_focus()


func _reset_refund() -> void:
	_refund_armed = false
	_refund_button.text = TEXT_REFUND


func _on_bought(_id: StringName, row: SkillRow) -> void:
	_reset_refund()
	_sfx.play(&"click")
	var button: Button = row.buy_button()
	PixelFxPlayer.spawn(_fx_layer, FxLibrary.event_fx(&"purchase"),
		button.global_position + button.size * buy_fx_anchor)
	_status_label.text = TEXT_BOUGHT % row.skill_name()
	_refresh()
	if button.disabled:
		_focus_first()


## First press arms the button, second press refunds every rank (like Settings Restart).
func _on_refund_pressed() -> void:
	if not _refund_armed:
		_refund_armed = true
		_refund_button.text = TEXT_REFUND_CONFIRM
		_sfx.play(&"click")
		return
	_reset_refund()
	_sfx.play(&"click")
	var refunded: int = SkillStore.refund_all(Game.skills_path)
	_status_label.text = TEXT_REFUNDED % refunded
	_refresh()
	_focus_first()
