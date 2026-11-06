## '자리를 비운 동안' 편지 — docs/SAVE.md 4.2. 촌장이 쓴 편지 한 장 (손글씨는 그림체가 정해질 때까지 UiTheme 글꼴).
## 큰 일 3~5줄 · 인구 변화 "13명 → 17명" · 새 얼굴(아기 초상) / 떠난 얼굴 · 기다리는 것(제물·소원 편지·위기 조짐) ·
## 비운 동안 쌓인 제물은 '기다리는 것' 맨 위에 장터 값과 함께 + [모두 받기] (곧바로 지폐, 저장 — SAVE.md 3.1).
## 등불보다 오래 비웠으면 머리에 "등불이 n시간 타고 꺼져 있었어요" (천천히 떠오름).
## [연대기에서 자세히] (비운 동안의 연대기를 같은 종이에) / [병 안으로] (닫힘 → closed).
## 쓰는 법: var l := ReturnLetter.new(); add_child(l); l.open(village, CatchUp.finish()의 편지, 연대기 시작 줄)
class_name ReturnLetter
extends Control

signal closed
signal chronicle_requested             # [연대기에서 자세히] — 장면이 받으면 연대기 화면(UI 07)을 연다 (없으면 이 종이에 비운 동안의 연대기)

const MAX_W := 340.0

var village: Village
var data: Dictionary = {}
var book_from := 0
var shade: ColorRect
var paper: PanelContainer
var scroll: ScrollContainer
var body: VBoxContainer
var chron_btn: Button
var enter_btn: Button
var showing_chronicle := false
var take_btn: Button                    # 제단 [모두 받기] (제물이 있을 때만)
var taken := 0.0                        # 편지에서 받은 지폐 (받았으면 > 0)


func _init() -> void:
	name = "ReturnLetter"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	visible = false
	shade = ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.07, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	paper = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	sb.anti_aliasing = false
	paper.add_theme_stylebox_override("panel", sb)
	add_child(paper)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	paper.add_child(outer)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	outer.add_child(row)
	chron_btn = _button(row, "연대기에서 자세히")
	chron_btn.pressed.connect(_toggle_chronicle)
	enter_btn = _button(row, "병 안으로")
	var psb := StyleBoxFlat.new()
	psb.bg_color = UiTheme.PRIMARY
	psb.border_color = UiTheme.INK
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(6)
	psb.set_content_margin_all(6)
	enter_btn.add_theme_stylebox_override("normal", psb)
	enter_btn.add_theme_stylebox_override("hover", psb)
	enter_btn.add_theme_color_override("font_color", UiTheme.PAPER)
	enter_btn.add_theme_color_override("font_hover_color", UiTheme.PAPER)
	enter_btn.pressed.connect(close)


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(GameAudio.ui_click)
	parent.add_child(b)
	return b


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := minf(MAX_W, vs.x - 16.0)
	var h := minf(vs.y * 0.86, 600.0)
	_place(w, h)
	if not showing_chronicle:
		_fit.call_deferred()


func _place(w: float, h: float) -> void:
	var vs := get_viewport_rect().size
	paper.custom_minimum_size = Vector2(w, h)
	paper.size = Vector2(w, h)
	paper.position = Vector2(roundf((vs.x - w) * 0.5), roundf((vs.y - h) * 0.5))


## 편지는 내용만큼만 (긴 편지는 스크롤) — 글줄이 감긴 뒤의 높이로
func _fit() -> void:
	var vs := get_viewport_rect().size
	var h := minf(vs.y * 0.86, 600.0)
	var need := body.get_combined_minimum_size().y + 14.0 * 2.0 + 8.0 + UiTheme.TOUCH + 2.0
	_place(paper.size.x, minf(h, need))


func open(v: Village, letter: Dictionary, from_line := 0) -> void:
	village = v
	data = letter
	book_from = from_line
	showing_chronicle = false
	taken = 0.0
	_fill_letter()
	visible = true
	_layout()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _toggle_chronicle() -> void:
	if not showing_chronicle and not chronicle_requested.get_connections().is_empty():
		chronicle_requested.emit()
		return
	showing_chronicle = not showing_chronicle
	if showing_chronicle:
		_fill_chronicle()
	else:
		_fill_letter()
	_layout()


func _clear() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	scroll.scroll_vertical = 0


func _label(text: String, variation := "", wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(l)
	return l


func _rule() -> void:
	var r := ColorRect.new()
	r.color = UiTheme.PAPER_LINE
	r.custom_minimum_size = Vector2(0, 1)
	body.add_child(r)


func _fill_letter() -> void:
	_clear()
	chron_btn.text = "연대기에서 자세히"
	var head := _label("자리를 비운 동안", "Title")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("거인님이 %s 비우신 사이" % CatchUp.away_words(float(data.get("away", 0.0))), "Small").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if float(data.get("slept", 0.0)) > 0.0:
		var lamp := _label("등불이 %d시간 타고 꺼져 있었어요" % int(data.get("lamp_h", 12)), "Small")
		lamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lamp.modulate.a = 0.0
		create_tween().tween_property(lamp, "modulate:a", 1.0, 0.8)
	_rule()
	_label("거인님께,")
	_label("자리를 비우신 동안 이런 일이 있었어요.")
	for e: String in data.get("events", []):
		_label("· " + e)
	var p0 := int(data.get("pop0", 0))
	var p1 := int(data.get("pop1", 0))
	var pl := _label("우리는 %d명 → %d명이 되었어요." % [p0, p1], "Section")
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if int(data.get("settlements", 1)) > 1:      # 넓은 세상: 세상 전체
		var wl := _label("세상 모든 무리 %d곳 · %d명 → %d명" % [int(data["settlements"]), int(data.get("world_pop0", p0)), int(data.get("world_pop1", p1))], "Small")
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var born: Array = data.get("born", [])
	if not born.is_empty():
		_label("새 얼굴", "Small")
		_faces(born.map(func(id: int) -> Resident: return village.person(id)), false)
	var lost: Array = data.get("lost", [])
	if not lost.is_empty():
		_label("떠난 얼굴", "Small")
		var rs: Array = []
		for l: Dictionary in lost:
			rs.append(_dead(int(l["id"])))
		_faces(rs, true)
	var waiting: Array = data.get("waiting", [])
	var altar_line := String(data.get("altar_line", ""))
	take_btn = null
	if not waiting.is_empty() or altar_line != "":
		_rule()
		_label("기다리는 것", "Section")
		if altar_line != "":
			_altar_row(altar_line)
		for w: String in waiting:
			_label("· " + w)
	if data.get("long", false):
		_label("오래 비우셔서, 거인님 이야기를 옛날이야기로 여기는 아이들도 생겼어요.")
	elif data.get("festival", false):
		_label("모두 광장에 모여 거인님을 기다리고 있어요!")
	var sign := _label("— 촌장 %s 올림" % String(data.get("chief", "")))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## 제단 줄 + [모두 받기] — 누르면 제단의 제물을 모두 장터에 팔아 곧바로 지폐 (Village.take_all → 거인의 행동이라 바로 저장)
func _altar_row(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	body.add_child(row)
	var l := Label.new()
	l.text = "· " + text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	take_btn = Button.new()
	take_btn.focus_mode = Control.FOCUS_NONE
	take_btn.custom_minimum_size = Vector2(92, UiTheme.TOUCH)
	take_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(take_btn)
	if taken > 0.0:
		_show_taken()
	else:
		take_btn.text = "모두 받기"
		take_btn.pressed.connect(take_all)


## [모두 받기] → 받은 지폐 (이미 받았거나 제단이 비었으면 0)
func take_all() -> float:
	if village == null or taken > 0.0:
		return 0.0
	var got := village.take_all()
	if got > 0.0:
		taken = got
		GameAudio.fx("coins")
		GameAudio.say("offering_taken")
	if take_btn != null:
		_show_taken()
	return got


func _show_taken() -> void:
	take_btn.disabled = true
	take_btn.text = ("%s 지폐 받음" % CatchUp._num(taken)) if taken > 0.0 else "받을 것 없음"


func _dead(id: int) -> Resident:
	if village == null:
		return null
	for r in village.dead:
		if r.id == id:
			return r
	return null


## 작은 얼굴 줄 (이름 아래) — 떠난 얼굴은 회색
func _faces(list: Array, gone: bool) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 4)
	body.add_child(flow)
	for r: Variant in list.slice(0, 8):
		if r == null:
			continue
		var res: Resident = r
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var face := FaceIcon.new()
		face.custom_minimum_size = Vector2(32, 32)
		face.set_resident(res)
		if gone:
			face.modulate = UiTheme.DEAD_TINT
		col.add_child(face)
		var nm := Label.new()
		nm.text = res.name
		nm.theme_type_variation = "Dead" if gone else "Small"
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		flow.add_child(col)
	if list.size() > 8:
		var more := Label.new()
		more.text = "그 밖 %d명" % (list.size() - 8)
		more.theme_type_variation = "Small"
		flow.add_child(more)


## 비운 동안의 연대기 (그 뒤로 쓰인 줄 전부)
func _fill_chronicle() -> void:
	_clear()
	chron_btn.text = "편지로"
	_label("연대기 — 비운 동안", "Title")
	_rule()
	if village == null:
		return
	var lines := village.book.slice(book_from)
	if lines.is_empty():
		_label("새로 적힌 일이 없어요.", "Small")
	for e: Dictionary in lines:
		_label(village.fmt_time(float(e["t"])), "Small")
		_label(String(e["text"]))
