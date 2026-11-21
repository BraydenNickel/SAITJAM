class_name FusionFlowTest
extends GdUnitTestSuite
## Unit tests for the fusion flows (design/fusion-contract.md §1): Lab splice
## (LabLogic.operate onto an occupied slot), the Incubator
## (FusionLogic.incubate_preview / incubate) and the persistent CodexStore.

const MUT_DIR: String = "res://src/data/mutations/"
const TOLERANCE: float = 0.0001
const HEAD_A: String = "ember_horns"
const HEAD_B: String = "leech_maw"
const HEAD_C: String = "venom_fangs"
const HEAD_KEY: String = "ember_horns+leech_maw"
const ARM: String = "mantis_arm"
const ARM_SIG: String = "flicker_blade"
const TORSO: String = "bone_plating"
const TAIL: String = "scorpion_tail"
const START_GOLD: int = 100
const CODEX_PATH: String = "user://test_codex_fusion_flow.json"

func before_test() -> void:
	_remove_codex()

func after_test() -> void:
	_remove_codex()

func _remove_codex() -> void:
	if FileAccess.file_exists(CODEX_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CODEX_PATH))

func _mut(id: String) -> MutationData:
	return load(MUT_DIR + id + ".tres") as MutationData

func _run(n: int) -> RunState:
	var r: RunState = RunState.new()
	r.gold = START_GOLD
	r.battle_index = Tuning.SAFE_LAB_BATTLES  # past the always-succeed round
	for i: int in n:
		var m: MonsterData = MonsterData.new()
		m.display_name = "Subject %02d" % (i + 1)
		r.roster.append(m)
		r.formation[i] = i
	return r

## RNG whose first randi_range(1, 100) is above `threshold` (above=true) or <= it.
func _rng_roll(threshold: int, above: bool) -> RandomNumberGenerator:
	for s: int in range(1, 1000):
		var probe: RandomNumberGenerator = RandomNumberGenerator.new()
		probe.seed = s
		var roll: int = probe.randi_range(1, 100)
		if (roll > threshold) == above:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = s
			return rng
	return null

## Run of three monsters: 0 and 1 are ready to incubate, 2 is a bystander.
## Slot kinds for (0, 1): HEAD merge, TORSO carry, TAIL carry, ARM_L carry, ARM_R choose.
func _incubator_run() -> RunState:
	var r: RunState = _run(3)
	var a: MonsterData = r.roster[0]
	var b: MonsterData = r.roster[1]
	a.slots[&"HEAD"] = _mut(HEAD_A)
	a.slots[&"TORSO"] = _mut(TORSO)
	a.slots[&"ARM_L"] = _mut(ARM)
	a.slots[&"ARM_R"] = FusionLogic.merge(_mut(ARM), _mut(ARM_SIG))
	b.slots[&"HEAD"] = _mut(HEAD_B)
	b.slots[&"TAIL"] = _mut(TAIL)
	b.slots[&"ARM_R"] = FusionLogic.merge(_mut(ARM), _mut(ARM))
	return r

# --- Lab splice ----------------------------------------------------------------

func test_splice_listing_and_preview() -> void:
	var mon: MonsterData = MonsterData.new()
	mon.slots[&"HEAD"] = _mut(HEAD_A)
	mon.slots[&"ARM_L"] = _mut(ARM)
	var incoming: MutationData = _mut(HEAD_B)
	assert_array(mon.slots_for(incoming)).is_empty()
	assert_bool(mon.can_apply(incoming, &"HEAD")).is_false()
	assert_array(LabLogic.splice_slots_for(mon, incoming)).contains_exactly([&"HEAD"])
	assert_array(LabLogic.operable_slots(mon, _mut(ARM))).contains_exactly([&"ARM_L", &"ARM_R"])
	assert_array(LabLogic.splice_slots_for(mon, _mut(ARM))).contains_exactly([&"ARM_L"])
	var preview: MutationData = LabLogic.splice_preview(mon, incoming, &"HEAD")
	assert_str(String(preview.id)).is_equal(HEAD_KEY)
	assert_object(mon.slots[&"HEAD"]).is_same(_mut(HEAD_A))
	assert_object(LabLogic.splice_preview(mon, _mut(ARM), &"ARM_R")).is_null()
	assert_object(LabLogic.splice_preview(mon, _mut(ARM), &"HEAD")).is_null()
	assert_str(LabLogic.slot_block_reason(mon, incoming, &"HEAD")).is_equal("")
	assert_str(LabLogic.slot_block_reason(mon, incoming, &"TAIL")).is_not_equal("")

func test_splice_success_merges_into_the_slot() -> void:
	var r: RunState = _run(1)
	var mon: MonsterData = r.roster[0]
	mon.slots[&"HEAD"] = _mut(HEAD_A)
	var incoming: MutationData = _mut(HEAD_B)
	r.inventory.append(incoming)
	var chance: int = LabLogic.success_chance(r, mon, incoming, 0)
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"HEAD", 0, _rng_roll(chance, false))
	assert_bool(res[&"ok"]).is_true()
	assert_bool(res[&"success"]).is_true()
	assert_bool(res[&"spliced"]).is_true()
	var merged: MutationData = mon.slots[&"HEAD"] as MutationData
	assert_str(String(merged.id)).is_equal(HEAD_KEY)
	assert_int(merged.merge_count).is_equal(1)
	assert_object(res[&"result"]).is_same(merged)
	assert_int(r.inventory.size()).is_equal(0)
	assert_float(mon.instability).is_equal_approx(
		float(Tuning.INSTABILITY_PER_RARITY[int(incoming.rarity)]), TOLERANCE)
	var entries: Array = res[&"new_codex"]
	assert_int(entries.size()).is_equal(1)
	assert_str(String((entries[0] as Dictionary)[&"key"])).is_equal(HEAD_KEY)
	assert_str(String((entries[0] as Dictionary)[&"name"])).is_equal(merged.display_name)
	assert_array(r.fusion_codex).contains_exactly([HEAD_KEY])
	assert_int(r.gold).is_equal(START_GOLD)

func test_splice_fail_mushes_and_keeps_the_old_part() -> void:
	var r: RunState = _run(2)
	var mon: MonsterData = r.roster[0]
	mon.slots[&"HEAD"] = _mut(HEAD_A)
	mon.instability = 50.0
	var incoming: MutationData = _mut(HEAD_B)
	r.inventory.append(incoming)
	var chance: int = LabLogic.success_chance(r, mon, incoming, 0)
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"HEAD", 0, _rng_roll(chance, true))
	assert_bool(res[&"ok"]).is_true()
	assert_bool(res[&"success"]).is_false()
	assert_bool(res[&"mushed"]).is_true()
	assert_bool(res[&"spliced"]).is_true()
	assert_object(res[&"result"]).is_null()
	assert_bool(mon.mushed).is_true()
	assert_object(mon.slots[&"HEAD"]).is_same(_mut(HEAD_A))
	var refund: int = roundi(LabLogic.price_of(incoming) * Tuning.MUSH_REFUND)
	assert_int(int(res[&"refund"])).is_equal(refund)
	assert_int(r.gold).is_equal(START_GOLD + refund)
	assert_int(r.mush_memory).is_equal(Tuning.MUSH_MEMORY_BONUS)
	assert_bool(r.formation.values().has(0)).is_false()
	assert_array(res[&"new_codex"] as Array).is_empty()
	assert_array(r.fusion_codex).is_empty()

func test_splice_blocked_changes_nothing() -> void:
	var r: RunState = _run(1)
	var mon: MonsterData = r.roster[0]
	var apex: MutationData = FusionLogic.merge(
		FusionLogic.merge(_mut(HEAD_A), _mut(HEAD_B)), _mut(HEAD_C))
	mon.slots[&"HEAD"] = apex
	r.inventory.append(_mut(HEAD_B))
	assert_array(LabLogic.operable_slots(mon, _mut(HEAD_B))).is_empty()
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"HEAD", 0, _rng_roll(100, false))
	assert_bool(res[&"ok"]).is_false()
	assert_str(String(res[&"reason"])).is_equal(FusionLogic.REASON_APEX)
	assert_int(r.inventory.size()).is_equal(1)
	assert_object(mon.slots[&"HEAD"]).is_same(apex)

func test_free_slot_operate_is_unchanged() -> void:
	var r: RunState = _run(1)
	var mon: MonsterData = r.roster[0]
	var incoming: MutationData = _mut(HEAD_B)
	r.inventory.append(incoming)
	var chance: int = LabLogic.success_chance(r, mon, incoming, 0)
	var res: Dictionary = LabLogic.operate(r, 0, 0, &"HEAD", 0, _rng_roll(chance, false))
	assert_bool(res[&"success"]).is_true()
	assert_bool(res[&"spliced"]).is_false()
	assert_object(mon.slots[&"HEAD"]).is_same(incoming)
	assert_object(res[&"result"]).is_same(incoming)
	assert_array(res[&"new_codex"] as Array).is_empty()
	assert_array(r.codex).contains_exactly([incoming.id])

# --- Incubator -----------------------------------------------------------------

func test_incubate_preview_slot_kinds() -> void:
	var r: RunState = _incubator_run()
	var a: MonsterData = r.roster[0]
	var b: MonsterData = r.roster[1]
	var p: Dictionary = FusionLogic.incubate_preview(a, b)
	assert_bool(p[&"ok"]).is_true()
	assert_str(String(p[&"reason"])).is_equal("")
	assert_int(int(p[&"cost"])).is_equal(Tuning.FUSION_COST)
	assert_int(int(p[&"chance"])).is_equal(clampi(Tuning.FUSION_BASE_CHANCE,
		Tuning.FUSION_MIN_CHANCE, Tuning.FUSION_MAX_CHANCE))
	var slots: Dictionary = p[&"slots"]
	assert_array(slots.keys()).contains_exactly_in_any_order(
		[&"HEAD", &"TORSO", &"ARM_L", &"ARM_R", &"TAIL"])
	assert_that((slots[&"HEAD"] as Dictionary)[&"kind"]).is_equal(&"merge")
	assert_str(String(((slots[&"HEAD"] as Dictionary)[&"result"] as MutationData).id)) \
		.is_equal(HEAD_KEY)
	assert_that((slots[&"TORSO"] as Dictionary)[&"kind"]).is_equal(&"carry")
	assert_object((slots[&"TORSO"] as Dictionary)[&"result"]).is_same(a.slots[&"TORSO"])
	assert_that((slots[&"TAIL"] as Dictionary)[&"kind"]).is_equal(&"carry")
	assert_object((slots[&"TAIL"] as Dictionary)[&"result"]).is_same(b.slots[&"TAIL"])
	assert_that((slots[&"ARM_L"] as Dictionary)[&"kind"]).is_equal(&"carry")
	var choose: Dictionary = slots[&"ARM_R"]
	assert_that(choose[&"kind"]).is_equal(&"choose")
	assert_int((choose[&"options"] as Array).size()).is_equal(2)
	assert_object(choose[&"result"]).is_same(a.slots[&"ARM_R"])
	var picked: Dictionary = FusionLogic.incubate_preview(a, b, {&"ARM_R": 1})
	assert_object(((picked[&"slots"] as Dictionary)[&"ARM_R"] as Dictionary)[&"result"]) \
		.is_same(b.slots[&"ARM_R"])

func test_incubate_preview_rejects_unready_monsters() -> void:
	var r: RunState = _incubator_run()
	var bare: MonsterData = r.roster[2]
	bare.slots[&"HEAD"] = _mut(HEAD_C)
	var p: Dictionary = FusionLogic.incubate_preview(r.roster[0], bare)
	assert_bool(p[&"ok"]).is_false()
	assert_str(String(p[&"reason"])).is_not_equal("")
	assert_bool(FusionLogic.incubate_preview(r.roster[0], r.roster[0])[&"ok"]).is_false()
	r.roster[1].mushed = true
	assert_bool(FusionLogic.incubate_preview(r.roster[0], r.roster[1])[&"ok"]).is_false()
	assert_bool(FusionLogic.incubate(r, 0, 2, {}, _rng_roll(100, false))[&"ok"]).is_false()
	assert_int(r.gold).is_equal(START_GOLD)

func test_incubate_chance_formula() -> void:
	var r: RunState = _incubator_run()
	var a: MonsterData = r.roster[0]
	var b: MonsterData = r.roster[1]
	a.instability = 40.0
	b.instability = 20.0
	var base: int = Tuning.FUSION_BASE_CHANCE - 30
	assert_int(FusionLogic.incubate_chance(r, a, b, 0)).is_equal(
		clampi(base, Tuning.FUSION_MIN_CHANCE, Tuning.FUSION_MAX_CHANCE))
	assert_int(FusionLogic.incubate_chance(r, a, b, 1)).is_equal(clampi(
		base + Tuning.STABILIZER_BONUS, Tuning.FUSION_MIN_CHANCE, Tuning.FUSION_MAX_CHANCE))
	a.instability = 100.0
	b.instability = 100.0
	assert_int(FusionLogic.incubate_chance(r, a, b, 0)).is_equal(Tuning.FUSION_MIN_CHANCE)
	a.instability = 0.0
	b.instability = 0.0
	assert_int(FusionLogic.incubate_chance(r, a, b, Tuning.STABILIZER_MAX)) \
		.is_equal(Tuning.FUSION_MAX_CHANCE)

func test_incubate_round_one_chance_is_100_and_never_fails() -> void:
	var r: RunState = _incubator_run()
	r.battle_index = 0
	var a: MonsterData = r.roster[0]
	var b: MonsterData = r.roster[1]
	a.instability = 100.0
	b.instability = 100.0
	assert_int(FusionLogic.incubate_chance(r, a, b, 0)).is_equal(100)
	var total: int = 0
	for row: Dictionary in FusionLogic.incubate_breakdown(r, a, b, 0):
		total += int(row[&"value"])
	assert_int(total).is_equal(100)
	var res: Dictionary = FusionLogic.incubate(r, 0, 1, {}, _rng_roll(99, true))
	assert_bool(res[&"success"]).is_true()

func test_incubate_round_two_uses_normal_formula() -> void:
	var r: RunState = _incubator_run()
	r.battle_index = 1
	r.roster[0].instability = 100.0
	r.roster[1].instability = 100.0
	assert_int(FusionLogic.incubate_chance(r, r.roster[0], r.roster[1], 0)) \
		.is_equal(Tuning.FUSION_MIN_CHANCE)

func test_incubate_success_replaces_parents_with_one_monster() -> void:
	var r: RunState = _incubator_run()
	var a: MonsterData = r.roster[0]
	var b: MonsterData = r.roster[1]
	var bystander: MonsterData = r.roster[2]
	r.stabilizers = 1
	var chance: int = FusionLogic.incubate_chance(r, a, b, 1)
	var res: Dictionary = FusionLogic.incubate(r, 0, 1, {&"ARM_R": 1},
		_rng_roll(chance, false), 1)
	assert_bool(res[&"ok"]).is_true()
	assert_bool(res[&"success"]).is_true()
	assert_int(int(res[&"chance"])).is_equal(chance)
	var fused: MonsterData = res[&"monster"]
	assert_object(fused).is_not_null()
	assert_bool(fused.fused).is_true()
	assert_float(fused.instability).is_equal_approx(
		float(Tuning.FUSION_START_INSTABILITY), TOLERANCE)
	assert_str(fused.title).is_not_equal("")
	var k: float = Tuning.FUSION_STAT_MULT * Tuning.FUSION_BOOST
	assert_float(fused.base_hp).is_equal_approx(k * (a.base_hp + b.base_hp), TOLERANCE)
	assert_float(fused.base_atk).is_equal_approx(k * (a.base_atk + b.base_atk), TOLERANCE)
	assert_float(fused.base_interval).is_equal_approx(
		(a.base_interval + b.base_interval) / 2.0, TOLERANCE)
	assert_str(String((fused.slots[&"HEAD"] as MutationData).id)).is_equal(HEAD_KEY)
	assert_object(fused.slots[&"TORSO"]).is_same(a.slots[&"TORSO"])
	assert_object(fused.slots[&"TAIL"]).is_same(b.slots[&"TAIL"])
	assert_object(fused.slots[&"ARM_R"]).is_same(b.slots[&"ARM_R"])
	# Roster and formation: fused takes index 0, the bystander moves from 2 to 1.
	assert_int(r.roster.size()).is_equal(2)
	assert_int(int(res[&"roster_index"])).is_equal(0)
	assert_object(r.roster[0]).is_same(fused)
	assert_object(r.roster[1]).is_same(bystander)
	assert_dict(r.formation).is_equal({0: 0, 2: 1})
	assert_int(r.gold).is_equal(START_GOLD - Tuning.FUSION_COST)
	assert_int(r.stabilizers).is_equal(0)
	assert_bool(a.mushed).is_false()
	# Codex: the new HEAD hybrid and the title (the carried ARM_R twin predates this run's list).
	var keys: Array[String] = []
	for entry: Dictionary in res[&"new_codex"]:
		keys.append(String(entry[&"key"]))
	assert_bool(keys.has(HEAD_KEY)).is_true()
	assert_bool(keys.has(fused.title)).is_true()
	assert_bool(r.fusion_codex.has(HEAD_KEY)).is_true()
	assert_array(r.fusion_titles).contains_exactly([fused.title])

func test_incubate_success_with_b_before_a_remaps_indices() -> void:
	var r: RunState = _incubator_run()
	var bystander: MonsterData = r.roster[2]
	r.formation = {4: 1, 5: 2}
	var chance: int = FusionLogic.incubate_chance(r, r.roster[1], r.roster[0], 0)
	var res: Dictionary = FusionLogic.incubate(r, 1, 0, {}, _rng_roll(chance, false))
	assert_bool(res[&"success"]).is_true()
	assert_int(int(res[&"roster_index"])).is_equal(0)
	assert_object(r.roster[0]).is_same(res[&"monster"])
	assert_object(r.roster[1]).is_same(bystander)
	assert_dict(r.formation).is_equal({4: 0, 5: 1})

func test_incubate_failure_mushes_both() -> void:
	var r: RunState = _incubator_run()
	var a: MonsterData = r.roster[0]
	var b: MonsterData = r.roster[1]
	var chance: int = FusionLogic.incubate_chance(r, a, b, 0)
	var res: Dictionary = FusionLogic.incubate(r, 0, 1, {}, _rng_roll(chance, true))
	assert_bool(res[&"ok"]).is_true()
	assert_bool(res[&"success"]).is_false()
	assert_bool(res[&"mushed"]).is_true()
	assert_object(res[&"monster"]).is_null()
	assert_bool(a.mushed).is_true()
	assert_bool(b.mushed).is_true()
	assert_int(r.roster.size()).is_equal(3)
	assert_dict(r.formation).is_equal({2: 2})
	assert_int(r.gold).is_equal(START_GOLD - Tuning.FUSION_COST)
	assert_int(r.mush_memory).is_equal(Tuning.MUSH_MEMORY_BONUS)
	assert_array(res[&"new_codex"] as Array).is_empty()
	assert_int(r.living_count()).is_equal(1)

func test_incubate_failure_with_insurance_spares_both() -> void:
	var r: RunState = _incubator_run()
	r.insurance = true
	var chance: int = FusionLogic.incubate_chance(r, r.roster[0], r.roster[1], 0)
	var res: Dictionary = FusionLogic.incubate(r, 0, 1, {}, _rng_roll(chance, true))
	assert_bool(res[&"success"]).is_false()
	assert_bool(res[&"insured"]).is_true()
	assert_bool(r.insurance).is_false()
	assert_bool(r.roster[0].mushed).is_false()
	assert_bool(r.roster[1].mushed).is_false()
	assert_int(r.formation.size()).is_equal(3)

func test_incubate_needs_gold() -> void:
	var r: RunState = _incubator_run()
	r.gold = Tuning.FUSION_COST - 1
	var res: Dictionary = FusionLogic.incubate(r, 0, 1, {}, _rng_roll(100, false))
	assert_bool(res[&"ok"]).is_false()
	assert_int(r.roster.size()).is_equal(3)
	assert_int(r.gold).is_equal(Tuning.FUSION_COST - 1)

# --- Codex store ---------------------------------------------------------------

func test_codex_store_round_trip_with_injected_path() -> void:
	var empty: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_bool((empty[CodexStore.KEY_PARTS] as Dictionary).is_empty()).is_true()
	var entries: Array = [
		{&"kind": &"part", &"key": HEAD_KEY, &"name": "Ember Maw", &"signature": false},
		{&"kind": &"part", &"key": "flicker_blade+mantis_arm", &"name": "Thresher",
			&"signature": true},
		{&"kind": &"title", &"key": "Ember-Bone Chimera", &"name": "Ember-Bone Chimera",
			&"signature": false},
	]
	assert_int(CodexStore.record(entries, CODEX_PATH).size()).is_equal(3)
	var data: Dictionary = CodexStore.load_codex(CODEX_PATH)
	assert_bool(CodexStore.has_part(data, HEAD_KEY)).is_true()
	assert_bool(CodexStore.has_part(data, "nope+nope")).is_false()
	var parts: Dictionary = data[CodexStore.KEY_PARTS]
	assert_str(String((parts[HEAD_KEY] as Dictionary)["name"])).is_equal("Ember Maw")
	assert_bool((parts["flicker_blade+mantis_arm"] as Dictionary)["signature"]).is_true()
	assert_array(data[CodexStore.KEY_TITLES] as Array).contains_exactly(["Ember-Bone Chimera"])
	# Recording the same entries again finds nothing new.
	assert_int(CodexStore.record(entries, CODEX_PATH).size()).is_equal(0)
	assert_bool(FileAccess.file_exists(CodexStore.DEFAULT_PATH) \
		and CODEX_PATH == CodexStore.DEFAULT_PATH).is_false()
