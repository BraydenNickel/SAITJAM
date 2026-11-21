@tool
class_name AbMend
extends AbilityData
## on_tick: every `interval` seconds, heal the living unit on the owner's side
## (allies or self) with the lowest HP fraction. Ties go to the lowest unit index.

@export var interval: float = 5.0
@export var amount: float = 10.0

func used_hooks() -> int:
	return Hook.TICK

func get_id() -> StringName:
	return &"mend"

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	if not tick_timer(ctx, me, delta, interval):
		return
	var best: UnitState = null
	var best_frac: float = 1.0
	for u: UnitState in ctx.units:
		if not u.alive or u.side != me.side:
			continue
		var frac: float = u.hp_fraction()
		if frac < best_frac:
			best_frac = frac
			best = u
	if best == null:
		return
	announce(ctx, me)
	ctx.heal(best, roundi(amount))

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["amount"])

## Params empowered() divides: none. A timed ability keeps its `interval` when
## empowered; scaling the amount and the rate together made Twin parts about
## 2.1x their parent (design/balance/stage4-balance.md, Pass 2).
func inverse_params() -> PackedStringArray:
	return PackedStringArray()
