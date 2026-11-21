@tool
class_name AbLifesteal
extends AbilityData
## on_hit: heal the owner for a fraction of the damage dealt.

@export_range(0.0, 1.0, 0.01) var fraction: float = 0.25

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"lifesteal"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var amount: int = roundi(hit.amount * fraction)
	if amount > 0 and me.hp < me.max_hp:
		ctx.heal(me, amount)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["fraction"])
