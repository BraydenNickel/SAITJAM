# Mutation expansion: shared contract (100 mutations, ULTRA tier, VFX, SFX)

All agents on this pass follow this file. Do not change names defined here; if something
cannot work, report it instead of renaming.

Godot: `"C:/Godot/Godot_v4.7.2-stable_win64_console.exe"` (not on PATH). After adding a
`class_name` script or asset run `... --headless --path . --import`.
Tests: `... --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode`
Python: stdlib only (no PIL). User rule: visuals are real nodes / PNG / .tres files, no `_draw()`.

## 1. Data model

`MutationData.Rarity { COMMON, UNCOMMON, RARE, ULTRA }` (ULTRA = 3).
New `MutationData` exports (group "Body override", used by ULTRA mutations only):

| field | type | default | meaning |
|---|---|---|---|
| `body_front` | Texture2D | null | replaces the 64x64 torso sprite in the front view |
| `body_side` | Texture2D | null | same for the side view |
| `body_tint` | Color | white | modulate on the body sprite (parts keep their own colour) |
| `body_scale` | float | 1.0 | scale of the whole MonsterView |
| `aura_fx` | String (json path) | "" | looping pixelfx played behind the monster |

If several installed mutations override the body, the first in `MonsterData.SLOTS` order wins.

Every rarity-indexed array in `Tuning` gets a 4th entry (starting values, balance may move them):
`BUDGET_COST [1,2,3,5]`, `PRICE_BY_RARITY [10,18,30,60]`, `RARITY_WEIGHTS [60,30,10,2]`,
`INSTABILITY_PER_RARITY [10,15,25,35]`, `RISK_PER_RARITY [0,10,20,35]`.
New: `ULTRA_ENEMY_MIN_BATTLE = 3` (enemies never get ULTRA before battle index 3),
`RARE_WEIGHT_PER_BATTLE` stays rare-only. Rarity name "Ultra", colour hot magenta `#ff3df0`.

## 2. Ability catalog

Script path = `res://src/data/abilities/<file>.gd`. `get_id()` returns the id. All are
stateless (state in `UnitState.state[state_key(ctx)]`), deterministic (`ctx.rng` only), and
emit `ctx.notify(&"ability", {&"unit": me.index, &"ability_id": get_id()})` when they visibly
trigger (guarded by `ctx.emit_events`). "basic" = `not hit.from_hook`.

Existing (unchanged; read the script for exact param names):
`AbVenom` venom, `AbDodge` dodge, `AbDoubleStrike` double_strike, `AbLifesteal` lifesteal,
`AbReflect` reflect, `AbSporePulse` spore_pulse.

New:

| class / file | id | exported params (defaults) | behaviour |
|---|---|---|---|
| `AbRegen` ab_regen | regen | `interval` 3.0, `amount` 6.0 | tick: heal self |
| `AbMend` ab_mend | mend | `interval` 5.0, `amount` 10.0 | tick: heal the living ally (or self) with the lowest hp fraction |
| `AbThorns` ab_thorns | thorns | `damage` 2.0 | when hit by a basic attack: flat damage to the attacker, ignores DEF |
| `AbShield` ab_shield | shield | `amount` 40.0 | battle start: a shield that absorbs that much damage first |
| `AbExecute` ab_execute | execute | `threshold` 0.25, `bonus` 8.0 | own basic hit on a target under threshold hp fraction: bonus damage, ignores DEF |
| `AbCleave` ab_cleave | cleave | `fraction` 0.4 | own basic hit: fraction of the hit to every other enemy in the target's row |
| `AbStun` ab_stun | stun | `chance` 0.15, `delay` 0.8 | own basic hit: chance to push the target's attack_timer back by delay (not below -delay) |
| `AbRage` ab_rage | rage | `atk_per_stack` 1.0, `max_stacks` 6 | each basic hit taken: +atk, capped |
| `AbBerserk` ab_berserk | berserk | `threshold` 0.5, `interval_mult` 0.7 | once, when own hp fraction drops below threshold: attack_interval *= mult (floor MIN_INTERVAL) |
| `AbWarCry` ab_war_cry | war_cry | `atk_bonus` 1.0, `def_bonus` 0.0, `hp_bonus` 0.0 | battle start: every ally (not self) gains these |
| `AbVengeance` ab_vengeance | vengeance | `atk_bonus` 2.0, `heal` 20.0 | ally death: gain atk, heal self |
| `AbSnipe` ab_snipe | snipe | `interval` 4.0, `damage` 6.0 | tick: damage the enemy with the lowest hp anywhere, ignores DEF |
| `AbChill` ab_chill | chill | `slow_per_hit` 0.05, `max_slow` 0.4 | own basic hit: target attack_interval += slow, capped per target |
| `AbCorrode` ab_corrode | corrode | `def_per_hit` 1.0, `max_total` 4.0 | own basic hit: target defense -= n, capped per target |
| `AbSecondWind` ab_second_wind | second_wind | `heal_fraction` 0.3 | once: a lethal hit is cancelled and self is healed to that fraction of max hp |
| `AbAmbush` ab_ambush | ambush | `damage` 12.0 | battle start: damage a random enemy, ignores DEF |
| `AbChain` ab_chain | chain | `chance` 0.3, `damage` 5.0 | own basic hit: chance to zap one other random enemy, ignores DEF |
| `AbMomentum` ab_momentum | momentum | `crit_per_hit` 0.03, `max_crit` 0.3 | own basic hit: +crit, capped |
| `AbBurn` ab_burn | burn | `fraction` 0.01, `duration` 4.0 | own basic hit: target burns for fraction of ITS max hp per second for duration (refreshes, no stacking, min 1) |
| `AbTitan` ab_titan | titan | `damage_reduction` 0.2, `stomp_interval` 5.0, `stomp_damage` 6.0 | ULTRA: all damage taken x(1-reduction); tick: stomp all enemies in the front-most enemy row |
| `AbPhase` ab_phase | phase | `chance` 0.25, `counter` 6.0 | ULTRA: chance to cancel ANY hit (not own-id); on a cancel, counter damage to the source |
| `AbSwarm` ab_swarm | swarm | `interval` 2.5, `damage` 3.0, `heal` 2.0 | ULTRA: tick: damage a random enemy and heal self |

Hook damage always uses `ctx.deal_damage(me, target, n, true, get_id(), ignore_def, hit.depth + 1)`
(depth 1 from battle start / tick).

## 3. Mutation table: `tools/mutation_table.py`

Pure data, stdlib, importable: `MUTATIONS = [ {...}, ... ]`, exactly 100 entries, ids unique
snake_case. The 6 existing mutations are included with `"existing": True` and values copied
from their `.tres` (generators skip them). Entry keys:

```python
{"id": "ember_gland", "name": "Ember Gland", "socket": "BACK",      # HEAD TORSO BACK ARM LEG TAIL
 "rarity": 1,                                                        # 0..3
 "desc": "Short flavour.\n+2 ATK.\nHits burn 1% max HP/s for 4s.",  # stats and ability in plain words
 "hp": 0.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
 "tags": ["fire", "gland"],
 "ability": ("AbBurn", {"fraction": 0.01, "duration": 4.0}),         # or None
 "art": {"motif": "sacs", "colors": ["#5a1a0c", "#c8501e", "#ffb040"], "accent": "#fff2a0"},
 "body": None}                                                       # ULTRA only, see below
```

Counts: HEAD 16, TORSO 14, BACK 14, ARM 20, LEG 16, TAIL 12 non-ultra (92) + 8 ULTRA
(2 HEAD, 2 TORSO, 2 BACK, 1 ARM, 1 TAIL). Rarity: about 45 common, 30 uncommon, 17 rare, 8 ultra.

Motifs per socket (art agent implements one drawer per motif per view):
- HEAD: maw, horns, eyes, crest, antennae, beak, skull, tentacles, halo
- TORSO: plates, ribs, core, scales, fur, crystal
- BACK: sacs, wings, spikes, shell, fins, tubes
- ARM: blade, claw, tentacle, pincer, club, cannon
- LEG: raptor, hoof, spider, spring, paw, tread
- TAIL: stinger, whip, club, fan, rattle, flame

ULTRA `"body"`: `{"style": <one of crystal shadow molten slime gold skeletal void angelic>,
"tint": "#rrggbb" (use "#ffffff" when the texture carries the colour), "scale": 1.0-1.35,
"aura": <pixelfx id like "fire/torch" or None>}`. Each of the 8 ultras uses a different style.

## 4. File naming

- Parts: `assets/sprites/parts/<id>_front.png`, `<id>_side.png` (32x32, centred on socket, ARM/LEG drawn as LEFT).
- Ultra bodies: `assets/sprites/torso/body_<id>_front.png`, `body_<id>_side.png` (64x64, same pose and
  socket positions as `human_front/side.png`).
- Mutations: `src/data/mutations/<id>.tres` written by `tools/gen_mutations.py` from the table.
- FX sheets: `assets/fx/<name>.png` + `.json`. SFX: `assets/sfx/<name>.wav`.
- `src/data/fx_library.gd` (`class_name FxLibrary`): the single lookup for effects and sounds, see §5.

## 5. FX / SFX lookup (`FxLibrary`, static, no autoload)

```gdscript
const ABILITY_FX: Dictionary   # ability id (StringName) -> "res://assets/fx/x.json"  (every id in §2)
const EVENT_FX: Dictionary     # &"hit", &"crit", &"death", &"heal", &"dodge", &"frenzy",
                               # &"win_small", &"win_medium", &"win_big", &"coin", &"purchase",
                               # &"mutate_success", &"mush", &"ultra_reveal"
const AURA_FX: Dictionary      # ultra body style (StringName) -> looping json
const SFX: Dictionary          # same event keys + &"attack", &"click", &"ability", &"lose" -> "res://assets/sfx/x.wav"
static func ability_fx(id: StringName) -> String   # "" if none
static func event_fx(key: StringName) -> String
static func sfx(key: StringName) -> AudioStream     # cached load, null if missing
```
