extends Control
## Hub screen: between-battle overview of gold, progress and the team.

@onready var _gold_label: Label = %GoldLabel
@onready var _battle_label: Label = %BattleLabel
@onready var _stock_label: Label = %StockLabel
@onready var _lab_button: Button = %LabButton
@onready var _shop_button: Button = %ShopButton
@onready var _incubator_button: Button = %IncubatorButton
@onready var _codex_button: Button = %CodexButton
@onready var _roster_button: Button = %RosterButton
@onready var _fight_button: Button = %FightButton
@onready var _sponsor_label: Label = %SponsorLabel
@onready var _sfx: SfxPlayer = %Sfx

@onready var _hint_label: Label = %HintLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _settings_menu: SettingsMenu = %SettingsMenu

var _cards: Array[MonsterCard] = []

func _ready() -> void:
	Game.ensure_run()
	_cards.assign([%Card1, %Card2, %Card3, %Card4])
	_settings_button.pressed.connect(_sfx.play.bind(&"click"))
	_settings_button.pressed.connect(_settings_menu.open)
	_settings_menu.closed.connect(_fight_button.grab_focus)
	Game.gold_changed.connect(_on_gold_changed)
	_roster_button.pressed.connect(_on_roster_pressed)
	_lab_button.pressed.connect(func() -> void: Game.go_to(&"lab"))
	_shop_button.pressed.connect(func() -> void: Game.go_to(&"shop"))
	_fight_button.pressed.connect(_on_fight_pressed)
	_incubator_button.pressed.connect(func() -> void: Game.go_to(&"incubator"))
	_codex_button.pressed.connect(func() -> void: Game.go_to(&"codex"))
	for button: Button in [_roster_button, _lab_button, _shop_button, _fight_button,
			_incubator_button, _codex_button]:
		button.pressed.connect(_sfx.play_detached.bind(&"click"))
	var can_fight: bool = false
	for monster: MonsterData in Game.run.roster:
		if not monster.mushed:
			can_fight = true
	_fight_button.disabled = not can_fight
	_fight_button.tooltip_text = "" if can_fight else "You need at least one living monster"
	# Sponsor grant: once per hub visit when broke.
	if Game.run.gold < Tuning.SPONSOR_THRESHOLD:
		Game.add_gold(Tuning.SPONSOR_GRANT)
		_sponsor_label.text = "A sponsor pities your lab: +%dg!" % Tuning.SPONSOR_GRANT
		_sponsor_label.visible = true
		_hint_label.visible = false
		_sfx.play(&"coin")
	_on_gold_changed(Game.run.gold)
	_battle_label.text = "Next: Battle %d/%d" % [Game.run.battle_index + 1, Tuning.BATTLES_PER_RUN]
	_stock_label.text = "Stabilizers: %d   Mutations: %d" % [Game.run.stabilizers,
		Game.run.inventory.size()]
	# Living monsters only; mush is shown in the Roster.
	var living: Array[MonsterData] = []
	for monster: MonsterData in Game.run.roster:
		if not monster.mushed:
			living.append(monster)
	for i: int in _cards.size():
		var has_monster: bool = i < living.size()
		_cards[i].visible = has_monster
		if has_monster:
			_cards[i].setup(living[i])
	_fight_button.grab_focus()

## Esc toggles the settings panel (the open panel handles its own Esc first).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _settings_menu.is_open():
		get_viewport().set_input_as_handled()
		_settings_menu.open()

func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = "Gold: %d" % new_gold

func _on_roster_pressed() -> void:
	Game.go_to(&"roster")

func _on_fight_pressed() -> void:
	Game.go_to(&"formation")
