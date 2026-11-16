class_name Toasts
extends Control
## Bottom toast lines (placeholder band). Each line stays 2 s. The same text while it is showing only
## restarts its timer, so duplicates collapse into one line.

const LIFE_MS: int = 2000
const MAX_LINES: int = 3

var _box: VBoxContainer


func setup() -> void:
	# Under a CanvasLayer the parent has no rect, so use absolute geometry (base pixels), not anchors.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1080, 2340)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.position = Vector2(60, 1900)
	_box.size = Vector2(960, 190)
	add_child(_box)


func show_text(text: String) -> void:
	if text == "" or _box == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	for line: Node in _box.get_children():
		if str(line.get_meta("text", "")) == text:
			line.set_meta("until", now_ms + LIFE_MS)
			return
	while _box.get_child_count() >= MAX_LINES:
		var oldest: Node = _box.get_child(0)
		_box.remove_child(oldest)
		oldest.queue_free()
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = UiKit.panel_style(Color(0.15, 0.12, 0.1, 0.86), 20)
	box.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", box)
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	panel.set_meta("text", text)
	panel.set_meta("until", now_ms + LIFE_MS)
	_box.add_child(panel)


func _process(_delta: float) -> void:
	if _box == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	for line: Node in _box.get_children():
		if now_ms >= int(line.get_meta("until", 0)):
			_box.remove_child(line)
			line.queue_free()
