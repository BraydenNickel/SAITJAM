@tool
class_name AbVenom
extends AbilityData
## on_hit: apply venom stacks to the target (refreshes duration, capped).
## on_tick: the owner deals stacks * damage_per_second to each poisoned target
## once per second (ability damage, ignores DEF). Stacks live on the TARGET's
## state keyed by source, so several venomous units stack independently.

@export var stacks_per_hit: int = 1
@export var damage_per_second: float = 1.0
@export var duration: float = 5.0
@export var max_stacks: int = 5

func used_hooks() -> int:
	return Hook.HIT | Hook.TICK

func get_id() -> StringName:
	return &"venom"

func on_hit(ctx: BattleSim, _me: UnitState, hit: HitInfo) -> void:
	var t: UnitState = hit.target
	if t == null or not t.alive or t.hp <= 0:
		return
	var key: String = state_key(ctx)
	var v: Dictionary = t.state.get(key, {})
	if v.is_empty():
		v = {&"stacks": 0, &"remaining": 0.0, &"timer": 0.0}
		t.state[key] = v
	v[&"stacks"] = mini(max_stacks, int(v[&"stacks"]) + stacks_per_hit)
	v[&"remaining"] = duration

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	var key: String = state_key(ctx)
	for t: UnitState in ctx.units:
		if not t.alive or t.side == me.side or not t.state.has(key):
			continue
		var v: Dictionary = t.state[key]
		v[&"timer"] = float(v[&"timer"]) + delta
		v[&"remaining"] = float(v[&"remaining"]) - delta
		if float(v[&"timer"]) >= 1.0:
			v[&"timer"] = float(v[&"timer"]) - 1.0
			var dmg: int = roundi(int(v[&"stacks"]) * damage_per_second)
			if dmg > 0:
				ctx.deal_damage(me, t, dmg, true, get_id(), true, 1)
		if float(v[&"remaining"]) <= 0.0:
			t.state.erase(key)
		if ctx.finished or not me.alive:
			return

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["damage_per_second", "max_stacks"])
