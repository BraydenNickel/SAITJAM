@tool
class_name AbExecute
extends AbilityData
## on_hit: an own basic hit that leaves the target alive under `threshold` HP
## fraction deals `bonus` extra damage (ignores DEF).

@export_range(0.0, 1.0, 0.01) var threshold: float = 0.25
@export var bonus: float = 8.0

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"execute"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var t: UnitState = hit.target
	if hit.from_hook or t == null or not t.alive or t.hp <= 0:
		return
	if t.hp_fraction() >= threshold:
		return
	announce(ctx, me)
	ctx.deal_damage(me, t, roundi(bonus), true, get_id(), true, hit.depth + 1)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["threshold", "bonus"])
