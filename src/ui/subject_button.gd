class_name SubjectButton
extends Button
## Toggle button for picking a roster monster in the Lab: small front preview,
## name, instability and mutation count.

@onready var _view: MonsterView = %MonsterView
@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel

## The monster shown.
var monster: MonsterData
## Index of the monster in RunState.roster.
var roster_index: int = -1

func _ready() -> void:
	_apply()

## Shows `m` (roster index `index`). Safe to call before entering the tree.
func setup(m: MonsterData, index: int) -> void:
	monster = m
	roster_index = index
	if is_node_ready():
		_apply()

## Redraws after the monster changed (new mutation, purge, ...).
func refresh() -> void:
	_apply()

func _apply() -> void:
	if monster == null:
		return
	_view.data = monster
	_view.refresh()
	_name_label.text = monster.display_name
	_info_label.text = "Instab %d  |  %d/%d slots" % [roundi(monster.instability),
		monster.slots.size(), MonsterData.SLOTS.size()]
