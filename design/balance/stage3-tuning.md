# Stage 3 balance tuning: MUTANT LAB

Source: `reports/balance_baseline.md` (500 runs, seed 1). All numbers below are proposals to
apply, re-run the sim, and then correct with §4. Design decisions (handoff §2) are untouched.

## 1. Changes

| File | Key | Old | New | Rationale |
|---|---|---|---|---|
| tuning.gd | `BASE_HP` | 100.0 | **330.0** | HP x3.3 sets battle length (§2). Humans and enemies both use it. |
| tuning.gd | `PRICE_BY_RARITY` | [12, 22, 38] | **[10, 18, 30]** | Mutations become worth more per gold than a body (§2b). |
| tuning.gd | `PRICE_HUMAN` | 20 | **30** | A body was the best buy per gold. It is still a body, but now a deliberate one. |
| tuning.gd | `PRICE_STABILIZER` | 15 | **10** | 2 stabilizers (+50%) = 20g protects a 60-100g monster: a real choice instead of a tax. |
| tuning.gd | `INSTABILITY_PER_RARITY` | [10, 20, 30] | **[10, 15, 25]** | A focused carry can take 5-6 parts at about 80-100% with stabilizers. Stacking stays costly, not suicidal. |
| tuning.gd | `ENEMY_BUDGET` | [1, 3, 6, 10, 16] | **[1, 3, 5, 8, 12]** | Budget = enemy damage. Removes the B5 DPS spike (19 to 28). |
| tuning.gd | `ENEMY_HP_MULT` *(new)* | none | **[1.2, 1.25, 1.15, 1.2, 1.25]** | Enemy HP = toughness and length. Makes B1/B2 a real fight and keeps late fights long without raising enemy DPS. |
| tuning.gd | `BLITZ_TIME` | 25.0 | **30.0** | Betting only: Blitz stays a long shot (~p15 of win durations) once fights run about 40 s. |
| bone_plating.tres | `hp_mod` | 30.0 | **100.0** | Scales with `BASE_HP` (x3.3). |
| spore_sacs.tres | `hp_mod` | 10.0 | **35.0** | Scales with `BASE_HP`. |
| spore_sacs.tres | ability `damage` | 3.0 | **4.0** | Uncommon buff: 1 AoE DPS per enemy, ignores DEF. The anti-tank pick. |
| leech_maw.tres | `atk_mod` | 2.0 | **4.0** | Uncommon was the weakest buy (about 80 strength per gold, see §2b). |
| leech_maw.tres | ability `fraction` | 0.25 | **0.4** | Lifesteal scales with the carry's DPS: rewards focusing it. |
| raptor_leg.tres | `interval_mod` | -0.15 | **-0.25** | Speed stacks with Mantis (2 legs + 2 arms = 0.7 s interval). This is the build payoff. |
| raptor_leg.tres | ability `chance` | 0.12 | **0.18** | Dodge on a carry or tank is now noticeable. |

Unchanged on purpose: Mantis Arm, Scorpion Tail, `STABILIZER_BONUS` 25, `STABILIZER_MAX` 2,
`RISK_PER_RARITY`, `MUSH_REFUND`, `BATTLE_REWARD`, sponsor, `RARITY_WEIGHTS`, `ENEMY_TEAM_SIZE`, frenzy and cap.
Also update the `description` text in the 4 edited .tres files (for example "+100 HP, +3 DEF").

**New const, exact placement.** In `tuning.gd` under "Enemy generation":
`const ENEMY_HP_MULT: Array[float] = [1.2, 1.25, 1.15, 1.2, 1.25]`. Apply it in `EnemyGen.generate()`
right after `team.append(m)` (line 56): `m.base_hp = Tuning.BASE_HP * Tuning.ENEMY_HP_MULT[i]`.
It scales the base body only, not mutation `hp_mod`. It also covers the B5 Dr. Splice team. Stage 4
champions are normalized separately and must skip it. `BetOdds` reuses the generated team, so the odds stay consistent.

## 2. Math

**a) Battle length.** Damage stays the same everywhere, so length scales with HP / DPS.
- Solo: a human was 100 HP / 3.94 DPS (6 x 1.05 / 1.6) = **25 s** to kill. Now 330 / 3.94 = **84 s**.
- Team, greedy, baseline: enemy HP / raw player DPS was 216/13.9 = 15.5 s (B1) to 459/22.5 = 20.4 s (B5). The observed win means were 10.6-13.4 s, because venom, spores and double strike add about 35-60% hidden DPS.
- After: win duration is roughly baseline x 3.3 x `ENEMY_HP_MULT` / player power gain. The power gain comes from cheaper parts and buffed uncommons, and is estimated at 1.15 / 1.15 / 1.25 / 1.3 / 1.35:

| | B1 | B2 | B3 | B4 | B5 |
|---|---|---|---|---|---|
| Baseline win mean (s) | 11.7 | 10.6 | 12.5 | 12.0 | 13.4 |
| Enemy HP / player DPS, before | 15.5 | 14.9 | 19.3 | 17.2 | 20.4 |
| Predicted mean (s) | ~40 | ~38 | ~38 | ~37 | ~41 |

Frenzy (45 s) should now trigger on about 15-25% of fights, the slow tail, as a tiebreaker. That is intended.
Longer fights also lower the variance (more hits per fight), so favorites win more often. That is
why B1/B2 need the enemy HP bump and not just the length fix.

**b) Bodies vs builds (Lanchester: strength is about team HP x team DPS).** Team before the buy: 2 humans (660 HP, 14 DPS).
- Human: (990)(17.94) - (660)(14) = **8,520**. At 20g that was 426 per gold. At 30g it is **284 per gold**.
- Mantis Arm on a base human (+6.1 DPS): 660 x 6.1 = **4,030**. At 12g that was 336 per gold. At 10g it is **403 per gold**.
- Leech Maw, old: about +1.3 DPS plus about 50 HP healed, around 1,500, at 22g = **68 per gold**. New: +2.6 DPS plus about 140 HP healed on a carry, around 3,600, at 18g = **200 per gold**. On a Mantis/Raptor carry it reaches about 300 per gold.
- Result: a common is about 1.4x a human per gold, which covers the mush risk. An uncommon is worse alone and better on a carry. That gap is the reason to plan a build.

**c) Carry ceiling.** 2 Mantis + 2 Raptor + Leech on Subject 02 (Scorpion Tail) gives ATK 18, interval 0.7 s, crit 0.15, and 5/3 strikes per attack.
That is 18 x 1.15 / 0.7 x 1.67 = **49 DPS** plus 5 venom DPS. Instability is 10 + 10 + 15 + 15 + 15 = 65 (B5 reachable).
Cost: 10 + 10 + 18 + 18 + 18 = 74g plus about 6 stabilizers (60g). This is about 90% of a run's income.
It is strong but has to be earned. Enemy archetypes rarely combine Mantis and Raptor.

## 3. "build" sim policy (smart play)

Roles: **Carry** = Subject 02 (it starts with Mantis + Scorpion). **Tank** = the other living monster with the highest max HP.
If the carry is mushed, the living monster with the most mutations becomes the carry, and the tank is chosen again.

1. **Plan lists** (socket order = priority):
   carry wants `mantis_arm, raptor_leg, raptor_leg, leech_maw, mantis_arm (2nd arm), bone_plating`.
   Tank wants `bone_plating, leech_maw, spore_sacs, raptor_leg`. A mutation is *on-plan* if
   a free slot of its socket exists on the carry or tank and the id appears in that monster's list.
2. **Shop, in this order:**
   a. Compute `need` = stabilizers to bring each planned op to at least 90%, minus stabilizers owned.
   b. Buy on-plan mutations, carry first, cheapest rarity first. Buy one only if
      `gold - price >= need_for_it * PRICE_STABILIZER`.
   c. Buy stabilizers up to `need` (max 2 per op).
   d. If nothing on-plan was in stock and `gold >= reroll_cost + 18`: reroll, at most 2 per visit, then repeat a-c.
   e. Buy a human only if `living < 2`, or if `living < 3` and `gold >= PRICE_HUMAN + 10` after a-d.
   f. Off-plan mutations: buy only commons, only if `gold >= 25` after a-e, and give them to non-carry monsters.
3. **Lab:** operate on the carry or tank (plan target). Add stabilizers until the chance is at least 90%.
   Operate only if the chance is at least 85%; otherwise keep the part in inventory for the next visit.
   Never operate on the only living monster below 100%. Off-plan parts go to the lowest-instability non-carry.
4. **Formation:** tank in spot 0 (front). Other non-carry monsters by HP in spot 1, then 3. Carry in **spot 2**
   (middle row; enemies hit the front row first). If the carry is the only living monster, it goes in spot 0.
5. **Reward, first valid:** free_mutation if on-plan > stabilizers if `need > 0` > catalyst if carry instability
   >= 40 > free_human if living < 3 > gold > lucky_gene > insurance > cleanse > first option.

Report `build` as a 4th column next to greedy, cautious and random (the same tables).

## 4. Expected results and next knobs

| Target | Expected after this tuning | If missed, turn this next |
|---|---|---|
| Fight mean 35-50 s | 36-42 s, p90 about 55 s | < 35: `BASE_HP` +30 (and bone/spore `hp_mod` x the same ratio). > 50: -30. |
| Frenzy is rare, not routine | 15-25% of fights | > 35%: `FRENZY_START` 45 to 50, or `BASE_HP` -30. |
| About 60% of runs reach B3 (all policies) | build 75%, greedy 60%, random 55%, cautious 60% | Too high: `ENEMY_HP_MULT[0..1]` +0.1 each. Too low: -0.1. |
| B1 bet odds not all 99-100% | mean P(win) at B1: 85-92% | Still at least 96%: `ENEMY_HP_MULT[0]` 1.2 to 1.35. |
| Build wins clearly: 35-50% | build about 38% (B3 80, B4 78, B5 75%) | < 35: `ENEMY_BUDGET[4]` 12 to 11. > 50: 12 to 14. |
| Random/naive wins 10-20% | random about 10%, greedy about 15% | Random > 20%: `PRICE_HUMAN` 30 to 35. Random < 8%: `ENEMY_HP_MULT[2..4]` -0.05. |
| Mutations beat bodies | random (buys humans) wins less than greedy | If not: `PRICE_BY_RARITY[0]` 10 to 8, and check uncommon pick rate. |
| Stabilizers are a choice | cautious spends about 30g on them; build about 40g | No one buys them: `PRICE_STABILIZER` 10 to 8. Always bought: `STABILIZER_BONUS` 25 to 20. |
| Mush is a risk, rarely the end | greedy mush 10-15% per op; no-living ends < 3% of runs | Ends > 3%: `INSTABILITY_PER_RARITY[2]` 25 to 20. Mush < 5% for greedy: back to [10, 20, 30]. |
| No late gold pile | gold at hub B5 < 45 (rerolls are the sink) | > 55: `BATTLE_REWARD[3]` 35 to 28. |

Change one row's knob per re-run. Read B1/B2 rows first: the length fix and the cliff fix interact,
because longer fights make favorites win more often. Confidence: the length numbers are solid (pure HP scaling).
The win rates are estimates (±10 pts), because raw DPS misses ability value. Let the sim decide.

## 5. Results (applied 2026-11-21)

Sim: `tools/balance/run_sim.gd -- runs=500 policy=all seed=1 odds=10`, report in
`reports/balance_stage3.md`. Iterations used `runs=200 odds=0`. A `build` policy (§3) was added to the sim.

### Final values

All of §1 was applied as written (descriptions updated). `human.tres` stores no `base_hp`, so it uses
`Tuning.BASE_HP` from the script default; enemies get `BASE_HP * ENEMY_HP_MULT[i]` in `EnemyGen.generate()`.
Changes made during iteration:

| # | Knob | §1 value | Final | Why |
|---|---|---|---|---|
| 1 | `BASE_HP` (+ bone/spore `hp_mod` x same ratio) | 330 (100 / 35) | **360** (**109 / 38**) | Fights were 31-38 s (< 35). §4 row 1. |
| 2 | `ENEMY_HP_MULT[0..1]` | 1.2, 1.25 | **1.3, 1.35** | B3 reach too high (72-92%). §4 row 3. Effect on wins: almost none (only longer fights). |
| 3 | `ENEMY_BUDGET[4]` | 12 | **14** | Build run win 87%. §4 row 5. Effect: build -2 pts. |
| 4 | `ENEMY_BUDGET[0..1]` | 1, 3 | **2, 4** | Not in §4: HP mult did not move B1/B2 wins. Enemy damage did (random/greedy B3 reach 84/72 -> 67/65). |
| 5 | `ENEMY_HP_MULT[2..4]` probe 1.45/1.5/1.5 | - | reverted | Build win only 85 -> 80%, but fights 42-49 s and frenzy 30-70%. Not worth it. |
| 6 | `ENEMY_BUDGET[2..3]` | 5, 8 | **6, 10** | Back to the old values; greedy/random/cautious late wins dropped, build unchanged. |

Final: `BASE_HP 360`, `ENEMY_BUDGET [2, 4, 6, 10, 14]`, `ENEMY_HP_MULT [1.3, 1.35, 1.15, 1.2, 1.25]`,
`PRICE_BY_RARITY [10, 18, 30]`, `PRICE_HUMAN 30`, `PRICE_STABILIZER 10`, `INSTABILITY_PER_RARITY [10, 15, 25]`,
`BLITZ_TIME 30`; bone_plating hp_mod 109, spore_sacs hp_mod 38 / damage 4, leech_maw atk 4 / fraction 0.4,
raptor_leg interval -0.25 / dodge 0.18.

### Before / after (500 runs, seed 1)

| Target | Baseline | After | Status |
|---|---|---|---|
| Fight mean 35-50 s | 11-15 s | greedy 34.5-37.9, cautious 37.5-41.9, random 43.9-47.2, build 33.5-42.9 | **Met** (build B2 33.5, greedy B4 34.5 just under) |
| Frenzy 15-25% of fights | 0% | greedy 12-23, cautious 17-37, random 35-56, build 6-40 (B5) | Partly: random and cautious B1 too high |
| ~60% reach B3 (55-75%) | 72 / 79 / 90 / - | greedy 63.6, cautious 77.8, random 67.8, build 89.8 | **Met** for greedy/random, cautious just over, build over |
| B1 P(win) clearly < 99% | 94 / 91 / 97 | 89.7 / 89.5 / 85.0 / 92.4 | **Met** |
| Build run win 35-50% | - | **82.0%** | **Missed** (badly) |
| Random/greedy run win 10-20% | 14.4 / 18.4 | random **11.2**, greedy **28.2** (cautious 37.6) | Random met, greedy missed |
| Random wins less than greedy | yes | 11.2 < 28.2 | Met |
| Greedy mush <= ~15% per op | 17.5% | 18.2% overall (8 at B1, 19-27 later) | Missed (about the same as before) |
| No-living ends < 3% of runs (greedy) | 9.6% | **13.2%** | **Missed** |
| Gold at hub B5 < 45 | 44-56 | greedy 53, cautious 46, random 57, build 64 | Missed (build banks gold: reroll cap 2) |

### What is still off

1. **The build policy is far too strong (82% run win).** It wins 97-98% of B2-B4 fights. Enemy HP and budget
   changes that hurt the other policies barely touch it (6 iterations: 87 -> 82%). Enemy HP is a bad
   lever: longer fights make the favorite win more often. The focused Mantis/Raptor/Leech carry in the
   middle row with a bone-plated tank in front beats random enemy archetypes by a wide margin. Next steps need
   a design call: weaker carry payoff (raptor `interval_mod` back toward -0.15, leech `fraction` 0.3), enemies
   that target the middle row or scale with the player's power, or accepting that skilled play wins about 80%.
2. **Greedy loses its whole roster in 13% of runs.** The greedy sim operates at >= 50% chance, so this is mostly
   reckless play. §4's knob (`INSTABILITY_PER_RARITY[2]` 25 -> 20) would make everyone stronger, so it was not
   applied while wins were already too high.
3. Gold piles up for the build policy (64 at B5). `BATTLE_REWARD[3]` 35 -> 28 is the §4 knob; not applied yet.
4. Random fights often reach frenzy (35-56%): random teams are slow and bulky. Fine as a tiebreaker; watch it.

## 6. Adaptive scaling (applied 2026-11-21)

Why: with fixed enemies the `build` policy won 82% of runs (§5). Enemies now scale with the
player's lab, and the bet screen says so. Sim: `runs=500 policy=all seed=1 odds=10`, report in
`reports/balance_stage3b.md`. Iterations used `runs=200 odds=0`.

### Rule

- **Power** (`EnemyGen.player_power(roster)`): over the whole **living** roster (not the formation, so
  benching cannot game it), the sum of `cost_of` (= `BUDGET_COST[rarity]`: 1 / 2 / 3) of every installed
  mutation, plus `ADAPT_BODY_POWER` per living monster beyond `START_HUMANS`. A new run starts at 4
  (Mantis Arm 1 + Scorpion Tail 3).
- **Bonus** (`EnemyGen.adapt_bonus(i, power)`): `clampi(roundi(ADAPT_RATE * (power - ADAPT_EXPECTED[i])), 0, ADAPT_MAX[i])`.
  It is never negative: enemies only get harder.
- **Generation:** `EnemyGen.generate(i, rng, power = 0)` spends `ENEMY_BUDGET[i] + bonus`. Budget the
  round-robin cannot spend (all sockets full) becomes base HP on every enemy: `base_hp *= 1 + ADAPT_HP_PER_POINT * leftover`.
  With the current budgets this never happens (at most 24 points over 4 x 8 sockets); it is a safety valve.
  The result dict carries `&"adapt": bonus`. Power 0 gives exactly the old team (unit-tested).
- **When:** `Game.prepare_battle()` runs when the formation screen opens, i.e. after the hub (shop, lab,
  incubator). Formation cannot change the roster, so the power is the roster at fight time. It stores
  `Game.enemy_adapt`.
- **Shown:** `bet.tscn` has an `AdaptLabel` (bottom-left): "Enemies adapt to your lab: +N power", hidden
  when N = 0. Bet odds already simulate the adapted team, so they stay honest.

### Final values

| Const | Value | Note |
|---|---|---|
| `ADAPT_EXPECTED` | **[7, 9, 10, 12, 14]** | Greedy-sim power at each fight was 7.2 / 9.0 / 10.6 / 12.2 / 14.1. B3 set to 10 (iteration 4), because build sat at 11.4. |
| `ADAPT_RATE` | **3.5** | The power gap between build and the others is only 1-3 points, so the slope has to be steep. |
| `ADAPT_MAX` | **[2, 4, 6, 8, 10]** | Build's mean bonus (1.7 / 4.2 / 5.5 / 6.7 at B2-B5) stays under the caps. |
| `ADAPT_BODY_POWER` | **2** | 3 punished `random` (it buys the most bodies) below 5%. |
| `ADAPT_HP_PER_POINT` | **0.1** | Safety valve only (see above). |
| `BATTLE_REWARD[3]` | 35 -> **28** | §4 last row: B5 hub gold was > 45 for 3 of 4 policies. |

Iterations (200 runs, one knob each, run win greedy / cautious / random / build):

| # | Change | Result |
|---|---|---|
| 0 | first guess: expected [6,8,10,12,14], rate 0.5, max [2,3,4,5,6], body 3 | 19.0 / 28.5 / 7.0 / 75.5 |
| 1 | expected [7,9,11,12,14], rate 1.0, max [2,4,6,8,10] | 15.5 / 29.0 / 7.0 / 69.0 |
| 2 | rate 2.0 | 12.5 / 26.5 / 4.5 / 51.5 |
| 3 | body power 3 -> 2 | 12.5 / 26.5 / 7.5 / 64.0 |
| 4 | expected[2] 11 -> 10 | 12.5 / 26.0 / 7.5 / 62.5 |
| 5 | rate 3.0 | 12.0 / 23.0 / 6.0 / 52.0 |
| 6 | rate 3.5 | 10.0 / 22.5 / 5.5 / 48.0 |
| final | + `BATTLE_REWARD[3]` 28, 500 runs, odds=10 | **12.6 / 26.6 / 4.8 / 43.4** |

B3 barely responds to budget (build 97.8 -> 96.1% at B3 with +3 budget). The scaling works at B4/B5,
where the bigger enemy teams use the extra budget.

### Results (500 runs, seed 1)

| Metric | greedy | cautious | random | build | Target |
|---|---|---|---|---|---|
| Run win (%) | 12.6 | 26.6 | 4.8 | **43.4** | build 35-50, greedy 10-20, random 5-15, cautious between |
| Reach B3 / B5 (%) | 54.2 / 21.6 | 75.0 / 47.4 | 66.2 / 19.0 | 87.0 / 66.0 | 55-75% reach B3 |
| Fight mean (s), range B1-B5 | 35.1-38.8 | 37.6-41.9 | 41.3-47.3 | 35.7-44.1 | 35-50 |
| B1 sim P(win) | 86.9% | 89.5% | 85.0% | 91.7% | < 95% |
| Gold at hub B5 | 47.7 | 38.6 | 51.1 | 56.3 | < 45 |
| Adapt bonus B5 (mean / % of fights) | 3.8 / 47 | 1.4 / 24 | 2.5 / 38 | 6.7 / 85 | - |
| Mush per op (overall) | 17.5% | 6.1% | 4.5% | 3.2% | ~15% |
| Frenzy > 45 s (% of fights, B1-B5) | 16-29 | 18-37 | 33-56 | 12-56 | 15-25 |

Met: build 43.4 (was 82), greedy 12.6 (was 28.2), cautious between them, fight length, B1 odds.
Near misses: random 4.8% (0.2 under the band, it fell from 5.5 at 200 runs when the B4 reward cut
went in); greedy reaches B3 54.2% (0.8 under 55); cautious 75.0% (at the edge); build 87% (over: build loses
mainly at B4/B5 now, by design). B5 hub gold dropped (53/46/57/64 -> 48/39/51/56) but is still > 45 for
3 of 4 policies; the next knob is `BATTLE_REWARD[2]` 30 -> 25, or a gold sink.
Greedy mush 17.5% per op (23-27% at B2-B4) is accepted: it comes from the greedy sim's 50% operate
threshold. With the same parts, cautious (operates at >= 80%) is at 6.1% and build (>= 85%) at 3.2%.
Frenzy is high for random and for build at B5 (bigger, adapted teams); watch it in playtests.
