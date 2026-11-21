class_name UltraRarityTest
extends GdUnitTestSuite
## ULTRA rarity (design/balance/stage4-mutations.md section 1): every
## rarity-indexed table has an entry for it, enemies only receive ULTRA
## mutations from Tuning.ULTRA_ENEMY_MIN_BATTLE on, the shop rolls it through
## RARITY_WEIGHTS while the pity stays rare-only, and archetypes match by tag.

## Seeds tried per battle index when looking for / excluding ULTRA picks.
const SEEDS: int = 40
const ULTRA_COLOR_HEX: String = "ff3df0"
## Player power far above every ADAPT_MAX, so enemies get their largest budget.
const LETHAL_POWER: int = 100000

var _saved_pool: Array[MutationData] = []

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _mut(id: StringName, rarity: MutationData.Rarity, socket: MutationData.SocketType,
		tags: Array[StringName] = []) -> MutationData:
	var m: MutationData = MutationData.new()
	m.id = id
	m.rarity = rarity
	m.socket_type = socket
	m.tags = tags
	return m

## Replaces the mutation pool for one test; after_test() puts the real one back.
func _use_pool(pool: Array[MutationData]) -> void:
	EnemyGen._cache = pool

func before_test() -> void:
	_saved_pool = EnemyGen.all_mutations().duplicate()

func after_test() -> void:
	EnemyGen._cache = _saved_pool

func _ultra_count(team: Array) -> int:
	var n: int = 0
	for m: MonsterData in team:
		for v: Variant in m.slots.values():
			if (v as MutationData).rarity == MutationData.Rarity.ULTRA:
				n += 1
	return n

func test_every_rarity_table_has_an_entry_per_rarity() -> void:
	var n: int = MutationData.Rarity.size()
	assert_int(int(MutationData.Rarity.ULTRA)).is_equal(3)
	assert_int(Tuning.BUDGET_COST.size()).is_equal(n)
	assert_int(Tuning.PRICE_BY_RARITY.size()).is_equal(n)
	assert_int(Tuning.RARITY_WEIGHTS.size()).is_equal(n)
	assert_int(Tuning.INSTABILITY_PER_RARITY.size()).is_equal(n)
	assert_int(Tuning.RISK_PER_RARITY.size()).is_equal(n)
	assert_int(InventoryItem.RARITY_COLORS.size()).is_equal(n)
	assert_int(InventoryItem.RARITY_NAMES.size()).is_equal(n)

func test_ultra_lookups_use_the_fourth_entry() -> void:
	var ultra: MutationData = _mut(&"u", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO)
	var r: int = MutationData.Rarity.ULTRA
	assert_int(EnemyGen.cost_of(ultra)).is_equal(Tuning.BUDGET_COST[r])
	assert_int(LabLogic.price_of(ultra)).is_equal(Tuning.PRICE_BY_RARITY[r])
	assert_str(InventoryItem.rarity_name(r)).is_equal("Ultra")
	assert_str(InventoryItem.rarity_color(r).to_html(false)).is_equal(ULTRA_COLOR_HEX)

func test_ultra_counts_toward_player_power() -> void:
	var ultra: MutationData = _mut(&"u", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO)
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(ultra, &"TORSO")
	var roster: Array[MonsterData] = [mon]
	assert_int(EnemyGen.player_power(roster)).is_equal(Tuning.BUDGET_COST[MutationData.Rarity.ULTRA])

func test_allowed_for_battle_gates_only_ultra() -> void:
	var ultra: MutationData = _mut(&"u", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO)
	var rare: MutationData = _mut(&"r", MutationData.Rarity.RARE, MutationData.SocketType.TORSO)
	for battle: int in Tuning.BATTLES_PER_RUN:
		assert_bool(EnemyGen.allowed_for_battle(ultra, battle)).is_equal(
			battle >= Tuning.ULTRA_ENEMY_MIN_BATTLE)
		assert_bool(EnemyGen.allowed_for_battle(rare, battle)).is_true()

func test_enemies_get_no_ultra_before_min_battle_even_with_max_budget() -> void:
	var pool: Array[MutationData] = [
		_mut(&"u_head", MutationData.Rarity.ULTRA, MutationData.SocketType.HEAD),
		_mut(&"u_torso", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO),
		_mut(&"c_arm", MutationData.Rarity.COMMON, MutationData.SocketType.ARM),
	]
	_use_pool(pool)
	for battle: int in Tuning.ULTRA_ENEMY_MIN_BATTLE:
		for s: int in SEEDS:
			var gen: Dictionary = EnemyGen.generate(battle, _rng(s), LETHAL_POWER)
			assert_int(_ultra_count(gen[&"team"])).override_failure_message(
				"ULTRA on an enemy at battle %d seed %d" % [battle, s]).is_equal(0)

func test_enemies_can_get_ultra_from_min_battle_on() -> void:
	var pool: Array[MutationData] = [
		_mut(&"u_head", MutationData.Rarity.ULTRA, MutationData.SocketType.HEAD),
		_mut(&"u_torso", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO),
		_mut(&"c_arm", MutationData.Rarity.COMMON, MutationData.SocketType.ARM),
	]
	_use_pool(pool)
	for battle: int in range(Tuning.ULTRA_ENEMY_MIN_BATTLE, Tuning.BATTLES_PER_RUN):
		var found: int = 0
		for s: int in SEEDS:
			found += _ultra_count(EnemyGen.generate(battle, _rng(s))[&"team"])
		assert_int(found).is_greater(0)

func test_archetype_prefers_mutations_with_matching_tags() -> void:
	var fire_tags: Array[StringName] = [&"fire", &"gland"]
	var frost_tags: Array[StringName] = [&"frost"]
	var fire: MutationData = _mut(&"f", MutationData.Rarity.COMMON, MutationData.SocketType.BACK, fire_tags)
	var frost: MutationData = _mut(&"i", MutationData.Rarity.COMMON, MutationData.SocketType.BACK, frost_tags)
	var untagged: MutationData = _mut(&"n", MutationData.Rarity.COMMON, MutationData.SocketType.BACK)
	assert_bool(EnemyGen.matches_archetype(fire, &"fire")).is_true()
	assert_bool(EnemyGen.matches_archetype(frost, &"fire")).is_false()
	assert_bool(EnemyGen.matches_archetype(untagged, &"fire")).is_false()
	assert_bool(EnemyGen.matches_archetype(fire, &"")).is_false()
	var pool: Array[MutationData] = [fire, frost, untagged]
	for s: int in SEEDS:
		var pick: Array = EnemyGen._pick(MonsterData.new(), &"fire", pool, 1, _rng(s), 0)
		assert_str(String((pick[0] as MutationData).id)).is_equal("f")

func test_archetypes_keep_legacy_names_and_are_tag_lists() -> void:
	for arch: StringName in [&"venom", &"tank", &"spore"]:
		assert_bool(Tuning.ENEMY_ARCHETYPES.has(arch)).is_true()
	for arch: StringName in Tuning.ENEMY_ARCHETYPES:
		assert_bool((Tuning.ENEMY_ARCHETYPES[arch] as Array).is_empty()).is_false()

func test_real_pool_every_archetype_generation_is_valid() -> void:
	# With whatever mutations are on disk: every battle still builds a legal team.
	for battle: int in Tuning.BATTLES_PER_RUN:
		var gen: Dictionary = EnemyGen.generate(battle, _rng(battle))
		assert_int((gen[&"team"] as Array).size()).is_equal(Tuning.ENEMY_TEAM_SIZE[battle])
		if battle < Tuning.ULTRA_ENEMY_MIN_BATTLE:
			assert_int(_ultra_count(gen[&"team"])).is_equal(0)

func test_shop_rolls_ultra_and_prices_it() -> void:
	var pool: Array[MutationData] = [
		_mut(&"c", MutationData.Rarity.COMMON, MutationData.SocketType.ARM),
		_mut(&"n", MutationData.Rarity.UNCOMMON, MutationData.SocketType.LEG),
		_mut(&"r", MutationData.Rarity.RARE, MutationData.SocketType.TAIL),
		_mut(&"u", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO),
	]
	_use_pool(pool)
	var run: RunState = RunState.new()
	var rng: RandomNumberGenerator = _rng(5)
	var counts: Array[int] = [0, 0, 0, 0]
	var rolls: int = 4000
	for i: int in rolls:
		counts[int(ShopLogic.random_mutation(run, rng).rarity)] += 1
	var total_weight: int = 0
	for w: int in Tuning.RARITY_WEIGHTS:
		total_weight += w
	var expected: float = float(rolls) * Tuning.RARITY_WEIGHTS[MutationData.Rarity.ULTRA] / total_weight
	assert_int(counts[MutationData.Rarity.ULTRA]).is_greater(0)
	assert_float(float(counts[MutationData.Rarity.ULTRA])).is_between(expected * 0.5, expected * 1.5)
	assert_int(counts[MutationData.Rarity.COMMON]).is_greater(counts[MutationData.Rarity.ULTRA])

func test_shop_rare_pity_is_not_satisfied_by_ultra() -> void:
	var pool: Array[MutationData] = [
		_mut(&"u1", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO),
		_mut(&"u2", MutationData.Rarity.ULTRA, MutationData.SocketType.HEAD),
		_mut(&"u3", MutationData.Rarity.ULTRA, MutationData.SocketType.BACK),
		_mut(&"u4", MutationData.Rarity.ULTRA, MutationData.SocketType.ARM),
		_mut(&"r", MutationData.Rarity.RARE, MutationData.SocketType.TAIL),
	]
	_use_pool(pool)
	for s: int in SEEDS:
		var run: RunState = RunState.new()
		run.shop_visits_since_rare = Tuning.SHOP_RARE_PITY
		ShopLogic.roll_stock(run, _rng(s))
		var rares: int = 0
		for e: Dictionary in run.shop_stock:
			var m: MutationData = e[&"mutation"] as MutationData
			if m != null and m.rarity == MutationData.Rarity.RARE:
				rares += 1
		assert_int(rares).is_greater(0)
		assert_int(run.shop_visits_since_rare).is_equal(0)

func test_shop_ultra_only_stock_keeps_pity_counter_growing() -> void:
	var pool: Array[MutationData] = [
		_mut(&"u1", MutationData.Rarity.ULTRA, MutationData.SocketType.TORSO),
		_mut(&"u2", MutationData.Rarity.ULTRA, MutationData.SocketType.HEAD),
		_mut(&"u3", MutationData.Rarity.ULTRA, MutationData.SocketType.BACK),
	]
	_use_pool(pool)
	var run: RunState = RunState.new()
	ShopLogic.roll_stock(run, _rng(1))
	assert_int(run.shop_visits_since_rare).is_equal(1)
	assert_int(int(run.shop_stock[0][&"price"])).is_equal(
		Tuning.PRICE_BY_RARITY[MutationData.Rarity.ULTRA])

func test_spore_archetype_matches_existing_spore_sacs_tags() -> void:
	var sacs: MutationData = load("res://src/data/mutations/spore_sacs.tres") as MutationData
	assert_bool(EnemyGen.matches_archetype(sacs, &"spore")).is_true()
	assert_array(Tuning.ENEMY_ARCHETYPES[&"spore"] as Array).contains([&"spore", &"fungus"])
