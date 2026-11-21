# Fusion (Splice + Incubator): shared contract

Approved by the user 2026-11-21. All agents on the fusion stage follow this file; names here
are fixed. Godot/test commands and house rules: `design/balance/stage4-mutations.md` header
and `handoff.md` §1, §4.

## 1. Rules

A **fused mutation** is two mutations of the same socket type merged into one slot.
Two triggers, one function (`FusionLogic.merge`):

- **Splice (Lab):** operating a mutation onto a slot that already holds one merges them
  (normal Lab cost, success chance and mush-on-fail rules; risk uses the incoming mutation).
- **Incubate (Incubator):** two monsters become one body. Per slot: only one parent filled ->
  carried over; both filled and mergeable -> merged; both filled and NOT mergeable -> the
  player picks which to keep. ARM_L merges with ARM_L, ARM_R with ARM_R (same for legs).

`merge_count` of a mutation: 0 base, 1 after one merge, 2 after two. A merge of `a` and `b`
gives `a.merge_count + b.merge_count + 1`, and is **blocked above 2**:

| a | b | result |
|---|---|---|
| base | base, different id | **Hybrid** (1) |
| base | base, same id | **Twin** (1) |
| hybrid/twin | base | **Apex** (2) |
| hybrid/twin | hybrid/twin | blocked (would be 3) |
| apex | anything | blocked |

Result fields:
- `parent_ids`: the BASE source ids, sorted, 2 (hybrid/twin) or 3 (apex) entries, duplicates kept for twins.
- `id`: parent ids joined with `+` (e.g. `ember_horns+leech_maw`). This is the **pair key**.
- Stats: each stat mod = `Tuning.FUSION_PART_STAT_MULT[merge_count]` x sum over base parents
  (`[1.0, 0.75, 0.65]`). Signature fusions use 1.0 instead of 0.75.
- Abilities: a mutation can now carry several (`MutationData.all_abilities()` = `ability` +
  `extra_abilities`). Hybrid: both parents' abilities. Twin: ONE ability, the parent's
  `empowered(Tuning.FUSION_TWIN_POWER)` (1.5). Apex: at most `Tuning.FUSION_MAX_ABILITIES` (2);
  the caller passes which to keep, default = first two in parent order.
- `rarity`: highest parent rarity. `fused_cost`: sum of parents' `Tuning.BUDGET_COST` (used by
  `EnemyGen.cost_of` so fused parts count fully toward adaptive scaling).
- Body override (ULTRA): copied from the highest-rarity parent that has one (first in
  parent order on a tie).
- Name: signature name if the pair is a signature; else Twin -> `"Twin <name>"`; Hybrid ->
  first word of the lower-rarity parent + last word of the higher-rarity parent (tie: sorted id
  order), e.g. Leech Maw + Ember Horns -> "Leech Horns"; Apex -> `"Apex <hybrid name>"`.
- `description`: generated: one line naming the parents, the combined stat line, then each
  kept ability's sentence taken from the parent descriptions.
- Sprites: see §3.

Incubator (unchanged from handoff §2 unless stated): needs two living monsters with at least
2 mutations each; costs `Tuning.FUSION_COST`; base body stats = `FUSION_STAT_MULT` x (A+B) x
`FUSION_BOOST`; `success% = clamp(FUSION_BASE_CHANCE - avg instability + stabilizer bonus, 10, 95)`;
on a fail both become mush; result has `fused = true`, instability `FUSION_START_INSTABILITY`,
and a generated title. Every new fused-part id and title is added to the Codex.

## 2. Code interface

```gdscript
# MutationData, new export group "Fusion"
@export var merge_count: int = 0
@export var parent_ids: Array[StringName] = []
@export var extra_abilities: Array[AbilityData] = []
@export var fused_cost: int = 0            # 0 = use Tuning.BUDGET_COST[rarity]
@export var signature: bool = false
func all_abilities() -> Array[AbilityData]

# AbilityData
func empowered(mult: float) -> AbilityData   # duplicate with "bigger is better" params x mult,
                                             # interval/cooldown-like params / mult

# src/data/fusion_logic.gd   class_name FusionLogic   (static, deterministic, no Nodes)
static func can_merge(a: MutationData, b: MutationData) -> bool
static func block_reason(a: MutationData, b: MutationData) -> String      # "" if mergeable
static func pair_key(a: MutationData, b: MutationData) -> String          # sorted base ids joined by "+"
static func ability_choices(a: MutationData, b: MutationData) -> Array[AbilityData]
static func merge(a: MutationData, b: MutationData, keep: Array[int] = []) -> MutationData  # null if blocked
static func incubate_preview(a: MonsterData, b: MonsterData) -> Dictionary
    # {&"slots": {slot: {&"kind": &"carry"|&"merge"|&"choose", &"result": MutationData, &"options": [..]}},
    #  &"chance": int, &"cost": int, &"ok": bool, &"reason": String}
static func incubate(run: RunState, a_idx: int, b_idx: int, choices: Dictionary,
        rng: RandomNumberGenerator) -> Dictionary   # {&"ok", &"success", &"monster", &"new_codex": [..]}
```

`BattleSim._add_unit` registers every entry of `all_abilities()`; the state key gains the
ability's index within the mutation so two abilities in one slot never share state.

## 3. Art

`tools/gen_hybrids.py` (stdlib only) writes:
- `assets/sprites/hybrids/<socket>_<view>.png`: one atlas per socket (head torso back arm leg tail)
  and view (front side), 32x32 cells, `COLUMNS = 16`. One cell per unordered pair of that
  socket's base mutations (including the 6 originals and ULTRAs) and one per twin.
- `assets/sprites/hybrids/sig_<a>__<b>_front.png` / `_side.png`: bespoke 32x32 sprites for signatures.
- `src/data/fusion_index.json`:
  `{"cell": 32, "columns": 16, "pairs": {"<a>+<b>": {"socket": "HEAD", "cell": 12}},`
  `"signatures": {"<a>+<b>": {"name": "...", "desc": "...", "front": "res://...", "side": "res://..."}}}`
  (twins use key `"<a>+<a>"`).

Runtime: `FusionLogic` reads the index once and builds `AtlasTexture`s for `sprite_front` /
`sprite_side`. Apex parts reuse their hybrid/twin cell and get the glow material
(`assets/shaders/apex_glow.gdshader`) from `MonsterView`.

## 4. Signature fusions: `tools/signature_table.py`

`SIGNATURES = [ {...} ]`, about 25 entries, each a pair of DIFFERENT base ids of the same socket:

```python
{"a": "ember_horns", "b": "leech_maw",            # sorted ids
 "name": "Hellmouth", "desc": "One flavour line.", # shown above the generated stat lines
 "art": {"motif": "maw", "colors": ["#3a0c08", "#c8401a", "#ffb040"], "accent": "#fff2a0",
         "flourish": "flames"}}                    # glow spikes eyes crown flames runes drips sparks
```
