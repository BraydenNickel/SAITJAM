class_name RunSummary
extends RefCounted
## Run-end summary data (handoff.md §8 follow-up): one log entry per battle
## played, and the Codex entries first discovered during the run. Static and
## autoload-free so tests can call it directly.
##
## Log entry layout (StringName keys):
## {&"battle": int (1-based), &"won": bool, &"net": int (reward + payouts - stakes),
##  &"top_name": String ("" if nobody dealt damage), &"top_damage": int}

const MUTATIONS_DIR: String = "res://src/data/mutations/"

## Builds one battle log entry. `result` is BattleSim.result(); its
## &"damage_by_roster" (roster index -> damage) picks the top damage dealer,
## named from `roster`. Ties go to the lower roster index.
static func make_entry(battle_number: int, won: bool, net: int, result: Dictionary,
		roster: Array[MonsterData]) -> Dictionary:
	var top_idx: int = -1
	var top_dmg: int = 0
	var dmg: Dictionary = result.get(&"damage_by_roster", {})
	var keys: Array = dmg.keys()
	keys.sort()
	for key: Variant in keys:
		var d: int = int(dmg[key])
		if d > top_dmg:
			top_dmg = d
			top_idx = int(key)
	var top_name: String = ""
	if top_idx >= 0 and top_idx < roster.size() and roster[top_idx] != null:
		top_name = roster[top_idx].display_name
	return {&"battle": battle_number, &"won": won, &"net": net,
		&"top_name": top_name, &"top_damage": top_dmg if top_name != "" else 0}

## Net gold of a battle from its gold delta (reward + payouts) and the placed
## bets ({&"stake": int, ...}): gold_delta minus the total stakes.
static func net_from_bets(gold_delta: int, bets: Array[Dictionary]) -> int:
	var stakes: int = 0
	for bet: Dictionary in bets:
		stakes += int(bet.get(&"stake", 0))
	return gold_delta - stakes

## Display names of the Codex entries in `now` but not in `start` (both in
## CodexStore.load_codex() layout): new base mutations first, then new fused
## monster titles. Mutation names come from their .tres, falling back to the id.
static func new_codex_names(start: Dictionary, now: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var old_muts: Array = start.get(CodexStore.KEY_MUTATIONS, [])
	for id: Variant in now.get(CodexStore.KEY_MUTATIONS, []):
		if not old_muts.has(id):
			out.append(mutation_name(String(id)))
	var old_titles: Array = start.get(CodexStore.KEY_TITLES, [])
	for title: Variant in now.get(CodexStore.KEY_TITLES, []):
		if not old_titles.has(title):
			out.append(String(title))
	return out

## Display name of base mutation `id`, or `id` itself if its .tres is missing.
static func mutation_name(id: String) -> String:
	var path: String = MUTATIONS_DIR + id + ".tres"
	if ResourceLoader.exists(path):
		var m: MutationData = load(path) as MutationData
		if m != null and m.display_name != "":
			return m.display_name
	return id
