class_name CodexStore
extends RefCounted
## Persistent fusion Codex (design/fusion-contract.md §1): every fused part and
## fused-monster title the player has ever discovered, as JSON. Static; the file
## path is a parameter so tests never touch the real user file.
##
## File / dictionary layout (String keys, as JSON gives them):
## {"parts": {"<pair key>": {"name": String, "signature": bool}}, "titles": [String]}

## The real save file.
const DEFAULT_PATH: String = "user://codex.json"
const KEY_PARTS: String = "parts"
const KEY_TITLES: String = "titles"

## The stored Codex, or an empty one ({"parts": {}, "titles": []}) if the file is
## missing or unreadable.
static func load_codex(path: String = DEFAULT_PATH) -> Dictionary:
	var data: Dictionary = {KEY_PARTS: {}, KEY_TITLES: []}
	if not FileAccess.file_exists(path):
		return data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var d: Dictionary = parsed
		if d.get(KEY_PARTS) is Dictionary:
			data[KEY_PARTS] = d[KEY_PARTS]
		if d.get(KEY_TITLES) is Array:
			data[KEY_TITLES] = d[KEY_TITLES]
	return data

## Writes `data` (same layout as load_codex()) to `path`. Returns false on failure.
static func save_codex(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

## True if the pair key is a discovered fused part in `data`.
static func has_part(data: Dictionary, key: String) -> bool:
	return data.get(KEY_PARTS) is Dictionary and (data[KEY_PARTS] as Dictionary).has(key)

## Adds `new_codex` entries (as reported by FusionLogic.incubate and
## LabLogic.operate: {&"kind": &"part"|&"title", &"key", &"name", &"signature"})
## to the stored Codex and saves it if anything changed. Returns the entries that
## were not stored before (first-ever discoveries).
static func record(new_codex: Array, path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var fresh: Array[Dictionary] = []
	if new_codex.is_empty():
		return fresh
	var data: Dictionary = load_codex(path)
	var parts: Dictionary = data[KEY_PARTS]
	var titles: Array = data[KEY_TITLES]
	for value: Variant in new_codex:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		var key: String = String(entry.get(&"key", ""))
		if key == "":
			continue
		if entry.get(&"kind", &"part") == &"title":
			if not titles.has(key):
				titles.append(key)
				fresh.append(entry)
		elif not parts.has(key):
			parts[key] = {"name": String(entry.get(&"name", key)),
				"signature": bool(entry.get(&"signature", false))}
			fresh.append(entry)
	if not fresh.is_empty():
		save_codex(data, path)
	return fresh
