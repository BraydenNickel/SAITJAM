class_name SkillRow
extends PanelContainer
## One skill on the Skills screen: name, rank pips, the current and next bonus, and
## a buy button showing the next rank's cost ("MAX" when maxed). Reads SkillStore;
## the button is disabled when the player cannot afford the next rank.
##
## Add it to the tree first, then call setup(def, path). Call refresh() after any
## change to the store (another row bought, refund).

## Emitted after a rank of this skill was bought (the store is already saved).
signal bought(id: StringName)

const TEXT_BUY: String = "Buy: %d"
const TEXT_MAX: String = "MAX"
const TEXT_NEXT: String = "Next: %s"
const TEXT_MAXED: String = "Fully upgraded"

## Pip colour for an owned rank.
@export var pip_on_color: Color = Color(0.55, 1, 0.25, 1)
## Pip colour for a rank not bought yet.
@export var pip_off_color: Color = Color(0.12, 0.25, 0.2, 1)

## The Tuning.SKILLS id this row shows.
var skill_id: StringName = &""

var _def: Dictionary = {}
var _path: String = ""

@onready var _name_label: Label = %NameLabel
@onready var _desc_label: Label = %DescLabel
@onready var _next_label: Label = %NextLabel
@onready var _buy_button: Button = %BuyButton
@onready var _pips: Array[ColorRect] = [%Pip1, %Pip2, %Pip3, %Pip4]


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)


## Shows the skill `def` (a Tuning.SKILLS entry) read from the store at `path`.
func setup(def: Dictionary, path: String) -> void:
	_def = def
	_path = path
	skill_id = def[&"id"]
	_name_label.text = def[&"name"]
	if int(def[&"max_rank"]) > _pips.size():
		push_warning("SkillRow: %s has more ranks than pips in skill_row.tscn" % skill_id)
	refresh()


## Re-reads the rank, points and cost from the store and updates every label.
func refresh() -> void:
	if _def.is_empty():
		return
	var ranks: Dictionary = SkillStore.ranks(_path)
	var rank: int = int(ranks.get(skill_id, 0))
	var max_rank: int = int(_def[&"max_rank"])
	var desc: String = _def[&"desc"]
	for i: int in _pips.size():
		_pips[i].visible = i < max_rank
		_pips[i].color = pip_on_color if i < rank else pip_off_color
	_desc_label.text = desc % SkillEffects.value(ranks, skill_id)
	if rank >= max_rank:
		_next_label.text = TEXT_MAXED
		_buy_button.text = TEXT_MAX
		_buy_button.disabled = true
		return
	var next_ranks: Dictionary = ranks.duplicate()
	next_ranks[skill_id] = rank + 1
	_next_label.text = TEXT_NEXT % (desc % SkillEffects.value(next_ranks, skill_id))
	_buy_button.text = TEXT_BUY % SkillStore.next_cost(skill_id, _path)
	_buy_button.disabled = not SkillStore.can_buy(skill_id, _path)


## The skill's display name ("" before setup).
func skill_name() -> String:
	return _def.get(&"name", "")


## The buy button (for focus and the purchase effect position).
func buy_button() -> Button:
	return _buy_button


func _on_buy_pressed() -> void:
	if SkillStore.buy(skill_id, _path):
		bought.emit(skill_id)
	refresh()
