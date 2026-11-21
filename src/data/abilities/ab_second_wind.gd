@tool
class_name AbSecondWind
extends AbilityData
## on_take_damage: once per battle, a hit that would kill the owner is cancelled
## and the owner is healed to `heal_fraction` of max HP (at least 1 HP).

@export_range(0.0, 1.0, 0.01) var heal_fraction: float = 0.3

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"second_wind"

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.cancelled or hit.amount < me.hp:
		return
	var key: String = state_key(ctx)
	if me.state.has(key):
		return
	me.state[key] = true
	hit.cancelled = true
	announce(ctx, me)
	var target_hp: int = clampi(roundi(me.max_hp * heal_fraction), 1, me.max_hp)
	ctx.heal(me, target_hp - me.hp)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["heal_fraction"])
