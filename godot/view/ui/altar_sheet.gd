## 제단 시트 — docs/UI.md 화면 02 (v4.0: 건설 화면 대신 제단). 기획서 6.7 · 11.1.
## 세로 화면 = 아래에서 올라오는 시트(화면 높이 70%), 가로 창 = 오른쪽 패널. 시간은 멈추지 않고 1초에 두 번 다시 읽는다.
## 칸: 머리(제단 · 지폐) · 오늘의 제물(물건·개수·장터 값 [받기]) + [모두 받기] · 주민의 소원 편지 [들어준다] ·
##     거인의 등불(비운 동안 흐르는 시간 12 → 24시간 업그레이드 — 선반 화면이 생기면 그리로, SAVE.md 3 · SHOP.md) ·
##     건물 사 주기(우물 600 지폐 — 자리는 지금은 촌장이 고를 자리, 거인이 고르는 화면은 나중) · 접힌 칸 [강제로 거두기] + '마을에 생기는 일'.
## 숫자는 경제(지폐·개수)에만. 색·글꼴은 view/ui/ui_theme.gd.
## 쓰는 법: add_child(AltarSheet.new()) → setup(village) → open(). 신호: closed · bought(building).
class_name AltarSheet
extends Control

signal closed
signal bought(b: Building)

const REFRESH := 0.5
const SHEET_FRAC := 0.7                # 세로 화면: 아래 시트 높이 (화면의 70%)
const FORCE_AMT := 10                 # [강제로 거두기] 한 번에 거두는 개수 (안)
const SHOP_LIST := ["우물"]           # 지금 사 줄 수 있는 건물 (튜토리얼 T4 — 상점 화면 06이 생기면 그리로)

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
var shop_box: VBoxContainer
var lamp_box: VBoxContainer
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
	# 건물 사 주기
	_section(body, "건물 사 주기")
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 4)
	body.add_child(shop_box)
	# 거인의 등불 (임시 자리 — 선반 화면이 생기면 그리로)
	_section(body, "거인의 등불")
	lamp_box = VBoxContainer.new()
	lamp_box.add_theme_constant_override("separation", 4)
	body.add_child(lamp_box)
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
func _card(parent: Node, top: String, sub: String, btn_text: String, on_press: Callable, enabled := true) -> Button:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	parent.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var t := _label(col, top)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if sub != "":
		var s := _label(col, sub, "Small")
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
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	visible = true
	_sig = ""
	scroll.scroll_vertical = 0
	_refresh()


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
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


# ───────────────────────── 값 채우기 ─────────────────────────
func _state_sig() -> String:
	var items := village.altar_items()
	var s := "%s|%d|%s|%s|%s|%d|" % [str(items), int(Market.notes), str(force_open), _force_item, str(Market.sold), Market.lamp_level]
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
	for box: Node in [offer_box, letter_box, shop_box, lamp_box, force_box]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	# 오늘의 제물
	var items := village.altar_items()
	if items.is_empty():
		_label(offer_box, "제단이 비어 있어요. 저녁 기도 때 바쳐요.", "Small")
	var total := 0.0
	for item: String in items:
		var n := int(items[item])
		var val := Market.quote(item, n)
		total += val
		var fav := "  · 좋아하시는 것" if village.is_favourite(item) else ""
		_card(offer_box, "%s × %d" % [item, n], "장터 값 %s 지폐%s" % [_num(val), fav], "받기", _on_take.bind(item))
	take_all_btn.visible = items.size() > 1
	take_all_btn.text = "모두 받기 (%s 지폐)" % _num(total)
	# 소원 편지
	var wl := village.open_letters()
	if wl.is_empty():
		_label(letter_box, "아직 온 편지가 없어요.", "Small")
	for l: Dictionary in wl:
		if l["kind"] == "wish":
			_card(letter_box, "%s의 편지" % l["name"], "\"%s\"" % l["text"], "들어준다", _on_grant.bind(int(l["id"])))
		else:
			_card(letter_box, "%s의 편지" % l["name"], "\"%s\"" % l["text"], "새 땅 고르기", _on_split.bind(int(l["id"])), village.water is WorldWater)
	# 건물 사 주기
	for ty: String in SHOP_LIST:
		var cost := int(Balance.SHOP[ty])
		var have := village.count_type(ty)
		var sub := "%d 지폐 · 완성된 채 하늘에서 내려요" % cost
		if have > 0:
			sub += " (마을에 %d채)" % have
		_card(shop_box, ty, sub, "사 주기", _on_buy.bind(ty), Market.can_pay(cost))
	# 거인의 등불
	var nx := Market.next_lamp()
	if nx.is_empty():
		_label(lamp_box, "등불 %d시간 — 가장 큰 등불이에요. 자리를 비워도 하루 내내 병이 흘러요." % Market.lamp_hours(), "Small").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var cost := float(nx["cost"])
		_card(lamp_box, "등불 %d시간 → %d시간" % [Market.lamp_hours(), int(nx["hours"])],
			"%s · %s 지폐 · 자리를 비운 동안 병이 흐르고 제물이 쌓이는 시간" % [nx["name"], _num(cost)], "올리기", _on_lamp, Market.can_pay(cost))
	# 강제로 거두기 (접힌 칸)
	force_btn.text = ("▾ " if force_open else "▸ ") + "강제로 거두기"
	force_box.visible = force_open
	if force_open:
		var warn := _label(force_box, "창고에서 직접 가져가요. 주민들은 거인님이 노하셨다고 여겨요.", "Status")
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var any := false
		for item: String in Balance.PRICE:
			var have := floori(float(village.stock.get(item, 0.0)))
			if have < 1:
				continue
			any = true
			var n := mini(FORCE_AMT, have)
			var sub := "창고 %d개 · %d개에 %s 지폐\n%s" % [have, n, _num(Market.quote(item, n)), village.force_preview(item, n)]
			_card(force_box, item, sub, "거두기", _on_force.bind(item, n))
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


# ───────────────────────── 누르기 ─────────────────────────
func _on_take(item: String) -> void:
	if village.take_offering(item) > 0.0:
		GameAudio.fx("coins")                  # 지폐 받기 (짤랑) + "고맙습니다!" (AUDIO.md 3 · 7)
		GameAudio.say("offering_taken")
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


## 분가 자리 고르기 — 지금은 가까운 좋은 자리를 바로 고른다 (안개 속 자리 고르기 화면은 나중)
func _on_split(_id: int) -> void:
	var jw: JarWorld = get_meta("world") if has_meta("world") else null
	if jw == null:
		return
	var p: Variant = jw.split_spot(village)
	if p != null:
		jw.split_out(village, (p as Vector2).x, (p as Vector2).y)
	_refresh()


func _on_buy(type: String) -> void:
	var b := village.buy_building(type)
	if b != null:
		GameAudio.fx("drop_thud")              # 하늘에서 내려온 건물 (쿵 — 작게) + 진동 + "기적이다!"
		GameAudio.buzz()
		GameAudio.say("miracle")
		bought.emit(b)
	_refresh()


## 등불 올리기 — 거인 쪽 (GameSave.buy_lamp_upgrade: 지폐를 내고 거인 묶음을 곧바로 저장). 저장 관리자가 없으면 장터만
func _on_lamp() -> void:
	var sm := GameSave.get_instance()
	var ok := sm.buy_lamp_upgrade() if sm != null else Market.buy_lamp_upgrade()
	if ok:
		GameAudio.fx("chime")
	_refresh()


func _on_force(item: String, n: int) -> void:
	if village.force_take(item, n) > 0.0:
		GameAudio.fx("coins", "Room", -6.0)
		GameAudio.say("forced_take")
	_refresh()
