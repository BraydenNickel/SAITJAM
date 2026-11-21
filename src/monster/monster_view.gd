@tool
class_name MonsterView
extends Node2D
## Shows a MonsterData by placing each slot's mutation sprite on the matching
## Marker2D under Sockets (marker name == slot name). Works in the editor.
## Part sprites are created at runtime WITHOUT an owner, so they are never saved
## into the scene; only those are ever freed.
##
## Body override (design/balance/stage4-mutations.md section 1): the first
## installed mutation in MonsterData.SLOTS order whose overrides_body() is true
## replaces the body texture, tints the body sprite, scales the monster and adds
## a looping aura behind it. Without one the default human body is restored.
## The override only touches the Body sprite and the Sockets node, never this
## node's own transform (owners mirror and size the view through `scale`), and
## it is undone around editor saves so it is never written into a scene.

enum View { FRONT, SIDE }

const PART_SCENE: PackedScene = preload("res://src/monster/part_sprite.tscn")
const PART_META: StringName = &"_monster_view_part"
const APEX_SHADER: Shader = preload("res://assets/shaders/apex_glow.gdshader")
static var _apex_material: ShaderMaterial = null
## Name of the body sprite node in monster_front.tscn / monster_side.tscn.
const BODY_NODE: NodePath = ^"Torso"
const SOCKETS_NODE: NodePath = ^"Sockets"
## Default (human) body texture per View, restored when nothing overrides it.
const DEFAULT_BODY: Array[Texture2D] = [
	preload("res://assets/sprites/torso/human_front.png"),
	preload("res://assets/sprites/torso/human_side.png"),
]
## Aura z-index: same layer as the BACK / TAIL sockets. The aura is also the
## first child, so it draws before (behind) those parts and the body.
## A negative ABSOLUTE z would put that layer behind every z-0 background (card
## panel, arena), so the view root has z_index = 1 in monster_front.tscn and
## monster_side.tscn: the -1 layer then lands on z 0, in front of everything
## earlier in the tree.
const AURA_Z_INDEX: int = -1
## Y of the feet / ground line in view space: half the 64 px body art below the
## view origin. A scaled body keeps its feet here and grows upward.
const FEET_Y: float = 32.0

## The monster to display. Null shows the plain human torso.
@export var data: MonsterData:
	set(value):
		if Engine.is_editor_hint() and data != null and data.changed.is_connected(refresh):
			data.changed.disconnect(refresh)
		data = value
		if Engine.is_editor_hint() and data != null and not data.changed.is_connected(refresh):
			data.changed.connect(refresh)
		refresh()
## Which art set to use.
@export var view: View = View.FRONT:
	set(value):
		view = value
		refresh()

## Vertical shift currently applied to the body and sockets (see _apply_body).
var _feet_shift: float = 0.0
## Scale of the body override currently applied (1 without one).
var _body_scale: float = 1.0

func _ready() -> void:
	refresh()

func _notification(what: int) -> void:
	# Never let a body override leak into a saved scene.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_apply_body(null)
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_apply_body(body_override_of(data))

## The mutation whose body override applies to `monster`: the first one in
## MonsterData.SLOTS order with overrides_body(), or null if there is none.
static func body_override_of(monster: MonsterData) -> MutationData:
	if monster == null:
		return null
	for slot: StringName in MonsterData.SLOTS:
		var mutation: MutationData = monster.slots.get(slot) as MutationData
		if mutation != null and mutation.overrides_body():
			return mutation
	return null

## Rebuilds the part sprites and the body override. Call after mutating `data`
## at runtime.
func refresh() -> void:
	if not is_node_ready():
		return
	_apply_body(body_override_of(data))
	var sockets: Node = get_node_or_null(SOCKETS_NODE)
	if sockets == null:
		return
	for child: Node in sockets.get_children():
		var marker: Marker2D = child as Marker2D
		if marker == null:
			continue
		_clear_parts(marker)
		if data == null:
			continue
		var mutation: MutationData = data.slots.get(marker.name) as MutationData
		if mutation == null:
			continue
		var tex: Texture2D = mutation.sprite_front if view == View.FRONT else mutation.sprite_side
		if tex == null:
			continue
		var part: Sprite2D = PART_SCENE.instantiate() as Sprite2D
		part.texture = tex
		part.flip_h = view == View.FRONT and String(marker.name).ends_with("_R")
		# Apex parts glow. The part is a runtime node without an owner, so the
		# material is never saved into a scene.
		if mutation.merge_count >= Tuning.FUSION_MAX_MERGES:
			part.material = apex_material()
		part.set_meta(PART_META, true)
		marker.add_child(part)

## The ShaderMaterial (assets/shaders/apex_glow.gdshader) shared by every Apex
## part sprite, created on first use with the Tuning.APEX_GLOW_* values.
static func apex_material() -> ShaderMaterial:
	if _apex_material == null:
		_apex_material = ShaderMaterial.new()
		_apex_material.shader = APEX_SHADER
		_apex_material.set_shader_parameter(&"glow_color", Tuning.APEX_GLOW_COLOR)
		_apex_material.set_shader_parameter(&"pulse_speed", Tuning.APEX_GLOW_PULSE_SPEED)
		_apex_material.set_shader_parameter(&"pulse_min", Tuning.APEX_GLOW_MIN)
	return _apex_material

## Applies `mut` (null = default human body) to the body sprite, the
## sockets and the aura. A scaled body grows UP from its feet: the body and the
## sockets are shifted so the feet stay on the FEET_Y ground line.
func _apply_body(mut: MutationData) -> void:
	_clear_parts(self)
	var tex: Texture2D = null
	var tint: Color = Color.WHITE
	var size: Vector2 = Vector2.ONE
	if mut != null:
		tex = mut.body_front if view == View.FRONT else mut.body_side
		tint = mut.body_tint
		if mut.body_scale > 0.0:
			size = Vector2(mut.body_scale, mut.body_scale)
	# Scaling about the centre moves the feet by FEET_Y * (scale - 1); undo it.
	# Applied as a delta so a position authored in the scene is kept.
	var shift: float = FEET_Y * (1.0 - size.y)
	var change: float = shift - _feet_shift
	_feet_shift = shift
	_body_scale = size.y
	var body: Sprite2D = get_node_or_null(BODY_NODE) as Sprite2D
	if body != null:
		body.texture = tex if tex != null else DEFAULT_BODY[view]
		body.modulate = tint
		body.scale = size
		body.position.y += change
	var sockets: Node2D = get_node_or_null(SOCKETS_NODE) as Node2D
	if sockets != null:
		sockets.scale = size
		sockets.position.y += change
	if mut != null:
		_spawn_aura(mut.aura_fx, size.y)

## Scale of the body override currently shown (1 without one).
func body_scale_factor() -> float:
	return _body_scale

## Ground point under the monster, in this view's local space. It does not move
## when a body override scales the monster.
func feet_position() -> Vector2:
	return Vector2(0.0, FEET_Y)

## Middle of the (possibly scaled) body, in this view's local space.
func body_center() -> Vector2:
	return Vector2(0.0, _feet_shift)

## Scale for an aura sheet with `frame_size` px frames on a body drawn at
## `body_scale`: it follows the body but never covers more than `max_size`.
static func aura_scale(frame_size: Vector2, body_scale: float, max_size: Vector2) -> float:
	var result: float = body_scale
	if frame_size.x > 0.0:
		result = minf(result, max_size.x / frame_size.x)
	if frame_size.y > 0.0:
		result = minf(result, max_size.y / frame_size.y)
	return result

## Plays the looping aura behind the body. Sheets drawn standing on the ground
## (pivot near the bottom of the frame) sit at the feet, the rest at the body
## centre. Runtime only (PixelFxPlayer is not a tool script); silently does
## nothing if the json is empty or missing.
func _spawn_aura(json_path: String, body_scale: float) -> void:
	if json_path == "" or Engine.is_editor_hint() or not FileAccess.file_exists(json_path):
		return
	var aura: PixelFxPlayer = PixelFxPlayer.spawn(self, json_path, Vector2.ZERO)
	if aura == null:
		return
	aura.set_meta(PART_META, true)
	var frame: Texture2D = aura.sprite_frames.get_frame_texture(aura.animation, 0)
	var frame_size: Vector2 = frame.get_size() if frame != null else Vector2.ZERO
	# PixelFxPlayer stores the sheet's pivot as a negative sprite offset.
	var grounded: bool = frame_size.y > 0.0 \
		and -aura.offset.y / frame_size.y >= Tuning.FX_GROUND_PIVOT_RATIO
	var factor: float = aura_scale(frame_size, body_scale, Tuning.AURA_MAX_SIZE)
	aura.position = feet_position() if grounded else body_center()
	aura.scale = Vector2(factor, factor)
	aura.z_index = AURA_Z_INDEX
	move_child(aura, 0)

## Frees the runtime children of `parent` this view created (tagged PART_META).
func _clear_parts(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child.has_meta(PART_META):
			parent.remove_child(child)
			child.queue_free()
