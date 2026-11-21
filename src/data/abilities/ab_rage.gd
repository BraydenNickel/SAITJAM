@tool
class_name AbRage
extends AbilityData
## on_take_damage: each incoming basic attack adds a rage stack worth
## `atk_per_stack` ATK, up to `max_stacks`. Stacks live on the unit, per slot.

@export var atk_per_stack: float = 1.0
@export var max_stacks: int = 6

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"rage"

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.from_hook or hit.cancelled:
		return
	var key: String = state_key(ctx)
	var stacks: int = int(me.state.get(key, 0))
	if stacks >= max_stacks:
		return
	me.state[key] = stacks + 1
	# Difference of rounded totals, so a fractional atk_per_stack adds up exactly.
	me.atk += roundi(atk_per_stack * (stacks + 1)) - roundi(atk_per_stack * stacks)
	announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["atk_per_stack"])
