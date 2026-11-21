extends Control
## Hub screen: between-battle overview of gold, progress and the team.

@onready var _gold_label: Label = %GoldLabel
@onready var _battle_label: Label = %BattleLabel
@onready var _roster_button: Button = %RosterButton
@onready var _fight_button: Button = %FightButton
@onready var _sponsor_label: Label = %SponsorLabel

var _slots: Array[Control] = []
var _monsters: Array[MonsterView] = []
var _names: Array[Label] = []

func _ready() -> void:
	Game.ensure_run()
	_slots.assign([%Slot1, %Slot2, %Slot3, %Slot4])
	_monsters.assign([%Monster1, %Monster2, %Monster3, %Monster4])
	_names.assign([%Name1, %Name2, %Name3, %Name4])
	Game.gold_changed.connect(_on_gold_changed)
	_roster_button.pressed.connect(_on_roster_pressed)
	_fight_button.pressed.connect(_on_fight_pressed)
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
	_on_gold_changed(Game.run.gold)
	_battle_label.text = "Battle %d/%d" % [Game.run.battle_index + 1, Tuning.BATTLES_PER_RUN]
	for i: int in _slots.size():
		var has_monster: bool = i < Game.run.roster.size()
		_slots[i].visible = has_monster
		if has_monster:
			_monsters[i].data = Game.run.roster[i]
			_names[i].text = Game.run.roster[i].display_name

func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = "Gold: %d" % new_gold

func _on_roster_pressed() -> void:
	Game.go_to(&"roster")

func _on_fight_pressed() -> void:
	Game.go_to(&"formation")
