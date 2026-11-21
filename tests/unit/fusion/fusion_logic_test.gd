class_name FusionLogicTest
extends GdUnitTestSuite
## Unit tests for FusionLogic.merge and friends (design/fusion-contract.md §1-3):
## merge table, ids, stats, abilities, names, body carry, sprites, cost, and the
## BattleSim registration of several abilities per slot.

const MUT_DIR: String = "res://src/data/mutations/"
const TOLERANCE: float = 0.0001
const SEED: int = 4242
## Pair with no signature entry (HEAD). ember_horns has no ability.
const HYBRID_A: String = "ember_horns"
const HYBRID_B: String = "leech_maw"
const HYBRID_KEY: String = "ember_horns+leech_maw"
## Third HEAD part for apex tests.
const APEX_C: String = "venom_fangs"
## Signature pair (ARM): both parents carry Double Strike.
const SIG_A: String = "flicker_blade"
const SIG_B: String = "mantis_arm"
const SIG_KEY: String = "flicker_blade+mantis_arm"
## ULTRA with a body override (HEAD).
const ULTRA: String = "amber_hive_crown"
const MISSING_INDEX: String = "res://tests/unit/fusion/no_such_index.json"
## Seconds of simulated battle in the sim tests.
const SIM_SECONDS: float = 12.0
const SIM_STEP: float = 0.1
const BIG_HP: float = 100000.0

func after_test() -> void:
	FusionLogic.set_index_path("")

func _mut(id: String) -> MutationData:
	return load(MUT_DIR + id + ".tres") as MutationData

## In-memory base mutation with one ability.
func _synthetic(id: String, ability: AbilityData, hp: float = 0.0) -> MutationData:
	var m: MutationData = MutationData.new()
	m.id = StringName(id)
	m.display_name = id.capitalize()
	m.description = "Flavour.\n+%d HP.\nSentence of %s." % [int(hp), id]
	m.socket_type = MutationData.SocketType.TORSO
	m.hp_mod = hp
	m.ability = ability
	return m

func _team(ms: Array) -> Array[MonsterData]:
	var t: Array[MonsterData] = []
	for m: Variant in ms:
		t.append(m as MonsterData)
	return t

func _spots(n: int) -> Array[int]:
	var t: Array[int] = []
	for i: int in n:
		t.append(i)
	return t

# --- Merge table ---------------------------------------------------------------

func test_base_plus_different_base_is_hybrid() -> void:
	var h: MutationData = FusionLogic.merge(_mut(HYBRID_B), _mut(HYBRID_A))
	assert_object(h).is_not_null()
	assert_int(h.merge_count).is_equal(1)
	assert_str(String(h.id)).is_equal(HYBRID_KEY)
	assert_array(h.parent_ids).contains_exactly([StringName(HYBRID_A), StringName(HYBRID_B)])
	assert_str(FusionLogic.pair_key(_mut(HYBRID_B), _mut(HYBRID_A))).is_equal(HYBRID_KEY)
	assert_bool(h.signature).is_false()
	assert_int(int(h.socket_type)).is_equal(int(_mut(HYBRID_A).socket_type))

func test_base_plus_same_base_is_twin() -> void:
	var t: MutationData = FusionLogic.merge(_mut(SIG_B), _mut(SIG_B))
	assert_int(t.merge_count).is_equal(1)
	assert_str(String(t.id)).is_equal("%s+%s" % [SIG_B, SIG_B])
	assert_array(t.parent_ids).contains_exactly([StringName(SIG_B), StringName(SIG_B)])
	assert_int(t.all_abilities().size()).is_equal(1)

func test_fused_plus_base_is_apex() -> void:
	var h: MutationData = FusionLogic.merge(_mut(HYBRID_A), _mut(HYBRID_B))
	var apex: MutationData = FusionLogic.merge(_mut(APEX_C), h)
	assert_int(apex.merge_count).is_equal(2)
	assert_str(String(apex.id)).is_equal("%s+%s+%s" % [HYBRID_A, HYBRID_B, APEX_C])
	assert_int(apex.parent_ids.size()).is_equal(3)
	var twin: MutationData = FusionLogic.merge(_mut(HYBRID_B), _mut(HYBRID_B))
	assert_int(FusionLogic.merge(twin, _mut(HYBRID_A)).merge_count).is_equal(2)

func test_fused_plus_fused_is_blocked() -> void:
	var h: MutationData = FusionLogic.merge(_mut(HYBRID_A), _mut(HYBRID_B))
	var twin: MutationData = FusionLogic.merge(_mut(APEX_C), _mut(APEX_C))
	assert_bool(FusionLogic.can_merge(h, twin)).is_false()
	assert_str(FusionLogic.block_reason(h, twin)).is_equal(FusionLogic.REASON_TOO_MANY)
	assert_object(FusionLogic.merge(h, twin)).is_null()

func test_apex_plus_anything_is_blocked() -> void:
	var h: MutationData = FusionLogic.merge(_mut(HYBRID_A), _mut(HYBRID_B))
	var apex: MutationData = FusionLogic.merge(h, _mut(APEX_C))
	assert_bool(FusionLogic.can_merge(apex, _mut(HYBRID_A))).is_false()
	assert_bool(FusionLogic.can_merge(_mut(HYBRID_A), apex)).is_false()
	assert_str(FusionLogic.block_reason(apex, _mut(HYBRID_A))).is_equal(FusionLogic.REASON_APEX)
	assert_object(FusionLogic.merge(apex, _mut(HYBRID_A))).is_null()

func test_different_socket_or_null_is_blocked() -> void:
	assert_bool(FusionLogic.can_merge(_mut(HYBRID_A), _mut(SIG_B))).is_false()
	assert_str(FusionLogic.block_reason(_mut(HYBRID_A), _mut(SIG_B))) \
		.is_equal(FusionLogic.REASON_SOCKET)
	assert_bool(FusionLogic.can_merge(null, _mut(SIG_B))).is_false()
	assert_str(FusionLogic.block_reason(_mut(HYBRID_A), _mut(HYBRID_B))).is_equal("")

# --- Stats, rarity, cost -------------------------------------------------------

func test_hybrid_stats_use_merge_multiplier() -> void:
	var a: MutationData = _mut(HYBRID_A)
	var b: MutationData = _mut(HYBRID_B)
	var h: MutationData = FusionLogic.merge(a, b)
	var k: float = Tuning.FUSION_PART_STAT_MULT[1]
	assert_float(h.hp_mod).is_equal_approx(k * (a.hp_mod + b.hp_mod), TOLERANCE)
	assert_float(h.atk_mod).is_equal_approx(k * (a.atk_mod + b.atk_mod), TOLERANCE)
	assert_float(h.defense_mod).is_equal_approx(k * (a.defense_mod + b.defense_mod), TOLERANCE)
	assert_float(h.interval_mod).is_equal_approx(k * (a.interval_mod + b.interval_mod), TOLERANCE)
	assert_float(h.crit_mod).is_equal_approx(k * (a.crit_mod + b.crit_mod), TOLERANCE)
	assert_int(int(h.rarity)).is_equal(maxi(int(a.rarity), int(b.rarity)))

func test_apex_stats_sum_all_three_base_parents() -> void:
	var a: MutationData = _mut(HYBRID_A)
	var b: MutationData = _mut(HYBRID_B)
	var c: MutationData = _mut(APEX_C)
	var apex: MutationData = FusionLogic.merge(FusionLogic.merge(a, b), c)
	var k: float = Tuning.FUSION_PART_STAT_MULT[2]
	assert_float(apex.hp_mod).is_equal_approx(k * (a.hp_mod + b.hp_mod + c.hp_mod), TOLERANCE)
	assert_float(apex.atk_mod).is_equal_approx(k * (a.atk_mod + b.atk_mod + c.atk_mod), TOLERANCE)

func test_signature_keeps_full_stats_name_and_art() -> void:
	var a: MutationData = _mut(SIG_A)
	var b: MutationData = _mut(SIG_B)
	var s: MutationData = FusionLogic.merge(a, b)
	var info: Dictionary = FusionLogic.signature_info(SIG_KEY)
	assert_bool(s.signature).is_true()
	assert_str(s.display_name).is_equal(String(info["name"]))
	assert_float(s.hp_mod).is_equal_approx(
		Tuning.FUSION_SIGNATURE_STAT_MULT * (a.hp_mod + b.hp_mod), TOLERANCE)
	assert_float(s.atk_mod).is_equal_approx(
		Tuning.FUSION_SIGNATURE_STAT_MULT * (a.atk_mod + b.atk_mod), TOLERANCE)
	assert_str(s.sprite_front.resource_path).is_equal(String(info["front"]))
	assert_str(s.sprite_side.resource_path).is_equal(String(info["side"]))
	assert_bool(s.description.begins_with(String(info["desc"]))).is_true()
	# An apex built on a signature is no longer one and uses the apex multiplier.
	var apex: MutationData = FusionLogic.merge(s, b)
	assert_bool(apex.signature).is_false()
	assert_float(apex.hp_mod).is_equal_approx(
		Tuning.FUSION_PART_STAT_MULT[2] * (a.hp_mod + 2.0 * b.hp_mod), TOLERANCE)

func test_fused_cost_sums_parents_and_cost_of_uses_it() -> void:
	var a: MutationData = _mut(HYBRID_A)
	var b: MutationData = _mut(HYBRID_B)
	var c: MutationData = _mut(APEX_C)
	var base_cost: int = Tuning.BUDGET_COST[int(a.rarity)]
	assert_int(EnemyGen.cost_of(a)).is_equal(base_cost)
	var h: MutationData = FusionLogic.merge(a, b)
	var expected: int = base_cost + Tuning.BUDGET_COST[int(b.rarity)]
	assert_int(h.fused_cost).is_equal(expected)
	assert_int(EnemyGen.cost_of(h)).is_equal(expected)
	var apex: MutationData = FusionLogic.merge(h, c)
	assert_int(EnemyGen.cost_of(apex)).is_equal(expected + Tuning.BUDGET_COST[int(c.rarity)])
	var mon: MonsterData = MonsterData.new()
	mon.slots[&"HEAD"] = apex
	var roster: Array[MonsterData] = [mon]
	assert_int(EnemyGen.player_power(roster)).is_equal(apex.fused_cost)

# --- Abilities -----------------------------------------------------------------

func test_hybrid_carries_both_parent_abilities() -> void:
	var a: MutationData = _mut(SIG_A)
	var b: MutationData = _mut(SIG_B)
	var s: MutationData = FusionLogic.merge(b, a)
	var all: Array[AbilityData] = s.all_abilities()
	assert_int(all.size()).is_equal(2)
	assert_object(all[0]).is_same(a.ability)
	assert_object(all[1]).is_same(b.ability)
	assert_object(s.ability).is_same(a.ability)
	assert_int(s.extra_abilities.size()).is_equal(1)
	# A parent without an ability contributes none.
	assert_int(FusionLogic.merge(_mut(HYBRID_A), _mut(HYBRID_B)).all_abilities().size()) \
		.is_equal(1)

func test_twin_has_one_empowered_ability() -> void:
	var base: MutationData = _mut(SIG_B)
	var original: AbDoubleStrike = base.ability as AbDoubleStrike
	var every_n: int = original.every_n
	var extra: int = original.extra_strikes
	var twin: MutationData = FusionLogic.merge(base, base)
	var ab: AbDoubleStrike = twin.ability as AbDoubleStrike
	assert_int(twin.all_abilities().size()).is_equal(1)
	assert_object(ab).is_not_same(original)
	assert_int(ab.extra_strikes).is_equal(ceili(extra * Tuning.FUSION_TWIN_POWER - TOLERANCE))
	assert_int(ab.every_n).is_equal(
		maxi(1, ceili(every_n / Tuning.FUSION_TWIN_POWER - TOLERANCE)))
	assert_int(original.every_n).is_equal(every_n)
	assert_int(original.extra_strikes).is_equal(extra)
	assert_str(twin.display_name).is_equal(FusionLogic.NAME_TWIN % base.display_name)
	assert_float(twin.hp_mod).is_equal_approx(
		Tuning.FUSION_PART_STAT_MULT[1] * 2.0 * base.hp_mod, TOLERANCE)

func test_apex_keeps_first_two_abilities_by_default_and_honours_keep() -> void:
	var a: MutationData = _synthetic("t_a", AbThorns.new(), 10.0)
	var b: MutationData = _synthetic("t_b", AbShield.new(), 20.0)
	var c: MutationData = _synthetic("t_c", AbRegen.new(), 30.0)
	var h: MutationData = FusionLogic.merge(a, b)
	var choices: Array[AbilityData] = FusionLogic.ability_choices(h, c)
	assert_int(choices.size()).is_equal(3)
	assert_object(choices[0]).is_same(a.ability)
	assert_object(choices[2]).is_same(c.ability)
	var by_default: MutationData = FusionLogic.merge(h, c)
	assert_int(by_default.all_abilities().size()).is_equal(Tuning.FUSION_MAX_ABILITIES)
	assert_object(by_default.all_abilities()[0]).is_same(a.ability)
	assert_object(by_default.all_abilities()[1]).is_same(b.ability)
	var keep: Array[int] = [2, 0]
	var kept: MutationData = FusionLogic.merge(c, h, keep)
	assert_object(kept.all_abilities()[0]).is_same(a.ability)
	assert_object(kept.all_abilities()[1]).is_same(c.ability)
	assert_bool(kept.description.contains("Sentence of t_c.")).is_true()
	assert_bool(kept.description.contains("Sentence of t_b.")).is_false()
	# Unknown base ids: the stat sum is recovered from the hybrid itself.
	assert_float(kept.hp_mod).is_equal_approx(Tuning.FUSION_PART_STAT_MULT[2] * 60.0, TOLERANCE)
	var one: Array[int] = [1, 99, 1]
	var padded: MutationData = FusionLogic.merge(h, c, one)
	assert_object(padded.all_abilities()[0]).is_same(a.ability)
	assert_object(padded.all_abilities()[1]).is_same(b.ability)

func test_empowered_scales_without_touching_the_original() -> void:
	var regen: AbRegen = AbRegen.new()
	regen.interval = 3.0
	regen.amount = 6.0
	var strong: AbRegen = regen.empowered(1.5) as AbRegen
	assert_object(strong).is_not_same(regen)
	assert_float(strong.amount).is_equal_approx(9.0, TOLERANCE)
	assert_float(strong.interval).is_equal_approx(3.0, TOLERANCE)
	assert_float(regen.amount).is_equal_approx(6.0, TOLERANCE)
	assert_float(regen.interval).is_equal_approx(3.0, TOLERANCE)
	var ds: AbDoubleStrike = AbDoubleStrike.new()
	ds.every_n = 4
	ds.extra_strikes = 1
	var ds2: AbDoubleStrike = ds.empowered(1.5) as AbDoubleStrike
	assert_int(ds2.every_n).is_equal(3)
	assert_int(ds2.extra_strikes).is_equal(2)
	assert_int(ds.every_n).is_equal(4)
	assert_int((ds.empowered(100.0) as AbDoubleStrike).every_n).is_equal(1)

func test_empowered_respects_caps() -> void:
	var dodge: AbDodge = AbDodge.new()
	dodge.chance = 0.8
	assert_float((dodge.empowered(1.5) as AbDodge).chance) \
		.is_equal_approx(Tuning.EMPOWER_MAX_CHANCE, TOLERANCE)
	var titan: AbTitan = AbTitan.new()
	titan.damage_reduction = 0.5
	titan.stomp_interval = 6.0
	var big: AbTitan = titan.empowered(1.5) as AbTitan
	assert_float(big.damage_reduction).is_equal_approx(Tuning.EMPOWER_MAX_REDUCTION, TOLERANCE)
	assert_float(big.stomp_interval).is_equal_approx(6.0, TOLERANCE)
	var steal: AbLifesteal = AbLifesteal.new()
	steal.fraction = 0.9
	assert_float((steal.empowered(1.5) as AbLifesteal).fraction) \
		.is_equal_approx(Tuning.EMPOWER_MAX_FRACTION, TOLERANCE)
	assert_float(dodge.chance).is_equal_approx(0.8, TOLERANCE)

func test_every_ability_script_lists_valid_params() -> void:
	var dir: String = "res://src/data/abilities/"
	var seen: int = 0
	for file: String in DirAccess.get_files_at(dir):
		if not file.begins_with("ab_") or not file.ends_with(".gd"):
			continue
		var ab: AbilityData = (load(dir + file) as GDScript).new() as AbilityData
		seen += 1
		assert_bool(ab.power_params().is_empty()).override_failure_message(file).is_false()
		for pname: String in ab.power_params() + ab.inverse_params():
			assert_bool(pname in ab).override_failure_message("%s: %s" % [file, pname]).is_true()
	assert_int(seen).is_greater(0)

# --- Names, description, body --------------------------------------------------

func test_hybrid_name_uses_lower_rarity_first_word_and_higher_last_word() -> void:
	var a: MutationData = _mut(HYBRID_A)
	var b: MutationData = _mut(HYBRID_B)
	var low: MutationData = a
	var high: MutationData = b
	if int(b.rarity) < int(a.rarity):
		low = b
		high = a
	var expected: String = "%s %s" % [low.display_name.split(" ")[0],
		high.display_name.split(" ")[high.display_name.split(" ").size() - 1]]
	var h: MutationData = FusionLogic.merge(b, a)
	assert_str(h.display_name).is_equal(expected)
	assert_str(FusionLogic.merge(a, b).display_name).is_equal(expected)
	var apex: MutationData = FusionLogic.merge(h, _mut(APEX_C))
	assert_str(apex.display_name).is_equal(FusionLogic.NAME_APEX % expected)

func test_description_names_parents_stats_and_abilities() -> void:
	var a: MutationData = _mut(HYBRID_A)
	var b: MutationData = _mut(HYBRID_B)
	var h: MutationData = FusionLogic.merge(a, b)
	var lines: PackedStringArray = h.description.split("\n")
	assert_str(lines[0]).is_equal(FusionLogic.TEXT_PARENTS % [a.display_name, b.display_name])
	assert_str(lines[1]).is_equal(FusionLogic.stat_line(h))
	var parent_lines: PackedStringArray = b.description.split("\n")
	assert_str(lines[lines.size() - 1]).is_equal(parent_lines[parent_lines.size() - 1])

func test_ultra_body_override_is_carried() -> void:
	var ultra: MutationData = _mut(ULTRA)
	assert_bool(ultra.overrides_body()).is_true()
	var h: MutationData = FusionLogic.merge(_mut(HYBRID_A), ultra)
	assert_bool(h.overrides_body()).is_true()
	assert_object(h.body_front).is_same(ultra.body_front)
	assert_object(h.body_side).is_same(ultra.body_side)
	assert_float(h.body_scale).is_equal_approx(ultra.body_scale, TOLERANCE)
	assert_str(h.aura_fx).is_equal(ultra.aura_fx)
	assert_int(int(h.rarity)).is_equal(int(MutationData.Rarity.ULTRA))
	var apex: MutationData = FusionLogic.merge(_mut(HYBRID_B), h)
	assert_object(apex.body_front).is_same(ultra.body_front)
	assert_bool(FusionLogic.merge(_mut(HYBRID_A), _mut(HYBRID_B)).overrides_body()).is_false()

# --- Sprites -------------------------------------------------------------------

func test_sprites_are_atlas_cells_from_the_index() -> void:
	var idx: Dictionary = FusionLogic.index()
	var entry: Dictionary = (idx["pairs"] as Dictionary)[HYBRID_KEY]
	var cell: int = int(idx["cell"])
	var columns: int = int(idx["columns"])
	var n: int = int(entry["cell"])
	@warning_ignore("integer_division")
	var region: Rect2 = Rect2((n % columns) * cell, (n / columns) * cell, cell, cell)
	var h: MutationData = FusionLogic.merge(_mut(HYBRID_A), _mut(HYBRID_B))
	assert_bool(h.sprite_front is AtlasTexture).is_true()
	assert_bool(h.sprite_side is AtlasTexture).is_true()
	var front: AtlasTexture = h.sprite_front as AtlasTexture
	var side: AtlasTexture = h.sprite_side as AtlasTexture
	assert_bool(front.region == region).is_true()
	assert_bool(side.region == region).is_true()
	assert_str(front.atlas.resource_path).is_equal(FusionLogic.ATLAS_PATH % ["head", "front"])
	assert_str(side.atlas.resource_path).is_equal(FusionLogic.ATLAS_PATH % ["head", "side"])
	# Apex reuses the hybrid's cell.
	var apex: MutationData = FusionLogic.merge(h, _mut(APEX_C))
	assert_object(apex.sprite_front).is_same(h.sprite_front)
	assert_object(apex.sprite_side).is_same(h.sprite_side)

func test_sprites_fall_back_to_higher_rarity_parent() -> void:
	assert_int(FusionLogic.sprites_for("no_such+pair").size()).is_equal(0)
	FusionLogic.set_index_path(MISSING_INDEX)
	assert_bool(FusionLogic.index().is_empty()).is_true()
	var a: MutationData = _mut(HYBRID_A)
	var b: MutationData = _mut(HYBRID_B)
	var donor: MutationData = b if int(b.rarity) > int(a.rarity) else a
	var h: MutationData = FusionLogic.merge(a, b)
	assert_object(h).is_not_null()
	assert_object(h.sprite_front).is_same(donor.sprite_front)
	assert_object(h.sprite_side).is_same(donor.sprite_side)
	# No index: a signature pair is a plain hybrid.
	assert_bool(FusionLogic.merge(_mut(SIG_A), _mut(SIG_B)).signature).is_false()

# --- BattleSim -----------------------------------------------------------------

func _tough() -> MonsterData:
	var m: MonsterData = MonsterData.new()
	m.base_hp = BIG_HP
	return m

func test_two_same_class_abilities_in_one_slot_keep_independent_state() -> void:
	var first: AbDoubleStrike = AbDoubleStrike.new()
	first.every_n = 2
	var second: AbDoubleStrike = AbDoubleStrike.new()
	second.every_n = 3
	var part: MutationData = MutationData.new()
	part.id = &"test_thresher"
	part.socket_type = MutationData.SocketType.ARM
	part.merge_count = 1
	part.ability = first
	var extras: Array[AbilityData] = [second]
	part.extra_abilities = extras
	var mon: MonsterData = _tough()
	mon.slots[&"ARM_L"] = part
	var sim: BattleSim = BattleSim.new(_team([mon]), _spots(1), _spots(1),
		_team([_tough()]), _spots(1), SEED, false)
	var u: UnitState = sim.units[0]
	assert_int(u.abilities.size()).is_equal(2)
	var key0: String = (u.abilities[0] as Array)[2]
	var key1: String = (u.abilities[1] as Array)[2]
	assert_str(key0).is_equal("0|double_strike|ARM_L")
	assert_str(key1).is_equal("0|double_strike|ARM_L|1")
	var t: float = 0.0
	while t < SIM_SECONDS:
		sim.step(SIM_STEP)
		t += SIM_STEP
	var count0: int = int(u.state.get(key0, 0))
	var count1: int = int(u.state.get(key1, 0))
	# Each ability counted every attack once; a shared key would have counted twice.
	assert_int(count0).is_greater(0)
	assert_int(count1).is_equal(count0)
	assert_int(u.state.size()).is_equal(2)

func test_real_signature_and_twin_register_two_and_one_abilities() -> void:
	var mon: MonsterData = _tough()
	mon.slots[&"ARM_L"] = FusionLogic.merge(_mut(SIG_A), _mut(SIG_B))
	mon.slots[&"ARM_R"] = FusionLogic.merge(_mut(SIG_B), _mut(SIG_B))
	var sim: BattleSim = BattleSim.new(_team([mon]), _spots(1), _spots(1),
		_team([_tough()]), _spots(1), SEED, false)
	var keys: Array[String] = []
	for entry: Array in sim.units[0].abilities:
		keys.append(String(entry[2]))
	assert_array(keys).contains_exactly(["0|double_strike|ARM_L", "0|double_strike|ARM_L|1",
		"0|double_strike|ARM_R"])

func _unfused_team() -> Array[MonsterData]:
	var a: MonsterData = MonsterData.new()
	a.slots[&"ARM_L"] = _mut(SIG_B)
	a.slots[&"ARM_R"] = _mut(SIG_B)
	a.slots[&"HEAD"] = _mut(HYBRID_B)
	var b: MonsterData = MonsterData.new()
	b.slots[&"HEAD"] = _mut(APEX_C)
	b.slots[&"HEAD"] = _mut(HYBRID_A)
	return _team([a, b])

func test_unfused_battle_keeps_old_keys_and_is_deterministic() -> void:
	var sim: BattleSim = BattleSim.new(_unfused_team(), _spots(2), _spots(2),
		_unfused_team(), _spots(2), SEED, false)
	var keys: Array[String] = []
	for u: UnitState in sim.units:
		for entry: Array in u.abilities:
			# The pre-fusion format: "<unit>|<ability id>|<slot>", nothing appended.
			assert_str(String(entry[2])).is_equal("%d|%s|%s" % [u.index,
				(entry[1] as AbilityData).get_id(), entry[0]])
			keys.append(String(entry[2]))
	assert_array(keys).contains_exactly(["0|lifesteal|HEAD", "0|double_strike|ARM_L",
		"0|double_strike|ARM_R", "2|lifesteal|HEAD", "2|double_strike|ARM_L",
		"2|double_strike|ARM_R"])
	var again: BattleSim = BattleSim.new(_unfused_team(), _spots(2), _spots(2),
		_unfused_team(), _spots(2), SEED, false)
	var r1: Dictionary = sim.run_to_end()
	var r2: Dictionary = again.run_to_end()
	assert_int(int(r1[&"winner"])).is_equal(int(r2[&"winner"]))
	assert_float(float(r1[&"time"])).is_equal_approx(float(r2[&"time"]), TOLERANCE)
	assert_dict(r1[&"damage_by_roster"] as Dictionary).is_equal(r2[&"damage_by_roster"])
