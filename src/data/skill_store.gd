class_name SkillStore
extends RefCounted
## Persistent skill points and skill ranks (meta-progression;
## docs/superpowers/specs/2026-11-21-skill-points-design.md), as JSON. Static; the
## file path is a parameter so tests never touch the real user file.
##
## File layout (String keys, as JSON gives them): {"points": int, "ranks": {"<id>": int}}.
## Skill definitions and costs live in Tuning (SKILLS, SKILL_COST_PER_RANK).

## The real save file.
const DEFAULT_PATH: String = "user://skills.json"
const KEY_POINTS: String = "points"
const KEY_RANKS: String = "ranks"

## The stored data, or {"points": 0, "ranks": {}} if the file is missing or
## unreadable. Rank keys are Strings here (raw file layout).
static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	var data: Dictionary = {KEY_POINTS: 0, KEY_RANKS: {}}
	if not FileAccess.file_exists(path):
		return data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var d: Dictionary = parsed
		var p: Variant = d.get(KEY_POINTS)
		if p is float or p is int:
			data[KEY_POINTS] = maxi(0, int(p))
		if d.get(KEY_RANKS) is Dictionary:
			var clean: Dictionary = {}
			var raw: Dictionary = d[KEY_RANKS]
			for k: Variant in raw.keys():
				var v: Variant = raw[k]
				if (v is float or v is int) and int(v) > 0:
					clean[String(k)] = int(v)
			data[KEY_RANKS] = clean
	return data

## Writes `data` (same layout as load_data()) to `path`. Returns false on failure.
static func save_data(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

## Unspent skill points.
static func points(path: String = DEFAULT_PATH) -> int:
	return int(load_data(path)[KEY_POINTS])

## Current rank of skill `id` (0 if never bought).
static func rank(id: StringName, path: String = DEFAULT_PATH) -> int:
	return int((load_data(path)[KEY_RANKS] as Dictionary).get(String(id), 0))

## All bought ranks as StringName id -> int (only ranks above 0).
static func ranks(path: String = DEFAULT_PATH) -> Dictionary:
	var out: Dictionary = {}
	var raw: Dictionary = load_data(path)[KEY_RANKS]
	for k: Variant in raw.keys():
		out[StringName(String(k))] = int(raw[k])
	return out

## Cost of the next rank of `id`, or 0 if it is maxed or unknown.
static func next_cost(id: StringName, path: String = DEFAULT_PATH) -> int:
	var def: Dictionary = SkillEffects.skill_def(id)
	if def.is_empty():
		return 0
	var r: int = rank(id, path)
	if r >= int(def[&"max_rank"]):
		return 0
	return (r + 1) * Tuning.SKILL_COST_PER_RANK

## True if `id` is not maxed and the player has enough points for its next rank.
static func can_buy(id: StringName, path: String = DEFAULT_PATH) -> bool:
	var cost: int = next_cost(id, path)
	return cost > 0 and points(path) >= cost

## Buys the next rank of `id` and saves. Returns false (and changes nothing) if
## it is maxed, unknown or unaffordable.
static func buy(id: StringName, path: String = DEFAULT_PATH) -> bool:
	if not can_buy(id, path):
		return false
	var data: Dictionary = load_data(path)
	var r: Dictionary = data[KEY_RANKS]
	var key: String = String(id)
	var current: int = int(r.get(key, 0))
	data[KEY_POINTS] = int(data[KEY_POINTS]) - (current + 1) * Tuning.SKILL_COST_PER_RANK
	r[key] = current + 1
	return save_data(data, path)

## Adds `n` points (ignored if n <= 0) and saves.
static func add_points(n: int, path: String = DEFAULT_PATH) -> void:
	if n <= 0:
		return
	var data: Dictionary = load_data(path)
	data[KEY_POINTS] = int(data[KEY_POINTS]) + n
	save_data(data, path)

## Resets every rank to 0 and returns the points spent on them to the pool.
## Returns the number of points refunded.
static func refund_all(path: String = DEFAULT_PATH) -> int:
	var data: Dictionary = load_data(path)
	var refunded: int = 0
	var r: Dictionary = data[KEY_RANKS]
	for k: Variant in r.keys():
		var n: int = int(r[k])
		# Rank n cost 1 + 2 + ... + n steps of SKILL_COST_PER_RANK.
		@warning_ignore("integer_division")
		refunded += n * (n + 1) / 2 * Tuning.SKILL_COST_PER_RANK
	data[KEY_POINTS] = int(data[KEY_POINTS]) + refunded
	data[KEY_RANKS] = {}
	save_data(data, path)
	return refunded
