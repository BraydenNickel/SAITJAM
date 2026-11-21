# Skill points (meta-progression) — design

_2026-11-21. Status: draft for approval._

## Why
Every run starts from zero, while battle 5 can be your previous winning team. Players
should feel each run makes the next one a little stronger, including players who lose.

## Goals / non-goals
- Goals: points from every battle won; a Skills screen on the main menu; moderate,
  permanent bonuses to economy, lab odds and combat; free respec.
- Non-goals: unlock gates or prerequisites (see `design/ideas/skill-tree-branching.md`),
  new mutations, real-money anything.
- Anti-goals: bonuses so large that a maxed profile trivialises the run; odds shown on the
  bet screen that ignore the bonuses (they must include them, so the bet math stays honest).

## Approaches
- **A. Ranked list in 3 columns (picked).** About 10 skills with ranks; any skill is buyable at any
  time; rank n costs n points. One screen + one row scene; all numbers in `tuning.gd`.
- B. Branching tree with prerequisites. More "tree" feel, more layout work, and players can
  get stuck behind locks. Saved for later in `design/ideas/skill-tree-branching.md`.
- (Dropped) Random perk picks per run: adds luck to what is meant to be a reliable reward.

## Earning points
- +1 point for each battle won (`SKILL_POINTS_PER_WIN = 1`).
- +2 bonus for winning the run (`SKILL_POINTS_RUN_WIN = 2`). Full win = 7 points.
- Awarded in `Game.complete_battle`. `run_end` shows "+N skill points".

## Skills (starting numbers, all in `tuning.gd`)
| Column | Skill | Per rank | Ranks |
|---|---|---|---|
| Economy | Seed Money | +5 starting gold | 4 |
| Economy | Bounty | +3 gold per battle won | 3 |
| Economy | Stockpile | +1 starting stabilizer | 2 |
| Lab | Common Graft | +4% success on common grafts | 3 |
| Lab | Uncommon Graft | +4% success on uncommon grafts | 3 |
| Lab | Rare Graft | +3% success on rare grafts (ULTRA not affected) | 3 |
| Lab | Steady Splice | +3% Incubator fusion success | 3 |
| Combat | Thick Hide | +4% HP for your monsters | 3 |
| Combat | Sharp Claws | +4% ATK for your monsters | 3 |
| Combat | Adrenaline | +3% attack speed for your monsters | 3 |

Rank n costs n points. Maxing everything costs 60 points (about 9 full wins), so most
players get a few ranks deep over a session. Max combat bonus: +12% HP/ATK, +9% speed.

## How it plugs in
- `SkillStore` (like `CodexStore`): saves points and ranks to `user://skills.json`; has `rank(id)`,
  `buy(id)`, `refund_all()` and `effect(id)`; takes a path argument for tests.
- `Game.new_run()`: adds starting gold and stabilizers. Bounty is added in `complete_battle`.
- `LabLogic.chance_breakdown` and the fusion breakdown get a **"Skills"** row, so the bonus shows on screen.
- `BattleSim` receives player stat multipliers (injected, not read from the store), and so do the
  bet-odds simulations. Enemies and the saved champion team are never buffed.
- Main menu: a SKILLS button next to CODEX/POTENTIAL → `Game.go_to(&"skills")`. The new
  `src/screens/skills.tscn` is laid out in the editor, with three columns of `skill_row.tscn` instances.

## Left to the builder
- Button art for SKILLS in the same style as the other menu buttons.
- Screen look and juice (a pixelfx pop on buying).
- A balance-sim run with a maxed profile to check the bonuses stay moderate.

## Champion growth (added 2026-11-21, user: "a little bit harder, not impossible")
- `ChampionStore` counts total run wins. The champion's HP/ATK get ×(1 + 5% × (wins − 1)),
  capped at +30% (`CHAMPION_GROWTH_PER_WIN`, `CHAMPION_GROWTH_MAX`), applied after the usual 0.9–1.3× normalization.
- This roughly matches the max skill bonus (+12% HP/ATK, +9% speed, plus gold and lab bonuses), so
  the boss keeps pace with you without outscaling you. The bet/formation labels show the bonus, e.g. "(+15% after 4 wins)".
