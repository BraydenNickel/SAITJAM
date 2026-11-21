class_name FusionLogic
extends RefCounted
## Fusion rules (design/fusion-contract.md §1-3): merging two mutations of one
## socket type into one fused part (Lab splice and Incubator), and incubating two
## monsters into one body. Static, deterministic, no Nodes. Functions that take a
## RunState mutate it (gold included); screens call Game.notify_gold() afterwards
## and CodexStore.record(result[&"new_codex"]) to persist discoveries.

## Default location of the index written by tools/gen_hybrids.py.
const INDEX_PATH: String = "res://src/data/fusion_index.json"
## Atlas per socket and view: ATLAS_PATH % [socket name (lower case), "front"|"side"].
const ATLAS_PATH: String = "res://assets/sprites/hybrids/%s_%s.png"
## Separator of base ids inside a fused id / pair key.
const KEY_SEPARATOR: String = "+"
## Fallbacks when the index does not carry its own grid.
const DEFAULT_CELL: int = 32
const DEFAULT_COLUMNS: int = 16

const NAME_TWIN: String = "Twin %s"
const NAME_APEX: String = "Apex %s"
const NAME_HYBRID_FALLBACK: String = "Hybrid %s"
const TEXT_PARENTS: String = "Fusion of %s + %s."
const TEXT_TWIN_ABILITY: String = "Twinned x%s: %s"
const NAME_FUSED_MONSTER: String = "Chimera %02d"
const TITLE_TWO: String = "%s-%s Chimera"
const TITLE_ONE: String = "%s Chimera"
const TITLE_NONE: String = "Nameless Chimera"

const REASON_MISSING: String = "Nothing to merge"
const REASON_SOCKET: String = "Different body part types"
const REASON_APEX: String = "An Apex part cannot be merged again"
const REASON_TOO_MANY: String = "Two fused parts cannot be merged"

static var _index: Dictionary = {}
static var _index_loaded: bool = false
static var _index_path: String = INDEX_PATH

# --- Index ---------------------------------------------------------------------

## Points the loader at another index file and drops the cache (tests; "" restores
## the default). A missing or broken file gives an empty index, never an error.
static func set_index_path(path: String) -> void:
	_index_path = path if path != "" else INDEX_PATH
	_index = {}
	_index_loaded = false

## The parsed fusion index ({cell, columns, pairs, signatures}), loaded once.
static func index() -> Dictionary:
	if _index_loaded:
		return _index
	_index_loaded = true
	_index = {}
	if FileAccess.file_exists(_index_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_index_path))
		if parsed is Dictionary:
			_index = parsed
	return _index

## Signature entry ({name, desc, front, side}) for a pair key, or {} if the pair
## is not a signature.
static func signature_info(key: String) -> Dictionary:
	var sigs: Variant = index().get("signatures", {})
	if sigs is Dictionary and (sigs as Dictionary).get(key) is Dictionary:
		return (sigs as Dictionary)[key]
	return {}

## [front, side] textures for a pair key: the bespoke signature sprites, or
## AtlasTextures of the pair's atlas cell. [] if the key (or its art) is missing.
static func sprites_for(key: String) -> Array[Texture2D]:
	var none: Array[Texture2D] = []
	var sig: Dictionary = signature_info(key)
	if not sig.is_empty():
		var front_path: String = String(sig.get("front", ""))
		var side_path: String = String(sig.get("side", ""))
		if ResourceLoader.exists(front_path) and ResourceLoader.exists(side_path):
			var sig_pair: Array[Texture2D] = [load(front_path) as Texture2D,
				load(side_path) as Texture2D]
			if sig_pair[0] != null and sig_pair[1] != null:
				return sig_pair
	var pairs: Variant = index().get("pairs", {})
	if not (pairs is Dictionary) or not ((pairs as Dictionary).get(key) is Dictionary):
		return none
	var entry: Dictionary = (pairs as Dictionary)[key]
	var socket: String = String(entry.get("socket", "")).to_lower()
	var cell_index: int = int(entry.get("cell", -1))
	if socket == "" or cell_index < 0:
		return none
	var cell: int = int(index().get("cell", DEFAULT_CELL))
	var columns: int = maxi(1, int(index().get("columns", DEFAULT_COLUMNS)))
	@warning_ignore("integer_division")
	var region: Rect2 = Rect2((cell_index % columns) * cell, (cell_index / columns) * cell,
		cell, cell)
	var result: Array[Texture2D] = []
	for view: String in ["front", "side"]:
		var path: String = ATLAS_PATH % [socket, view]
		if not ResourceLoader.exists(path):
			return none
		var sheet: Texture2D = load(path) as Texture2D
		if sheet == null:
			return none
		var tex: AtlasTexture = AtlasTexture.new()
		tex.atlas = sheet
		tex.region = region
		result.append(tex)
	return result

# --- Merge rules ---------------------------------------------------------------

## True if `a` and `b` may be merged into one fused mutation.
static func can_merge(a: MutationData, b: MutationData) -> bool:
	return block_reason(a, b) == ""

## Why `a` and `b` cannot merge ("" if they can).
static func block_reason(a: MutationData, b: MutationData) -> String:
	if a == null or b == null:
		return REASON_MISSING
	if a.socket_type != b.socket_type:
		return REASON_SOCKET
	if a.merge_count >= Tuning.FUSION_MAX_MERGES or b.merge_count >= Tuning.FUSION_MAX_MERGES:
		return REASON_APEX
	if a.merge_count + b.merge_count + 1 > Tuning.FUSION_MAX_MERGES:
		return REASON_TOO_MANY
	return ""

## Base source ids of a mutation: its own id for a base one, parent_ids otherwise.
static func base_ids(m: MutationData) -> Array[StringName]:
	var ids: Array[StringName] = []
	if m == null:
		return ids
	if m.merge_count <= 0 or m.parent_ids.is_empty():
		ids.append(m.id)
	else:
		ids.assign(m.parent_ids)
	return ids

## Sorted base ids of both mutations joined by "+": the fused id and Codex key.
static func pair_key(a: MutationData, b: MutationData) -> String:
	return KEY_SEPARATOR.join(PackedStringArray(_sorted_ids(a, b)))

## Abilities the merge of `a` and `b` could carry, in parent order (an already
## fused parent first, otherwise sorted id order). A Twin offers one entry: the
## parent's ability empowered by Tuning.FUSION_TWIN_POWER. merge()'s `keep`
## indexes this list.
static func ability_choices(a: MutationData, b: MutationData) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for entry: Array in _ability_entries(a, b):
		result.append(entry[0] as AbilityData)
	return result

## The fused mutation of `a` and `b`, or null if blocked. If the parents offer
## more than Tuning.FUSION_MAX_ABILITIES abilities, `keep` lists the indices of
## ability_choices() to keep (invalid or repeated indices are ignored, missing
## ones are filled in parent order). Neither parent is changed.
static func merge(a: MutationData, b: MutationData, keep: Array[int] = []) -> MutationData:
	if not can_merge(a, b):
		return null
	var ordered: Array[MutationData] = _ordered(a, b)
	var first: MutationData = ordered[0]
	var second: MutationData = ordered[1]
	var key: String = pair_key(a, b)
	var r: MutationData = MutationData.new()
	r.merge_count = a.merge_count + b.merge_count + 1
	r.id = StringName(key)
	var ids: Array[StringName] = []
	for id_text: String in _sorted_ids(a, b):
		ids.append(StringName(id_text))
	r.parent_ids = ids
	r.socket_type = a.socket_type
	r.rarity = maxi(int(a.rarity), int(b.rarity)) as MutationData.Rarity
	r.fused_cost = EnemyGen.cost_of(a) + EnemyGen.cost_of(b)
	var sig: Dictionary = signature_info(key) if r.merge_count == 1 else {}
	r.signature = not sig.is_empty()

	# Stats: multiplier x sum over the base parents.
	var mult: float = _stat_mult(r.merge_count, r.signature)
	var sa: Array[float] = _base_stat_sum(a)
	var sb: Array[float] = _base_stat_sum(b)
	r.hp_mod = mult * (sa[0] + sb[0])
	r.atk_mod = mult * (sa[1] + sb[1])
	r.interval_mod = mult * (sa[2] + sb[2])
	r.defense_mod = mult * (sa[3] + sb[3])
	r.crit_mod = mult * (sa[4] + sb[4])

	# Abilities.
	var kept: Array = _kept_entries(_ability_entries(a, b), keep)
	var texts: Array[String] = []
	var extras: Array[AbilityData] = []
	for i: int in kept.size():
		var ab: AbilityData = (kept[i] as Array)[0]
		if i == 0:
			r.ability = ab
		else:
			extras.append(ab)
		texts.append(String((kept[i] as Array)[1]))
	r.extra_abilities = extras
	r.ability_texts = texts

	var tags: Array[StringName] = []
	for parent: MutationData in ordered:
		for tag: StringName in parent.tags:
			if not tags.has(tag):
				tags.append(tag)
	r.tags = tags

	# ULTRA body override: highest-rarity parent that has one, first on a tie.
	var body: MutationData = null
	for parent: MutationData in ordered:
		if parent.overrides_body() and (body == null or int(parent.rarity) > int(body.rarity)):
			body = parent
	if body != null:
		r.body_front = body.body_front
		r.body_side = body.body_side
		r.body_tint = body.body_tint
		r.body_scale = body.body_scale
		r.aura_fx = body.aura_fx

	r.display_name = _fused_name(first, second, r.merge_count, sig)
	r.description = _fused_description(first, second, r, sig)

	# Sprites: apex reuses its fused parent's art; otherwise the index; otherwise
	# the higher-rarity parent's own sprites.
	var art: Array[Texture2D] = []
	if r.merge_count > 1:
		if first.sprite_front != null and first.sprite_side != null:
			art = [first.sprite_front, first.sprite_side]
	else:
		art = sprites_for(key)
	if art.size() < 2:
		var donor: MutationData = second if int(second.rarity) > int(first.rarity) else first
		art = [donor.sprite_front, donor.sprite_side]
	r.sprite_front = art[0]
	r.sprite_side = art[1]
	return r

## Codex entry {&"kind": &"part", &"key", &"name", &"signature"} for a fused part
## not yet in run.fusion_codex, which it is then added to. {} if `m` is not fused
## or already known this run.
static func record_part(run: RunState, m: MutationData) -> Dictionary:
	if m == null or m.merge_count <= 0:
		return {}
	var key: String = String(m.id)
	if run.fusion_codex.has(key):
		return {}
	run.fusion_codex.append(key)
	return {&"kind": &"part", &"key": key, &"name": m.display_name, &"signature": m.signature}

# --- Incubator -----------------------------------------------------------------

## Number of mutations installed on a monster.
static func mutation_count(m: MonsterData) -> int:
	var n: int = 0
	if m != null:
		for value: Variant in m.slots.values():
			if value is MutationData:
				n += 1
	return n

## Why these two monsters cannot be incubated ("" if they can). Gold is not
## checked here (see incubate()).
static func incubate_block_reason(a: MonsterData, b: MonsterData) -> String:
	if a == null or b == null:
		return "Pick two monsters"
	if a == b:
		return "Pick two different monsters"
	if a.mushed or b.mushed:
		return "Mush cannot be incubated"
	if mutation_count(a) < Tuning.FUSION_MIN_MUTATIONS \
			or mutation_count(b) < Tuning.FUSION_MIN_MUTATIONS:
		return "Each monster needs %d mutations" % Tuning.FUSION_MIN_MUTATIONS
	return ""

## Rows {label: String, value: int} that sum (before clamping) to the Incubator
## success %. Zero rows are omitted, except Base. Same conventions as
## LabLogic.chance_breakdown; `run` may be null (no run bonuses).
static func incubate_breakdown(run: RunState, a: MonsterData, b: MonsterData,
		stabilizers_used: int = 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{&"label": "Base", &"value": Tuning.FUSION_BASE_CHANCE}]
	var used: int = clampi(stabilizers_used, 0, Tuning.STABILIZER_MAX)
	var avg: float = 0.0
	if a != null and b != null:
		avg = (a.instability + b.instability) / 2.0
	var parts: Array = [
		["Avg instability", -roundi(avg)],
		["Stabilizers", used * Tuning.STABILIZER_BONUS],
		["Mush Memory", run.mush_memory if run != null else 0],
		["Lucky Gene", Tuning.LUCKY_GENE_BONUS if run != null and run.lucky_gene else 0],
		["Skills", SkillEffects.fusion_bonus(run.skill_ranks) if run != null else 0],
	]
	for p: Array in parts:
		if int(p[1]) != 0:
			rows.append({&"label": p[0] as String, &"value": int(p[1])})
	if LabLogic.is_safe(run):
		var sum: int = 0
		for row: Dictionary in rows:
			sum += int(row[&"value"])
		rows.append({&"label": "Round 1: safe", &"value": 100 - sum})
	return rows

## Incubator success % (clamped to FUSION_MIN_CHANCE..FUSION_MAX_CHANCE).
static func incubate_chance(run: RunState, a: MonsterData, b: MonsterData,
		stabilizers_used: int = 0) -> int:
	var total: int = 0
	for row: Dictionary in incubate_breakdown(run, a, b, stabilizers_used):
		total += int(row[&"value"])
	if LabLogic.is_safe(run):
		return 100
	return clampi(total, Tuning.FUSION_MIN_CHANCE, Tuning.FUSION_MAX_CHANCE)

## What incubating `a` and `b` would give. Returns
## {&"slots": {slot: {&"kind", &"result", &"options", &"abilities", &"need_keep"}},
##  &"chance": int, &"cost": int, &"ok": bool, &"reason": String}.
## Per slot (only slots at least one parent fills):
## - &"carry": one parent fills it; result = that mutation, options = [it].
## - &"merge": both fill it and can merge; result = the fused part, options =
##   [a's, b's], abilities = ability_choices(), need_keep = true if the player
##   must choose which abilities survive.
## - &"choose": both fill it but cannot merge; options = [a's, b's], result = the
##   picked one.
## `choices` (optional) is the same dictionary incubate() takes: slot -> int
## (0 = a's part, 1 = b's) for a choose slot, slot -> Array[int] (`keep`) for a
## merge slot. `chance` here has no stabilizers or run bonuses; use
## incubate_chance() for the live number.
static func incubate_preview(a: MonsterData, b: MonsterData,
		choices: Dictionary = {}) -> Dictionary:
	var reason: String = incubate_block_reason(a, b)
	var slots: Dictionary = {}
	if a != null and b != null:
		for slot: StringName in MonsterData.SLOTS:
			var ma: MutationData = a.slots.get(slot) as MutationData
			var mb: MutationData = b.slots.get(slot) as MutationData
			if ma == null and mb == null:
				continue
			var row: Dictionary = {&"kind": &"carry", &"result": null, &"options": [],
				&"abilities": [], &"need_keep": false}
			if ma == null or mb == null:
				var only: MutationData = ma if ma != null else mb
				row[&"result"] = only
				row[&"options"] = [only]
			elif can_merge(ma, mb):
				var offered: Array[AbilityData] = ability_choices(ma, mb)
				row[&"kind"] = &"merge"
				row[&"options"] = [ma, mb]
				row[&"abilities"] = offered
				row[&"need_keep"] = offered.size() > Tuning.FUSION_MAX_ABILITIES
				row[&"result"] = merge(ma, mb, _keep_from(choices.get(slot)))
			else:
				row[&"kind"] = &"choose"
				row[&"options"] = [ma, mb]
				var pick: Variant = choices.get(slot, 0)
				row[&"result"] = mb if (pick is int or pick is float) and int(pick) == 1 else ma
			slots[slot] = row
	return {&"slots": slots, &"chance": incubate_chance(null, a, b, 0),
		&"cost": Tuning.FUSION_COST, &"ok": reason == "", &"reason": reason}

## Incubates roster[a_idx] and roster[b_idx] for Tuning.FUSION_COST gold.
## Invalid input returns {ok=false, reason} and changes nothing. Otherwise returns
## {ok=true, success, monster, new_codex, chance, roll, insured, mushed,
##  roster_index, refund}. Conventions follow LabLogic.operate: stabilizers that
## count are consumed, Mush Memory and Lucky Gene are consumed by the roll,
## Insurance saves both parents from a failed roll (gold is still spent), a real
## failure mushes BOTH parents (they stay in the roster, leave the formation) and
## grants Mush Memory. Catalyst is not used by the Incubator.
##
## On success the fused monster takes parent A's roster index and parent B is
## removed, so every roster index above b_idx drops by one. run.formation is
## remapped here: the fused monster keeps A's spot (or B's if A had none), and
## later indices are shifted. `roster_index` is the fused monster's new index;
## callers holding other roster indices must refresh them.
##
## `new_codex` lists {&"kind": &"part"|&"title", &"key", &"name", &"signature"}
## for every fused part and title new to this run (run.fusion_codex /
## run.fusion_titles are updated here). Persisting them is the caller's job:
## CodexStore.record(result[&"new_codex"]).
static func incubate(run: RunState, a_idx: int, b_idx: int, choices: Dictionary,
		rng: RandomNumberGenerator, stabilizers_used: int = 0) -> Dictionary:
	if a_idx < 0 or a_idx >= run.roster.size() or b_idx < 0 or b_idx >= run.roster.size():
		return {&"ok": false, &"reason": "No such monster"}
	if a_idx == b_idx:
		return {&"ok": false, &"reason": "Pick two different monsters"}
	var a: MonsterData = run.roster[a_idx]
	var b: MonsterData = run.roster[b_idx]
	var preview: Dictionary = incubate_preview(a, b, choices)
	if not bool(preview[&"ok"]):
		return {&"ok": false, &"reason": String(preview[&"reason"])}
	if run.gold < Tuning.FUSION_COST:
		return {&"ok": false, &"reason": "Not enough gold"}
	if stabilizers_used < 0 or stabilizers_used > run.stabilizers:
		return {&"ok": false, &"reason": "Not enough stabilizers"}

	var chance: int = incubate_chance(run, a, b, stabilizers_used)
	run.gold -= Tuning.FUSION_COST
	run.stabilizers -= mini(stabilizers_used, Tuning.STABILIZER_MAX)
	var roll: int = rng.randi_range(1, 100)
	var success: bool = roll <= chance
	run.mush_memory = 0
	run.lucky_gene = false

	var new_codex: Array[Dictionary] = []
	var result: Dictionary = {&"ok": true, &"success": success, &"monster": null,
		&"new_codex": new_codex, &"chance": chance, &"roll": roll, &"insured": false,
		&"mushed": false, &"roster_index": -1, &"refund": 0}
	if success:
		var fused: MonsterData = _build_fused(run, a, b, preview[&"slots"] as Dictionary)
		for slot: StringName in MonsterData.SLOTS:
			var entry: Dictionary = record_part(run, fused.slots.get(slot) as MutationData)
			if not entry.is_empty():
				new_codex.append(entry)
		if not run.fusion_titles.has(fused.title):
			run.fusion_titles.append(fused.title)
			new_codex.append({&"kind": &"title", &"key": fused.title, &"name": fused.title,
				&"signature": false})
		result[&"monster"] = fused
		result[&"roster_index"] = _replace_parents(run, a_idx, b_idx, fused)
	elif run.insurance:
		run.insurance = false
		result[&"insured"] = true
	else:
		a.mushed = true
		b.mushed = true
		run.mush_memory = Tuning.MUSH_MEMORY_BONUS
		for spot: Variant in run.formation.keys():
			var idx: int = int(run.formation[spot])
			if idx == a_idx or idx == b_idx:
				run.formation.erase(spot)
		result[&"mushed"] = true
	return result

# --- Internals -----------------------------------------------------------------

static func _sorted_ids(a: MutationData, b: MutationData) -> Array[String]:
	var ids: Array[String] = []
	for id: StringName in base_ids(a):
		ids.append(String(id))
	for id: StringName in base_ids(b):
		ids.append(String(id))
	ids.sort()
	return ids

## Parent order: an already fused parent first, otherwise sorted by id.
static func _ordered(a: MutationData, b: MutationData) -> Array[MutationData]:
	var swap: bool = false
	if a.merge_count != b.merge_count:
		swap = b.merge_count > a.merge_count
	else:
		swap = String(b.id) < String(a.id)
	var result: Array[MutationData] = [a, b]
	if swap:
		result.reverse()
	return result

static func _stat_mult(merge_count: int, is_signature: bool) -> float:
	if is_signature:
		return Tuning.FUSION_SIGNATURE_STAT_MULT
	var i: int = clampi(merge_count, 0, Tuning.FUSION_PART_STAT_MULT.size() - 1)
	return Tuning.FUSION_PART_STAT_MULT[i]

static func _mods(m: MutationData) -> Array[float]:
	var mods: Array[float] = [m.hp_mod, m.atk_mod, m.interval_mod, m.defense_mod, m.crit_mod]
	return mods

## [hp, atk, interval, defense, crit] summed over the base parents of `m`. Base
## parents are looked up by id; if one is unknown the sum is recovered from the
## fused part's own (already multiplied) stats.
static func _base_stat_sum(m: MutationData) -> Array[float]:
	if m.merge_count <= 0 or m.parent_ids.is_empty():
		return _mods(m)
	var total: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	for id: StringName in m.parent_ids:
		var base: MutationData = EnemyGen.mutation_by_id(id)
		if base == null:
			var own: Array[float] = _mods(m)
			var mult: float = _stat_mult(m.merge_count, m.signature)
			for i: int in own.size():
				own[i] = own[i] / mult if mult > 0.0 else own[i]
			return own
		var mods: Array[float] = _mods(base)
		for i: int in total.size():
			total[i] += mods[i]
	return total

## One description sentence per ability of `m`: the stored texts of a fused part,
## or the last line of a base mutation's description.
static func _texts_of(m: MutationData) -> Array[String]:
	var count: int = m.all_abilities().size()
	var texts: Array[String] = []
	if m.ability_texts.size() == count:
		texts.assign(m.ability_texts)
		return texts
	var lines: PackedStringArray = m.description.strip_edges().split("\n", false)
	for i: int in count:
		texts.append(lines[lines.size() - 1].strip_edges() if i == 0 and lines.size() > 1 else "")
	return texts

## Array of [AbilityData, String sentence] offered by merging `a` and `b`.
static func _ability_entries(a: MutationData, b: MutationData) -> Array:
	var entries: Array = []
	if a == null or b == null:
		return entries
	var ordered: Array[MutationData] = _ordered(a, b)
	var twin: bool = a.merge_count == 0 and b.merge_count == 0 and a.id == b.id
	if twin:
		var own: Array[AbilityData] = ordered[0].all_abilities()
		if not own.is_empty():
			var text: String = _texts_of(ordered[0])[0]
			entries.append([own[0].empowered(Tuning.FUSION_TWIN_POWER),
				TEXT_TWIN_ABILITY % [String.num(Tuning.FUSION_TWIN_POWER, 2), text]])
		return entries
	for parent: MutationData in ordered:
		var abilities: Array[AbilityData] = parent.all_abilities()
		var texts: Array[String] = _texts_of(parent)
		for i: int in abilities.size():
			entries.append([abilities[i], texts[i]])
	return entries

static func _kept_entries(entries: Array, keep: Array[int]) -> Array:
	var limit: int = Tuning.FUSION_MAX_ABILITIES
	if entries.size() <= limit:
		return entries
	var picked: Array[int] = []
	for i: int in keep:
		if i >= 0 and i < entries.size() and not picked.has(i) and picked.size() < limit:
			picked.append(i)
	for i: int in entries.size():
		if picked.size() >= limit:
			break
		if not picked.has(i):
			picked.append(i)
	picked.sort()
	var kept: Array = []
	for i: int in picked:
		kept.append(entries[i])
	return kept

static func _keep_from(value: Variant) -> Array[int]:
	var keep: Array[int] = []
	if value is Array:
		for v: Variant in value as Array:
			if v is int or v is float:
				keep.append(int(v))
	return keep

static func _fused_name(first: MutationData, second: MutationData, merge_count: int,
		sig: Dictionary) -> String:
	if not sig.is_empty() and String(sig.get("name", "")) != "":
		return String(sig["name"])
	if merge_count > 1:
		return NAME_APEX % first.display_name
	if first.id == second.id:
		return NAME_TWIN % first.display_name
	# `first`/`second` are in sorted id order, which is the tie order.
	var low: MutationData = first
	var high: MutationData = second
	if int(second.rarity) < int(first.rarity):
		low = second
		high = first
	var low_words: PackedStringArray = low.display_name.split(" ", false)
	var high_words: PackedStringArray = high.display_name.split(" ", false)
	if low_words.is_empty() or high_words.is_empty():
		return NAME_HYBRID_FALLBACK % (low.display_name + high.display_name)
	var hybrid: String = "%s %s" % [low_words[0], high_words[high_words.size() - 1]]
	if hybrid == first.display_name or hybrid == second.display_name:
		return NAME_HYBRID_FALLBACK % hybrid
	return hybrid

static func _signed(value: float, decimals: int) -> String:
	var text: String = String.num(absf(value), decimals)
	return ("+" if value >= 0.0 else "-") + text

## Signed display text of a stat value: a whole number when it rounds to one,
## otherwise one decimal ("+36", "-58.5", "+1.6"). Display only; the stored
## modifiers are never rounded.
static func _tidy(value: float) -> String:
	var shown: float = snappedf(absf(value), 0.1)
	var text: String = str(roundi(shown)) if is_equal_approx(shown, roundf(shown)) 		else "%.1f" % shown
	return ("+" if value >= 0.0 else "-") + text

## "-75 HP, +3.8 ATK." style line of the non-zero stat mods ("" if none).
static func stat_line(m: MutationData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if not is_zero_approx(m.hp_mod):
		parts.append("%s HP" % _tidy(m.hp_mod))
	if not is_zero_approx(m.atk_mod):
		parts.append("%s ATK" % _tidy(m.atk_mod))
	if not is_zero_approx(m.defense_mod):
		parts.append("%s DEF" % _tidy(m.defense_mod))
	if not is_zero_approx(m.interval_mod):
		parts.append("%ss attack interval" % _signed(m.interval_mod, 2))
	if not is_zero_approx(m.crit_mod):
		parts.append("%s%% crit" % _tidy(m.crit_mod * 100.0))
	return ", ".join(parts) + "." if not parts.is_empty() else ""

static func _fused_description(first: MutationData, second: MutationData, r: MutationData,
		sig: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if not sig.is_empty() and String(sig.get("desc", "")) != "":
		lines.append(String(sig["desc"]))
	lines.append(TEXT_PARENTS % [first.display_name, second.display_name])
	var stats: String = stat_line(r)
	if stats != "":
		lines.append(stats)
	for text: String in r.ability_texts:
		if text != "":
			lines.append(text)
	return "\n".join(lines)

static func _first_word(text: String) -> String:
	var words: PackedStringArray = text.split(" ", false)
	return words[0] if not words.is_empty() else text

## The title a fused monster with these parts (slot -> MutationData) would get.
## Lets the Incubator show the title before committing.
static func fused_title(slots: Dictionary) -> String:
	return _fused_title(slots)

static func _fused_title(slots: Dictionary) -> String:
	# The two most expensive parts (slot order breaks ties) name the chimera.
	var best: Array[MutationData] = []
	for slot: StringName in MonsterData.SLOTS:
		var m: MutationData = slots.get(slot) as MutationData
		if m == null:
			continue
		var at: int = best.size()
		for i: int in best.size():
			if EnemyGen.cost_of(m) > EnemyGen.cost_of(best[i]):
				at = i
				break
		best.insert(at, m)
	if best.is_empty():
		return TITLE_NONE
	if best.size() == 1:
		return TITLE_ONE % _first_word(best[0].display_name)
	return TITLE_TWO % [_first_word(best[0].display_name), _first_word(best[1].display_name)]

static func _build_fused(run: RunState, a: MonsterData, b: MonsterData,
		slot_rows: Dictionary) -> MonsterData:
	var m: MonsterData = MonsterData.new()
	m.base_kind = a.base_kind
	var k: float = Tuning.FUSION_STAT_MULT * Tuning.FUSION_BOOST
	m.base_hp = k * (a.base_hp + b.base_hp)
	m.base_atk = k * (a.base_atk + b.base_atk)
	m.base_defense = k * (a.base_defense + b.base_defense)
	m.base_crit = k * (a.base_crit + b.base_crit)
	# Attack interval is a time, not a power stat: the body keeps the parents' mean.
	m.base_interval = (a.base_interval + b.base_interval) / 2.0
	var slots: Dictionary = {}
	for slot: StringName in MonsterData.SLOTS:
		if slot_rows.has(slot):
			var part: MutationData = (slot_rows[slot] as Dictionary)[&"result"] as MutationData
			if part != null:
				slots[slot] = part
	m.slots = slots
	m.fused = true
	m.instability = float(Tuning.FUSION_START_INSTABILITY)
	m.title = _fused_title(slots)
	var made: int = 1
	for other: MonsterData in run.roster:
		if other != null and other.fused:
			made += 1
	m.display_name = NAME_FUSED_MONSTER % made
	return m

## Puts `fused` at a_idx, removes b_idx, remaps run.formation. Returns the fused
## monster's new roster index.
static func _replace_parents(run: RunState, a_idx: int, b_idx: int, fused: MonsterData) -> int:
	run.roster[a_idx] = fused
	run.roster.remove_at(b_idx)
	var a_has_spot: bool = run.formation.values().has(a_idx)
	var new_idx: int = a_idx - 1 if b_idx < a_idx else a_idx
	var remapped: Dictionary = {}
	for spot: Variant in run.formation.keys():
		var idx: int = int(run.formation[spot])
		if idx == b_idx:
			if a_has_spot:
				continue
			idx = a_idx
		remapped[spot] = idx - 1 if idx > b_idx else idx
	run.formation = remapped
	return new_idx
