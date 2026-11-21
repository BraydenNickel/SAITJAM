extends Control
## Roster screen: one MonsterCard per roster monster.

const CARD_SCENE: PackedScene = preload("res://src/ui/monster_card.tscn")

@onready var _grid: GridContainer = %Grid
@onready var _back_button: Button = %BackButton

func _ready() -> void:
	Game.ensure_run()
	_back_button.pressed.connect(_on_back_pressed)
	for monster: MonsterData in Game.run.roster:
		var card: MonsterCard = CARD_SCENE.instantiate() as MonsterCard
		_grid.add_child(card)
		card.setup(monster)

func _on_back_pressed() -> void:
	Game.go_to(&"hub")
