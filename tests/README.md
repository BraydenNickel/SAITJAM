# Test Infrastructure

**Engine**: Godot 4.7.2
**Test Framework**: GdUnit4 6.2.3 (installed in `addons/gdUnit4/`, plugin enabled)
**CI**: none (workflow skipped; no git remote yet)
**Setup date**: 2026-11-21

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
```

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> **Manual evidence lives under `production/qa/evidence/`, not `tests/`** — that
> is where every consumer reads it.

## Installing GdUnit4

```
1. Open Godot -> Asset Store -> search "GdUnit4" -> install it
   (Godot 4.7+ uses the Asset Store)
2. Enable the plugin: Project -> Project Settings -> Plugins -> GdUnit4 (checked)
3. Restart the editor
4. Verify: res://addons/gdUnit4/bin/GdUnitCmdTool.gd exists (capital U)
```

## Running Tests

Run the import first (a fresh clone has no `.godot/` class cache and the run exits 1 without it):

```bash
"C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
```

Then the suite (this is `commands.test` in `project.yaml`):

```bash
"C:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Exit codes: **0** all pass, **100** a test failed, **101** all passed but nodes
leaked (warning), **103/104** gdUnit4 could not run, **105** a test script does
not parse. Two `ERROR:` lines about `127.0.0.1:0` are expected. A run that
prints `No test cases found` exits 0 — that is not a pass.

## Test Naming

- **Godot**: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `payout_odds_test.gd` -> `test_base_spin_returns_expected_payout()`

## Story Type -> Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` |
| UI | Retained screenshot of each screen touched | `production/qa/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Not set up. To add it later, re-run `/test-setup force` once the project has a
GitHub remote; it creates only the missing `.github/workflows/tests.yml`.
