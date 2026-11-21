class_name SkillEffects
extends RefCounted
## Pure helpers that turn a skill-ranks dictionary (StringName id -> int rank, as
## SkillStore.ranks() / RunState.skill_ranks hold it) into gameplay numbers
## (docs/superpowers/specs/2026-11-21-skill-points-design.md). Definitions and
## numbers live in Tuning.SKILLS.

## Graft skill id per MutationData.Rarity (COMMON, UNCOMMON, RARE). ULTRA has none.
const GRAFT_SKILLS: Array[StringName] = [&"common_graft", &"uncommon_graft", &"rare_graft"]

## The Tuning.SKILLS entry with this id, or {} if there is none.
static func skill_def(id: StringName) -> Dictionary:
	for def: Dictionary in Tuning.SKILLS:
		if def[&"id"] == id:
			return def
	return {}

## Total value of skill `id` for `ranks`: rank x per_rank (0 if unknown or unranked).
## Ranks are clamped to the skill's max_rank.
static func value(ranks: Dictionary, id: StringName) -> int:
	var def: Dictionary = skill_def(id)
	if def.is_empty():
		return 0
	var r: int = clampi(int(ranks.get(id, 0)), 0, int(def[&"max_rank"]))
	return r * int(def[&"per_rank"])

## Lab success % bonus for grafting a mutation of `rarity` (MutationData.Rarity).
## ULTRA grafts get no bonus.
static func graft_bonus(ranks: Dictionary, rarity: int) -> int:
	if rarity < 0 or rarity >= GRAFT_SKILLS.size():
		return 0
	return value(ranks, GRAFT_SKILLS[rarity])

## Incubator fusion success % bonus.
static func fusion_bonus(ranks: Dictionary) -> int:
	return value(ranks, &"steady_splice")

## Player-side BattleSim multipliers: {&"hp_mult", &"atk_mult", &"speed_mult"}
## (1.0 + percent / 100). Empty ranks give all 1.0.
static func combat_mods(ranks: Dictionary) -> Dictionary:
	return {
		&"hp_mult": 1.0 + value(ranks, &"thick_hide") / 100.0,
		&"atk_mult": 1.0 + value(ranks, &"sharp_claws") / 100.0,
		&"speed_mult": 1.0 + value(ranks, &"adrenaline") / 100.0,
	}
