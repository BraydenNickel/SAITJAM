@tool
class_name AbMomentum
extends AbilityData
## on_hit: each own basic hit adds `crit_per_hit` crit chance, up to `max_crit`
## bonus in total. The bonus gained so far lives on the unit, per slot.

@export_range(0.0, 1.0, 0.01) var crit_per_hit: float = 0.03
@export_range(0.0, 1.0, 0.01) var max_crit: float = 0.3

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"momentum"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.from_hook:
		return
	var key: String = state_key(ctx)
	var total: float = float(me.state.get(key, 0.0))
	var add: float = minf(crit_per_hit, max_crit - total)
	if add <= 0.0:
		return
	me.state[key] = total + add
	me.crit = minf(me.crit + add, 1.0)
	announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["crit_per_hit", "max_crit"])
