@tool
class_name AbilityData
extends Resource
## Base class for mutation abilities. Abilities are STATELESS data + hook logic;
## any per-unit state (counters, timers, stacks) lives in UnitState.state.
## `ctx` is the running BattleSim; ctx.current_slot is the body slot being
## dispatched, so one shared resource in two slots keeps separate state.

## Optional pixelfx json played when the ability triggers.
@export_file("*.json") var fx_json: String = ""

## Hook bits for used_hooks(): the sim only dispatches hooks an ability uses.
enum Hook { BATTLE_START = 1, TICK = 2, ATTACK = 4, HIT = 8, TAKE_DAMAGE = 16, ALLY_DEATH = 32 }
const ALL_HOOKS: int = 63

## Bitmask of Hook values this ability implements. Default: all (always safe);
## override to skip no-op dispatch in the hot loop.
func used_hooks() -> int:
	return ALL_HOOKS

## Stable ability id used in events and the hook re-trigger guard.
func get_id() -> StringName:
	return &""

## Names of exported numeric params where bigger is better (damage, chance,
## heal...). empowered() multiplies them. Override per ability.
func power_params() -> PackedStringArray:
	return PackedStringArray()

## Names of exported numeric params where smaller is better (own interval or
## cooldown). empowered() divides them. Override per ability.
func inverse_params() -> PackedStringArray:
	return PackedStringArray()

## Param name -> highest value empowered() may produce. The default covers the
## shared names (chance, damage_reduction, fractions); override to add more.
func param_caps() -> Dictionary:
	return {
		&"chance": Tuning.EMPOWER_MAX_CHANCE,
		&"damage_reduction": Tuning.EMPOWER_MAX_REDUCTION,
		&"fraction": Tuning.EMPOWER_MAX_FRACTION,
		&"heal_fraction": Tuning.EMPOWER_MAX_FRACTION,
		&"threshold": Tuning.EMPOWER_MAX_FRACTION,
		&"max_crit": Tuning.EMPOWER_MAX_FRACTION,
		&"crit_per_hit": Tuning.EMPOWER_MAX_FRACTION,
	}

## A stronger copy of this ability (design/fusion-contract.md §1, Twin fusions):
## power_params() are multiplied by `mult`, inverse_params() divided by it, then
## capped by param_caps(). Int params stay ints, rounded up (never below 1 when
## divided). This resource is never changed; `mult` <= 0 returns a plain copy.
func empowered(mult: float) -> AbilityData:
	var copy: AbilityData = duplicate() as AbilityData
	if mult <= 0.0:
		return copy
	var caps: Dictionary = param_caps()
	for pname: String in power_params():
		_scale_param(copy, StringName(pname), mult, caps)
	for pname: String in inverse_params():
		_scale_param(copy, StringName(pname), 1.0 / mult, caps)
	return copy

## Rounding slack so 4.0000001 does not round up to 5.
const _CEIL_EPSILON: float = 0.00001

func _scale_param(copy: AbilityData, pname: StringName, factor: float, caps: Dictionary) -> void:
	var value: Variant = get(pname)
	if typeof(value) == TYPE_INT:
		var scaled_int: int = maxi(1, ceili(float(value) * factor - _CEIL_EPSILON)) \
			if int(value) > 0 else int(value)
		if caps.has(pname):
			scaled_int = mini(scaled_int, int(caps[pname]))
		copy.set(pname, scaled_int)
	elif typeof(value) == TYPE_FLOAT:
		var scaled: float = float(value) * factor
		if caps.has(pname):
			scaled = minf(scaled, float(caps[pname]))
		copy.set(pname, scaled)

## Key into UnitState.state unique to (owner unit, this ability, current slot).
func state_key(ctx: BattleSim) -> String:
	return ctx.current_key

## Emits the &"ability" event for `me` (no-op in headless sims). Call when the
## ability visibly triggers.
func announce(ctx: BattleSim, me: UnitState) -> void:
	if ctx.emit_events:
		ctx.notify(&"ability", {&"unit": me.index, &"ability_id": get_id()})

## Advances this ability's per-unit timer (stored at state_key) by `delta` and
## returns true each time `interval` seconds have accumulated.
func tick_timer(ctx: BattleSim, me: UnitState, delta: float, interval: float) -> bool:
	if interval <= 0.0:
		return false
	var key: String = ctx.current_key
	var t: float = float(me.state.get(key, 0.0)) + delta
	var fired: bool = t >= interval
	if fired:
		t -= interval
	me.state[key] = t
	return fired

## Called once when the battle starts.
func on_battle_start(_ctx: BattleSim, _me: UnitState) -> void:
	pass

## Called every simulation tick with the elapsed time.
func on_tick(_ctx: BattleSim, _me: UnitState, _delta: float) -> void:
	pass

## Called when the owner is about to attack (before damage is dealt).
## Set hit.extra_strikes to strike more than once.
func on_attack(_ctx: BattleSim, _me: UnitState, _hit: HitInfo) -> void:
	pass

## Called after the owner's hit lands (basic attacks and depth-1 hook damage).
func on_hit(_ctx: BattleSim, _me: UnitState, _hit: HitInfo) -> void:
	pass

## Called when the owner is about to take damage. May cancel or modify the hit.
func on_take_damage(_ctx: BattleSim, _me: UnitState, _hit: HitInfo) -> void:
	pass

## Called when an ally of the owner dies.
func on_ally_death(_ctx: BattleSim, _me: UnitState, _dead: UnitState) -> void:
	pass
