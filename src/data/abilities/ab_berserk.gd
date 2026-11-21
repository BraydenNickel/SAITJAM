@tool
class_name AbBerserk
extends AbilityData
## on_take_damage: once per battle, when a hit will leave the owner alive under
## `threshold` HP fraction, attack_interval is multiplied by `interval_mult`
## (never below Tuning.MIN_INTERVAL).

@export_range(0.0, 1.0, 0.01) var threshold: float = 0.5
@export_range(0.05, 1.0, 0.01) var interval_mult: float = 0.7

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"berserk"

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.cancelled:
		return
	var key: String = state_key(ctx)
	if me.state.has(key):
		return
	var after: int = me.hp - maxi(hit.amount, 0)
	if after <= 0 or float(after) >= threshold * float(me.max_hp):
		return
	me.state[key] = true
	me.attack_interval = maxf(me.attack_interval * interval_mult, Tuning.MIN_INTERVAL)
	announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["threshold"])

## Params empowered() divides (smaller is better).
func inverse_params() -> PackedStringArray:
	return PackedStringArray(["interval_mult"])
