@tool
class_name AbDodge
extends AbilityData
## on_take_damage: chance to completely cancel an incoming basic attack.
## Ability damage (spores, venom, reflect) cannot be dodged.

@export_range(0.0, 1.0, 0.01) var chance: float = 0.12

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"dodge"

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.from_hook or hit.cancelled:
		return
	if ctx.rng.randf() < chance:
		hit.cancelled = true
		if ctx.emit_events:
			ctx.notify(&"dodge", {&"dst": me.index})
			ctx.notify(&"ability", {&"unit": me.index, &"ability_id": get_id()})

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["chance"])
