## 묻는 쪽지 하나 (예: 뒤로 가기 → "거인의 방으로 돌아갈까요?" — UI.md 00) — 화면 가운데 종이 카드 + 단추 둘.
## 쓰는 법: add_child(ConfirmSheet.new()) → ask(질문, 예 글자, 아니오 글자). 신호 answered(yes). 바깥을 누르거나 뒤로 가기 = 아니오.
## (Q23 ㊼) 되돌릴 수 없는 물음은 ask(…, danger = true): '예'는 위험 모양(종이 바탕 + 밤색 테두리·글자 — UiTheme "Danger"),
## [그만두기]가 이끼 초록 주요 모양이고 오른쪽(엄지 쪽)에 선다. 보통 물음은 예전 그대로 ('예'가 초록, 오른쪽).
class_name ConfirmSheet
extends Control

signal answered(yes: bool)

var card: PanelContainer
var text_l: Label
var yes_btn: Button
var no_btn: Button
var row: HBoxContainer
var danger := false


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
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	col.add_child(row)
	no_btn = _btn(row, false)
	yes_btn = _btn(row, true)
	_style(false)


## 보통: 예 = 이끼 초록(오른쪽) · 아니오 = 종이 / 위험: 예 = Danger(왼쪽) · 아니오 = 이끼 초록(오른쪽)
func _style(is_danger: bool) -> void:
	danger = is_danger
	yes_btn.theme_type_variation = "Danger" if is_danger else "Primary"
	no_btn.theme_type_variation = "Primary" if is_danger else ""
	row.move_child(no_btn, 1 if is_danger else 0)


func _btn(parent: Node, yes: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(GameAudio.ui_click)
	b.pressed.connect(answer.bind(yes))
	parent.add_child(b)
	return b


func ask(question: String, yes_text := "예", no_text := "아니요", is_danger := false) -> void:
	_style(is_danger)
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
