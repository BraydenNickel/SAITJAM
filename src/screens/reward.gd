extends Control
## Reward screen (after a won battle that is not the last): pick 1 of the
## options rolled once by RewardLogic, apply it, then return to the hub.
## Cards fade/slide in staggered; a pick pops the chosen card, fades the rest
## and bursts an effect before leaving.

const CARD_SCENE: PackedScene = preload("res://src/ui/reward_card.tscn")

## Seconds between each card's intro start.
@export var intro_stagger: float = 0.08
## Seconds each card takes to slide / fade in.
@export var intro_time: float = 0.3
## Pixels each card slides up from on intro.
@export var intro_offset: float = 24.0
## Seconds of one header pulse half-cycle.
@export var pulse_time: float = 0.7
## Header colour at the dim end of the pulse.
@export var pulse_dim: Color = Color(0.65, 0.8, 0.65, 1)
## Scale the chosen card pops to.
@export var pick_scale: float = 1.15
## Seconds to wait after a pick before leaving for the hub.
@export var exit_delay: float = 0.5

@onready var _title: Label = %Title
@onready var _sub_label: Label = %SubLabel
@onready var _card_row: HBoxContainer = %CardRow
@onready var _fx_layer: Node2D = %FxLayer
@onready var _sfx: SfxPlayer = %Sfx

var _picked: bool = false
var _cards: Array[RewardCard] = []

func _ready() -> void:
	Game.ensure_run()
	_sub_label.text = "Battle won!   Gold: %d   Next: battle %d/%d" % [Game.run.gold,
		Game.run.battle_index + 1, Tuning.BATTLES_PER_RUN]
	var options: Array[Dictionary] = RewardLogic.roll_options(Game.run, Game.rng)
	for option: Dictionary in options:
		var card: RewardCard = CARD_SCENE.instantiate() as RewardCard
		_card_row.add_child(card)
		card.setup(option)
		card.chosen.connect(_on_chosen.bind(card))
		_cards.append(card)
	if _cards.is_empty():
		Game.go_to.call_deferred(&"hub")  # nothing to offer
		return
	_pulse_title()
	_play_intro()

func _pulse_title() -> void:
	var tween: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title, ^"self_modulate", pulse_dim, pulse_time)
	tween.tween_property(_title, ^"self_modulate", Color.WHITE, pulse_time)

func _play_intro() -> void:
	for card: RewardCard in _cards:
		card.card().modulate.a = 0.0
		card.card().position.y = intro_offset
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	for i: int in _cards.size():
		var button: Button = _cards[i].card()
		var delay: float = intro_stagger * i
		tween.tween_property(button, ^"modulate:a", 1.0, intro_time).set_delay(delay)
		tween.tween_property(button, ^"position:y", 0.0, intro_time).set_delay(delay)
	# Focus after the intro so the hover lift does not fight the slide-in.
	tween.finished.connect(func() -> void:
		if not _picked and not _cards.is_empty():
			_cards[0].focus())

func _on_chosen(option: Dictionary, chosen_card: RewardCard) -> void:
	if _picked:
		return
	_picked = true
	RewardLogic.apply(Game.run, option)
	var gift: MutationData = option.get(&"mutation") as MutationData
	if option.get(&"id") == &"free_mutation" and gift != null:
		CodexStore.record_mutation(gift.id)
	_sfx.play_detached(&"coin")
	Game.notify_gold()
	_play_pick(chosen_card)
	await get_tree().create_timer(exit_delay).timeout
	Game.go_to(&"hub")

func _play_pick(chosen_card: RewardCard) -> void:
	var tween: Tween = create_tween().set_parallel()
	for card: RewardCard in _cards:
		card.lock()
		if card == chosen_card:
			tween.tween_property(card.card(), ^"scale", Vector2.ONE * pick_scale, 0.18) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(card.card(), ^"position:y", -10.0, 0.18)
		else:
			tween.tween_property(card.card(), ^"modulate:a", 0.0, 0.25)
			tween.tween_property(card.card(), ^"scale", Vector2.ONE * 0.9, 0.25)
	var center: Vector2 = chosen_card.card().get_global_rect().get_center()
	PixelFxPlayer.spawn(_fx_layer, FxLibrary.event_fx(&"win_small"), center)
