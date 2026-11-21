---
name: "game-chance-compliance-check"
description: "Audit a game feature with random rewards, purchases or return incentives against loot box laws, PEGI/ESRB ratings, FTC dark-pattern rules and app-store odds disclosure."
---

# Game Chance Compliance Check

This is not legal advice. Always tell the user to confirm with counsel before launch. The law changes fast: **search the web for updates** on each jurisdiction below before giving the final verdict, and note the date checked.

## Step 1 - Classify the feature
Answer each question yes or no:
- **Pay?** Can the player spend real money, or currency bought with real money, to get the outcome?
- **Random?** Is the outcome unknown at the time of purchase?
- **Value?** Can the reward be traded, sold or cashed out, inside or outside the game?
- **Return incentive?** Daily quests, login streaks, limited-time offers, battle pass with rewards you lose if you don't keep up?
- **Casino imagery?** Cards, chips, slots, roulette?
- **Minors?** Is the game likely to be played by under-18s?

Pay + Random + Value = high gambling-law risk almost everywhere. Remove any one of the three to cut risk sharply.

## Step 2 - Check against the reference map (as of late 2026; verify each item)
- **PEGI (new submissions since June 2026):** paid random items → 16 by default (sometimes 18), including random items bought with virtual currency purchased for money. Social casino → 18. NFT/blockchain required to play → 18. Time- or quantity-limited offers / paid battle pass → 12. Daily quests and login streaks → 7, or 12 if missing them costs rewards.
- **Belgium:** paid loot boxes with value count as illegal gambling. Fines up to €800k. App stores can also be held liable.
- **Netherlands:** courts ruled the same mechanic is not gambling. The government is pushing for an EU ban.
- **EU:** Digital Fairness Act proposal expected around Q4 2026, possibly banning loot boxes where minors can access them. CPC consumer guidelines on virtual currency pricing.
- **Brazil:** loot box sales to under-18s banned since March 2026.
- **South Korea:** mandatory odds disclosure, with triple damages for mislabelled odds.
- **China:** mandatory probability disclosure.
- **USA:** no loot box statute, but there is case-by-case enforcement: FTC v. Epic ($245M refunds over dark patterns, plus a $275M COPPA penalty); FTC v. Cognosphere/HoYoverse ($20M over loot box odds, under-16 purchases blocked without parental consent); NY AG v. Valve (Feb 2026, tradeable skins).
- **Apple / Google:** odds disclosure required for random paid items.
- **ESRB:** "In-Game Purchases (Includes Random Items)" label.

## Step 3 - Dark pattern scan
Flag the following: one-tap purchases with no confirmation; confusing currency bundles that leave leftover balances; misleading odds or celebration of net losses; faked near-misses; countdown pressure; hard-to-find refunds or spending controls; spending switched on by default for minors.

## Step 4 - Output
A table with columns: Region/Rule | Applies? | Likely outcome (rating, legal status) | Fix.
Then give the **lowest-risk redesign** that keeps the fun. Common fixes: earned-only currency for random rolls; direct-purchase cosmetics; make rewards non-tradeable; visible odds; replace streaks with rested bonuses; re-theme casino imagery.
End with: "Verify with qualified legal counsel in each launch market."