@tool
class_name AbAmbush
extends AbilityData
## on_battle_start: deal `damage` (ignores DEF) to one random living enemy.

@export var damage: float = 12.0

func used_hooks() -> int:
	return Hook.BATTLE_START

func get_id() -> StringName:
	return &"ambush"

func on_battle_start(ctx: BattleSim, me: UnitState) -> void:
	var t: UnitState = ctx.random_enemy(me)
	if t == null:
		return
	announce(ctx, me)
	ctx.deal_damage(me, t, roundi(damage), true, get_id(), true, 1)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["damage"])
