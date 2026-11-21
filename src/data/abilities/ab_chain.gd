@tool
class_name AbChain
extends AbilityData
## on_hit: an own basic hit has `chance` to zap one other random living enemy
## for `damage` (ignores DEF).

@export_range(0.0, 1.0, 0.01) var chance: float = 0.3
@export var damage: float = 5.0

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"chain"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.from_hook or ctx.rng.randf() >= chance:
		return
	var depth: int = hit.depth + 1
	var t: UnitState = ctx.random_enemy(me, hit.target)
	if t == null:
		return
	announce(ctx, me)
	ctx.deal_damage(me, t, roundi(damage), true, get_id(), true, depth)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["chance", "damage"])
