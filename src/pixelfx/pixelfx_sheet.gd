class_name PixelFxSheet
extends RefCounted
## Loads a pixelfx sprite sheet (PNG + Aseprite-style JSON exported with
## `node tools/pixelfx/tools/render.mjs <category>/<name> --sheet`) into SpriteFrames.
## Copy the exported .png and .json into res://assets/fx/ first.

## Returns {"frames": SpriteFrames, "pivot": Vector2, "frame_size": Vector2, "loop": bool, "act": Dictionary}
static func load_sheet(json_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(json_path)
	var data = JSON.parse_string(text)
	if data == null:
		push_error("PixelFxSheet: cannot parse %s" % json_path)
		return {}
	var meta: Dictionary = data["meta"]
	var info: Dictionary = meta.get("pixelfx", {})
	var tex: Texture2D = load(json_path.get_base_dir().path_join(meta["image"]))
	var anim := String(info.get("name", "fx"))
	var fps := float(info.get("fps", 30))
	var loop := bool(info.get("loop", false))
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	var base_ms := 1000.0 / fps
	for f in data["frames"]:
		var r: Dictionary = f["frame"]
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(r["x"], r["y"], r["w"], r["h"])
		# per-frame duration relative to the base fps
		sf.add_frame(anim, at, float(f.get("duration", base_ms)) / base_ms)
	var fs: Array = info.get("frameSize", [0, 0])
	var pv: Array = info.get("pivot", [fs[0] / 2, fs[1] / 2])
	return {
		"frames": sf,
		"animation": anim,
		"pivot": Vector2(pv[0], pv[1]),
		"frame_size": Vector2(fs[0], fs[1]),
		"loop": loop,
		"act": info.get("act", {}),
	}
