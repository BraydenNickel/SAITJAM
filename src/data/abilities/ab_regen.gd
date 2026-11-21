@tool
class_name AbRegen
extends AbilityData
## on_tick: every `interval` seconds the owner heals itself for `amount`.

@export var interval: float = 3.0
@export var amount: float = 6.0

func used_hooks() -> int:
	return Hook.TICK

func get_id() -> StringName:
	return &"regen"

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	if not tick_timer(ctx, me, delta, interval) or me.hp >= me.max_hp:
		return
	announce(ctx, me)
	ctx.heal(me, roundi(amount))

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["amount"])

## Params empowered() divides: none. A timed ability keeps its `interval` when
## empowered; scaling the amount and the rate together made Twin parts about
## 2.1x their parent (design/balance/stage4-balance.md, Pass 2).
func inverse_params() -> PackedStringArray:
	return PackedStringArray()
