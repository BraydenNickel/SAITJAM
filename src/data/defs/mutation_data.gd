@tool
class_name MutationData
extends Resource
## Definition of one mutation (body part + stat modifiers + ability).
## One .tres per mutation in src/data/mutations/.

## Which kind of socket this mutation fits. ARM fits ARM_L/ARM_R, LEG fits LEG_L/LEG_R.
enum SocketType { HEAD, TORSO, BACK, ARM, LEG, TAIL }
enum Rarity { COMMON, UNCOMMON, RARE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var socket_type: SocketType = SocketType.TORSO
@export var rarity: Rarity = Rarity.COMMON

@export_group("Art")
@export var sprite_front: Texture2D
@export var sprite_side: Texture2D

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
