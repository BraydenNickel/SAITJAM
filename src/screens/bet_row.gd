class_name BetRow
extends PanelContainer
## One bettable claim: toggle, description, probability, payout, stake.

## Emitted when the toggle or the stake changes.
signal changed(row: BetRow)

## Which claim this row bets on (one of BetOdds.CLAIMS).
@export var claim: StringName = &"victory"

@onready var _toggle: CheckBox = %Toggle
@onready var _desc_label: Label = %DescLabel
@onready var _prob_label: Label = %ProbLabel
@onready var _mult_label: Label = %MultLabel
@onready var _mvp_option: OptionButton = %MvpOption
@onready var _stake_spin: SpinBox = %StakeSpin

var _probs: Dictionary = {}
var _p: float = 0.0
var _mult: float = 0.0
var _max_stake: int = 0
var _is_mvp: bool = false

func _ready() -> void:
	_toggle.text = BetText.name_of(claim)
	_desc_label.text = BetText.description_of(claim)
	_toggle.toggled.connect(func(_on: bool) -> void: changed.emit(self))
	_stake_spin.value_changed.connect(func(_v: float) -> void: changed.emit(self))
	_mvp_option.item_selected.connect(_on_mvp_selected)
	_mvp_option.visible = false

## Configures a plain claim with win probability `p`.
func setup(p: float, max_stake: int) -> void:
	_is_mvp = false
	_probs = {}
	_p = p
	_max_stake = max_stake
	_refresh()

## Configures the MVP claim. `probs`: roster index -> probability,
## `names`: roster index -> display name.
func setup_mvp(probs: Dictionary, names: Dictionary, max_stake: int) -> void:
	_is_mvp = true
	_probs = probs
	_max_stake = max_stake
	_mvp_option.clear()
	var ids: Array = probs.keys()
	ids.sort()
	for id: Variant in ids:
		_mvp_option.add_item(String(names.get(id, "Monster")), int(id))
	_mvp_option.visible = _mvp_option.item_count > 0
	if _mvp_option.item_count > 0:
		_mvp_option.select(0)
	_update_mvp_p()
	_refresh()

## True if the player toggled this claim on.
func is_active() -> bool:
	return _toggle.button_pressed and not _toggle.disabled

## Programmatically switches the claim on/off (emits `changed`).
func set_active(active: bool) -> void:
	_toggle.button_pressed = active

## Stake in gold.
func stake() -> int:
	return int(_stake_spin.value)

## Payout multiplier (0.0 = unavailable).
func get_mult() -> float:
	return _mult

## Chosen roster index for the MVP claim, else -1.
func mvp_roster_idx() -> int:
	if _is_mvp and _mvp_option.item_count > 0:
		return _mvp_option.get_selected_id()
	return -1

## The bet dictionary stored in Game.bets.
func to_bet() -> Dictionary:
	return {&"claim": claim, &"stake": stake(), &"mult": _mult, &"mvp_roster_idx": mvp_roster_idx()}

func _on_mvp_selected(_index: int) -> void:
	_update_mvp_p()
	_refresh()
	changed.emit(self)

func _update_mvp_p() -> void:
	_p = float(_probs.get(_mvp_option.get_selected_id(), 0.0))

func _refresh() -> void:
	_mult = BetOdds.payout_mult(_p)
	_prob_label.text = "p = %d%%" % roundi(_p * 100.0)
	var available: bool = _mult > 0.0 and _max_stake >= Tuning.BET_MIN
	_mult_label.text = "x%.1f" % _mult if _mult > 0.0 else "n/a"
	_stake_spin.min_value = Tuning.BET_MIN
	_stake_spin.max_value = maxi(_max_stake, Tuning.BET_MIN)
	_stake_spin.step = 5
	_stake_spin.value = clampi(Tuning.BET_DEFAULT_STAKE, Tuning.BET_MIN, maxi(_max_stake, Tuning.BET_MIN))
	_stake_spin.editable = available
	_toggle.disabled = not available
	if not available:
		_toggle.set_pressed_no_signal(false)
	modulate = Color.WHITE if available else Color(1, 1, 1, 0.5)
