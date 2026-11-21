class_name BattleSim
extends RefCounted
## Deterministic auto-battle simulation (stage 2, design/jam-plan.md "CHOSEN DESIGN").
## Pure logic: no Nodes, all randomness from `rng` (seeded), so a seed replays
## exactly and odds can be estimated headlessly. The sim is the `ctx` passed to
## every AbilityData hook.
##
## Per attack: on_attack(attacker) -> [per strike] on_take_damage(target, may
## cancel) -> apply -> on_hit(attacker) -> on death: on_ally_death(living allies).
## Hooks only fire for hits with depth <= Tuning.HOOK_MAX_DEPTH and never for the
## ability that produced the hit, so hook chains always terminate.

## Visual / log events. Kinds: attack, damage, heal, dodge, ability, death, frenzy, end.
signal event(kind: StringName, info: Dictionary)

const PLAYER: int = 0
const ENEMY: int = 1
## Indices into UnitState.by_hook (bit i of AbilityData.used_hooks()).
const H_START: int = 0
const H_TICK: int = 1
const H_ATTACK: int = 2
const H_HIT: int = 3
const H_TAKE: int = 4
const H_DEATH: int = 5

var units: Array[UnitState] = []
var rng: RandomNumberGenerator
var time: float = 0.0
var finished: bool = false
## 0 = player, 1 = enemy. Only meaningful once `finished`.
var winner: int = ENEMY
## Slot of the ability currently being dispatched (lets one shared ability
## resource keep separate per-slot state, e.g. two Mantis Arms).
var current_slot: StringName = &""
## Precomputed per (unit, ability, slot) state key of the ability being dispatched.
var current_key: String = ""
## False for headless odds sims: no signals, no event dictionaries.
var emit_events: bool = true

var _started: bool = false
## LIFO pool of HitInfo objects (allocation is the hot-loop cost). Hooks must not
## keep a reference to a HitInfo after they return.
var _hit_pool: Array[HitInfo] = []
var _hit_top: int = 0
var _frenzy: bool = false

## Builds both sides. Arrays are parallel (team[i] sits on spots[i]).
## `player_mods` (SkillEffects.combat_mods(): &"hp_mult", &"atk_mult",
## &"speed_mult", each default 1.0) applies to player units only; enemies are
## never buffed. {} leaves the battle unchanged.
func _init(player_team: Array[MonsterData], player_spots: Array[int], player_roster_idx: Array[int],
		enemy_team: Array[MonsterData], enemy_spots: Array[int], rng_seed: int, events_on := true,
		player_mods: Dictionary = {}) -> void:
	emit_events = events_on
	rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i: int in player_team.size():
		var ridx: int = player_roster_idx[i] if i < player_roster_idx.size() else i
		_add_unit(player_team[i], PLAYER, player_spots[i] if i < player_spots.size() else i, ridx,
			player_mods)
	for i: int in enemy_team.size():
		_add_unit(enemy_team[i], ENEMY, enemy_spots[i] if i < enemy_spots.size() else i, -1)

func _add_unit(m: MonsterData, side: int, spot: int, roster_idx: int,
		mods: Dictionary = {}) -> void:
	var u: UnitState = UnitState.new()
	u.index = units.size()
	u.side = side
	u.spot = spot
	u.data = m
	u.roster_index = roster_idx
	var s: Dictionary = m.get_total_stats()
	var hp_mult: float = float(mods.get(&"hp_mult", 1.0))
	var atk_mult: float = float(mods.get(&"atk_mult", 1.0))
	var speed_mult: float = maxf(0.01, float(mods.get(&"speed_mult", 1.0)))
	u.max_hp = maxi(1, roundi((s[&"hp"] as float) * hp_mult))
	u.hp = u.max_hp
	u.atk = roundi((s[&"atk"] as float) * atk_mult)
	u.defense = roundi(s[&"defense"] as float)
	u.crit = s[&"crit"] as float
	u.attack_interval = maxf((s[&"attack_interval"] as float) / speed_mult, Tuning.MIN_INTERVAL)
	u.attack_timer = rng.randf_range(0.0, Tuning.ATTACK_START_JITTER)
	for slot: StringName in MonsterData.SLOTS:
		var mut: MutationData = m.slots.get(slot) as MutationData
		if mut == null:
			continue
		# A fused mutation carries several abilities (design/fusion-contract.md §2).
		# Index 0 keeps the original key format, so base mutations are unchanged;
		# later indices append "|<index>" so two abilities in one slot never share state.
		var slot_abilities: Array[AbilityData] = mut.all_abilities()
		for ai: int in slot_abilities.size():
			var ab: AbilityData = slot_abilities[ai]
			var id: StringName = ab.get_id()
			var key: String = "%d|%s|%s" % [u.index, id, slot]
			if ai > 0:
				key = "%s|%d" % [key, ai]
			var entry: Array = [slot, ab, key, id]
			u.abilities.append(entry)
			var mask: int = ab.used_hooks()
			for h: int in 6:
				if mask & (1 << h):
					(u.by_hook[h] as Array).append(entry)
	units.append(u)

# --- Main loop ---------------------------------------------------------------

## Advances the battle by `delta` seconds and emits events.
func step(delta: float) -> void:
	if finished:
		return
	if not _started:
		_started = true
		for u: UnitState in units:
			if u.alive:
				for pair: Array in u.by_hook[H_START]:
					current_slot = pair[0]
					current_key = pair[2]
					(pair[1] as AbilityData).on_battle_start(self, u)
		_check_end()
		if finished:
			return
	time += delta
	if not _frenzy and time >= Tuning.FRENZY_START:
		_frenzy = true
		notify(&"frenzy", {})
	for u: UnitState in units:
		var ticks: Array = u.by_hook[H_TICK]
		if not u.alive or ticks.is_empty():
			continue
		for pair: Array in ticks:
			current_slot = pair[0]
			current_key = pair[2]
			(pair[1] as AbilityData).on_tick(self, u, delta)
			if finished or not u.alive:
				break
		if finished:
			return
	for u: UnitState in units:
		if not u.alive:
			continue
		u.attack_timer += delta
		if u.attack_timer >= u.attack_interval:
			u.attack_timer -= u.attack_interval
			_attack(u)
			if finished:
				return
	if time >= Tuning.HARD_CAP:
		_end(_hp_winner())

## Runs until the battle is finished and returns result(). With events on it
## uses the fixed Tuning.SIM_STEP; headless it jumps straight to the next attack
## (capped at Tuning.SIM_STEP_HEADLESS so tick abilities stay accurate).
func run_to_end() -> Dictionary:
	while not finished:
		step(Tuning.SIM_STEP if emit_events else _next_gap())
	return result()

## Time until the next attack, clamped to (epsilon, SIM_STEP_HEADLESS].
func _next_gap() -> float:
	var gap: float = Tuning.SIM_STEP_HEADLESS
	for u: UnitState in units:
		if u.alive:
			gap = minf(gap, u.attack_interval - u.attack_timer)
	return maxf(gap, 0.0) + 0.0001

## {winner, time, player_deaths, player_alive, damage_by_roster (roster_idx -> int)}.
func result() -> Dictionary:
	var deaths: int = 0
	var alive_count: int = 0
	var dmg: Dictionary = {}
	for u: UnitState in units:
		if u.side != PLAYER:
			continue
		if u.alive:
			alive_count += 1
		else:
			deaths += 1
		dmg[u.roster_index] = int(dmg.get(u.roster_index, 0)) + u.damage_dealt
	return {
		&"winner": winner, &"time": time, &"player_deaths": deaths,
		&"player_alive": alive_count, &"damage_by_roster": dmg,
	}

# --- Helpers for abilities ----------------------------------------------------

## Living units on the other side of `u`.
func enemies_of(u: UnitState) -> Array[UnitState]:
	var out: Array[UnitState] = []
	for o: UnitState in units:
		if o.alive and o.side != u.side:
			out.append(o)
	return out

## Living units on `u`'s side, excluding `u`.
func allies_of(u: UnitState) -> Array[UnitState]:
	var out: Array[UnitState] = []
	for o: UnitState in units:
		if o.alive and o.side == u.side and o != u:
			out.append(o)
	return out

## Random living enemy of `u` anywhere on the board (not `exclude`), or null.
## Uses one rng roll when at least one candidate exists, none otherwise.
func random_enemy(u: UnitState, exclude: UnitState = null) -> UnitState:
	var count: int = 0
	for o: UnitState in units:
		if o.alive and o.side != u.side and o != exclude:
			count += 1
	if count == 0:
		return null
	var k: int = rng.randi_range(0, count - 1)
	for o: UnitState in units:
		if o.alive and o.side != u.side and o != exclude:
			if k == 0:
				return o
			k -= 1
	return null

## Front-most formation row that still holds a living enemy of `u`, or -1.
func front_enemy_row(u: UnitState) -> int:
	var best: int = -1
	for o: UnitState in units:
		if not o.alive or o.side == u.side:
			continue
		@warning_ignore("integer_division")
		var r: int = o.spot / Tuning.FORMATION_COLS
		if best < 0 or r < best:
			best = r
	return best

## Deals damage from `src` to `dst` (DEF applies unless ignore_def; min 1;
## frenzy scales it). Hook damage passes from_hook = true, its ability_id and
## depth = triggering hit's depth + 1.
func deal_damage(src: UnitState, dst: UnitState, amount: int, from_hook: bool, ability_id: StringName,
		ignore_def := false, depth := 1) -> void:
	if finished or dst == null or not dst.alive or dst.hp <= 0:
		return
	var hit: HitInfo = _acquire_hit(src, dst)
	hit.from_hook = from_hook
	hit.ability_id = ability_id
	hit.depth = depth
	var raw: int = amount if ignore_def else amount - dst.defense
	hit.amount = _scaled(maxi(1, raw))
	_resolve(hit)
	_hit_top -= 1

## Heals `u` up to max HP and emits &"heal" if anything was restored.
func heal(u: UnitState, amount: int) -> void:
	if not u.alive or amount <= 0:
		return
	var healed: int = mini(amount, u.max_hp - u.hp)
	if healed <= 0:
		return
	u.hp += healed
	if emit_events:
		notify(&"heal", {&"dst": u.index, &"amount": healed})

## Emits an event unless this is a headless sim.
func notify(kind: StringName, info: Dictionary) -> void:
	if emit_events:
		event.emit(kind, info)

## Current frenzy damage multiplier (1.0 before FRENZY_START).
func frenzy_mult() -> float:
	if time <= Tuning.FRENZY_START:
		return 1.0
	return 1.0 + Tuning.FRENZY_RAMP * (time - Tuning.FRENZY_START)

# --- Internals ----------------------------------------------------------------

## Next free pooled HitInfo, reset. Caller must `_hit_top -= 1` when done.
func _acquire_hit(src: UnitState, dst: UnitState) -> HitInfo:
	if _hit_top >= _hit_pool.size():
		_hit_pool.append(HitInfo.new())
	var h: HitInfo = _hit_pool[_hit_top]
	_hit_top += 1
	h.source = src
	h.target = dst
	h.amount = 0
	h.crit = false
	h.from_hook = false
	h.ability_id = &""
	h.cancelled = false
	h.depth = 0
	h.extra_strikes = 0
	return h

func _scaled(amount: int) -> int:
	if time <= Tuning.FRENZY_START:
		return amount
	return maxi(1, roundi(amount * frenzy_mult()))

## Random living enemy in the front-most row that still has a living unit.
func _pick_target(u: UnitState) -> UnitState:
	var best_row: int = 999
	var count: int = 0
	for o: UnitState in units:
		if not o.alive or o.side == u.side:
			continue
		@warning_ignore("integer_division")
		var r: int = o.spot / Tuning.FORMATION_COLS
		if r < best_row:
			best_row = r
			count = 1
		elif r == best_row:
			count += 1
	if count == 0:
		return null
	var k: int = rng.randi_range(0, count - 1)
	for o: UnitState in units:
		@warning_ignore("integer_division")
		if o.alive and o.side != u.side and o.spot / Tuning.FORMATION_COLS == best_row:
			if k == 0:
				return o
			k -= 1
	return null

func _attack(u: UnitState) -> void:
	var target: UnitState = _pick_target(u)
	if target == null:
		return
	var extra: int = 0
	var attack_hooks: Array = u.by_hook[H_ATTACK]
	if not attack_hooks.is_empty():
		var proto: HitInfo = _acquire_hit(u, target)
		for pair: Array in attack_hooks:
			current_slot = pair[0]
			current_key = pair[2]
			(pair[1] as AbilityData).on_attack(self, u, proto)
		extra = maxi(0, proto.extra_strikes)
		_hit_top -= 1
	var strikes: int = 1 + extra
	for i: int in strikes:
		if finished or not u.alive:
			return
		if not target.alive or target.hp <= 0:
			target = _pick_target(u)
			if target == null:
				return
		if emit_events:
			notify(&"attack", {&"src": u.index, &"dst": target.index})
		var hit: HitInfo = _acquire_hit(u, target)
		var dmg: int = maxi(1, u.atk - target.defense)
		if rng.randf() < u.crit:
			hit.crit = true
			dmg = roundi(dmg * Tuning.CRIT_MULT)
		hit.amount = _scaled(dmg)
		_resolve(hit)
		_hit_top -= 1

## on_take_damage -> apply -> on_hit -> death handling.
func _resolve(hit: HitInfo) -> void:
	var src: UnitState = hit.source
	var dst: UnitState = hit.target
	var hooks: bool = hit.depth <= Tuning.HOOK_MAX_DEPTH
	if hooks:
		for pair: Array in dst.by_hook[H_TAKE]:
			var ab: AbilityData = pair[1]
			if hit.from_hook and pair[3] == hit.ability_id:
				continue
			current_slot = pair[0]
			current_key = pair[2]
			ab.on_take_damage(self, dst, hit)
			if hit.cancelled:
				return
	if finished or not dst.alive or dst.hp <= 0 or hit.amount <= 0:
		return
	dst.hp -= hit.amount
	if src != null:
		src.damage_dealt += hit.amount
	if emit_events:
		notify(&"damage", {
			&"src": src.index if src != null else -1, &"dst": dst.index, &"amount": hit.amount,
			&"crit": hit.crit, &"from_hook": hit.from_hook, &"ability_id": hit.ability_id,
		})
	if hooks and src != null and src.alive:
		for pair: Array in src.by_hook[H_HIT]:
			var ab: AbilityData = pair[1]
			if hit.from_hook and pair[3] == hit.ability_id:
				continue
			current_slot = pair[0]
			current_key = pair[2]
			ab.on_hit(self, src, hit)
	if dst.alive and dst.hp <= 0:
		_kill(dst)

func _kill(u: UnitState) -> void:
	u.hp = 0
	u.alive = false
	notify(&"death", {&"unit": u.index})
	for ally: UnitState in allies_of(u):
		for pair: Array in ally.by_hook[H_DEATH]:
			current_slot = pair[0]
			current_key = pair[2]
			(pair[1] as AbilityData).on_ally_death(self, ally, u)
	_check_end()

func _check_end() -> void:
	if finished:
		return
	var p_alive: bool = false
	var e_alive: bool = false
	for u: UnitState in units:
		if u.alive:
			if u.side == PLAYER:
				p_alive = true
			else:
				e_alive = true
	if not p_alive:
		_end(ENEMY)
	elif not e_alive:
		_end(PLAYER)

## Hard cap: side with the higher fraction of total max HP left wins; tie -> enemy.
func _hp_winner() -> int:
	var hp: Array[float] = [0.0, 0.0]
	var mx: Array[float] = [0.0, 0.0]
	for u: UnitState in units:
		mx[u.side] += u.max_hp
		if u.alive:
			hp[u.side] += u.hp
	var p: float = hp[PLAYER] / mx[PLAYER] if mx[PLAYER] > 0.0 else 0.0
	var e: float = hp[ENEMY] / mx[ENEMY] if mx[ENEMY] > 0.0 else 0.0
	return PLAYER if p > e else ENEMY

func _end(w: int) -> void:
	finished = true
	winner = w
	notify(&"end", {&"winner": w})
