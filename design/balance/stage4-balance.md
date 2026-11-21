# Stage 4 balance pass: 100-mutation pool

_2026-11-21. Follows `design/balance/stage3-tuning.md`. Contract for the pool: `design/balance/stage4-mutations.md`._

**Status: partly on target. Not finished.** The pool is now flat within each rarity and the run win
rates of three of the four policies are inside their bands, but battle 1 is far too easy (simulated odds
98-100%, target under 95%), the cautious policy is under its band, late gold and battle-5 fight length are
over target, and ULTRA is too expensive to be a real choice. Section 8 lists every miss.

## 1. Method

Simulator: `tools/balance/run_sim.gd` (headless, deterministic, single thread).

- **Full runs** (`runs=N policy=all seed=1 odds=K`): unchanged idea from stage 3, real logic classes and
  real `BattleSim`. New in this pass:
  - `build` is role-driven, not id-driven. Each piece is valued in power points for the role of its best
    wearer (carry / tank / support) from its stats and the kind of its ability, plus a bonus when the wearer
    already has two pieces sharing a tag. All constants are at the top of the script.
  - Four rarities everywhere.
  - Per-mutation, per-ability and per-rarity report: runs owning it at the end, run win rate and mean battles
    won with and without, plus an "early" column (installed before battle 1). Also ULTRA seen / bought.
    Written into the markdown report and to `<out>_mutations.csv`.
  - **Policy changes that affect comparisons with stage 3** (see section 3): greedy, cautious and build now
    buy a human before parts while they have fewer than 3 living monsters; build may go to 4 bodies.
- **Arena** (`mode=arena fights=200`): a human wearing only one mutation (and two copies for ARM / LEG).
  - *Plain 2v2*: with one plain ally against two plain humans. The HP-fraction margin is the raw power
    used to compare rarities.
  - *Ladder*: 1v1 and 2v2 against a dummy, a plain human with extra plain stats (+20 HP and +0.75 ATK per
    power point). The dummy climbs from 0 to 2 x par over the fights; par by rarity is 1.5 / 2.5 / 4.0 / 6.5
    points (the guide in `tools/mutation_table.py`), doubled for two copies. A piece worth exactly par wins
    about 50, worth nothing about 0, worth twice par about 100. Score = mean of the two ladders (2v2 only
    for war_cry, mend, vengeance, cleave, chain, which do nothing alone).
  - Why a ladder: against a fixed opponent these long, low-variance fights give 0% or 100% for almost every
    piece, so a fixed-opponent win rate cannot show "within 15 points". The first arena run used a fixed
    par dummy and flagged 107 of 137 rows; it is not used below.
- **Retuner**: `tools/balance/retune.py` reads the arena CSV and moves each piece's plain stats toward
  score 50 (damped, HP first, then speed / ATK / DEF by theme), rewrites the stats line of `desc`, and
  re-syncs the six hand-made `.tres`. `tools/balance/retune_loop.sh` runs arena -> retune -> regenerate ->
  import. Ability parameters are only changed by hand.

Commands for the final numbers (project root, `G` = the 4.7.2 console exe):

```
"$G" --headless --path . -s res://tools/balance/run_sim.gd -- runs=500 policy=all seed=1 odds=10 out=res://reports/balance_stage4.md
"$G" --headless --path . -s res://tools/balance/run_sim.gd -- mode=arena fights=200 out=res://reports/s4_arena_after.md
```

## 2. Final table (500 runs per policy, seed 1, odds=10)

| | greedy | cautious | random | build |
|---|---|---|---|---|
| Run win | 15.6% | 22.4% | 15.8% | **42.0%** |
| Target band (after the "5% easier" request) | 15-25% | 25-40% | 10-20% | 40-55% |
| Reach B3 | 97.8% | 100.0% | 93.4% | 97.4% |
| Mean fight (per battle) | 42-49 s | 42-50 s | 43-52 s | 41-54 s |
| B1 sim odds | 100.0% | 100.0% | 98.0% | 100.0% |
| Gold at B5 hub | 43.1 | 35.9 | 51.5 | 54.2 |

Win given reached, per battle (B1 to B5):

| | B1 | B2 | B3 | B4 | B5 |
|---|---|---|---|---|---|
| greedy | 100.0 | 98.0 | 81.4 | 69.6 | 28.2 |
| cautious | 100.0 | 100.0 | 89.8 | 82.0 | 30.4 |
| random | 97.8 | 95.5 | 74.5 | 79.3 | 28.6 |
| build | 100.0 | 97.4 | 94.3 | 90.6 | 50.5 |

The difficulty curve is wrong in shape: battles 1 and 2 are close to free and battle 5 decides the run.
At battle 5, 31% of build fights and 20-26% of cautious / random fights reach the 60 s hard cap.

## 3. What was found (iteration log)

Run win rates are greedy / cautious / random / build. 200 runs unless stated.

| # | Change | Result |
|---|---|---|
| 0 | New 100 pool, stage-3 tuning, new build policy (odds=10) | 2.0 / 2.0 / 9.5 / 32.5; fights 41-54 s; B1 odds 86-98% |
| 1 | Old six and two burn rares nerfed by hand, then 4 retune passes | arena rows more than 15 from the median: 73 -> 3 of 137. Runs: 0.0 / 0.0 / 1.0 / 0.5; fights 37-58 s |
| 2 | Build policy spends more; grid over ENEMY_HP_MULT and ENEMY_BUDGET (5 configs) | best: 3.5 / 0.5 / 26.0 / 32.0. Greedy and cautious never own a third body and lose to 3 and 4 enemies |
| 3 | Greedy and cautious buy a body first; grid with ADAPT_BODY_POWER and ADAPT_RATE (5 configs) | 18.5 / 18.0 / 25.0 / 37.5 to 24.5 / 22.0 / 40.0 / 42.0 |
| 4 | Build buys a third body first; grid on HP shape and ADAPT_BODY_POWER 3-5 (5 configs) | chosen base: 21.5 / 17.5 / 15.0 / 52.0 |
| 5 | ADAPT_MAX raised late; 500 runs, odds=0 | 12.0 / 17.2 / 12.6 / 36.0 |
| 6 | User request: 5% easier (section 5); 500 runs, odds=10 | 15.6 / 22.4 / 15.8 / 42.0 |

The 200-run numbers in step 4 were optimistic by several points compared with 500 runs; steps 5 and 6 are
the ones to trust.

**Main finding: with a flat pool, bodies beat parts.** A common is now worth about a quarter of a body
for 10 gold; a human is a whole body with eight sockets for 30 gold. In stage 3 the six original pieces
were two to three times stronger than a new common (Mantis Arm alone was about +150% damage), which is
what made two heavily mutated monsters viable. After flattening to the level of the new commons, the
winning line is "buy bodies, then parts", and a run that stays at two bodies cannot win battle 3. This is
a design question, not a tuning one: see section 8.

## 4. Numbers changed

### 4.1 `src/data/tuning.gd`

| Knob | Before | After | Reason |
|---|---|---|---|
| `ENEMY_BUDGET` | [2, 4, 6, 10, 14] | [2, 4, 6, 9, 12] | late enemies were out of reach once player pieces became weaker |
| `ENEMY_HP_MULT` | [1.3, 1.35, 1.15, 1.2, 1.25] | [0.95, 0.9, 0.75, 0.7, 0.7], then x0.95 = [0.9, 0.86, 0.71, 0.67, 0.67] | weaker pieces made every fight a 52-57 s slugfest; lower enemy HP shortens fights and restores win rates. The x0.95 is the user request in section 5 |
| `ADAPT_BODY_POWER` | 2 | 4 | a body is now worth about four commons; at 2 the random policy (four bodies) won as often as build |
| `ADAPT_MAX` | [2, 4, 6, 8, 10] | [2, 4, 7, 10, 13] | the late cap was binding for build in most fights |

Not changed: `BUDGET_COST`, `PRICE_BY_RARITY`, `RARITY_WEIGHTS`, `INSTABILITY_PER_RARITY`, `RISK_PER_RARITY`,
`ULTRA_ENEMY_MIN_BATTLE`, `BATTLE_REWARD`, `ADAPT_EXPECTED`, `ADAPT_RATE`. The comment above
`ADAPT_BODY_POWER` ("a body is about a common+") is now out of date. No ability behaviour was changed.

### 4.2 Simulator policies (not game data)

| Policy | Before | After | Reason |
|---|---|---|---|
| greedy, cautious | human only after mutations, if living < 3 | human first if living < 3 | they never had 30 gold left and stayed at two bodies (0-3% run win) |
| build | fixed carry / tank plans by id, at most 3 bodies | value-driven by role and tags; third body first, up to 4 bodies; thresholds 1.0 / 1.8 / 2.6 / 4.0 points | the id plans named only the old six |

### 4.3 Mutations

The six originals were cut by hand first, then every piece went through the retuner. "Arena score before"
is after the hand cuts and before the retune passes. Ability parameters changed on five pieces only
(mantis_arm, bone_plating, leech_maw, furnace_belly, pyre_cannon); every other change is plain stats.
Reason for all rows: bring the piece to its rarity's par (score 50).

| Mutation | Rarity | Stats before | Stats after | Ability before -> after | Arena score before -> after |
|---|---|---|---|---|---|
| leech_maw | uncommon | +4 ATK | -80 HP, +2 ATK | AbLifesteal fraction 0.4 -> AbLifesteal fraction 0.25 | 69.5 -> 43.0 |
| ram_horns | common | -40 HP, +3 ATK | -60 HP, +3 ATK | same | 60.5 -> 48.3 |
| compound_eyes | common | +6% crit | +50 HP, +2% crit | same | 26.0 -> 51.3 |
| static_antennae | common | +20 HP | +60 HP | same | 27.0 -> 55.0 |
| frost_crest | common | +20 HP | +40 HP | same | 37.5 -> 52.0 |
| snapping_beak | common | +1.5 ATK | -40 HP, +1.5 ATK | same | 72.0 -> 50.5 |
| ember_horns | common | +3 ATK, -1 DEF | -20 HP, +3 ATK, -1 DEF | same | 58.5 -> 43.3 |
| howler_crest | uncommon | +30 HP | +90 HP | same | 25.0 -> 44.5 |
| venom_fangs | uncommon | +2 ATK | -70 HP | same | 97.5 -> 50.5 |
| storm_antennae | uncommon | +5% crit | +40 HP, +5% crit | same | 41.0 -> 54.5 |
| menders_halo | rare | +40 HP | -20 HP | same | 59.0 -> 50.5 |
| bone_plating | common | +109 HP, +3 DEF | +1 DEF | AbReflect chance 0.25, damage 4 -> AbReflect chance 0.2, damage 3 | 76.5 -> 51.8 |
| shaggy_pelt | common | +80 HP, +0.1s interval | +100 HP | same | 26.0 -> 52.3 |
| brine_scales | common | +50 HP, -1 ATK, +1 DEF | +110 HP, -1 ATK, +1 DEF | same | 23.0 -> 51.8 |
| rib_spurs | common | +20 HP | -10 HP | same | 66.5 -> 52.5 |
| ember_core | common | +1.5 ATK | -80 HP, +0.5 ATK, +0.05s interval | same | 100.0 -> 41.8 |
| chitin_carapace | common | +30 HP, +2 DEF, +0.1s interval | -10 HP, +2 DEF, +0.1s interval | same | 69.5 -> 55.5 |
| overgrown_heart | common | +30 HP | +70 HP | same | 27.0 -> 48.3 |
| crystal_lattice | uncommon | +2 DEF | -60 HP, +2 DEF | same | 63.5 -> 43.3 |
| dynamo_core | uncommon | +1.5 ATK, -0.1s interval | -20 HP, +1.5 ATK, -0.05s interval | same | 73.0 -> 58.0 |
| mycelium_coat | uncommon | +50 HP | +160 HP | same | 15.0 -> 44.8 |
| resonant_ribcage | uncommon | +40 HP | +100 HP | same | 38.0 -> 55.0 |
| furnace_belly | rare | +40 HP, +2 ATK, +0.1s interval | -10 HP, +1 ATK | AbBurn fraction 0.012, duration 4 -> AbBurn fraction 0.006, duration 4 | 78.5 -> 59.5 |
| revenant_ribcage | rare | +50 HP | +160 HP, +2 DEF | same | 12.5 -> 52.5 |
| obsidian_colossus_heart | ultra | +120 HP, +2 DEF, +0.3s interval | +50 HP | same | 73.0 -> 52.8 |
| quill_ridge | common | -20 HP | -60 HP | same | 69.5 -> 41.8 |
| barnacle_shell | common | +60 HP, +2 DEF, +0.2s interval | +20 HP, +2 DEF, +0.2s interval | same | 67.5 -> 56.8 |
| dorsal_fin | common | -1 ATK, -0.15s interval | +50 HP, -0.15s interval | same | 0.5 -> 45.8 |
| puffball_vents | common | +20 HP | +40 HP | same | 38.5 -> 51.5 |
| snowmoth_wings | common | -20 HP | +60 HP | same | 17.5 -> 54.5 |
| adrenal_tubes | common | +20 HP | -20 HP | same | 67.0 -> 45.8 |
| dusk_wings | uncommon | -0.15s interval | +110 HP, -0.05s interval | same | 23.5 -> 47.8 |
| acid_sprayer | uncommon | +1.5 ATK | -80 HP, +0.5 ATK, +0.05s interval | same | 88.5 -> 44.8 |
| magma_shell | rare | +80 HP, +2 DEF, +0.1s interval | +40 HP, +0.1s interval | same | 76.0 -> 45.5 |
| blight_stacks | rare | +40 HP | +120 HP | same | 37.5 -> 52.8 |
| razor_wings | rare | +2 ATK, -0.15s interval | +10 HP, -0.1s interval | same | 81.0 -> 52.0 |
| mantis_arm | common | +4 ATK, -0.2s interval | -40 HP, +1 ATK | AbDoubleStrike every_n 3, extra_strikes 1 -> AbDoubleStrike every_n 4, extra_strikes 1 | 77.5 -> 57.3 |
| crab_pincer | common | +1 ATK, +1 DEF, +0.05s interval | -20 HP, +1 ATK, +1 DEF, +0.05s interval | same | 59.5 -> 46.3 |
| bone_club | common | +3 ATK, +0.15s interval | -40 HP, +3 ATK, +0.05s interval | same | 66.0 -> 52.0 |
| sucker_arm | common | +1 ATK | -20 HP, +1 ATK | same | 63.0 -> 50.5 |
| spark_prod | common | +1 ATK | +20 HP, +1 ATK | same | 33.5 -> 49.3 |
| mold_tendril | common | +1 ATK | -50 HP, +1 ATK | same | 87.0 -> 69.0 |
| chitin_shiv | common | -30 HP, +2.5 ATK | -40 HP, +2.5 ATK | same | 70.0 -> 63.8 |
| cinder_fist | common | +1 ATK | -20 HP, +1 ATK | same | 77.0 -> 67.8 |
| butcher_blade | uncommon | +2.5 ATK | -10 HP, +0.5 ATK | same | 99.0 -> 63.5 |
| arc_cannon | uncommon | +1 ATK | +40 HP, +1 ATK | same | 46.0 -> 60.5 |
| toxin_claw | uncommon | +1.5 ATK | -30 HP, +0.5 ATK | same | 87.5 -> 62.8 |
| squid_arm | uncommon | +30 HP | -10 HP, +2 ATK | same | 19.5 -> 42.0 |
| bulwark_pincer | uncommon | +1 DEF | +60 HP, +1 DEF | same | 36.0 -> 50.5 |
| quartz_knuckle | uncommon | +1.5 ATK, +4% crit | -10 HP, +1.5 ATK, +2% crit | same | 62.0 -> 55.8 |
| pyre_cannon | rare | +2 ATK, +0.1s interval | +2 ATK, +0.1s interval | AbBurn fraction 0.01, duration 4 -> AbBurn fraction 0.006, duration 4 | 65.0 -> 64.5 |
| flicker_blade | rare | +1.5 ATK, -0.1s interval | +10 HP, +0.5 ATK, -0.1s interval | same | 68.0 -> 57.8 |
| reapers_scythe_arm | ultra | -70 HP, +5 ATK, +10% crit | +150 HP, +2 ATK, +2% crit | same | 40.0 -> 51.3 |
| cloven_hoof | common | +60 HP, +0.05s interval | +110 HP | same | 26.0 -> 56.0 |
| spider_leg | common | -20 HP, -0.1s interval | +30 HP, -0.25s interval | same | 15.5 -> 49.5 |
| spring_heel | common | -0.05s interval | +10 HP, -0.2s interval | same | 24.5 -> 50.0 |
| stalker_paw | common | +4% crit | +60 HP, +2% crit | same | 21.5 -> 50.3 |
| chitin_tread | common | +40 HP, +1 DEF, +0.1s interval | +40 HP, +1 DEF | same | 38.0 -> 52.3 |
| marsh_hopper | common | -0.05s interval | -0.15s interval | same | 37.0 -> 53.0 |
| rime_hoof | common | +30 HP | +50 HP | same | 27.0 -> 43.5 |
| bone_stilt | common | -30 HP, +2 ATK | -10 HP, +2 ATK | same | 41.0 -> 55.3 |
| stampede_hoof | uncommon | +40 HP | none | same | 62.0 -> 47.3 |
| widow_leg | uncommon | +5% crit | -20 HP, +3% crit | same | 67.5 -> 56.5 |
| capacitor_heel | uncommon | -0.1s interval | +80 HP, -0.2s interval | same | 14.0 -> 51.3 |
| alpha_paw | rare | +30 HP, +1.5 ATK | +130 HP, +1.5 ATK | same | 31.0 -> 52.0 |
| phantom_stride | rare | +5% crit, -0.2s interval | +70 HP, +5% crit, -0.25s interval | same | 34.5 -> 54.5 |
| juggernaut_tread | rare | +70 HP, +1 DEF, +0.2s interval | +150 HP, +1 DEF | same | 32.0 -> 53.5 |
| scorpion_tail | rare | +10% crit | -60 HP, +2% crit, +0.1s interval | same | 85.0 -> 53.3 |
| whip_tail | common | -30 HP, -0.15s interval | +40 HP, -0.2s interval | same | 11.5 -> 53.3 |
| seedpod_rattle | common | +20 HP | +80 HP | same | 24.0 -> 51.0 |
| fin_fan | common | +30 HP | +10 HP | same | 59.0 -> 46.5 |
| grudge_flame | common | +1 ATK | +40 HP, +1 ATK | same | 31.0 -> 49.5 |
| needle_barb | common | +1 ATK | -70 HP | same | 98.0 -> 43.0 |
| prism_fan | uncommon | +30 HP | +90 HP | same | 37.5 -> 53.8 |
| lamprey_tail | uncommon | +1.5 ATK | -50 HP, +1.5 ATK | same | 72.0 -> 53.3 |
| flail_tail | uncommon | +2 ATK | -60 HP, +2 ATK | same | 66.0 -> 42.3 |
| brimstone_tail | uncommon | +1 ATK | -80 HP, +0.05s interval | same | 86.5 -> 47.3 |

77 of 100 mutations changed; 23 unchanged.

Mantis Arm and Bone Plating stay COMMON (tests and the starting loadout depend on it) and were nerfed
instead: Mantis Arm from +4 ATK, 0.2 s faster, double strike every 3rd attack to the row above; Bone
Plating from +109 HP, +3 DEF, 25% reflect 4.

## 5. User request: 5% easier

Requested after a hand playtest: shift every run-win band up 5 points and multiply every `ENEMY_HP_MULT`
entry by 0.95 (rounded to 2 decimals). Both runs below use the final numbers of section 4 and differ only
in this multiplier (500 runs per policy, seed 1).

| | greedy | cautious | random | build |
|---|---|---|---|---|
| Without: `[0.95, 0.9, 0.75, 0.7, 0.7]` | 12.0% | 17.2% | 12.6% | 36.0% |
| With: `[0.9, 0.86, 0.71, 0.67, 0.67]` | 15.6% | 22.4% | 15.8% | 42.0% |
| Change | +3.6 | +5.2 | +3.2 | +6.0 |

Mean +4.5 points, so the multiplier alone delivers about the requested 5. Nothing further was taken from
`ENEMY_BUDGET` or `ADAPT_RATE`. Reach B3 moved by less than 1 point; fights are 1-2 s shorter. No unit
test pins `ENEMY_HP_MULT` values (they read `Tuning`), so no test was edited.

## 6. Arena after tuning (200 fights per column)

| Rarity | Pieces | Median score | Lowest | Highest | Median margin, plain 2v2 |
|---|---|---|---|---|---|
| common | 45 | 51.5 | 41.8 | 69.0 | 10.4 |
| uncommon | 30 | 51.5 | 42.0 | 63.5 | 19.6 |
| rare | 17 | 52.8 | 42.8 | 64.5 | 28.8 |
| ultra | 8 | 51.5 | 42.3 | 54.0 | 45.5 |

Before the retune (after the hand cuts) the ranges were 0.5-100, 14-99, 12.5-85 and 40-73.

- Raw power rises with rarity: 10.4 < 19.6 < 28.8 < 45.5. On target.
- Within 15 points of the rarity median: every single piece except two commons, mold_tendril (+17.5)
  and cinder_fist (+16.3). Of the 37 doubled ARM / LEG rows one is out: mold_tendril x2 (-24.5).

Top and bottom five per rarity (single copy):

**Common** (45 pieces)

| | Mutation | Ability | Score | Delta from median | Margin, plain 2v2 |
|---|---|---|---|---|---|
| top | mold_tendril | corrode | 69.0 | 17.5 | 24.8 |
| top | cinder_fist | burn | 67.8 | 16.3 | 18.3 |
| top | chitin_shiv | (none) | 63.8 | 12.3 | 15.7 |
| top | brine_feelers | regen | 58.0 | 6.5 | 10.9 |
| top | frostbite_claw | chill | 57.3 | 5.8 | 12.7 |
| bottom | rime_hoof | shield | 43.5 | -8.0 | 8.4 |
| bottom | ember_horns | (none) | 43.3 | -8.3 | 11.0 |
| bottom | needle_barb | venom | 43.0 | -8.5 | 11.5 |
| bottom | ember_core | burn | 41.8 | -9.8 | 7.2 |
| bottom | quill_ridge | thorns | 41.8 | -9.8 | 11.2 |

**Uncommon** (30 pieces)

| | Mutation | Ability | Score | Delta from median | Margin, plain 2v2 |
|---|---|---|---|---|---|
| top | butcher_blade | cleave | 63.5 | 12.0 | 23.6 |
| top | toxin_claw | venom | 62.8 | 11.3 | 29.1 |
| top | tesla_spines | reflect | 61.8 | 10.3 | 20.8 |
| top | arc_cannon | chain | 60.5 | 9.0 | 20.4 |
| top | dynamo_core | chain | 58.0 | 6.5 | 23.2 |
| bottom | rootfoot | regen | 44.3 | -7.3 | 14.0 |
| bottom | crystal_lattice | shield | 43.3 | -8.3 | 15.7 |
| bottom | leech_maw | lifesteal | 43.0 | -8.5 | 18.1 |
| bottom | flail_tail | double_strike | 42.3 | -9.3 | 19.6 |
| bottom | squid_arm | stun | 42.0 | -9.5 | 14.8 |

**Rare** (17 pieces)

| | Mutation | Ability | Score | Delta from median | Margin, plain 2v2 |
|---|---|---|---|---|---|
| top | pyre_cannon | burn | 64.5 | 11.8 | 35.2 |
| top | frost_maul | chill | 62.3 | 9.5 | 35.2 |
| top | furnace_belly | burn | 59.5 | 6.8 | 32.9 |
| top | flicker_blade | double_strike | 57.8 | 5.0 | 34.0 |
| top | phantom_stride | dodge | 54.5 | 1.8 | 24.2 |
| bottom | razor_wings | cleave | 52.0 | -0.8 | 28.8 |
| bottom | deaths_head | execute | 51.8 | -1.0 | 33.0 |
| bottom | menders_halo | mend | 50.5 | -2.3 | 27.8 |
| bottom | magma_shell | thorns | 45.5 | -7.3 | 26.7 |
| bottom | jelly_crown | stun | 42.8 | -10.0 | 23.2 |

**Ultra** (8 pieces)

| | Mutation | Ability | Score | Delta from median | Margin, plain 2v2 |
|---|---|---|---|---|---|
| top | amber_hive_crown | swarm | 54.0 | 2.5 | 47.1 |
| top | false_seraph_halo | mend | 53.5 | 2.0 | 39.9 |
| top | obsidian_colossus_heart | titan | 52.8 | 1.3 | 44.4 |
| top | prismatic_geode_heart | reflect | 51.5 | 0.0 | 45.5 |
| bottom | reapers_scythe_arm | execute | 51.3 | -0.3 | 46.7 |
| bottom | long_night_tail | snipe | 51.0 | -0.5 | 47.6 |
| bottom | void_moth_wings | phase | 47.5 | -4.0 | 38.8 |
| bottom | primordial_ooze_mantle | regen | 42.3 | -9.3 | 31.9 |

Doubled ARM / LEG pieces (score against a doubled par): lowest mold_tendril 27.0, chitin_shiv 38.3, pyre_cannon 38.3, ragged_claw 39.0, highest spider_leg 56.3, capacitor_heel 56.5, arc_cannon 57.0, phantom_stride 58.3.

Full table: `reports/s4_arena_after.md` (gitignored; regenerate with the command in section 1).

## 7. ULTRA

- **Sighting odds.** Weights [60, 30, 10 + 5 per battle, 2], three slots per stock: a run that visits all
  five shops without rerolling sees at least one ULTRA 23.8% of the time (15.6% after three visits); one
  reroll per visit raises five visits to 41.9%. Measured over the final 2000 runs, counting shop stock,
  rerolls and reward offers: 24.1% of runs (greedy 23.4%, cautious 25.0%, random 21.8%, build 26.2%), about
  1 run in 4. On target, at the generous end of "1 in 4-6". `RARITY_WEIGHTS` was left at [60, 30, 10, 2].
- **Buying.** 0.2% of runs bought one. At 60 gold with 36-54 gold in hand late in a run it is not a choice,
  it is out of reach. **Target missed.**
- **With / without.** Only 17 of 2000 runs ended owning an ULTRA (mostly from the free-mutation reward):
  41.2% run win against 23.8% without (pooled); build 55.6% (9 runs) against 41.8%. The direction is right
  (clearly better, far from 100%) but 17 runs prove nothing.
- In the arena all eight ULTRAs sit at par for 6.5 points (scores 42-54), about 4.4 times the raw margin
  of a common.

## 8. Off target, and what needs a human

| Target | Result | Verdict |
|---|---|---|
| build 40-55% | 42.0% | met, low end |
| cautious 25-40% | 22.4% | **missed** by 2.6 |
| greedy 15-25% | 15.6% | met, low end |
| random 10-20% | 15.8% | met |
| mean fight 35-50 s | 41-54 s | **missed** at battle 5 (build 53.8 s, random 52.2 s) |
| B1 sim odds under 95% | 98-100% | **missed** |
| gold at B5 hub about 45 or less | 35.9 / 43.1 / 51.5 / 54.2 | **missed** for random and build |
| arena within 15 of the median | 2 single pieces and 1 doubled row out | nearly met |
| median power rises with rarity | 10.4 / 19.6 / 28.8 / 45.5 | met |
| ULTRA seen by 1 run in 4-6 | 1 in 4.1 | met |
| ULTRA a real choice at 60 | bought in 0.2% of runs | **missed** |

Next steps, in the order I would take them (none of these was simulated):

1. **Difficulty curve.** Battle 1 and 2 need to be harder and battle 5 softer: raise `ENEMY_HP_MULT[0..1]`
   and `ENEMY_BUDGET[0..1]`, lower entry 4. Three bodies against two enemies at battle 1 is the cause of
   the 100% odds; `ENEMY_TEAM_SIZE` [2, 2, 3, 3, 4] or `PRICE_HUMAN` 30 may be the honest knobs, and both
   were outside this pass.
2. **Decide what a mutation should be worth.** Either accept "bodies first, parts second" (then raise
   `PRICE_HUMAN` so it is a decision), or raise the par of the whole pool by about half so that parts
   compete with bodies again and fights get shorter on their own. The retune loop can do the second in
   four passes by raising `ARENA_PAR` in `run_sim.gd` and `PAR` in `retune.py`.
3. **ULTRA price** 60 -> about 45, then re-measure buying.
4. **Late gold**: `BATTLE_REWARD[2]` 30 -> 25, or the fusion cost of stage 4.

Needs a human playtest or a designer's eye:

- The retuner equalises mostly with HP. Several pieces now read oddly: venom_fangs is -70 HP with no ATK,
  leech_maw -80 HP, needle_barb -70 HP, mycelium_coat and revenant_ribcage +160 HP. The numbers are fair
  in the arena; the flavour is not always. The stats line of each `desc` was rewritten automatically.
- The arena is a duel against plain humans. It undervalues nothing in particular but it cannot see
  synergy, and the full-run lift table is biased by survivorship (longer runs own more). The run report
  (`reports/balance_stage4.md`) shows crystal_lattice (-16), nectar_sacs (-10), quill_ridge (-10) and
  ember_core (-9) below their peers and revenant_ribcage (+26), spore_sacs (+25), blight_stacks (+19)
  above; 45-135 owning runs each, so treat these as leads, not verdicts.
- Designer suspects, as measured:
  - **Burn**: damage is `max(1, round(max HP x fraction))`, so on a 360 HP body any fraction below about
    0.4% deals the same 1 per second. Common burn pieces cannot be tuned through `fraction`; they were
    balanced through stats. The two rare burns were halved (1.2% and 1% -> 0.6%).
  - **Corrode**: mold_tendril scores 49 alone but 89 with an ally (negative DEF helps the whole team), and
    its second copy is nearly worthless because the cap is per target (x2 scores 27). The same cap makes
    doubled burn and chill pieces weak (cinder_fist x2 40.5, pyre_cannon x2 38.3).
  - **DEF against 6 base ATK** is still strong; the retuner priced one DEF at about 1.1 points and
    stripped it where a piece was over par.
  - **Cleave scaled twice by frenzy**: not touched.
- Battle-1 odds, the fight-length feel of battle 5 (a third of build fights end on the timer) and whether
  the nerfed starting loadout (Mantis Arm + Scorpion Tail) still feels like a carry.

## 9. Tests

`Overall Summary: 160 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans` (full
`tests/unit` suite, after the final numbers; the count includes suites added by other work in progress).
No test expectation had to change. `python tools/mutation_table.py` passes its self-check.


---

# Pass 2 (2026-11-21) - mutations matter, toughness restored, fusion check

Pass 1 above is kept as the record of the first attempt. Pass 2 replaces its numbers. It was cut
short by the jam deadline; what was skipped is listed in 2.7.

## 2.1 What changed and why

**Pool.** The arena par per rarity was raised by half (`ARENA_PAR` in `tools/balance/run_sim.gd`:
`[2.25, 3.75, 6.0, 9.75]` points for common / uncommon / rare / ultra) and all 100 mutations were
retuned to it with a new retuner (`tools/balance/retune.py`, driven by
`tools/balance/retune_loop.sh`). Unlike pass 1, the retuner keeps each piece's original stat
signature from `tools/balance/mutation_baseline.py`: same signs, same dominant stat, magnitudes
scaled. Caps: HP within +/-120 (ultra +/-200), ATK -3..+6, interval -0.25..+0.3, DEF -2..+3,
crit <= 0.3. No offence piece is paid for by an HP penalty alone and no common gives +160 HP.
91 of 100 mutations changed. Per-piece before/after: `reports/s4b_arena_pass1.csv` and
`reports/s4b_arena_after.md` / `.csv`.

Arena result (200 fights per rung, score 50 = at par):

| Rarity | Rows | Median score | Min | Max | Plain 2v2 margin |
|---|---|---|---|---|---|
| Common | 45 | 47.3 | 16.3 | 72.8 | 15.5 |
| Uncommon | 30 | 48.5 | 11.0 | 70.0 | 26.9 |
| Rare | 17 | 49.5 | 10.3 | 60.8 | 40.1 |
| Ultra | 8 | 49.3 | 39.5 | 51.0 | 56.0 |

20 of 137 rows are more than 15 from their rarity median:

- 8 are abilities the arena cannot see (they need deaths or low HP: second wind, vengeance,
  berserk, execute) on overgrown_heart, mycelium_coat, revenant_ribcage, juggernaut_tread,
  alpha_paw and reapers_scythe_arm. These are pinned to the median scale factor, not tuned.
- Low and at their caps: spider_leg, whip_tail, dorsal_fin (speed commons), pyre_cannon x2.
- High: mold_tendril 73, brimstone_tail 70 (corrode), thick_skull 67, chitin_tread 65-67,
  frostbite_claw 63, adrenal_tubes 63.

**Economy (`src/data/tuning.gd`).**

| Constant | Stage 3 | Pass 1 | Pass 2 |
|---|---|---|---|
| `ENEMY_HP_MULT` | [1.3, 1.35, 1.15, 1.2, 1.25] | [0.9, 0.86, 0.71, 0.67, 0.67] | **[1.04, 1.04, 0.9, 0.95, 0.81]** (tuned [1.1, 1.1, 0.95, 1.0, 0.85] x 0.95) |
| `ENEMY_BUDGET` | [2, 4, 6, 10, 14] | [2, 4, 6, 9, 12] | **[2, 4, 5, 8, 9]** |
| `ENEMY_TEAM_SIZE` | [2, 2, 3, 3, 4] | same | same |
| `ADAPT_MAX` | [2, 4, 6, 8, 10] | [2, 4, 7, 10, 13] | **[2, 3, 4, 5, 6]** |
| `ADAPT_BODY_POWER` | 2 | 4 | **3** |
| `ADAPT_RATE` | 3.5 | 3.5 | 3.5 |
| `PRICE_BY_RARITY` | [10, 18, 30, 60] | same | **[10, 18, 30, 45]** |
| `PRICE_HUMAN` | 30 | 30 | **35** |
| `BATTLE_REWARD` | [20, 25, 30, 28, 0] | same | **[20, 25, 25, 25, 0]** |
| `FRENZY_START` | 45.0 | 45.0 | **30.0** |
| `FUSION_PART_STAT_MULT` | - | [1.0, 0.75, 0.65] | **[1.0, 0.65, 0.6]** |

Why the late multipliers are still below 1.0: with stronger parts the enemy's parts are stronger
too, and an enemy team of 3-4 with a budget of 10-14 was unbeatable (0-10% at battle 5 at any HP
multiplier tried). The late difficulty now comes from team size and budget, not from an HP
multiplier. Battles 1-2 are back above 1.0.

## 2.2 Final result (500 runs per policy, seed 1, odds=10, bodies=2)

Command: `run_sim.gd -- runs=500 policy=all seed=1 odds=10 bodies=2`. Full report:
`reports/s4b_grid_final.md`.

| Policy | Run win | Band | Reach B3 | Fight length | B1 odds | Gold at B5 |
|---|---|---|---|---|---|---|
| build | 54.4% | 40-55 | 89.6% | 41-47 s | 92.6% | 49.8 |
| cautious | 16.0% | 25-40 | 82.0% | 43-48 s | 88.4% | 30.5 |
| greedy | 18.0% | 15-25 | 62.8% | 42-44 s | 84.7% | 37.2 |
| random | 17.6% | 10-20 | 91.0% | 44-49 s | 97.1% | 44.1 |

Won given reached (%), per battle:

| Policy | B1 | B2 | B3 | B4 | B5 |
|---|---|---|---|---|---|
| build | 92.8 | 96.6 | 89.3 | 84.5 | 80.5 |
| cautious | 88.2 | 93.2 | 78.0 | 55.5 | 45.2 |
| greedy | 84.6 | 75.9 | 79.9 | 63.3 | 56.6 |
| random | 97.2 | 93.6 | 67.3 | 60.1 | 47.8 |
| target (build) | 85-93 | 80-90 | 75-85 | 70-80 | 60-75 |

Fights hitting the 60 s cap (build): 0.0 / 0.2 / 1.8 / 4.0 / 2.4 % for battles 1-5 (pass 1 had 31%
at battle 5). Build mean duration 42.7 / 41.3 / 45.0 / 46.5 / 46.8 s.

## 2.3 "5% easier" (separately labelled change)

Same command, same odds setting (odds=10), 500 runs. Only `ENEMY_HP_MULT` differs.

| Policy | Without ([1.1, 1.1, 0.95, 1.0, 0.85]) | With ([1.04, 1.04, 0.9, 0.95, 0.81]) |
|---|---|---|
| build | 49.6% | 54.4% |
| cautious | 13.2% | 16.0% |
| greedy | 15.4% | 18.0% |
| random | 13.8% | 17.6% |

Report without: `reports/s4b_grid_final_without_5pct.md`.

## 2.4 Targets

Met:

- Build 54.4% (in band, at the top edge, not mid-band), greedy 18.0%, random 17.6%.
- Battle 1 odds under 95% for build, cautious and greedy.
- Battle 1 no longer free for build (92.8%); battle 5 is no longer the only gate.
- Fights 41-49 s; battle 5 mean under 50 s; cap hits 0-4% for build, at most 10% for any policy.
- ULTRA price 45.

Missed:

- Cautious 16.0% against a 25-40 band (9 points low). It loses battles 4 and 5.
- Random policy battle 1 odds 97.1% (limit 95%).
- Build curve is too easy from battle 2 on: 96.6 / 89.3 / 84.5 / 80.5 against 80-90 / 75-85 /
  70-80 / 60-75. Battle 2 is the clearest miss.
- Late gold for build 49.8 (target about 45 or less).
- `ENEMY_HP_MULT` is back in the 1.1 range only for battles 1-2 (before the 5% cut), not 1.1-1.35
  across the run.
- ULTRA is still rarely bought at 45: 0-1.2% of runs (seen in about 20%). The runs that bought one
  won far more often (50-67%), on 4-10 runs per policy, so that is not a measured effect.

## 2.5 Policy rules used

- **build**: role-driven. Picks parts by stat and ability value for the monster's role, keeps half
  its gold spare, buys a body only after parts (up to 4 bodies). Not forced to buy humans first.
- **greedy / cautious**: play battle 1 as bought; from battle 2 on they buy a third human before
  parts while they have fewer than 3 living monsters (`bodies=2`).
- **random**: unchanged.
- `bodies=0` (never bodies first) and `bodies=1` (always bodies first) remain as sim options. The
  default is `bodies=0`, so the final numbers need `bodies=2` on the command line.
- With the raised par, parts are competitive with bodies: at the same settings build wins about the
  same with bodies after parts as pass 1 did with bodies first. Bodies-first is still stronger for
  every policy where it was tested (grid O against M, 200 runs: build 85.5% against 68.5%).

## 2.6 Fusion power check

New sim mode: `run_sim.gd -- mode=fusion fights=100`. Report `reports/s4b_fusion.md` / `.csv`.
Ratio = fused part's ladder power / stronger parent's.

| Kind | n | Median ratio | Min | Max | Target |
|---|---|---|---|---|---|
| Hybrid | 27 | 1.46 | 0.88 | 2.00 | 1.3-1.6 |
| Twin | 22 | 1.50 | 1.13 | 4.06 | about the same as hybrid |
| Twin, timed abilities | 6 | 1.57 | 1.25 | 1.72 | about the same as hybrid |
| Signature (all 26) | 26 | 1.67 | 1.27 | 2.25 | clearly best, at most about 2 |
| Apex | 8 | 1.42 | 1.23 | 1.71 | above hybrid, not runaway |

Changes made:

- Twins of timed abilities were 2.13x their parent (1.89-2.14) because `empowered()` scaled the
  amount up and the interval down. `inverse_params()` now returns nothing for regen, mend, snipe,
  spore_pulse, swarm and titan, so only the amount scales. They now sit at 1.57x.
  `tests/unit/fusion/fusion_logic_test.gd` pinned the old intervals in two assertions; both were
  updated (regen interval stays 3.0, titan stomp interval stays 6.0).
- `FUSION_PART_STAT_MULT` [1.0, 0.75, 0.65] -> [1.0, 0.65, 0.6]: hybrids were at 1.63x.

Not in line:

- Apex median (1.42) is below hybrid (1.46), not above it. Only 8 common apexes were sampled.
- Four signatures are above 2x: butcher_blade+squid_arm 2.25, leech_maw+venom_fangs 2.23,
  fin_fan+seedpod_rattle 2.10, mantis_arm+quartz_knuckle 2.09 (measured before the stat multiplier
  change; signatures use `FUSION_SIGNATURE_STAT_MULT`, left at 1.0).
- The 4.06 twin is overgrown_heart (berserk), an ability the arena cannot see; its parent scores
  near zero, so the ratio is not meaningful.
- Two stun/venom twins are high: capacitor_heel 2.74, widow_leg 2.45 (measured before the stat
  multiplier change; not rechecked individually).

## 2.7 Skipped (deadline)

- No further iterations on the cautious band, the build curve or late gold.
- `PRICE_HUMAN` 40 was tried (grid V, 200 runs: within 1-2 points of 35) and not adopted.
- `ENEMY_TEAM_SIZE` [2, 2, 2, 3, 3] was tried once (grid J) and not adopted.
- `FUSION_TWIN_POWER` and `FUSION_SIGNATURE_STAT_MULT` were not changed.
- The build policy does not splice in the lab, so there is no win rate with/without a fused part.
- No in-game playtest of these numbers; all results are from the headless sim.

## 2.8 Tests

`Overall Summary: 160 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans` (full
`tests/unit` suite, run after the final numbers and the fusion change).
`python tools/mutation_table.py`: `OK: 100 mutations pass the stage-4 contract checks.`
