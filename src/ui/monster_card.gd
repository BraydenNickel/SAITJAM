class_name MonsterCard
extends PanelContainer
## Compact card showing a monster preview, name, stats and instability.
## A mushed monster shows the mush-jar sprite instead of its body.

## Scale of the monster preview (the hub shows bigger monsters).
@export var preview_scale: float = 1.0
## Shows a "N mutations | X% unstable" line under the stats (hub).
@export var show_summary: bool = false

@onready var _view: MonsterView = %MonsterView
@onready var _summary_label: Label = %SummaryLabel
@onready var _preview: Control = %Preview
@onready var _holder: Node2D = %Holder
@onready var _mush_jar: TextureRect = %MushJar
@onready var _name_label: Label = %NameLabel
@onready var _hp_label: Label = %HpLabel
@onready var _atk_label: Label = %AtkLabel
@onready var _spd_label: Label = %SpdLabel
@onready var _def_label: Label = %DefLabel
@onready var _crit_label: Label = %CritLabel
@onready var _instability_bar: ProgressBar = %InstabilityBar
@onready var _mush_tag: Label = %MushTag
@onready var _fused_tag: Label = %FusedTag

var _data: MonsterData

func _ready() -> void:
	if not is_equal_approx(preview_scale, 1.0):
		_preview.custom_minimum_size *= preview_scale
		_holder.position *= preview_scale
		_holder.scale = Vector2.ONE * preview_scale
	_summary_label.visible = show_summary
	_apply()

## Shows `data` on this card. Safe to call before the card enters the tree.
func setup(data: MonsterData) -> void:
	_data = data
	if is_node_ready():
		_apply()

func _apply() -> void:
	if _data == null:
		return
	var stats: Dictionary = _data.get_total_stats()
	_view.data = _data
	_name_label.text = _data.display_name
	var tips: PackedStringArray = []
	if _data.title != "":
		tips.append(_data.title)
	for slot: StringName in MonsterData.SLOTS:
		var part: MutationData = _data.slots.get(slot) as MutationData
		if part == null:
			continue
		var tag: String = InventoryItem.fusion_tag(part)
		var line: String = "%s: %s" % [String(slot).replace("_", " "), part.display_name]
		if tag != "":
			line += " [%s]" % tag
			for text: String in InventoryItem.ability_lines(part):
				line += "\n   " + text
		tips.append(line)
	tooltip_text = "\n".join(tips)
	_hp_label.text = "HP %d" % roundi(stats[&"hp"] as float)
	_atk_label.text = "ATK %d" % roundi(stats[&"atk"] as float)
	_spd_label.text = "SPD %.2fs" % (stats[&"attack_interval"] as float)
	_def_label.text = "DEF %d" % roundi(stats[&"defense"] as float)
	_crit_label.text = "CRIT %d%%" % roundi((stats[&"crit"] as float) * 100.0)
	_instability_bar.value = _data.instability
	_mush_tag.visible = _data.mushed
	_mush_jar.visible = _data.mushed
	_view.visible = not _data.mushed
	_instability_bar.visible = not _data.mushed
	_fused_tag.visible = _data.fused
	var count: int = _data.slots.size()
	_summary_label.text = "%d mutation%s | %d%% unstable" % [count,
		"" if count == 1 else "s", roundi(_data.instability)]
