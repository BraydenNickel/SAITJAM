@tool
class_name AbCleave
extends AbilityData
## on_hit: an own basic hit splashes `fraction` of its damage onto every other
## living enemy in the target's formation row (their DEF applies, min 1).

@export_range(0.0, 1.0, 0.01) var fraction: float = 0.4

func used_hooks() -> int:
	return Hook.HIT

func get_id() -> StringName:
	return &"cleave"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var t: UnitState = hit.target
	if hit.from_hook or t == null:
		return
	var splash: int = roundi(hit.amount * fraction)
	if splash <= 0:
		return
	# Copy what we need: the pooled HitInfo is not ours to keep across deal_damage.
	var depth: int = hit.depth + 1
	@warning_ignore("integer_division")
	var row: int = t.spot / Tuning.FORMATION_COLS
	var announced: bool = false
	for o: UnitState in ctx.units:
		@warning_ignore("integer_division")
		if not o.alive or o.side == me.side or o == t or o.spot / Tuning.FORMATION_COLS != row:
			continue
		if not announced:
			announced = true
			announce(ctx, me)
		ctx.deal_damage(me, o, splash, true, get_id(), false, depth)
		if ctx.finished or not me.alive:
			return

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["fraction"])
