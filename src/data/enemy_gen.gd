class_name EnemyGen
extends RefCounted
## Builds enemy teams per battle (stage 2, design/jam-plan.md "CHOSEN DESIGN").
## Team size and mutation budget come from Tuning.ENEMY_TEAM_SIZE / ENEMY_BUDGET;
## each mutation costs Tuning.BUDGET_COST[rarity]. Deterministic for a given rng.

const MUTATIONS_DIR: String = "res://src/data/mutations/"
const HUMAN_PATH: String = "res://src/data/kinds/human.tres"

static var _cache: Array[MutationData] = []

## All mutation resources in MUTATIONS_DIR, sorted by id (stable order).
static func all_mutations() -> Array[MutationData]:
	if not _cache.is_empty():
		return _cache
	var files: PackedStringArray = ResourceLoader.list_directory(MUTATIONS_DIR) \
		if ResourceLoader.has_method(&"list_directory") else DirAccess.get_files_at(MUTATIONS_DIR)
	for f: String in files:
		var name: String = f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var m: MutationData = load(MUTATIONS_DIR + name) as MutationData
		if m != null:
			_cache.append(m)
	_cache.sort_custom(func(a: MutationData, b: MutationData) -> bool: return a.id < b.id)
	return _cache

## False for ULTRA mutations before Tuning.ULTRA_ENEMY_MIN_BATTLE (enemies never
## receive them that early); true for everything else.
static func allowed_for_battle(m: MutationData, battle_index: int) -> bool:
	return m.rarity != MutationData.Rarity.ULTRA or battle_index >= Tuning.ULTRA_ENEMY_MIN_BATTLE

## True if `m` carries at least one of archetype `arch`'s preferred tags
## (Tuning.ENEMY_ARCHETYPES). Unknown or empty archetypes prefer nothing.
static func matches_archetype(m: MutationData, arch: StringName) -> bool:
	var preferred: Array = Tuning.ENEMY_ARCHETYPES.get(arch, [])
	for tag: StringName in m.tags:
		if preferred.has(tag):
			return true
	return false

## Budget cost of one mutation. A fused mutation (fused_cost > 0) costs the sum
## of its parents, so it counts fully toward adaptive scaling.
static func cost_of(m: MutationData) -> int:
	if m.fused_cost > 0:
		return m.fused_cost
	return Tuning.BUDGET_COST[int(m.rarity)]

static var _by_id: Dictionary = {}

## The base mutation with this id from MUTATIONS_DIR, or null.
static func mutation_by_id(id: StringName) -> MutationData:
	if _by_id.is_empty():
		for m: MutationData in all_mutations():
			_by_id[m.id] = m
	return _by_id.get(id) as MutationData

## Player power used by adaptive scaling (design/balance/stage3-tuning.md §6).
## Over the whole living (non-mushed) roster, not the formation, so benching
## cannot game it: sum of cost_of() of every installed mutation, plus
## Tuning.ADAPT_BODY_POWER per living monster beyond Tuning.START_HUMANS.
static func player_power(roster: Array[MonsterData]) -> int:
	var power: int = 0
	var living: int = 0
	for mon: MonsterData in roster:
		if mon == null or mon.mushed:
			continue
		living += 1
		for value: Variant in mon.slots.values():
			var mut: MutationData = value as MutationData
			if mut != null:
				power += cost_of(mut)
	power += Tuning.ADAPT_BODY_POWER * maxi(0, living - Tuning.START_HUMANS)
	return power

## Extra enemy budget for `power` at battle `battle_index` (§6):
## clampi(roundi(ADAPT_RATE * (power - ADAPT_EXPECTED[i])), 0, ADAPT_MAX[i]).
## Never negative: adaptation only makes enemies harder.
static func adapt_bonus(battle_index: int, power: int) -> int:
	var i: int = clampi(battle_index, 0, Tuning.ADAPT_EXPECTED.size() - 1)
	var raw: int = roundi(Tuning.ADAPT_RATE * float(power - Tuning.ADAPT_EXPECTED[i]))
	return clampi(raw, 0, Tuning.ADAPT_MAX[i])

## Returns {team: Array[MonsterData], spots: Array[int], archetypes: Array[StringName],
## adapt: int}. `power` (from player_power()) adds adapt_bonus() to the budget;
## the default 0 gives the unscaled team. Budget the round-robin cannot spend
## (all sockets full) becomes extra base HP: x(1 + ADAPT_HP_PER_POINT * leftover).
## Battle index 4 is the "Dr. Splice" boss team (stage 4 replaces it with the champion).
static func generate(battle_index: int, rng: RandomNumberGenerator,
		power: int = 0) -> Dictionary:
	var i: int = clampi(battle_index, 0, Tuning.ENEMY_BUDGET.size() - 1)
	var size: int = Tuning.ENEMY_TEAM_SIZE[i]
	var bonus: int = adapt_bonus(i, power)
	var budget: int = Tuning.ENEMY_BUDGET[i] + bonus
	var boss: bool = i == Tuning.BATTLES_PER_RUN - 1
	var pool: Array[MutationData] = all_mutations()
	var human: MonsterData = load(HUMAN_PATH) as MonsterData
	var archetype_names: Array = Tuning.ENEMY_ARCHETYPES.keys()

	var team: Array[MonsterData] = []
	var archetypes: Array[StringName] = []
	var used_numbers: Array[int] = []
	for n: int in size:
		var m: MonsterData = human.clone() if human != null else MonsterData.new()
		if boss:
			m.display_name = Tuning.BOSS_NAME if n == 0 else "Splice Subject %02d" % n
		else:
			var num: int = rng.randi_range(1, 99)
			while used_numbers.has(num):
				num = rng.randi_range(1, 99)
			used_numbers.append(num)
			m.display_name = "Feral %02d" % num
		team.append(m)
		# Enemy toughness per battle (design/balance/stage3-tuning.md §1). Base body only,
		# not mutation hp_mod. Stage 4 champions must skip this.
		m.base_hp = Tuning.BASE_HP * Tuning.ENEMY_HP_MULT[i]
		var arch: StringName = &""
		if rng.randf() < Tuning.ENEMY_ARCHETYPE_CHANCE:
			arch = archetype_names[rng.randi_range(0, archetype_names.size() - 1)]
		archetypes.append(arch)

	# Spend the budget round-robin; each monster prefers its archetype parts.
	var stuck: int = 0
	var n: int = 0
	while budget > 0 and stuck < size:
		var m: MonsterData = team[n]
		var choice: Array = _pick(m, archetypes[n], pool, budget, rng, battle_index)
		if choice.is_empty():
			stuck += 1
		else:
			stuck = 0
			m.apply_mutation(choice[0] as MutationData, choice[1] as StringName)
			budget -= cost_of(choice[0] as MutationData)
		n = (n + 1) % size

	# Unspendable adaptive budget becomes toughness (base body only).
	if budget > 0:
		var hp_mult: float = 1.0 + Tuning.ADAPT_HP_PER_POINT * float(budget)
		for m: MonsterData in team:
			m.base_hp *= hp_mult

	return {&"team": team, &"spots": _place(archetypes, rng), &"archetypes": archetypes,
		&"adapt": bonus}

## [mutation, slot] affordable, allowed at this battle and socket-legal for `m`,
## or [] if none. Mutations tagged for the archetype are preferred.
static func _pick(m: MonsterData, arch: StringName, pool: Array[MutationData], budget: int,
		rng: RandomNumberGenerator, battle_index: int) -> Array:
	var has_arch: bool = arch != &""
	var fits: Array = []
	var fits_pref: Array = []
	for mut: MutationData in pool:
		if cost_of(mut) > budget or not allowed_for_battle(mut, battle_index):
			continue
		var free: Array[StringName] = m.slots_for(mut)
		if free.is_empty():
			continue
		var option: Array = [mut, free[0]]
		fits.append(option)
		if has_arch and matches_archetype(mut, arch):
			fits_pref.append(option)
	var from: Array = fits_pref if not fits_pref.is_empty() else fits
	if from.is_empty():
		return []
	return from[rng.randi_range(0, from.size() - 1)]

## Distinct random spots 0-5; tanks take the front-most free row first.
static func _place(archetypes: Array[StringName], rng: RandomNumberGenerator) -> Array[int]:
	var total: int = Tuning.FORMATION_ROWS * Tuning.FORMATION_COLS
	var free: Array[int] = []
	for s: int in total:
		free.append(s)
	var spots: Array[int] = []
	spots.resize(archetypes.size())
	for pass_tanks: bool in [true, false]:
		for n: int in archetypes.size():
			if (archetypes[n] == &"tank") != pass_tanks:
				continue
			var options: Array[int] = []
			if pass_tanks:
				var best: int = 999
				for s: int in free:
					best = mini(best, RunState.row_of(s))
				for s: int in free:
					if RunState.row_of(s) == best:
						options.append(s)
			else:
				options = free.duplicate()
			var pick: int = options[rng.randi_range(0, options.size() - 1)]
			spots[n] = pick
			free.erase(pick)
	return spots
