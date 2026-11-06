## 거인의 상점 시트 — docs/UI.md 화면 06 · SHOP.md 1 · 4 · ROADMAP A7.
## 세로 = 아래에서 올라오는 시트 (화면 78%), 가로 = 오른쪽 패널. 위: 제목 · 지폐 / 탭 줄 (잠긴 탭은 흐리게 '곧', 새로 열린 탭은 부드럽게 빛남) /
## 카드 2열: 물건 그림 + 이름 + '거인에게는 / 병 안에서는' 두 줄 + 값 버튼. 못 사면 값이 흐리게, 누르면 "지폐가 n 모자라요".
## 사면 물건이 거인의 손에 (Shop.buy) — 아래 띠 [손]에서 뚜껑을 열고 떨어뜨린다. 숫자는 값에만.
## 쓰는 법: add_child(ShopSheet.new()) → setup(village) → open(). 신호: closed · bought(item).
class_name ShopSheet
extends Control

signal closed
signal bought(item: String)

const SHEET_FRAC := 0.8
const REFRESH := 0.5
const ICON_PX := 56
const TOAST_SECS := 2.4

var village: Village
var tab := "건물"
var portrait_mode := true
var panel: PanelContainer
var notes_l: Label
var tab_row: HBoxContainer
var tab_scroll: ScrollContainer
var tab_buttons: Dictionary = {}       # 탭 이름 → Button
var scroll: ScrollContainer
var grid: GridContainer
var locked_box: VBoxContainer
var toast: Label
var hand_l: Label
var close_btn: Button
var _cards: Array = []                 # [{name, text, dim, btn}]
var _t := 0.0
var _glow_t := 0.0
var _toast_t := 0.0
var _sig := ""


func _init() -> void:
	name = "ShopSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_build()


func setup(v: Village) -> void:
	if v != village:
		_sig = ""
	village = v


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTheme.GAP)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	outer.add_child(head)
	var title := _label(head, "거인의 상점", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bn := GameIcons.rect("지폐", 22)
	bn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bn)
	notes_l = _label(head, "")
	notes_l.add_theme_font_override("font", UiTheme.font(true))
	notes_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sub := _label(outer, "거인의 방에 굴러다니는 작은 것이 병 안에서는 기적이 돼요. 산 것은 손에 들고, 뚜껑을 열어 떨어뜨려요.", "Small")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab_scroll = ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tab_scroll.custom_minimum_size.y = UiTheme.TOUCH + 4
	outer.add_child(tab_scroll)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(tab_row)
	for t: String in Shop.TABS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
		b.text = t
		GameIcons.button_icon(b, String(Shop.TAB_ICON.get(t, "")), 22)
		b.expand_icon = false
		b.pressed.connect(func() -> void:
			GameAudio.ui_click()
			select_tab(t))
		tab_row.add_child(b)
		tab_buttons[t] = b
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTheme.GAP)
	scroll.add_child(body)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", UiTheme.GAP)
	grid.add_theme_constant_override("v_separation", UiTheme.GAP)
	body.add_child(grid)
	locked_box = VBoxContainer.new()
	locked_box.add_theme_constant_override("separation", 6)
	body.add_child(locked_box)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_color_override("font_color", UiTheme.PAPER)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = UiTheme.TOAST_BG
	tsb.set_corner_radius_all(6)
	tsb.set_content_margin_all(6)
	toast.add_theme_stylebox_override("normal", tsb)
	toast.visible = false
	outer.add_child(toast)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiTheme.GAP)
	outer.add_child(foot)
	var hi := GameIcons.rect("손", 24)
	hi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hi)
	hand_l = _label(foot, "", "Small")
	hand_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hand_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(96, UiTheme.TOUCH)
	close_btn.pressed.connect(close)
	foot.add_child(close_btn)


func _label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


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
		var w := minf(UiTheme.SIDE_W + 40.0, vs.x * 0.55)
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -w
		panel.offset_right = 0
		panel.offset_top = 0
		panel.offset_bottom = 0
	SafeArea.pad_sheet(panel, SafeArea.insets(get_viewport()).y)


# ───────────────────────── 열기·닫기 ─────────────────────────
## 열면 새로 열린 탭부터 (없으면 지난 탭)
func open() -> void:
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	visible = true
	if village != null:
		Shop.update_unlocks(village)
		for t: String in Shop.TABS:
			if Shop.is_new(village, t):
				tab = t
				break
	select_tab(tab)


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
	visible = false
	closed.emit()


func select_tab(t: String) -> void:
	tab = t
	if village != null and Shop.tab_open(village, t):
		Shop.mark_seen(village, t)
	scroll.scroll_vertical = 0
	_sig = ""
	_refresh()
	var b: Button = tab_buttons.get(t)
	if b != null and is_inside_tree():
		tab_scroll.ensure_control_visible.call_deferred(b)


func _process(dt: float) -> void:
	if not visible or village == null:
		return
	_t += dt
	_glow_t += dt
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			toast.visible = false
	_style_tabs()
	if _t >= REFRESH:
		_t = 0.0
		_refresh()


## 탭 모양: 고른 탭 = 초록, 잠긴 탭 = 흐리게, 새로 열린 탭 = 금빛으로 숨 쉼 (빨간 점 대신)
func _style_tabs() -> void:
	var k := 0.5 + 0.5 * sin(_glow_t * 2.6)
	for t: String in tab_buttons:
		var b: Button = tab_buttons[t]
		var open_t := village != null and Shop.tab_open(village, t)
		b.modulate = Color(1, 1, 1, 1.0 if open_t else 0.55)
		var sb: StyleBoxFlat
		if t == tab:
			sb = UiTheme._box(UiTheme.PRIMARY, UiTheme.INK, 1, 6, 6)
		elif village != null and Shop.is_new(village, t):
			sb = UiTheme._box(UiTheme.BUTTON.lerp(Color("fff1c4"), k), UiTheme.GLOW.darkened(0.2), 2, 6, 6)
			sb.shadow_color = Color(UiTheme.GLOW, 0.3 + 0.4 * k)
			sb.shadow_size = int(2 + 4 * k)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_stylebox_override("pressed")
			for c in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.remove_theme_color_override(c)
			continue
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var fc := UiTheme.CHIP_TEXT if t == tab else UiTheme.INK
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, fc)


# ───────────────────────── 카드 ─────────────────────────
func _state_sig() -> String:
	var s := "%s|%d|%d|%s|%s|%d|%s" % [tab, int(Market.notes), Market.hand.size(), str(village.shop_open.keys()), str(village.shop_bought), village.era,
		str(SkyDrops.active_towers(village))]
	return s


func _refresh() -> void:
	if village == null:
		return
	notes_l.text = Shop._num(Market.notes)
	hand_l.text = "손에 든 것 %d / %d — 아래 [손]에서 떨어뜨려요" % [Market.hand.size(), Shop.HAND_MAX] if not Market.hand.is_empty() else "산 것은 아래 [손]에 들려요 (%d개까지)" % Shop.HAND_MAX
	var sig := _state_sig()
	if sig == _sig:
		return
	_sig = sig
	for box: Node in [grid, locked_box]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_cards = []
	if not Shop.tab_open(village, tab):
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		locked_box.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		card.add_child(col)
		var ic := GameIcons.rect(String(Shop.TAB_ICON.get(tab, "")), 72)
		ic.modulate = Color(1, 1, 1, 0.55)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
		var l := _label(col, "%s — 곧" % tab, "Section")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var h := _label(col, Shop.tab_hint(village, tab), "Small")
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var names := PackedStringArray()
		for it: String in Shop.items_in(tab):
			names.append(it)
		if not names.is_empty():
			var nl := _label(col, " · ".join(names), "Small")
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	for it: String in Shop.items_in(tab, village):
		_card(it)


func _card(item: String) -> void:
	var c := Shop.card(village, item)
	var lock := String(c["lock"])
	var can := Shop.can_buy(village, item)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)
	var ic: Control
	if bool(c["building"]):
		ic = BuildingThumb.rect(item, ICON_PX)
	else:
		ic = GameIcons.rect(String(c["icon"]), ICON_PX)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if lock != "":
		ic.modulate = Color(1, 1, 1, 0.5)
	col.add_child(ic)
	var nm := _label(col, item)
	nm.add_theme_font_override("font", UiTheme.font(true))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var g := _two(col, "거인에게는", String(c["giant"]))
	var ins := _two(col, "병 안에서는", String(c["inside"]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	b.add_theme_font_override("font", UiTheme.font(true))
	if lock != "":
		b.text = lock
		b.disabled = true
	else:
		b.text = Shop._num(float(c["price"]))
		GameIcons.button_icon(b, "지폐", 20)
		if not bool(can["ok"]):
			b.modulate = Color(1, 1, 1, 0.5)            # 못 사면 값이 흐리게 (누르면 까닭)
	b.pressed.connect(press.bind(item))
	col.add_child(b)
	_cards.append({"name": item, "text": "거인에게는: %s\n병 안에서는: %s" % [c["giant"], c["inside"]], "dim": lock != "" or not bool(can["ok"]), "btn": b,
		"labels": [g, ins]})
	if item == Shop.AMPOULE and lock == "":
		_two(col, "", "탑은 한 병에 둘까지 · 물가는 녹조 주의").modulate = Color(1, 1, 1, 0.85)


## '거인에게는' 작은 머리말 + 글
func _two(parent: Node, head: String, text: String) -> Label:
	if head != "":
		var h := _label(parent, head, "Small")
		h.add_theme_color_override("font_color", UiTheme.INK_BROWN if head == "병 안에서는" else UiTheme.INK_SOFT)
	var l := _label(parent, text, "Small")
	l.add_theme_color_override("font_color", UiTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


## 값 버튼 — 사거나 못 사는 까닭을 잠깐
func press(item: String) -> void:
	GameAudio.ui_click()
	var r := Shop.buy(village, item)
	if bool(r["ok"]):
		GameAudio.fx("coins")
		show_toast("%s — 손에 들었어요. 아래 [손]에서 떨어뜨려요." % item)
		bought.emit(item)
	else:
		GameAudio.fx("glass_tap_light", "Room", -8.0)
		show_toast(String(r["why"]))
	_sig = ""
	_refresh()


func show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	_toast_t = TOAST_SECS


# ───────────────────────── 시험용 ─────────────────────────
func cards() -> Array:
	return _cards


func toast_text() -> String:
	return toast.text if toast.visible else ""


func locked_text() -> String:
	var s := ""
	for c in locked_box.get_children():
		for l in c.find_children("*", "Label", true, false):
			s += (l as Label).text + " "
	return s
