## 처음 겪는 사건의 안내 창 (EVENTS_STAGING 6b · 6c · 2c — sim/firsts.gd의 표를 그린다).
## 화면 가운데 작은 종이 카드: 그림 하나 · 제목 · 2~4줄 · [확인] / [보러 가기]. 뒤는 살짝 어둡게 (한 번에 하나).
## 거인에게 하는 말이다 (주민 말 아님) — 지폐·사다 같은 말을 써도 된다. 숫자·확률은 없다.
## 장면이 연출이 끝난 뒤 Firsts.queue에서 하나씩 꺼내 show_id로 띄운다. 신호: closed(id) · go(id, what)
class_name FirstPopup
extends Control

signal closed(id: String)
signal go(id: String, what: String)

var id := ""
var shade: ColorRect
var card: PanelContainer
var icon: TextureRect
var title_l: Label
var body: VBoxContainer
var ok_btn: Button
var go_btn: Button
var _a := 0.0


func _init() -> void:
	name = "FirstPopup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	visible = false
	shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.06, 0.05, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.15, 0.1, 0.05, 0.35)
	sb.shadow_size = 12
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	icon = GameIcons.rect("", 44)
	head.add_child(icon)
	title_l = Label.new()
	title_l.add_theme_font_override("font", UiTheme.title_font())
	title_l.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE)
	title_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title_l)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	col.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	go_btn = Button.new()
	go_btn.focus_mode = Control.FOCUS_NONE
	go_btn.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	go_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_btn.pressed.connect(GameAudio.ui_click)
	go_btn.pressed.connect(func() -> void:
		var was := id
		var what := String(Firsts.POPUPS.get(was, {}).get("go", ""))
		close()
		go.emit(was, what))
	row.add_child(go_btn)
	ok_btn = Button.new()
	ok_btn.text = "확인"
	ok_btn.theme_type_variation = "Primary"
	ok_btn.focus_mode = Control.FOCUS_NONE
	ok_btn.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_btn.pressed.connect(GameAudio.ui_click)
	ok_btn.pressed.connect(close)
	row.add_child(ok_btn)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var vs := get_viewport_rect().size
	var wide := bool(Firsts.POPUPS.get(id, {}).get("wide", false))
	var w := minf(340.0 if wide else 312.0, vs.x - 28.0)
	for c in body.get_children():                    # 감기는 글줄은 폭을 정해 줘야 높이가 맞다
		var kids := c.get_children()
		var dot := kids.size() > 1
		for l in kids:
			if l is Label and (l as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
				var lw := w - 32.0 - 4.0 - (16.0 if dot else 0.0)
				(l as Label).custom_minimum_size.x = lw
				(l as Label).size = Vector2(lw, 0)      # 감기는 폭을 곧바로 (컨테이너 정렬을 기다리지 않게)
				(l as Label).update_minimum_size()
		(c as Control).update_minimum_size()
	title_l.custom_minimum_size.x = w - 32.0 - 54.0
	title_l.size = Vector2(w - 32.0 - 54.0, 0)
	title_l.visible = true
	card.custom_minimum_size = Vector2(w, 0)
	card.size = Vector2(w, 0)
	card.size = card.get_combined_minimum_size()
	card.position = Vector2(roundf((vs.x - w) * 0.5), roundf(maxf(20.0, (vs.y - card.size.y) * 0.44)))


func showing() -> bool:
	return visible and id != ""


## 안내 창 하나를 띄운다 (Firsts.POPUPS id) — 돌려줌: 띄웠나
func show_id(pid: String) -> bool:
	var p: Dictionary = Firsts.POPUPS.get(pid, {})
	if p.is_empty():
		return false
	id = pid
	title_l.text = String(p.get("title", ""))
	icon.texture = GameIcons.tex(String(p.get("icon", "")))
	icon.visible = icon.texture != null
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	var lines: Array = p.get("lines", [])
	for ln: String in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		body.add_child(row)
		if lines.size() > 2:                         # 줄이 많으면 작은 점으로 나눠 읽기 쉽게
			var dot := Label.new()
			dot.text = "·"
			dot.add_theme_color_override("font_color", UiTheme.PARCHMENT_EDGE)
			dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(dot)
		var l := Label.new()
		l.text = ln
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", UiTheme.INK)
		l.add_theme_constant_override("line_spacing", 3)
		row.add_child(l)
	var g := String(p.get("go", ""))
	go_btn.visible = g != ""
	go_btn.text = String(p.get("go_text", "보러 가기"))
	visible = true
	_a = 0.0
	modulate.a = 0.0
	_layout()
	_relayout()
	GameAudio.fx("paper", "Room", -6.0)
	return true


func _relayout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame                  # 글줄이 감긴 뒤 높이를 다시
	_layout()


func close() -> void:
	if not visible:
		return
	var was := id
	visible = false
	id = ""
	closed.emit(was)


func _process(dt: float) -> void:
	if not visible:
		return
	_a = minf(1.0, _a + dt / 0.25)
	modulate.a = _a


## (시험) 지금 창의 글 전부
func text_all() -> String:
	var s := title_l.text
	for c in body.get_children():
		for l in c.get_children():
			if l is Label:
				s += "\n" + (l as Label).text
	return s
