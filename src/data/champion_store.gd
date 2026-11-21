class_name ChampionStore
extends Resource
## Persistent champion (handoff.md §2 "Champion"): the team that won the last
## run's final battle, saved to user:// as this Resource and used as the next
## run's battle-5 boss (EnemyGen.champion_team). Static API; every function takes
## the file path so tests never touch the real save.

## The real save file.
const DEFAULT_PATH: String = "user://champion.tres"

## Deep copies of the champion monsters (fused parts embedded, base mutation
## .tres files referenced by path).
@export var team: Array[MonsterData] = []

## Saves the living (non-mush, non-null) monsters of `source`, at most
## Tuning.MAX_TEAM, as the champion. Overwrites any earlier champion.
## Returns false if no monster qualifies or the file cannot be written.
static func save_team(source: Array[MonsterData], path: String = DEFAULT_PATH) -> bool:
	var store: ChampionStore = ChampionStore.new()
	for mon: MonsterData in source:
		if mon == null or mon.mushed:
			continue
		if store.team.size() >= Tuning.MAX_TEAM:
			break
		store.team.append(mon.duplicate_deep() as MonsterData)
	if store.team.is_empty():
		return false
	return ResourceSaver.save(store, path) == OK

## The saved champion team (fresh copies, never the cached file), or [] if there
## is no readable champion.
static func load_team(path: String = DEFAULT_PATH) -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	if not FileAccess.file_exists(path):
		return out
	var store: ChampionStore = ResourceLoader.load(path, "",
		ResourceLoader.CACHE_MODE_IGNORE) as ChampionStore
	if store == null:
		return out
	for mon: MonsterData in store.team:
		if mon != null and not mon.mushed:
			out.append(mon)
	return out

## True if a champion with at least one monster is saved at `path`.
static func has_champion(path: String = DEFAULT_PATH) -> bool:
	return not load_team(path).is_empty()

## Deletes the saved champion (tests, or a future "reset progress" option).
static func clear(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
