class_name SkillEffectsTest
extends GdUnitTestSuite
## Unit tests for SkillEffects and where the skill bonuses plug into the game
## logic (docs/superpowers/specs/2026-11-21-skill-points-design.md).

func _team(ms: Array) -> Array[MonsterData]:
	var t: Array[MonsterData] = []
	for m: Variant in ms:
		t.append(m as MonsterData)
	return t

func _ints(xs: Array) -> Array[int]:
	var t: Array[int] = []
	for x: Variant in xs:
		t.append(int(x))
	return t

func test_value_is_rank_times_per_rank() -> void:
	assert_int(SkillEffects.value({&"seed_money": 3}, &"seed_money")).is_equal(15)
	assert_int(SkillEffects.value({}, &"seed_money")).is_equal(0)
	assert_int(SkillEffects.value({&"seed_money": 3}, &"unknown")).is_equal(0)

func test_graft_bonus_by_rarity() -> void:
	var ranks: Dictionary = {&"common_graft": 2, &"rare_graft": 1}
	assert_int(SkillEffects.graft_bonus(ranks, MutationData.Rarity.COMMON)).is_equal(8)
	assert_int(SkillEffects.graft_bonus(ranks, MutationData.Rarity.UNCOMMON)).is_equal(0)
	assert_int(SkillEffects.graft_bonus(ranks, MutationData.Rarity.RARE)).is_equal(3)
	assert_int(SkillEffects.graft_bonus(ranks, MutationData.Rarity.ULTRA)).is_equal(0)

func test_fusion_bonus() -> void:
	assert_int(SkillEffects.fusion_bonus({&"steady_splice": 2})).is_equal(6)
	assert_int(SkillEffects.fusion_bonus({})).is_equal(0)

func test_combat_mods() -> void:
	var mods: Dictionary = SkillEffects.combat_mods({&"thick_hide": 3, &"adrenaline": 1})
	assert_float(mods[&"hp_mult"] as float).is_equal_approx(1.12, 0.0001)
	assert_float(mods[&"atk_mult"] as float).is_equal_approx(1.0, 0.0001)
	assert_float(mods[&"speed_mult"] as float).is_equal_approx(1.03, 0.0001)

func test_battle_sim_applies_player_mods_only() -> void:
	var base_hp: float = MonsterData.new().get_total_stats()[&"hp"] as float
	var sim: BattleSim = BattleSim.new(_team([MonsterData.new()]), _ints([0]), _ints([0]),
		_team([MonsterData.new()]), _ints([0]), 1, false, {&"hp_mult": 1.12})
	assert_int(sim.units[0].max_hp).is_equal(roundi(base_hp * 1.12))
	assert_int(sim.units[1].max_hp).is_equal(roundi(base_hp))

func test_battle_sim_speed_and_atk_mods() -> void:
	var s: Dictionary = MonsterData.new().get_total_stats()
	var mods: Dictionary = {&"atk_mult": 1.5, &"speed_mult": 2.0}
	var sim: BattleSim = BattleSim.new(_team([MonsterData.new()]), _ints([0]), _ints([0]),
		_team([MonsterData.new()]), _ints([0]), 1, false, mods)
	assert_int(sim.units[0].atk).is_equal(roundi((s[&"atk"] as float) * 1.5))
	assert_float(sim.units[0].attack_interval).is_equal_approx(
		(s[&"attack_interval"] as float) / 2.0, 0.0001)
	assert_int(sim.units[1].atk).is_equal(roundi(s[&"atk"] as float))

func test_lab_breakdown_has_skills_row() -> void:
	var run: RunState = RunState.new()
	run.battle_index = Tuning.SAFE_LAB_BATTLES
	run.skill_ranks = {&"common_graft": 1}
	var mut: MutationData = MutationData.new()
	mut.rarity = MutationData.Rarity.COMMON
	var rows: Array[Dictionary] = LabLogic.chance_breakdown(run, MonsterData.new(), mut, 0)
	var found: int = 0
	for row: Dictionary in rows:
		if row[&"label"] == "Skills":
			found = int(row[&"value"])
	assert_int(found).is_equal(4)

func test_lab_breakdown_omits_zero_skills_row() -> void:
	var run: RunState = RunState.new()
	run.battle_index = Tuning.SAFE_LAB_BATTLES
	run.skill_ranks = {&"common_graft": 1}
	var mut: MutationData = MutationData.new()
	mut.rarity = MutationData.Rarity.ULTRA
	for row: Dictionary in LabLogic.chance_breakdown(run, MonsterData.new(), mut, 0):
		assert_str(row[&"label"] as String).is_not_equal("Skills")

func test_incubate_breakdown_has_skills_row() -> void:
	var run: RunState = RunState.new()
	run.battle_index = Tuning.SAFE_LAB_BATTLES
	run.skill_ranks = {&"steady_splice": 1}
	var found: int = 0
	for row: Dictionary in FusionLogic.incubate_breakdown(run, MonsterData.new(), MonsterData.new()):
		if row[&"label"] == "Skills":
			found = int(row[&"value"])
	assert_int(found).is_equal(3)
	for row: Dictionary in FusionLogic.incubate_breakdown(null, MonsterData.new(), MonsterData.new()):
		assert_str(row[&"label"] as String).is_not_equal("Skills")
