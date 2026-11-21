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

## Budget cost of one mutation.
static func cost_of(m: MutationData) -> int:
	return Tuning.BUDGET_COST[int(m.rarity)]

## Returns {team: Array[MonsterData], spots: Array[int], archetypes: Array[StringName]}.
## Battle index 4 is the "Dr. Splice" boss team (stage 4 replaces it with the champion).
static func generate(battle_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var i: int = clampi(battle_index, 0, Tuning.ENEMY_BUDGET.size() - 1)
	var size: int = Tuning.ENEMY_TEAM_SIZE[i]
	var budget: int = Tuning.ENEMY_BUDGET[i]
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
		var arch: StringName = &""
		if rng.randf() < Tuning.ENEMY_ARCHETYPE_CHANCE:
			arch = archetype_names[rng.randi_range(0, archetype_names.size() - 1)]
		archetypes.append(arch)

	# Spend the budget round-robin; each monster prefers its archetype parts.
	var stuck: int = 0
	var n: int = 0
	while budget > 0 and stuck < size:
		var m: MonsterData = team[n]
		var choice: Array = _pick(m, archetypes[n], pool, budget, rng)
		if choice.is_empty():
			stuck += 1
		else:
			stuck = 0
			m.apply_mutation(choice[0] as MutationData, choice[1] as StringName)
			budget -= cost_of(choice[0] as MutationData)
		n = (n + 1) % size

	return {&"team": team, &"spots": _place(archetypes, rng), &"archetypes": archetypes}

## [mutation, slot] affordable and socket-legal for `m`, or [] if none.
static func _pick(m: MonsterData, arch: StringName, pool: Array[MutationData], budget: int,
		rng: RandomNumberGenerator) -> Array:
	var preferred: Array = Tuning.ENEMY_ARCHETYPES.get(arch, [])
	var fits: Array = []
	var fits_pref: Array = []
	for mut: MutationData in pool:
		if cost_of(mut) > budget:
			continue
		var free: Array[StringName] = m.slots_for(mut)
		if free.is_empty():
			continue
		var option: Array = [mut, free[0]]
		fits.append(option)
		if preferred.has(mut.id):
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
