extends Control
## Roster screen: one MonsterCard per roster monster (mushed ones show the
## mush jar). Living monsters can be renamed by clicking their name.

const CARD_SCENE: PackedScene = preload("res://src/ui/monster_card.tscn")

@onready var _grid: GridContainer = %Grid
@onready var _back_button: Button = %BackButton
@onready var _rename_dialog: RenameDialog = %RenameDialog

var _cards: Array[MonsterCard] = []
## Monster whose rename dialog is open (focus returns to its card).
var _renaming: MonsterData

func _ready() -> void:
	Game.ensure_run()
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.grab_focus()
	_rename_dialog.name_saved.connect(_on_renamed)
	_rename_dialog.closed.connect(_on_rename_closed)
	for monster: MonsterData in Game.run.roster:
		var card: MonsterCard = CARD_SCENE.instantiate() as MonsterCard
		card.allow_rename = true  # the card hides the button for mush
		card.rename_requested.connect(_on_rename_requested)
		_grid.add_child(card)
		card.setup(monster)
		_cards.append(card)

func _on_rename_requested(monster: MonsterData) -> void:
	_renaming = monster
	_rename_dialog.open(monster)

func _on_renamed(_monster: MonsterData, _new_name: String) -> void:
	for card: MonsterCard in _cards:
		card.refresh()

## Gives focus back to the renamed card's name (keyboard/gamepad flow).
func _on_rename_closed() -> void:
	for card: MonsterCard in _cards:
		if card.get_data() == _renaming:
			card.focus_name()
			break
	_renaming = null

func _on_back_pressed() -> void:
	Game.go_to(&"hub")
