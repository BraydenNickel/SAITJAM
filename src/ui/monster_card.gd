class_name MonsterCard
extends PanelContainer
## Compact card showing a monster preview, name, stats and instability.
## A mushed monster shows the mush-jar sprite instead of its body.

@onready var _view: MonsterView = %MonsterView
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
	tooltip_text = _data.title
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
