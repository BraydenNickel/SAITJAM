# Handoff: MUTANT LAB (theme: "Unnatural Evolution")

_Last updated: 2026-11-21. Stages 1–3 of 5 are done, playable and committed. Next: Stage 4._

A 2D pixel-art roguelike **auto-battler**. Humans are mutated into monsters, and the player **bets on their own battles**. It is built in **Godot 4.7.2 / GDScript** for a game jam. See `JAM.md` for the jam rules, and `design/jam-plan.md` § "CHOSEN DESIGN" for the design note.

---

## 1. User preferences (follow these every session)

- **Everything must be visible and editable in the Godot 2D editor.** Build real `.tscn` scenes: Sprite2D nodes with PNG files, Marker2D nodes as sockets and spots, and Control UI laid out in the scene. Mutation data lives in `.tres` files. **No `_draw()` visuals and no UI trees built in code.** Instancing small item scenes from code is fine. (An early version that drew everything in code was reverted because of this.)
- **Always use the project's skills and subagents.** For example: `chance-mechanic-designer`, `game-designer`, `godot-specialist`, `godot-gdscript-specialist`, `gameplay-programmer`, `technical-artist`, `economy-designer`, and the `pixelfx` skill.
- **Jam batch approval.** Show a plan of at most 3 lines and the file list, then wait for "go". Ask before deleting files, committing, or touching `project.godot`.
- **When the user says "stop", stop immediately** and only report.
- **Playable after every stage.** Verify by running the game and taking screenshots before reporting a stage as done.

---

## 2. Design decisions (approved by the user)

| Topic | Decision |
|---|---|
| Core | Hook A+C from the jam plan: bet on yourself, with push-your-luck. Inspired by creature auto-battlers like *Batomon Showdown* (style only, nothing copied). |
| Run | 5 battles. **One life**: losing a battle ends the run. Start with 2 humans ("Subject 01/02") and 40 gold. |
| Loop | Hub (Lab / Shop / Incubator / Roster / Fight) → Formation → Bet → auto-Battle → *(Stage 3: pick 1 of 3 rewards)* → Hub |
| Formation | 6 spots per side: **2 front, 2 middle, 2 back**. The player places 1–4 monsters. **Enemy spots are random.** Units attack the front-most row that still has a living unit. |
| Body slots | HEAD, TORSO, BACK, **ARM_L, ARM_R, LEG_L, LEG_R**, TAIL. Every slot can be mutated. Arm and leg mutations fit either side and stack. |
| Architecture | Composition: one generic Monster holds data-driven mutations (`MutationData` `.tres` = sprites + stat mods + an `AbilityData`). Hooks `on_battle_start / on_tick / on_attack / on_hit / on_take_damage / on_ally_death` combine through a shared `HitInfo`, with no glue code. Hook damage goes at most 1 level deep and never re-triggers the same ability. |
| Starting mutations (6) | Bone Plating (TORSO), Mantis Arm (ARM), Leech Maw (HEAD), Spore Sacs (BACK), Raptor Leg (LEG; replaced Brood Crown so legs are covered), Scorpion Tail (TAIL). More will be added later. |
| Lab risk | Instability 0–100. `success% = clamp(100 − instability − rarity_risk + stabilizers, 5, 100)`. On a fail the monster becomes **MUSH**: retired permanently, 40% refund, +15% "Mush Memory" on the next operation. |
| Fusion | In the Incubation Chamber. Takes two monsters with at least 2 mutations each. Stats = 0.6×(A+B)×1.25. `success% = clamp(90 − avg instability + stabilizers, 10, 95)`. On a fail both become mush. Fusion titles fill a Codex. |
| Bets | Claims: Victory / Flawless / Blitz (<25 s) / Last Stand / MVP. Odds come from **simulating the real matchup** (`SIM_RUNS`). `mult = clamp(0.9/p, 1.1, 10)`. At most 2 claims, each at most 50% of gold. A 15g sponsor grant prevents soft-locks. Celebrations scale with **net** gold. |
| Shop | 5 slots (3 mutations, 1 human, 1 stabilizer), new stock every visit. Reroll costs 5g, +3g for each further reroll. A rare is guaranteed after 3 visits without one. |
| Champion | The team that wins battle 5 is saved to `user://` and becomes the next run's battle-5 boss, with stats normalized to 0.9–1.3× of the tier budget. Runs with no saved champion face "Dr. Splice". |
| Autoload | `Game` (`res://src/game.gd`). Approved by the user; registered in `project.godot`. |
| Numbers | Global rules go in `src/data/tuning.gd`. Per-mutation numbers go in `src/data/mutations/*.tres`. |
| Guardrails | Odds always shown, no fake near-misses, no real money, no casino imagery. |

---

## 3. What's built

### Stage 1: monsters + hub ✅
- `src/game.gd`: autoload for run state, screen routing (`go_to`), `ensure_run()` (lets any screen run alone with F6), battle setup.
- `src/data/defs/`: `mutation_data.gd`, `monster_data.gd`, `run_state.gd` (the field is `rng_seed`; `seed` would shadow a built-in).
- `src/data/mutations/*.tres` (6), `kinds/human.tres`, `examples/demo_mutant.tres` (all 6 mutations).
- `src/monster/monster_view.gd` (**@tool**: assign `data` in the Inspector and the parts redraw live), `monster_front.tscn`, `monster_side.tscn` (8 Marker2D sockets), `part_sprite.tscn`, `demo_monster.tscn` (editor showcase).
- `src/main.tscn` (title screen), `src/screens/hub.*`, `roster.*`, `src/ui/monster_card.*`, `src/ui/theme.tres`.

### Stage 2: battle + betting ✅
- Logic (no Nodes, seeded RNG, deterministic): `src/battle/battle_sim.gd`, `unit_state.gd`, `hit_info.gd`, `bet_odds.gd`, `src/data/enemy_gen.gd`, all 6 abilities in `src/data/abilities/`.
- Scenes: `src/screens/formation.*`, `bet.*`, `bet_row.*`, `run_end.*`, `src/battle/battle.tscn/.gd`, `battle_unit.*`, `damage_number.*`, `src/ui/monster_slot.*`, `bet_text.gd`.
- Battle speed uses `Engine.time_scale` (1×/2×/4×) and is reset on exit.

### Stage 3: Lab, Shop, Rewards, balance ✅
- Logic (static, deterministic, tested): `src/data/lab_logic.gd` (`success_chance`, `chance_breakdown`, `operate`, `purge`), `shop_logic.gd` (`ensure_stock` = one stock per battle, `reroll`, `can_buy`, `buy`, rare pity, no duplicate mutations in one stock), `reward_logic.gd` (`roll_options`, `apply`; 8 option ids).
- `RunState` now holds `inventory`, `mush_memory`, the one-shot buffs `lucky_gene`/`insurance`/`catalyst`, the shop state, and `living_count()`.
- Logic mutates `run` (gold included). Screens then call `Game.notify_gold()`. `Game.rng` (seeded from the run) is used for lab and shop rolls.
- Screens: `src/screens/lab.*` (operate + purge modes, ghost preview, breakdown, result panel), `shop.*`, `reward.*` (after every non-final win, from `Game.complete_battle`). Item scenes: `src/ui/inventory_item.*` (also holds the shared rarity and stat helpers), `subject_button.*`, `shop_slot.*`, `reward_card.*`.
- Mush jar: `assets/sprites/mush_jar.png` (from `tools/gen_parts.py`), shown on the monster card and roster. The hub shows living monsters only.
- **Adaptive enemies** (user's choice): `EnemyGen.player_power(roster)` = budget cost of the living roster's mutations + `ADAPT_BODY_POWER` per extra body. `adapt_bonus` = `clamp(round(ADAPT_RATE × (power − ADAPT_EXPECTED[i])), 0, ADAPT_MAX[i])` is added to the enemy budget; budget that can't be spent becomes HP. It is computed in `Game.prepare_battle()` (formation `_ready`) and shown on the bet screen (`AdaptLabel`).
- `ENEMY_HP_MULT` sets enemy base HP per battle (Stage 4 champions must skip it).
- Balance simulator: `tools/balance/run_sim.gd`. Policies are greedy, cautious, random and build. Command: `"<godot>" --headless --path . -s res://tools/balance/run_sim.gd -- runs=500 policy=all seed=1 odds=10` (use `runs=200 odds=0` for fast iterations). Reports go to `reports/` (gitignored). Design and results: `design/balance/stage3-tuning.md` §1–6.

### Art
- `assets/sprites/torso/human_front.png`, `human_side.png`: the user's 64×64 art.
- `assets/sprites/parts/<id>_front|side.png`: 32×32 parts, **centered on the socket**. ARM/LEG art is the LEFT side; the right side uses `flip_h`. Generated by `tools/gen_parts.py`.
- `assets/sprites/battle/arena_bg.png`: a lab arena with green vats. Generated by `tools/gen_battle_bg.py`.
- Both generators use **only the Python standard library** (PIL is not installed).

### Socket coordinates (pixels on the 64×64 torso; Marker2D position = (x−32, y−32))
- **Front:** HEAD (32,12), TORSO (32,32), BACK (32,28) z−1, ARM_L (18,34), ARM_R (46,34), LEG_L (24,53), LEG_R (40,53), TAIL (32,46) z−1
- **Side** (faces right): HEAD (34,18), TORSO (34,40), BACK (29,38) z−1, ARM_L/R (35,40) z−1/+1, LEG_L/R (34,56), TAIL (28,48) z−1
- Optional tweaks suggested by the art agent: side TAIL → (24,46); front BACK → (32,30).

### Battle spot layout (`battle.tscn`)
- Player x 240 (front) / 160 / 80 (back); enemy x 400 / 480 / 560; rows y 180 and 268. Units are drawn at scale 1.0.
- The background shadows match these positions. If spots move, update `tools/gen_battle_bg.py` too.

### Tests
- gdUnit4: `tests/unit/monster/`, `battle/` (includes `enemy_scaling_test.gd`), `lab/`, `shop/`, `reward/`. **59 tests, all passing.**
- Screenshots: `production/qa/evidence/stage1_*.png`, `stage2_*.png`, `stage3_*.png`. Screenshot and flow scripts: `production/qa/stage3_shots.gd`, `stage3_flow_check.gd`, `stage3_adapt_shot.gd`.

---

## 4. Things we learned (gotchas)

1. **The Godot MCP (`godot` server, Coding-Solo) launches Godot 4.6, not 4.7.2.** It is configured in the user-level Claude config, not this repo. Fix it by setting `GODOT_PATH` to `C:/Godot/Godot_v4.7.2-stable_win64_console.exe`. Until then, verify directly:
   - Import: `"C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import`. **Run this after adding any new `class_name` script or asset**; otherwise you get errors like "Could not find type RunState".
   - Run a scene: `... --headless --path . --quit-after 120 res://src/screens/hub.tscn`
   - Tests: `... --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode`
   - Screenshots: run windowed (not headless) with a small `SceneTree` script that calls `Game.new_run()` and `Game.prepare_battle()`, changes scene, waits N frames, then calls `root.get_texture().get_image().save_png(...)`.
2. **An open editor keeps stale project settings.** After `project.godot` changes (for example the `Game` autoload), the editor shows `Identifier not found: Game` until you choose **Project → Reload Current Project**. Don't save Project Settings from a stale editor, because it would remove the autoload line.
3. **Godot leaves default values out of `.tres` files.** `MutationData.socket_type` defaults to TORSO, so a HEAD mutation **must** contain `socket_type = 0` explicitly. (`leech_maw.tres` had this bug; it's fixed.)
4. **Subagents stop at about 20 turns.** Large stages need a `SendMessage` to continue. Giving parallel agents a precise interface contract worked well (logic agent vs scenes agent).
5. **Simulation speed:** headless sims jump from attack to attack, with steps of at most `SIM_STEP_HEADLESS` = 0.25 s. 200 fights of 4v4 take about 0.1–0.2 s. Multithreading was 5× *slower*, so don't use it. `SIM_RUNS` is now 100 (the bet screen text still says "200 simulated fights", which needs updating).
6. Hit objects are pooled, so abilities must not keep a reference to a `HitInfo` after a hook returns. Abilities are **stateless**; per-unit state lives in `UnitState.state`.
7. The project write-guard hook only auto-allows subagent writes in `production/`, `docs/` and `tests/`. Briefs must name their allowed paths explicitly. (Writes to `src/`, `tools/` and `design/` still go through, with a warning.)
8. Almost every subagent hits the ~20-turn limit. Plan on one `SendMessage` "continue" per agent.
9. Logic result dictionaries use StringName keys (`&"ok"`, `&"success"` …); read them the same way.
10. `reports/` is gitignored (gdUnit HTML and balance reports). Durable balance notes go in `design/balance/`.

---

## 5. Balance snapshot (after Stage 3 + adaptive enemies, 500 runs per policy, seed 1)

Key values: `BASE_HP` 360, `ENEMY_BUDGET [2,4,6,10,14]`, `ENEMY_HP_MULT [1.3,1.35,1.15,1.2,1.25]`, prices [10,18,30] / human 30 / stabilizer 10, `BATTLE_REWARD [20,25,30,28,0]`, `ADAPT_EXPECTED [7,9,10,12,14]`, `ADAPT_RATE` 3.5, `ADAPT_MAX [2,4,6,8,10]`.

| | greedy | cautious | random | build |
|---|---|---|---|---|
| Run win | 12.6% | 26.6% | 4.8% | **43.4%** |
| Reach B3 | 54% | 75% | 66% | 87% |
| Mean fight | 35–39 s | 38–42 s | 41–47 s | 36–44 s |
| B1 sim odds | 87% | 90% | 85% | 92% |
| Gold at B5 hub | 48 | 39 | 51 | 56 |

- On target: build at 35–50%, greedy at 10–20%, fights at 35–50 s, B1 odds under 95%.
- Slightly off: random at 4.8% (band 5–15%), greedy reaching B3 at 54%, late gold over 45 (next knob: `BATTLE_REWARD[2]` 30 → 25, or a gold sink such as the Stage 4 fusion cost).
- Watch in playtests: power counts mutations, not synergy, so the steep `ADAPT_RATE` can punish players who stack many weak mutations. Frenzy (fights over 45 s) is common in random play and in build's B5 fights.
- Full numbers: `design/balance/stage3-tuning.md` §5–6.

---

## 6. Still needed

### Open issues
- [ ] Scorpion Tail is barely visible in the front view (it's behind the body). Consider a different front sprite or z-order.
- [ ] Lab SubjectButton names use the large 16 px font; a smaller font would look better.
- [ ] No reward screenshot yet with a free-mutation card (the code path is there).
- [ ] Rename tests to `[system]_[feature]_test.gd` if strict naming is wanted (optional).
- [ ] Commits only when the user asks.

### Stage 4: Incubator, full run, champion (next, waiting for "go")
- Note: the champion boss must skip `ENEMY_HP_MULT`. Decide whether the adaptive bonus applies to it (probably not, since it is normalized to the budget instead). Fusion should add a gold sink (`FUSION_COST`), which helps the late-gold pile-up.
- `src/screens/incubator.*`: pick 2 monsters, preview the fused result and success %; on overlapping slots choose which to keep, and the other becomes an "Echo" (50% of its stats, no ability); a generated title; the Codex.
- Champion save: `ResourceSaver.save(..., "user://champion.tres")` using `duplicate_deep()`. Load with `CACHE_MODE_IGNORE`. Normalize the champion to 0.9–1.3× of the budget. Show "Beat your last run" on battle 5.
- Run-end summary: net-gold graph and newly found titles.

### Stage 5: Juice (pixelfx)
- Use the `pixelfx` skill (`tools/pixelfx`; `node tools/pixelfx/tools/render.mjs <category>/<name> --sheet`, copy the `.png` and `.json` into `assets/fx/`, then `PixelFxPlayer.spawn(parent, "res://assets/fx/<name>.json", pos)`). Recolor with `palette`.
- Effects for: each ability trigger (`AbilityData.fx_json`), hits and crits, deaths, mush failure, fusion success, bet and battle wins (scaled to net gold), shop purchase, coins.
- Sound, screen shake on crits and deaths, polish.

### Later (user said "expand later")
- More mutations beyond the first 6, more champion and "beat your last run" features.
- Run the `game-chance-compliance-check` and `retention-loop-audit` skills before release.
