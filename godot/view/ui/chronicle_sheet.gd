## 연대기 화면 — docs/UI.md 07 (1차, ROADMAP A10). 양피지 + 손글씨 (나눔손글씨 펜 — UiTheme.hand_font 한 곳, A14).
## 탭: 최근 (위에서 아래로 — 오래된 것 위·새것 아래, 열면 가장 최근 날부터, 병 달력 n일차마다 묶음 — 넓은 세상은 무리 이름을 붙여 모든 무리) ·
##      창세 신화 (창조가 적은 신화, 없으면 첫 기록 — 그것도 없으면 부드러운 빈 자리) ·
##      사람들 (살아 있음 · 잠듦 · 분가로 떠남 — 작은 얼굴 · 이름 · 나이, 살아 있는 사람을 누르면 주민 상세) ·
##      발견 (도감: 발견한 것 = 그림 · 처음 찾은 사람 · 날, 못 한 것 = 실루엣 + 힌트 한 줄 — sim/codex.gd).
## 세로 화면 = 아래에서 올라오는 큰 시트 (화면 90%), 가로 창 = 오른쪽 패널. 스크롤은 손가락으로 끌기 (버튼은 PASS — 끌면 스크롤).
## 데이터는 sim/chronicle.gd · sim/codex.gd (화면 없이 시험). 쓰는 법: setup(village, world) → open(tab). 신호: closed · resident_pressed(v, r).
class_name ChronicleSheet
extends Control

signal closed
signal resident_pressed(v: Village, r: Resident)
signal people_requested               # [사람들 목록] [모두 보기] → view/ui/people_sheet.gd

const TABS := ["최근", "창세 신화", "사람들", "발견"]
const SHEET_FRAC := 0.9
const PAGE := 150                     # 최근: 한 번에 보여 줄 줄 수 ('더 오래된 기록' 누를 때마다 더)
const REFRESH := 1.0

var village: Village
var world: JarWorld
var tab := 0
var portrait_mode := true
var limit := PAGE
var _t := 0.0
var _sig := ""

var panel: PanelContainer
var title_l: Label
var where_l: Label
var tab_btns: Array[Button] = []
var scroll: ScrollContainer
var _last_day: Control                 # 최근 탭: 가장 최근 날 머리줄 (열 때 여기부터 아래로 읽게)
var body: VBoxContainer
var close_btn: Button
var strip: PanelContainer              # [자람의 보상 Q9] 고비 도장 띠 — 제목과 탭 사이, 어느 탭에서나 보인다 (view/ui/milestone_stamps.gd)
var _strip_sig := ""


func _init() -> void:
	name = "ChronicleSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_build()


func setup(v: Village, w: JarWorld = null) -> void:
	if v != village:
		_sig = ""
	village = v
	world = w


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


## 같은 병의 무리 (소형 병 = [village])
func villages() -> Array:
	if world != null and not world.settlements.is_empty():
		return world.settlements
	return [village] if village != null else []


# ───────────────────────── 틀 ─────────────────────────
static func parchment_box(pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PARCHMENT
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(2)
	sb.border_width_bottom = 0
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0.2, 0.12, 0.04, 0.3)
	sb.shadow_size = 8
	sb.anti_aliasing = false
	return sb


func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	title_l = _label(head, "연대기", "Title")
	title_l.add_theme_font_override("font", UiTheme.hand_font())
	title_l.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE + 8)
	title_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	where_l = _label(head, "", "Small")
	where_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	where_l.add_theme_color_override("font_color", UiTheme.INK_BROWN.lightened(0.25))
	strip = PanelContainer.new()                     # [자람의 보상 Q9] 고비 도장 띠 (수첩 종이 한 줄 — _refresh_strip이 채움)
	strip.name = "StampStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color("fdf6dc")
	ssb.border_color = UiTheme.PARCHMENT_EDGE
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(4)
	ssb.content_margin_left = 6
	ssb.content_margin_right = 6
	ssb.content_margin_top = 4
	ssb.content_margin_bottom = 3
	strip.add_theme_stylebox_override("panel", ssb)
	strip.visible = false
	outer.add_child(strip)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	outer.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(GameAudio.ui_click)
		b.pressed.connect(show_tab.bind(i))
		tabs.add_child(b)
		tab_btns.append(b)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	outer.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_left", 2)
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(pad)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	pad.add_child(body)
	close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	close_btn.pressed.connect(GameAudio.ui_click)
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)
	_style_tabs()


func _label(parent: Node, text: String, variation := "", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


## 손글씨 줄 (연대기 글 — 갈색 잉크)
func _hand(parent: Node, text: String, size := 0) -> Label:
	var l := _label(parent, text, "", true)
	l.add_theme_font_override("font", UiTheme.hand_font())
	l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	l.add_theme_font_size_override("font_size", size if size > 0 else UiTheme.SIZE_HAND)
	l.add_theme_constant_override("line_spacing", 0)
	return l


func _rule(parent: Node) -> void:
	var r := ColorRect.new()
	r.color = UiTheme.PARCHMENT_EDGE
	r.color.a = 0.55
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


func _tab_box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_bottom = bw
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.set_content_margin_all(4)
	sb.anti_aliasing = false
	return sb


func _style_tabs() -> void:
	for i in tab_btns.size():
		var b := tab_btns[i]
		var on := i == tab
		var bg := UiTheme.PARCHMENT_DEEP if on else UiTheme.PARCHMENT.lightened(0.18)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, _tab_box(bg if st != "hover" else bg.lightened(0.06), UiTheme.PARCHMENT_EDGE, 3 if on else 1))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, UiTheme.INK_BROWN if on else UiTheme.INK_BROWN_SOFT)
		b.add_theme_font_override("font", UiTheme.font(on))


func _layout() -> void:
	var vs := get_viewport_rect().size
	portrait_mode = vs.y >= vs.x
	var sb := parchment_box()
	if portrait_mode:
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.anchor_top = 1.0 - SHEET_FRAC
		panel.anchor_bottom = 1.0
		panel.offset_left = 0
		panel.offset_right = 0
		panel.offset_top = maxf(0.0, SafeArea.insets(get_viewport()).x + 8.0 - vs.y * (1.0 - SHEET_FRAC))
		panel.offset_bottom = 0
	else:
		var w := minf(UiTheme.SIDE_W + 40.0, vs.x * 0.55)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -w
		panel.offset_right = 0
		panel.offset_top = 0
		panel.offset_bottom = 0
		sb.corner_radius_top_right = 0
		sb.corner_radius_bottom_left = 6
		sb.border_width_bottom = 2
		sb.border_width_right = 0
	sb.content_margin_bottom += SafeArea.insets(get_viewport()).y     # 제스처 막대 위로 내용
	panel.add_theme_stylebox_override("panel", sb)


# ───────────────────────── 열기·닫기 ─────────────────────────
func open(t := -1) -> void:
	var was := visible
	if not visible:
		GameAudio.fx("paper", "Room", -2.0)
	visible = true
	if t >= 0:
		tab = t
	limit = PAGE
	_sig = ""
	_style_tabs()
	_refresh()
	_scroll_start()
	if not was:
		UiTheme.slide_in(panel)              # (Q23 52) 아래에서 밀려 올라옴 (움직임 줄이기면 그대로)


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
	visible = false
	closed.emit()


func show_tab(i: int) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	limit = PAGE
	_sig = ""
	_style_tabs()
	_refresh()
	_scroll_start()


## 열 때 처음 보이는 자리 — 최근 탭은 가장 최근 날의 머리줄(그날 일을 위에서 아래로), 다른 탭은 맨 위
func _scroll_start() -> void:
	scroll.scroll_vertical = 0
	if tab != 0 or not is_instance_valid(_last_day):
		return
	# (Q21 ㊸) 줄 높이(손글씨 줄바꿈)와 스크롤 끝은 화면 몇 장에 걸쳐 정해진다 — 한 장만 기다리면 끝이 아직 0이라 맨 위(1일차)에 머묾.
	# 끝이 마지막 날 머리줄에 닿거나(또는 더 늘지 않을 때)까지 몇 장 더 맞춤
	var bar := scroll.get_v_scroll_bar()
	var last_max := -1.0
	for i in 8:
		await get_tree().process_frame
		if not is_instance_valid(_last_day) or not visible or tab != 0:
			return
		var want := maxi(0, int(_last_day.global_position.y - body.global_position.y) - 4)
		scroll.scroll_vertical = want
		if scroll_settled(i, want, scroll.scroll_vertical, bar.max_value, last_max, bar.page):
			return
		last_max = bar.max_value


## (Q21 ㊸) 열 때 맞춤을 그만둬도 되나: 마지막 날 머리줄까지 내려갔거나, 스크롤 끝이 두 장 내리 같고 그 끝에 닿았을 때.
## 머리줄 자리가 아직 0(줄이 아직 놓이지 않음)이면 '닿음'으로 치지 않는다 — 예전엔 첫 장에서 그만둬 1일차에 머묾
static func scroll_settled(i: int, want: int, got: int, max_v: float, last_max: float, page: float) -> bool:
	if want > 0 and got >= want:
		return true
	return i >= 2 and page > 0.0 and is_equal_approx(max_v, last_max) and got >= int(max_v - page) - 1


func _process(dt: float) -> void:
	if not visible or village == null:
		return
	_t += dt
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


func _state_sig() -> String:
	var vs := villages()
	match tab:
		0:
			return "0|%d|%d" % [Chronicle.line_count(vs), limit]
		1:
			return "1|%d|%d" % [village.myth.size() + mini(village.book.size(), 12), jar_notes().size()]
		2:
			return "2|%d|%d|%d|%d" % [village.people.size(), village.dead.size(), village.departed.size(), int(village.t / Balance.DAY * 10.0)]
		3:
			return "3|%s" % str(Codex.count(vs))
	return ""


func _refresh() -> void:
	if village == null:
		return
	var vs := villages()
	where_l.text = village.settlement_name if vs.size() > 1 and tab >= 1 else ("%d줄" % Chronicle.line_count(vs))
	_refresh_strip()
	var sig := _state_sig()
	if sig == _sig:
		return
	_sig = sig
	var keep := scroll.scroll_vertical
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	match tab:
		0: _fill_recent()
		1: _fill_myth()
		2: _fill_people()
		3: _fill_codex()
	scroll.scroll_vertical = keep


## [자람의 보상 Q9] 고비 도장 띠: 넘은 고비 = 잉크 도장, 아직 = 흐린 동그라미, 다음 고비 한 줄 (PROGRESSION 4.5). 도장이 늘 때만 다시 그린다
func _refresh_strip() -> void:
	var mv := Milestones.owner(villages())
	strip.visible = mv != null
	if mv == null:
		return
	var sig := "%d|%d" % [mv.get_instance_id(), Milestones.count(mv)]
	if sig == _strip_sig and strip.get_child_count() > 0:
		return
	_strip_sig = sig
	for c in strip.get_children():
		strip.remove_child(c)
		c.queue_free()
	strip.add_child(MilestoneStamps.make(mv, true))


# ───────────────────────── 최근 ─────────────────────────
func _fill_recent() -> void:
	var vs := villages()
	var groups := Chronicle.recent(vs, limit)
	if groups.is_empty():
		_soft("아직 적힌 일이 없어요.")
		return
	var shown := 0
	groups.reverse()                                   # 위에서 아래로 읽는다: 오래된 것 위 · 새것 아래 (사용자 결정 2026-11-07)
	for g: Dictionary in groups:
		shown += (g["entries"] as Array).size()
	if Chronicle.line_count(vs) > shown:               # 더 오래된 기록은 맨 위에서 이어 붙임
		var more := Button.new()
		more.text = "더 오래된 기록"
		more.focus_mode = Control.FOCUS_NONE
		more.mouse_filter = Control.MOUSE_FILTER_PASS
		more.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
		more.pressed.connect(func() -> void:
			var before := body.size.y
			limit += PAGE
			_sig = ""
			_refresh()
			await get_tree().process_frame
			scroll.scroll_vertical += int(body.size.y - before))   # 읽던 자리 그대로
		body.add_child(more)
	for g: Dictionary in groups:
		var hd := HBoxContainer.new()
		_last_day = hd
		hd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hd.add_theme_constant_override("separation", 8)
		body.add_child(hd)
		var l1 := ColorRect.new()
		l1.color = Color(UiTheme.PARCHMENT_EDGE, 0.6)
		l1.custom_minimum_size = Vector2(0, 1)
		l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hd.add_child(l1)
		var dl := _label(hd, "%d일차" % int(g["day"]), "Section")
		dl.add_theme_color_override("font_color", UiTheme.INK_BROWN)
		var l2 := l1.duplicate() as ColorRect
		hd.add_child(l2)
		var es: Array = (g["entries"] as Array).duplicate()
		es.reverse()
		for e: Dictionary in es:
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 8)
			body.add_child(row)
			var tl := _label(row, _clock(float(e["t"])), "Small")
			tl.custom_minimum_size.x = 34
			tl.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 1)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(col)
			if String(e["where"]) != "":
				var wl := _label(col, String(e["where"]), "Small")
				wl.add_theme_color_override("font_color", UiTheme.PRIMARY)
			if String(e.get("card", "")) != "":
				col.add_child(picture_card(String(e.get("pic", "")), String(e["text"])))
			else:
				_hand(col, String(e["text"]))


## (E1-0) 연대기 그림 카드 — 그 장면 한 장 + 손글씨 한 줄 (그림 파일이 없으면 글만 카드에)
static var _pic_cache: Dictionary = {}


func picture_card(path: String, text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fbf3dc")
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	sb.shadow_color = Color(0.3, 0.2, 0.05, 0.25)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(1, 2)
	pc.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(col)
	var tex: Texture2D = _pic_cache.get(path)
	if tex == null and path != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
			_pic_cache[path] = tex
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(0, 150)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.clip_contents = true
		col.add_child(tr)
	_hand(col, text)
	return pc


func _clock(tt: float) -> String:
	var c := fmod(village.start_clock + tt, Balance.DAY)
	return "%02d:%02d" % [int(c / Balance.HOUR), int(fmod(c, Balance.HOUR) / 60.0)]


func _soft(text: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size.y = 40
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(sp)
	var l := _hand(body, text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)


# ───────────────────────── 창세 신화 ─────────────────────────
func _fill_myth() -> void:
	var lines := Chronicle.myth(village)
	var sp := Control.new()
	sp.custom_minimum_size.y = 10
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(sp)
	var cap := _label(body, "— 태초의 이야기 —", "Small")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
	if lines.is_empty():
		_soft("아직 아무도 이 땅의 처음을 이야기하지 않았어요.\n언젠가 노인들이 아이들에게 들려줄 거예요.")
		_fill_jar()
		return
	for i in lines.size():
		var l := _hand(body, lines[i], UiTheme.SIZE_HAND + 2)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i < lines.size() - 1:
			var orn := _label(body, "·", "Small")
			orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			orn.add_theme_color_override("font_color", UiTheme.PARCHMENT_EDGE)
	_fill_jar()


# ───────────────────────── 이 병 (A28b — 별지기의 수첩) ─────────────────────────
## 핵 크기 = 병의 따뜻함 (OPENING v4.0-6): '조용한 별 / 따뜻한 별 / 뜨거운 별' + 살면서 처음 눈에 띈 병의 성질 (Village.jar_notes) — 손글씨, 숫자 없이.
const STAR_WORDS := ["조용한 별", "따뜻한 별", "뜨거운 별"]


## 같은 병의 무리가 적은 수첩 한 줄 (적힌 차례대로 — 같은 줄은 한 번만)
func jar_notes() -> Array:
	var out: Array = []
	var seen := {}
	for q: Village in villages():
		for n: Dictionary in q.jar_notes:
			var id := String(n.get("id", ""))
			if seen.has(id):
				continue
			seen[id] = true
			out.append(n)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	return out


func star_word() -> String:
	return STAR_WORDS[clampi(CoreWarmth.core_of(village), 0, 2)] if village != null else STAR_WORDS[1]


func _fill_jar() -> void:
	var sp := Control.new()
	sp.custom_minimum_size.y = 18
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(sp)
	_rule(body)
	var cap := _label(body, "— 이 병 —", "Small")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
	var star := _hand(body, star_word(), UiTheme.SIZE_HAND + 4)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var notes := jar_notes()
	var page := PanelContainer.new()                 # 수첩 한 장 (줄 공책 — NotebookNote와 같은 종이·왼쪽 묶음)
	page.name = "JarNotes"
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fdf6dc")
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	page.add_theme_stylebox_override("panel", sb)
	body.add_child(page)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(col)
	var head := _label(col, "별지기의 수첩", "Small")
	head.add_theme_font_override("font", UiTheme.font(true))
	head.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	if notes.is_empty():
		var l := _hand(col, "아직 이 병만의 버릇은 모르겠다. 지켜보다 보면 알게 되겠지.")
		l.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
		return
	for n: Dictionary in notes:
		var l := _hand(col, "· " + String(n.get("text", "")))
		l.add_theme_constant_override("line_spacing", -2)
		_rule(col)

# ───────────────────────── 사람들 ─────────────────────────
func _fill_people() -> void:
	var d := Chronicle.people(village, world)
	if not village.people.is_empty():     # [사람들 목록] 지금 사람들 명부로
		var all_b := Button.new()
		all_b.text = "모두 보기"
		all_b.focus_mode = Control.FOCUS_NONE
		all_b.mouse_filter = Control.MOUSE_FILTER_PASS
		all_b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
		all_b.pressed.connect(GameAudio.ui_click)
		all_b.pressed.connect(func() -> void: people_requested.emit())
		body.add_child(all_b)
	_people_section("살아 있음", d["alive"], "alive")
	_people_section("잠듦", d["dead"], "dead")
	_people_section("분가로 떠남", d["left"], "left")


func _people_section(title: String, rows: Array, kind: String) -> void:
	var hd := _label(body, "%s  %d" % [title, rows.size()], "Section")
	hd.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	if rows.is_empty():
		var e := _label(body, {"alive": "아무도 없어요.", "dead": "아직 잠든 사람이 없어요.", "left": "아직 떠난 사람이 없어요."}[kind], "Small")
		e.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
		_rule(body)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(grid)
	for row: Dictionary in rows:
		grid.add_child(_person_row(row, kind))
	_rule(body)


func _person_row(row: Dictionary, kind: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r: Resident = row["r"]
	var alive := kind == "alive" or (kind == "left" and r != null and not r.dead and row["v"] != null)
	var bg := UiTheme.PARCHMENT.lightened(0.12) if alive else Color(UiTheme.PARCHMENT_DEEP, 0.5)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.08) if st == "hover" else (bg.darkened(0.06) if st == "pressed" else bg)
		sb.border_color = Color(UiTheme.PARCHMENT_EDGE, 0.7)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(4)
		b.add_theme_stylebox_override(st, sb)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 4
	hb.offset_right = -4
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 6)
	b.add_child(hb)
	var face := FaceIcon.new()
	face.custom_minimum_size = Vector2(28, 28)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.set_resident(r)
	if kind == "dead" or (r != null and r.dead):
		face.modulate = UiTheme.DEAD_TINT
	hb.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	var nm := _label(col, "%s · %d세" % [row["name"], int(row["age"])])
	nm.clip_text = true
	nm.add_theme_color_override("font_color", UiTheme.INK_BROWN if alive else UiTheme.INK_BROWN_SOFT)
	var note := ""
	match kind:
		"alive":
			note = ResidentText.job_word(r, village) if r != null else ""
		"dead":
			note = "%s · %s" % [ResidentText.death_word(r) if r != null else "", row["note"]]
		"left":
			note = String(row["note"])
	if note != "":
		var nl := _label(col, note, "Small")
		nl.clip_text = true
		nl.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
	b.custom_minimum_size.y = maxf(UiTheme.TOUCH, 40.0)
	if alive and r != null:
		var rv: Village = row["v"]
		b.pressed.connect(GameAudio.ui_click)
		b.pressed.connect(func() -> void: resident_pressed.emit(rv, r))
	else:
		b.disabled = true
	return b


# ───────────────────────── 발견 도감 ─────────────────────────
func _fill_codex() -> void:
	var vs := villages()
	var rows := Codex.entries(vs)
	var c := Codex.doc_count(vs)
	var hd := _label(body, "발견 %d / %d" % [c.x, c.y], "Section")
	hd.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	var sub := _label(body, "세상이 바뀌면, 그 자리에 있던 사람이 찾아내요.", "Small", true)
	sub.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT)
	# DISCOVERIES 25종 (발견한 것 먼저, 표 순서 그대로) — 곁가지(누룩·푸른 가루·얼룩버섯·물고기 지혜)는 찾은 것만 뒤에
	var main: Array = rows.filter(func(r: Dictionary) -> bool: return String(r["doc"]) != "")
	var side: Array = rows.filter(func(r: Dictionary) -> bool: return String(r["doc"]) == "" and bool(r["known"]))
	var grid := _codex_grid()
	for want: bool in [true, false]:
		for row: Dictionary in main:
			if bool(row["known"]) == want:
				grid.add_child(_codex_card(row))
	if not side.is_empty():
		var sh := _label(body, "그 밖에 찾은 것", "Section")
		sh.add_theme_color_override("font_color", UiTheme.INK_BROWN)
		var g2 := _codex_grid()
		for row: Dictionary in side:
			g2.add_child(_codex_card(row))


func _codex_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(grid)
	return grid


func _codex_card(row: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var known: bool = row["known"]
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PARCHMENT.lightened(0.15) if known else Color(UiTheme.PARCHMENT_DEEP, 0.55)
	sb.border_color = UiTheme.PARCHMENT_EDGE if known else Color(UiTheme.PARCHMENT_EDGE, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hb)
	var icon_name := String(row["icon"])
	var art_key := String(row.get("art", ""))
	if art_key != "" and GameIcons.has(art_key):      # 발견 그림 (art/icons/disc) — 없으면 임시 아이콘
		icon_name = art_key
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(34, 34)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(holder)
	if icon_name != "" and GameIcons.has(icon_name):
		var ic := GameIcons.rect(icon_name, 34)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		if not known:
			ic.modulate = Color(0.28, 0.2, 0.12, 0.38)       # 실루엣
		holder.add_child(ic)
	else:
		var q := Label.new()
		q.text = "?" if not known else "★"
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.theme_type_variation = "Title"
		q.add_theme_color_override("font_color", Color(UiTheme.INK_BROWN, 0.55 if not known else 0.8))
		holder.add_child(q)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	var nm := _label(col, String(row["name"]) if known else "???", "Section")
	nm.add_theme_color_override("font_color", UiTheme.INK_BROWN if known else UiTheme.INK_BROWN_FAINT)
	var line := _label(col, Codex.credit(row) if known else String(row["hint"]), "Small", true)
	line.add_theme_color_override("font_color", UiTheme.INK_BROWN_SOFT if known else UiTheme.INK_BROWN_FAINT)
	if not known:
		line.add_theme_font_override("font", UiTheme.hand_font())
		line.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND_SMALL)
	elif String(row.get("found", "")) != "":          # 찾은 것: 한 줄 이야기 (손글씨)
		var fl := _label(col, String(row["found"]), "Small", true)
		fl.add_theme_font_override("font", UiTheme.hand_font())
		fl.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND_SMALL)
		fl.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	return card
