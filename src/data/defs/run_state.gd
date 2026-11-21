class_name RunState
extends Resource
## All mutable state of one run (one life, Tuning.BATTLES_PER_RUN battles).

@export var rng_seed: int = 0
@export var battle_index: int = 0
@export var gold: int = 0
@export var roster: Array[MonsterData] = []
## Formation spot (0-5) -> roster index. Spots 0-1 front, 2-3 middle, 4-5 back.
@export var formation: Dictionary = {}
@export var stabilizers: int = 0
## Mutation ids the player has discovered.
@export var codex: Array[StringName] = []

# --- Stage 3: Lab, Shop, Rewards ---
## Owned mutations not yet applied to a monster.
@export var inventory: Array[MutationData] = []
## Percent bonus pending for the next lab operation (set by a mush).
@export var mush_memory: int = 0
## One-shot reward buffs, consumed by the next lab operation.
@export var lucky_gene: bool = false
@export var insurance: bool = false
@export var catalyst: bool = false
## Current shop entries: {kind, mutation, price, sold}. See ShopLogic.
@export var shop_stock: Array[Dictionary] = []
## battle_index the stock was rolled for (-1 = never).
@export var shop_stock_battle: int = -1
@export var reroll_count: int = 0
@export var shop_visits_since_rare: int = 0

# --- Fusion (design/fusion-contract.md) ---
## Ids (pair keys, e.g. "ember_horns+leech_maw") of fused parts made this run.
@export var fusion_codex: Array[String] = []
## Titles of incubated monsters made this run.
@export var fusion_titles: Array[String] = []

## Number of roster monsters that are not mush.
func living_count() -> int:
	var n: int = 0
	for m: MonsterData in roster:
		if m != null and not m.mushed:
			n += 1
	return n

## Row (0 front, 1 middle, 2 back) of a formation spot.
static func row_of(spot: int) -> int:
	@warning_ignore("integer_division")
	return spot / Tuning.FORMATION_COLS
