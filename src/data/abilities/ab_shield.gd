@tool
class_name AbShield
extends AbilityData
## on_battle_start: gain a shield of `amount`. on_take_damage: the shield absorbs
## incoming damage (any source) before HP. The remaining shield (int) lives on
## the unit at this ability's state key.

@export var amount: float = 40.0

func used_hooks() -> int:
	return Hook.BATTLE_START | Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"shield"

func on_battle_start(ctx: BattleSim, me: UnitState) -> void:
	me.state[state_key(ctx)] = roundi(amount)
	announce(ctx, me)

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.cancelled or hit.amount <= 0:
		return
	var key: String = state_key(ctx)
	var left: int = int(me.state.get(key, 0))
	if left <= 0:
		return
	var absorbed: int = mini(left, hit.amount)
	hit.amount -= absorbed
	me.state[key] = left - absorbed
	announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["amount"])
