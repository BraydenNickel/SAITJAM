extends Control
## Codex screen (read-only): every fused part and chimera title the player has
## ever discovered (CodexStore, user://codex.json), the discovery totals, and all
## signature fusions, with undiscovered ones as silhouettes that only hint at
## their body part.

const ENTRY_SCENE: PackedScene = preload("res://src/ui/codex_entry.tscn")
const UNKNOWN_NAME: String = "???"

@onready var _fusion_total: Label = %FusionTotal
@onready var _signature_total: Label = %SignatureTotal
@onready var _sig_grid: GridContainer = %SigGrid
@onready var _part_grid: GridContainer = %PartGrid
@onready var _parts_empty: Label = %PartsEmpty
@onready var _titles_label: Label = %TitlesLabel
@onready var _back_button: Button = %BackButton
@onready var _sfx: SfxPlayer = %Sfx

func _ready() -> void:
	_back_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	# Opened from the title screen there is no run yet: go back there.
	_back_button.pressed.connect(func() -> void:
		Game.go_to(&"hub" if Game.run != null else &"title"))
	_build()
	_back_button.grab_focus()

func _build() -> void:
	var data: Dictionary = CodexStore.load_codex()
	var parts: Dictionary = data.get(CodexStore.KEY_PARTS, {}) as Dictionary
	var titles: Array = data.get(CodexStore.KEY_TITLES, []) as Array
	var index: Dictionary = FusionLogic.index()
	var pairs: Dictionary = index.get("pairs", {}) as Dictionary if index.get("pairs") is Dictionary else {}
	var sigs: Dictionary = index.get("signatures", {}) as Dictionary if index.get("signatures") is Dictionary else {}

	# Signatures: all of them, discovered or not.
	var sig_keys: Array = sigs.keys()
	sig_keys.sort()
	var sig_found: int = 0
	for value: Variant in sig_keys:
		var key: String = String(value)
		var info: Dictionary = sigs[key] as Dictionary
		var known: bool = CodexStore.has_part(data, key)
		var socket: String = String((pairs.get(key, {}) as Dictionary).get("socket", "?"))
		if known:
			sig_found += 1
		var tip: String = "%s\n%s\n%s" % [String(info.get("name", key)), _parents_text(key),
			String(info.get("desc", ""))] if known \
			else "Undiscovered signature fusion.\nBody part: %s" % socket
		_add_entry(_sig_grid, _icon_for(key), String(info.get("name", key)) if known else UNKNOWN_NAME,
			"SIGNATURE" if known else socket, InventoryItem.FUSION_COLOR_SIGNATURE, known, tip)

	# Every other discovered fused part (hybrids, twins, apex forms).
	var part_keys: Array = parts.keys()
	part_keys.sort()
	var pair_found: int = 0
	var others: int = 0
	for value: Variant in part_keys:
		var key: String = String(value)
		if pairs.has(key):
			pair_found += 1
		if sigs.has(key):
			continue
		others += 1
		var ids: PackedStringArray = key.split(FusionLogic.KEY_SEPARATOR, false)
		var tag: String = "HYBRID"
		var color: Color = InventoryItem.FUSION_COLOR_HYBRID
		if ids.size() > 2:
			tag = "APEX"
			color = InventoryItem.FUSION_COLOR_APEX
		elif ids.size() == 2 and ids[0] == ids[1]:
			tag = "TWIN"
		var entry_name: String = String((parts[key] as Dictionary).get("name", key))
		_add_entry(_part_grid, _icon_for(key), entry_name, tag, color, true,
			"%s\n%s" % [entry_name, _parents_text(key)])
	_parts_empty.visible = others == 0
	_part_grid.visible = others > 0

	_fusion_total.text = "Fusions discovered %d / %d" % [pair_found, pairs.size()]
	_signature_total.text = "Signatures %d / %d" % [sig_found, sigs.size()]
	var title_lines: PackedStringArray = []
	for title: Variant in titles:
		title_lines.append(String(title))
	_titles_label.text = "\n".join(title_lines) if not title_lines.is_empty() \
		else "No chimera yet.\nIncubate two monsters to name one."

func _add_entry(grid: GridContainer, icon: Texture2D, entry_name: String, tag: String,
		color: Color, known: bool, tip: String) -> void:
	var entry: CodexEntry = ENTRY_SCENE.instantiate() as CodexEntry
	grid.add_child(entry)
	entry.setup(icon, entry_name, tag, color, known, tip)

## Front icon of a pair key. An apex key (three ids) has no art of its own: it
## shows the first of its pairs that has some.
func _icon_for(key: String) -> Texture2D:
	var art: Array[Texture2D] = FusionLogic.sprites_for(key)
	if not art.is_empty():
		return art[0]
	var ids: PackedStringArray = key.split(FusionLogic.KEY_SEPARATOR, false)
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			art = FusionLogic.sprites_for(ids[i] + FusionLogic.KEY_SEPARATOR + ids[j])
			if not art.is_empty():
				return art[0]
	return null

## "Frost Crest + Snapping Beak" from a pair key.
func _parents_text(key: String) -> String:
	var names: PackedStringArray = []
	for id: String in key.split(FusionLogic.KEY_SEPARATOR, false):
		names.append(id.capitalize())
	return " + ".join(names)
