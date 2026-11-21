extends Control
## Codex screen (read-only), two tabs:
## - Mutations (default): every base mutation in src/data/mutations/, filterable by
##   body part and rarity. Mutations the player never obtained (CodexStore
##   "mutations") are dimmed but keep their name and rarity.
## - Fusions: every fused part and chimera title the player has ever discovered
##   (CodexStore, user://codex.json), the discovery totals, and all signature
##   fusions, with undiscovered ones as silhouettes that only hint at their body part.
## Filtering only toggles the visibility of the entries built once in _ready().

const ENTRY_SCENE: PackedScene = preload("res://src/ui/codex_entry.tscn")
const UNKNOWN_NAME: String = "???"
## Filter value of an "All" button (metadata/filter_value in codex.tscn).
const FILTER_ALL: int = -1
const META_FILTER: StringName = &"filter_value"

@onready var _mutations_tab: Button = %MutationsTab
@onready var _fusions_tab: Button = %FusionsTab
@onready var _mutations_panel: Control = %MutationsPanel
@onready var _fusions_panel: Control = %FusionsPanel
@onready var _part_filter: HBoxContainer = %PartFilter
@onready var _rarity_filter: HBoxContainer = %RarityFilter
@onready var _mutation_grid: GridContainer = %MutationGrid
@onready var _mutations_empty: Label = %MutationsEmpty
@onready var _owned_total: Label = %OwnedTotal
@onready var _shown_total: Label = %ShownTotal
@onready var _fusion_total: Label = %FusionTotal
@onready var _signature_total: Label = %SignatureTotal
@onready var _sig_grid: GridContainer = %SigGrid
@onready var _part_grid: GridContainer = %PartGrid
@onready var _parts_empty: Label = %PartsEmpty
@onready var _titles_label: Label = %TitlesLabel
@onready var _back_button: Button = %BackButton
@onready var _sfx: SfxPlayer = %Sfx

## Current part filter (MutationData.SocketType or FILTER_ALL).
var part_filter: int = FILTER_ALL
## Current rarity filter (MutationData.Rarity or FILTER_ALL).
var rarity_filter: int = FILTER_ALL

var _mutation_entries: Array[CodexEntry] = []
## Base mutation id (String) -> obtained.
var _owned: Dictionary = {}

func _ready() -> void:
	_back_button.pressed.connect(_sfx.play_detached.bind(&"click"))
	# Opened from the title screen there is no run yet: go back there.
	_back_button.pressed.connect(func() -> void:
		Game.go_to(&"hub" if Game.run != null else &"title"))
	_mutations_tab.toggled.connect(_on_tab_toggled)
	_fusions_tab.toggled.connect(_on_tab_toggled)
	_connect_filter(_part_filter, _on_part_filter)
	_connect_filter(_rarity_filter, _on_rarity_filter)
	var data: Dictionary = CodexStore.load_codex()
	_build_mutations(data)
	_build_fusions(data)
	_on_tab_toggled(true)
	_back_button.grab_focus()

## Sets both filters and presses the matching buttons (also used by QA scripts).
func set_filters(part: int, rarity: int) -> void:
	_press_filter_button(_part_filter, part)
	_press_filter_button(_rarity_filter, rarity)
	part_filter = part
	rarity_filter = rarity
	_apply_filters()

func _connect_filter(row: HBoxContainer, handler: Callable) -> void:
	for child: Node in row.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var value: int = int(button.get_meta(META_FILTER, FILTER_ALL))
		button.toggled.connect(func(on: bool) -> void:
			if on:
				handler.call(value))
		button.pressed.connect(_sfx.play.bind(&"click"))

func _press_filter_button(row: HBoxContainer, value: int) -> void:
	for child: Node in row.get_children():
		var button: Button = child as Button
		# button_pressed (not set_pressed_no_signal) so the ButtonGroup releases
		# the previously pressed button.
		if button != null and int(button.get_meta(META_FILTER, FILTER_ALL)) == value:
			button.button_pressed = true

func _on_part_filter(value: int) -> void:
	part_filter = value
	_apply_filters()

func _on_rarity_filter(value: int) -> void:
	rarity_filter = value
	_apply_filters()

func _on_tab_toggled(_on: bool) -> void:
	_mutations_panel.visible = _mutations_tab.button_pressed
	_fusions_panel.visible = _fusions_tab.button_pressed

# --- Mutations tab -------------------------------------------------------------

func _build_mutations(data: Dictionary) -> void:
	var defs: Array[MutationData] = []
	for m: MutationData in EnemyGen.all_mutations():
		if m.merge_count == 0:
			defs.append(m)
	defs.sort_custom(func(a: MutationData, b: MutationData) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	for m: MutationData in defs:
		var owned: bool = CodexStore.has_mutation(data, m.id)
		_owned[String(m.id)] = owned
		var entry: CodexEntry = ENTRY_SCENE.instantiate() as CodexEntry
		entry.mutation = m
		_mutation_grid.add_child(entry)
		entry.setup(m.sprite_front, m.display_name, _mutation_tag(m),
			InventoryItem.rarity_color(m.rarity), owned, _mutation_tip(m, owned), true)
		_mutation_entries.append(entry)
	_apply_filters()

## Badge under a mutation tile: "Rare Arm".
func _mutation_tag(m: MutationData) -> String:
	return "%s %s" % [InventoryItem.rarity_name(m.rarity),
		InventoryItem.socket_name(m.socket_type).capitalize()]

func _mutation_tip(m: MutationData, owned: bool) -> String:
	if owned:
		return InventoryItem.mutation_tooltip(m)
	return "%s (%s, %s)\nNot bought yet\n%s" % [m.display_name,
		InventoryItem.rarity_name(m.rarity), InventoryItem.socket_name(m.socket_type),
		InventoryItem.stat_summary(m)]

func _apply_filters() -> void:
	var shown: int = 0
	var shown_owned: int = 0
	var owned_total: int = 0
	for entry: CodexEntry in _mutation_entries:
		var m: MutationData = entry.mutation
		var owned: bool = bool(_owned.get(String(m.id), false))
		if owned:
			owned_total += 1
		var match_part: bool = part_filter == FILTER_ALL or int(m.socket_type) == part_filter
		var match_rarity: bool = rarity_filter == FILTER_ALL or int(m.rarity) == rarity_filter
		entry.visible = match_part and match_rarity
		if entry.visible:
			shown += 1
			if owned:
				shown_owned += 1
	_owned_total.text = "Owned %d / %d" % [owned_total, _mutation_entries.size()]
	_shown_total.text = "Showing %d (%d owned)" % [shown, shown_owned]
	_mutations_empty.visible = shown == 0

# --- Fusions tab ---------------------------------------------------------------

func _build_fusions(data: Dictionary) -> void:
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
