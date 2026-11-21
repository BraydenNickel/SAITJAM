class_name RewardLogic
extends RefCounted
## Post-battle rewards (stage 3): pick 1 of REWARD_CHOICES. Option dict:
## {id: StringName, title: String, description: String, mutation: MutationData or null}.
## Pure logic; mutates the RunState passed in.

## All option ids in a stable order.
const IDS: Array[StringName] = [
	&"free_mutation", &"stabilizers", &"gold", &"free_human",
	&"cleanse", &"lucky_gene", &"insurance", &"catalyst",
]

## REWARD_CHOICES distinct, currently useful options (fewer if not enough are valid).
static func roll_options(run: RunState, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var valid: Array[StringName] = []
	for id: StringName in IDS:
		if _is_valid(run, id):
			valid.append(id)
	# Deterministic Fisher-Yates with the passed rng.
	for i: int in range(valid.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: StringName = valid[i]
		valid[i] = valid[j]
		valid[j] = tmp
	var result: Array[Dictionary] = []
	for i: int in mini(Tuning.REWARD_CHOICES, valid.size()):
		result.append(_make(run, valid[i], rng))
	return result

## Grants `option` (a dict from roll_options).
static func apply(run: RunState, option: Dictionary) -> void:
	match option.get(&"id", &"") as StringName:
		&"free_mutation":
			var m: MutationData = option.get(&"mutation") as MutationData
			if m != null:
				run.inventory.append(m)
		&"stabilizers":
			run.stabilizers += Tuning.REWARD_STABILIZERS
		&"gold":
			run.gold += Tuning.REWARD_GOLD
		&"free_human":
			ShopLogic.add_human(run)
		&"cleanse":
			var target: MonsterData = _most_unstable(run)
			if target != null:
				target.instability = maxf(0.0, target.instability - Tuning.CLEANSE_AMOUNT)
		&"lucky_gene":
			run.lucky_gene = true
		&"insurance":
			run.insurance = true
		&"catalyst":
			run.catalyst = true

static func _is_valid(run: RunState, id: StringName) -> bool:
	match id:
		&"free_human":
			return run.living_count() < Tuning.ROSTER_MAX
		&"cleanse":
			return _most_unstable(run) != null
		&"lucky_gene":
			return not run.lucky_gene
		&"insurance":
			return not run.insurance
		&"catalyst":
			return not run.catalyst
		&"free_mutation":
			return not EnemyGen.all_mutations().is_empty()
	return true

static func _make(run: RunState, id: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var m: MutationData = null
	var title: String = ""
	var desc: String = ""
	match id:
		&"free_mutation":
			m = ShopLogic.random_mutation(run, rng)
			title = "Free %s" % m.display_name
			desc = "Add %s (%s) to your inventory." % [m.display_name,
				MutationData.Rarity.keys()[int(m.rarity)].capitalize()]
		&"stabilizers":
			title = "Stabilizers"
			desc = "Gain %d stabilizers (+%d%% success each, max %d per operation)." % [
				Tuning.REWARD_STABILIZERS, Tuning.STABILIZER_BONUS, Tuning.STABILIZER_MAX]
		&"gold":
			title = "Grant Money"
			desc = "Gain %d gold." % Tuning.REWARD_GOLD
		&"free_human":
			title = "Volunteer"
			desc = "A new human subject joins your roster (max %d living)." % Tuning.ROSTER_MAX
		&"cleanse":
			title = "Cleanse"
			desc = "Your most unstable monster loses %d instability." % Tuning.CLEANSE_AMOUNT
		&"lucky_gene":
			title = "Lucky Gene"
			desc = "+%d%% success on your next operation." % Tuning.LUCKY_GENE_BONUS
		&"insurance":
			title = "Insurance"
			desc = "If your next operation fails, the monster is unharmed (the mutation is lost)."
		&"catalyst":
			title = "Catalyst"
			desc = "Your next successful operation adds 0 instability."
	return {&"id": id, &"title": title, &"description": desc, &"mutation": m}

## Living monster with the highest instability > 0 (first on ties), or null.
static func _most_unstable(run: RunState) -> MonsterData:
	var best: MonsterData = null
	for m: MonsterData in run.roster:
		if m == null or m.mushed or m.instability <= 0.0:
			continue
		if best == null or m.instability > best.instability:
			best = m
	return best
