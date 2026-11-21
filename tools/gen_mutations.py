#!/usr/bin/env python3
"""Generate src/data/mutations/<id>.tres from tools/mutation_table.py.

Usage (from the project root):
    python tools/gen_mutations.py            validate, then write every non-"existing" entry
    python tools/gen_mutations.py --check    validate and report only, write nothing

Options:
    --table PATH   use another table module file (default tools/mutation_table.py)
    --out DIR      write the .tres files to DIR (default src/data/mutations)
    --expect N     required number of entries (default 100; for test tables)

Contract: design/balance/stage4-mutations.md (sections 1-4).
Errors stop the run before anything is written (exit code 1). Warnings (missing
ability script, sprite PNG, aura json, ...) never stop it, so a --check run doubles
as an integration check. Python 3.10+, stdlib only.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent

SOCKETS = {"HEAD": 0, "TORSO": 1, "BACK": 2, "ARM": 3, "LEG": 4, "TAIL": 5}
RARITY_NAMES = ["COMMON", "UNCOMMON", "RARE", "ULTRA"]
ULTRA = 3
BODY_STYLES = ["crystal", "shadow", "molten", "slime", "gold", "skeletal", "void", "angelic"]

# The six hand-made files. They are never written, whatever the table says.
HAND_MADE = {"mantis_arm", "scorpion_tail", "leech_maw", "raptor_leg", "bone_plating", "spore_sacs"}

# Ability catalog (contract section 2). Value = default params, used for the param
# names and as the type fallback while the script is not on disk. None = existing
# ability: its params are read from the script.
CATALOG: dict[str, dict | None] = {
    "AbVenom": None, "AbDodge": None, "AbDoubleStrike": None,
    "AbLifesteal": None, "AbReflect": None, "AbSporePulse": None,
    "AbRegen": {"interval": 3.0, "amount": 6.0},
    "AbMend": {"interval": 5.0, "amount": 10.0},
    "AbThorns": {"damage": 2.0},
    "AbShield": {"amount": 40.0},
    "AbExecute": {"threshold": 0.25, "bonus": 8.0},
    "AbCleave": {"fraction": 0.4},
    "AbStun": {"chance": 0.15, "delay": 0.8},
    "AbRage": {"atk_per_stack": 1.0, "max_stacks": 6},
    "AbBerserk": {"threshold": 0.5, "interval_mult": 0.7},
    "AbWarCry": {"atk_bonus": 1.0, "def_bonus": 0.0, "hp_bonus": 0.0},
    "AbVengeance": {"atk_bonus": 2.0, "heal": 20.0},
    "AbSnipe": {"interval": 4.0, "damage": 6.0},
    "AbChill": {"slow_per_hit": 0.05, "max_slow": 0.4},
    "AbCorrode": {"def_per_hit": 1.0, "max_total": 4.0},
    "AbSecondWind": {"heal_fraction": 0.3},
    "AbAmbush": {"damage": 12.0},
    "AbChain": {"chance": 0.3, "damage": 5.0},
    "AbMomentum": {"crit_per_hit": 0.03, "max_crit": 0.3},
    "AbBurn": {"fraction": 0.01, "duration": 4.0},
    "AbTitan": {"damage_reduction": 0.2, "stomp_interval": 5.0, "stomp_damage": 6.0},
    "AbPhase": {"chance": 0.25, "counter": 6.0},
    "AbSwarm": {"interval": 2.5, "damage": 3.0, "heal": 2.0},
}

ID_RE = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
EXPORT_RE = re.compile(
    r"^@export(?:_\w+)?(?:\([^)]*\))?\s+var\s+(\w+)\s*(?::\s*([\w.]+))?\s*(?::?=\s*(.+?))?\s*$"
)
STAT_FIELDS = [("hp", "hp_mod"), ("atk", "atk_mod"), ("interval", "interval_mod"),
               ("defense", "defense_mod"), ("crit", "crit_mod")]


# ---------------------------------------------------------------- helpers

def class_to_file(cls: str) -> str:
    """AbSecondWind -> ab_second_wind"""
    return re.sub(r"(?<!^)(?=[A-Z])", "_", cls).lower()


def ability_script_rel(cls: str) -> str:
    return f"src/data/abilities/{class_to_file(cls)}.gd"


_export_cache: dict[str, dict[str, str] | None] = {}


def script_exports(cls: str) -> dict[str, str] | None:
    """{param name: 'int' | 'float' | 'bool' | 'String' | ...} from the script, or None if not on disk."""
    if cls in _export_cache:
        return _export_cache[cls]
    path = ROOT / ability_script_rel(cls)
    result: dict[str, str] | None = None
    if path.is_file():
        result = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            m = EXPORT_RE.match(line.strip())
            if not m:
                continue
            name, typ, default = m.group(1), m.group(2), (m.group(3) or "").split("#")[0].strip()
            if not typ:  # inferred type (`:=` or untyped): read it off the default literal
                if default in ("true", "false"):
                    typ = "bool"
                elif re.fullmatch(r"-?\d+", default):
                    typ = "int"
                elif re.fullmatch(r"-?(\d+\.\d*|\.\d+|\d+)([eE][-+]?\d+)?", default):
                    typ = "float"
                elif default.startswith('"'):
                    typ = "String"
                else:
                    typ = ""
            result[name] = typ
    _export_cache[cls] = result
    return result


def fmt_float(v: float) -> str:
    return repr(float(v))  # 2 -> '2.0', 0.01 -> '0.01'; always reads back as a float


def fmt_string(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fmt_param(value, typ: str) -> str:
    """Format one ability param as `typ` ('int', 'float', 'bool', 'String', or '' = by Python type)."""
    if isinstance(value, bool) or typ == "bool":
        return "true" if value else "false"
    if isinstance(value, str):
        return fmt_string(value)
    if typ == "int":
        return str(int(value))
    if typ == "float":
        return fmt_float(value)
    return str(value) if isinstance(value, int) else fmt_float(value)


def param_type(cls: str, name: str) -> str:
    """Script export type first, then the catalog default's type, then '' (use the Python type)."""
    exports = script_exports(cls)
    if exports and exports.get(name) in ("int", "float", "bool", "String"):
        return exports[name]
    defaults = CATALOG.get(cls) or {}
    if name in defaults:
        return "int" if isinstance(defaults[name], int) else "float"
    return ""


def fmt_color(hex_str: str) -> str:
    parts = [f"{round(int(hex_str[i:i + 2], 16) / 255.0, 4):g}" for i in (1, 3, 5)]
    return f"Color({parts[0]}, {parts[1]}, {parts[2]}, 1)"


def is_number(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


# ---------------------------------------------------------------- load

def load_table(path: Path) -> list:
    if not path.is_file():
        sys.exit(f"ERROR: mutation table not found: {path}")
    sys.path.insert(0, str(path.parent))
    try:
        spec = importlib.util.spec_from_file_location(path.stem, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception as exc:  # a half-written table must fail with a clear message
        sys.exit(f"ERROR: could not import {path}: {type(exc).__name__}: {exc}")
    table = getattr(module, "MUTATIONS", None)
    if not isinstance(table, list):
        sys.exit(f"ERROR: {path} does not define a list named MUTATIONS")
    return table


# ---------------------------------------------------------------- validate

def validate(table: list, expect: int) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    if len(table) != expect:
        errors.append(f"table has {len(table)} entries, expected {expect}")

    seen: dict[str, int] = {}
    styles: dict[str, str] = {}
    for index, m in enumerate(table):
        if not isinstance(m, dict):
            errors.append(f"entry #{index}: not a dict")
            continue
        mid = m.get("id")
        tag = f"entry #{index} ({mid!r})"
        if not isinstance(mid, str) or not ID_RE.match(mid):
            errors.append(f"{tag}: id must be snake_case")
            continue
        if mid in seen:
            errors.append(f"{tag}: duplicate id, first used by entry #{seen[mid]}")
        seen[mid] = index

        existing = bool(m.get("existing"))
        if mid in HAND_MADE and not existing:
            errors.append(f'{tag}: is a hand-made mutation and must have "existing": True')
        if existing and not (ROOT / "src/data/mutations" / f"{mid}.tres").is_file():
            warnings.append(f'{mid}: marked "existing" but src/data/mutations/{mid}.tres is not on disk')

        if not isinstance(m.get("name"), str) or not m["name"].strip():
            errors.append(f"{tag}: missing name")
        if not isinstance(m.get("desc"), str):
            errors.append(f"{tag}: missing desc")
        if m.get("socket") not in SOCKETS:
            errors.append(f"{tag}: invalid socket {m.get('socket')!r} (one of {' '.join(SOCKETS)})")
        rarity = m.get("rarity")
        if isinstance(rarity, bool) or not isinstance(rarity, int) or not 0 <= rarity <= ULTRA:
            errors.append(f"{tag}: invalid rarity {rarity!r} (0..3)")
            rarity = None

        for key, _field in STAT_FIELDS:
            if not is_number(m.get(key, 0.0)):
                errors.append(f"{tag}: {key} must be a number, got {m.get(key)!r}")

        tags = m.get("tags", [])
        if not isinstance(tags, (list, tuple)) or not all(isinstance(t, str) and ID_RE.match(t) for t in tags):
            errors.append(f"{tag}: tags must be a list of snake_case strings, got {tags!r}")

        ability = m.get("ability")
        if ability is not None:
            if (not isinstance(ability, (tuple, list)) or len(ability) != 2
                    or not isinstance(ability[0], str) or not isinstance(ability[1], dict)):
                errors.append(f'{tag}: ability must be ("AbClass", {{params}}) or None')
            elif ability[0] not in CATALOG:
                errors.append(f"{tag}: ability class {ability[0]!r} is not in the catalog")
            else:
                cls, params = ability
                exports = script_exports(cls)
                known = exports if exports is not None else (CATALOG[cls] or {})
                if exports is None and not existing:
                    warnings.append(f"{mid}: ability script missing: res://{ability_script_rel(cls)}")
                for pname, pvalue in params.items():
                    if not isinstance(pvalue, (int, float, str)):
                        errors.append(f"{tag}: ability param {pname}={pvalue!r} has an unsupported type")
                    elif known and pname not in known:
                        warnings.append(f"{mid}: {cls} has no param {pname!r} (known: {', '.join(known)})")
                    elif (param_type(cls, pname) == "int" and isinstance(pvalue, float)
                          and not pvalue.is_integer()):
                        errors.append(f"{tag}: {cls}.{pname} is an int, got {pvalue!r}")

        body = m.get("body")
        if rarity == ULTRA:
            if not isinstance(body, dict):
                errors.append(f'{tag}: ULTRA entry needs a "body" dict')
            else:
                style = body.get("style")
                if style not in BODY_STYLES:
                    errors.append(f"{tag}: invalid body style {style!r} (one of {' '.join(BODY_STYLES)})")
                elif style in styles:
                    warnings.append(f"{mid}: body style {style!r} is also used by {styles[style]}")
                else:
                    styles[style] = mid
                if not isinstance(body.get("tint", "#ffffff"), str) or not HEX_RE.match(body.get("tint", "#ffffff")):
                    errors.append(f"{tag}: body tint must be \"#rrggbb\", got {body.get('tint')!r}")
                scale = body.get("scale", 1.0)
                if not is_number(scale) or scale <= 0:
                    errors.append(f"{tag}: body scale must be a positive number, got {scale!r}")
                elif not 1.0 <= scale <= 1.35:
                    warnings.append(f"{mid}: body scale {scale} is outside the contract range 1.0-1.35")
        elif body is not None:
            warnings.append(f"{mid}: non-ULTRA entry has a body override; it is ignored")

        if not existing and not errors:
            for rel in asset_paths(m):
                if not (ROOT / rel).is_file():
                    warnings.append(f"{mid}: missing asset: res://{rel}")

    # The fields this generator writes must exist on MutationData, or Godot drops them on load.
    script = ROOT / "src/data/defs/mutation_data.gd"
    if script.is_file():
        source = script.read_text(encoding="utf-8")
        if any(isinstance(m, dict) and m.get("rarity") == ULTRA for m in table):
            if "ULTRA" not in source:
                warnings.append("mutation_data.gd: Rarity has no ULTRA value yet (rarity = 3 will not load)")
            for field in ("body_front", "body_side", "body_tint", "body_scale", "aura_fx"):
                if not re.search(rf"\bvar\s+{field}\b", source):
                    warnings.append(f"mutation_data.gd: export '{field}' is not defined yet")
    else:
        warnings.append("src/data/defs/mutation_data.gd is missing")

    return errors, warnings


def asset_paths(m: dict) -> list[str]:
    """Project-relative asset files a generated entry references."""
    mid = m["id"]
    paths = [f"assets/sprites/parts/{mid}_front.png", f"assets/sprites/parts/{mid}_side.png"]
    if m["rarity"] == ULTRA:
        paths += [f"assets/sprites/torso/body_{mid}_front.png", f"assets/sprites/torso/body_{mid}_side.png",
                  f"assets/fx/aura_{m['body']['style']}.json"]
    return paths


# ---------------------------------------------------------------- render

def render(m: dict) -> str:
    mid = m["id"]
    ultra = m["rarity"] == ULTRA
    ability = m.get("ability")

    ext = ['[ext_resource type="Script" path="res://src/data/defs/mutation_data.gd" id="1_mut"]']
    if ability:
        ext.append(f'[ext_resource type="Script" path="res://{ability_script_rel(ability[0])}" id="2_ab"]')
    ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/parts/{mid}_front.png" id="3_front"]')
    ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/parts/{mid}_side.png" id="4_side"]')
    if ultra:
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/torso/body_{mid}_front.png" id="5_bfront"]')
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/torso/body_{mid}_side.png" id="6_bside"]')

    out = ['[gd_resource type="Resource" script_class="MutationData" format=3]', ""]
    out += ext
    out.append("")

    if ability:
        cls, params = ability
        out.append('[sub_resource type="Resource" id="Resource_ability"]')
        out.append('script = ExtResource("2_ab")')
        for pname, pvalue in params.items():
            out.append(f"{pname} = {fmt_param(pvalue, param_type(cls, pname))}")
        out.append("")

    out.append("[resource]")
    out.append('script = ExtResource("1_mut")')
    out.append(f'id = &"{mid}"')
    out.append(f"display_name = {fmt_string(m['name'])}")
    out.append(f"description = {fmt_string(m['desc'])}")
    out.append(f"socket_type = {SOCKETS[m['socket']]}")  # always explicit: HEAD is 0, the default is TORSO
    out.append(f"rarity = {m['rarity']}")
    out.append('sprite_front = ExtResource("3_front")')
    out.append('sprite_side = ExtResource("4_side")')
    for key, field in STAT_FIELDS:
        value = float(m.get(key, 0.0) or 0.0)
        if value != 0.0:
            out.append(f"{field} = {fmt_float(value)}")
    tags = ", ".join(f'&"{t}"' for t in m.get("tags", []))
    out.append(f"tags = Array[StringName]([{tags}])")
    if ability:
        out.append('ability = SubResource("Resource_ability")')
    if ultra:
        body = m["body"]
        out.append('body_front = ExtResource("5_bfront")')
        out.append('body_side = ExtResource("6_bside")')
        out.append(f"body_tint = {fmt_color(body.get('tint', '#ffffff'))}")
        out.append(f"body_scale = {fmt_float(body.get('scale', 1.0))}")
        # The table's body.aura is unreliable; the VFX pass exports one loop per style.
        out.append(f'aura_fx = "res://assets/fx/aura_{body["style"]}.json"')
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- main

def main() -> int:
    parser = argparse.ArgumentParser(description="Generate mutation .tres files from the mutation table.")
    parser.add_argument("--check", action="store_true", help="validate and report, write nothing")
    parser.add_argument("--table", type=Path, default=TOOLS_DIR / "mutation_table.py",
                        help="table module file (default tools/mutation_table.py)")
    parser.add_argument("--out", type=Path, default=ROOT / "src/data/mutations",
                        help="output directory (default src/data/mutations)")
    parser.add_argument("--expect", type=int, default=100, help="required entry count (default 100)")
    args = parser.parse_args()

    table = load_table(args.table.resolve())
    errors, warnings = validate(table, args.expect)

    if errors:
        print(f"VALIDATION FAILED: {len(errors)} error(s), nothing written", file=sys.stderr)
        for line in errors:
            print(f"  ERROR  {line}", file=sys.stderr)
        return 1

    to_write = [m for m in table if not m.get("existing")]
    skipped = len(table) - len(to_write)
    out_dir = args.out.resolve()

    written = 0
    if not args.check:
        out_dir.mkdir(parents=True, exist_ok=True)
        for m in to_write:
            target = out_dir / f"{m['id']}.tres"
            with open(target, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(render(m))
            written += 1

    for line in warnings:
        print(f"  WARN   {line}")

    print(f"Table: {args.table}  ({len(table)} entries, {skipped} existing skipped)")
    print("Rarity: " + "  ".join(
        f"{name} {sum(1 for m in table if m['rarity'] == i)}" for i, name in enumerate(RARITY_NAMES)))
    print("Socket: " + "  ".join(
        f"{name} {sum(1 for m in table if m['socket'] == name)}" for name in SOCKETS))
    with_ability = sum(1 for m in table if m.get("ability"))
    print(f"Abilities: {with_ability} entries, "
          f"{len({m['ability'][0] for m in table if m.get('ability')})} of {len(CATALOG)} classes used")
    if args.check:
        print(f"CHECK ONLY: would write {len(to_write)} file(s) to {out_dir}")
    else:
        print(f"Files written: {written} -> {out_dir}")
    print(f"Warnings: {len(warnings)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
