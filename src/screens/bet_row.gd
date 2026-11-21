class_name BetRow
extends PanelContainer
## One bettable claim: tick box + name, description, odds word + %, stake and
## the net outcome ("Win +Xg / Lose -Yg"). A row is unavailable when the claim
## is structurally impossible or the player cannot afford the minimum stake
## (a short reason is shown), and locked while the claim cap is reached.

## Emitted when the toggle, the stake or the MVP pick changes.
signal changed(row: BetRow)

## Which claim this row bets on (one of BetOdds.CLAIMS).
@export var claim: StringName = &"victory"

const COLOR_WIN: Color = Color(0.55, 1, 0.45)
const COLOR_LOSE: Color = Color(1, 0.45, 0.4)
const COLOR_REASON: Color = Color(1, 0.6, 0.3)
const COLOR_LOCKED: Color = Color(0.6, 0.7, 0.65)

@onready var _toggle: CheckBox = %Toggle
@onready var _desc_label: Label = %DescLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _odds_label: Label = %OddsLabel
@onready var _mvp_option: OptionButton = %MvpOption
@onready var _stake_spin: SpinBox = %StakeSpin
@onready var _win_label: Label = %WinLabel
@onready var _lose_label: Label = %LoseLabel

var _probs: Dictionary = {}
var _p: float = 0.0
var _mult: float = 0.0
var _max_stake: int = 0
var _is_mvp: bool = false
var _possible: bool = true
var _impossible_reason: String = ""
var _available: bool = false
var _locked: bool = false

func _ready() -> void:
	_toggle.text = BetText.name_of(claim)
	_desc_label.text = BetText.description_of(claim)
	_toggle.toggled.connect(func(_on: bool) -> void: changed.emit(self))
	_stake_spin.value_changed.connect(_on_stake_changed)
	_mvp_option.item_selected.connect(_on_mvp_selected)
	_mvp_option.visible = false
	_reason_label.visible = false

## Configures a plain claim with simulated win probability `p`. `possible`
## comes from BetOdds.claim_possible; `reason` is shown when it is false.
func setup(p: float, max_stake: int, possible: bool = true, reason: String = "") -> void:
	_is_mvp = false
	_probs = {}
	_p = p
	_max_stake = max_stake
	_possible = possible
	_impossible_reason = reason
	_reset_stake()
	_refresh()

## Configures the MVP claim. `probs`: roster index -> probability,
## `names`: roster index -> display name.
func setup_mvp(probs: Dictionary, names: Dictionary, max_stake: int) -> void:
	_is_mvp = true
	_probs = probs
	_max_stake = max_stake
	_possible = not probs.is_empty()
	_impossible_reason = BetText.impossible_reason(claim, probs.size())
	_mvp_option.clear()
	var ids: Array = probs.keys()
	ids.sort()
	for id: Variant in ids:
		_mvp_option.add_item(String(names.get(id, "Monster")), int(id))
	_mvp_option.visible = _mvp_option.item_count > 0
	if _mvp_option.item_count > 0:
		_mvp_option.select(0)
	_update_mvp_p()
	_reset_stake()
	_refresh()

## True if the player ticked this claim and it is bettable.
func is_active() -> bool:
	return _toggle.button_pressed and _available

## True if the claim can be bet on (possible and affordable), lock aside.
func is_available() -> bool:
	return _available

## Locks an unticked row while the claim cap is reached (shown, not hidden).
func set_locked(locked: bool) -> void:
	_locked = locked and not _toggle.button_pressed
	_refresh_state()

## Programmatically switches the claim on/off (emits `changed`).
func set_active(active: bool) -> void:
	_toggle.button_pressed = active

## Stake in gold.
func stake() -> int:
	return int(_stake_spin.value)

## Payout multiplier stored in the bet (0.0 = unavailable).
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

func _on_stake_changed(_value: float) -> void:
	_update_outcome()
	changed.emit(self)

func _update_mvp_p() -> void:
	_p = float(_probs.get(_mvp_option.get_selected_id(), 0.0))

func _reset_stake() -> void:
	var top: int = maxi(_max_stake, Tuning.BET_MIN)
	_stake_spin.min_value = Tuning.BET_MIN
	_stake_spin.max_value = top
	_stake_spin.step = 5
	_stake_spin.set_value_no_signal(clampi(Tuning.BET_DEFAULT_STAKE, Tuning.BET_MIN, top))

func _refresh() -> void:
	_mult = BetOdds.offered_mult(_p, _possible)
	_available = _possible and _max_stake >= Tuning.BET_MIN
	if _possible:
		_odds_label.text = BetText.odds_text(_p)
		_odds_label.add_theme_color_override("font_color", BetText.odds_color(_p))
		_odds_label.tooltip_text = "Won %s of the simulated fights. Pays x%.1f." % [
			BetText.percent_text(_p), _mult]
		if BetOdds.is_longshot(_p, _possible):
			_odds_label.tooltip_text = ("Never happened in the simulated fights, but it can."
				+ " Pays the maximum x%.1f." % _mult)
	else:
		_odds_label.text = "-"
		_odds_label.remove_theme_color_override("font_color")
		_odds_label.tooltip_text = ""
	if not _available:
		_toggle.set_pressed_no_signal(false)
	_update_outcome()
	_refresh_state()

func _update_outcome() -> void:
	var shown: bool = _possible
	_win_label.visible = shown
	_lose_label.visible = shown
	if shown:
		_win_label.text = "Win +%dg" % BetText.net_win(stake(), _mult)
		_lose_label.text = "Lose -%dg" % stake()

func _refresh_state() -> void:
	var reason: String = ""
	if not _possible:
		reason = _impossible_reason
	elif _max_stake < Tuning.BET_MIN:
		reason = "Not enough gold (min %dg stake)." % Tuning.BET_MIN
	elif _locked:
		reason = "Locked (%d picked). Untick one to swap." % Tuning.BET_MAX_CLAIMS
	_reason_label.text = reason
	_reason_label.visible = reason != ""
	_reason_label.add_theme_color_override("font_color", COLOR_LOCKED if _available else COLOR_REASON)
	_desc_label.visible = reason == ""
	_toggle.disabled = not _available or _locked
	_stake_spin.editable = _available
	_mvp_option.disabled = not _available
	modulate = Color.WHITE if (_available and not _locked) else Color(1, 1, 1, 0.55)
