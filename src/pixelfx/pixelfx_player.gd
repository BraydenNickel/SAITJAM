class_name PixelFxPlayer
extends AnimatedSprite2D
## Spawn a pixelfx effect at a position. One-shot effects free themselves.
##   PixelFxPlayer.spawn(self, "res://assets/fx/coin-spin.json", global_position)

static var _cache := {}

static func spawn(parent: Node, json_path: String, at: Vector2, flip := false) -> PixelFxPlayer:
	if not _cache.has(json_path):
		_cache[json_path] = PixelFxSheet.load_sheet(json_path)
	var s: Dictionary = _cache[json_path]
	if s.is_empty():
		return null
	var p := PixelFxPlayer.new()
	p.sprite_frames = s["frames"]
	p.centered = false
	p.flip_h = flip
	var pivot: Vector2 = s["pivot"]
	p.offset = -pivot if not flip else Vector2(pivot.x - s["frame_size"].x, -pivot.y)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(p)
	p.global_position = at
	if not s["loop"]:
		p.animation_finished.connect(p.queue_free)
	p.play(s["animation"])
	return p
