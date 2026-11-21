@tool
class_name AbTitan
extends AbilityData
## ULTRA. on_take_damage: all damage taken is multiplied by (1 - damage_reduction)
## (min 1). on_tick: every `stomp_interval` seconds, stomp every living enemy in
## the front-most enemy row for `stomp_damage` (their DEF applies).

@export_range(0.0, 1.0, 0.01) var damage_reduction: float = 0.2
@export var stomp_interval: float = 5.0
@export var stomp_damage: float = 6.0

func used_hooks() -> int:
	return Hook.TAKE_DAMAGE | Hook.TICK

func get_id() -> StringName:
	return &"titan"

func on_take_damage(_ctx: BattleSim, _me: UnitState, hit: HitInfo) -> void:
	if hit.cancelled or hit.amount <= 0:
		return
	hit.amount = maxi(1, roundi(hit.amount * (1.0 - damage_reduction)))

func on_tick(ctx: BattleSim, me: UnitState, delta: float) -> void:
	if not tick_timer(ctx, me, delta, stomp_interval):
		return
	var row: int = ctx.front_enemy_row(me)
	if row < 0:
		return
	announce(ctx, me)
	for o: UnitState in ctx.units:
		@warning_ignore("integer_division")
		if not o.alive or o.side == me.side or o.spot / Tuning.FORMATION_COLS != row:
			continue
		ctx.deal_damage(me, o, roundi(stomp_damage), true, get_id(), false, 1)
		if ctx.finished or not me.alive:
			return

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["damage_reduction", "stomp_damage"])

## Params empowered() divides: none. A timed ability keeps its `stomp_interval` when
## empowered; scaling the amount and the rate together made Twin parts about
## 2.1x their parent (design/balance/stage4-balance.md, Pass 2).
func inverse_params() -> PackedStringArray:
	return PackedStringArray()
