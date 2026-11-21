class_name ShopLogicTest
extends GdUnitTestSuite
## Unit tests for ShopLogic (stage 3 shop).

func _run(n: int = 2) -> RunState:
	var r: RunState = RunState.new()
	for i: int in n:
		r.roster.append(MonsterData.new())
		r.formation[i] = i
	return r

func _rng(s: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = s
	return rng

func _has_rare(r: RunState) -> bool:
	for e: Dictionary in r.shop_stock:
		var m: MutationData = e[&"mutation"] as MutationData
		if m != null and m.rarity == MutationData.Rarity.RARE:
			return true
	return false

func test_roll_stock_layout() -> void:
	var r: RunState = _run()
	ShopLogic.roll_stock(r, _rng(1))
	assert_int(r.shop_stock.size()).is_equal(Tuning.SHOP_MUTATION_SLOTS + 2)
	for i: int in Tuning.SHOP_MUTATION_SLOTS:
		var e: Dictionary = r.shop_stock[i]
		assert_str(String(e[&"kind"])).is_equal("mutation")
		assert_object(e[&"mutation"]).is_not_null()
		assert_int(e[&"price"] as int).is_equal(LabLogic.price_of(e[&"mutation"] as MutationData))
		assert_bool(e[&"sold"] as bool).is_false()
	assert_str(String(r.shop_stock[-2][&"kind"])).is_equal("human")
	assert_int(r.shop_stock[-2][&"price"] as int).is_equal(Tuning.PRICE_HUMAN)
	assert_str(String(r.shop_stock[-1][&"kind"])).is_equal("stabilizer")
	assert_int(r.shop_stock[-1][&"price"] as int).is_equal(Tuning.PRICE_STABILIZER)

func test_ensure_stock_only_rolls_once_per_battle() -> void:
	var r: RunState = _run()
	r.reroll_count = 2
	ShopLogic.ensure_stock(r, _rng(5))
	assert_int(r.shop_stock_battle).is_equal(0)
	assert_int(r.reroll_count).is_equal(0)
	var first: Array[Dictionary] = r.shop_stock
	r.reroll_count = 1
	ShopLogic.ensure_stock(r, _rng(99))
	assert_bool(is_same(r.shop_stock, first)).is_true()
	assert_int(r.reroll_count).is_equal(1)
	r.battle_index = 1
	ShopLogic.ensure_stock(r, _rng(99))
	assert_int(r.shop_stock_battle).is_equal(1)
	assert_int(r.reroll_count).is_equal(0)

func test_pity_forces_rare() -> void:
	for s: int in 50:
		var r: RunState = _run()
		r.shop_visits_since_rare = Tuning.SHOP_RARE_PITY
		ShopLogic.roll_stock(r, _rng(s))
		assert_bool(_has_rare(r)).is_true()
		assert_int(r.shop_visits_since_rare).is_equal(0)

## Mutation ids in the stock's mutation slots.
func _stock_ids(r: RunState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for i: int in Tuning.SHOP_MUTATION_SLOTS:
		var m: MutationData = r.shop_stock[i][&"mutation"] as MutationData
		ids.append(m.id if m != null else &"")
	return ids

func test_roll_stock_no_duplicate_mutations_when_pool_allows() -> void:
	# Arrange: the pool must hold enough distinct mutations for the guarantee to apply.
	if EnemyGen.all_mutations().size() < Tuning.SHOP_MUTATION_SLOTS:
		return
	for s: int in 300:
		var r: RunState = _run()
		r.battle_index = s % Tuning.BATTLES_PER_RUN
		# Half the seeds also exercise the rare-pity replacement.
		if s % 2 == 1:
			r.shop_visits_since_rare = Tuning.SHOP_RARE_PITY
		# Act
		ShopLogic.roll_stock(r, _rng(s))
		# Assert
		var ids: Array[StringName] = _stock_ids(r)
		for i: int in ids.size():
			assert_int(ids.count(ids[i])).override_failure_message(
				"seed %d: duplicate %s in %s" % [s, ids[i], ids]).is_equal(1)

func test_visits_counter_increments_without_rare() -> void:
	var counted: bool = false
	for s: int in 50:
		var r: RunState = _run()
		ShopLogic.roll_stock(r, _rng(s))
		if _has_rare(r):
			assert_int(r.shop_visits_since_rare).is_equal(0)
		else:
			assert_int(r.shop_visits_since_rare).is_equal(1)
			counted = true
	assert_bool(counted).is_true()

func test_reroll_cost_grows_and_charges() -> void:
	var r: RunState = _run()
	r.gold = 100
	assert_int(ShopLogic.reroll_cost(r)).is_equal(Tuning.REROLL_BASE)
	assert_bool(ShopLogic.reroll(r, _rng(1))).is_true()
	assert_int(r.gold).is_equal(100 - Tuning.REROLL_BASE)
	assert_int(r.reroll_count).is_equal(1)
	assert_int(ShopLogic.reroll_cost(r)).is_equal(Tuning.REROLL_BASE + Tuning.REROLL_STEP)
	r.gold = ShopLogic.reroll_cost(r) - 1
	assert_bool(ShopLogic.reroll(r, _rng(2))).is_false()
	assert_int(r.reroll_count).is_equal(1)

func test_buy_mutation_and_stabilizer() -> void:
	var r: RunState = _run()
	ShopLogic.roll_stock(r, _rng(3))
	r.gold = 0
	assert_str(ShopLogic.can_buy(r, 0)).is_equal("Not enough gold")
	assert_bool(ShopLogic.buy(r, 0)).is_false()
	r.gold = 200
	var price: int = r.shop_stock[0][&"price"]
	assert_bool(ShopLogic.buy(r, 0)).is_true()
	assert_int(r.gold).is_equal(200 - price)
	assert_int(r.inventory.size()).is_equal(1)
	assert_str(ShopLogic.can_buy(r, 0)).is_equal("Sold")
	assert_bool(ShopLogic.buy(r, 0)).is_false()
	assert_bool(ShopLogic.buy(r, r.shop_stock.size() - 1)).is_true()
	assert_int(r.stabilizers).is_equal(1)
	assert_str(ShopLogic.can_buy(r, 99)).is_not_empty()

func test_buy_human_names_and_places() -> void:
	var r: RunState = _run(2)
	ShopLogic.roll_stock(r, _rng(4))
	r.gold = 100
	var idx: int = r.shop_stock.size() - 2
	assert_bool(ShopLogic.buy(r, idx)).is_true()
	assert_int(r.roster.size()).is_equal(3)
	assert_str(r.roster[2].display_name).is_equal("Subject 03")
	assert_int(int(r.formation[2])).is_equal(2)

func test_human_not_placed_when_team_full() -> void:
	var r: RunState = _run(Tuning.MAX_TEAM)
	r.roster[0].mushed = true
	ShopLogic.add_human(r)
	assert_int(r.formation.size()).is_equal(Tuning.MAX_TEAM)

func test_buy_human_roster_full() -> void:
	var r: RunState = _run(Tuning.ROSTER_MAX)
	ShopLogic.roll_stock(r, _rng(4))
	r.gold = 100
	var idx: int = r.shop_stock.size() - 2
	assert_str(ShopLogic.can_buy(r, idx)).is_equal("Roster full")
	r.roster[0].mushed = true
	assert_str(ShopLogic.can_buy(r, idx)).is_equal("")
