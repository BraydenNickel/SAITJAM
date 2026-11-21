@tool
class_name AbBurn
extends AbilityData
## on_hit: an own basic hit sets the target on fire for `duration` seconds
## (refreshes, never stacks: one burn per target, owned by the last igniter).
## on_tick: the owner deals `fraction` of the TARGET's max HP once per second
## (min 1, ignores DEF). The burn lives on the TARGET under STATE_KEY.

## Key in the target's UnitState.state holding its burn
## {remaining: float, timer: float, owner: String (the igniter's state key)}.
const STATE_KEY: String = "burn"
## Seconds between burn damage ticks.
const TICK_SECONDS: float = 1.0

@export_range(0.0, 1.0, 0.001) var fraction: float = 0.01
@export var duration: float = 4.0

func used_hooks() -> int:
	return Hook.HIT | Hook.TICK

func get_id() -> StringName:
	return &"burn"

func on_hit(ctx: BattleSim, me: UnitState, hit: HitInfo) -> void:
	var t: UnitState = hit.target
	if hit.from_hook or t == null or not t.alive or t.hp <= 0:
		return
	var b: Dictionary = t.state.get(STATE_KEY, {})
	if b.is_empty():
		b = {&"remaining": 0.0, &"timer": 0.0, &"owner": ""}
		t.state[STATE_KEY] = b
		announce(ctx, me)
	b[&"remaining"] = duration
	b[&"owner"] = state_key(ctx)

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	var key: String = state_key(ctx)
	for t: UnitState in ctx.units:
		if not t.alive or t.side == me.side or not t.state.has(STATE_KEY):
			continue
		var b: Dictionary = t.state[STATE_KEY]
		if String(b[&"owner"]) != key:
			continue
		b[&"timer"] = float(b[&"timer"]) + delta
		b[&"remaining"] = float(b[&"remaining"]) - delta
		if float(b[&"timer"]) >= TICK_SECONDS:
			b[&"timer"] = float(b[&"timer"]) - TICK_SECONDS
			ctx.deal_damage(me, t, maxi(1, roundi(t.max_hp * fraction)), true, get_id(), true, 1)
		if float(b[&"remaining"]) <= 0.0:
			t.state.erase(STATE_KEY)
		if ctx.finished or not me.alive:
			return

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["fraction"])
