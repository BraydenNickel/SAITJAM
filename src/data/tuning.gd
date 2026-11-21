class_name Tuning
extends RefCounted
## Global rules and tunable numbers for Mutant Lab. Per-mutation numbers live in
## each mutation .tres; everything global lives here so balancing is one file.

# --- Base human stats ---
const BASE_HP: float = 100.0
const BASE_ATK: float = 6.0
const BASE_INTERVAL: float = 1.6
const BASE_DEF: float = 0.0
const BASE_CRIT: float = 0.05
## Attack interval can never drop below this (seconds).
const MIN_INTERVAL: float = 0.3

# --- Run structure ---
const START_GOLD: int = 40
const START_HUMANS: int = 2
const BATTLES_PER_RUN: int = 5
const MAX_TEAM: int = 4
const FORMATION_ROWS: int = 3
const FORMATION_COLS: int = 2
const BATTLE_REWARD: Array[int] = [20, 25, 30, 35, 0]

# --- Enemy generation (indexed by battle) ---
const ENEMY_BUDGET: Array[int] = [1, 3, 6, 10, 16]
const ENEMY_TEAM_SIZE: Array[int] = [2, 2, 3, 3, 4]
## Budget cost by rarity (COMMON, UNCOMMON, RARE).
const BUDGET_COST: Array[int] = [1, 2, 3]
const BUDGET_COST_FUSION: int = 3

# --- Shop ---
const PRICE_BY_RARITY: Array[int] = [12, 22, 38]
const PRICE_HUMAN: int = 20
const PRICE_STABILIZER: int = 15
const REROLL_BASE: int = 5
const REROLL_STEP: int = 3
const RARITY_WEIGHTS: Array[int] = [60, 30, 10]
const RARE_WEIGHT_PER_BATTLE: int = 5

# --- Instability / risk ---
const INSTABILITY_PER_RARITY: Array[int] = [10, 20, 30]
const RISK_PER_RARITY: Array[int] = [0, 10, 20]
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
const FRENZY_START: float = 45.0
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
const BLITZ_TIME: float = 25.0

# --- Enemy generation archetypes ---
## Chance an enemy follows a coherent archetype instead of random mutations.
const ENEMY_ARCHETYPE_CHANCE: float = 0.7
## Archetype name -> preferred mutation ids.
const ENEMY_ARCHETYPES: Dictionary = {
	&"venom": [&"scorpion_tail", &"mantis_arm"],
	&"tank": [&"bone_plating", &"leech_maw"],
	&"spore": [&"spore_sacs", &"raptor_leg"],
}
## Name of the battle-5 boss used until a champion is saved (stage 4).
const BOSS_NAME: String = "Dr. Splice"

# --- Battle presentation (stage 2) ---
const BATTLE_INTRO_TIME: float = 1.0
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
