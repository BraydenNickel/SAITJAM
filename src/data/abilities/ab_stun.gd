@tool
class_name AbStun
extends AbilityData
## on_hit: an own basic hit has `chance` to push the target's attack timer back
## by `delay` seconds (never below -delay, so stuns cannot chain into a lock).

@export_range(0.0, 1.0, 0.01) var chance: float = 0.15
@export var delay: float = 0.8

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"stun"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var t: UnitState = hit.target
	if hit.from_hook or t == null or not t.alive or t.hp <= 0:
		return
	if ctx.rng.randf() < chance:
		t.attack_timer = maxf(t.attack_timer - delay, -delay)
		announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["chance", "delay"])
