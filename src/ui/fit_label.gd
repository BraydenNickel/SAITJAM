@tool
class_name FitLabel
extends Label
## A Label that keeps long text inside its box: it word-wraps, then steps the
## font size down until the text fits in `max_lines` lines (and the height
## budget), never below `min_font_size`. If it still does not fit, the text is
## trimmed with an ellipsis and the full text goes in the tooltip.
## Re-fits only when the text or the label's width changes.
## Height budget: `custom_minimum_size.y` when set, else the label's own height
## when it is not inside a Container, else unlimited (only `max_lines` counts).
## Fitting is skipped in the editor so the overrides are never saved into scenes.

## Most lines the text may wrap to.
@export_range(1, 6) var max_lines: int = 2:
	set(value):
		max_lines = value
		_queue_fit(true)
## Smallest font size tried before falling back to the ellipsis.
@export var min_font_size: int = 6:
	set(value):
		min_font_size = value
		_queue_fit(true)
## Starting font size. 0 = the label's theme font size when it first fits.
@export var base_font_size: int = 0:
	set(value):
		base_font_size = value
		_queue_fit(true)

var _base: int = 0
var _fit_text: String = ""
var _fit_width: float = -1.0
var _queued: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	clip_text = false  # clip + wrap collapses a Label's height in a container
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	max_lines_visible = max_lines
	resized.connect(_queue_fit)
	minimum_size_changed.connect(_queue_fit)
	_queue_fit(true)

## Label has no text-changed signal, and a new text of the same height does not
## emit minimum_size_changed (e.g. a shop reroll), so watch the text directly.
func _process(_delta: float) -> void:
	if text != _fit_text and not _queued:
		_queue_fit()

func _queue_fit(force: bool = false) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if force:
		_fit_width = -1.0
	if _queued:
		return
	_queued = true
	_fit.call_deferred()

## Re-fits now if the text or width changed since the last fit.
func _fit() -> void:
	_queued = false
	if text == _fit_text and is_equal_approx(size.x, _fit_width):
		return
	_fit_text = text
	_fit_width = size.x
	if _base <= 0:
		_base = base_font_size if base_font_size > 0 else get_theme_font_size(&"font_size")
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	max_lines_visible = max_lines
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	tooltip_text = ""
	if size.x <= 1.0 or text == "":
		add_theme_font_size_override(&"font_size", _base)
		return
	var font_size: int = _base
	while font_size > min_font_size and not _fits(font_size):
		font_size -= 1
	add_theme_font_size_override(&"font_size", font_size)
	if not _fits(font_size):
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tooltip_text = text

func _fits(font_size: int) -> bool:
	var font: Font = get_theme_font(&"font")
	if font == null:
		return true
	var width: float = size.x
	var para: TextParagraph = TextParagraph.new()
	para.add_string(text, font, font_size)
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_TRIM_EDGE_SPACES
	var lines: int = para.get_line_count()
	if lines > max_lines:
		return false
	for i: int in lines:
		if para.get_line_width(i) > width + 0.5:
			return false  # a single word is wider than the label
	var line_h: float = font.get_height(font_size)
	var budget: float = custom_minimum_size.y
	if budget <= 0.0 and not (get_parent() is Container):
		budget = size.y
	if budget <= 0.0:
		return true
	var spacing: float = float(get_theme_constant(&"line_spacing"))
	return lines * line_h + (lines - 1) * spacing <= budget + 0.5
