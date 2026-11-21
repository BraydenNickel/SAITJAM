class_name AbilitiesExpansionTest
extends GdUnitTestSuite
## Unit tests for the 22 abilities of design/balance/stage4-mutations.md section 2.
## Every test builds its own in-memory mutation, freezes basic attacks and then
## drives the sim by hand (one attack, one tick, one damage instance), so the
## expected numbers follow directly from the ability's exported params.

## Seed for every sim: results below do not depend on it (crit is zeroed and
## chances are forced to 0 or 1), it only has to be fixed.
const SEED: int = 1234
## Attack timer value that keeps a unit from attacking for the whole test.
const FROZEN_TIMER: float = -100000.0
## Damage far above any unit's HP.
const LETHAL: int = 99999
## Formation spots: 0-1 front row, 4 back row.
const FRONT_A: int = 0
const FRONT_B: int = 1
const BACK_A: int = 4

func _plain() -> MonsterData:
	return MonsterData.new()

## A human with one mutation carrying `ability` in `slot`.
func _mon(ability: AbilityData, slot: StringName = &"TORSO") -> MonsterData:
	var m: MonsterData = MonsterData.new()
	var mut: MutationData = MutationData.new()
	mut.id = StringName("test_%s" % ability.get_id())
	mut.socket_type = MonsterData.SLOT_SOCKET[slot]
	mut.ability = ability
	m.apply_mutation(mut, slot)
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

func _seq(n: int) -> Array[int]:
	var t: Array[int] = []
	for i: int in n:
		t.append(i)
	return t

## Started sim (battle-start hooks have run) with no crits and no automatic
## basic attacks. Player units come first in sim.units, then enemies.
func _sim(p: Array, e: Array, e_spots: Array = []) -> BattleSim:
	var es: Array[int] = _ints(e_spots) if not e_spots.is_empty() else _seq(e.size())
	var sim: BattleSim = BattleSim.new(_team(p), _seq(p.size()), _seq(p.size()),
		_team(e), es, SEED, false)
	sim.step(0.0)
	for u: UnitState in sim.units:
		u.crit = 0.0
		u.attack_timer = FROZEN_TIMER
	return sim

## One basic attack by `u` (random front-row target).
func _attack(sim: BattleSim, u: UnitState) -> void:
	sim._attack(u)

## One plain, DEF-ignoring basic-attack-like damage instance.
func _hurt(sim: BattleSim, src: UnitState, dst: UnitState, amount: int) -> void:
	sim.deal_damage(src, dst, amount, false, &"", true, 0)

func _half(n: int) -> int:
	@warning_ignore("integer_division")
	return n / 2

func _lost(u: UnitState) -> int:
	return u.max_hp - u.hp

# --- Catalog -----------------------------------------------------------------

func test_catalog_ids_and_hooks_match_contract() -> void:
	var h: Dictionary = AbilityData.Hook
	var expected: Array = [
		[AbRegen.new(), &"regen", h.TICK],
		[AbMend.new(), &"mend", h.TICK],
		[AbThorns.new(), &"thorns", h.TAKE_DAMAGE],
		[AbShield.new(), &"shield", h.BATTLE_START | h.TAKE_DAMAGE],
		[AbExecute.new(), &"execute", h.HIT],
		[AbCleave.new(), &"cleave", h.HIT],
		[AbStun.new(), &"stun", h.HIT],
		[AbRage.new(), &"rage", h.TAKE_DAMAGE],
		[AbBerserk.new(), &"berserk", h.TAKE_DAMAGE],
		[AbWarCry.new(), &"war_cry", h.BATTLE_START],
		[AbVengeance.new(), &"vengeance", h.ALLY_DEATH],
		[AbSnipe.new(), &"snipe", h.TICK],
		[AbChill.new(), &"chill", h.HIT],
		[AbCorrode.new(), &"corrode", h.HIT],
		[AbSecondWind.new(), &"second_wind", h.TAKE_DAMAGE],
		[AbAmbush.new(), &"ambush", h.BATTLE_START],
		[AbChain.new(), &"chain", h.HIT],
		[AbMomentum.new(), &"momentum", h.HIT],
		[AbBurn.new(), &"burn", h.HIT | h.TICK],
		[AbTitan.new(), &"titan", h.TAKE_DAMAGE | h.TICK],
		[AbPhase.new(), &"phase", h.TAKE_DAMAGE],
		[AbSwarm.new(), &"swarm", h.TICK],
	]
	for row: Array in expected:
		var ab: AbilityData = row[0]
		assert_str(String(ab.get_id())).is_equal(String(row[1] as StringName))
		assert_int(ab.used_hooks()).override_failure_message(
			"used_hooks of %s" % ab.get_id()).is_equal(int(row[2]))

func test_ability_event_is_emitted_when_events_are_on() -> void:
	var ab: AbAmbush = AbAmbush.new()
	var sim: BattleSim = BattleSim.new(_team([_mon(ab)]), _seq(1), _seq(1),
		_team([_plain()]), _seq(1), SEED, true)
	var seen: Array[StringName] = []
	sim.event.connect(func(kind: StringName, info: Dictionary) -> void:
		if kind == &"ability":
			seen.append(info[&"ability_id"] as StringName))
	sim.step(0.0)
	assert_int(seen.size()).is_equal(1)
	assert_str(String(seen[0])).is_equal("ambush")

# --- Heals -------------------------------------------------------------------

func test_regen_heals_self_once_per_interval() -> void:
	var ab: AbRegen = AbRegen.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	me.hp = _half(me.max_hp)
	var hp_before: int = me.hp
	sim.step(ab.interval * 0.5)
	assert_int(me.hp).is_equal(hp_before)
	sim.step(ab.interval * 0.5)
	assert_int(me.hp).is_equal(hp_before + roundi(ab.amount))

func test_mend_heals_lowest_fraction_ally_not_self() -> void:
	var ab: AbMend = AbMend.new()
	var sim: BattleSim = _sim([_mon(ab), _plain(), _plain()], [_plain()])
	var me: UnitState = sim.units[0]
	var hurt: UnitState = sim.units[2]
	me.hp = me.max_hp - 20
	hurt.hp = _half(hurt.max_hp)
	var hp_before: int = hurt.hp
	sim.step(ab.interval)
	assert_int(hurt.hp).is_equal(hp_before + roundi(ab.amount))
	assert_int(me.hp).is_equal(me.max_hp - 20)
	assert_int(sim.units[1].hp).is_equal(sim.units[1].max_hp)

func test_mend_heals_self_when_self_is_lowest() -> void:
	var ab: AbMend = AbMend.new()
	var sim: BattleSim = _sim([_mon(ab), _plain()], [_plain()])
	var me: UnitState = sim.units[0]
	me.hp = _half(me.max_hp)
	var hp_before: int = me.hp
	sim.step(ab.interval)
	assert_int(me.hp).is_equal(hp_before + roundi(ab.amount))

# --- Reactive ----------------------------------------------------------------

func test_thorns_damages_basic_attacker_only() -> void:
	var ab: AbThorns = AbThorns.new()
	var sim: BattleSim = _sim([_plain()], [_mon(ab)])
	var attacker: UnitState = sim.units[0]
	var thorny: UnitState = sim.units[1]
	_attack(sim, attacker)
	assert_int(_lost(attacker)).is_equal(roundi(ab.damage))
	assert_int(_lost(thorny)).is_equal(attacker.atk)
	# Ability damage does not trigger thorns.
	sim.deal_damage(attacker, thorny, 5, true, &"test", true, 1)
	assert_int(_lost(attacker)).is_equal(roundi(ab.damage))

func test_shield_absorbs_damage_before_hp() -> void:
	var ab: AbShield = AbShield.new()
	var sim: BattleSim = _sim([_plain()], [_mon(ab)])
	var src: UnitState = sim.units[0]
	var shielded: UnitState = sim.units[1]
	var first: int = roundi(ab.amount) - 10
	_hurt(sim, src, shielded, first)
	assert_int(_lost(shielded)).is_equal(0)
	_hurt(sim, src, shielded, 30)
	# 10 shield left: 20 of the 30 goes through, then the shield is gone.
	assert_int(_lost(shielded)).is_equal(20)
	_hurt(sim, src, shielded, 7)
	assert_int(_lost(shielded)).is_equal(27)

func test_rage_adds_atk_per_basic_hit_up_to_cap() -> void:
	var ab: AbRage = AbRage.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	var base_atk: int = me.atk
	_attack(sim, sim.units[1])
	assert_int(me.atk).is_equal(base_atk + roundi(ab.atk_per_stack))
	for i: int in ab.max_stacks + 3:
		_attack(sim, sim.units[1])
	assert_int(me.atk).is_equal(base_atk + roundi(ab.atk_per_stack * ab.max_stacks))

func test_berserk_speeds_up_once_below_threshold() -> void:
	var ab: AbBerserk = AbBerserk.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	var base: float = me.attack_interval
	var chunk: int = roundi(me.max_hp * (1.0 - ab.threshold) * 0.6)
	_hurt(sim, sim.units[1], me, chunk)
	assert_float(me.attack_interval).is_equal_approx(base, 0.0001)
	_hurt(sim, sim.units[1], me, chunk)
	assert_float(me.attack_interval).is_equal_approx(base * ab.interval_mult, 0.0001)
	_hurt(sim, sim.units[1], me, 1)
	assert_float(me.attack_interval).is_equal_approx(base * ab.interval_mult, 0.0001)

func test_berserk_interval_never_drops_below_min_interval() -> void:
	var ab: AbBerserk = AbBerserk.new()
	ab.interval_mult = 0.05
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	_hurt(sim, sim.units[1], me, me.max_hp - 1)
	assert_float(me.attack_interval).is_equal_approx(Tuning.MIN_INTERVAL, 0.0001)

func test_second_wind_cancels_one_lethal_hit_and_heals() -> void:
	var ab: AbSecondWind = AbSecondWind.new()
	var sim: BattleSim = _sim([_mon(ab), _plain()], [_plain()])
	var me: UnitState = sim.units[0]
	me.hp = 20
	_hurt(sim, sim.units[2], me, LETHAL)
	assert_bool(me.alive).is_true()
	assert_int(me.hp).is_equal(roundi(me.max_hp * ab.heal_fraction))
	_hurt(sim, sim.units[2], me, LETHAL)
	assert_bool(me.alive).is_false()

func test_second_wind_ignores_non_lethal_hits() -> void:
	var ab: AbSecondWind = AbSecondWind.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	_hurt(sim, sim.units[1], me, 10)
	assert_int(_lost(me)).is_equal(10)
	assert_bool(me.state.is_empty()).is_true()

func test_vengeance_gains_atk_and_heals_on_ally_death() -> void:
	var ab: AbVengeance = AbVengeance.new()
	var sim: BattleSim = _sim([_mon(ab), _plain()], [_plain()])
	var me: UnitState = sim.units[0]
	var base_atk: int = me.atk
	me.hp = _half(me.max_hp)
	var hp_before: int = me.hp
	_hurt(sim, sim.units[2], sim.units[1], LETHAL)
	assert_bool(sim.units[1].alive).is_false()
	assert_int(me.atk).is_equal(base_atk + roundi(ab.atk_bonus))
	assert_int(me.hp).is_equal(hp_before + roundi(ab.heal))

# --- On hit ------------------------------------------------------------------

func test_execute_adds_bonus_only_under_threshold() -> void:
	var ab: AbExecute = AbExecute.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	var target: UnitState = sim.units[1]
	_attack(sim, me)
	assert_int(_lost(target)).is_equal(me.atk)
	target.hp = roundi(target.max_hp * ab.threshold * 0.5)
	var hp_before: int = target.hp
	_attack(sim, me)
	assert_int(target.hp).is_equal(hp_before - me.atk - roundi(ab.bonus))

func test_cleave_splashes_same_row_only() -> void:
	var ab: AbCleave = AbCleave.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain(), _plain(), _plain()],
		[FRONT_A, FRONT_B, BACK_A])
	var me: UnitState = sim.units[0]
	_attack(sim, me)
	var splash: int = roundi(me.atk * ab.fraction)
	var front: Array[int] = [_lost(sim.units[1]), _lost(sim.units[2])]
	front.sort()
	assert_array(front).is_equal([splash, me.atk])
	assert_int(_lost(sim.units[3])).is_equal(0)

func test_stun_pushes_timer_back_but_not_below_minus_delay() -> void:
	var ab: AbStun = AbStun.new()
	ab.chance = 1.0
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var target: UnitState = sim.units[1]
	target.attack_timer = 0.5
	_attack(sim, sim.units[0])
	assert_float(target.attack_timer).is_equal_approx(0.5 - ab.delay, 0.0001)
	_attack(sim, sim.units[0])
	assert_float(target.attack_timer).is_equal_approx(-ab.delay, 0.0001)

func test_stun_never_triggers_at_zero_chance() -> void:
	var ab: AbStun = AbStun.new()
	ab.chance = 0.0
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var target: UnitState = sim.units[1]
	target.attack_timer = 0.5
	_attack(sim, sim.units[0])
	assert_float(target.attack_timer).is_equal_approx(0.5, 0.0001)

func test_chill_slows_target_up_to_cap() -> void:
	var ab: AbChill = AbChill.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var target: UnitState = sim.units[1]
	var base: float = target.attack_interval
	_attack(sim, sim.units[0])
	assert_float(target.attack_interval).is_equal_approx(base + ab.slow_per_hit, 0.0001)
	for i: int in ceili(ab.max_slow / ab.slow_per_hit) + 3:
		_attack(sim, sim.units[0])
	assert_float(target.attack_interval).is_equal_approx(base + ab.max_slow, 0.0001)

func test_corrode_lowers_def_up_to_cap() -> void:
	var ab: AbCorrode = AbCorrode.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var target: UnitState = sim.units[1]
	var base: int = target.defense
	_attack(sim, sim.units[0])
	assert_int(target.defense).is_equal(base - roundi(ab.def_per_hit))
	for i: int in ceili(ab.max_total / ab.def_per_hit) + 3:
		_attack(sim, sim.units[0])
	assert_int(target.defense).is_equal(base - roundi(ab.max_total))

func test_chain_zaps_one_other_enemy() -> void:
	var ab: AbChain = AbChain.new()
	ab.chance = 1.0
	var sim: BattleSim = _sim([_mon(ab)], [_plain(), _plain()], [FRONT_A, BACK_A])
	var me: UnitState = sim.units[0]
	_attack(sim, me)
	# The basic attack must hit the front unit; the zap can only reach the other.
	assert_int(_lost(sim.units[1])).is_equal(me.atk)
	assert_int(_lost(sim.units[2])).is_equal(roundi(ab.damage))

func test_chain_does_nothing_without_a_second_enemy() -> void:
	var ab: AbChain = AbChain.new()
	ab.chance = 1.0
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	_attack(sim, sim.units[0])
	assert_int(_lost(sim.units[1])).is_equal(sim.units[0].atk)

func test_momentum_adds_crit_per_hit_up_to_cap() -> void:
	var ab: AbMomentum = AbMomentum.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	_attack(sim, me)
	assert_float(me.crit).is_equal_approx(ab.crit_per_hit, 0.0001)
	me.crit = 0.0
	for i: int in ceili(ab.max_crit / ab.crit_per_hit) + 3:
		_attack(sim, me)
		me.crit = 0.0
	# crit was zeroed after every hit, so the stored bonus is the only evidence.
	var stored: float = 0.0
	for v: Variant in me.state.values():
		stored += float(v)
	assert_float(stored).is_equal_approx(ab.max_crit, 0.0001)

func test_burn_ticks_fraction_of_target_max_hp_for_duration() -> void:
	var ab: AbBurn = AbBurn.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	var target: UnitState = sim.units[1]
	_attack(sim, me)
	var per_tick: int = maxi(1, roundi(target.max_hp * ab.fraction))
	var half: float = AbBurn.TICK_SECONDS * 0.5
	for i: int in roundi(ab.duration / half):
		sim.step(half)
	var ticks: int = floori(ab.duration / AbBurn.TICK_SECONDS)
	assert_int(_lost(target)).is_equal(me.atk + per_tick * ticks)
	assert_bool(target.state.has(AbBurn.STATE_KEY)).is_false()
	# Burnt out: no more damage.
	for i: int in 6:
		sim.step(half)
	assert_int(_lost(target)).is_equal(me.atk + per_tick * ticks)

func test_burn_deals_at_least_one_per_tick() -> void:
	var ab: AbBurn = AbBurn.new()
	ab.fraction = 0.0001
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	_attack(sim, sim.units[0])
	sim.step(AbBurn.TICK_SECONDS)
	assert_int(_lost(sim.units[1])).is_equal(sim.units[0].atk + 1)

# --- Battle start ------------------------------------------------------------

func test_war_cry_buffs_allies_not_self_or_enemies() -> void:
	var ab: AbWarCry = AbWarCry.new()
	ab.atk_bonus = 2.0
	ab.def_bonus = 1.0
	ab.hp_bonus = 10.0
	var plain: Dictionary = _plain().get_total_stats()
	var atk: int = roundi(plain[&"atk"] as float)
	var hp: int = roundi(plain[&"hp"] as float)
	var def: int = roundi(plain[&"defense"] as float)
	var sim: BattleSim = _sim([_mon(ab), _plain()], [_plain()])
	var ally: UnitState = sim.units[1]
	assert_int(ally.atk).is_equal(atk + 2)
	assert_int(ally.defense).is_equal(def + 1)
	assert_int(ally.max_hp).is_equal(hp + 10)
	assert_int(ally.hp).is_equal(hp + 10)
	for other: UnitState in [sim.units[0], sim.units[2]]:
		assert_int(other.atk).is_equal(atk)
		assert_int(other.defense).is_equal(def)
		assert_int(other.max_hp).is_equal(hp)

func test_ambush_damages_one_enemy_at_battle_start() -> void:
	var ab: AbAmbush = AbAmbush.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain(), _plain()])
	var total: int = _lost(sim.units[1]) + _lost(sim.units[2])
	assert_int(total).is_equal(roundi(ab.damage))
	assert_bool(_lost(sim.units[1]) == 0 or _lost(sim.units[2]) == 0).is_true()

# --- Ticks -------------------------------------------------------------------

func test_snipe_hits_lowest_hp_enemy_even_in_back_row() -> void:
	var ab: AbSnipe = AbSnipe.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain(), _plain()], [FRONT_A, BACK_A])
	var back: UnitState = sim.units[2]
	back.hp = 50
	sim.step(ab.interval)
	assert_int(back.hp).is_equal(50 - roundi(ab.damage))
	assert_int(_lost(sim.units[1])).is_equal(0)

func test_swarm_damages_enemy_and_heals_self() -> void:
	var ab: AbSwarm = AbSwarm.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	me.hp = _half(me.max_hp)
	var hp_before: int = me.hp
	sim.step(ab.interval)
	assert_int(_lost(sim.units[1])).is_equal(roundi(ab.damage))
	assert_int(me.hp).is_equal(hp_before + roundi(ab.heal))

# --- Ultra -------------------------------------------------------------------

func test_titan_reduces_all_damage_taken() -> void:
	var ab: AbTitan = AbTitan.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	_hurt(sim, sim.units[1], me, 10)
	assert_int(_lost(me)).is_equal(roundi(10 * (1.0 - ab.damage_reduction)))
	sim.deal_damage(sim.units[1], me, 10, true, &"test", true, 1)
	assert_int(_lost(me)).is_equal(2 * roundi(10 * (1.0 - ab.damage_reduction)))

func test_titan_stomp_hits_front_most_enemy_row_only() -> void:
	var ab: AbTitan = AbTitan.new()
	var sim: BattleSim = _sim([_mon(ab)], [_plain(), _plain(), _plain()],
		[FRONT_A, FRONT_B, BACK_A])
	sim.step(ab.stomp_interval)
	assert_int(_lost(sim.units[1])).is_equal(roundi(ab.stomp_damage))
	assert_int(_lost(sim.units[2])).is_equal(roundi(ab.stomp_damage))
	assert_int(_lost(sim.units[3])).is_equal(0)

func test_phase_cancels_any_hit_and_counters_source() -> void:
	var ab: AbPhase = AbPhase.new()
	ab.chance = 1.0
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	var me: UnitState = sim.units[0]
	var foe: UnitState = sim.units[1]
	_attack(sim, foe)
	assert_int(_lost(me)).is_equal(0)
	assert_int(_lost(foe)).is_equal(roundi(ab.counter))
	# Ability damage is cancelled too (unlike dodge).
	sim.deal_damage(foe, me, 9, true, &"test", true, 1)
	assert_int(_lost(me)).is_equal(0)

func test_phase_lets_hits_through_at_zero_chance() -> void:
	var ab: AbPhase = AbPhase.new()
	ab.chance = 0.0
	var sim: BattleSim = _sim([_mon(ab)], [_plain()])
	_attack(sim, sim.units[1])
	assert_int(_lost(sim.units[0])).is_equal(sim.units[1].atk)
	assert_int(_lost(sim.units[1])).is_equal(0)

# --- Table rulings (tools/mutation_table.py) -----------------------------------

func test_corrode_takes_def_below_zero_and_negative_def_adds_damage() -> void:
	var ab: AbCorrode = AbCorrode.new()
	var sim: BattleSim = _sim([_mon(ab, &"ARM_L")], [_plain()])
	var me: UnitState = sim.units[0]
	var target: UnitState = sim.units[1]
	assert_int(target.defense).is_equal(0)
	_attack(sim, me)
	# The first hit lands at DEF 0, then corrodes: DEF is now negative.
	assert_int(target.defense).is_equal(-roundi(ab.def_per_hit))
	assert_int(_lost(target)).is_equal(me.atk)
	var hp_before: int = target.hp
	_attack(sim, me)
	assert_int(hp_before - target.hp).is_equal(me.atk + roundi(ab.def_per_hit))
	# Ability damage that respects DEF is amplified too.
	target.defense = -3
	hp_before = target.hp
	sim.deal_damage(me, target, 5, true, &"test", false, 2)
	assert_int(hp_before - target.hp).is_equal(5 + 3)

func test_mutation_with_negative_def_mod_makes_unit_take_more() -> void:
	var frail: MonsterData = MonsterData.new()
	var mut: MutationData = MutationData.new()
	mut.socket_type = MutationData.SocketType.TORSO
	mut.defense_mod = -1.0
	frail.apply_mutation(mut, &"TORSO")
	var sim: BattleSim = _sim([_plain()], [frail])
	assert_int(sim.units[1].defense).is_equal(-1)
	_attack(sim, sim.units[0])
	assert_int(_lost(sim.units[1])).is_equal(sim.units[0].atk + 1)

func test_shields_on_both_arms_add_up() -> void:
	var ab: AbShield = AbShield.new()
	var m: MonsterData = _mon(ab, &"ARM_L")
	m.apply_mutation(m.slots[&"ARM_L"] as MutationData, &"ARM_R")
	var sim: BattleSim = _sim([_plain()], [m])
	var shielded: UnitState = sim.units[1]
	var total: int = 2 * roundi(ab.amount)
	_hurt(sim, sim.units[0], shielded, total - 5)
	assert_int(_lost(shielded)).is_equal(0)
	_hurt(sim, sim.units[0], shielded, 12)
	assert_int(_lost(shielded)).is_equal(7)

func test_rage_on_both_arms_stacks_independently_per_slot() -> void:
	var ab: AbRage = AbRage.new()
	var m: MonsterData = _mon(ab, &"ARM_L")
	m.apply_mutation(m.slots[&"ARM_L"] as MutationData, &"ARM_R")
	var sim: BattleSim = _sim([m], [_plain()])
	var me: UnitState = sim.units[0]
	var base_atk: int = me.atk
	for i: int in ab.max_stacks + 2:
		_attack(sim, sim.units[1])
	assert_int(me.atk).is_equal(base_atk + 2 * roundi(ab.atk_per_stack * ab.max_stacks))

func test_venom_single_stack_double_damage_still_ticks() -> void:
	var ab: AbVenom = AbVenom.new()
	ab.max_stacks = 1
	ab.damage_per_second = 2.0
	var sim: BattleSim = _sim([_mon(ab, &"TAIL")], [_plain()])
	var me: UnitState = sim.units[0]
	_attack(sim, me)
	_attack(sim, me)
	sim.step(1.0)
	# Two hits, but one stack: exactly 2 venom damage after one second.
	assert_int(_lost(sim.units[1])).is_equal(2 * me.atk + 2)

# --- Whole-battle safety -------------------------------------------------------

func test_full_battle_with_every_new_ability_is_deterministic_and_ends() -> void:
	var a: Array = [
		_mon(AbTitan.new(), &"TORSO"), _mon(AbPhase.new(), &"HEAD"),
		_mon(AbSwarm.new(), &"BACK"), _mon(AbSecondWind.new(), &"TORSO"),
	]
	var b: Array = [
		_mon(AbThorns.new(), &"TORSO"), _mon(AbBurn.new(), &"TAIL"),
		_mon(AbCleave.new(), &"ARM_L"), _mon(AbChain.new(), &"ARM_R"),
	]
	var first: Dictionary = BattleSim.new(_team(a), _seq(4), _seq(4), _team(b), _seq(4),
		SEED, false).run_to_end()
	var second: Dictionary = BattleSim.new(_team(a), _seq(4), _seq(4), _team(b), _seq(4),
		SEED, false).run_to_end()
	assert_dict(first).is_equal(second)
	assert_float(first[&"time"] as float).is_less_equal(Tuning.HARD_CAP + Tuning.SIM_STEP_HEADLESS + 0.001)
