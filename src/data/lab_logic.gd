class_name LabLogic
extends RefCounted
## Lab operations (stage 3, handoff.md section 2 "Lab risk"): apply an owned
## mutation with a success roll, or purge one. Pure logic; mutates the RunState
## passed in (including gold). Screens call Game.notify_gold() afterwards.

## Shop price of a mutation (also the base for the mush refund).
static func price_of(m: MutationData) -> int:
	return Tuning.PRICE_BY_RARITY[int(m.rarity)]

## Success % for applying `mutation` to `monster` with `stabilizers_used` stabilizers.
static func success_chance(run: RunState, monster: MonsterData, mutation: MutationData,
		stabilizers_used: int) -> int:
	var total: int = 0
	for row: Dictionary in chance_breakdown(run, monster, mutation, stabilizers_used):
		total += int(row[&"value"])
	return clampi(total, Tuning.MIN_SUCCESS, Tuning.MAX_SUCCESS)

## Rows {label: String, value: int} that sum (before clamping) to the success %.
## Zero rows are omitted, except Base.
static func chance_breakdown(run: RunState, monster: MonsterData, mutation: MutationData,
		stabilizers_used: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{&"label": "Base", &"value": 100}]
	var used: int = clampi(stabilizers_used, 0, Tuning.STABILIZER_MAX)
	var parts: Array = [
		["Instability", -int(monster.instability)],
		["Rarity risk", -Tuning.RISK_PER_RARITY[int(mutation.rarity)]],
		["Stabilizers", used * Tuning.STABILIZER_BONUS],
		["Mush Memory", run.mush_memory],
		["Lucky Gene", Tuning.LUCKY_GENE_BONUS if run.lucky_gene else 0],
	]
	for p: Array in parts:
		if int(p[1]) != 0:
			rows.append({&"label": p[0] as String, &"value": int(p[1])})
	return rows

## Applies inventory[inv_idx] to roster[roster_idx] in `slot` with a success roll.
## Invalid input returns {ok=false, reason}. Otherwise returns
## {ok=true, success, chance, roll, refund, insured, mushed}.
static func operate(run: RunState, roster_idx: int, inv_idx: int, slot: StringName,
		stabilizers_used: int, rng: RandomNumberGenerator) -> Dictionary:
	if roster_idx < 0 or roster_idx >= run.roster.size():
		return {&"ok": false, &"reason": "No such monster"}
	if inv_idx < 0 or inv_idx >= run.inventory.size():
		return {&"ok": false, &"reason": "No such mutation"}
	var monster: MonsterData = run.roster[roster_idx]
	var mutation: MutationData = run.inventory[inv_idx]
	if monster == null or monster.mushed:
		return {&"ok": false, &"reason": "Monster is mush"}
	if not monster.can_apply(mutation, slot):
		return {&"ok": false, &"reason": "Slot not available"}
	if stabilizers_used < 0 or stabilizers_used > run.stabilizers:
		return {&"ok": false, &"reason": "Not enough stabilizers"}

	var chance: int = success_chance(run, monster, mutation, stabilizers_used)
	run.inventory.remove_at(inv_idx)
	# Only the stabilizers that count toward the chance are consumed.
	run.stabilizers -= mini(stabilizers_used, Tuning.STABILIZER_MAX)
	var roll: int = rng.randi_range(1, 100)
	var success: bool = roll <= chance
	run.mush_memory = 0
	run.lucky_gene = false

	var result: Dictionary = {&"ok": true, &"success": success, &"chance": chance,
		&"roll": roll, &"refund": 0, &"insured": false, &"mushed": false}
	if success:
		monster.apply_mutation(mutation, slot)
		if run.catalyst:
			run.catalyst = false
		else:
			monster.instability = minf(100.0,
				monster.instability + Tuning.INSTABILITY_PER_RARITY[int(mutation.rarity)])
		if not run.codex.has(mutation.id):
			run.codex.append(mutation.id)
	elif run.insurance:
		run.insurance = false
		result[&"insured"] = true
	else:
		monster.mushed = true
		var refund: int = roundi(price_of(mutation) * Tuning.MUSH_REFUND)
		run.gold += refund
		run.mush_memory = Tuning.MUSH_MEMORY_BONUS
		for spot: Variant in run.formation.keys():
			if int(run.formation[spot]) == roster_idx:
				run.formation.erase(spot)
		result[&"refund"] = refund
		result[&"mushed"] = true
	return result

## Removes the mutation in `slot` back to inventory for Tuning.PURGE_COST gold,
## lowering instability by PURGE_INSTABILITY. Returns false if not possible.
static func purge(run: RunState, roster_idx: int, slot: StringName) -> bool:
	if roster_idx < 0 or roster_idx >= run.roster.size():
		return false
	var monster: MonsterData = run.roster[roster_idx]
	if monster == null or monster.mushed or run.gold < Tuning.PURGE_COST:
		return false
	var mutation: MutationData = monster.slots.get(slot) as MutationData
	if mutation == null:
		return false
	run.gold -= Tuning.PURGE_COST
	monster.slots.erase(slot)
	monster.emit_changed()
	run.inventory.append(mutation)
	monster.instability = maxf(0.0, monster.instability - Tuning.PURGE_INSTABILITY)
	return true
