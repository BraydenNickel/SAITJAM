extends Control
## Formation screen: place 1-4 non-mushed monsters on the 6 spots, see the enemy.

const SLOT_SCENE: PackedScene = preload("res://src/ui/monster_slot.tscn")

@onready var _player_grid: GridContainer = %PlayerGrid
@onready var _enemy_grid: GridContainer = %EnemyGrid
@onready var _roster_row: HBoxContainer = %RosterRow
@onready var _info_label: Label = %InfoLabel
@onready var _battle_label: Label = %BattleLabel
@onready var _back_button: Button = %BackButton
@onready var _continue_button: Button = %ContinueButton

## Spot (0-5) -> roster index.
var _formation: Dictionary = {}
## Selected roster index, or -1.
var _selected: int = -1
var _spot_slots: Dictionary = {}
var _chips: Dictionary = {}

func _ready() -> void:
	Game.ensure_run()
	Game.prepare_battle()
	_battle_label.text = "Battle %d/%d" % [Game.run.battle_index + 1, Tuning.BATTLES_PER_RUN]
	for child: Node in _player_grid.get_children():
		var slot: MonsterSlot = child as MonsterSlot
		_spot_slots[slot.spot] = slot
		slot.pressed.connect(_on_spot_pressed.bind(slot.spot))
	for child: Node in _enemy_grid.get_children():
		var enemy_slot: MonsterSlot = child as MonsterSlot
		var enemy_i: int = Game.enemy_spots.find(enemy_slot.spot)
		enemy_slot.set_monster(Game.enemy_team[enemy_i] if enemy_i >= 0 else null)
	for i: int in Game.run.roster.size():
		var monster: MonsterData = Game.run.roster[i]
		if monster.mushed:
			continue
		var chip: MonsterSlot = SLOT_SCENE.instantiate() as MonsterSlot
		chip.show_stats = true
		_roster_row.add_child(chip)
		chip.set_monster(monster, i)
		chip.pressed.connect(_on_chip_pressed.bind(i))
		_chips[i] = chip
	# Restore the last formation (drop mushed / out-of-range / duplicate entries).
	for key: Variant in Game.run.formation.keys():
		var ri: int = int(Game.run.formation[key])
		if _chips.has(ri) and not _formation.values().has(ri) and _formation.size() < Tuning.MAX_TEAM:
			_formation[int(key)] = ri
	if _formation.is_empty() and not _chips.is_empty():
		_formation[0] = int(_chips.keys()[0])
	_back_button.pressed.connect(_on_back_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_refresh()

func _on_back_pressed() -> void:
	_save()
	Game.go_to(&"hub")

func _on_chip_pressed(roster_index: int) -> void:
	_selected = -1 if _selected == roster_index else roster_index
	_refresh()

func _on_spot_pressed(spot: int) -> void:
	_info_label.text = ""
	if _selected < 0:
		_formation.erase(spot)  # click a placed monster to remove it
		_refresh()
		return
	var old_spot: int = _find_spot(_selected)
	var occupant: Variant = _formation.get(spot)
	if old_spot < 0 and occupant == null and _formation.size() >= Tuning.MAX_TEAM:
		_info_label.text = "Max %d monsters" % Tuning.MAX_TEAM
		return
	if old_spot >= 0:
		_formation.erase(old_spot)
		if occupant != null:
			_formation[old_spot] = occupant  # swap
	_formation[spot] = _selected
	_selected = -1
	_refresh()

func _on_continue_pressed() -> void:
	_save()
	Game.go_to(&"bet")

func _find_spot(roster_index: int) -> int:
	for key: Variant in _formation.keys():
		if int(_formation[key]) == roster_index:
			return int(key)
	return -1

func _save() -> void:
	Game.run.formation = _formation.duplicate()

func _refresh() -> void:
	for spot: int in _spot_slots.keys():
		var slot: MonsterSlot = _spot_slots[spot] as MonsterSlot
		var ri: int = int(_formation.get(spot, -1))
		slot.set_monster(Game.run.roster[ri] if ri >= 0 else null, ri)
		slot.set_selected(ri >= 0 and ri == _selected)
	for ri: int in _chips.keys():
		var chip: MonsterSlot = _chips[ri] as MonsterSlot
		chip.set_selected(ri == _selected)
		chip.set_tag("SET" if _find_spot(ri) >= 0 else "")
	var count: int = _formation.size()
	_continue_button.disabled = count < 1 or count > Tuning.MAX_TEAM
	if _info_label.text == "" or _info_label.text.begins_with("Place"):
		_info_label.text = "Place 1-%d monsters (%d placed)" % [Tuning.MAX_TEAM, count]
	_save()
