@tool
class_name AbCorrode
extends AbilityData
## on_hit: an own basic hit lowers the target's DEF by `def_per_hit`. The total
## corrosion on one target (from every source) is capped at `max_total`; it is
## tracked on the TARGET under STATE_KEY. DEF may go negative.

## Key in the target's UnitState.state holding its total DEF loss (float).
const STATE_KEY: String = "corrode"

@export var def_per_hit: float = 1.0
@export var max_total: float = 4.0

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"corrode"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var t: UnitState = hit.target
	if hit.from_hook or t == null or not t.alive or t.hp <= 0:
		return
	var total: float = float(t.state.get(STATE_KEY, 0.0))
	var add: float = minf(def_per_hit, max_total - total)
	if add <= 0.0:
		return
	t.state[STATE_KEY] = total + add
	# Difference of rounded totals, so a fractional def_per_hit adds up exactly.
	t.defense -= roundi(total + add) - roundi(total)
	announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["def_per_hit", "max_total"])
