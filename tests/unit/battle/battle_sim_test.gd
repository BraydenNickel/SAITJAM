class_name BattleSimTest
extends GdUnitTestSuite
## Unit tests for BattleSim rules and the mutation abilities (stage 2).

const MUT_DIR: String = "res://src/data/mutations/"

## Counts events of one kind (optionally filtered by ability_id) for assertions.
class EventCounter:
	extends RefCounted
	var kind: StringName
	var ability_id: StringName
	var count: int = 0
	var amount: int = 0
	var last: Dictionary = {}

	func _init(k: StringName, ab: StringName = &"") -> void:
		kind = k
		ability_id = ab

	func on_event(k: StringName, info: Dictionary) -> void:
		if k != kind:
			return
		if ability_id != &"" and info.get(&"ability_id", &"") != ability_id:
			return
		count += 1
		amount += int(info.get(&"amount", 0))
		last = info

func _human() -> MonsterData:
	return MonsterData.new()

func _with(paths: Array, slots: Array) -> MonsterData:
	var m: MonsterData = MonsterData.new()
	for i: int in paths.size():
		var mut: MutationData = load(MUT_DIR + str(paths[i]) + ".tres") as MutationData
		if not m.apply_mutation(mut, slots[i] as StringName) and not m.slots_for(mut).is_empty():
			m.apply_mutation(mut, m.slots_for(mut)[0])
	return m

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

func _sim(p: Array, e: Array, seed_value: int, emit := false) -> BattleSim:
	var ps: Array[int] = []
	for i: int in p.size():
		ps.append(i)
	var es: Array[int] = []
	for i: int in e.size():
		es.append(i)
	return BattleSim.new(_team(p), ps, ps.duplicate(), _team(e), es, seed_value, emit)

func _count(sim: BattleSim, kind: StringName, ab: StringName = &"") -> EventCounter:
	var c: EventCounter = EventCounter.new(kind, ab)
	sim.event.connect(c.on_event)
	return c

func test_same_seed_gives_identical_result() -> void:
	var p: Array = [_with(["mantis_arm", "scorpion_tail"], [&"ARM_L", &"TAIL"]), _human()]
	var e: Array = [_with(["bone_plating", "leech_maw"], [&"TORSO", &"HEAD"]), _with(["spore_sacs"], [&"BACK"])]
	var a: Dictionary = _sim(p, e, 42).run_to_end()
	var b: Dictionary = _sim(p, e, 42).run_to_end()
	assert_dict(a).is_equal(b)

func test_human_vs_empty_side_wins_immediately() -> void:
	var res: Dictionary = _sim([_human()], [], 1).run_to_end()
	assert_int(res[&"winner"] as int).is_equal(BattleSim.PLAYER)
	assert_float(res[&"time"] as float).is_equal(0.0)
	assert_int(res[&"player_alive"] as int).is_equal(1)

func test_empty_player_side_loses() -> void:
	assert_int(_sim([], [_human()], 1).run_to_end()[&"winner"] as int).is_equal(BattleSim.ENEMY)

func test_mirror_plain_humans_battle_ends_within_hard_cap() -> void:
	var sim: BattleSim = _sim([_human()], [_human()], 7)
	var res: Dictionary = sim.run_to_end()
	assert_bool(sim.finished).is_true()
	assert_float(res[&"time"] as float).is_less_equal(Tuning.HARD_CAP + 0.1)

func test_front_row_is_targeted_first() -> void:
	var sim: BattleSim = BattleSim.new(_team([_human()]), _ints([0]), _ints([0]),
		_team([_human(), _human()]), _ints([4, 0]), 3, false)
	for i: int in 200:
		sim.step(0.05)
	# Unit 2 (spot 0, front) is hit; unit 1 (spot 4, back) is untouched while 2 lives.
	assert_int(sim.units[2].hp).is_less(sim.units[2].max_hp)
	if sim.units[2].alive:
		assert_int(sim.units[1].hp).is_equal(sim.units[1].max_hp)

func test_dodge_cancels_some_hits() -> void:
	var fast: MonsterData = _with(["raptor_leg", "raptor_leg"], [&"LEG_L", &"LEG_R"])
	var sim: BattleSim = _sim([_human()], [fast], 5, true)
	var dodges: EventCounter = _count(sim, &"dodge")
	sim.run_to_end()
	assert_int(dodges.count).is_greater(0)

func test_reflect_damages_attacker_from_hook() -> void:
	var tank: MonsterData = _with(["bone_plating"], [&"TORSO"])
	var sim: BattleSim = _sim([_human()], [tank], 9, true)
	var reflected: EventCounter = _count(sim, &"damage", &"reflect")
	sim.run_to_end()
	assert_int(reflected.count).is_greater(0)
	assert_bool(reflected.last[&"from_hook"] as bool).is_true()
	assert_int(reflected.last[&"dst"] as int).is_equal(0)

func test_venom_ticks_damage_on_target() -> void:
	var stinger: MonsterData = _with(["scorpion_tail"], [&"TAIL"])
	var sim: BattleSim = _sim([stinger], [_human()], 11, true)
	var venom: EventCounter = _count(sim, &"damage", &"venom")
	sim.run_to_end()
	assert_int(venom.amount).is_greater(0)

func test_lifesteal_heals() -> void:
	var sim: BattleSim = _sim([_with(["leech_maw"], [&"HEAD"])], [_human()], 13, true)
	var heals: EventCounter = _count(sim, &"heal")
	sim.run_to_end()
	assert_int(heals.count).is_greater(0)

func test_spore_pulse_hits_all_enemies() -> void:
	var sim: BattleSim = _sim([_with(["spore_sacs"], [&"BACK"])], [_human(), _human()], 15, true)
	var spores: EventCounter = _count(sim, &"damage", &"spore_pulse")
	for i: int in 90:
		sim.step(0.05)
	assert_int(spores.count).is_equal(2)

func test_two_mantis_arms_double_strike_stacks() -> void:
	var m: MonsterData = _with(["mantis_arm", "mantis_arm"], [&"ARM_L", &"ARM_R"])
	var sim: BattleSim = _sim([m], [_with(["bone_plating"], [&"TORSO"])], 17, true)
	var triggers: EventCounter = _count(sim, &"ability", &"double_strike")
	sim.run_to_end()
	# Both arms keep separate counters and fire on the same attack.
	assert_int(triggers.count).is_greater(0)
	assert_int(triggers.count % 2).is_equal(0)

func test_hook_recursion_terminates_with_everything_mirrored() -> void:
	var all: Array = ["bone_plating", "leech_maw", "spore_sacs", "mantis_arm", "mantis_arm",
		"raptor_leg", "raptor_leg", "scorpion_tail"]
	var slots: Array = [&"TORSO", &"HEAD", &"BACK", &"ARM_L", &"ARM_R", &"LEG_L", &"LEG_R", &"TAIL"]
	var sim: BattleSim = _sim([_with(all, slots), _with(all, slots)], [_with(all, slots), _with(all, slots)], 21)
	var res: Dictionary = sim.run_to_end()
	assert_bool(sim.finished).is_true()
	assert_float(res[&"time"] as float).is_less_equal(Tuning.HARD_CAP + 0.1)

func test_depth_two_hook_damage_triggers_no_hooks() -> void:
	var tank: MonsterData = _with(["bone_plating"], [&"TORSO"])
	var sim: BattleSim = _sim([tank], [tank.clone()], 2)
	var hp_start: int = sim.units[0].hp
	for i: int in 50:
		sim.deal_damage(sim.units[1], sim.units[0], 1, true, &"test", true, 2)
	assert_int(sim.units[0].hp).is_equal(hp_start - 50)
	assert_int(sim.units[1].hp).is_equal(sim.units[1].max_hp)

func test_damage_by_roster_reports_every_player_unit() -> void:
	var res: Dictionary = _sim([_human(), _human()], [_human()], 4).run_to_end()
	var dmg: Dictionary = res[&"damage_by_roster"]
	assert_bool(dmg.has(0) and dmg.has(1)).is_true()
