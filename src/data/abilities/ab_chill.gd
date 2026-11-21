@tool
class_name AbChill
extends AbilityData
## on_hit: an own basic hit adds `slow_per_hit` seconds to the target's
## attack_interval. The total chill on one target (from every source) is capped
## at `max_slow`; it is tracked on the TARGET under STATE_KEY.

## Key in the target's UnitState.state holding its total chill slow (float).
const STATE_KEY: String = "chill"

@export var slow_per_hit: float = 0.05
@export var max_slow: float = 0.4

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"chill"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var t: UnitState = hit.target
	if hit.from_hook or t == null or not t.alive or t.hp <= 0:
		return
	var total: float = float(t.state.get(STATE_KEY, 0.0))
	var add: float = minf(slow_per_hit, max_slow - total)
	if add <= 0.0:
		return
	t.state[STATE_KEY] = total + add
	t.attack_interval += add
	announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["slow_per_hit", "max_slow"])
