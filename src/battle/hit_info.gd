class_name HitInfo
extends RefCounted
## One damage instance flowing through the ability hooks. Hooks combine by
## reading / writing this object (e.g. dodge sets `cancelled`).

var source: UnitState
var target: UnitState
## Final damage after DEF, crit and frenzy. Hooks may modify it.
var amount: int = 0
var crit: bool = false
## True if an ability (not a basic attack) produced this damage.
var from_hook: bool = false
## Ability that produced this damage (&"" for basic attacks).
var ability_id: StringName = &""
## Set by on_take_damage hooks to negate the hit.
var cancelled: bool = false
## 0 = basic attack, 1 = damage from a hook, 2+ = hook damage caused by hook damage.
var depth: int = 0
## Set by on_attack hooks: extra strikes this attack makes (double strike).
var extra_strikes: int = 0
