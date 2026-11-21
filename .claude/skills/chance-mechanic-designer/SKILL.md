---
name: "chance-mechanic-designer"
description: "Design a chance-based game feature (luck engine, reward reveal, push-your-luck, collection drops) that hooks players through agency instead of paid randomness."
---

# Chance Mechanic Designer

Use this when designing or iterating on any feature built around randomness: slot-like engines, drops, reveals, push-your-luck, gacha-style collection, roguelike runs.

## Step 1 - Pin down the brief
Ask for (or infer and state) the following:
- Host game and genre, platform, target age rating, regions shipped.
- Business model: premium, F2P cosmetics, battle pass, ads.
- Session target (minutes) and return target (daily, weekly, seasonal).

## Step 2 - Choose the levers
Build from these well-evidenced levers, and say which ones each part of the design uses:
1. **Variable-ratio reward timing**: unpredictable payoff is the engine.
2. **Rarity ladder + reveal**: rarer outcomes produce more arousal and more anticipation before the reveal. Invest in the reveal animation and sound.
3. **Agency over odds**: players change the probabilities themselves through drafted symbols, modifiers or synergies (Balatro jokers, CloverPit charms, Luck be a Landlord symbols). This is the honest version of the illusion of control.
4. **Escalation**: exponential targets and big numbers.
5. **Push-your-luck banking**: repeated cash-out-or-risk decisions.
6. **Earned stakes**: loss aversion on items the player earned (extraction-style), never on purchased items.
7. **Visible guarantees**: pity as an open progress bar on earned rewards.
8. **Social layer**: seeded shared challenges, duels, spectating, shareable replays.
9. **Natural endings**: runs end clearly. Use rested bonuses instead of streak punishment.

## Step 3 - Apply the red lines (non-negotiable)
Reject or redesign anything that does the following:
- Sells random outcomes for money, or for currency bought with money (PEGI 16+, illegal in Belgium, banned for minors in Brazil).
- Lets random rewards be traded or cashed out for real value (NY v. Valve).
- Fakes near-misses. A near-miss is only allowed when a different player choice would really have won.
- Celebrates net losses (losses disguised as wins). Feedback must scale with the real net outcome.
- Hides or misstates odds.
- Uses purchase-flow dark patterns (FTC v. Epic, $245M).
- Punishes missed days, or aims hard FOMO at minors.

Also flag literal casino imagery (cards, chips, slot cabinets) as a ratings risk. Balatro was briefly rated PEGI 18. Suggest re-theming.

## Step 4 - Output format
Produce:
1. **One-line pitch.**
2. **Core loop** (run level) and **meta loop** (weeks to months) as numbered steps.
3. **Lever map**: table of feature element → lever → why it works.
4. **Odds sheet**: base probabilities, how modifiers change them, expected run length, how often the player wins.
5. **Monetisation**, compliant with the red lines.
6. **Risk check**: run the `game-chance-compliance-check` skill if available, or list rating and regional implications.
7. **Playtest plan**: metrics (session length distribution, D1/D7/D30, % of runs where player choice changed the result) and qualitative signals ("fun" versus "couldn't stop").

## Step 5 - Prototype support
If asked, write a simple simulation (Python) of the odds model. Run 10k simulated runs and report the distribution of score, run length and win rate, so the tuning is grounded in numbers.