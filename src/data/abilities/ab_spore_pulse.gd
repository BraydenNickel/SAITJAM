@tool
class_name AbSporePulse
extends AbilityData
## on_tick: every `interval` seconds, damage all enemies ignoring DEF.
## The accumulated timer lives on the unit.

@export var interval: float = 4.0
@export var damage: float = 3.0

func used_hooks() -> int:
	return Hook.TICK

func get_id() -> StringName:
	return &"spore_pulse"

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	if interval <= 0.0:
		return
	var key: String = state_key(ctx)
	var t: float = float(me.state.get(key, 0.0)) + delta
	if t >= interval:
		t -= interval
		if ctx.emit_events:
			ctx.notify(&"ability", {&"unit": me.index, &"ability_id": get_id()})
		for e: UnitState in ctx.enemies_of(me):
			if ctx.finished or not me.alive:
				break
			ctx.deal_damage(me, e, roundi(damage), true, get_id(), true, 1)
	me.state[key] = t

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["damage"])

## Params empowered() divides: none. A timed ability keeps its `interval` when
## empowered; scaling the amount and the rate together made Twin parts about
## 2.1x their parent (design/balance/stage4-balance.md, Pass 2).
func inverse_params() -> PackedStringArray:
	return PackedStringArray()
