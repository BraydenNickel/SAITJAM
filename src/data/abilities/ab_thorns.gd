@tool
class_name AbThorns
extends AbilityData
## on_take_damage: every incoming basic attack deals flat damage (ignores DEF)
## back to the attacker. Only reacts to basic attacks, so it can never ping-pong.

@export var damage: float = 2.0

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"thorns"

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.from_hook or hit.cancelled or hit.source == null or not hit.source.alive:
		return
	announce(ctx, me)
	ctx.deal_damage(me, hit.source, roundi(damage), true, get_id(), true, hit.depth + 1)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["damage"])
