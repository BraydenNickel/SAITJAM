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

## Key into UnitState.state unique to (owner unit, this ability, current slot).
func state_key(ctx: BattleSim) -> String:
	return ctx.current_key

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
