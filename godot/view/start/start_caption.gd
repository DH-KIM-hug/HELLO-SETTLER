## 화면 아래 손글씨 자막 (OPENING.md 0 '화자') — 등장인물·음성 없이, 한 글자씩 써진다. 종이 띠 위 먹색 글씨.
class_name StartCaption
extends PanelContainer

const CPS := 18.0                     # 1초에 써지는 글자 수

var label: Label
var full := ""
var _shown := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.988, 0.965, 0.905, 0.92)
	sb.border_color = Color(0.145, 0.13, 0.133, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	add_theme_stylebox_override("panel", sb)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UiTheme.font())
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UiTheme.INK)
	label.add_theme_constant_override("line_spacing", 3)
	add_child(label)


## 새 자막 (instant = 바로 다 보임 — 캡처·시험)
func say(text: String, instant := false) -> void:
	full = text
	_shown = float(text.length()) if instant else 0.0
	label.text = text
	label.visible_characters = int(_shown)
	visible = text != ""


func done() -> bool:
	return int(_shown) >= full.length()


func _process(dt: float) -> void:
	if int(_shown) < full.length():
		var before := int(_shown)
		_shown += dt * CPS
		label.visible_characters = int(_shown)
		if int(_shown) / 6 != before / 6:
			GameAudio.fx("paper", "Room", -18.0)       # 사각사각 (아주 작게)
