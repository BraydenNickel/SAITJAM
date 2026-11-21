@tool
class_name AbVengeance
extends AbilityData
## on_ally_death: the owner gains `atk_bonus` ATK and heals itself for `heal`.

@export var atk_bonus: float = 2.0
@export var heal: float = 20.0

func used_hooks() -> int:
	return Hook.ALLY_DEATH

func get_id() -> StringName:
	return &"vengeance"

func on_ally_death(ctx: BattleSim, me: UnitState, _dead: UnitState) -> void:
	if not me.alive:
		return
	me.atk += roundi(atk_bonus)
	announce(ctx, me)
	ctx.heal(me, roundi(heal))

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["atk_bonus", "heal"])
