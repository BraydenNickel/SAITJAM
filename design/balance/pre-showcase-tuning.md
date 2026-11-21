# Pre-showcase tuning snapshot (2026-11-21)

These are the **pre-showcase** difficulty values, as committed in `4934a21`.
Restore the whole tuning file with:

```
git show 4934a21:src/data/tuning.gd > src/data/tuning.gd
```

## Difficulty-relevant consts (pre-showcase, commit 4934a21)

| Const | Value |
|---|---|
| START_GOLD | 40 |
| START_HUMANS | 2 |
| BATTLE_REWARD | [20, 25, 25, 25, 0] |
| ENEMY_BUDGET | [2, 4, 5, 8, 9] |
| ENEMY_TEAM_SIZE | [2, 2, 3, 3, 4] |
| ENEMY_HP_MULT | [1.04, 1.04, 0.9, 0.95, 0.81] |
| ADAPT_EXPECTED | [7, 9, 10, 12, 14] |
| ADAPT_RATE | 3.5 |
| ADAPT_MAX | [2, 3, 4, 5, 6] |
| ADAPT_BODY_POWER | 3 |
| ADAPT_HP_PER_POINT | 0.1 |
| PRICE_BY_RARITY | [10, 18, 30, 45] |
| PRICE_HUMAN | 35 |
| PRICE_STABILIZER | 10 |
| REROLL_BASE / REROLL_STEP | 5 / 3 |
| RISK_PER_RARITY | [0, 10, 20, 35] |
| INSTABILITY_PER_RARITY | [10, 15, 25, 35] |
| STABILIZER_BONUS / STABILIZER_MAX | 25 / 2 |
| FUSION_COST / FUSION_BASE_CHANCE | 30 / 90 |
| SAFE_LAB_BATTLES | 1 |
| FRENZY_START / FRENZY_RAMP / HARD_CAP | 30.0 / 0.10 / 60.0 |
| CHAMPION_NORM_MIN / MAX | 0.9 / 1.3 (x ENEMY_BUDGET[4]) |
| CHAMPION_SCALE_MIN / MAX | 0.1 / 3.0 |

## Pre-showcase run-win rates (handoff.md §5a; 500 runs/policy, seed 1, odds=10, bodies=2)

| Policy | Run win |
|---|---|
| build | 54.4% |
| cautious | 16.0% |
| greedy | 18.0% |
| random | 17.6% |

B1 odds 85–93% (random 97%). Fights 41–49 s.

---

## Showcase tuning (applied 2026-11-21)

Target: random ~60% run win, build >= 85%, greedy/cautious between, fights 25–45 s.

Reasoning: run win is roughly the product of five battle wins. Random at 17.6%
is ~0.71 per battle; 60% needs ~0.90 per battle. Build at 54% is ~0.88 per
battle; 85% needs ~0.97. That is a large shift, so the change hits three
levers at once: enemy base HP (about -15%), enemy mutation budget (-1 to -2
in B2–B5), and the adaptive bonus (rate 3.5 -> 2.0, caps roughly halved, so
strong builds are no longer pulled back toward a coin flip). Champion battle 5
stays normalized to ENEMY_BUDGET[4] automatically (now 7).

| Const | Old | New |
|---|---|---|
| ENEMY_HP_MULT | [1.04, 1.04, 0.9, 0.95, 0.81] | [0.9, 0.9, 0.76, 0.8, 0.68] |
| ENEMY_BUDGET | [2, 4, 5, 8, 9] | [2, 3, 4, 6, 7] |
| ADAPT_RATE | 3.5 | 2.0 |
| ADAPT_MAX | [2, 3, 4, 5, 6] | [1, 2, 2, 3, 3] |
| START_GOLD | 40 | 45 |

### New results

Balance sim, runs=200 policy=all seed=1 odds=0 (2026-11-21):

| Policy | Run win (before) | Run win (showcase) | Reach B3 | Fight length |
|---|---|---|---|---|
| random | 17.6% | **70.0%** | 98.0% | 39-44 s |
| cautious | 16.0% | **66.5%** | 97.0% | 39-43 s |
| build | 54.4% | **88.5%** | 96.0% | 37-40 s |
| greedy | 18.0% | 28.0% | 69.0% | 39-40 s |

Greedy stays low because it gambles on lab risk; casual (random) and careful
players now win most runs. Accepted as the showcase difficulty (target was
random ~60%, build >= 85%).
