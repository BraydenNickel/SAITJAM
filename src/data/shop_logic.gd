class_name ShopLogic
extends RefCounted
## Shop (stage 3, handoff.md section 2 "Shop"): SHOP_MUTATION_SLOTS mutations,
## 1 human, 1 stabilizer. Stock entry: {kind: StringName, mutation: MutationData
## or null, price: int, sold: bool}. Pure logic; mutates the RunState passed in.

const KIND_MUTATION: StringName = &"mutation"
const KIND_HUMAN: StringName = &"human"
const KIND_STABILIZER: StringName = &"stabilizer"

## Rolls new stock once per battle_index (repeat visits keep the same stock).
static func ensure_stock(run: RunState, rng: RandomNumberGenerator) -> void:
	if run.shop_stock_battle == run.battle_index:
		return
	roll_stock(run, rng)
	run.shop_stock_battle = run.battle_index
	run.reroll_count = 0

## Replaces the stock. Applies the rare pity and updates shop_visits_since_rare.
static func roll_stock(run: RunState, rng: RandomNumberGenerator) -> void:
	var stock: Array[Dictionary] = []
	var has_rare: bool = false
	# Ids already in this stock: rolls avoid them while another option exists.
	var taken: Array[StringName] = []
	for i: int in Tuning.SHOP_MUTATION_SLOTS:
		var m: MutationData = random_mutation(run, rng, taken)
		if m != null and m.rarity == MutationData.Rarity.RARE:
			has_rare = true
		if m != null:
			taken.append(m.id)
		stock.append(_mutation_entry(m))
	if not has_rare and run.shop_visits_since_rare >= Tuning.SHOP_RARE_PITY \
			and Tuning.SHOP_MUTATION_SLOTS > 0:
		# The last slot is replaced, so its own id does not count as taken.
		taken.resize(Tuning.SHOP_MUTATION_SLOTS - 1)
		var rare: MutationData = _of_rarity(MutationData.Rarity.RARE, rng, taken)
		if rare == null:
			rare = _of_rarity(MutationData.Rarity.RARE, rng)
		if rare != null:
			stock[Tuning.SHOP_MUTATION_SLOTS - 1] = _mutation_entry(rare)
			has_rare = true
	stock.append({&"kind": KIND_HUMAN, &"mutation": null, &"price": Tuning.PRICE_HUMAN,
		&"sold": false})
	stock.append({&"kind": KIND_STABILIZER, &"mutation": null,
		&"price": Tuning.PRICE_STABILIZER, &"sold": false})
	run.shop_stock = stock
	run.shop_visits_since_rare = 0 if has_rare else run.shop_visits_since_rare + 1

## Random mutation using RARITY_WEIGHTS (rare + RARE_WEIGHT_PER_BATTLE * battle).
## Falls back to any mutation if none exists at the rolled rarity. Ids in
## `exclude` are avoided: first another mutation of the rolled rarity, then any
## non-excluded mutation, and only if every mutation is excluded a duplicate.
static func random_mutation(run: RunState, rng: RandomNumberGenerator,
		exclude: Array[StringName] = []) -> MutationData:
	var weights: Array[int] = Tuning.RARITY_WEIGHTS.duplicate()
	weights[MutationData.Rarity.RARE] += Tuning.RARE_WEIGHT_PER_BATTLE * run.battle_index
	var total: int = 0
	for w: int in weights:
		total += w
	var pick: int = rng.randi_range(1, maxi(total, 1))
	var rarity: int = 0
	for r: int in weights.size():
		pick -= weights[r]
		if pick <= 0:
			rarity = r
			break
	var m: MutationData = _of_rarity(rarity, rng, exclude)
	if m != null:
		return m
	var pool: Array[MutationData] = []
	for p: MutationData in EnemyGen.all_mutations():
		if not exclude.has(p.id):
			pool.append(p)
	if pool.is_empty():
		pool = EnemyGen.all_mutations()
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]

## Gold cost of the next reroll.
static func reroll_cost(run: RunState) -> int:
	return Tuning.REROLL_BASE + Tuning.REROLL_STEP * run.reroll_count

## Pays reroll_cost and rolls new stock. Returns false if gold is short.
static func reroll(run: RunState, rng: RandomNumberGenerator) -> bool:
	var cost: int = reroll_cost(run)
	if run.gold < cost:
		return false
	run.gold -= cost
	run.reroll_count += 1
	roll_stock(run, rng)
	return true

## "" if shop_stock[idx] can be bought, else a player-facing reason.
static func can_buy(run: RunState, idx: int) -> String:
	if idx < 0 or idx >= run.shop_stock.size():
		return "Invalid"
	var e: Dictionary = run.shop_stock[idx]
	if bool(e[&"sold"]):
		return "Sold"
	if run.gold < int(e[&"price"]):
		return "Not enough gold"
	if e[&"kind"] == KIND_HUMAN and run.living_count() >= Tuning.ROSTER_MAX:
		return "Roster full"
	return ""

## Buys shop_stock[idx]: pays, marks it sold, and delivers the goods.
static func buy(run: RunState, idx: int) -> bool:
	if can_buy(run, idx) != "":
		return false
	var e: Dictionary = run.shop_stock[idx]
	run.gold -= int(e[&"price"])
	e[&"sold"] = true
	match e[&"kind"] as StringName:
		KIND_MUTATION:
			run.inventory.append(e[&"mutation"] as MutationData)
		KIND_HUMAN:
			add_human(run)
		KIND_STABILIZER:
			run.stabilizers += 1
	return true

## Appends a fresh human "Subject NN" (NN = roster.size() + 1) and auto-places
## it in the lowest free formation spot if fewer than MAX_TEAM are placed.
static func add_human(run: RunState) -> MonsterData:
	var base: MonsterData = load(EnemyGen.HUMAN_PATH) as MonsterData
	var h: MonsterData = base.clone() if base != null else MonsterData.new()
	h.display_name = "Subject %02d" % (run.roster.size() + 1)
	run.roster.append(h)
	if run.formation.size() < Tuning.MAX_TEAM:
		for spot: int in Tuning.FORMATION_ROWS * Tuning.FORMATION_COLS:
			if not run.formation.has(spot):
				run.formation[spot] = run.roster.size() - 1
				break
	return h

static func _mutation_entry(m: MutationData) -> Dictionary:
	return {&"kind": KIND_MUTATION, &"mutation": m,
		&"price": LabLogic.price_of(m) if m != null else 0, &"sold": false}

## Random mutation of `rarity` whose id is not in `exclude`, or null.
static func _of_rarity(rarity: int, rng: RandomNumberGenerator,
		exclude: Array[StringName] = []) -> MutationData:
	var options: Array[MutationData] = []
	for m: MutationData in EnemyGen.all_mutations():
		if int(m.rarity) == rarity and not exclude.has(m.id):
			options.append(m)
	if options.is_empty():
		return null
	return options[rng.randi_range(0, options.size() - 1)]
