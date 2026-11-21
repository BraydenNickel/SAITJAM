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

## Row (0 front, 1 middle, 2 back) of a formation spot.
static func row_of(spot: int) -> int:
	@warning_ignore("integer_division")
	return spot / Tuning.FORMATION_COLS
