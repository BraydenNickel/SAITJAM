@tool
class_name AbPhase
extends AbilityData
## ULTRA. on_take_damage: `chance` to cancel ANY incoming hit (basic or ability;
## the sim never offers a unit its own ability's damage). On a cancel the source
## takes `counter` damage (its DEF applies).

@export_range(0.0, 1.0, 0.01) var chance: float = 0.25
@export var counter: float = 6.0

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"phase"

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.cancelled or ctx.rng.randf() >= chance:
		return
	hit.cancelled = true
	if ctx.emit_events:
		ctx.notify(&"dodge", {&"dst": me.index})
	announce(ctx, me)
	var src: UnitState = hit.source
	if src != null and src.alive and src != me:
		ctx.deal_damage(me, src, roundi(counter), true, get_id(), false, hit.depth + 1)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["chance", "counter"])
