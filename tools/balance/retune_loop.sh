#!/usr/bin/env bash
# Stage-4 balance loop: arena -> retune (tools/balance/retune.py) -> regenerate .tres -> import.
# Run from the project root. Usage: bash tools/balance/retune_loop.sh [passes=5] [fights=100]
# Start a fresh search with: python tools/balance/retune.py --init 1.3
set -e
G="${GODOT:-C:/Godot/Godot_v4.7.2-stable_win64_console.exe}"
PASSES="${1:-5}"
FIGHTS="${2:-100}"
python tools/gen_mutations.py > /dev/null
"$G" --headless --path . --import > /dev/null 2>&1 || true
for i in $(seq 1 "$PASSES"); do
  "$G" --headless --path . -s res://tools/balance/run_sim.gd -- mode=arena fights="$FIGHTS" out=res://reports/s4b_arena_pass$i.md 2>&1 | grep -E "ARENA|Arena time|SCRIPT ERROR|Parse" || true
  python tools/balance/retune.py reports/s4b_arena_pass$i.csv | tail -1
  python tools/mutation_table.py | tail -1
  python tools/gen_mutations.py > /dev/null
  "$G" --headless --path . --import > /dev/null 2>&1 || true
done
"$G" --headless --path . -s res://tools/balance/run_sim.gd -- mode=arena fights=200 out=res://reports/s4b_arena_after.md 2>&1 | grep -E "ARENA|Arena time|SCRIPT ERROR|Parse" || true
echo LOOP_DONE
