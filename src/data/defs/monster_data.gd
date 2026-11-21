@tool
class_name MonsterData
extends Resource
## One monster: a base human plus mutations in body slots.

## All body slots, in display order.
const SLOTS: Array[StringName] = [
	&"HEAD", &"TORSO", &"BACK", &"ARM_L", &"ARM_R", &"LEG_L", &"LEG_R", &"TAIL",
]
## Socket type each body slot accepts.
const SLOT_SOCKET: Dictionary = {
	&"HEAD": MutationData.SocketType.HEAD,
	&"TORSO": MutationData.SocketType.TORSO,
	&"BACK": MutationData.SocketType.BACK,
	&"ARM_L": MutationData.SocketType.ARM,
	&"ARM_R": MutationData.SocketType.ARM,
	&"LEG_L": MutationData.SocketType.LEG,
	&"LEG_R": MutationData.SocketType.LEG,
	&"TAIL": MutationData.SocketType.TAIL,
}

@export var display_name: String = "Subject"
@export var base_kind: StringName = &"human"
@export var title: String = ""

@export_group("Base stats")
@export var base_hp: float = Tuning.BASE_HP
@export var base_atk: float = Tuning.BASE_ATK
@export var base_interval: float = Tuning.BASE_INTERVAL
@export var base_defense: float = Tuning.BASE_DEF
@export var base_crit: float = Tuning.BASE_CRIT

@export_group("Mutations")
## Slot name (StringName, one of SLOTS) -> MutationData.
@export var slots: Dictionary = {}
@export_range(0.0, 100.0, 1.0) var instability: float = 0.0
@export var mushed: bool = false
@export var fused: bool = false

## Final stats: base + all mutation modifiers. Keys: hp, atk, attack_interval,
## defense, crit (all floats).
func get_total_stats() -> Dictionary:
	var hp: float = base_hp
	var atk: float = base_atk
	var interval: float = base_interval
	var defense: float = base_defense
	var crit: float = base_crit
	for value: Variant in slots.values():
		var m: MutationData = value as MutationData
		if m == null:
			continue
		hp += m.hp_mod
		atk += m.atk_mod
		interval += m.interval_mod
		defense += m.defense_mod
		crit += m.crit_mod
	return {
		&"hp": maxf(hp, 1.0),
		&"atk": maxf(atk, 0.0),
		&"attack_interval": maxf(interval, Tuning.MIN_INTERVAL),
		&"defense": defense,
		&"crit": clampf(crit, 0.0, 1.0),
	}

## True if `mutation` fits `slot` by socket type and the slot is empty.
func can_apply(mutation: MutationData, slot: StringName) -> bool:
	if mutation == null or not SLOT_SOCKET.has(slot):
		return false
	if SLOT_SOCKET[slot] != mutation.socket_type:
		return false
	return slots.get(slot) == null

## All currently free slots `mutation` could go into (e.g. ARM -> ARM_L, ARM_R).
func slots_for(mutation: MutationData) -> Array[StringName]:
	var result: Array[StringName] = []
	for slot: StringName in SLOTS:
		if can_apply(mutation, slot):
			result.append(slot)
	return result

## Puts `mutation` into `slot` if allowed. Returns true on success.
## Does not change instability; callers own that rule.
func apply_mutation(mutation: MutationData, slot: StringName) -> bool:
	if not can_apply(mutation, slot):
		return false
	slots[slot] = mutation
	emit_changed()
	return true

## Independent copy (own slots dictionary; mutation resources are shared).
func clone() -> MonsterData:
	var copy: MonsterData = duplicate() as MonsterData
	copy.slots = slots.duplicate()
	return copy
