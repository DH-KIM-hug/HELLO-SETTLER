## 묻는 쪽지 하나 (예: 뒤로 가기 → "거인의 방으로 돌아갈까요?" — UI.md 00) — 화면 가운데 종이 카드 + 단추 둘.
## 쓰는 법: add_child(ConfirmSheet.new()) → ask(질문, 예 글자, 아니오 글자). 신호 answered(yes). 바깥을 누르거나 뒤로 가기 = 아니오.
class_name ConfirmSheet
extends Control

signal answered(yes: bool)

var card: PanelContainer
var text_l: Label
var yes_btn: Button
var no_btn: Button


func _init() -> void:
	name = "ConfirmSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.07, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(UiTheme.RADIUS)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size.x = 280
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	text_l = Label.new()
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	col.add_child(row)
	no_btn = _btn(row, false)
	yes_btn = _btn(row, true)
	var psb := StyleBoxFlat.new()
	psb.bg_color = UiTheme.PRIMARY
	psb.set_corner_radius_all(6)
	psb.set_content_margin_all(6)
	yes_btn.add_theme_stylebox_override("normal", psb)
	yes_btn.add_theme_stylebox_override("hover", psb)
	var psb2 := psb.duplicate() as StyleBoxFlat
	psb2.bg_color = UiTheme.PRIMARY.darkened(0.15)
	yes_btn.add_theme_stylebox_override("pressed", psb2)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		yes_btn.add_theme_color_override(k, UiTheme.PAPER)


func _btn(parent: Node, yes: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(GameAudio.ui_click)
	b.pressed.connect(answer.bind(yes))
	parent.add_child(b)
	return b


func ask(question: String, yes_text := "예", no_text := "아니요") -> void:
	text_l.text = question
	yes_btn.text = yes_text
	no_btn.text = no_text
	visible = true
	GameAudio.fx("sheet_open", "Room", -6.0)


func answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	answered.emit(yes)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and not card.get_global_rect().has_point((e as InputEventMouseButton).global_position):
		answer(false)
