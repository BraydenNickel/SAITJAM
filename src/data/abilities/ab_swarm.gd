@tool
class_name AbSwarm
extends AbilityData
## ULTRA. on_tick: every `interval` seconds, damage one random living enemy for
## `damage` (its DEF applies) and heal the owner for `heal`.

@export var interval: float = 2.5
@export var damage: float = 3.0
@export var heal: float = 2.0

func used_hooks() -> int:
	return Hook.TICK

func get_id() -> StringName:
	return &"swarm"

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	if not tick_timer(ctx, me, delta, interval):
		return
	var t: UnitState = ctx.random_enemy(me)
	if t == null:
		return
	announce(ctx, me)
	ctx.deal_damage(me, t, roundi(damage), true, get_id(), false, 1)
	if me.alive:
		ctx.heal(me, roundi(heal))

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["damage", "heal"])

## Params empowered() divides: none. A timed ability keeps its `interval` when
## empowered; scaling the amount and the rate together made Twin parts about
## 2.1x their parent (design/balance/stage4-balance.md, Pass 2).
func inverse_params() -> PackedStringArray:
	return PackedStringArray()
