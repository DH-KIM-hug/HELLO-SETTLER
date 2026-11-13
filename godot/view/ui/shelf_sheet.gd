## 선반 시트 — docs/UI.md 화면 05 · 기획서 12 · 5.5 · BALANCE v3-4 통합표 (ROADMAP C1). 거인의 방 선반과 같은 곳 (GIANT_ROOM 1).
##   병들: 선반의 병마다 카드 (이름 · n일째 · 시대 · 인구 · 기후) + [들어가기] (지금 보는 병은 '지금 보는 병'). 사 둔 빈 병은 [만들기]
##   기념품 (Q19): 병 목록 바로 아래 — 주워 온 기념품이 작은 그림으로 (주운 차례, 여러 줄). 누르면 선반의 것과 같은 종이 쪽지
##     (무엇 · 어느 지구 · 병 며칠째 · 누가). 없으면 조용한 한 줄. 개수·진행도·보상 말 없음
##     (Q20 ㊱) 쪽지는 그림 줄들 **아래**에 그 높이만큼 벌어진 띠에 뜬다 (누른 그림과 같은 세로줄, 띠가 보이게 시트가 스스로 밀림) —
##     예전처럼 누른 그림 바로 위에 떠서 윗줄 그림을 가리지 않는다. 누른 그림만 또렷하고 나머지는 옅게
##   새 병: 다음 병까지 지폐 진행도 → [새 병 사기 6,000] (세 번째 30,000 · 네 번째부터 80,000) · 기후 고르기 (지금은 온대 — "다른 기후는 곧")
##   거인의 등불: 비운 동안 흐르는 시간 12 → 16 → 20 → 24시간 (SAVE.md 3 — 2,000 · 6,000 · 15,000)
##   키트 업그레이드: 밀밭 1,000 · 목조 주택 6,000 · 가족 하나 더 8,000/12,000 · 암반 컵 하나 더 4,000 — 그 건물을 지어 본 뒤 열림, 산 것은 끄고 켬
##   (거인의 다리·유적 탐방은 곧)
## 쓰는 법: add_child(ShelfSheet.new()) → open(). 저장 관리자(GameSave)가 없으면 등불만 (시험·캡처).
## 신호: closed · enter_requested(id) (그 병으로 — 장면이 switch_jar) · make_jar_requested() (새 병을 샀거나 사 둔 병 — 장면이 빠른 창조로)
class_name ShelfSheet
extends Control

signal closed
signal enter_requested(id: int)
signal make_jar_requested

const SHEET_FRAC := 0.72

var panel: PanelContainer
var jars_box: VBoxContainer
var buy_box: VBoxContainer
var souv_box: VBoxContainer             # [기념품 Q19] 주워 온 기념품 (그림 줄 또는 조용한 한 줄)
var souv_flow: HFlowContainer           # 지금 그려 둔 그림 줄 (없으면 null)
var souvenir_note: SouvenirNote         # 그림을 누르면 뜨는 쪽지 (선반의 것과 같은 것 — view/room/souvenir_note.gd)
var souv_gap: Control                   # (Q20) 그림 줄 아래, 쪽지가 뜰 띠 (쪽지가 열린 동안만 쪽지 높이만큼 벌어진다)
var souv_open := -1                     # (Q20) 지금 쪽지가 열린 그림 번호 (없으면 -1)
var scroll: ScrollContainer
var lamp_box: VBoxContainer
var kit_box: VBoxContainer
var notes_l: Label
var star_l: Label                       # '별생활 N일째' (STORY 4 · N2) — 제목 아래 작게
var confirm: ConfirmSheet
var sm: GameSave = null                 # 비면 GameSave.get_instance()
var current_id := -1                    # 지금 보는 병 (장면이 알려 줌 — 비면 sm.current)
var climate := "온대"                   # 새 병의 기후 (고른 것)
var _sig := ""
var _t := 0.0
var _pending_buy := false


func _init() -> void:
	name = "ShelfSheet"
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
	var ti := GameIcons.rect("선반", 30)
	head.add_child(ti)
	var title := _label(head, "선반", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bn := GameIcons.rect("지폐", 22)
	bn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bn)
	notes_l = _label(head, "")
	notes_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	notes_l.add_theme_font_override("font", UiTheme.font(true))
	star_l = _label(outer, "", "Small")
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTheme.GAP)
	scroll.add_child(body)
	_section(body, "선반", "선반의 병들")
	jars_box = _box(body)
	var sh := HBoxContainer.new()                     # [기념품 Q19] 병 목록 바로 아래
	body.add_child(sh)
	var si := TextureRect.new()
	si.texture = SouvenirView.pic_texture("more")
	si.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	si.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	si.custom_minimum_size = Vector2(26, 26)
	si.mouse_filter = Control.MOUSE_FILTER_IGNORE
	si.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sh.add_child(si)
	_label(sh, "기념품", "Section").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	souv_box = _box(body)
	buy_box = _box(body)
	body.add_child(HSeparator.new())
	_section(body, "등불", "별지기의 등불")
	lamp_box = _box(body)
	body.add_child(HSeparator.new())
	_section(body, "밀", "키트 업그레이드")
	var kh := _label(body, "다음 새 세상부터 처음부터 함께 놓여요. 산 것은 끄고 켤 수 있어요.", "Small")
	kh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kit_box = _box(body)
	body.add_child(HSeparator.new())
	var soon := _label(body, "병과 병 사이 별지기의 다리 · 유적 탐방은 곧 열려요.", "Small")
	soon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)
	confirm = ConfirmSheet.new()
	add_child(confirm)
	confirm.answered.connect(_on_confirm)
	souvenir_note = SouvenirNote.new()                # 맨 위에 (시트 어디를 눌러도 닫히기만)
	add_child(souvenir_note)
	souvenir_note.visibility_changed.connect(_on_note_visibility)


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


func _box(parent: Node) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", 6)
	parent.add_child(b)
	return b


func _section(parent: Node, icon: String, text: String) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	h.add_child(GameIcons.rect(icon, 26))
	_label(h, text, "Section").size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _card(parent: Node) -> HBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	return row


func _col(row: Node) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	return col


func _button(row: Node, text: String, cb: Callable, money := false, w := 96) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, UiTheme.TOUCH)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.text = text
	b.clip_text = false
	if money:
		GameIcons.button_icon(b, "지폐", 20)
	b.pressed.connect(cb)
	row.add_child(b)
	return b


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


func _sm() -> GameSave:
	return sm if sm != null else GameSave.get_instance()


func open() -> void:
	var was := visible
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	visible = true
	_sig = ""
	_refresh()
	if not was:
		UiTheme.slide_in(panel)              # (Q23 52) 아래에서 밀려 올라옴 (움직임 줄이기면 그대로)


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
		UiTheme.slide_out(self, panel)       # (Q29) 열 때와 짝으로 아래로 내려감 (움직임 줄이기면 바로) — 닫히는 동안 누름은 막힘
	visible = false
	confirm.visible = false
	souvenir_note.close()
	closed.emit()


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if _t >= 0.5:
		_t = 0.0
		_refresh()
	if souv_open >= 0:
		_reveal_gap()                                   # (Q20) 화면 크기가 바뀌어도 띠는 보이는 곳에 · 쪽지는 띠 위에
		_place_note()


func _cur() -> int:
	var s := _sm()
	if current_id >= 0:
		return current_id
	return s.current if s != null else -1


func _refresh() -> void:
	notes_l.text = Shop._num(Market.notes)
	var s := _sm()
	star_l.text = "별생활 %d일째" % s.star_days() if s != null else ""
	star_l.visible = star_l.text != ""
	var shelf: Array = s.shelf_list() if s != null else []
	var sig := "%d|%d|%s|%s|%s|%s|%s" % [int(Market.notes), Market.lamp_level, str(shelf), str(s.giant if s != null else {}), climate, _cur(), _souvenir_sig()]
	if sig == _sig:
		return
	_sig = sig
	_fill_jars(s, shelf)
	_fill_souvenirs()
	_fill_buy(s, shelf)
	_fill_lamp()
	_fill_kits(s)


static func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# ───────────────────────── 병들 ─────────────────────────
## 카드 한 줄: "초록별 · 12일째" / "마을 · 23명 · 온대"
static func jar_lines(j: Dictionary) -> Array:
	var nm := String(j.get("name", ""))
	if nm == "":
		nm = "나의 작은 병"
	var era := int(j.get("era", 0))
	var era_s: String = Balance.ERAS[clampi(era, 0, Balance.ERAS.size() - 1)]
	return ["%s · %d일째" % [nm, int(j.get("day", 1))], "%s · %d명 · %s" % [era_s, int(j.get("pop", 0)), String(j.get("climate", Balance.CLIMATE_DEFAULT))]]


func _fill_jars(s: GameSave, shelf: Array) -> void:
	_clear(jars_box)
	if s == null or shelf.is_empty():
		var l := _label(jars_box, "아직 선반에 병이 없어요.", "Small")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	for j: Dictionary in shelf:
		var row := _card(jars_box)
		var col := _col(row)
		var ln := jar_lines(j)
		_label(col, ln[0]).add_theme_font_override("font", UiTheme.font(true))
		_label(col, ln[1], "Small")
		var id := int(j.get("id", -1))
		if id == _cur():
			var here := _label(row, "지금 보는 병", "Small")
			here.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			_button(row, "들어가기", func() -> void: _enter(id))
	var pj := s.pending_jar()
	if not pj.is_empty():
		var row := _card(jars_box)
		var col := _col(row)
		_label(col, "사 둔 빈 병").add_theme_font_override("font", UiTheme.font(true))
		_label(col, "%s · 아직 세상이 없어요" % String(pj.get("climate", "온대")), "Small")
		_button(row, "만들기", func() -> void: make_jar_requested.emit())


func _enter(id: int) -> void:
	GameAudio.ui_click()
	enter_requested.emit(id)


# ───────────────────────── 기념품 (Q19) ─────────────────────────
const SOUVENIR_EMPTY := "아직 없어요. 마을이 고비를 넘으면 작은 것이 하나씩 놓여요."


## 별지기가 주워 온 기념품 (거인 저장 — 주운 차례, 오래된 것부터). 저장 계통이 없으면 빈 것
func souvenir_list() -> Array:
	var s := _sm()
	return s.player.souvenirs if s != null else []


func _souvenir_sig() -> String:
	var out := ""
	for r: Variant in souvenir_list():
		if r is Dictionary:
			out += String((r as Dictionary).get("key", (r as Dictionary).get("id", ""))) + ","
	return out


func _fill_souvenirs() -> void:
	# 그림 줄을 다시 그려도 (자동 저장 등으로 시트가 새로 채워질 때) 열린 쪽지는 같은 기념품이면 그대로 둔다
	var keep := souv_open if souvenir_note != null and souvenir_note.is_open() else -1
	var keep_key := String(souvenir_note.shown.get("key", "")) if keep >= 0 else ""
	_clear(souv_box)
	souv_flow = null
	souv_gap = null
	souv_open = -1
	var list := souvenir_list()
	if keep >= 0 and not (keep < list.size() and list[keep] is Dictionary and String((list[keep] as Dictionary).get("key", "")) == keep_key):
		keep = -1
		souvenir_note.close()
	if list.is_empty():
		var l := _label(souv_box, SOUVENIR_EMPTY, "Small")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	souv_flow = HFlowContainer.new()
	souv_flow.add_theme_constant_override("h_separation", 6)
	souv_flow.add_theme_constant_override("v_separation", 6)
	souv_box.add_child(souv_flow)
	var px := Balance.SOUVENIR_SHEET_PIC
	for i in list.size():
		if not (list[i] is Dictionary):
			continue
		var rec: Dictionary = list[i]
		var b := TextureButton.new()
		b.name = "Souvenir%d" % i
		b.texture_normal = SouvenirView.pic_texture(String(rec.get("id", "")))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(px, px)
		b.focus_mode = Control.FOCUS_NONE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.pressed.connect(open_souvenir.bind(i))
		souv_flow.add_child(b)
	souv_gap = Control.new()                            # (Q20) 쪽지가 뜰 띠 — 닫혀 있으면 자리를 차지하지 않는다
	souv_gap.name = "SouvenirGap"
	souv_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	souv_gap.visible = false
	souv_box.add_child(souv_gap)
	if keep >= 0:
		_show_note(keep)


const NOTE_PAD := 4.0                   # (Q20) 띠 안에서 쪽지 위아래 틈 (px)
const SOUV_DIM := 0.4                   # (Q20) 쪽지가 열린 동안 다른 그림의 짙기


## 그림을 누름 → 선반의 것과 같은 작은 쪽지 (무엇 · 어느 지구 · 병 며칠째 · 누가). 열었으면 true.
## (Q20 ㊱) 쪽지는 그림 줄들 아래의 띠에 뜬다 — 어떤 기념품 그림도 가리지 않는다. 띠가 보이도록 시트가 스스로 밀린다
func open_souvenir(i: int) -> bool:
	var list := souvenir_list()
	if i < 0 or i >= list.size() or not (list[i] is Dictionary):
		return false
	GameAudio.fx("glass_tap_light", "Room", -12.0)
	_show_note(i)
	return true


func _show_note(i: int) -> void:
	var list := souvenir_list()
	var at := get_viewport_rect().size * 0.5 if is_inside_tree() else Vector2(180, 320)
	souvenir_note.open(list[i], at)
	souv_open = i
	if souv_flow == null or souv_gap == null:
		return
	for c: Node in souv_flow.get_children():
		if c is Control:
			(c as Control).modulate = Color(1, 1, 1, 1.0 if c.name == "Souvenir%d" % i else SOUV_DIM)
	souv_gap.custom_minimum_size = Vector2(0.0, souvenir_note.panel.size.y + NOTE_PAD * 2.0)
	souv_gap.visible = true
	_settle_layout(panel)
	_reveal_gap()
	_place_note()


## (Q20) 띠가 다 보이게 시트를 민다 (띠가 스크롤 칸 아래로 나가 있으면 그만큼, 위로 나가 있으면 그만큼)
func _reveal_gap() -> void:
	if souv_gap == null or not souv_gap.visible:
		return
	var over := souv_gap.get_global_rect().end.y - scroll.get_global_rect().end.y
	var under := scroll.get_global_rect().position.y - souv_gap.get_global_rect().position.y
	var before := scroll.scroll_vertical
	if over > 0.5:
		scroll.scroll_vertical += int(ceil(over))
	elif under > 0.5:
		scroll.scroll_vertical -= int(ceil(under))
	if scroll.scroll_vertical != before:
		_settle_layout(scroll)


## (Q20) 쪽지를 띠 위에: 누른 그림과 같은 세로줄 (띠 안으로 밀어 넣음)
func _place_note() -> void:
	if souv_gap == null or souv_flow == null or souv_open < 0 or not souvenir_note.is_open():
		return
	var gap := souv_gap.get_global_rect()
	var sz := souvenir_note.panel.size
	var b := souv_flow.get_node_or_null("Souvenir%d" % souv_open) as Control
	var cx := b.get_global_rect().get_center().x if b != null else gap.get_center().x
	var right := minf(gap.end.x, get_viewport_rect().size.x - gap.position.x) if is_inside_tree() else gap.end.x      # 화면 밖으로도 나가지 않게
	var x := clampf(cx - sz.x * 0.5, gap.position.x, maxf(gap.position.x, right - sz.x))
	souvenir_note.panel.global_position = Vector2(x, gap.position.y + NOTE_PAD)


## (Q20) 쪽지가 닫히면 (어디를 눌러도 닫힌다) 띠를 접고 그림을 모두 또렷하게
func _on_note_visibility() -> void:
	if souvenir_note.is_open():
		return
	souv_open = -1
	if souv_gap != null and is_instance_valid(souv_gap):
		souv_gap.visible = false
	if souv_flow != null and is_instance_valid(souv_flow):
		for c: Node in souv_flow.get_children():
			if c is Control:
				(c as Control).modulate = Color.WHITE


## (Q20) 칸들을 지금 바로 다시 놓는다 (위에서 아래로) — 띠를 벌린 그 화면에서 쪽지 자리를 알아야 해서 다음 화면을 기다리지 않는다
## 두 번 돈다: 여러 줄로 접히는 칸(HFlowContainer)은 한 번 놓여 봐야 제 높이를 알고, 그 높이로 위 칸이 다시 놓인다
static func _settle_layout(n: Node) -> void:
	for i in 2:
		_sort_down(n)


static func _sort_down(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c: Node in n.get_children():
		if c is Control and (c as Control).visible:
			_sort_down(c)


# ───────────────────────── 새 병 사기 ─────────────────────────
func _fill_buy(s: GameSave, shelf: Array) -> void:
	_clear(buy_box)
	if s == null:
		return
	var n := maxi(1, shelf.size())
	if n >= Shelf.MAX_JARS:
		_label(buy_box, "선반이 가득 찼어요 (병 %d개)." % Shelf.MAX_JARS, "Small")
		return
	var price := Shelf.jar_price(n)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	buy_box.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	_label(col, "새 병 — 새 기후의 새 세상").add_theme_font_override("font", UiTheme.font(true))
	var bar := ProgressBar.new()                      # 다음 병까지 지폐 진행도 (UI 05)
	bar.min_value = 0.0
	bar.max_value = price
	bar.value = minf(Market.notes, price)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	col.add_child(bar)
	_label(col, "다음 병까지 %s / %s" % [Shop._num(minf(Market.notes, price)), Shop._num(price)], "Small")
	var cr := HBoxContainer.new()                      # 기후 (한 병 = 한 기후대 — 기획서 5.2)
	cr.add_theme_constant_override("separation", 6)
	col.add_child(cr)
	_label(cr, "기후", "Small").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for c: Dictionary in Shelf.climate_choices():
		if not bool(c["ready"]):
			continue
		var b := Button.new()
		b.text = String(c["name"])
		b.toggle_mode = true
		b.button_pressed = climate == String(c["name"])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 0)
		var nm := String(c["name"])
		b.pressed.connect(func() -> void:
			climate = nm
			_sig = ""
			_refresh())
		cr.add_child(b)
		UiTheme.hit_pad(b, 34.0)                     # (Q23 ㊾) 보이는 높이 34 그대로, 누르는 높이 44
	_label(cr, "다른 기후는 곧", "Small").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var can := Shelf.can_buy_jar(s.giant, n)
	var row := HBoxContainer.new()
	col.add_child(row)
	var why := _label(row, "" if bool(can["ok"]) else String(can["why"]), "Small")
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := _button(row, "새 병 사기 %s" % Shop._num(price), ask_buy, true, 150)
	b.name = "BuyJar"
	b.disabled = not bool(can["ok"])


## [새 병 사기] → "6,000 지폐로 새 병을 살까요?" (지폐를 크게 쓰는 일은 한 번 묻는다)
func ask_buy() -> void:
	var s := _sm()
	if s == null:
		return
	_pending_buy = true
	confirm.ask("%s 지폐로 새 병을 살까요?\n%s 세상을 새로 만들어요." % [Shop._num(Shelf.jar_price(maxi(1, s.order.size()))), climate], "사기", "그만두기")


func _on_confirm(yes: bool) -> void:
	if not _pending_buy:
		return
	_pending_buy = false
	if yes:
		buy_jar()


## 새 병을 산다 (GameSave.buy_jar — 지폐를 내고 거인 묶음을 곧바로 저장) → 장면이 빠른 창조로
func buy_jar() -> bool:
	var s := _sm()
	if s == null or not s.buy_jar(climate):
		GameAudio.fx("glass_tap_light")
		return false
	GameAudio.fx("chime")
	_sig = ""
	_refresh()
	make_jar_requested.emit()
	return true


# ───────────────────────── 등불 ─────────────────────────
func _fill_lamp() -> void:
	_clear(lamp_box)
	var nx := Market.next_lamp()
	if nx.is_empty():
		var l := _label(lamp_box, "등불 %d시간 — 가장 큰 등불이에요. 자리를 비워도 하루 내내 병이 흘러요." % Market.lamp_hours(), "Small")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var cost := float(nx["cost"])
	var row := _card(lamp_box)
	var col := _col(row)
	_label(col, "등불 %d시간 → %d시간" % [Market.lamp_hours(), int(nx["hours"])]).add_theme_font_override("font", UiTheme.font(true))
	var s := _label(col, "%s · 자리를 비운 동안 모든 병이 흐르고 제물이 쌓이는 시간" % nx["name"], "Small")
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := _button(row, Shop._num(cost), _on_lamp, true)
	b.disabled = not Market.can_pay(cost)


func has_lamp() -> bool:
	return lamp_box.get_child_count() > 0


## 등불 올리기 — 거인 쪽 (GameSave.buy_lamp_upgrade: 지폐를 내고 거인 묶음을 곧바로 저장). 저장 관리자가 없으면 장터만
func _on_lamp() -> void:
	var s := _sm()
	var ok := s.buy_lamp_upgrade() if s != null else Market.buy_lamp_upgrade()
	if ok:
		GameAudio.fx("chime")
	_sig = ""
	_refresh()


# ───────────────────────── 키트 업그레이드 ─────────────────────────
const KIT_TEXT := {"밀밭": "씨앗 한 자루 → 밀밭 하나", "목조 주택": "오두막 2채 → 목조 주택 2채",
	"가족 하나 더": "다섯 식구 + 오두막 한 채 (혈통 없음)", "암반 컵 하나 더": "철·석탄·금·암염 중 하나를 땅속에 더"}


func _fill_kits(s: GameSave) -> void:
	_clear(kit_box)
	var g: Dictionary = s.giant if s != null else {}
	for name: String in Shelf.UPGRADE_ORDER:
		var st := Shelf.upgrade_state(g, name)
		var row := _card(kit_box)
		row.name = "Kit_" + name
		var col := _col(row)
		var title := name
		if int(st["max"]) > 1 and int(st["owned"]) > 0:
			title += " (%d/%d)" % [int(st["owned"]), int(st["max"])]
		_label(col, title).add_theme_font_override("font", UiTheme.font(true))
		var sub := _label(col, String(KIT_TEXT.get(name, "")), "Small")
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not bool(st["unlocked"]):
			var lk := _label(col, Shelf.unlock_hint(name), "Small")
			lk.add_theme_color_override("font_color", UiTheme.INK_SOFT)
		if int(st["owned"]) > 0:
			var tg := CheckButton.new()
			tg.text = "켬" if bool(st["on"]) else "끔"
			tg.button_pressed = bool(st["on"])
			tg.focus_mode = Control.FOCUS_NONE
			tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tg.toggled.connect(func(on: bool) -> void: set_kit_on(name, on))
			row.add_child(tg)
		var price := int(st["price"])
		if price >= 0:
			var b := _button(row, Shop._num(price), func() -> void: buy_kit(name), true)
			b.disabled = s == null or not bool(st["unlocked"]) or not Market.can_pay(float(price))
		elif int(st["owned"]) == 0:
			_label(row, "—", "Small")


func buy_kit(name: String) -> bool:
	var s := _sm()
	if s == null or not s.buy_upgrade(name):
		GameAudio.fx("glass_tap_light")
		return false
	GameAudio.fx("chime")
	_sig = ""
	_refresh()
	return true


func set_kit_on(name: String, on: bool) -> void:
	var s := _sm()
	if s == null:
		return
	s.set_upgrade_on(name, on)
	GameAudio.ui_click()
	_sig = ""
	_refresh()
