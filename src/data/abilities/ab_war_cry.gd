@tool
class_name AbWarCry
extends AbilityData
## on_battle_start: every living ally (not the owner) gains ATK, DEF and max HP.

@export var atk_bonus: float = 1.0
@export var def_bonus: float = 0.0
@export var hp_bonus: float = 0.0

func used_hooks() -> int:
	return Hook.BATTLE_START

func get_id() -> StringName:
	return &"war_cry"

func on_battle_start(ctx: BattleSim, me: UnitState) -> void:
	var hp_gain: int = roundi(hp_bonus)
	var any: bool = false
	for o: UnitState in ctx.units:
		if not o.alive or o.side != me.side or o == me:
			continue
		any = true
		o.atk += roundi(atk_bonus)
		o.defense += roundi(def_bonus)
		o.max_hp = maxi(1, o.max_hp + hp_gain)
		o.hp = clampi(o.hp + hp_gain, 1, o.max_hp)
	if any:
		announce(ctx, me)

## Params empowered() multiplies (design/fusion-contract.md §2).
func power_params() -> PackedStringArray:
	return PackedStringArray(["atk_bonus", "def_bonus", "hp_bonus"])
