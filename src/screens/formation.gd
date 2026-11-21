extends Control
## Formation screen: place 1-4 non-mushed monsters on the 6 spots, see the enemy.
## Placement works by drag and drop (roster card -> spot, spot -> spot, spot ->
## roster or anywhere off the grid to remove) or by click (monster, then spot).
## Every drop goes through the click path (_on_spot_pressed) so the rules live
## in one place.

const DRAG_HINT_PLACE: String = "Drop on a glowing spot"
const DRAG_HINT_REMOVE: String = "Drop on a spot to move, or on the roster to remove"

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
		slot.drag_enabled = true
		slot.drop_check = _can_drop_on_slot
		slot.dropped.connect(_on_slot_dropped.bind(slot))
	for child: Node in _enemy_grid.get_children():
		var enemy_slot: MonsterSlot = child as MonsterSlot
		var enemy_i: int = Game.enemy_spots.find(enemy_slot.spot)
		enemy_slot.set_monster(Game.enemy_team[enemy_i] if enemy_i >= 0 else null)
		# Dropping a placed monster on the enemy side counts as "off the grid".
		enemy_slot.drop_check = _can_drop_on_slot
		enemy_slot.dropped.connect(_on_slot_dropped.bind(enemy_slot))
	for i: int in Game.run.roster.size():
		var monster: MonsterData = Game.run.roster[i]
		if monster.mushed:
			continue
		var chip: MonsterSlot = SLOT_SCENE.instantiate() as MonsterSlot
		chip.show_stats = true
		_roster_row.add_child(chip)
		chip.set_monster(monster, i)
		chip.pressed.connect(_on_chip_pressed.bind(i))
		chip.drag_enabled = true
		chip.drop_check = _can_drop_on_slot
		chip.dropped.connect(_on_slot_dropped.bind(chip))
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_show_drop_targets(get_viewport().gui_get_drag_data())
	elif what == NOTIFICATION_DRAG_END:
		_show_drop_targets(null)

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
	if not _can_place(_selected, spot):
		_info_label.text = "Max %d monsters" % Tuning.MAX_TEAM
		return
	var occupant: Variant = _formation.get(spot)
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

## True if roster monster `roster_index` may go to `spot`: moving or swapping
## is always fine; a new monster needs a free team place unless it replaces
## the spot's occupant.
func _can_place(roster_index: int, spot: int) -> bool:
	if not _chips.has(roster_index) or not _spot_slots.has(spot):
		return false
	var placed: bool = _find_spot(roster_index) >= 0
	return placed or _formation.has(spot) or _formation.size() < Tuning.MAX_TEAM

# --- Drag and drop ------------------------------------------------------------

func _is_monster_drag(drag_data: Variant) -> bool:
	return drag_data is Dictionary and (drag_data as Dictionary).get(&"kind") == &"monster"

## Drop rule for every MonsterSlot on this screen (set as its drop_check).
## Player spots take any roster monster that _can_place allows (not its own
## spot); roster chips and enemy spots take a placed monster, which removes it.
func _can_drop_on_slot(slot: MonsterSlot, drag_data: Dictionary) -> bool:
	if not _is_monster_drag(drag_data):
		return false
	var ri: int = int(drag_data.get(&"roster_index", -1))
	var from_spot: int = int(drag_data.get(&"from_spot", -1))
	if _spot_slots.values().has(slot):
		return from_spot != slot.spot and _can_place(ri, slot.spot)
	return from_spot >= 0 and _formation.has(from_spot)

func _on_slot_dropped(drag_data: Dictionary, slot: MonsterSlot) -> void:
	if _spot_slots.values().has(slot):
		_selected = int(drag_data.get(&"roster_index", -1))
		_on_spot_pressed(slot.spot)
	else:
		_remove_dragged(drag_data)

## Dropping a placed monster anywhere off the grid (background, roster strip)
## removes it from the formation.
func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	return _is_monster_drag(drag_data) 		and _formation.has(int((drag_data as Dictionary).get(&"from_spot", -1)))

func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	_remove_dragged(drag_data as Dictionary)

func _remove_dragged(drag_data: Dictionary) -> void:
	_selected = -1
	_on_spot_pressed(int(drag_data.get(&"from_spot", -1)))

## Outlines every valid drop target for `drag_data` (null = clear them all).
func _show_drop_targets(drag_data: Variant) -> void:
	var dragging: bool = _is_monster_drag(drag_data)
	for slot: MonsterSlot in _spot_slots.values():
		slot.set_drop_highlight(dragging and _can_drop_on_slot(slot, drag_data))
	for chip: MonsterSlot in _chips.values():
		chip.set_drop_highlight(dragging and _can_drop_on_slot(chip, drag_data))
	if dragging:
		_selected = -1
		var placed: bool = int((drag_data as Dictionary).get(&"from_spot", -1)) >= 0
		_info_label.text = DRAG_HINT_REMOVE if placed else DRAG_HINT_PLACE
	elif _info_label.text == DRAG_HINT_PLACE or _info_label.text == DRAG_HINT_REMOVE:
		_info_label.text = ""
	_refresh()

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
