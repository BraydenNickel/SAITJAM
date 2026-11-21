"""MUTANT LAB signature fusions (design/fusion-contract.md section 4).

Pure data, stdlib only, importable: ``from signature_table import SIGNATURES``.
Exactly 26 entries. Each is a pair of DIFFERENT base mutation ids of the same socket
(``a`` < ``b``, sorted) that fuses into a named part with a bespoke sprite and keeps
100% of the summed stats instead of 75%. These are the Codex trophies.

Design rules used:
- Both parents carry an ability and the two abilities visibly combine.
- Spread: HEAD 5, TORSO 4, BACK 4, ARM 5, LEG 4, TAIL 4.
- At most 6 entries involve a RARE parent, at most 2 involve an ULTRA, and every
  entry has at least one COMMON or UNCOMMON parent.
- No base mutation appears in more than 2 signatures.
- Colours run dark -> light and blend the parents' palettes.

Run ``python tools/signature_table.py`` for the self-check and a summary.
"""

SIGNATURES = [
    # =====================================================================
    # HEAD (5)
    # =====================================================================
    # AbChill + AbExecute: slow the prey down, then finish it.
    {"a": "frost_crest", "b": "snapping_beak",
     "name": "Winterkill", "desc": "It waits for the cold to do most of the work.",
     "art": {"motif": "beak", "colors": ["#1c2c3a", "#5a86a8", "#d8e4d8"], "accent": "#ffffff",
             "flourish": "spikes"}},

    # AbLifesteal + AbVenom: poison the blood, then drink it back.
    {"a": "leech_maw", "b": "venom_fangs",
     "name": "Bloodrot Maw", "desc": "It sours the blood first, then drinks every drop.",
     "art": {"motif": "maw", "colors": ["#2a2014", "#8c2a3c", "#a6e03c"], "accent": "#b040e0",
             "flourish": "drips"}},

    # AbMomentum + AbSnipe: crit ramps on every hit while the weakest is picked off.
    {"a": "compound_eyes", "b": "stalker_eyes",
     "name": "Thousand Stare", "desc": "Every facet has already chosen who falls next.",
     "art": {"motif": "eyes", "colors": ["#16122a", "#4c4a3c", "#c2c85a"], "accent": "#c83cff",
             "flourish": "eyes"}},

    # AbStun + AbChain: the jolt that staggers one enemy jumps to the next.
    {"a": "jelly_crown", "b": "static_antennae",
     "name": "Thunderbloom", "desc": "A drifting crown of tendrils that hums before it strikes.",
     "art": {"motif": "tentacles", "colors": ["#0c2a4a", "#1f8f9a", "#fff25a"], "accent": "#5ad8ff",
             "flourish": "sparks"}},

    # TROPHY (ULTRA). AbSwarm + AbLifesteal: the swarm and the bite both feed the host.
    {"a": "amber_hive_crown", "b": "leech_maw",
     "name": "Honeymaw", "desc": "The hive has a mouth now, and the mouth is never full.",
     "art": {"motif": "maw", "colors": ["#4a1a10", "#c8601e", "#ffd27a"], "accent": "#e05a78",
             "flourish": "crown"}},

    # =====================================================================
    # TORSO (4)
    # =====================================================================
    # AbReflect + AbShield: a barrier that hits back while it holds.
    {"a": "bone_plating", "b": "crystal_lattice",
     "name": "Mirrorbone", "desc": "Polished plates that hand every blow back to its owner.",
     "art": {"motif": "plates", "colors": ["#3c305a", "#a898c0", "#f0e8f4"], "accent": "#7ff8ff",
             "flourish": "runes"}},

    # AbBerserk + AbThorns: the closer it is to death, the worse it is to hit.
    {"a": "overgrown_heart", "b": "rib_spurs",
     "name": "Thornheart", "desc": "A caged heart that beats harder the more you hurt it.",
     "art": {"motif": "ribs", "colors": ["#3c1414", "#a0503c", "#f4ecd8"], "accent": "#ff5a4a",
             "flourish": "spikes"}},

    # AbChain + AbBurn: fast hits spread fire and arcs across the whole enemy line.
    {"a": "dynamo_core", "b": "ember_core",
     "name": "Plasma Heart", "desc": "Coal and current, wound together until they glow white.",
     "art": {"motif": "core", "colors": ["#4a2606", "#d8841a", "#fff25a"], "accent": "#5ad8ff",
             "flourish": "sparks"}},

    # AbSecondWind + AbBerserk: it dies, gets back up at low HP and is instantly frenzied.
    {"a": "mycelium_coat", "b": "overgrown_heart",
     "name": "Graveheart", "desc": "It stops once, then starts again much faster.",
     "art": {"motif": "core", "colors": ["#42162a", "#9a3452", "#f08cc0"], "accent": "#e8f07a",
             "flourish": "glow"}},

    # =====================================================================
    # BACK (4)
    # =====================================================================
    # AbRage + AbThorns: every hit taken hurts the attacker and feeds the next swing.
    {"a": "adrenal_tubes", "b": "quill_ridge",
     "name": "Wrathquills", "desc": "Each quill is wired straight into the temper.",
     "art": {"motif": "spikes", "colors": ["#3a1a12", "#8c452a", "#d88a58"], "accent": "#f0d8b0",
             "flourish": "spikes"}},

    # AbCorrode + AbSporePulse: melt the armour off, then gas everyone.
    {"a": "acid_sprayer", "b": "spore_sacs",
     "name": "Miasma Sacs", "desc": "The cloud eats metal first and lungs second.",
     "art": {"motif": "sacs", "colors": ["#4a1838", "#4f8a22", "#a6e03c"], "accent": "#f08cc0",
             "flourish": "drips"}},

    # AbMend + AbSporePulse: one breath heals the pack and chokes the enemy.
    {"a": "nectar_sacs", "b": "spore_sacs",
     "name": "Bittersweet", "desc": "Sweet for the pack, bitter for everyone else.",
     "art": {"motif": "sacs", "colors": ["#2a4a2a", "#a83a78", "#f0b8d0"], "accent": "#fff6c8",
             "flourish": "glow"}},

    # TROPHY (ULTRA). AbDodge + AbPhase: two separate chances that the hit never lands.
    {"a": "snowmoth_wings", "b": "void_moth_wings",
     "name": "Eclipse Moth", "desc": "Frost falls from wings that are not really there.",
     "art": {"motif": "wings", "colors": ["#07041a", "#2a3a90", "#bfe8ff"], "accent": "#f0f0ff",
             "flourish": "eyes"}},

    # =====================================================================
    # ARM (5)
    # =====================================================================
    # AbDoubleStrike + AbMomentum: extra strikes build crit twice as fast.
    {"a": "mantis_arm", "b": "quartz_knuckle",
     "name": "Facet Scythe", "desc": "Every cut hones the edge a little keener.",
     "art": {"motif": "blade", "colors": ["#2c2640", "#7a6ab0", "#d4d09a"], "accent": "#7ff8ff",
             "flourish": "glow"}},

    # AbBurn + AbCorrode: strip the armour and set what is underneath on fire.
    {"a": "cinder_fist", "b": "mold_tendril",
     "name": "Blightbrand", "desc": "Rot that smoulders, and embers that spread like mould.",
     "art": {"motif": "tentacle", "colors": ["#521a22", "#b8452c", "#f8a070"], "accent": "#a6e03c",
             "flourish": "flames"}},

    # AbCleave + AbStun: wide swings from an arm that pins the target in place.
    {"a": "butcher_blade", "b": "squid_arm",
     "name": "Riptide Cleaver", "desc": "It holds you still for the part that matters.",
     "art": {"motif": "blade", "colors": ["#1c1c30", "#7a3c48", "#7ac8cc"], "accent": "#c83cff",
             "flourish": "drips"}},

    # AbChain + AbStun: the bolt that jumps and the bolt that staggers, in one barrel.
    {"a": "arc_cannon", "b": "spark_prod",
     "name": "Galvanic Lance", "desc": "One limb, two terminals, and nowhere safe to stand.",
     "art": {"motif": "cannon", "colors": ["#33285a", "#d8b800", "#fff8a0"], "accent": "#5ad8ff",
             "flourish": "sparks"}},

    # AbDoubleStrike + AbDoubleStrike: every 2nd and every 3rd attack both strike twice.
    {"a": "flicker_blade", "b": "mantis_arm",
     "name": "Thresher", "desc": "You hear the second cut before you feel the first.",
     "art": {"motif": "blade", "colors": ["#1c3824", "#479a58", "#a8e098"], "accent": "#fff07a",
             "flourish": "spikes"}},

    # =====================================================================
    # LEG (4)
    # =====================================================================
    # AbDodge + AbAmbush: strike first, then be somewhere else.
    {"a": "raptor_leg", "b": "stalker_paw",
     "name": "Nightpounce", "desc": "It lands before the shadow does.",
     "art": {"motif": "raptor", "colors": ["#1c1414", "#5a4038", "#b08a70"], "accent": "#c83cff",
             "flourish": "glow"}},

    # AbShield + AbRage: the shield soaks the hits that build the charge.
    {"a": "rime_hoof", "b": "stampede_hoof",
     "name": "Avalanche Hoof", "desc": "It starts slow, and then the whole slope is moving.",
     "art": {"motif": "hoof", "colors": ["#2a2238", "#7a5f7c", "#cce4f4"], "accent": "#ffffff",
             "flourish": "spikes"}},

    # AbStun + AbVenom: the jolt holds them still while the poison works.
    {"a": "capacitor_heel", "b": "widow_leg",
     "name": "Jolt Widow", "desc": "The sting numbs, and then the numbness burns.",
     "art": {"motif": "spider", "colors": ["#2a3608", "#8fa010", "#f0f04a"], "accent": "#e8502a",
             "flourish": "sparks"}},

    # AbRegen + AbRegen: two healing pulses on different timers that never let up.
    {"a": "marsh_hopper", "b": "rootfoot",
     "name": "Mangrove Stride", "desc": "Wherever it stands, it is already drinking.",
     "art": {"motif": "tread", "colors": ["#1c2440", "#64558a", "#9ad0cc"], "accent": "#e8f07a",
             "flourish": "drips"}},

    # =====================================================================
    # TAIL (4)
    # =====================================================================
    # AbMend + AbWarCry: toughen the whole pack at the start, then keep it standing.
    {"a": "fin_fan", "b": "seedpod_rattle",
     "name": "Rainmaker", "desc": "One shake and the whole pack stands a little taller.",
     "art": {"motif": "fan", "colors": ["#143a3c", "#3f8f82", "#94e0c4"], "accent": "#f08cc0",
             "flourish": "glow"}},

    # AbCorrode + AbVenom: burn through the plating so the venom reaches the meat.
    {"a": "brimstone_tail", "b": "scorpion_tail",
     "name": "Sulphur Sting", "desc": "The armour goes first, and the venom follows it in.",
     "art": {"motif": "stinger", "colors": ["#3c2a0e", "#8c6d20", "#d8c83c"], "accent": "#b040e0",
             "flourish": "flames"}},

    # AbDoubleStrike + AbVengeance: the last one standing swings twice as often and far harder.
    {"a": "flail_tail", "b": "grudge_flame",
     "name": "Mourning Star", "desc": "It burns brighter for every friend it has lost.",
     "art": {"motif": "club", "colors": ["#4a1710", "#aa4024", "#ec8d48"], "accent": "#c83cff",
             "flourish": "flames"}},

    # AbSnipe + AbReflect: punishes whoever attacks it and whoever is weakest.
    {"a": "lightning_rod_tail", "b": "prism_fan",
     "name": "Stormglass", "desc": "Lightning goes in one side and comes out aimed.",
     "art": {"motif": "fan", "colors": ["#2e2244", "#a58fd0", "#fff6a0"], "accent": "#5ad8ff",
             "flourish": "runes"}},
]


# -------------------------------------------------------------------------
# Self-check (python tools/signature_table.py)
# -------------------------------------------------------------------------

EXPECTED_COUNT = 26
SOCKET_SPREAD = {"HEAD": 5, "TORSO": 4, "BACK": 4, "ARM": 5, "LEG": 4, "TAIL": 4}
FLOURISHES = {"glow", "spikes", "eyes", "crown", "flames", "runes", "drips", "sparks"}
ORIGINAL_IDS = {"mantis_arm", "bone_plating", "leech_maw", "spore_sacs", "raptor_leg",
                "scorpion_tail"}
MAX_RARE_ENTRIES = 6       # entries with a RARE (2) parent
MAX_ULTRA_ENTRIES = 2      # entries with an ULTRA (3) parent
MAX_USES_PER_BASE = 2      # signatures one base mutation may appear in
MIN_ORIGINAL_ENTRIES = 4   # entries that use one of the 6 original mutations
REQUIRED_KEYS = {"a", "b", "name", "desc", "art"}
ART_KEYS = {"motif", "colors", "accent", "flourish"}
RARITY_NAMES = ["common", "uncommon", "rare", "ultra"]


def _is_hex(s):
    return (isinstance(s, str) and len(s) == 7 and s[0] == "#"
            and all(c in "0123456789abcdefABCDEF" for c in s[1:]))


def check(mutations, motifs, archetype_tags):
    """Validate SIGNATURES against the fusion contract. Returns (problems, stats)."""
    problems = []
    by_id = dict((m["id"], m) for m in mutations)
    base_names = set(m["name"].lower() for m in mutations)

    if len(SIGNATURES) != EXPECTED_COUNT:
        problems.append("expected %d entries, found %d" % (EXPECTED_COUNT, len(SIGNATURES)))

    spread = dict((s, 0) for s in SOCKET_SPREAD)
    uses = {}
    seen_pairs = set()
    seen_names = set()
    tags_hit = set()
    rare_entries = []
    ultra_entries = []
    original_entries = []
    rows = []

    for i, sig in enumerate(SIGNATURES):
        label = "#%d %s" % (i, sig.get("name", "<no name>"))

        def bad(msg, label=label):
            problems.append("%s: %s" % (label, msg))

        missing = REQUIRED_KEYS - set(sig)
        if missing:
            bad("missing keys %s" % sorted(missing))
            continue
        a, b = sig["a"], sig["b"]

        # pair
        if a == b:
            bad("a and b are the same id (%s)" % a)
        elif not a < b:
            bad("ids are not sorted: %s must come before %s" % (b, a))
        unknown = [x for x in (a, b) if x not in by_id]
        if unknown:
            bad("unknown base id(s) %s" % unknown)
            continue
        ma, mb = by_id[a], by_id[b]
        if ma["socket"] != mb["socket"]:
            bad("sockets differ: %s is %s, %s is %s" % (a, ma["socket"], b, mb["socket"]))
            continue
        socket = ma["socket"]
        key = "+".join(sorted((a, b)))
        if key in seen_pairs:
            bad("pair %s is repeated" % key)
        seen_pairs.add(key)
        if socket in spread:
            spread[socket] += 1
        for x in (a, b):
            uses[x] = uses.get(x, 0) + 1

        # abilities: the contract wants a visible combination
        if ma["ability"] is None and mb["ability"] is None:
            bad("both parents are ability-less")

        # name and desc
        name = sig["name"]
        if not (isinstance(name, str) and name.strip() == name and 1 <= len(name.split()) <= 2):
            bad("name must be 1-2 words")
        elif name.lower() in seen_names:
            bad("name is used by another signature")
        elif name.lower() in base_names:
            bad("name equals a base mutation name")
        if isinstance(name, str):
            seen_names.add(name.lower())
        desc = sig["desc"]
        if not (isinstance(desc, str) and desc.strip() and "\n" not in desc):
            bad("desc must be one line")

        # art
        art = sig["art"]
        if not isinstance(art, dict) or set(art) != ART_KEYS:
            bad("art must have exactly the keys %s" % sorted(ART_KEYS))
        else:
            if art["motif"] not in motifs[socket]:
                bad("motif %r is not valid for %s" % (art["motif"], socket))
            cols = art["colors"]
            if not (isinstance(cols, list) and len(cols) == 3 and all(_is_hex(c) for c in cols)):
                bad("art.colors must be 3 hex strings")
            if not _is_hex(art["accent"]):
                bad("art.accent must be a hex string")
            if art["flourish"] not in FLOURISHES:
                bad("flourish %r is not in %s" % (art["flourish"], sorted(FLOURISHES)))

        # discoverability
        rarities = (ma["rarity"], mb["rarity"])
        if 3 in rarities:
            ultra_entries.append(name)
        if 2 in rarities:
            rare_entries.append(name)
        if min(rarities) > 1:
            bad("needs at least one COMMON or UNCOMMON parent")
        if a in ORIGINAL_IDS or b in ORIGINAL_IDS:
            original_entries.append(name)

        for t in ma["tags"] + mb["tags"]:
            if t in archetype_tags:
                tags_hit.add(t)

        rows.append((socket, a, b, name,
                     ma["ability"][0] if ma["ability"] else "-",
                     mb["ability"][0] if mb["ability"] else "-",
                     RARITY_NAMES[ma["rarity"]], RARITY_NAMES[mb["rarity"]],
                     art.get("flourish", "?") if isinstance(art, dict) else "?"))

    for s in sorted(SOCKET_SPREAD):
        if spread[s] != SOCKET_SPREAD[s]:
            problems.append("%s: %d signatures, expected %d" % (s, spread[s], SOCKET_SPREAD[s]))
    for x in sorted(uses):
        if uses[x] > MAX_USES_PER_BASE:
            problems.append("%s appears in %d signatures, max %d" % (x, uses[x], MAX_USES_PER_BASE))
    if len(rare_entries) > MAX_RARE_ENTRIES:
        problems.append("%d entries need a RARE parent, max %d" % (len(rare_entries), MAX_RARE_ENTRIES))
    if len(ultra_entries) > MAX_ULTRA_ENTRIES:
        problems.append("%d entries involve an ULTRA, max %d" % (len(ultra_entries), MAX_ULTRA_ENTRIES))
    if len(original_entries) < MIN_ORIGINAL_ENTRIES:
        problems.append("only %d entries use an original mutation, need %d"
                        % (len(original_entries), MIN_ORIGINAL_ENTRIES))
    missing_tags = [t for t in archetype_tags if t not in tags_hit]
    if missing_tags:
        problems.append("archetype tags never covered: %s" % missing_tags)

    stats = {"rows": rows, "spread": spread, "rare": rare_entries, "ultra": ultra_entries,
             "original": original_entries, "tags": sorted(tags_hit), "uses": uses}
    return problems, stats


def _summary(stats):
    print("signature fusions")
    for socket, a, b, name, ab_a, ab_b, r_a, r_b, flourish in stats["rows"]:
        print("  %-5s %-16s %s (%s) + %s (%s)" % (socket, name, a, r_a, b, r_b))
        print("        %s + %s, flourish %s" % (ab_a, ab_b, flourish))
    print("\nsocket spread: " + ", ".join("%s %d" % (s, stats["spread"][s])
                                          for s in ["HEAD", "TORSO", "BACK", "ARM", "LEG", "TAIL"]))
    print("archetype tags covered (%d): %s" % (len(stats["tags"]), " ".join(stats["tags"])))
    print("need a RARE parent (%d): %s" % (len(stats["rare"]), ", ".join(stats["rare"])))
    print("involve an ULTRA (%d): %s" % (len(stats["ultra"]), ", ".join(stats["ultra"])))
    print("use an original mutation (%d): %s" % (len(stats["original"]), ", ".join(stats["original"])))
    twice = sorted(x for x in stats["uses"] if stats["uses"][x] == 2)
    print("base mutations used twice (%d): %s" % (len(twice), ", ".join(twice)))


if __name__ == "__main__":
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from mutation_table import ARCHETYPE_TAGS, MOTIFS, MUTATIONS

    _problems, _stats = check(MUTATIONS, MOTIFS, ARCHETYPE_TAGS)
    _summary(_stats)
    assert not _problems, "signature table problems:\n  " + "\n  ".join(_problems)
    print("\nOK: %d signature fusions pass the fusion contract checks." % len(SIGNATURES))
