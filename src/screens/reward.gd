extends Control
## Reward screen (after a won battle that is not the last): pick 1 of the
## options rolled once by RewardLogic, apply it, then return to the hub.

const CARD_SCENE: PackedScene = preload("res://src/ui/reward_card.tscn")

@onready var _sub_label: Label = %SubLabel
@onready var _card_row: HBoxContainer = %CardRow

var _picked: bool = false

func _ready() -> void:
	Game.ensure_run()
	_sub_label.text = "Gold: %d   Next: battle %d/%d" % [Game.run.gold,
		Game.run.battle_index + 1, Tuning.BATTLES_PER_RUN]
	var options: Array[Dictionary] = RewardLogic.roll_options(Game.run, Game.rng)
	var first: RewardCard = null
	for option: Dictionary in options:
		var card: RewardCard = CARD_SCENE.instantiate() as RewardCard
		_card_row.add_child(card)
		card.setup(option)
		card.chosen.connect(_on_chosen)
		if first == null:
			first = card
	if first != null:
		first.grab_focus()
	else:
		Game.go_to.call_deferred(&"hub")  # nothing to offer

func _on_chosen(option: Dictionary) -> void:
	if _picked:
		return
	_picked = true
	RewardLogic.apply(Game.run, option)
	Game.notify_gold()
	Game.go_to(&"hub")
