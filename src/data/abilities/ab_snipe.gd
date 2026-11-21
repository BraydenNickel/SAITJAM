@tool
class_name AbSnipe
extends AbilityData
## on_tick: every `interval` seconds, damage the living enemy with the lowest HP
## anywhere on the board (ignores DEF and rows). Ties go to the lowest unit index.

@export var interval: float = 4.0
@export var damage: float = 6.0

func used_hooks() -> int:
	return Hook.TICK

func get_id() -> StringName:
	return &"snipe"

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	if not tick_timer(ctx, me, delta, interval):
		return
	var best: UnitState = null
	for o: UnitState in ctx.units:
		if o.alive and o.side != me.side and (best == null or o.hp < best.hp):
			best = o
	if best == null:
		return
	announce(ctx, me)
	ctx.deal_damage(me, best, roundi(damage), true, get_id(), true, 1)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["damage"])

## Params empowered() divides: none. A timed ability keeps its `interval` when
## empowered; scaling the amount and the rate together made Twin parts about
## 2.1x their parent (design/balance/stage4-balance.md, Pass 2).
func inverse_params() -> PackedStringArray:
	return PackedStringArray()
