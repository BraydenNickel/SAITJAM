class_name HintStore
extends RefCounted
## Persistent record of which first-time hint banners the player has seen
## (HintBanner, src/ui/hint_banner.tscn). Static; stored in a ConfigFile with
## one bool per hint id in section "seen".
##
## Tests and QA scripts point it at a temp file, either per call (`file_path`)
## or globally by setting HintStore.path, so the real user file is untouched.

## The real save file.
const DEFAULT_PATH: String = "user://hints.cfg"
const SECTION: String = "seen"

## File used when a call passes no `file_path`. Override for tests / QA shots.
static var path: String = DEFAULT_PATH

## True if hint `id` was already seen (dismissed) according to the file.
static func is_seen(id: StringName, file_path: String = "") -> bool:
	if id == &"":
		return false
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(_resolve(file_path)) != OK:
		return false
	return bool(cfg.get_value(SECTION, String(id), false))

## Marks hint `id` as seen and saves the file. Returns false on an empty id or
## a write failure.
static func mark_seen(id: StringName, file_path: String = "") -> bool:
	if id == &"":
		return false
	var resolved: String = _resolve(file_path)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(resolved)  # a missing file is fine: start empty
	cfg.set_value(SECTION, String(id), true)
	return cfg.save(resolved) == OK

## Forgets every seen hint (deletes the file). Safe if it does not exist.
static func clear(file_path: String = "") -> void:
	var resolved: String = _resolve(file_path)
	if FileAccess.file_exists(resolved):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resolved))

static func _resolve(file_path: String) -> String:
	return file_path if file_path != "" else path
