class_name Tuning
extends RefCounted
## Global rules and tunable numbers for Mutant Lab. Per-mutation numbers live in
## each mutation .tres; everything global lives here so balancing is one file.

# --- Base human stats ---
const BASE_HP: float = 360.0
const BASE_ATK: float = 6.0
const BASE_INTERVAL: float = 1.6
const BASE_DEF: float = 0.0
const BASE_CRIT: float = 0.05
## Attack interval can never drop below this (seconds).
const MIN_INTERVAL: float = 0.3

# --- Run structure ---
const START_GOLD: int = 45
const START_HUMANS: int = 2
const BATTLES_PER_RUN: int = 5
const MAX_TEAM: int = 4
const FORMATION_ROWS: int = 3
const FORMATION_COLS: int = 2
const BATTLE_REWARD: Array[int] = [20, 25, 25, 25, 0]

# --- Enemy generation (indexed by battle) ---
const ENEMY_BUDGET: Array[int] = [2, 3, 4, 6, 7]
const ENEMY_TEAM_SIZE: Array[int] = [2, 2, 3, 3, 4]
## Enemy base-body HP multiplier per battle (scales BASE_HP only, not mutation hp_mod).
const ENEMY_HP_MULT: Array[float] = [0.9, 0.9, 0.76, 0.8, 0.68]

# --- Adaptive enemy scaling (design/balance/stage3-tuning.md §6) ---
# Player power = sum of BUDGET_COST of every mutation on living monsters, plus
# ADAPT_BODY_POWER per living monster beyond START_HUMANS. Extra enemy budget =
# clamp(round(ADAPT_RATE * (power - ADAPT_EXPECTED[i])), 0, ADAPT_MAX[i]).
# Shown to the player on the bet screen; only ever makes enemies harder.
## Power a typical (greedy-sim) player has at each battle; at or below it there is no bonus.
const ADAPT_EXPECTED: Array[int] = [7, 9, 10, 12, 14]
## Extra enemy budget per point of power above ADAPT_EXPECTED.
const ADAPT_RATE: float = 2.0
## Cap on the extra enemy budget per battle.
const ADAPT_MAX: Array[int] = [1, 2, 2, 3, 3]
## Power counted for each living monster beyond START_HUMANS (a body is worth
## about three commons; design/balance/stage4-balance.md, Pass 2).
const ADAPT_BODY_POWER: int = 3
## Extra enemy base HP per adaptive budget point that could not be spent (sockets full).
const ADAPT_HP_PER_POINT: float = 0.1

## Budget cost by rarity (COMMON, UNCOMMON, RARE, ULTRA).
const BUDGET_COST: Array[int] = [1, 2, 3, 5]
const BUDGET_COST_FUSION: int = 3

# --- Shop ---
## Shop price by rarity (COMMON, UNCOMMON, RARE, ULTRA).
const PRICE_BY_RARITY: Array[int] = [10, 18, 30, 45]
const PRICE_HUMAN: int = 35
const PRICE_STABILIZER: int = 10
const REROLL_BASE: int = 5
const REROLL_STEP: int = 3
## Shop roll weight by rarity (COMMON, UNCOMMON, RARE, ULTRA).
## ULTRA is 8 of 108 (about 7.4% per slot, roughly +5 points over the old weight 2).
const RARITY_WEIGHTS: Array[int] = [60, 30, 10, 8]
## Added to the RARE weight only, per battle index (ULTRA never grows).
const RARE_WEIGHT_PER_BATTLE: int = 5

# --- Instability / risk ---
## Indexed by rarity (COMMON, UNCOMMON, RARE, ULTRA).
const INSTABILITY_PER_RARITY: Array[int] = [10, 15, 25, 35]
const RISK_PER_RARITY: Array[int] = [0, 10, 20, 35]
const STABILIZER_BONUS: int = 25
const STABILIZER_MAX: int = 2
const PURGE_COST: int = 10
const PURGE_INSTABILITY: int = 15

# --- Fusion ---
const FUSION_COST: int = 30
const FUSION_BASE_CHANCE: int = 90
const FUSION_STAT_MULT: float = 0.6
const FUSION_BOOST: float = 1.25
const FUSION_START_INSTABILITY: int = 50
## Fused-part stat multiplier indexed by merge_count (design/fusion-contract.md §1).
const FUSION_PART_STAT_MULT: Array[float] = [1.0, 0.65, 0.6]
## Stat multiplier of a signature fusion (replaces FUSION_PART_STAT_MULT[1]).
const FUSION_SIGNATURE_STAT_MULT: float = 1.0
## AbilityData.empowered() multiplier of a Twin fusion's single ability.
const FUSION_TWIN_POWER: float = 1.5
## Most abilities one fused mutation may carry.
const FUSION_MAX_ABILITIES: int = 2
## Highest merge_count a mutation can reach (0 base, 1 hybrid/twin, 2 apex).
const FUSION_MAX_MERGES: int = 2
## Mutations each parent needs before it may enter the Incubator.
const FUSION_MIN_MUTATIONS: int = 2
## Clamp of the Incubator success chance (percent).
const FUSION_MIN_CHANCE: int = 10
const FUSION_MAX_CHANCE: int = 95
## Caps applied by AbilityData.empowered(): chances, damage reductions, fractions.
const EMPOWER_MAX_CHANCE: float = 0.95
const EMPOWER_MAX_REDUCTION: float = 0.6
const EMPOWER_MAX_FRACTION: float = 1.0

# --- Mush (failed mutation) ---
const MUSH_REFUND: float = 0.4
const MUSH_MEMORY_BONUS: int = 15

# --- Betting ---
const BET_EDGE: float = 0.9
const BET_MIN: int = 5
const BET_MAX_MULT: float = 10.0
const BET_MIN_MULT: float = 1.1
const BET_STAKE_CAP: float = 0.5
const BET_MAX_CLAIMS: int = 2

# --- Sponsor ---
const SPONSOR_THRESHOLD: int = 15
const SPONSOR_GRANT: int = 15

# --- Battle pacing ---
const FRENZY_START: float = 30.0
const FRENZY_RAMP: float = 0.10
const HARD_CAP: float = 60.0

# --- Simulation ---
const SIM_RUNS: int = 100

# --- Battle simulation (stage 2) ---
## Fixed step used by BattleSim.run_to_end() when events are emitted (visual replays).
const SIM_STEP: float = 1.0 / 30.0
## Max step for headless odds sims (emit_events = false): they jump from attack to
## attack, never further than this, so tick abilities (spores, venom) stay accurate.
const SIM_STEP_HEADLESS: float = 0.25
## Each unit's attack timer starts at a random value in [0, this] seconds.
const ATTACK_START_JITTER: float = 0.3
## Damage multiplier on a critical hit.
const CRIT_MULT: float = 2.0
## Hook-generated damage at depth > this triggers no further hooks (loop guard).
const HOOK_MAX_DEPTH: int = 1
## Blitz claim: win in under this many seconds.
const BLITZ_TIME: float = 30.0

# --- Enemy generation archetypes ---
## Chance an enemy follows a coherent archetype instead of random mutations.
const ENEMY_ARCHETYPE_CHANCE: float = 0.7
## Archetype name -> preferred mutation tags (matched against MutationData.tags;
## a mutation is preferred if it carries at least one of them).
const ENEMY_ARCHETYPES: Dictionary = {
	&"venom": [&"venom", &"insect", &"parasite"],
	&"tank": [&"armor", &"bone", &"crystal"],
	&"spore": [&"spore", &"fungus"],
	&"fire": [&"fire"],
	&"frost": [&"frost", &"aquatic"],
	&"brute": [&"brute", &"beast"],
	&"swift": [&"swift", &"speed", &"shadow"],
	&"support": [&"support"],
	&"storm": [&"electric"],
}
## Enemies never receive ULTRA mutations before this battle index.
const ULTRA_ENEMY_MIN_BATTLE: int = 3
## Name of the battle-5 boss used until a champion is saved (stage 4).
const BOSS_NAME: String = "Dr. Splice"

# --- Champion boss (stage 4; handoff.md §2 "Champion") ---
## Boss name shown when battle 5 is the team that won the player's last run.
const CHAMPION_NAME: String = "Your Last Champion"
## Prefix added to each champion unit's name so the player sees it is their old team.
const CHAMPION_UNIT_PREFIX: String = "Champ "
## Champion power (sum of EnemyGen.cost_of over its mutations) is normalized into
## [CHAMPION_NORM_MIN, CHAMPION_NORM_MAX] x ENEMY_BUDGET[last battle] by scaling
## every unit's total HP and ATK by the same factor. Inside the band: unchanged.
const CHAMPION_NORM_MIN: float = 0.9
const CHAMPION_NORM_MAX: float = 1.3
## Safety clamp on that HP/ATK factor (a champion with almost no mutations would
## otherwise be multiplied many times over). Outside it the band is not reached.
const CHAMPION_SCALE_MIN: float = 0.1
const CHAMPION_SCALE_MAX: float = 3.0
## Champion growth: after the first saved champion, each further run the player
## wins makes the champion this much stronger (HP and ATK, applied after the
## normalization clamp), up to CHAMPION_GROWTH_MAX. See EnemyGen.champion_growth().
const CHAMPION_GROWTH_PER_WIN: float = 0.05
const CHAMPION_GROWTH_MAX: float = 0.30

# --- Battle presentation (stage 2) ---
const BATTLE_INTRO_TIME: float = 1.0
## Seconds for units and placement zones to fade in when the arena lights come on.
const ARENA_UNIT_FADE_TIME: float = 0.5
## Playback speeds cycled by the battle speed button (applied as Engine.time_scale).
const BATTLE_SPEEDS: Array[float] = [1.0, 2.0, 4.0]
## Pause between the last hit and the result panel (real seconds).
const BATTLE_END_DELAY: float = 0.9
const LUNGE_DISTANCE: float = 14.0
const LUNGE_TIME: float = 0.12
const FLASH_TIME: float = 0.12
const DEATH_TIME: float = 0.5
const NUMBER_RISE: float = 22.0
const NUMBER_TIME: float = 0.8
## Net-gold thresholds for celebration tiers (small, medium, big).
const CELEBRATE_NET: Array[int] = [1, 25, 60]
## Coin particle count per celebration tier.
const CELEBRATE_PARTICLES: Array[int] = [8, 24, 60]
## Default stake shown on a bet row when first toggled.
const BET_DEFAULT_STAKE: int = 10

# --- Stage 3 ---
## Mutation slots in the shop (plus 1 human and 1 stabilizer).
const SHOP_MUTATION_SLOTS: int = 3
## Shop visits without a rare before a rare is forced.
const SHOP_RARE_PITY: int = 3
## Max living (non-mush) monsters in the roster.
const ROSTER_MAX: int = 4
## Post-battle reward options offered.
const REWARD_CHOICES: int = 3
const REWARD_GOLD: int = 25
const REWARD_STABILIZERS: int = 2
## Instability removed from the most unstable monster by the Cleanse reward.
const CLEANSE_AMOUNT: int = 30
## Success % added by the Lucky Gene reward to the next operation.
const LUCKY_GENE_BONUS: int = 20
## Lab operation success % bounds.
const MIN_SUCCESS: int = 5
const MAX_SUCCESS: int = 100
## Lab operations and Incubator fusions always succeed while run.battle_index < this.
const SAFE_LAB_BATTLES: int = 1

# --- Juice (stage 5) ---
## Volume of every SfxPlayer voice, in dB.
const SFX_VOLUME_DB: float = -6.0
## Minimum real seconds between two plays of the same sound key (stops
## machine-gunning and clipping at 4x battle speed).
const SFX_MIN_INTERVAL: float = 0.05
## Random pitch spread (+/- fraction) on repeated battle sounds.
const SFX_PITCH_JITTER: float = 0.08
## Most pixelfx effects alive at once in a battle; more are skipped.
const FX_MAX_ALIVE: int = 40
## Abilities that deal damage over time: their effect is small and rare.
const FX_TICK_ABILITIES: Array[StringName] = [&"venom", &"burn"]
## Minimum real seconds between two tick-ability effects on one unit.
const FX_TICK_INTERVAL: float = 1.0
## Scale of a tick-ability effect.
const FX_TICK_SCALE: float = 0.5
## Minimum real seconds between repeats of any other ability / heal effect on one unit.
const FX_REPEAT_INTERVAL: float = 0.3
## Sheets whose pivot sits at or below this fraction of the frame height stand
## on the ground: they anchor at a unit's feet instead of its centre.
const FX_GROUND_PIVOT_RATIO: float = 0.7
## Screen shake peak offset in px for a critical hit and for a death.
const SHAKE_CRIT_AMPLITUDE: float = 3.0
const SHAKE_DEATH_AMPLITUDE: float = 5.0
## Screen shake length in real seconds (linear decay to zero).
const SHAKE_DURATION: float = 0.18
## Largest size, in MonsterView pixels (the body is 64x64), an ultra aura frame
## may cover. Bigger sheets are scaled down to fit, so the aura reads as a glow
## around the body instead of swallowing its neighbours.
const AURA_MAX_SIZE: Vector2 = Vector2(120.0, 120.0)
## Apex part outline (assets/shaders/apex_glow.gdshader, set by MonsterView):
## colour, pulse speed (radians per second) and the alpha at the dimmest point.
const APEX_GLOW_COLOR: Color = Color(1.0, 0.82, 0.25, 1.0)
const APEX_GLOW_PULSE_SPEED: float = 3.0
const APEX_GLOW_MIN: float = 0.35

# --- Run summary ---
## Most "New this run" Codex names listed on the run-end screen; the rest are
## counted as "+N more".
const RUN_SUMMARY_MAX_NEW: int = 6

# --- Hints ---
## First-time hint banners (HintBanner / HintStore, user://hints.cfg).
## false: a banner keeps showing on each visit until the player presses "Got it".
## true: it is marked seen the first time it shows, even if never dismissed.
const HINT_MARK_SEEN_ON_SHOW: bool = false

# --- Skills (meta-progression; docs/superpowers/specs/2026-11-21-skill-points-design.md) ---
## Permanent skill points awarded for each battle won.
const SKILL_POINTS_PER_WIN: int = 1
## Extra skill points for winning the final battle of a run.
const SKILL_POINTS_RUN_WIN: int = 2
## A skill's next rank costs (current_rank + 1) * this.
const SKILL_COST_PER_RANK: int = 1
## Skills screen column headers; SKILLS[i][&"column"] indexes this.
const SKILL_COLUMNS: Array[String] = ["ECONOMY", "LAB", "COMBAT"]
## Every skill, in display order. `desc` takes one %d: the total value (rank x per_rank).
const SKILLS: Array[Dictionary] = [
	{&"id": &"seed_money", &"name": "Seed Money", &"column": 0, &"per_rank": 5, &"max_rank": 4,
		&"desc": "+%d starting gold"},
	{&"id": &"bounty", &"name": "Bounty", &"column": 0, &"per_rank": 3, &"max_rank": 3,
		&"desc": "+%d gold per battle won"},
	{&"id": &"stockpile", &"name": "Stockpile", &"column": 0, &"per_rank": 1, &"max_rank": 2,
		&"desc": "+%d starting stabilizers"},
	{&"id": &"common_graft", &"name": "Common Graft", &"column": 1, &"per_rank": 4, &"max_rank": 3,
		&"desc": "+%d%% common graft success"},
	{&"id": &"uncommon_graft", &"name": "Uncommon Graft", &"column": 1, &"per_rank": 4, &"max_rank": 3,
		&"desc": "+%d%% uncommon graft success"},
	{&"id": &"rare_graft", &"name": "Rare Graft", &"column": 1, &"per_rank": 3, &"max_rank": 3,
		&"desc": "+%d%% rare graft success"},
	{&"id": &"steady_splice", &"name": "Steady Splice", &"column": 1, &"per_rank": 3, &"max_rank": 3,
		&"desc": "+%d%% fusion success"},
	{&"id": &"thick_hide", &"name": "Thick Hide", &"column": 2, &"per_rank": 4, &"max_rank": 3,
		&"desc": "+%d%% monster HP"},
	{&"id": &"sharp_claws", &"name": "Sharp Claws", &"column": 2, &"per_rank": 4, &"max_rank": 3,
		&"desc": "+%d%% monster ATK"},
	{&"id": &"adrenaline", &"name": "Adrenaline", &"column": 2, &"per_rank": 3, &"max_rank": 3,
		&"desc": "+%d%% attack speed"},
]
