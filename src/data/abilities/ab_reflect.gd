@tool
class_name AbReflect
extends AbilityData
## on_take_damage: chance to reflect flat damage (ignores DEF) at the attacker.
## Only reacts to basic attacks, so reflect can never ping-pong.

@export_range(0.0, 1.0, 0.01) var chance: float = 0.25
@export var damage: float = 4.0

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE

func get_id() -> StringName:
	return &"reflect"

func on_take_damage(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	if hit.from_hook or hit.cancelled or hit.source == null or not hit.source.alive:
		return
	if ctx.rng.randf() < chance:
		if ctx.emit_events:
			ctx.notify(&"ability", {&"unit": me.index, &"ability_id": get_id()})
		ctx.deal_damage(me, hit.source, roundi(damage), true, get_id(), true, hit.depth + 1)
