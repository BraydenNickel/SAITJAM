class_name UnitState
extends RefCounted
## Runtime state of one monster inside a BattleSim (stage 2, design/jam-plan.md
## "CHOSEN DESIGN"). Pure data: the sim owns all rules.

## Position in BattleSim.units (used as the id in every event).
var index: int = 0
## 0 = player, 1 = enemy.
var side: int = 0
## Formation spot 0..5; row = spot / 2 (0 front, 1 middle, 2 back).
var spot: int = 0
## Source monster definition (never mutated by the sim).
var data: MonsterData
## Player's roster index, or -1 for enemies.
var roster_index: int = -1
var max_hp: int = 1
var hp: int = 1
var atk: int = 0
var defense: int = 0
var crit: float = 0.0
var attack_interval: float = 1.0
var alive: bool = true
## Seconds accumulated toward the next attack (attacks when >= attack_interval).
var attack_timer: float = 0.0
## Total damage this unit dealt (attacks + ability damage).
var damage_dealt: int = 0
## Per-ability, per-unit state (venom stacks, counters, timers).
var state: Dictionary = {}
## Abilities in fixed slot order: Array of [slot: StringName, ability: AbilityData,
## state_key: String, id: StringName].
var abilities: Array = []
## Same entries split per hook (index = BattleSim.H_*), only abilities that use it.
var by_hook: Array = [[], [], [], [], [], []]

## Current HP as a fraction of max HP (0.0 - 1.0).
func hp_fraction() -> float:
	return float(hp) / float(max_hp) if max_hp > 0 else 0.0

## Formation row of this unit (0 front, 1 middle, 2 back).
func row() -> int:
	return RunState.row_of(spot)
