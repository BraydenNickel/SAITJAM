@tool
class_name MutationData
extends Resource
## Definition of one mutation (body part + stat modifiers + ability).
## One .tres per mutation in src/data/mutations/.

## Which kind of socket this mutation fits. ARM fits ARM_L/ARM_R, LEG fits LEG_L/LEG_R.
enum SocketType { HEAD, TORSO, BACK, ARM, LEG, TAIL }
enum Rarity { COMMON, UNCOMMON, RARE, ULTRA }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var socket_type: SocketType = SocketType.TORSO
@export var rarity: Rarity = Rarity.COMMON

@export_group("Art")
@export var sprite_front: Texture2D
@export var sprite_side: Texture2D

@export_group("Body override")
## ULTRA only (design/balance/stage4-mutations.md section 1). Replaces the 64x64
## torso sprite in the front view; null keeps the default body.
@export var body_front: Texture2D
## Same for the side view.
@export var body_side: Texture2D
## Modulate on the body sprite (parts keep their own colour).
@export var body_tint: Color = Color.WHITE
## Scale of the whole MonsterView.
@export var body_scale: float = 1.0
## Looping pixelfx json played behind the monster ("" = none).
@export_file("*.json") var aura_fx: String = ""

@export_group("Stat modifiers")
@export var hp_mod: float = 0.0
@export var atk_mod: float = 0.0
## Added to attack interval (negative = faster).
@export var interval_mod: float = 0.0
@export var defense_mod: float = 0.0
@export var crit_mod: float = 0.0

@export_group("Behaviour")
@export var tags: Array[StringName] = []
@export var ability: AbilityData

@export_group("Fusion")
## 0 = base mutation, 1 = hybrid or twin, 2 = apex (design/fusion-contract.md §1).
@export var merge_count: int = 0
## Base source ids, sorted; 2 (hybrid/twin) or 3 (apex) entries. Empty for a base mutation.
@export var parent_ids: Array[StringName] = []
## Abilities beyond `ability` (fused mutations only). See all_abilities().
@export var extra_abilities: Array[AbilityData] = []
## Budget cost of a fused mutation; 0 = use Tuning.BUDGET_COST[rarity].
@export var fused_cost: int = 0
## True for a signature fusion (bespoke name, art and full stats).
@export var signature: bool = false
## One description sentence per entry of all_abilities() (fused mutations only;
## written by FusionLogic so an apex can rebuild its text).
@export var ability_texts: Array[String] = []

## Every ability this mutation carries: `ability` (if set) followed by
## `extra_abilities` (nulls skipped). A base mutation returns 0 or 1 entries.
func all_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	if ability != null:
		result.append(ability)
	for extra: AbilityData in extra_abilities:
		if extra != null:
			result.append(extra)
	return result

## True if this mutation changes the body sprite, tint, scale or adds an aura.
func overrides_body() -> bool:
	return body_front != null or body_side != null or body_tint != Color.WHITE \
		or not is_equal_approx(body_scale, 1.0) or aura_fx != ""
