class_name TestMonsterData
extends GdUnitTestSuite
## Unit tests for MonsterData stats and slot rules.

func _mutation(socket: MutationData.SocketType) -> MutationData:
	var m: MutationData = MutationData.new()
	m.socket_type = socket
	return m

func test_plain_human_has_base_stats() -> void:
	var stats: Dictionary = MonsterData.new().get_total_stats()
	assert_float(stats[&"hp"] as float).is_equal(Tuning.BASE_HP)
	assert_float(stats[&"atk"] as float).is_equal(Tuning.BASE_ATK)
	assert_float(stats[&"attack_interval"] as float).is_equal(Tuning.BASE_INTERVAL)

func test_total_stats_sum_all_mutation_modifiers() -> void:
	var monster: MonsterData = MonsterData.new()
	var plating: MutationData = _mutation(MutationData.SocketType.TORSO)
	plating.hp_mod = 30.0
	plating.defense_mod = 3.0
	var arm: MutationData = _mutation(MutationData.SocketType.ARM)
	arm.atk_mod = 4.0
	arm.interval_mod = -0.2
	assert_bool(monster.apply_mutation(plating, &"TORSO")).is_true()
	assert_bool(monster.apply_mutation(arm, &"ARM_L")).is_true()
	assert_bool(monster.apply_mutation(arm, &"ARM_R")).is_true()
	var stats: Dictionary = monster.get_total_stats()
	assert_float(stats[&"hp"] as float).is_equal(Tuning.BASE_HP + 30.0)
	assert_float(stats[&"defense"] as float).is_equal(3.0)
	assert_float(stats[&"atk"] as float).is_equal(Tuning.BASE_ATK + 8.0)
	assert_float(stats[&"attack_interval"] as float).is_equal_approx(Tuning.BASE_INTERVAL - 0.4, 0.0001)

func test_interval_and_crit_are_clamped() -> void:
	var monster: MonsterData = MonsterData.new()
	var leg: MutationData = _mutation(MutationData.SocketType.LEG)
	leg.interval_mod = -5.0
	leg.crit_mod = 5.0
	monster.apply_mutation(leg, &"LEG_L")
	var stats: Dictionary = monster.get_total_stats()
	assert_float(stats[&"attack_interval"] as float).is_equal(Tuning.MIN_INTERVAL)
	assert_float(stats[&"crit"] as float).is_equal(1.0)

func test_arm_fits_only_arm_slots() -> void:
	var monster: MonsterData = MonsterData.new()
	var arm: MutationData = _mutation(MutationData.SocketType.ARM)
	assert_bool(monster.can_apply(arm, &"ARM_L")).is_true()
	assert_bool(monster.can_apply(arm, &"ARM_R")).is_true()
	assert_bool(monster.can_apply(arm, &"LEG_L")).is_false()
	assert_bool(monster.can_apply(arm, &"HEAD")).is_false()
	assert_bool(monster.can_apply(arm, &"NOPE")).is_false()

func test_occupied_slot_is_rejected() -> void:
	var monster: MonsterData = MonsterData.new()
	var arm: MutationData = _mutation(MutationData.SocketType.ARM)
	assert_bool(monster.apply_mutation(arm, &"ARM_L")).is_true()
	assert_bool(monster.can_apply(arm, &"ARM_L")).is_false()
	assert_bool(monster.apply_mutation(arm, &"ARM_L")).is_false()
	assert_bool(monster.can_apply(arm, &"ARM_R")).is_true()

func test_slots_for_lists_free_matching_slots() -> void:
	var monster: MonsterData = MonsterData.new()
	var arm: MutationData = _mutation(MutationData.SocketType.ARM)
	assert_array(monster.slots_for(arm)).contains_exactly([&"ARM_L", &"ARM_R"])
	monster.apply_mutation(arm, &"ARM_L")
	assert_array(monster.slots_for(arm)).contains_exactly([&"ARM_R"])
