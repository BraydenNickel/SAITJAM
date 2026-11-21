@tool
class_name HintBanner
extends PanelContainer
## One-time help banner. Instance hint_banner.tscn in a screen, set `hint_id`
## and `text` in the Inspector, and place it where it covers nothing important.
## It shows until the player presses "Got it" (see Tuning.HINT_MARK_SEEN_ON_SHOW),
## and stays hidden in every later session (HintStore, user://hints.cfg).
## In the editor it is always visible so the text and layout can be edited.

## Emitted when the player dismisses the banner.
signal dismissed(hint_id: StringName)

## Persistent key in HintStore. Empty = never shown in game.
@export var hint_id: StringName = &""
## The help text (one or two short sentences).
@export_multiline var text: String = "":
	set(value):
		text = value
		if is_node_ready():
			_label.text = value
## Stack the text above the button (for narrow corner placements).
@export var vertical: bool = false:
	set(value):
		vertical = value
		if is_node_ready():
			_box.vertical = value

@onready var _box: BoxContainer = %Box
@onready var _label: Label = %Label
@onready var _button: Button = %GotItButton
@onready var _sfx: SfxPlayer = %Sfx

func _ready() -> void:
	_label.text = text
	_box.vertical = vertical
	if Engine.is_editor_hint():
		return
	_button.pressed.connect(dismiss)
	visible = hint_id != &"" and not HintStore.is_seen(hint_id)
	if visible and Tuning.HINT_MARK_SEEN_ON_SHOW:
		HintStore.mark_seen(hint_id)

## Hides the banner for good (saves `hint_id` as seen).
func dismiss() -> void:
	if not visible:
		return
	_sfx.play(&"click")
	HintStore.mark_seen(hint_id)
	visible = false
	dismissed.emit(hint_id)
