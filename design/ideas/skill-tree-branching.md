# Idea (parked): branching skill tree

_Parked 2026-11-21. We built option A (ranked list, any skill buyable any time). This is option B, to revisit later._

## Concept
The same skills as the ranked list, but each column is a path with locks:

```
 ECONOMY              LAB                     COMBAT
 Seed Money 1-2       Common Graft 1-3        Thick Hide 1-3
     |                     |                       |
 Bounty 1-3          Uncommon Graft 1-3      Sharp Claws 1-3
     |                     |                       |
 Stockpile 1-2        Rare Graft 1-3          Adrenaline 1-3
     |                     |                       |
 [Capstone]           [Capstone]              [Capstone]
```

To unlock a node, its parent needs at least 2 ranks. Each column ends in a **capstone** that
changes how you play, not just your numbers. Capstone ideas:
- Economy, **Investor:** carry 10% of leftover gold into the next run.
- Lab, **Mush Recycler:** a failed graft refunds 70% instead of 40%.
- Combat, **First Strike:** your front row attacks once at the start of every battle.

## Trade-offs vs the ranked list
- Plus: it looks and feels like a tree, gives longer-term goals, and capstones add build identity.
- Minus: more layout work (lines and lock states in the scene), and points can feel wasted
  when the skill you want is locked. That hurts the players who lose most, the ones the
  feature is meant to help.

## Migration path from option A
The saved data stays the same (`ranks` per skill id). Adding locks means one `requires`
field per skill in the tuning table, a lock check in `SkillStore.buy`, and connector lines in
`skills.tscn`. Ranks players already own stay valid.
