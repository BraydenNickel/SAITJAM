# Jam plan: a chance-mechanic game that fits any theme

Source research: "Chance Mechanics That Keep Players Coming Back" (doc). Key lesson:
the hits (Balatro, Luck be a Landlord, CloverPit) hook players through **agency over
odds + escalating targets + short runs with clear endings**, not paid randomness.

## Step 0 (first 20 min): theme → pick a hook → one-page brief

Ask Claude: *"Theme is X. Use chance-mechanic-designer and jam-plan.md to give me 3
one-line pitches, then write the brief for the one I pick."*

## Pick one of these core hooks

### A. Bet on Yourself (the fresh one: skill × wager)
Before each short action challenge (a 20–40 s room, wave, jump sequence or dodge), the
player **stakes chips on how well they will do** (e.g. "no hits", "under 15 s", "collect
all"). Bigger claims pay more. They then play the challenge with real skill.
Between rooms they buy **charms** that change the odds or payouts ("+1 heart on
risky bets", "double pay on no-hit claims", "one free reroll of a failed claim").
- Why it's new: chance games rarely let you bet on your *own* performance. It
  turns skill into odds the player sets themselves, so it feels earned.
- Gambling lever: push-your-luck, variable reward, escalation. Agency: total.
- Scope: one small action mechanic + a bet screen + 8–12 charms.

### B. Build the Machine (luck engine)
A 3×3 or 3×5 grid of symbols "spins" each turn. The player drafts symbols that
interact by adjacency, plus modifiers that **visibly change odds**. Scores must hit rising
targets (rent, debt, the theme's pressure). Odds bars are always shown.
- Proven formula; the twist comes from the theme (symbols = the theme's objects).
- Scope: grid + 20–30 symbols + 8 modifiers + target curve. Easiest to finish.

### C. Hot Hand (push-your-luck runner)
Each successful action raises a multiplier and adds risk (faster, more hazards). At any
moment you can **bank** your winnings. Fail before banking and you lose the unbanked pot.
- Gambling lever: tension of cashing out. Works with almost any action game.

**Combine if time allows:** A + C fits best (bet on yourself, then bank or push).

## Theme adapter (examples)

| Theme flavour | Re-skin of the machine / bet | Pressure (escalating target) |
|---|---|---|
| Loss / decay / impermanence | Bet memories that fade if you lose | Things vanish each round |
| Growth / evolution | Seeds or genes are the symbols; mutations are modifiers | Ecosystem demand |
| Time / loops | Bet seconds of your own clock | Clock shrinks |
| Space / exploration | Fuel is the stake; planets are reels | Distance to home |
| Monsters / horror | Deal with a demon: wager body parts | Debt to the demon |
| Small world / tiny | Bugs bet crumbs | Winter is coming |
| Connection / together | Two linked machines whose outcomes affect each other | Shared rent |
| "Out of control" | Machine rewires itself each spin; you nudge it | Overload meter |

## Minimum build (must have by hour 4)
1. Core action OR grid spin, readable at 640×360.
2. A stake/bet decision every 30–60 s.
3. Visible odds or claims, plus 8+ modifiers that change them.
4. Escalating target and a clear run end (win or bust screen with the score).
5. Juice: pixelfx on wins, a big-win effect, coin collect, screen shake, sound.

## Nice to have
- Seeded "daily run" with a shareable score string.
- Ghost of your best run.
- Run history with best combos.

## Hour plan (6 h)
| Time | Goal | Helpers |
|---|---|---|
| 0:00–0:20 | Theme → pitch → brief | chance-mechanic-designer, game-designer |
| 0:20–1:30 | Core loop playable with placeholder art | godot-gdscript-specialist, prototyper, Godot MCP |
| 1:30–2:30 | Bets/claims + 8 modifiers + odds UI | systems-designer, ux-designer |
| 2:30–3:15 | Escalation, run end, restart | gameplay-programmer |
| 3:15–4:15 | Art pass + pixelfx juice + sound | pixelfx, technical-artist, sound-designer |
| 4:15–5:00 | Balance with a Python sim of 10k runs + playtest | economy-designer, retention-loop-audit |
| 5:00–5:30 | Bug sweep, title screen, how-to-play | qa-tester, /scope-check |
| 5:30–5:50 | Export (Windows + Web), upload | release notes |
| 5:50–6:00 | Buffer | |

## Balance targets (starting point)
- First run: a new player reaches the 3rd target about 60% of the time and busts by the 6th.
- A good build should beat the target by 2–5× (the "broken combo" moment).
- In at least 30% of runs, a different player choice should have changed the result
  (measure this in the simulation).

---

## CHOSEN DESIGN (2026-11-21): MUTANT LAB, theme "Unnatural Evolution"

Hook A+C (Bet on Yourself), set in a roguelike auto-battler. Humans are mutated into monsters.

- **Run:** start with 2 humans and 40g. Hub (Lab / Shop / Incubator / Roster) → bet → auto-battle → pick 1 of 3 rewards → hub. 5 battles. **One life**: losing a battle ends the run.
- **Champion:** the team that wins battle 5 is saved to `user://` and becomes the next run's battle-5 boss, with stats normalized to 0.9–1.3× of that tier's budget. Runs with no saved champion face "Dr. Splice".
- **Formation:** 6 spots per side: 2 front, 2 middle, 2 back. The player places 1–4 mutants; enemy spots are random. Units attack the front-most row that still has living units.
- **Body (composition):** sockets HEAD, TORSO, BACK, ARM_L, ARM_R, LEG_L, LEG_R, TAIL. Each mutation is a `.tres` Resource (sprites, stat mods, ability with hooks `on_battle_start / on_tick / on_attack / on_hit / on_take_damage / on_ally_death`). Hooks combine through a shared HitInfo, with no glue code. Hook damage goes at most 1 level deep.
- **6 mutations:** Bone Plating (TORSO), Mantis Arm (ARM), Leech Maw (HEAD), Spore Sacs (BACK), Raptor Leg (LEG), Scorpion Tail (TAIL).
- **Lab risk:** instability rises +10/20/30 by rarity. `success% = clamp(100 − instability − rarity_risk + stabilizers, 5, 100)`. On a fail the monster becomes MUSH: retired, 40% refund, and +15% Mush Memory on the next operation.
- **Fusion (Incubator):** two monsters with at least 2 mutations each. Stats = 0.6×(A+B)×1.25. `success% = clamp(90 − avg_instability + stabilizers, 10, 95)`. On a fail both become mush. Fusion titles fill the Codex.
- **Bets:** Victory / Flawless / Blitz / Last Stand / MVP. Odds come from 200 simulations of the real matchup. `mult = clamp(0.9/p, 1.1, 10)`. At most 2 claims, each at most 50% of your gold. A 15g sponsor grant prevents a soft-lock. Celebrations scale with net gold.
- **Shop:** 5 slots (3 mutations, 1 human, 1 stabilizer), with new stock every visit. Reroll costs 5g, +3g for each further reroll. A rare is guaranteed after 3 visits without one.
- All global numbers are in `src/data/tuning.gd`. Per-mutation numbers are in `src/data/mutations/*.tres`.
- **Build stages:** 1 monsters + hub, 2 battle + bets, 3 lab + shop + rewards, 4 fusion + run + champion, 5 pixelfx juice.
