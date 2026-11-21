extends SceneTree
## Extends the 640x267 lab arena backgrounds to the full 640x360 game screen by continuing
## the floor in perspective (tile grid repeats in depth, grout lines keep converging).
## Writes <name>_full.png next to each source. Re-run after tools/art/lab_levels.py:
##   godot --headless --path . -s res://tools/art/extend_arena.gd
## Then run the importer (godot --headless --path . --import).

const SOURCES: Array[String] = [
	"res://assets/sprites/lab_polished.png",
	"res://assets/sprites/lab_level_01.png",
	"res://assets/sprites/lab_level_02.png",
	"res://assets/sprites/lab_level_03.png",
	"res://assets/sprites/lab_level_04.png",
	"res://assets/sprites/lab_level_05.png",
]
const OUT_SIZE := Vector2i(640, 360)
## Floor perspective, measured from the tile rows at y 226 / 236 / 247.5 / 260.
const HORIZON_Y := 60.0
const VANISH_X := 320.0
## One floor tile in depth, in 1 / (y - HORIZON_Y) units.
const TILE_DEPTH := 0.00034
## Clean floor used where a level's floor band has slime on it (so puddles don't repeat as stripes).
const CLEAN_FLOOR := "res://assets/sprites/lab_polished.png"
## How much darker the very bottom row gets (0 = none), to keep focus on the arena.
const BOTTOM_SHADE := 0.12


var _clean: Image


func _initialize() -> void:
	_clean = Image.load_from_file(ProjectSettings.globalize_path(CLEAN_FLOOR))
	_clean.convert(Image.FORMAT_RGBA8)
	for path in SOURCES:
		_extend(path)
	quit()


static func _is_slime(c: Color) -> bool:
	return c.g > 0.3 and c.g > c.r * 1.35 and c.g > c.b * 1.15


## Per-channel ratio level/clean over the non-slime pixels of the floor band (keeps red tints).
func _tint(src: Image, y0: int, y1: int) -> Color:
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	for y in range(y0, y1):
		for x in range(120, 520):
			var c := src.get_pixel(x, y)
			if _is_slime(c):
				continue
			var k := _clean.get_pixel(x, y)
			a += Vector3(c.r, c.g, c.b)
			b += Vector3(k.r, k.g, k.b)
	return Color(a.x / maxf(b.x, 0.001), a.y / maxf(b.y, 0.001), a.z / maxf(b.z, 0.001))


func _extend(path: String) -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(path))
	src.convert(Image.FORMAT_RGBA8)
	var src_h := src.get_height()
	var out := Image.create(OUT_SIZE.x, OUT_SIZE.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, src.get_width(), src_h), Vector2i.ZERO)
	var w_edge := 1.0 / (float(src_h) - HORIZON_Y)   # depth of the last source row
	var band_top := int(HORIZON_Y + 1.0 / (w_edge + TILE_DEPTH))
	var tint := _tint(src, band_top, src_h)
	for y in range(src_h, OUT_SIZE.y):
		var w := 1.0 / (float(y) + 0.5 - HORIZON_Y)
		# Step back whole tiles until the row lands inside the source floor.
		var w_src := w + ceilf((w_edge - w) / TILE_DEPTH + 0.001) * TILE_DEPTH
		var ys := clampi(int(HORIZON_Y + 1.0 / w_src), 0, src_h - 1)
		var shade := 1.0 - BOTTOM_SHADE * float(y - src_h) / float(OUT_SIZE.y - src_h)
		for x in OUT_SIZE.x:
			var xs := clampi(int(VANISH_X + (float(x) + 0.5 - VANISH_X) * w / w_src), 0, src.get_width() - 1)
			var c := src.get_pixel(xs, ys)
			if _is_slime(c):
				var k := _clean.get_pixel(xs, ys)
				c = Color(k.r * tint.r, k.g * tint.g, k.b * tint.b, k.a)
			out.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, c.a))
	var out_path := path.get_basename() + "_full.png"
	out.save_png(ProjectSettings.globalize_path(out_path))
	print("wrote ", out_path)
