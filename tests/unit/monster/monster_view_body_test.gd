class_name MonsterViewBodyTest
extends GdUnitTestSuite
## MonsterView body override (design/balance/stage4-mutations.md section 1):
## texture, tint, scale and aura come from the first overriding mutation in
## MonsterData.SLOTS order, and the default human body returns when there is none.

const FRONT_SCENE: String = "res://src/monster/monster_front.tscn"
const SIDE_SCENE: String = "res://src/monster/monster_side.tscn"
const DEFAULT_FRONT: String = "res://assets/sprites/torso/human_front.png"
const DEFAULT_SIDE: String = "res://assets/sprites/torso/human_side.png"
const TINT: Color = Color(0.5, 0.25, 1.0, 1.0)
const BODY_SCALE: float = 1.25
const OWNER_SCALE: Vector2 = Vector2(-2.0, 2.0)
## A real looping aura sheet (exported by the FX pass); its test is skipped
## with a message if the asset is not on disk.
const REAL_AURA: String = "res://assets/fx/aura_void.json"

func _view(scene_path: String) -> MonsterView:
	var v: MonsterView = auto_free((load(scene_path) as PackedScene).instantiate()) as MonsterView
	add_child(v)
	return v

func _tex() -> Texture2D:
	var t: PlaceholderTexture2D = PlaceholderTexture2D.new()
	t.size = Vector2(64, 64)
	return t

func _body_mut(socket: MutationData.SocketType, front: Texture2D, side: Texture2D) -> MutationData:
	var m: MutationData = MutationData.new()
	m.socket_type = socket
	m.rarity = MutationData.Rarity.ULTRA
	m.body_front = front
	m.body_side = side
	m.body_tint = TINT
	m.body_scale = BODY_SCALE
	return m

func _torso(v: MonsterView) -> Sprite2D:
	return v.get_node(MonsterView.BODY_NODE) as Sprite2D

func _sockets(v: MonsterView) -> Node2D:
	return v.get_node(MonsterView.SOCKETS_NODE) as Node2D

func test_plain_mutation_does_not_override_body() -> void:
	var m: MutationData = MutationData.new()
	assert_bool(m.overrides_body()).is_false()
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(m, &"TORSO")
	assert_object(MonsterView.body_override_of(mon)).is_null()
	assert_object(MonsterView.body_override_of(null)).is_null()

func test_first_override_in_slots_order_wins() -> void:
	var torso: MutationData = _body_mut(MutationData.SocketType.TORSO, _tex(), _tex())
	var head: MutationData = _body_mut(MutationData.SocketType.HEAD, _tex(), _tex())
	var mon: MonsterData = MonsterData.new()
	# Installed TORSO first; HEAD still wins because it comes first in SLOTS.
	mon.apply_mutation(torso, &"TORSO")
	mon.apply_mutation(head, &"HEAD")
	assert_object(MonsterView.body_override_of(mon)).is_same(head)

func test_front_view_applies_texture_tint_and_scale() -> void:
	var front: Texture2D = _tex()
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(_body_mut(MutationData.SocketType.TORSO, front, _tex()), &"TORSO")
	var v: MonsterView = _view(FRONT_SCENE)
	v.scale = OWNER_SCALE
	v.data = mon
	assert_object(_torso(v).texture).is_same(front)
	assert_bool(_torso(v).modulate.is_equal_approx(TINT)).is_true()
	assert_bool(_torso(v).scale.is_equal_approx(Vector2(BODY_SCALE, BODY_SCALE))).is_true()
	assert_bool(_sockets(v).scale.is_equal_approx(Vector2(BODY_SCALE, BODY_SCALE))).is_true()
	# The owner's own transform (mirroring, sizing) is left alone.
	assert_bool(v.scale.is_equal_approx(OWNER_SCALE)).is_true()

func test_side_view_uses_body_side() -> void:
	var side: Texture2D = _tex()
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(_body_mut(MutationData.SocketType.TORSO, _tex(), side), &"TORSO")
	var v: MonsterView = _view(SIDE_SCENE)
	v.data = mon
	assert_object(_torso(v).texture).is_same(side)

func test_default_body_is_restored_when_override_goes_away() -> void:
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(_body_mut(MutationData.SocketType.TORSO, _tex(), _tex()), &"TORSO")
	var v: MonsterView = _view(FRONT_SCENE)
	v.data = mon
	v.data = MonsterData.new()
	assert_str(_torso(v).texture.resource_path).is_equal(DEFAULT_FRONT)
	assert_bool(_torso(v).modulate.is_equal_approx(Color.WHITE)).is_true()
	assert_bool(_torso(v).scale.is_equal_approx(Vector2.ONE)).is_true()
	assert_bool(_sockets(v).scale.is_equal_approx(Vector2.ONE)).is_true()
	v.data = null
	assert_str(_torso(v).texture.resource_path).is_equal(DEFAULT_FRONT)

func test_missing_body_texture_keeps_default_but_applies_tint() -> void:
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(_body_mut(MutationData.SocketType.TORSO, null, null), &"TORSO")
	var v: MonsterView = _view(SIDE_SCENE)
	v.data = mon
	assert_str(_torso(v).texture.resource_path).is_equal(DEFAULT_SIDE)
	assert_bool(_torso(v).modulate.is_equal_approx(TINT)).is_true()

func test_empty_or_missing_aura_adds_no_children() -> void:
	var m: MutationData = _body_mut(MutationData.SocketType.TORSO, _tex(), _tex())
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(m, &"TORSO")
	var v: MonsterView = _view(FRONT_SCENE)
	var before: int = v.get_child_count()
	v.data = mon
	assert_int(v.get_child_count()).is_equal(before)
	m.aura_fx = "res://assets/fx/does_not_exist.json"
	v.refresh()
	assert_int(v.get_child_count()).is_equal(before)

func test_existing_aura_spawns_one_tagged_child_behind_body_and_refresh_clears_it() -> void:
	if not FileAccess.file_exists(REAL_AURA):
		push_warning("monster_view_body_test: %s missing, aura spawn not exercised" % REAL_AURA)
		return
	var m: MutationData = _body_mut(MutationData.SocketType.TORSO, _tex(), _tex())
	m.aura_fx = REAL_AURA
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(m, &"TORSO")
	var v: MonsterView = _view(FRONT_SCENE)
	var plain_count: int = v.get_child_count()
	v.data = mon
	var aura: Node2D = v.get_child(0) as Node2D
	assert_bool(aura is PixelFxPlayer).is_true()
	assert_bool(aura.has_meta(MonsterView.PART_META)).is_true()
	assert_object(aura.owner).is_null()
	assert_int(aura.z_index).is_equal(MonsterView.AURA_Z_INDEX)
	# Refreshing twice never stacks auras; removing the override removes it.
	v.refresh()
	await get_tree().process_frame
	assert_int(v.get_child_count()).is_equal(plain_count + 1)
	v.data = MonsterData.new()
	await get_tree().process_frame
	assert_int(v.get_child_count()).is_equal(plain_count)

func test_scaled_body_keeps_feet_on_ground_line_and_grows_up() -> void:
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(_body_mut(MutationData.SocketType.TORSO, _tex(), _tex()), &"TORSO")
	var v: MonsterView = _view(FRONT_SCENE)
	v.data = mon
	# Bottom edge of the 64 px body = position + half height * scale.
	var feet_y: float = _torso(v).position.y + MonsterView.FEET_Y * _torso(v).scale.y
	assert_float(feet_y).is_equal_approx(MonsterView.FEET_Y, 0.001)
	assert_float(_sockets(v).position.y).is_equal_approx(_torso(v).position.y, 0.001)
	assert_float(v.body_scale_factor()).is_equal_approx(BODY_SCALE, 0.001)
	assert_float(v.body_center().y).is_equal_approx(MonsterView.FEET_Y * (1.0 - BODY_SCALE), 0.001)
	assert_float(v.feet_position().y).is_equal_approx(MonsterView.FEET_Y, 0.001)
	# Refreshing again must not stack the shift; removing the override undoes it.
	v.refresh()
	assert_float(_torso(v).position.y).is_equal_approx(MonsterView.FEET_Y * (1.0 - BODY_SCALE), 0.001)
	v.data = MonsterData.new()
	assert_float(_torso(v).position.y).is_equal_approx(0.0, 0.001)
	assert_float(_sockets(v).position.y).is_equal_approx(0.0, 0.001)
	assert_float(v.body_center().y).is_equal_approx(0.0, 0.001)

func test_view_scenes_sit_on_their_own_z_layer_so_behind_parts_stay_above_backgrounds() -> void:
	for scene_path: String in [FRONT_SCENE, SIDE_SCENE]:
		var v: MonsterView = _view(scene_path)
		# Lowest relative z used inside the view (aura, BACK, TAIL) must not go
		# below absolute 0, or it is drawn behind panels and the arena.
		var lowest: int = MonsterView.AURA_Z_INDEX
		for marker: Node in _sockets(v).get_children():
			lowest = mini(lowest, (marker as Node2D).z_index)
		assert_int(v.z_index + lowest).is_greater_equal(0)

func test_aura_scale_follows_body_but_is_capped_to_max_size() -> void:
	var cap: Vector2 = Vector2(120.0, 120.0)
	# Small sheet: follows the body scale.
	assert_float(MonsterView.aura_scale(Vector2(60.0, 60.0), 1.25, cap)).is_equal_approx(1.25, 0.001)
	# Wide sheet: limited by width; tall sheet: limited by height.
	assert_float(MonsterView.aura_scale(Vector2(240.0, 100.0), 1.25, cap)).is_equal_approx(0.5, 0.001)
	assert_float(MonsterView.aura_scale(Vector2(80.0, 160.0), 1.25, cap)).is_equal_approx(0.75, 0.001)
	# Degenerate frame size never divides by zero.
	assert_float(MonsterView.aura_scale(Vector2.ZERO, 1.25, cap)).is_equal_approx(1.25, 0.001)

func test_ground_aura_is_anchored_at_feet_and_fits_max_size() -> void:
	if not FileAccess.file_exists(REAL_AURA):
		push_warning("monster_view_body_test: %s missing, aura anchor not exercised" % REAL_AURA)
		return
	var m: MutationData = _body_mut(MutationData.SocketType.TORSO, _tex(), _tex())
	m.aura_fx = REAL_AURA
	var mon: MonsterData = MonsterData.new()
	mon.apply_mutation(m, &"TORSO")
	var v: MonsterView = _view(FRONT_SCENE)
	v.data = mon
	var aura: PixelFxPlayer = v.get_child(0) as PixelFxPlayer
	assert_bool(aura.position.is_equal_approx(v.feet_position())).is_true()
	var frame: Vector2 = aura.sprite_frames.get_frame_texture(aura.animation, 0).get_size()
	assert_float(frame.x * aura.scale.x).is_less_equal(Tuning.AURA_MAX_SIZE.x + 0.01)
	assert_float(frame.y * aura.scale.y).is_less_equal(Tuning.AURA_MAX_SIZE.y + 0.01)
