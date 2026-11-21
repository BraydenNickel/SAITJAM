"""MUTANT LAB mutation table (design/balance/stage4-mutations.md section 3).

Pure data, stdlib only, importable: ``from mutation_table import MUTATIONS``.
Exactly 100 entries. The 6 mutations that already ship as .tres carry
``"existing": True`` and their values are copied from the .tres (generators skip them).

Power guide used (1 point ~ +40 HP ~ +1.5 ATK ~ -0.1 s interval ~ +2 DEF ~ +8% crit
~ a modest ability). New pieces: common ~1-2, uncommon ~2-3, rare ~3.5-4.5,
ultra ~6-7 (ultras carry a drawback). ARM and LEG pieces stack on both sides, so
their per-piece numbers are lower.

Run ``python tools/mutation_table.py`` for the self-check and a summary.
"""

# Colour families, one per archetype tag (dark -> light, then accent). Mutations of
# one archetype share a family so a build reads as one creature against peach skin.
_PAL = {
    "venom":    (["#1f3a12", "#4f8a22", "#a6e03c"], "#b040e0"),
    "insect":   (["#2e3312", "#6f7a24", "#c2c85a"], "#e8502a"),
    "bone":     (["#5a4c3a", "#b3a488", "#f4ecd8"], "#8a2a2a"),
    "armor":    (["#22303c", "#55708a", "#a9c2d6"], "#ffd24a"),
    "spore":    (["#4a1838", "#a83a78", "#f08cc0"], "#e8f07a"),
    "fire":     (["#5a1a0c", "#c8501e", "#ffb040"], "#fff2a0"),
    "frost":    (["#143a5c", "#3f8fc8", "#bfe8ff"], "#ffffff"),
    "brute":    (["#3c1414", "#8c2f2a", "#d86a50"], "#f0d8b0"),
    "swift":    (["#0f3d3a", "#1f9a8a", "#7ff0d0"], "#fff07a"),
    "support":  (["#2a4a2a", "#5fae6a", "#c8f0b0"], "#fff6c8"),
    "beast":    (["#3a2412", "#8a5a2c", "#d0a060"], "#f4e8c8"),
    "aquatic":  (["#0c2a4a", "#1f6f9a", "#5fd0d8"], "#ff8a5a"),
    "crystal":  (["#2a1a5c", "#7a4fd8", "#c8b0ff"], "#7ff8ff"),
    "shadow":   (["#0c0a14", "#2c2440", "#5a4a80"], "#c83cff"),
    "electric": (["#3a3200", "#d8b800", "#fff25a"], "#5ad8ff"),
    "parasite": (["#3a0c1c", "#8c1f3c", "#e05a78"], "#f0e0a0"),
}


def _art(motif, family, accent=None):
    """Art block for one mutation: motif + the colour family of its archetype."""
    colors, default_accent = _PAL[family]
    return {"motif": motif, "colors": list(colors), "accent": accent or default_accent}


MUTATIONS = [
    # =====================================================================
    # HEAD (16 non-ultra: 8 common, 5 uncommon, 3 rare) + 2 ultra
    # =====================================================================
    {"id": "leech_maw", "name": "Leech Maw", "socket": "HEAD", "rarity": 1, "existing": True,
     "desc": "A ring of hungry teeth.\n+2 ATK.\nHeals 26% of damage dealt.",
     "hp": 0.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["parasite", "bite"],
     "ability": ("AbLifesteal", {"fraction": 0.26}),
     "art": _art("maw", "parasite"), "body": None},

    {"id": "ram_horns", "name": "Ram Horns", "socket": "HEAD", "rarity": 0,
     "desc": "Curled horns of fused keratin.\n-40 HP, +3.5 ATK.",
     "hp": -40.0, "atk": 3.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["brute", "beast"],
     "ability": None,
     "art": _art("horns", "brute"), "body": None},

    {"id": "compound_eyes", "name": "Compound Eyes", "socket": "HEAD", "rarity": 0,
     "desc": "A cluster of faceted eyes.\n+14% crit.\nEach hit adds +2% crit (max +34%).",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.14,
     "tags": ["insect", "swift"],
     "ability": ("AbMomentum", {"crit_per_hit": 0.02, "max_crit": 0.34}),
     "art": _art("eyes", "insect"), "body": None},

    {"id": "static_antennae", "name": "Static Antennae", "socket": "HEAD", "rarity": 0,
     "desc": "Twitching feelers that crackle.\n+40 HP.\n20% chance on hit to zap another enemy for 9, ignoring DEF.",
     "hp": 40.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["electric", "insect"],
     "ability": ("AbChain", {"chance": 0.2, "damage": 9.0}),
     "art": _art("antennae", "electric"), "body": None},

    {"id": "thick_skull", "name": "Thick Skull", "socket": "HEAD", "rarity": 0,
     "desc": "A helmet of overgrown bone.\n+80 HP, +2 DEF, attacks 0.05s slower.",
     "hp": 80.0, "atk": 0.0, "interval": 0.05, "defense": 2.0, "crit": 0.0,
     "tags": ["bone", "armor"],
     "ability": None,
     "art": _art("skull", "bone"), "body": None},

    {"id": "frost_crest", "name": "Frost Crest", "socket": "HEAD", "rarity": 0,
     "desc": "A frill of ice-cold cartilage.\n+40 HP.\nHits slow the target's attacks by 0.05s (max 0.35s).",
     "hp": 40.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["frost", "crystal"],
     "ability": ("AbChill", {"slow_per_hit": 0.05, "max_slow": 0.35}),
     "art": _art("crest", "frost"), "body": None},

    {"id": "snapping_beak", "name": "Snapping Beak", "socket": "HEAD", "rarity": 0,
     "desc": "A hooked beak for finishing prey.\n+2 ATK.\nHits on enemies under 20% HP deal +6 damage, ignoring DEF.",
     "hp": 0.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["beast", "swift"],
     "ability": ("AbExecute", {"threshold": 0.2, "bonus": 6.0}),
     "art": _art("beak", "beast"), "body": None},

    {"id": "brine_feelers", "name": "Brine Feelers", "socket": "HEAD", "rarity": 0,
     "desc": "Wet tendrils that knit wounds shut.\n+40 HP.\nHeals 5 HP every 4s.",
     "hp": 40.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["aquatic", "parasite"],
     "ability": ("AbRegen", {"interval": 4.0, "amount": 5.0}),
     "art": _art("tentacles", "aquatic"), "body": None},

    {"id": "ember_horns", "name": "Ember Horns", "socket": "HEAD", "rarity": 0,
     "desc": "Horns that smoulder from within.\n+3.5 ATK, -1 DEF.",
     "hp": 0.0, "atk": 3.5, "interval": 0.0, "defense": -1.0, "crit": 0.0,
     "tags": ["fire", "brute"],
     "ability": None,
     "art": _art("horns", "fire"), "body": None},

    {"id": "howler_crest", "name": "Howler Crest", "socket": "HEAD", "rarity": 1,
     "desc": "A resonating throat crest.\n+90 HP.\nBattle start: every ally gains +3 ATK.",
     "hp": 90.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["support", "beast"],
     "ability": ("AbWarCry", {"atk_bonus": 3.0, "def_bonus": 0.0, "hp_bonus": 0.0}),
     "art": _art("crest", "support"), "body": None},

    {"id": "venom_fangs", "name": "Venom Fangs", "socket": "HEAD", "rarity": 1,
     "desc": "Hollow fangs dripping toxin.\n+1 ATK.\nHits add a venom stack (1 dmg/s, 4s, max 2).",
     "hp": 0.0, "atk": 1.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["venom", "parasite"],
     "ability": ("AbVenom", {"stacks_per_hit": 1, "damage_per_second": 1.0, "duration": 4.0, "max_stacks": 2}),
     "art": _art("maw", "venom"), "body": None},

    {"id": "storm_antennae", "name": "Storm Antennae", "socket": "HEAD", "rarity": 1,
     "desc": "Long feelers that arc with charge.\n+9% crit.\n35% chance on hit to zap another enemy for 11, ignoring DEF.",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.09,
     "tags": ["electric", "swift"],
     "ability": ("AbChain", {"chance": 0.35, "damage": 11.0}),
     "art": _art("antennae", "electric"), "body": None},

    {"id": "stalker_eyes", "name": "Stalker Eyes", "socket": "HEAD", "rarity": 1,
     "desc": "Slit pupils that find the weak.\n+13% crit.\nEvery 4s, 8 damage to the enemy with the lowest HP, ignoring DEF.",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.13,
     "tags": ["shadow", "swift"],
     "ability": ("AbSnipe", {"interval": 4.0, "damage": 8.0}),
     "art": _art("eyes", "shadow"), "body": None},

    {"id": "jelly_crown", "name": "Jelly Crown", "socket": "HEAD", "rarity": 2,
     "desc": "A crown of stinging tendrils.\n+60 HP, +3 ATK.\n38% chance on hit to delay the target's next attack by 1s.",
     "hp": 60.0, "atk": 3.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["aquatic", "electric"],
     "ability": ("AbStun", {"chance": 0.38, "delay": 1.0}),
     "art": _art("tentacles", "aquatic", "#fff25a"), "body": None},

    {"id": "menders_halo", "name": "Mender's Halo", "socket": "HEAD", "rarity": 2,
     "desc": "A ring of soft bioluminescence.\n+50 HP.\nEvery 4s, heals the most wounded ally for 18 HP.",
     "hp": 50.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["support", "crystal"],
     "ability": ("AbMend", {"interval": 4.0, "amount": 18.0}),
     "art": _art("halo", "support"), "body": None},

    {"id": "deaths_head", "name": "Death's Head", "socket": "HEAD", "rarity": 2,
     "desc": "The face recedes to bare skull.\n-20 HP, +4 ATK, +10% crit.\nHits on enemies under 30% HP deal +16 damage, ignoring DEF.",
     "hp": -20.0, "atk": 4.0, "interval": 0.0, "defense": 0.0, "crit": 0.1,
     "tags": ["bone", "shadow"],
     "ability": ("AbExecute", {"threshold": 0.3, "bonus": 16.0}),
     "art": _art("skull", "bone", "#c83cff"), "body": None},

    {"id": "false_seraph_halo", "name": "Halo of the False Seraph", "socket": "HEAD", "rarity": 3,
     "desc": "Flesh turns to pale light and feathers.\n+100 HP, -1.5 ATK, +1 DEF.\nEvery 3s, heals the most wounded ally for 21 HP.",
     "hp": 100.0, "atk": -1.5, "interval": 0.0, "defense": 1.0, "crit": 0.0,
     "tags": ["support", "angelic"],
     "ability": ("AbMend", {"interval": 3.0, "amount": 21.0}),
     "art": {"motif": "halo", "colors": ["#8a7a3a", "#e8d890", "#fffbe0"], "accent": "#9ad8ff"},
     "body": {"style": "angelic", "tint": "#ffffff", "scale": 1.15, "aura": None}},

    {"id": "amber_hive_crown", "name": "Crown of the Amber Hive", "socket": "HEAD", "rarity": 3,
     "desc": "Wax and amber encase the body; it hums.\n+90 HP, -1 DEF.\nEvery 1.5s, the swarm bites a random enemy for 7 and heals you for 4.",
     "hp": 90.0, "atk": 0.0, "interval": 0.0, "defense": -1.0, "crit": 0.0,
     "tags": ["insect", "parasite", "hive"],
     "ability": ("AbSwarm", {"interval": 1.5, "damage": 7.0, "heal": 4.0}),
     "art": {"motif": "antennae", "colors": ["#5a3a08", "#d89a1e", "#ffe27a"], "accent": "#3a2408"},
     "body": {"style": "gold", "tint": "#ffffff", "scale": 1.1, "aura": None}},

    # =====================================================================
    # TORSO (14 non-ultra: 7 common, 4 uncommon, 3 rare) + 2 ultra
    # =====================================================================
    {"id": "bone_plating", "name": "Bone Plating", "socket": "TORSO", "rarity": 0, "existing": True,
     "desc": "Armoured plates grow over the torso.\n+60 HP, +1 DEF.\n20% chance to reflect 3 damage when hit.",
     "hp": 60.0, "atk": 0.0, "interval": 0.0, "defense": 1.0, "crit": 0.0,
     "tags": ["bone", "armor"],
     "ability": ("AbReflect", {"chance": 0.2, "damage": 3.0}),
     "art": _art("plates", "bone"), "body": None},

    {"id": "shaggy_pelt", "name": "Shaggy Pelt", "socket": "TORSO", "rarity": 0,
     "desc": "A thick, matted winter coat.\n+120 HP, attacks 0.05s slower.",
     "hp": 120.0, "atk": 0.0, "interval": 0.05, "defense": 0.0, "crit": 0.0,
     "tags": ["beast", "frost"],
     "ability": None,
     "art": _art("fur", "beast", "#bfe8ff"), "body": None},

    {"id": "brine_scales", "name": "Brine Scales", "socket": "TORSO", "rarity": 0,
     "desc": "Overlapping scales slick with brine.\n+70 HP, -0.5 ATK, +1 DEF.",
     "hp": 70.0, "atk": -0.5, "interval": 0.0, "defense": 1.0, "crit": 0.0,
     "tags": ["aquatic", "armor"],
     "ability": None,
     "art": _art("scales", "aquatic"), "body": None},

    {"id": "rib_spurs", "name": "Rib Spurs", "socket": "TORSO", "rarity": 0,
     "desc": "Ribs split the skin as jagged spurs.\n+20 HP.\nAttackers take 2 damage per basic hit, ignoring DEF.",
     "hp": 20.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["bone", "brute"],
     "ability": ("AbThorns", {"damage": 2.0}),
     "art": _art("ribs", "bone"), "body": None},

    {"id": "ember_core", "name": "Ember Core", "socket": "TORSO", "rarity": 0,
     "desc": "A coal-hot knot behind the sternum.\n+1 ATK.\nHits burn for 0.3% of the target's max HP per second for 3s.",
     "hp": 0.0, "atk": 1.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["fire", "gland"],
     "ability": ("AbBurn", {"fraction": 0.003, "duration": 3.0}),
     "art": _art("core", "fire"), "body": None},

    {"id": "chitin_carapace", "name": "Chitin Carapace", "socket": "TORSO", "rarity": 0,
     "desc": "A glossy segmented chestplate.\n+30 HP, +2 DEF, attacks 0.1s slower.",
     "hp": 30.0, "atk": 0.0, "interval": 0.1, "defense": 2.0, "crit": 0.0,
     "tags": ["insect", "armor"],
     "ability": None,
     "art": _art("plates", "insect"), "body": None},

    {"id": "overgrown_heart", "name": "Overgrown Heart", "socket": "TORSO", "rarity": 0,
     "desc": "A second heart that pounds when cornered.\n+40 HP.\nOnce, below 40% HP: attack interval x0.8.",
     "hp": 40.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["brute", "parasite"],
     "ability": ("AbBerserk", {"threshold": 0.4, "interval_mult": 0.8}),
     "art": _art("core", "brute"), "body": None},

    {"id": "crystal_lattice", "name": "Crystal Lattice", "socket": "TORSO", "rarity": 1,
     "desc": "Mineral veins harden into a lattice.\n+2 DEF.\nBattle start: a shield that absorbs 75 damage.",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 2.0, "crit": 0.0,
     "tags": ["crystal", "armor"],
     "ability": ("AbShield", {"amount": 75.0}),
     "art": _art("crystal", "crystal"), "body": None},

    {"id": "dynamo_core", "name": "Dynamo Core", "socket": "TORSO", "rarity": 1,
     "desc": "A humming organ that stores charge.\n+2 ATK, attacks 0.15s faster.\n30% chance on hit to zap another enemy for 6, ignoring DEF.",
     "hp": 0.0, "atk": 2.0, "interval": -0.15, "defense": 0.0, "crit": 0.0,
     "tags": ["electric", "swift"],
     "ability": ("AbChain", {"chance": 0.3, "damage": 6.0}),
     "art": _art("core", "electric"), "body": None},

    {"id": "mycelium_coat", "name": "Mycelium Coat", "socket": "TORSO", "rarity": 1,
     "desc": "Fungal threads that regrow what dies.\n+60 HP.\nOnce: survive a lethal hit and heal to 25% of max HP.",
     "hp": 60.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["spore", "parasite"],
     "ability": ("AbSecondWind", {"heal_fraction": 0.25}),
     "art": _art("fur", "spore"), "body": None},

    {"id": "resonant_ribcage", "name": "Resonant Ribcage", "socket": "TORSO", "rarity": 1,
     "desc": "A hollow chest that booms like a drum.\n+110 HP.\nBattle start: every ally gains +1 DEF and +60 HP.",
     "hp": 110.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["support", "bone"],
     "ability": ("AbWarCry", {"atk_bonus": 0.0, "def_bonus": 1.0, "hp_bonus": 60.0}),
     "art": _art("ribs", "support"), "body": None},

    {"id": "furnace_belly", "name": "Furnace Belly", "socket": "TORSO", "rarity": 2,
     "desc": "A gut full of living fire.\n+40 HP, +2 ATK, attacks 0.1s slower.\nHits burn for 0.6% of the target's max HP per second for 4s.",
     "hp": 40.0, "atk": 2.0, "interval": 0.1, "defense": 0.0, "crit": 0.0,
     "tags": ["fire", "brute"],
     "ability": ("AbBurn", {"fraction": 0.006, "duration": 4.0}),
     "art": _art("core", "fire"), "body": None},

    {"id": "glacier_hide", "name": "Glacier Hide", "socket": "TORSO", "rarity": 2,
     "desc": "Skin like packed blue ice.\n+120 HP, +3 DEF, attacks 0.1s slower.\nBattle start: a shield that absorbs 90 damage.",
     "hp": 120.0, "atk": 0.0, "interval": 0.1, "defense": 3.0, "crit": 0.0,
     "tags": ["frost", "armor"],
     "ability": ("AbShield", {"amount": 90.0}),
     "art": _art("scales", "frost"), "body": None},

    {"id": "revenant_ribcage", "name": "Revenant Ribcage", "socket": "TORSO", "rarity": 2,
     "desc": "A cage of bone that refuses to stay dead.\n+60 HP.\nOnce: survive a lethal hit and heal to 45% of max HP.",
     "hp": 60.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["bone", "shadow"],
     "ability": ("AbSecondWind", {"heal_fraction": 0.45}),
     "art": _art("ribs", "bone", "#c83cff"), "body": None},

    {"id": "obsidian_colossus_heart", "name": "Obsidian Colossus Heart", "socket": "TORSO", "rarity": 3,
     "desc": "The body swells into cracked volcanic glass.\n+130 HP, +2 DEF, attacks 0.3s slower.\nTakes 25% less damage. Every 4s, stomps the enemy front row for 9.",
     "hp": 130.0, "atk": 0.0, "interval": 0.3, "defense": 2.0, "crit": 0.0,
     "tags": ["fire", "brute", "armor"],
     "ability": ("AbTitan", {"damage_reduction": 0.25, "stomp_interval": 4.0, "stomp_damage": 9.0}),
     "art": {"motif": "core", "colors": ["#1a0f14", "#b8320e", "#ff9a2a"], "accent": "#fff2a0"},
     "body": {"style": "molten", "tint": "#ffffff", "scale": 1.35, "aura": None}},

    {"id": "prismatic_geode_heart", "name": "Prismatic Geode Heart", "socket": "TORSO", "rarity": 3,
     "desc": "Skin splits into towering crystal facets.\n+100 HP, -1.5 ATK, +3 DEF.\n60% chance to reflect 12 damage when hit.",
     "hp": 100.0, "atk": -1.5, "interval": 0.0, "defense": 3.0, "crit": 0.0,
     "tags": ["crystal", "armor"],
     "ability": ("AbReflect", {"chance": 0.6, "damage": 12.0}),
     "art": {"motif": "crystal", "colors": ["#2a1a5c", "#8a5ff0", "#e0d0ff"], "accent": "#7ff8ff"},
     "body": {"style": "crystal", "tint": "#ffffff", "scale": 1.2, "aura": None}},

    # =====================================================================
    # BACK (14 non-ultra: 6 common, 5 uncommon, 3 rare) + 2 ultra
    # =====================================================================
    {"id": "spore_sacs", "name": "Spore Sacs", "socket": "BACK", "rarity": 1, "existing": True,
     "desc": "Pulsing sacs on the back.\n+50 HP.\nEvery 4s, 5 damage to all enemies, ignoring DEF.",
     "hp": 50.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["fungus", "aoe"],
     "ability": ("AbSporePulse", {"interval": 4.0, "damage": 5.0}),
     "art": _art("sacs", "spore"), "body": None},

    {"id": "quill_ridge", "name": "Quill Ridge", "socket": "BACK", "rarity": 0,
     "desc": "A ridge of barbed quills.\n-20 HP.\nAttackers take 3 damage per basic hit, ignoring DEF.",
     "hp": -20.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["beast", "brute"],
     "ability": ("AbThorns", {"damage": 3.0}),
     "art": _art("spikes", "beast"), "body": None},

    {"id": "barnacle_shell", "name": "Barnacle Shell", "socket": "BACK", "rarity": 0,
     "desc": "A crusted shell, heavy as stone.\n+70 HP, +2 DEF, attacks 0.2s slower.",
     "hp": 70.0, "atk": 0.0, "interval": 0.2, "defense": 2.0, "crit": 0.0,
     "tags": ["aquatic", "armor"],
     "ability": None,
     "art": _art("shell", "aquatic"), "body": None},

    {"id": "dorsal_fin", "name": "Dorsal Fin", "socket": "BACK", "rarity": 0,
     "desc": "A sleek fin that cuts the air.\n-0.5 ATK, attacks 0.25s faster.",
     "hp": 0.0, "atk": -0.5, "interval": -0.25, "defense": 0.0, "crit": 0.0,
     "tags": ["aquatic", "swift"],
     "ability": None,
     "art": _art("fins", "aquatic"), "body": None},

    {"id": "puffball_vents", "name": "Puffball Vents", "socket": "BACK", "rarity": 0,
     "desc": "Vents that cough up choking spores.\n+30 HP.\nEvery 5s, 3 damage to all enemies, ignoring DEF.",
     "hp": 30.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["spore", "aoe"],
     "ability": ("AbSporePulse", {"interval": 5.0, "damage": 3.0}),
     "art": _art("tubes", "spore"), "body": None},

    {"id": "snowmoth_wings", "name": "Snowmoth Wings", "socket": "BACK", "rarity": 0,
     "desc": "Powdery wings that shed frost.\n-10 HP.\n35% chance to dodge a hit.",
     "hp": -10.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["frost", "insect"],
     "ability": ("AbDodge", {"chance": 0.35}),
     "art": _art("wings", "frost"), "body": None},

    {"id": "adrenal_tubes", "name": "Adrenal Tubes", "socket": "BACK", "rarity": 0,
     "desc": "Exposed glands that pump with every blow.\n+20 HP.\nEach basic hit taken: +0.5 ATK (max 5 stacks).",
     "hp": 20.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["brute", "parasite"],
     "ability": ("AbRage", {"atk_per_stack": 0.5, "max_stacks": 5}),
     "art": _art("tubes", "brute"), "body": None},

    {"id": "dusk_wings", "name": "Dusk Wings", "socket": "BACK", "rarity": 1,
     "desc": "Leathery wings for a silent first strike.\nAttacks 0.25s faster.\nBattle start: 90 damage to a random enemy, ignoring DEF.",
     "hp": 0.0, "atk": 0.0, "interval": -0.25, "defense": 0.0, "crit": 0.0,
     "tags": ["shadow", "swift"],
     "ability": ("AbAmbush", {"damage": 90.0}),
     "art": _art("wings", "shadow"), "body": None},

    {"id": "tesla_spines", "name": "Tesla Spines", "socket": "BACK", "rarity": 1,
     "desc": "Metallic spines that hold a charge.\n+30 HP, +1 DEF.\n40% chance to reflect 6 damage when hit.",
     "hp": 30.0, "atk": 0.0, "interval": 0.0, "defense": 1.0, "crit": 0.0,
     "tags": ["electric", "armor"],
     "ability": ("AbReflect", {"chance": 0.4, "damage": 6.0}),
     "art": _art("spikes", "electric"), "body": None},

    {"id": "nectar_sacs", "name": "Nectar Sacs", "socket": "BACK", "rarity": 1,
     "desc": "Swollen sacs of restorative nectar.\n+30 HP.\nEvery 5s, heals the most wounded ally for 13 HP.",
     "hp": 30.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["support", "spore"],
     "ability": ("AbMend", {"interval": 5.0, "amount": 13.0}),
     "art": _art("sacs", "support", "#f08cc0"), "body": None},

    {"id": "acid_sprayer", "name": "Acid Sprayer", "socket": "BACK", "rarity": 1,
     "desc": "Nozzles that mist dissolving acid.\n+0.5 ATK.\nHits strip 1 DEF from the target (max 3).",
     "hp": 0.0, "atk": 0.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["venom", "insect"],
     "ability": ("AbCorrode", {"def_per_hit": 1.0, "max_total": 3.0}),
     "art": _art("tubes", "venom"), "body": None},

    {"id": "magma_shell", "name": "Magma Shell", "socket": "BACK", "rarity": 2,
     "desc": "A crust of cooling lava.\n+80 HP, +2 DEF, attacks 0.1s slower.\nAttackers take 4 damage per basic hit, ignoring DEF.",
     "hp": 80.0, "atk": 0.0, "interval": 0.1, "defense": 2.0, "crit": 0.0,
     "tags": ["fire", "armor"],
     "ability": ("AbThorns", {"damage": 4.0}),
     "art": _art("shell", "fire"), "body": None},

    {"id": "blight_stacks", "name": "Blight Stacks", "socket": "BACK", "rarity": 2,
     "desc": "Chimneys that belch a toxic cloud.\n+80 HP.\nEvery 3.5s, 8 damage to all enemies, ignoring DEF.",
     "hp": 80.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["spore", "venom"],
     "ability": ("AbSporePulse", {"interval": 3.5, "damage": 8.0}),
     "art": _art("tubes", "spore", "#a6e03c"), "body": None},

    {"id": "razor_wings", "name": "Razor Wings", "socket": "BACK", "rarity": 2,
     "desc": "Wing-cases honed to a cutting edge.\n+2 ATK, attacks 0.15s faster.\nHits deal 50% of their damage to other enemies in the target's row.",
     "hp": 0.0, "atk": 2.0, "interval": -0.15, "defense": 0.0, "crit": 0.0,
     "tags": ["swift", "insect"],
     "ability": ("AbCleave", {"fraction": 0.5}),
     "art": _art("wings", "swift"), "body": None},

    {"id": "void_moth_wings", "name": "Wings of the Void Moth", "socket": "BACK", "rarity": 3,
     "desc": "The body thins to a starless outline.\n-50 HP, +6 ATK.\n30% chance to cancel any hit and strike back for 13.",
     "hp": -50.0, "atk": 6.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["shadow", "swift", "void"],
     "ability": ("AbPhase", {"chance": 0.3, "counter": 13.0}),
     "art": {"motif": "wings", "colors": ["#07041a", "#2a1470", "#7a5cf0"], "accent": "#f0f0ff"},
     "body": {"style": "void", "tint": "#ffffff", "scale": 1.05, "aura": None}},

    {"id": "primordial_ooze_mantle", "name": "Primordial Ooze Mantle", "socket": "BACK", "rarity": 3,
     "desc": "Flesh melts into glistening, self-knitting ooze.\n+200 HP, -1 DEF, attacks 0.05s slower.\nHeals 14 HP every 2s.",
     "hp": 200.0, "atk": 0.0, "interval": 0.05, "defense": -1.0, "crit": 0.0,
     "tags": ["parasite", "spore", "ooze"],
     "ability": ("AbRegen", {"interval": 2.0, "amount": 14.0}),
     "art": {"motif": "sacs", "colors": ["#1a4a2a", "#3fb86a", "#b0f8a0"], "accent": "#f0ffd0"},
     "body": {"style": "slime", "tint": "#ffffff", "scale": 1.25, "aura": None}},

    # =====================================================================
    # ARM (20 non-ultra: 10 common, 7 uncommon, 3 rare) + 1 ultra
    # Arms fit both sides and stack: numbers are per piece.
    # =====================================================================
    {"id": "mantis_arm", "name": "Mantis Arm", "socket": "ARM", "rarity": 0, "existing": True,
     "desc": "A serrated blade-arm.\n+1 ATK.\nEvery 4th attack strikes twice.",
     "hp": 0.0, "atk": 1.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["insect", "blade"],
     "ability": ("AbDoubleStrike", {"every_n": 4, "extra_strikes": 1}),
     "art": _art("blade", "insect"), "body": None},

    {"id": "crab_pincer", "name": "Crab Pincer", "socket": "ARM", "rarity": 0,
     "desc": "A heavy crushing claw.\n+1.5 ATK, +1 DEF, attacks 0.05s slower.",
     "hp": 0.0, "atk": 1.5, "interval": 0.05, "defense": 1.0, "crit": 0.0,
     "tags": ["aquatic", "armor"],
     "ability": None,
     "art": _art("pincer", "aquatic"), "body": None},

    {"id": "bone_club", "name": "Bone Club", "socket": "ARM", "rarity": 0,
     "desc": "A knotted fist of solid bone.\n+3 ATK, attacks 0.15s slower.",
     "hp": 0.0, "atk": 3.0, "interval": 0.15, "defense": 0.0, "crit": 0.0,
     "tags": ["bone", "brute"],
     "ability": None,
     "art": _art("club", "bone"), "body": None},

    {"id": "ragged_claw", "name": "Ragged Claw", "socket": "ARM", "rarity": 0,
     "desc": "Torn nails grown into hooks.\n-10 HP, +2 ATK, +6% crit.",
     "hp": -10.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.06,
     "tags": ["beast", "claw"],
     "ability": None,
     "art": _art("claw", "beast"), "body": None},

    {"id": "sucker_arm", "name": "Sucker Arm", "socket": "ARM", "rarity": 0,
     "desc": "A boneless limb lined with suckers.\n+1 ATK.\nHeals 15% of damage dealt.",
     "hp": 0.0, "atk": 1.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["aquatic", "parasite"],
     "ability": ("AbLifesteal", {"fraction": 0.15}),
     "art": _art("tentacle", "aquatic", "#e05a78"), "body": None},

    {"id": "spark_prod", "name": "Spark Prod", "socket": "ARM", "rarity": 0,
     "desc": "A forearm ending in a live electrode.\n+2 ATK.\n18% chance on hit to delay the target's next attack by 0.6s.",
     "hp": 0.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["electric", "gland"],
     "ability": ("AbStun", {"chance": 0.18, "delay": 0.6}),
     "art": _art("cannon", "electric"), "body": None},

    {"id": "frostbite_claw", "name": "Frostbite Claw", "socket": "ARM", "rarity": 0,
     "desc": "Blue-black talons, cold to the bone.\n+1.5 ATK.\nHits slow the target's attacks by 0.03s (max 0.25s).",
     "hp": 0.0, "atk": 1.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["frost", "beast"],
     "ability": ("AbChill", {"slow_per_hit": 0.03, "max_slow": 0.25}),
     "art": _art("claw", "frost"), "body": None},

    {"id": "mold_tendril", "name": "Mold Tendril", "socket": "ARM", "rarity": 0,
     "desc": "A creeping vine of rot.\n+0.5 ATK.\nHits strip 0.5 DEF from the target (max 2).",
     "hp": 0.0, "atk": 0.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["spore", "venom"],
     "ability": ("AbCorrode", {"def_per_hit": 0.5, "max_total": 2.0}),
     "art": _art("tentacle", "spore", "#a6e03c"), "body": None},

    {"id": "chitin_shiv", "name": "Chitin Shiv", "socket": "ARM", "rarity": 0,
     "desc": "A thin, brittle stabbing limb.\n-20 HP, +3 ATK.",
     "hp": -20.0, "atk": 3.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["insect", "swift"],
     "ability": None,
     "art": _art("blade", "insect"), "body": None},

    {"id": "cinder_fist", "name": "Cinder Fist", "socket": "ARM", "rarity": 0,
     "desc": "Knuckles crusted with hot ash.\n+1 ATK.\nHits burn for 0.3% of the target's max HP per second for 3s.",
     "hp": 0.0, "atk": 1.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["fire", "brute"],
     "ability": ("AbBurn", {"fraction": 0.003, "duration": 3.0}),
     "art": _art("club", "fire"), "body": None},

    {"id": "butcher_blade", "name": "Butcher Blade", "socket": "ARM", "rarity": 1,
     "desc": "A broad slab of sharpened bone.\n+2 ATK.\nHits deal 25% of their damage to other enemies in the target's row.",
     "hp": 0.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["brute", "bone"],
     "ability": ("AbCleave", {"fraction": 0.25}),
     "art": _art("blade", "brute"), "body": None},

    {"id": "arc_cannon", "name": "Arc Cannon", "socket": "ARM", "rarity": 1,
     "desc": "A hollow limb that spits lightning.\n+1.5 ATK.\n40% chance on hit to zap another enemy for 6, ignoring DEF.",
     "hp": 0.0, "atk": 1.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["electric", "crystal"],
     "ability": ("AbChain", {"chance": 0.4, "damage": 6.0}),
     "art": _art("cannon", "electric", "#c8b0ff"), "body": None},

    {"id": "toxin_claw", "name": "Toxin Claw", "socket": "ARM", "rarity": 1,
     "desc": "Claws grooved to carry poison.\n+1 ATK.\nHits add a venom stack (1 dmg/s, 4s, max 2).",
     "hp": 0.0, "atk": 1.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["venom", "beast"],
     "ability": ("AbVenom", {"stacks_per_hit": 1, "damage_per_second": 1.0, "duration": 4.0, "max_stacks": 2}),
     "art": _art("claw", "venom"), "body": None},

    {"id": "squid_arm", "name": "Squid Arm", "socket": "ARM", "rarity": 1,
     "desc": "A grasping arm that will not let go.\n+100 HP.\n50% chance on hit to delay the target's next attack by 0.8s.",
     "hp": 100.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["aquatic", "shadow"],
     "ability": ("AbStun", {"chance": 0.5, "delay": 0.8}),
     "art": _art("tentacle", "aquatic", "#c83cff"), "body": None},

    {"id": "bulwark_pincer", "name": "Bulwark Pincer", "socket": "ARM", "rarity": 1,
     "desc": "A claw broad enough to hide behind.\n+2 DEF.\nBattle start: a shield that absorbs 80 damage.",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 2.0, "crit": 0.0,
     "tags": ["armor", "insect"],
     "ability": ("AbShield", {"amount": 80.0}),
     "art": _art("pincer", "armor"), "body": None},

    {"id": "quartz_knuckle", "name": "Quartz Knuckle", "socket": "ARM", "rarity": 1,
     "desc": "A fist of faceted stone.\n+2 ATK, +5% crit.\nEach hit adds +2% crit (max +26%).",
     "hp": 0.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.05,
     "tags": ["crystal", "brute"],
     "ability": ("AbMomentum", {"crit_per_hit": 0.02, "max_crit": 0.26}),
     "art": _art("club", "crystal"), "body": None},

    {"id": "shade_talon", "name": "Shade Talon", "socket": "ARM", "rarity": 1,
     "desc": "A claw that seems to arrive early.\n+2.5 ATK.\nHits on enemies under 25% HP deal +9 damage, ignoring DEF.",
     "hp": 0.0, "atk": 2.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["shadow", "claw"],
     "ability": ("AbExecute", {"threshold": 0.25, "bonus": 9.0}),
     "art": _art("claw", "shadow"), "body": None},

    {"id": "pyre_cannon", "name": "Pyre Cannon", "socket": "ARM", "rarity": 2,
     "desc": "A barrel of bone venting white flame.\n+2.5 ATK, attacks 0.1s slower.\nHits burn for 0.8% of the target's max HP per second for 4s.",
     "hp": 0.0, "atk": 2.5, "interval": 0.1, "defense": 0.0, "crit": 0.0,
     "tags": ["fire", "gland"],
     "ability": ("AbBurn", {"fraction": 0.008, "duration": 4.0}),
     "art": _art("cannon", "fire"), "body": None},

    {"id": "flicker_blade", "name": "Flicker Blade", "socket": "ARM", "rarity": 2,
     "desc": "A blade too fast to follow.\n+2 ATK, attacks 0.15s faster.\nEvery 2nd attack strikes twice.",
     "hp": 0.0, "atk": 2.0, "interval": -0.15, "defense": 0.0, "crit": 0.0,
     "tags": ["swift", "insect"],
     "ability": ("AbDoubleStrike", {"every_n": 2, "extra_strikes": 1}),
     "art": _art("blade", "swift"), "body": None},

    {"id": "frost_maul", "name": "Frost Maul", "socket": "ARM", "rarity": 2,
     "desc": "A fist of frozen rock.\n+5 ATK, attacks 0.15s slower.\nHits slow the target's attacks by 0.1s (max 0.65s).",
     "hp": 0.0, "atk": 5.0, "interval": 0.15, "defense": 0.0, "crit": 0.0,
     "tags": ["frost", "brute"],
     "ability": ("AbChill", {"slow_per_hit": 0.1, "max_slow": 0.65}),
     "art": _art("club", "frost"), "body": None},

    {"id": "reapers_scythe_arm", "name": "Reaper's Scythe Arm", "socket": "ARM", "rarity": 3,
     "desc": "Flesh sloughs away, leaving a grinning frame of bone.\n-50 HP, +6 ATK, +13% crit.\nHits on enemies under 35% HP deal +26 damage, ignoring DEF.",
     "hp": -50.0, "atk": 6.0, "interval": 0.0, "defense": 0.0, "crit": 0.13,
     "tags": ["bone", "shadow"],
     "ability": ("AbExecute", {"threshold": 0.35, "bonus": 26.0}),
     "art": {"motif": "blade", "colors": ["#3a3440", "#a8a0a8", "#f4f0e8"], "accent": "#7af0c0"},
     "body": {"style": "skeletal", "tint": "#ffffff", "scale": 1.1, "aura": None}},

    # =====================================================================
    # LEG (16 non-ultra: 8 common, 5 uncommon, 3 rare), no ultra
    # Legs fit both sides and stack: numbers are per piece.
    # =====================================================================
    {"id": "raptor_leg", "name": "Raptor Leg", "socket": "LEG", "rarity": 1, "existing": True,
     "desc": "Springy digitigrade legs.\nAttacks 0.25s faster.\n28% chance to dodge a hit.",
     "hp": 0.0, "atk": 0.0, "interval": -0.25, "defense": 0.0, "crit": 0.0,
     "tags": ["beast", "speed"],
     "ability": ("AbDodge", {"chance": 0.28}),
     "art": _art("raptor", "beast"), "body": None},

    {"id": "cloven_hoof", "name": "Cloven Hoof", "socket": "LEG", "rarity": 0,
     "desc": "A heavy, split hoof.\n+120 HP, attacks 0.05s slower.",
     "hp": 120.0, "atk": 0.0, "interval": 0.05, "defense": 0.0, "crit": 0.0,
     "tags": ["beast", "brute"],
     "ability": None,
     "art": _art("hoof", "beast"), "body": None},

    {"id": "spider_leg", "name": "Spider Leg", "socket": "LEG", "rarity": 0,
     "desc": "A jointed leg that never rests.\n-10 HP, attacks 0.25s faster.",
     "hp": -10.0, "atk": 0.0, "interval": -0.25, "defense": 0.0, "crit": 0.0,
     "tags": ["insect", "swift"],
     "ability": None,
     "art": _art("spider", "insect"), "body": None},

    {"id": "spring_heel", "name": "Spring Heel", "socket": "LEG", "rarity": 0,
     "desc": "A coiled tendon under the heel.\nAttacks 0.15s faster.\n22% chance to dodge a hit.",
     "hp": 0.0, "atk": 0.0, "interval": -0.15, "defense": 0.0, "crit": 0.0,
     "tags": ["swift", "speed"],
     "ability": ("AbDodge", {"chance": 0.22}),
     "art": _art("spring", "swift"), "body": None},

    {"id": "stalker_paw", "name": "Stalker Paw", "socket": "LEG", "rarity": 0,
     "desc": "Soft pads for a soundless approach.\n+15% crit.\nBattle start: 67 damage to a random enemy, ignoring DEF.",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.15,
     "tags": ["shadow", "beast"],
     "ability": ("AbAmbush", {"damage": 67.0}),
     "art": _art("paw", "shadow"), "body": None},

    {"id": "chitin_tread", "name": "Chitin Tread", "socket": "LEG", "rarity": 0,
     "desc": "Rows of plated segments grind forward.\n+80 HP, +2 DEF, attacks 0.05s slower.",
     "hp": 80.0, "atk": 0.0, "interval": 0.05, "defense": 2.0, "crit": 0.0,
     "tags": ["armor", "insect"],
     "ability": None,
     "art": _art("tread", "armor"), "body": None},

    {"id": "marsh_hopper", "name": "Marsh Hopper", "socket": "LEG", "rarity": 0,
     "desc": "A webbed, rubbery jumping leg.\nAttacks 0.1s faster.\nHeals 8 HP every 5s.",
     "hp": 0.0, "atk": 0.0, "interval": -0.1, "defense": 0.0, "crit": 0.0,
     "tags": ["aquatic", "amphibian"],
     "ability": ("AbRegen", {"interval": 5.0, "amount": 8.0}),
     "art": _art("spring", "aquatic"), "body": None},

    {"id": "rime_hoof", "name": "Rime Hoof", "socket": "LEG", "rarity": 0,
     "desc": "A hoof sheathed in clear ice.\n+70 HP.\nBattle start: a shield that absorbs 55 damage.",
     "hp": 70.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["frost", "crystal"],
     "ability": ("AbShield", {"amount": 55.0}),
     "art": _art("hoof", "frost"), "body": None},

    {"id": "bone_stilt", "name": "Bone Stilt", "socket": "LEG", "rarity": 0,
     "desc": "A long, fleshless striding limb.\n-20 HP, +3 ATK.",
     "hp": -20.0, "atk": 3.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["bone", "stilt"],
     "ability": None,
     "art": _art("raptor", "bone"), "body": None},

    {"id": "stampede_hoof", "name": "Stampede Hoof", "socket": "LEG", "rarity": 1,
     "desc": "A hoof that hits harder the angrier it gets.\n+50 HP.\nEach basic hit taken: +0.5 ATK (max 8 stacks).",
     "hp": 50.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["brute", "beast"],
     "ability": ("AbRage", {"atk_per_stack": 0.5, "max_stacks": 8}),
     "art": _art("hoof", "brute"), "body": None},

    {"id": "widow_leg", "name": "Widow Leg", "socket": "LEG", "rarity": 1,
     "desc": "A needle-tipped leg with a red mark.\n+7% crit.\nHits apply venom (2 dmg/s, 3s, does not stack).",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.07,
     "tags": ["venom", "insect"],
     "ability": ("AbVenom", {"stacks_per_hit": 1, "damage_per_second": 2.0, "duration": 3.0, "max_stacks": 1}),
     "art": _art("spider", "venom", "#e8502a"), "body": None},

    {"id": "capacitor_heel", "name": "Capacitor Heel", "socket": "LEG", "rarity": 1,
     "desc": "A heel that discharges on impact.\nAttacks 0.25s faster.\n50% chance on hit to delay the target's next attack by 0.7s.",
     "hp": 0.0, "atk": 0.0, "interval": -0.25, "defense": 0.0, "crit": 0.0,
     "tags": ["electric", "swift"],
     "ability": ("AbStun", {"chance": 0.5, "delay": 0.7}),
     "art": _art("spring", "electric"), "body": None},

    {"id": "rootfoot", "name": "Rootfoot", "socket": "LEG", "rarity": 1,
     "desc": "Toes that burrow in and drink.\n+100 HP, attacks 0.05s slower.\nHeals 6 HP every 3s.",
     "hp": 100.0, "atk": 0.0, "interval": 0.05, "defense": 0.0, "crit": 0.0,
     "tags": ["spore", "support"],
     "ability": ("AbRegen", {"interval": 3.0, "amount": 6.0}),
     "art": _art("tread", "spore"), "body": None},

    {"id": "alpha_paw", "name": "Alpha Paw", "socket": "LEG", "rarity": 2,
     "desc": "The paw of one who leads the pack.\n+40 HP, +2 ATK.\nWhen an ally dies: +4 ATK and heal 50 HP.",
     "hp": 40.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["beast", "support"],
     "ability": ("AbVengeance", {"atk_bonus": 4.0, "heal": 50.0}),
     "art": _art("paw", "beast"), "body": None},

    {"id": "phantom_stride", "name": "Phantom Stride", "socket": "LEG", "rarity": 2,
     "desc": "A leg that is never quite where it looks.\n+16% crit, attacks 0.25s faster.\n35% chance to dodge a hit.",
     "hp": 0.0, "atk": 0.0, "interval": -0.25, "defense": 0.0, "crit": 0.16,
     "tags": ["shadow", "swift"],
     "ability": ("AbDodge", {"chance": 0.35}),
     "art": _art("raptor", "shadow"), "body": None},

    {"id": "juggernaut_tread", "name": "Juggernaut Tread", "socket": "LEG", "rarity": 2,
     "desc": "An armoured crawler limb.\n+90 HP, +1 DEF, attacks 0.15s slower.\nOnce, below 50% HP: attack interval x0.6.",
     "hp": 90.0, "atk": 0.0, "interval": 0.15, "defense": 1.0, "crit": 0.0,
     "tags": ["armor", "brute"],
     "ability": ("AbBerserk", {"threshold": 0.5, "interval_mult": 0.6}),
     "art": _art("tread", "armor"), "body": None},

    # =====================================================================
    # TAIL (12 non-ultra: 6 common, 4 uncommon, 2 rare) + 1 ultra
    # =====================================================================
    {"id": "scorpion_tail", "name": "Scorpion Tail", "socket": "TAIL", "rarity": 2, "existing": True,
     "desc": "A venomous stinger.\n+9% crit.\nHits add a venom stack (1 dmg/s, 5s, max 4).",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.09,
     "tags": ["venom", "insect"],
     "ability": ("AbVenom", {"stacks_per_hit": 1, "damage_per_second": 1.0, "duration": 5.0, "max_stacks": 4}),
     "art": _art("stinger", "venom"), "body": None},

    {"id": "whip_tail", "name": "Whip Tail", "socket": "TAIL", "rarity": 0,
     "desc": "A long, lashing counterweight.\n-20 HP, attacks 0.25s faster.",
     "hp": -20.0, "atk": 0.0, "interval": -0.25, "defense": 0.0, "crit": 0.0,
     "tags": ["swift", "beast"],
     "ability": None,
     "art": _art("whip", "swift"), "body": None},

    {"id": "ice_mace_tail", "name": "Ice Mace Tail", "socket": "TAIL", "rarity": 0,
     "desc": "A frozen knob on a thick tail.\n+60 HP, +1.5 ATK, attacks 0.1s slower.",
     "hp": 60.0, "atk": 1.5, "interval": 0.1, "defense": 0.0, "crit": 0.0,
     "tags": ["frost", "brute"],
     "ability": None,
     "art": _art("club", "frost"), "body": None},

    {"id": "seedpod_rattle", "name": "Seedpod Rattle", "socket": "TAIL", "rarity": 0,
     "desc": "Shakes loose a cloud of nourishing spores.\n+80 HP.\nBattle start: every ally gains +80 HP.",
     "hp": 80.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["support", "spore"],
     "ability": ("AbWarCry", {"atk_bonus": 0.0, "def_bonus": 0.0, "hp_bonus": 80.0}),
     "art": _art("rattle", "support", "#f08cc0"), "body": None},

    {"id": "fin_fan", "name": "Fin Fan", "socket": "TAIL", "rarity": 0,
     "desc": "A broad tail fin that stirs healing mist.\n+40 HP.\nEvery 6s, heals the most wounded ally for 8 HP.",
     "hp": 40.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["aquatic", "support"],
     "ability": ("AbMend", {"interval": 6.0, "amount": 8.0}),
     "art": _art("fan", "aquatic", "#c8f0b0"), "body": None},

    {"id": "grudge_flame", "name": "Grudge Flame", "socket": "TAIL", "rarity": 0,
     "desc": "A tail-tip flame that feeds on loss.\n+1.5 ATK.\nWhen an ally dies: +2 ATK and heal 20 HP.",
     "hp": 0.0, "atk": 1.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["fire", "shadow"],
     "ability": ("AbVengeance", {"atk_bonus": 2.0, "heal": 20.0}),
     "art": _art("flame", "fire", "#c83cff"), "body": None},

    {"id": "needle_barb", "name": "Needle Barb", "socket": "TAIL", "rarity": 0,
     "desc": "A thin barb with a bitter sting.\n+0.5 ATK.\nHits apply venom (1 dmg/s, 3s, does not stack).",
     "hp": 0.0, "atk": 0.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["venom", "insect"],
     "ability": ("AbVenom", {"stacks_per_hit": 1, "damage_per_second": 1.0, "duration": 3.0, "max_stacks": 1}),
     "art": _art("stinger", "venom"), "body": None},

    {"id": "prism_fan", "name": "Prism Fan", "socket": "TAIL", "rarity": 1,
     "desc": "A fan of mirrored shards.\n+60 HP.\n35% chance to reflect 9 damage when hit.",
     "hp": 60.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["crystal", "support"],
     "ability": ("AbReflect", {"chance": 0.35, "damage": 9.0}),
     "art": _art("fan", "crystal"), "body": None},

    {"id": "lamprey_tail", "name": "Lamprey Tail", "socket": "TAIL", "rarity": 1,
     "desc": "A second mouth on the end of the tail.\n+1.5 ATK.\nHeals 28% of damage dealt.",
     "hp": 0.0, "atk": 1.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["parasite", "aquatic"],
     "ability": ("AbLifesteal", {"fraction": 0.28}),
     "art": _art("whip", "parasite"), "body": None},

    {"id": "flail_tail", "name": "Flail Tail", "socket": "TAIL", "rarity": 1,
     "desc": "A spiked ball of bone on a living chain.\n+2 ATK.\nEvery 4th attack strikes twice.",
     "hp": 0.0, "atk": 2.0, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["brute", "bone"],
     "ability": ("AbDoubleStrike", {"every_n": 4, "extra_strikes": 1}),
     "art": _art("club", "brute"), "body": None},

    {"id": "brimstone_tail", "name": "Brimstone Tail", "socket": "TAIL", "rarity": 1,
     "desc": "A sulphurous flame that eats through armour.\n+0.5 ATK.\nHits strip 1 DEF from the target (max 4).",
     "hp": 0.0, "atk": 0.5, "interval": 0.0, "defense": 0.0, "crit": 0.0,
     "tags": ["fire", "venom"],
     "ability": ("AbCorrode", {"def_per_hit": 1.0, "max_total": 4.0}),
     "art": _art("flame", "fire", "#a6e03c"), "body": None},

    {"id": "lightning_rod_tail", "name": "Lightning Rod Tail", "socket": "TAIL", "rarity": 2,
     "desc": "A forked tail that calls down sparks.\n+12% crit.\nEvery 3s, 12 damage to the enemy with the lowest HP, ignoring DEF.",
     "hp": 0.0, "atk": 0.0, "interval": 0.0, "defense": 0.0, "crit": 0.12,
     "tags": ["electric", "crystal"],
     "ability": ("AbSnipe", {"interval": 3.0, "damage": 12.0}),
     "art": _art("rattle", "electric", "#c8b0ff"), "body": None},

    {"id": "long_night_tail", "name": "Tail of the Long Night", "socket": "TAIL", "rarity": 3,
     "desc": "The body drains to living shadow.\n-50 HP, +4 ATK, +20% crit.\nEvery 2.5s, 13 damage to the enemy with the lowest HP, ignoring DEF.",
     "hp": -50.0, "atk": 4.0, "interval": 0.0, "defense": 0.0, "crit": 0.2,
     "tags": ["shadow", "swift"],
     "ability": ("AbSnipe", {"interval": 2.5, "damage": 13.0}),
     "art": {"motif": "whip", "colors": ["#050308", "#1c1430", "#4a3a78"], "accent": "#ff3df0"},
     "body": {"style": "shadow", "tint": "#ffffff", "scale": 1.1, "aura": None}},
]


# -------------------------------------------------------------------------
# Self-check (python tools/mutation_table.py)
# -------------------------------------------------------------------------

SOCKETS = ["HEAD", "TORSO", "BACK", "ARM", "LEG", "TAIL"]
RARITY_NAMES = ["common", "uncommon", "rare", "ultra"]
NON_ULTRA_COUNTS = {"HEAD": 16, "TORSO": 14, "BACK": 14, "ARM": 20, "LEG": 16, "TAIL": 12}
ULTRA_COUNTS = {"HEAD": 2, "TORSO": 2, "BACK": 2, "ARM": 1, "LEG": 0, "TAIL": 1}
MOTIFS = {
    "HEAD": {"maw", "horns", "eyes", "crest", "antennae", "beak", "skull", "tentacles", "halo"},
    "TORSO": {"plates", "ribs", "core", "scales", "fur", "crystal"},
    "BACK": {"sacs", "wings", "spikes", "shell", "fins", "tubes"},
    "ARM": {"blade", "claw", "tentacle", "pincer", "club", "cannon"},
    "LEG": {"raptor", "hoof", "spider", "spring", "paw", "tread"},
    "TAIL": {"stinger", "whip", "club", "fan", "rattle", "flame"},
}
BODY_STYLES = {"crystal", "shadow", "molten", "slime", "gold", "skeletal", "void", "angelic"}
ARCHETYPE_TAGS = ["venom", "insect", "bone", "armor", "spore", "fire", "frost", "brute",
                  "swift", "support", "beast", "aquatic", "crystal", "shadow", "electric",
                  "parasite"]
ULTRA_ONLY = {"AbTitan", "AbPhase", "AbSwarm"}
ABILITY_PARAMS = {
    "AbVenom": {"stacks_per_hit", "damage_per_second", "duration", "max_stacks"},
    "AbDodge": {"chance"},
    "AbDoubleStrike": {"every_n", "extra_strikes"},
    "AbLifesteal": {"fraction"},
    "AbReflect": {"chance", "damage"},
    "AbSporePulse": {"interval", "damage"},
    "AbRegen": {"interval", "amount"},
    "AbMend": {"interval", "amount"},
    "AbThorns": {"damage"},
    "AbShield": {"amount"},
    "AbExecute": {"threshold", "bonus"},
    "AbCleave": {"fraction"},
    "AbStun": {"chance", "delay"},
    "AbRage": {"atk_per_stack", "max_stacks"},
    "AbBerserk": {"threshold", "interval_mult"},
    "AbWarCry": {"atk_bonus", "def_bonus", "hp_bonus"},
    "AbVengeance": {"atk_bonus", "heal"},
    "AbSnipe": {"interval", "damage"},
    "AbChill": {"slow_per_hit", "max_slow"},
    "AbCorrode": {"def_per_hit", "max_total"},
    "AbSecondWind": {"heal_fraction"},
    "AbAmbush": {"damage"},
    "AbChain": {"chance", "damage"},
    "AbMomentum": {"crit_per_hit", "max_crit"},
    "AbBurn": {"fraction", "duration"},
    "AbTitan": {"damage_reduction", "stomp_interval", "stomp_damage"},
    "AbPhase": {"chance", "counter"},
    "AbSwarm": {"interval", "damage", "heal"},
}
REQUIRED_KEYS = {"id", "name", "socket", "rarity", "desc", "hp", "atk", "interval",
                 "defense", "crit", "tags", "ability", "art", "body"}
EXISTING_IDS = {"leech_maw", "bone_plating", "spore_sacs", "mantis_arm", "raptor_leg",
                "scorpion_tail"}


def _is_hex(s):
    return (isinstance(s, str) and len(s) == 7 and s[0] == "#"
            and all(c in "0123456789abcdefABCDEF" for c in s[1:]))


def _sign(v):
    return "+" if v > 0 else "-"


def _expected_stat_text(m):
    """Substrings the desc must contain so the tooltip matches the numbers."""
    out = []
    if m["hp"] != 0:
        out.append("%s%d HP" % (_sign(m["hp"]), int(abs(m["hp"]))))
    if m["atk"] != 0:
        out.append("%s%g ATK" % (_sign(m["atk"]), abs(m["atk"])))
    if m["interval"] != 0:
        out.append("%gs %s" % (abs(m["interval"]), "faster" if m["interval"] < 0 else "slower"))
    if m["defense"] != 0:
        out.append("%s%g DEF" % (_sign(m["defense"]), abs(m["defense"])))
    if m["crit"] != 0:
        out.append("%s%d%% crit" % (_sign(m["crit"]), int(round(abs(m["crit"]) * 100))))
    return out


def check():
    """Validate MUTATIONS against the stage-4 contract. Returns a list of problems."""
    problems = []

    def bad(mid, msg):
        problems.append("%s: %s" % (mid, msg))

    if len(MUTATIONS) != 100:
        problems.append("expected 100 entries, found %d" % len(MUTATIONS))

    ids = [m.get("id") for m in MUTATIONS]
    for dup in sorted({i for i in ids if ids.count(i) > 1}):
        problems.append("duplicate id: %s" % dup)
    names = [m.get("name") for m in MUTATIONS]
    for dup in sorted({n for n in names if names.count(n) > 1}):
        problems.append("duplicate name: %s" % dup)

    non_ultra = dict((s, 0) for s in SOCKETS)
    ultra = dict((s, 0) for s in SOCKETS)
    styles = []
    usage = dict((c, 0) for c in ABILITY_PARAMS)
    tag_count = dict((t, 0) for t in ARCHETYPE_TAGS)
    tag_sockets = dict((t, set()) for t in ARCHETYPE_TAGS)
    combos = {}

    for m in MUTATIONS:
        mid = m.get("id", "<no id>")
        missing = REQUIRED_KEYS - set(m)
        if missing:
            bad(mid, "missing keys %s" % sorted(missing))
            continue
        if not (isinstance(mid, str) and mid and mid == mid.lower()
                and all(c.isalnum() or c == "_" for c in mid)):
            bad(mid, "id is not snake_case")
        if m["socket"] not in SOCKETS:
            bad(mid, "bad socket %r" % (m["socket"],))
            continue
        if m["rarity"] not in (0, 1, 2, 3):
            bad(mid, "bad rarity %r" % (m["rarity"],))
            continue
        is_ultra = m["rarity"] == 3
        (ultra if is_ultra else non_ultra)[m["socket"]] += 1

        # stats
        for k in ("hp", "atk", "interval", "defense", "crit"):
            if not isinstance(m[k], float):
                bad(mid, "%s must be a float" % k)
        if m["defense"] > 3.0:
            bad(mid, "defense above +3")
        if not (-0.25 <= m["interval"] <= 0.3):
            bad(mid, "interval mod outside [-0.25, 0.3]")

        # desc
        desc = m["desc"]
        if desc.count("\n") > 3:
            bad(mid, "desc longer than 4 lines")
        for text in _expected_stat_text(m):
            if text not in desc:
                bad(mid, "desc does not mention %r" % text)

        # ability
        ab = m["ability"]
        if ab is not None:
            cls, params = ab
            if cls not in ABILITY_PARAMS:
                bad(mid, "unknown ability class %s" % cls)
            else:
                usage[cls] += 1
                for p in params:
                    if p not in ABILITY_PARAMS[cls]:
                        bad(mid, "param %s is not valid for %s" % (p, cls))
                if cls in ULTRA_ONLY and not is_ultra:
                    bad(mid, "%s is ULTRA-only" % cls)

        # tags
        if not m["tags"]:
            bad(mid, "no tags")
        for t in m["tags"]:
            if t in tag_count:
                tag_count[t] += 1
                tag_sockets[t].add(m["socket"])

        # art
        art = m["art"]
        if art.get("motif") not in MOTIFS[m["socket"]]:
            bad(mid, "motif %r is not valid for %s" % (art.get("motif"), m["socket"]))
        cols = art.get("colors", [])
        if len(cols) != 3 or not all(_is_hex(c) for c in cols):
            bad(mid, "art.colors must be 3 hex strings")
        if not _is_hex(art.get("accent")):
            bad(mid, "art.accent must be a hex string")

        # body
        body = m["body"]
        if is_ultra:
            if not isinstance(body, dict):
                bad(mid, "ultra needs a body dict")
            else:
                if body.get("style") not in BODY_STYLES:
                    bad(mid, "bad body style %r" % (body.get("style"),))
                styles.append(body.get("style"))
                if not _is_hex(body.get("tint")):
                    bad(mid, "body.tint must be a hex string")
                if not (1.0 <= body.get("scale", 0.0) <= 1.35):
                    bad(mid, "body.scale outside 1.0-1.35")
                if "aura" not in body or not (body["aura"] is None or isinstance(body["aura"], str)):
                    bad(mid, "body.aura must be a pixelfx id string or None")
        elif body is not None:
            bad(mid, "only ultras may have a body")

        # existing flag
        if bool(m.get("existing")) != (mid in EXISTING_IDS):
            bad(mid, "'existing' flag does not match the 6 shipped mutations")

        # distinct stat/ability combination
        key = (m["socket"], m["hp"], m["atk"], m["interval"], m["defense"], m["crit"],
               ab[0] if ab else None,
               tuple(sorted(ab[1].items())) if ab else None)
        if key in combos:
            bad(mid, "same socket, stats and ability as %s" % combos[key])
        combos[key] = mid

    for s in SOCKETS:
        if non_ultra[s] != NON_ULTRA_COUNTS[s]:
            problems.append("%s: %d non-ultra, expected %d" % (s, non_ultra[s], NON_ULTRA_COUNTS[s]))
        if ultra[s] != ULTRA_COUNTS[s]:
            problems.append("%s: %d ultra, expected %d" % (s, ultra[s], ULTRA_COUNTS[s]))
    if len(styles) != 8 or len(set(styles)) != len(styles):
        problems.append("ultras must use 8 distinct body styles, got %s" % sorted(styles))
    for cls in sorted(usage):
        need = 1 if cls in ULTRA_ONLY else 2
        if usage[cls] < need:
            problems.append("%s used %d time(s), need at least %d" % (cls, usage[cls], need))
    for t in ARCHETYPE_TAGS:
        if tag_count[t] < 8:
            problems.append("tag %s on %d mutations, need at least 8" % (t, tag_count[t]))
        if len(tag_sockets[t]) < 3:
            problems.append("tag %s only on sockets %s" % (t, sorted(tag_sockets[t])))

    return problems, usage, tag_count


def _summary(usage, tag_count):
    print("rarity x socket")
    print("%-9s" % "" + "".join("%7s" % s for s in SOCKETS) + "%7s" % "total")
    for r in range(4):
        row = [sum(1 for m in MUTATIONS if m["rarity"] == r and m["socket"] == s) for s in SOCKETS]
        print("%-9s" % RARITY_NAMES[r] + "".join("%7d" % n for n in row) + "%7d" % sum(row))
    totals = [sum(1 for m in MUTATIONS if m["socket"] == s) for s in SOCKETS]
    print("%-9s" % "total" + "".join("%7d" % n for n in totals) + "%7d" % sum(totals))
    commons = [m for m in MUTATIONS if m["rarity"] == 0]
    plain = sum(1 for m in commons if m["ability"] is None)
    print("\ncommons without an ability: %d of %d" % (plain, len(commons)))
    print("\nability usage")
    for cls in sorted(usage, key=lambda c: (-usage[c], c)):
        print("  %-15s %d" % (cls, usage[cls]))
    print("\narchetype tags")
    for t in ARCHETYPE_TAGS:
        print("  %-9s %d" % (t, tag_count[t]))
    print("\nultras")
    for m in MUTATIONS:
        if m["rarity"] == 3:
            print("  %-26s %-6s %-9s %s" % (m["id"], m["socket"], m["body"]["style"], m["ability"][0]))


if __name__ == "__main__":
    _problems, _usage, _tag_count = check()
    _summary(_usage, _tag_count)
    assert not _problems, "mutation table problems:\n  " + "\n  ".join(_problems)
    print("\nOK: %d mutations pass the stage-4 contract checks." % len(MUTATIONS))
