## 창고 시트 — 창고 띠를 누르면 (다른 시트와 같은 모양: 세로 화면 = 아래 시트, 가로 = 오른쪽 패널).
##   맨 위: 무리가 여럿이면 무리 고르기 (처음엔 지금 보는 무리) · 식량이 며칠 가나 한 줄
##   묶음: 먹을 것 / 재료 / 도구·옷 / 특별한 것 — 물건마다 아이콘 · 양 · 지난 하루 변화 (만든 것 − 쓴 것) · 한 줄 설명
##   열려 있는 동안 1초에 두 번 새로 씀 (물건 목록이 그대로면 글자만 바꿈)
## 쓰는 법: var s := StoreSheet.new() → s.setup(book, scene) → add_child → s.open(village)
class_name StoreSheet
extends Control

signal closed

const SHEET_FRAC := 0.66
const EVERY := 0.5

var panel: PanelContainer
var scroll: ScrollContainer
var body: VBoxContainer
var pick_row: HBoxContainer
var summary_l: Label
var book: StoreBook
var scene: Object
var village: Village
var rows: Dictionary = {}                # 이름 → {amt, chg, note}
var _sig := ""
var _t := 0.0


func _init() -> void:
	name = "StoreSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiTheme.GAP)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	head.add_child(GameIcons.rect("빵", 30))
	var title := _label(head, "창고", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_row = HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 4)
	outer.add_child(pick_row)
	summary_l = _label(outer, "", "Small")
	summary_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(outer, "오른쪽 숫자 = 지난 하루 동안 늘고 준 양 (만든 것 - 쓴 것)", "Small").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)


func setup(b: StoreBook, s: Object) -> void:
	book = b
	scene = s


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


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
	if vs.y >= vs.x:
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
	SafeArea.pad_sheet(panel, SafeArea.insets(get_viewport()).y)


func open(v: Village = null) -> void:
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	visible = true
	village = v if v != null else (scene.call("focus_village") if scene != null else null)
	_sig = ""
	scroll.scroll_vertical = 0
	refresh()


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
	visible = false
	closed.emit()


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if _t < EVERY:
		return
	_t = 0.0
	refresh()


func _villages() -> Array:
	var out: Array = []
	if scene != null:
		for vv: Array in scene.call("village_views"):
			out.append(vv[0])
	elif village != null:
		out.append(village)
	return out


func select(v: Village) -> void:
	village = v
	_sig = ""
	scroll.scroll_vertical = 0
	refresh()


## 물건 목록이 바뀌었으면 다시 짓고, 아니면 글자만
func refresh() -> void:
	if village == null:
		return
	var vs := _villages()
	if not vs.has(village) and not vs.is_empty():
		village = vs[0]
	if book != null:
		book.sample(village)
	var gs := StoreBook.groups(village)
	var sig := "%d|%d|%s" % [vs.size(), village.get_instance_id(), str(gs)]
	if sig != _sig:
		_sig = sig
		_rebuild(gs, vs)
	var days := StoreBook.food_days(village)
	var need := StoreBook.food_need(village)
	if need <= 0.0:
		summary_l.text = "먹을 것 %s" % StoreBook.short(village.food_total())
	else:
		summary_l.text = "먹을 것 %s · 하루에 %s 먹어요 · %s" % [StoreBook.short(village.food_total()), StoreBook.short(need),
			("%.1f일치" % days) if days < 10.0 else ("%d일치" % int(days))]
	summary_l.add_theme_color_override("font_color", StoreStrip.WARM if StoreBook.food_warn(village) else UiTheme.INK_SOFT)
	for k: String in rows:
		var r: Dictionary = rows[k]
		var val := StoreBook.amount(village, k)
		var ch := book.day_change(village, k) if book != null else 0.0
		(r["amt"] as Label).text = StoreBook.short(val)
		var chl: Label = r["chg"]
		var tr := StoreBook.trend(ch, val)
		chl.text = ("+" if ch > 0.5 else "") + StoreBook.short(ch) if absf(ch) >= 0.5 else "0"
		chl.add_theme_color_override("font_color", StoreStrip.UP if tr > 0 else (StoreStrip.DOWN if tr < 0 else UiTheme.INK_SOFT))
		(r["note"] as Label).text = StoreBook.note(village, k, ch)


func _rebuild(gs: Array, vs: Array) -> void:
	for c in pick_row.get_children():
		c.queue_free()
	pick_row.visible = vs.size() > 1
	if vs.size() > 1:
		for v: Village in vs:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = v.settlement_name if v.settlement_name != "" else "마을"
			b.clip_text = true
			b.custom_minimum_size = Vector2(0, 36)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if v == village:
				b.theme_type_variation = "FollowOn"
			b.pressed.connect(select.bind(v))
			pick_row.add_child(b)
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	rows.clear()
	for g: Array in gs:
		var ks: Array = g[1]
		if ks.is_empty():
			continue
		var sec := _label(body, String(g[0]), "Section")
		sec.set_meta("group", g[0])
		for k: String in ks:
			_row(k)
	if rows.is_empty():
		_label(body, "창고가 비어 있어요", "Small")


func _row(k: String) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.set_meta("good", k)
	body.add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var ic := GameIcons.rect(k if GameIcons.has(k) else "밀", 28)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	h.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var nm := _label(top, k)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var amt := _label(top, "")
	amt.add_theme_font_override("font", UiTheme.font(true))
	var chg := _label(top, "", "Small")
	chg.custom_minimum_size.x = 44
	chg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var note := _label(col, "", "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows[k] = {"amt": amt, "chg": chg, "note": note}


## 시트에 보이는 묶음: {묶음 제목: [물건…]} (시험용)
func shown_groups() -> Dictionary:
	var d := {}
	var cur := ""
	for c in body.get_children():
		if c.is_queued_for_deletion():
			continue
		if c.has_meta("group"):
			cur = String(c.get_meta("group"))
			d[cur] = []
		elif c.has_meta("good") and cur != "":
			(d[cur] as Array).append(String(c.get_meta("good")))
	return d
