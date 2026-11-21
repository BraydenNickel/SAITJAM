# JAM MODE: 6-hour Godot 2D game jam

This project is a 6-hour game jam entry. **Godot 4.6, GDScript, 2D pixel art.**
The theme is announced at the start. The design plan in `design/jam-plan.md` is
built to adapt to any theme.
These rules take priority over the slower studio defaults while the jam runs.

## Speed rules (jam overrides)

- **Batch approval:** for each feature, show a plan of at most 3 lines and the list
  of files you will touch. After one "go", write them all without asking file by file.
  Still ask before: deleting files, git commits, anything outside this folder,
  and changing `project.godot` settings.
- **Rigor is minimal.** No GDDs, ADRs, stories or director gates unless the user asks.
  A design note in `design/jam-plan.md` is enough.
- **Playable at every hour.** Never leave the game broken at the end of a step. Run it
  through the Godot MCP (`run_project` and then `get_debug_output`) after every feature
  and fix the errors before moving on.
- **Cut, don't slip.** If a feature is not working after 20 minutes, propose cutting or
  simplifying it.
- **Data in one place.** Put every tunable number (odds, payouts, targets, timers) in
  `src/data/tuning.gd` as consts or a Resource, so balancing is one file.

## Engine and tools

- Code lives in `src/`, scenes next to their scripts, art and sound in `assets/`.
- Static typing in GDScript. Use signals rather than reaching across nodes.
- **Godot MCP** (`.mcp.json`, server `godot`, Coding-Solo/godot-mcp): launch the
  editor, run the project, read debug output, create scenes, add nodes and load
  sprites. Use it to *verify* every change. Edit `.gd` and `.tscn` files directly
  when that is faster.
- **godot-ai** (`addons/godot_ai`, v3.2.5, server `godot-ai`): live control of the **open
  editor**: scene tree, nodes, properties, signals, UI, animation, particles,
  cameras, and hot-reloaded scripts. Use it for scene building and tweaking while the editor is open.
  Use `godot` (Coding-Solo) to run the game headlessly and read debug output. Keep v3.2.5: v4 needs Godot 4.7.
- **pixelfx** (`tools/pixelfx`, skill `pixelfx`): 244 pixel effects.
  To export an effect: `node tools/pixelfx/tools/render.mjs <category>/<name> --sheet`, then copy the
  `.png` and `.json` from `tools/pixelfx/records/<category>/<name>/` into `assets/fx/` and play it with
  `PixelFxPlayer.spawn(self, "res://assets/fx/<name>.json", pos)`.
  Use `palette` to recolour effects to match the game. Use pixelfx for
  all juice: wins, near-wins, payouts, coins, transitions and UI pops.

## Which helpers to use

| Need | Use |
|---|---|
| Turn the theme into a design | `chance-mechanic-designer` skill + `game-designer` / `systems-designer` agents |
| Odds, payouts, economy, balance | `economy-designer` agent + a Python odds simulation |
| GDScript and scenes | `godot-gdscript-specialist`, `godot-specialist`, `gameplay-programmer` |
| Fast throwaway tests | `prototyper` |
| Shaders and screen effects | `godot-shader-specialist`, `technical-artist` |
| Effects, sprite sheets, game juice | `pixelfx` skill |
| HUD, odds display, readability | `ux-designer`, `ui-programmer` |
| Is it fun, and is it fair? | `retention-loop-audit` skill, `qa-tester` |
| Check for loot box or gambling issues before release | `game-chance-compliance-check` skill |
| Cut list near the end | `/scope-check`, `/cut` |

## Design guardrails for the chance mechanics

- The player gets the thrill of gambling **with agency**: they can see and change the
  odds. Wins come from smart builds, not only from luck.
- No real money. No fake near-misses: a near-miss only shows when a different choice
  would have won. Win celebrations scale with the actual net result.
- Avoid literal casino visuals (cards, chips, slot cabinets) unless the theme needs
  them. Re-skin the machine to fit the theme.
