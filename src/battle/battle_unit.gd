class_name BattleUnit
extends Node2D
## Visual for one fighter in the battle scene: monster sprite, HP bar, name,
## and the lunge / flash / death animations. Holds no combat logic.

const PLAYER_NAME_COLOR: Color = Color(0.75, 1.0, 0.75)
const ENEMY_NAME_COLOR: Color = Color(1.0, 0.65, 0.6)
const DEAD_MODULATE: Color = Color(0.4, 0.4, 0.45, 0.35)

## True once die() has been called.
var dead: bool = false

@onready var _body: Node2D = %Body
@onready var _view: MonsterView = %MonsterView
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _name_label: Label = %NameLabel

var _move_tween: Tween
var _flash_tween: Tween
var _facing: float = 1.0

## Configures the visual for `unit`. Enemies face left (only the view is flipped).
func setup(unit: UnitState, facing_left: bool) -> void:
	_view.data = unit.data
	_view.scale.x = -1.0 if facing_left else 1.0
	_facing = -1.0 if facing_left else 1.0
	_name_label.text = unit.data.display_name
	_name_label.add_theme_color_override("font_color", ENEMY_NAME_COLOR if facing_left else PLAYER_NAME_COLOR)
	set_hp(float(unit.hp), float(unit.max_hp))

## Updates the HP bar.
func set_hp(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = maxf(max_hp, 1.0)
	_hp_bar.value = maxf(hp, 0.0)

## Short lunge toward a world position and back.
func lunge(target_global: Vector2) -> void:
	if dead:
		return
	if _move_tween != null:
		_move_tween.kill()
	_body.position = Vector2.ZERO
	var dir: Vector2 = (target_global - global_position).normalized()
	_move_tween = create_tween()
	_move_tween.tween_property(_body, "position", dir * Tuning.LUNGE_DISTANCE, Tuning.LUNGE_TIME)
	_move_tween.tween_property(_body, "position", Vector2.ZERO, Tuning.LUNGE_TIME * 1.5)

## White flash when hit.
func flash() -> void:
	if dead:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_view.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_view, "modulate", Color.WHITE, Tuning.FLASH_TIME)

## Falls over, fades and greys out.
func die() -> void:
	if dead:
		return
	dead = true
	if _move_tween != null:
		_move_tween.kill()
	if _flash_tween != null:
		_flash_tween.kill()
	_view.modulate = Color.WHITE
	_hp_bar.visible = false
	_name_label.visible = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_body, "modulate", DEAD_MODULATE, Tuning.DEATH_TIME)
	tween.tween_property(_body, "rotation_degrees", -80.0 * _facing, Tuning.DEATH_TIME)
	tween.tween_property(_body, "position", Vector2(-6.0 * _facing, 10.0), Tuning.DEATH_TIME)
