#!/usr/bin/env python3
"""Signature-preserving retuner for the stage-4 balance pass (design/balance/stage4-balance.md, Pass 2).

Every mutation keeps the stat signature its designer gave it in
tools/balance/mutation_baseline.py (same signs, same dominant stat) and gets one
scale factor k:

    positive stats and the ability's magnitude   x k
    negative stats (drawbacks)                   x clamp(1 / k, 0.5, 1.5)

k is moved after every arena run so the piece's ladder score goes to 50 (worth
exactly its rarity's par, see run_sim.gd ARENA_PAR). The factors are kept in
tools/balance/retune_state.json. The stats line and the ability line of each
``desc`` are rebuilt from the numbers, so the table self-check keeps passing.

Usage (from the project root):
    python tools/balance/retune.py --init [K]           every k = K (default 1.3), rewrite the table
    python tools/balance/retune.py reports/arena.csv    one step from an arena CSV
    python tools/balance/retune.py --sync-only          only re-sync the 6 hand-made .tres
Afterwards: python tools/gen_mutations.py, then a headless --import
(tools/balance/retune_loop.sh does all of it). Stdlib only.
"""

import csv
import importlib.util
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TABLE = ROOT / "tools" / "mutation_table.py"
BASELINE = HERE / "mutation_baseline.py"
STATE = HERE / "retune_state.json"
MUT_DIR = ROOT / "src" / "data" / "mutations"

K_MIN, K_MAX = 0.15, 5.0
# Fraction of the (log) error corrected per step.
GAIN = 0.8
# Scores inside 50 +/- BAND are left alone.
BAND = 5.0
ULTRA = 3
# (quantum, low, high) per stat; HP has a wider range for ULTRA.
STAT_RULES = {"hp": (10.0, -120.0, 120.0), "atk": (0.5, -3.0, 6.0), "interval": (0.05, -0.25, 0.3),
              "defense": (1.0, -2.0, 3.0), "crit": (0.01, -0.1, 0.3)}
ULTRA_HP = (10.0, -200.0, 200.0)
# For interval, negative is the bonus.
STAT_KEYS = ("hp", "atk", "interval", "defense", "crit")
# Ability params scaled with k: name -> (quantum, cap). Abilities not listed keep their numbers.
ABILITY_SCALE = {
    "AbAmbush": {"damage": (1.0, 90.0)},
    "AbBurn": {"fraction": (0.001, 0.05)},
    "AbChain": {"damage": (1.0, 60.0)},
    "AbChill": {"slow_per_hit": (0.01, 0.3), "max_slow": (0.05, 1.5)},
    "AbCleave": {"fraction": (0.05, 1.0)},
    "AbDodge": {"chance": (0.01, 0.35)},
    "AbExecute": {"bonus": (1.0, 80.0)},
    "AbLifesteal": {"fraction": (0.01, 0.6)},
    "AbMend": {"amount": (1.0, 80.0)},
    "AbMomentum": {"max_crit": (0.02, 0.5)},
    "AbPhase": {"counter": (1.0, 60.0)},
    "AbRage": {"max_stacks": (1.0, 16.0)},
    "AbReflect": {"damage": (1.0, 40.0)},
    "AbRegen": {"amount": (1.0, 60.0)},
    "AbSecondWind": {"heal_fraction": (0.05, 0.8)},
    "AbShield": {"amount": (5.0, 400.0)},
    "AbSnipe": {"damage": (1.0, 60.0)},
    "AbSporePulse": {"damage": (1.0, 30.0)},
    "AbStun": {"chance": (0.01, 0.5)},
    "AbSwarm": {"damage": (1.0, 40.0), "heal": (1.0, 30.0)},
    "AbThorns": {"damage": (1.0, 30.0)},
    "AbTitan": {"stomp_damage": (1.0, 60.0)},
    "AbVengeance": {"heal": (5.0, 200.0), "atk_bonus": (0.5, 12.0)},
    "AbVenom": {"max_stacks": (1.0, 12.0)},
    "AbWarCry": {"hp_bonus": (10.0, 200.0), "atk_bonus": (1.0, 6.0)},
}
# Abilities the arena cannot see (they need a death or a nearly dead unit, and arena
# fights mostly end on the timer). Their pieces are not searched: they follow the
# median k of every other piece, so they keep the designer's relative numbers.
BLIND = {"AbSecondWind", "AbVengeance", "AbBerserk", "AbExecute"}
EXISTING = ["mantis_arm", "bone_plating", "leech_maw", "spore_sacs", "raptor_leg", "scorpion_tail"]
ORDINAL = {2: "2nd", 3: "3rd", 4: "4th", 5: "5th", 6: "6th"}


def load_table(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MUTATIONS


def quant(v, q):
    return round(round(v / q) * q, 4)


def scale_stat(key, base, k, ultra):
    """Scaled value of one stat: keeps the sign, never rounds to zero, stays inside the caps."""
    if base == 0:
        return 0.0
    q, lo, hi = ULTRA_HP if (key == "hp" and ultra) else STAT_RULES[key]
    bonus = (base < 0) if key == "interval" else (base > 0)
    f = k if bonus else max(0.5, min(1.5, 1.0 / k))
    v = quant(base * f, q)
    if v == 0 or (v > 0) != (base > 0):
        v = q if base > 0 else -q
    return float(max(lo, min(hi, v)))


def scale_ability(ability, k):
    if ability is None:
        return None
    cls, params = ability
    out = dict(params)
    for name, (q, cap) in ABILITY_SCALE.get(cls, {}).items():
        base = params.get(name, 0)
        if not base:
            continue
        v = min(cap, max(q, quant(base * k, q)))
        out[name] = int(round(v)) if isinstance(base, int) else float(v)
    return (cls, out)


def pct(v):
    return "%g" % round(v * 100.0, 2)


def ability_line(ability):
    """Plain-words sentence for an ability, built from its numbers."""
    cls, p = ability
    g = lambda name: "%g" % p[name]
    if cls == "AbVenom":
        if p["max_stacks"] <= 1:
            return "Hits apply venom (%s dmg/s, %ss, does not stack)." % (g("damage_per_second"), g("duration"))
        return "Hits add a venom stack (%s dmg/s, %ss, max %d)." % (g("damage_per_second"), g("duration"), p["max_stacks"])
    if cls == "AbDodge":
        return "%s%% chance to dodge a hit." % pct(p["chance"])
    if cls == "AbDoubleStrike":
        return "Every %s attack strikes twice." % ORDINAL.get(p["every_n"], "%dth" % p["every_n"])
    if cls == "AbLifesteal":
        return "Heals %s%% of damage dealt." % pct(p["fraction"])
    if cls == "AbReflect":
        return "%s%% chance to reflect %s damage when hit." % (pct(p["chance"]), g("damage"))
    if cls == "AbSporePulse":
        return "Every %ss, %s damage to all enemies, ignoring DEF." % (g("interval"), g("damage"))
    if cls == "AbRegen":
        return "Heals %s HP every %ss." % (g("amount"), g("interval"))
    if cls == "AbMend":
        return "Every %ss, heals the most wounded ally for %s HP." % (g("interval"), g("amount"))
    if cls == "AbThorns":
        return "Attackers take %s damage per basic hit, ignoring DEF." % g("damage")
    if cls == "AbShield":
        return "Battle start: a shield that absorbs %s damage." % g("amount")
    if cls == "AbExecute":
        return "Hits on enemies under %s%% HP deal +%s damage, ignoring DEF." % (pct(p["threshold"]), g("bonus"))
    if cls == "AbCleave":
        return "Hits deal %s%% of their damage to other enemies in the target's row." % pct(p["fraction"])
    if cls == "AbStun":
        return "%s%% chance on hit to delay the target's next attack by %ss." % (pct(p["chance"]), g("delay"))
    if cls == "AbRage":
        return "Each basic hit taken: +%s ATK (max %d stacks)." % (g("atk_per_stack"), p["max_stacks"])
    if cls == "AbBerserk":
        return "Once, below %s%% HP: attack interval x%s." % (pct(p["threshold"]), g("interval_mult"))
    if cls == "AbWarCry":
        parts = []
        if p.get("atk_bonus"):
            parts.append("+%s ATK" % g("atk_bonus"))
        if p.get("def_bonus"):
            parts.append("+%s DEF" % g("def_bonus"))
        if p.get("hp_bonus"):
            parts.append("+%s HP" % g("hp_bonus"))
        return "Battle start: every ally gains %s." % " and ".join(parts)
    if cls == "AbVengeance":
        return "When an ally dies: +%s ATK and heal %s HP." % (g("atk_bonus"), g("heal"))
    if cls == "AbSnipe":
        return "Every %ss, %s damage to the enemy with the lowest HP, ignoring DEF." % (g("interval"), g("damage"))
    if cls == "AbChill":
        return "Hits slow the target's attacks by %ss (max %ss)." % (g("slow_per_hit"), g("max_slow"))
    if cls == "AbCorrode":
        return "Hits strip %s DEF from the target (max %s)." % (g("def_per_hit"), g("max_total"))
    if cls == "AbSecondWind":
        return "Once: survive a lethal hit and heal to %s%% of max HP." % pct(p["heal_fraction"])
    if cls == "AbAmbush":
        return "Battle start: %s damage to a random enemy, ignoring DEF." % g("damage")
    if cls == "AbChain":
        return "%s%% chance on hit to zap another enemy for %s, ignoring DEF." % (pct(p["chance"]), g("damage"))
    if cls == "AbMomentum":
        return "Each hit adds +%s%% crit (max +%s%%)." % (pct(p["crit_per_hit"]), pct(p["max_crit"]))
    if cls == "AbBurn":
        return "Hits burn for %s%% of the target's max HP per second for %ss." % (pct(p["fraction"]), g("duration"))
    if cls == "AbTitan":
        return "Takes %s%% less damage. Every %ss, stomps the enemy front row for %s." % (
            pct(p["damage_reduction"]), g("stomp_interval"), g("stomp_damage"))
    if cls == "AbPhase":
        return "%s%% chance to cancel any hit and strike back for %s." % (pct(p["chance"]), g("counter"))
    if cls == "AbSwarm":
        return "Every %ss, the swarm bites a random enemy for %s and heals you for %s." % (
            g("interval"), g("damage"), g("heal"))
    raise ValueError("no sentence for %s" % cls)


def stats_line(m):
    """Plain-words stats sentence in the wording the table self-check expects."""
    parts = []
    if m["hp"]:
        parts.append("%s%d HP" % ("+" if m["hp"] > 0 else "-", abs(m["hp"])))
    if m["atk"]:
        parts.append("%s%g ATK" % ("+" if m["atk"] > 0 else "-", abs(m["atk"])))
    if m["defense"]:
        parts.append("%s%g DEF" % ("+" if m["defense"] > 0 else "-", abs(m["defense"])))
    if m["crit"]:
        parts.append("%s%d%% crit" % ("+" if m["crit"] > 0 else "-", round(abs(m["crit"]) * 100)))
    if m["interval"]:
        parts.append("attacks %gs %s" % (abs(m["interval"]), "faster" if m["interval"] < 0 else "slower"))
    if not parts:
        return ""
    text = ", ".join(parts) + "."
    return text[0].upper() + text[1:]


def apply_k(base, k):
    """The table entry values of baseline entry `base` at scale k: (stats dict, ability, desc)."""
    ultra = base["rarity"] == ULTRA
    stats = dict((key, scale_stat(key, base[key], k, ultra)) for key in STAT_KEYS)
    ability = scale_ability(base["ability"], k)
    lines = [base["desc"].split("\n")[0]]
    sl = stats_line(stats)
    if sl:
        lines.append(sl)
    if ability:
        lines.append(ability_line(ability))
    return stats, ability, "\n".join(lines)


def _py(v):
    return repr(v)


def write_entry(src, mid, stats, ability, desc):
    start = src.index('{"id": "%s",' % mid)
    end = src.index('"art":', start)
    block = src[start:end]
    block, n1 = re.subn(r'"desc": ".*",\n', lambda _: '"desc": "%s",\n' % desc.replace("\n", "\\n"), block, count=1)
    line = '"hp": %r, "atk": %r, "interval": %r, "defense": %r, "crit": %r,' % tuple(stats[k] for k in STAT_KEYS)
    block, n2 = re.subn(r'"hp": .*?"crit": [-0-9.]+,', lambda _: line, block, count=1)
    n3 = 1
    if ability is not None:
        text = '("%s", {%s})' % (ability[0], ", ".join('"%s": %s' % (k, _py(v)) for k, v in ability[1].items()))
        block, n3 = re.subn(r'"ability": \(.*\),\n', lambda _: '"ability": %s,\n' % text, block, count=1)
    if (n1, n2, n3) != (1, 1, 1):
        raise ValueError("%s: could not rewrite the table entry" % mid)
    return src[:start] + block + src[end:]


def _gd(v):
    return repr(v) if isinstance(v, int) and not isinstance(v, bool) else repr(float(v))


def sync_existing(entries):
    """Write stats, description and ability params of the 6 hand-made .tres from the table values."""
    for mid in EXISTING:
        stats, ability, desc = entries[mid]
        path = MUT_DIR / (mid + ".tres")
        text = path.read_text(encoding="utf-8")
        text = re.sub(r'(?m)^(hp_mod|atk_mod|interval_mod|defense_mod|crit_mod) = .*\n', "", text)
        mods = "".join("%s = %r\n" % (name, stats[key]) for name, key in (
            ("hp_mod", "hp"), ("atk_mod", "atk"), ("interval_mod", "interval"),
            ("defense_mod", "defense"), ("crit_mod", "crit")) if stats[key])
        text, n = re.subn(r'(?m)^(tags = )', lambda _: mods + "tags = ", text, count=1)
        if n != 1:
            raise ValueError("%s: no tags line in the .tres" % mid)
        text, n = re.subn(r'(?s)description = ".*?"\n', lambda _: 'description = "%s"\n' % desc, text, count=1)
        if n != 1:
            raise ValueError("%s: no description in the .tres" % mid)
        for key, val in ability[1].items():
            text, n = re.subn(r'(?m)^%s = .*$' % key, lambda _: "%s = %s" % (key, _gd(val)), text, count=1)
            if n != 1:
                text, n = re.subn(r'(script = ExtResource\("2_ab"\)\n)',
                                  lambda mo: mo.group(1) + "%s = %s\n" % (key, _gd(val)), text, count=1)
                if n != 1:
                    raise ValueError("%s: could not set %s" % (mid, key))
        path.write_text(text, encoding="utf-8", newline="\n")


def rewrite(state):
    baseline = load_table(BASELINE, "mutation_baseline")
    src = TABLE.read_text(encoding="utf-8")
    entries = {}
    for base in baseline:
        k = state.get(base["id"], 1.0)
        stats, ability, desc = apply_k(base, k)
        entries[base["id"]] = (stats, ability, desc)
        src = write_entry(src, base["id"], stats, ability, desc)
    TABLE.write_text(src, encoding="utf-8", newline="\n")
    sync_existing(entries)
    STATE.write_text(json.dumps(state, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def main(argv):
    if "--sync-only" in argv:
        rewrite(json.loads(STATE.read_text(encoding="utf-8")))
        print("table and hand-made .tres re-synced from the state")
        return
    if "--init" in argv:
        i = argv.index("--init")
        k0 = float(argv[i + 1]) if len(argv) > i + 1 else 1.3
        rewrite(dict((m["id"], k0) for m in load_table(BASELINE, "mutation_baseline")))
        print("initialised every k to %g" % k0)
        return
    state = json.loads(STATE.read_text(encoding="utf-8"))
    scores = {}
    with open(argv[0], newline="") as f:
        for row in csv.DictReader(f):
            scores.setdefault(row["id"], []).append(float(row["score"]))
    moved = 0
    for mid, vals in scores.items():
        score = sum(vals) / len(vals)
        if abs(score - 50.0) <= BAND or mid not in state:
            continue
        factor = (50.0 / max(12.0, min(100.0, score))) ** GAIN
        if score >= 99.0:
            factor = min(factor, 0.5)
        state[mid] = round(max(K_MIN, min(K_MAX, state[mid] * factor)), 4)
        moved += 1
    baseline = load_table(BASELINE, "mutation_baseline")
    blind = [m["id"] for m in baseline if m["ability"] and m["ability"][0] in BLIND]
    seen = sorted(v for mid, v in state.items() if mid not in blind)
    for mid in blind:
        state[mid] = seen[len(seen) // 2]
    rewrite(state)
    ks = sorted(state.values())
    print("retuned %d mutations; k min %.2f median %.2f max %.2f" % (moved, ks[0], ks[len(ks) // 2], ks[-1]))


if __name__ == "__main__":
    main(sys.argv[1:])
