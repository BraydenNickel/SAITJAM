extends Node2D
## Arena that gets more dangerous every level (LEVEL 01–05). Swaps in that level's lab background
## and damaged vats, then starts its hazards (flicker, sparks, alarm) once the intro turns the lights on.

const WIRE_LOOSE := Vector2(393, 43)   ## end of the loose wire (levels 2+)
const WIRE_RIGHT := Vector2(499, 45)   ## end of the dangling right cable
const WIRE_SAG := Vector2(214, 28)     ## lowest point of the sagging left cables

## Per-level look and hazards. [min, max] pairs are random intervals in seconds.
const LEVELS := [
	{"bg": "res://assets/sprites/lab_level_01.png", "left_vat": "intact", "right_vat": "intact",
		"flicker": [9.0, 15.0], "blackout_chance": 0.0, "sparks": [], "spark_every": [0.0, 0.0],
		"alarm": 0, "sweep": false},
	{"bg": "res://assets/sprites/lab_level_02.png", "left_vat": "hairline", "right_vat": "intact",
		"flicker": [6.0, 10.0], "blackout_chance": 0.0, "sparks": [WIRE_LOOSE], "spark_every": [5.0, 9.0],
		"alarm": 0, "sweep": false},
	{"bg": "res://assets/sprites/lab_level_03.png", "left_vat": "leaking", "right_vat": "intact",
		"flicker": [4.0, 7.0], "blackout_chance": 0.0, "sparks": [WIRE_LOOSE, WIRE_RIGHT], "spark_every": [3.0, 5.5],
		"alarm": 1, "sweep": false},
	{"bg": "res://assets/sprites/lab_level_04.png", "left_vat": "leaking", "right_vat": "leaking",
		"flicker": [2.5, 4.5], "blackout_chance": 0.15, "sparks": [WIRE_LOOSE, WIRE_RIGHT, WIRE_SAG],
		"spark_every": [1.8, 3.5], "alarm": 2, "sweep": false},
	{"bg": "res://assets/sprites/lab_level_05.png", "left_vat": "shattered", "right_vat": "leaking",
		"flicker": [1.2, 2.5], "blackout_chance": 0.35, "sparks": [WIRE_LOOSE, WIRE_RIGHT, WIRE_SAG],
		"spark_every": [0.6, 1.6], "alarm": 2, "sweep": true},
]
const VAT_SHEETS := {
	"hairline": "res://assets/sprites/cylinder_hairline.png",
	"leaking": "res://assets/sprites/cylinder_leaking.png",
	"shattered": "res://assets/sprites/cylinder_shattered.png",
}
const VAT_FRAME_SIZE := Vector2(74, 108)
const VAT_FRAMES := 4
const VAT_FPS := 5.0
## Glass drawn over the scientist in the observation window, per level (cracks from level 4).
const WINDOW_GLASS := "res://assets/sprites/window_glass_%02d.png"

## Level to show when not following the run (1–5).
@export_range(1, 5) var level := 1
## When on and a run is active, the level is the run's battle number (Game.run.battle_index + 1).
@export var follow_run := true

@onready var _background: Sprite2D = $Background
@onready var _left_vat: AnimatedSprite2D = $TestTube
@onready var _right_vat: AnimatedSprite2D = $TestTube2
@onready var _window_glass: Sprite2D = $WindowGlass


func _ready() -> void:
	level = resolve_level()
	var cfg: Dictionary = LEVELS[level - 1]
	_background.texture = load(cfg["bg"])
	_window_glass.texture = load(WINDOW_GLASS % level)
	_set_vat(_left_vat, cfg["left_vat"], false)
	_set_vat(_right_vat, cfg["right_vat"], true)

	var hazards := ArenaHazards.new()
	hazards.name = "Hazards"
	hazards.config = cfg
	for child in get_children():
		if child is Light2D:
			hazards.lights.append(child)
	var intro := get_node_or_null("ArenaIntro")
	hazards.intro = intro
	add_child(hazards)  # last child, so sparks draw over the intro's darkness
	if intro != null and intro.has_signal("lights_on"):
		intro.lights_on.connect(hazards.start)
	else:
		hazards.start()


## The level to show: a `--arena-level=N` command-line override, else the run's battle when
## [member follow_run] is on and a run exists, else [member level].
func resolve_level() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arena-level="):
			return clampi(arg.get_slice("=", 1).to_int(), 1, LEVELS.size())
	if follow_run and Game.run != null:
		return clampi(Game.run.battle_index + 1, 1, LEVELS.size())
	return clampi(level, 1, LEVELS.size())


func _set_vat(vat: AnimatedSprite2D, kind: String, mirror: bool) -> void:
	if not VAT_SHEETS.has(kind):
		return  # "intact": keep the scene's own animation
	var sheet: Texture2D = load(VAT_SHEETS[kind])
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", VAT_FPS)
	frames.set_animation_loop(&"default", true)
	for i in VAT_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2(i * VAT_FRAME_SIZE.x, 0), VAT_FRAME_SIZE)
		frames.add_frame(&"default", atlas)
	vat.sprite_frames = frames
	vat.flip_h = mirror
	vat.play(&"default")
