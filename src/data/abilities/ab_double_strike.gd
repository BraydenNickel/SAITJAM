@tool
class_name AbDoubleStrike
extends AbilityData
## on_attack: every Nth attack strikes extra times. Counter lives on the unit,
## per slot, so two Mantis Arms each add their strikes (they stack).

@export var every_n: int = 3
@export var extra_strikes: int = 1

func used_hooks() -> int:
	return Hook.ATTACK

func get_id() -> StringName:
	return &"double_strike"

func on_attack(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var key: String = state_key(ctx)
	var count: int = int(me.state.get(key, 0)) + 1
	me.state[key] = count
	if every_n > 0 and count % every_n == 0:
		hit.extra_strikes += extra_strikes
		if ctx.emit_events:
			ctx.notify(&"ability", {&"unit": me.index, &"ability_id": get_id()})

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["extra_strikes"])

## Params empowered() divides (smaller is better).
func inverse_params() -> PackedStringArray:
	return PackedStringArray(["every_n"])
