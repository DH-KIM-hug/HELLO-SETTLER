## 제단 시트 — docs/UI.md 화면 02 (v4.0: 건설 화면 대신 제단). 기획서 6.7 · 11.1.
## 세로 화면 = 아래에서 올라오는 시트(화면 높이 70%), 가로 창 = 오른쪽 패널. 시간은 멈추지 않고 1초에 두 번 다시 읽는다.
## 칸: 머리(제단 · 지폐) · 오늘의 제물(물건·개수·장터 값 [받기]) + [모두 받기] · 주민의 소원 편지 [들어준다] ·
##     접힌 칸 [강제로 거두기] + '마을에 생기는 일'. (건물 사 주기는 상점 시트 — view/ui/shop_sheet.gd, 등불은 선반 — view/ui/shelf_sheet.gd)
## 숫자는 경제(지폐·개수)에만. 색·글꼴은 view/ui/ui_theme.gd.
## 쓰는 법: add_child(AltarSheet.new()) → setup(village) → open(). 신호: closed.
class_name AltarSheet
extends Control

signal closed
signal split_requested(from: Village)
signal shop_requested(item: String)    # (Q25) 촌장의 '연장이 모자라요' 편지 [연장 꾸러미 보기] — 장면이 상점을 그 물건의 탭으로 연다
signal reveal_requested(v: Village)     # [계시] (A5) — 장면이 받아 계시 연출(RevelationShow) → Village.giant_reveal   # 분가 편지 [새 땅 고르기] — 넓은 세상 장면이 받으면 거인이 땅을 고르는 화면으로

const REFRESH := 0.5
const SHEET_FRAC := 0.7                # 세로 화면: 아래 시트 높이 (화면의 70%)
const FORCE_AMT := 10                 # [강제로 거두기] 한 번에 거두는 개수 (안)

var village: Village
var portrait_mode := true
var force_open := false
var _t := 0.0
var _sig := ""
var _force_item := ""

var panel: PanelContainer
var scroll: ScrollContainer
var notes_l: Label
var offer_box: VBoxContainer
var take_all_btn: Button
var letter_box: VBoxContainer
var reveal_box: VBoxContainer          # 맨 위 [계시] 칸 (시대 점수가 찼을 때만 — 빛나는 카드)
var _reveal_card: PanelContainer
var _glow_t := 0.0
var force_btn: Button
var force_box: VBoxContainer
var close_btn: Button


func _init() -> void:
	name = "AltarSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_build()


func setup(v: Village) -> void:
	village = v


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


# ───────────────────────── 틀 ─────────────────────────
func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTheme.GAP)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var title := _label(head, "제단", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_l = _label(head, "")
	notes_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(outer, "주민들이 저녁 기도 때 남는 물건을 바쳐요. 받은 물건은 더 만들어 바쳐요.", "Small").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTheme.GAP)
	scroll.add_child(body)
	# [계시] (A5) — 맨 위, 시대 점수가 찼을 때만
	reveal_box = VBoxContainer.new()
	reveal_box.add_theme_constant_override("separation", 4)
	body.add_child(reveal_box)
	# 오늘의 제물
	_section(body, "오늘의 제물")
	offer_box = VBoxContainer.new()
	offer_box.add_theme_constant_override("separation", 4)
	body.add_child(offer_box)
	take_all_btn = _button(body, "모두 받기")
	take_all_btn.pressed.connect(_on_take_all)
	# 소원 편지
	_section(body, "소원 편지")
	letter_box = VBoxContainer.new()
	letter_box.add_theme_constant_override("separation", 4)
	body.add_child(letter_box)
	# 강제로 거두기 (접힌 칸)
	body.add_child(HSeparator.new())
	force_btn = _button(body, "")
	force_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	force_btn.pressed.connect(func() -> void:
		force_open = not force_open
		_sig = ""
		_refresh())
	force_box = VBoxContainer.new()
	force_box.add_theme_constant_override("separation", 4)
	body.add_child(force_box)
	var pad := Control.new()
	pad.custom_minimum_size.y = 4
	body.add_child(pad)
	close_btn = _button(outer, "닫기")
	close_btn.pressed.connect(close)


func _label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, expand := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS      # 스크롤 안에서 끌면 스크롤 (부모 패널이 STOP — 화면 뒤로 새지 않음)
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b


func _section(parent: Node, title: String) -> void:
	parent.add_child(HSeparator.new())
	_label(parent, title, "Section")


## 한 줄 카드: 왼쪽 글(위·아래), 오른쪽 버튼
## hand_sub = 아랫줄을 손글씨로 (주민이 쓴 편지)
func _card(parent: Node, top: String, sub: String, btn_text: String, on_press: Callable, enabled := true, icon := "", hand_sub := false) -> Button:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	parent.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	if icon != "" and GameIcons.has(icon):     # 물건 그림 (A8 아이콘)
		var ic := GameIcons.rect(icon, 32)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var t := _label(col, top)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if sub != "":
		var s := _label(col, sub, "Hand" if hand_sub else "Small")
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := _button(row, btn_text, false)
	b.custom_minimum_size.x = 84
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not enabled
	b.pressed.connect(on_press)
	return b


## 세로 화면 = 아래 시트, 가로 = 오른쪽 패널
func _layout() -> void:
	var vs := get_viewport_rect().size
	portrait_mode = vs.y >= vs.x
	if portrait_mode:
		panel.theme_type_variation = "Sheet"
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.anchor_top = 1.0 - SHEET_FRAC
		panel.anchor_bottom = 1.0
		panel.offset_left = 0
		panel.offset_right = 0
		panel.offset_top = 0
		panel.offset_bottom = 0
	else:
		panel.theme_type_variation = "Side"
		var w := minf(UiTheme.SIDE_W, vs.x * 0.5)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -w
		panel.offset_right = 0
		panel.offset_top = 0
		panel.offset_bottom = 0
	SafeArea.pad_sheet(panel, SafeArea.insets(get_viewport()).y)   # 제스처 막대 위로 내용


# ───────────────────────── 열기·닫기 ─────────────────────────
func open() -> void:
	var was := visible
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	visible = true
	_sig = ""
	scroll.scroll_vertical = 0
	_refresh()
	if not was:
		UiTheme.slide_in(panel)              # (Q23 52) 아래에서 밀려 올라옴 (움직임 줄이기면 그대로)


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
	visible = false
	force_open = false
	closed.emit()


func _process(dt: float) -> void:
	if not visible or village == null:
		return
	_t += dt
	_glow_t += dt
	if _reveal_card != null and is_instance_valid(_reveal_card):     # [계시] 카드가 천천히 빛남 (빨간 점 대신)
		var sb := _reveal_card.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			var k := 0.5 + 0.5 * sin(_glow_t * 2.4)
			sb.shadow_color = Color(UiTheme.GLOW, 0.35 + 0.35 * k)
			sb.shadow_size = int(6 + 6 * k)
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


# ───────────────────────── 값 채우기 ─────────────────────────
func _state_sig() -> String:
	var items := village.altar_items()
	var s := "%s|%d|%s|%s|%s|%d|%s|%s|%d|" % [str(items), int(Market.notes), str(force_open), _force_item, str(Market.sold), Market.lamp_level,
		str(village.revelation_pending()), str(village.altar_built), village.era]
	s += "%d|%s|" % [village.altar_level, str(Altar.rebuilding(village))]
	for l: Dictionary in village.open_letters():
		s += "%d;" % int(l["id"])
	if force_open:
		for k: String in Balance.PRICE:
			s += "%d," % int(float(village.stock.get(k, 0.0)))
	return s


func _refresh() -> void:
	if village == null:
		return
	notes_l.text = "%s 지폐" % _num(Market.notes)
	var sig := _state_sig()
	if sig == _sig:
		return
	_sig = sig
	for box: Node in [reveal_box, offer_box, letter_box, force_box]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_reveal_card = null
	if village.revelation_pending():
		_fill_reveal()
	# 오늘의 제물
	var items := village.altar_items()
	if not village.altar_built:               # 깨달음 전 (A4b) — 제단이 아직 없다
		var l := _label(offer_box, "아직 제단이 없어요. 사람들은 하늘 너머에 누가 있는지 몰라요." if not village.aware else "사람들이 모닥불 곁에 제단을 짓고 있어요.", "Small")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif items.is_empty():
		_label(offer_box, "제단이 비어 있어요. 저녁 기도 때 바쳐요.", "Small")
	var total := 0.0
	for item: String in items:
		var n := int(items[item])
		var val := Market.quote(item, n)
		total += val
		var fav := "  · 좋아하시는 것" if village.is_favourite(item) else ""
		_card(offer_box, "%s × %d" % [item, n], "장터 값 %s 지폐%s" % [_num(val), fav], "받기", _on_take.bind(item), true, item)
	take_all_btn.visible = items.size() > 1
	take_all_btn.text = "모두 받기 (%s 지폐)" % _num(total)
	if village.altar_built:                   # v5 제단 크기 (SAVE.md 3.1): 담는 양 + 넓히기
		var dn := Altar.days(village)
		var how := "반나절치" if dn < 1.0 else "%d일치" % int(dn)
		var sub := "%s — 기도 %d번(%s)까지 쌓여요%s" % [Altar.level_name(village), Altar.slots(village), how, " · 가득 찼어요" if Altar.full(village) else ""]
		var nx := Altar.next(village)
		if nx.is_empty():
			_label(offer_box, sub, "Small")
		else:
			var lk := String(nx["lock"])
			var bt := "넓히기 %s" % _num(float(nx["cost"])) if lk == "" else lk
			_card(offer_box, "제단 넓히기 → %s" % nx["name"], sub, bt, _on_expand, lk == "" and Market.can_pay(float(nx["cost"])))
	# 소원 편지
	var wl := village.open_letters()
	if wl.is_empty():
		_label(letter_box, "아직 온 편지가 없어요." if village.altar_built else "제단이 생기면 사람들이 별지기님께 편지를 써요.", "Small")
	for l: Dictionary in wl:
		if l["kind"] == "wish" and ToolShort.is_tool_wish(l):     # (Q25) 들어주는 길은 상점의 연장 꾸러미 — 떨어뜨리면 이루어짐
			_card(letter_box, "%s의 편지" % l["name"], "\"%s\"" % l["text"], "연장 꾸러미 보기", _on_tools_shop, true, "", true)
		elif l["kind"] == "wish":
			_card(letter_box, "%s의 편지" % l["name"], "\"%s\"" % l["text"], "들어준다", _on_grant.bind(int(l["id"])), true, "", true)
		else:
			_card(letter_box, "%s의 편지" % l["name"], "\"%s\"" % l["text"], "새 땅 고르기", _on_split.bind(int(l["id"])), village.water is WorldWater, "", true)
	# 강제로 거두기 (접힌 칸)
	force_btn.text = ("▼ " if force_open else "▶ ") + "강제로 거두기"
	force_box.visible = force_open
	if force_open:
		var warn := _label(force_box, "창고에서 직접 가져가요. 주민들은 별지기님이 노하셨다고 여겨요.", "Status")
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var any := false
		for item: String in Balance.PRICE:
			var have := floori(float(village.stock.get(item, 0.0)))
			if have < 1:
				continue
			any = true
			var n := mini(FORCE_AMT, have)
			var sub := "창고 %d개 · %d개에 %s 지폐\n%s" % [have, n, _num(Market.quote(item, n)), village.force_preview(item, n)]
			_card(force_box, item, sub, "거두기", _on_force.bind(item, n), true, item)
		if not any:
			_label(force_box, "창고에 거둘 것이 없어요.", "Small")


static func _num(v: float) -> String:
	var n := int(roundf(v))
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## [계시] 칸 (A5): 노인의 편지 + 빛나는 [계시 내리기]. 누르면 장면이 연출을 띄운다 (reveal_requested)
func _fill_reveal() -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff4d2")
	sb.border_color = UiTheme.GLOW.darkened(0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	sb.shadow_color = Color(UiTheme.GLOW, 0.5)
	sb.shadow_size = 8
	card.add_theme_stylebox_override("panel", sb)
	reveal_box.add_child(card)
	_reveal_card = card
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var nx: String = Balance.ERAS[mini(village.era + 1, Balance.ERAS.size() - 1)]
	var head := _label(col, "계시 — 새 시대 '%s'" % nx, "Section")
	head.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	var who := String(village.revelation.get("name", ""))
	var txt := _label(col, "%s\"%s\"" % ["%s의 편지  " % who if who != "" else "", String(village.revelation.get("text", ""))])
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_override("font", UiTheme.hand_font())
	txt.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND)
	var un := Village.era_unlocks(village.era + 1)
	if not un.is_empty():
		var ul := _label(col, "열리는 것: " + " · ".join(un.slice(0, 8)), "Small")
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := _button(col, "계시 내리기")
	b.theme_type_variation = "Primary"
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = UiTheme.GLOW
	gsb.border_color = UiTheme.INK_BROWN
	gsb.set_border_width_all(1)
	gsb.set_corner_radius_all(6)
	gsb.set_content_margin_all(6)
	for st in ["normal", "hover", "pressed"]:
		var s2 := gsb.duplicate() as StyleBoxFlat
		if st == "hover":
			s2.bg_color = UiTheme.GLOW.lightened(0.12)
		elif st == "pressed":
			s2.bg_color = UiTheme.GLOW.darkened(0.12)
		b.add_theme_stylebox_override(st, s2)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UiTheme.INK_BROWN)
	b.pressed.connect(_on_reveal)


func _on_reveal() -> void:
	if not village.revelation_pending():
		return
	if reveal_requested.get_connections().is_empty():      # 장면이 없으면 (시험) 바로
		if village.giant_reveal():
			GameAudio.fx("chime")
		_sig = ""
		_refresh()
		return
	reveal_requested.emit(village)


# ───────────────────────── 누르기 ─────────────────────────
func _on_take(item: String) -> void:
	if village.take_offering(item) > 0.0:
		GameAudio.fx("coins")                  # 지폐 받기 (짤랑) + "고맙습니다!" (AUDIO.md 3 · 7)
		GameAudio.say("offering_taken")
	_refresh()


func _on_expand() -> void:
	if Altar.expand(village):
		GameAudio.fx("coins")
	_refresh()


func _on_take_all() -> void:
	if village.take_all() > 0.0:
		GameAudio.fx("coins")
		GameAudio.say("offering_taken")
	_refresh()


func _on_grant(id: int) -> void:
	if village.grant_wish(id):
		GameAudio.fx("chime")                  # 소원 들어줌 (맑은 차임)
		GameAudio.say("wish_granted")
	_refresh()


## (Q25) [연장 꾸러미 보기] — 장면이 상점을 연다 (시트는 닫힘)
func _on_tools_shop() -> void:
	GameAudio.ui_click()
	shop_requested.emit(ToolShort.TOOL_ITEM)


## 분가 자리 고르기 — 장면이 split_requested를 받으면 거인이 땅을 누르는 화면, 아니면 가까운 좋은 자리를 바로
func _on_split(_id: int) -> void:
	if not split_requested.get_connections().is_empty():
		split_requested.emit(village)
		return
	var jw: JarWorld = get_meta("world") if has_meta("world") else null
	if jw == null:
		return
	var p: Variant = jw.split_spot(village)
	if p != null:
		jw.split_out(village, (p as Vector2).x, (p as Vector2).y)
	_refresh()


func _on_force(item: String, n: int) -> void:
	if village.force_take(item, n) > 0.0:
		GameAudio.fx("coins", "Room", -6.0)
		GameAudio.say("forced_take")
	_refresh()
