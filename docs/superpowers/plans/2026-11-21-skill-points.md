# Skill Points Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permanent skill points earned per battle won, spent on a Skills screen in the main menu for moderate bonuses.

**Architecture:** `SkillStore` persists points and ranks in `user://skills.json` (static, path param, like `CodexStore`). Pure `SkillEffects` turns a ranks dictionary into numbers. `Game.new_run()` snapshots the ranks into `RunState.skill_ranks`, so all logic stays pure and testable. Combat bonuses are injected into `BattleSim` (player side only), and the bet odds use the same bonuses.

**Tech Stack:** Godot 4.7.2, GDScript (static typing), gdUnit4.

**Spec:** `docs/superpowers/specs/2026-11-21-skill-points-design.md`

## Global Constraints
- Every number lives in `src/data/tuning.gd` (new section "Skills").
- UI is built in `.tscn` and visible in the editor. Only `skill_row.tscn` instances are added from code.
- Enemies and the champion are never buffed. The bet odds must include the player's bonuses.
- Godot exe: `C:/Godot/Godot_v4.7.2-stable_win64_console.exe`. Run `--headless --path . --import` after adding any `class_name`.
- Tests: `... --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode`. All 199+ tests must pass.
- No commits (the user commits).

## Review Focus
- A missing or corrupt `skills.json` loads as 0 points and no ranks (test in Task 1).
- Buying with too few points, or buying a maxed skill, changes nothing (test in Task 1).
- `refund_all` returns exactly the points that were spent (test in Task 1).
- ULTRA grafts get no bonus (test in Task 1).
- Default mods (`{}`) leave `BattleSim` unchanged, so all existing tests keep passing (Task 1).

---

### Task 1: Skill data, store, effects and game hooks (gameplay-programmer)

**Files:**
- Modify: `src/data/tuning.gd` (append a "Skills" section)
- Create: `src/data/skill_store.gd`, `src/data/skill_effects.gd`
- Modify: `src/data/defs/run_state.gd`, `src/game.gd`, `src/data/lab_logic.gd`, `src/data/fusion_logic.gd`, `src/battle/battle_sim.gd`, `src/battle/bet_odds.gd`, `src/battle/battle.gd:78`, `src/screens/bet.gd:70`
- Test: `tests/unit/skills/skill_store_test.gd`, `tests/unit/skills/skill_effects_test.gd`

**Interfaces (Produces, used by Task 2):**
- `Tuning.SKILL_POINTS_PER_WIN: int = 1`, `Tuning.SKILL_POINTS_RUN_WIN: int = 2`, `Tuning.SKILL_COLUMNS: Array[String] = ["ECONOMY", "LAB", "COMBAT"]`
- `Tuning.SKILLS: Array[Dictionary]`, in display order. Each entry is `{&"id": StringName, &"name": String, &"column": int, &"per_rank": int, &"max_rank": int, &"desc": String}`, where `desc` has one `%d` for the total value. The rows (column 0/1/2):
  - `seed_money` "Seed Money" 0, 5, 4, "+%d starting gold"
  - `bounty` "Bounty" 0, 3, 3, "+%d gold per battle won"
  - `stockpile` "Stockpile" 0, 1, 2, "+%d starting stabilizers"
  - `common_graft` "Common Graft" 1, 4, 3, "+%d%% common graft success"
  - `uncommon_graft` "Uncommon Graft" 1, 4, 3, "+%d%% uncommon graft success"
  - `rare_graft` "Rare Graft" 1, 3, 3, "+%d%% rare graft success"
  - `steady_splice` "Steady Splice" 1, 3, 3, "+%d%% fusion success"
  - `thick_hide` "Thick Hide" 2, 4, 3, "+%d%% monster HP"
  - `sharp_claws` "Sharp Claws" 2, 4, 3, "+%d%% monster ATK"
  - `adrenaline` "Adrenaline" 2, 3, 3, "+%d%% attack speed"
- A skill's next rank costs `(current_rank + 1) * Tuning.SKILL_COST_PER_RANK` (`= 1`).
- `class_name SkillStore`. Static functions, `path: String = DEFAULT_PATH` last, `DEFAULT_PATH = "user://skills.json"`. File: `{"points": int, "ranks": {"<id>": int}}`.
  - `load_data(path) -> Dictionary` (a missing or corrupt file gives `{"points": 0, "ranks": {}}`), `save_data(data, path) -> bool`
  - `points(path) -> int`, `rank(id: StringName, path) -> int`, `ranks(path) -> Dictionary` (StringName → int)
  - `next_cost(id, path) -> int` (0 when maxed), `can_buy(id, path) -> bool`, `buy(id, path) -> bool`
  - `add_points(n: int, path) -> void`, `refund_all(path) -> int` (returns the points refunded)
- `class_name SkillEffects`. Static and pure:
  - `skill_def(id) -> Dictionary`, `value(ranks: Dictionary, id) -> int` (= rank × per_rank)
  - `graft_bonus(ranks, rarity: int) -> int`: common/uncommon/rare map to the three graft skills; ULTRA gives 0
  - `fusion_bonus(ranks) -> int`
  - `combat_mods(ranks) -> Dictionary` with `{&"hp_mult": float, &"atk_mult": float, &"speed_mult": float}` (1.0 + pct/100)
- `RunState.skill_ranks: Dictionary = {}` (snapshot taken at the start of a run)
- `Game.skills_path: String = SkillStore.DEFAULT_PATH`, `Game.skill_points_earned: int` (reset in `new_run`)
- `Game.SCREENS[&"skills"] = "res://src/screens/skills.tscn"` (Task 2 creates the scene)

- [ ] **Step 1: Write the failing tests**, using temp paths under `user://test_skills_*.json` that are deleted after each test:
  - `test_missing_file_loads_empty`, `test_corrupt_file_loads_empty`
  - `test_buy_spends_rising_cost`: 3 points, then buy seed_money (cost 1) and buy it again (cost 2). Expect rank 2, points 0, and `next_cost` = 3.
  - `test_buy_without_points_fails`, `test_buy_maxed_fails` (stockpile at rank 2 cannot be bought)
  - `test_refund_all_returns_spent`: after the two buys above, `refund_all` returns 3, leaves points at 3 and ranks empty.
  - `test_graft_bonus_by_rarity`: ranks `{common_graft:2, rare_graft:1}` give 8, 0, 3, 0 for COMMON, UNCOMMON, RARE, ULTRA.
  - `test_combat_mods`: `{thick_hide:3, adrenaline:1}` gives hp 1.12, atk 1.0, speed 1.03.
  - `test_battle_sim_applies_player_mods_only`: a sim with `{hp_mult: 1.12}` gives player `max_hp` = round(base × 1.12), and the enemy `max_hp` is unchanged.
  - `test_lab_breakdown_has_skills_row`: a run with `skill_ranks {common_graft:1}` and a common mutation has a "Skills" row worth +4.
- [ ] **Step 2:** Run the tests. Expected: FAIL (the classes don't exist yet).
- [ ] **Step 3: Implement.**
  - `BattleSim._init(..., events_on := true, player_mods: Dictionary = {})`: player units only. Multiply HP and ATK, then round; divide `attack_interval` by `speed_mult`.
  - `BetOdds.estimate(..., runs, player_mods: Dictionary = {})` passes the mods to `BattleSim`. `battle.gd` and `bet.gd` pass `SkillEffects.combat_mods(Game.run.skill_ranks)`.
  - In `LabLogic.chance_breakdown` and `FusionLogic.incubate_breakdown`, add a `["Skills", ...]` row (omitted when it is 0, and when `run` is null).
  - `Game.new_run`: set `run.skill_ranks = SkillStore.ranks(skills_path)`, add the `seed_money` value to gold and the `stockpile` value to `run.stabilizers`, and set `skill_points_earned = 0`.
  - `Game.complete_battle`: when `won`, compute `pts = SKILL_POINTS_PER_WIN` (+ `SKILL_POINTS_RUN_WIN` on the final battle) and call `SkillStore.add_points(pts, skills_path)`. Add `pts` to `skill_points_earned`, and add the `bounty` value to `gold_delta` before calling `add_gold`. Points are saved right away, so quitting mid-run keeps them.
- [ ] **Step 4:** Run `--import`, then the whole suite. Expected: everything passes, the new tests included.

### Task 1b: Champion grows with each run won (gameplay-programmer; extra scope approved by the user)

**Files:** `src/data/tuning.gd`, `src/data/champion_store.gd`, `src/data/enemy_gen.gd`, `src/game.gd`, `src/screens/bet.gd`, `src/screens/formation.gd`. Test: `tests/unit/champion/champion_growth_test.gd`.

- [x] `Tuning.CHAMPION_GROWTH_PER_WIN = 0.05`, `Tuning.CHAMPION_GROWTH_MAX = 0.30`.
- [x] `ChampionStore`: `@export var total_wins: int = 0` (named `total_wins` because GDScript forbids a member and a function sharing the name `wins`), set to the previous file's wins + 1 by `save_team()`. `static func wins(path) -> int` (0 if there is no file; old files load with 0).
- [x] `EnemyGen.champion_growth(wins) -> float` = 1 + min(0.05 × max(wins − 1, 0), 0.30). `generate_champion(champion, rng, growth := 1.0)` multiplies the HP/ATK factor by the growth after the normalization clamp and returns `&"growth"`. `generate_for_battle(..., growth := 1.0)` passes it through. Dr. Splice is unaffected.
- [x] `Game.prepare_battle` reads `ChampionStore.wins(champion_path)`, sets `Game.champion_growth` and `Game.champion_wins`. `EnemyGen.champion_growth_text()` adds " (+15% after 4 wins)" to the bet `%BossLabel` and formation `%EnemyLabel` (text only).
- [x] Tests: growth(1) = 1.0, growth(4) = 1.15, growth(50) = 1.30; the wins counter increments across two saves; growth 1.1 gives 10% more HP.

### Task 2: Skills screen, menu button, run-end line (ui-programmer)

**Files:**
- Create: `src/screens/skills.tscn/.gd`, `src/ui/skill_row.tscn/.gd`
- Modify: `scenes/main_menu.tscn`, `scenes/main_menu.gd` (a SKILLS button, signal `skills_pressed` → `Game.go_to(&"skills")`, included in the hover and focus lists), `src/screens/run_end.tscn/.gd` (a label reading "+N skill points" from `Game.skill_points_earned`, hidden when 0)
- Evidence: `production/qa/evidence/skills_screen.png`, `skills_menu_button.png`, `run_end_skill_points.png`; QA script `production/qa/skills_shots.gd`

**Interfaces:** consumes everything Task 1 produces (above).

- [ ] **Step 1:** Build `skill_row.tscn`: a name label, a "●●○○" rank pips label, a desc label (`desc % value`), and a buy button showing the cost, or "MAX" when maxed. `setup(def: Dictionary)` and `refresh()` read from `SkillStore`. It emits `bought(id)`.
- [ ] **Step 2:** Build `skills.tscn` in the editor: a title, a "Skill points: N" label, three column `VBoxContainer`s with header labels from `Tuning.SKILL_COLUMNS`, a Refund-all button (two-click confirm, like Settings Restart), and a Back button → `Game.go_to(&"title")`. Use the theme from `src/ui/theme.tres`. Add one row per `Tuning.SKILLS` entry to its column. Play the shared click sfx when buying.
- [ ] **Step 3:** Add a SKILLS `TextureButton` to the main menu, styled like the CODEX and POTENTIAL buttons. If it needs new button art, generate it with the same tool or palette as the existing button PNGs in `assets/sprites/menu/`.
- [ ] **Step 4:** Add the run-end label.
- [ ] **Step 5:** Run `--import`, run the full test suite, then take windowed screenshots with `production/qa/skills_shots.gd`: the menu, the skills screen with some ranks bought (use a temp `Game.skills_path`), and the run end with points. Expected: no errors in the output, and three PNGs saved.
