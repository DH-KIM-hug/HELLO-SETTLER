## 선반 시트 — docs/UI.md 화면 05 (자리만 — "곧 열려요") + 거인의 등불 (SHOP 1 · SAVE.md 3: 비운 동안 흐르는 시간 12 → 16 → 20 → 24시간).
## 다음 병·거인의 다리·병 목록은 선반 화면이 생기면 (ROADMAP). 등불 올리기는 제단 시트에서 옮겨 왔다.
## 쓰는 법: add_child(ShelfSheet.new()) → open(). 신호: closed.
class_name ShelfSheet
extends Control

signal closed

const SHEET_FRAC := 0.55

var panel: PanelContainer
var lamp_box: VBoxContainer
var notes_l: Label
var _sig := ""
var _t := 0.0


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
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiTheme.GAP)
	scroll.add_child(body)
	var soon := PanelContainer.new()
	soon.theme_type_variation = "Card"
	body.add_child(soon)
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 4)
	soon.add_child(sc)
	_label(sc, "곧 열려요", "Section")
	var sl := _label(sc, "거인의 방 선반에 병들이 나란히 놓일 자리예요. 새 병 사기 · 병과 병 사이 거인의 다리 · 병 목록이 여기에 생겨요.", "Small")
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(HSeparator.new())
	var lh := HBoxContainer.new()
	body.add_child(lh)
	lh.add_child(GameIcons.rect("등불", 26))
	_label(lh, "거인의 등불", "Section").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lamp_box = VBoxContainer.new()
	lamp_box.add_theme_constant_override("separation", 4)
	body.add_child(lamp_box)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)


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


func open() -> void:
	if not visible:
		GameAudio.fx("sheet_open", "Room", -2.0)
	visible = true
	_sig = ""
	_refresh()


func close() -> void:
	if visible:
		GameAudio.fx("sheet_close", "Room", -2.0)
	visible = false
	closed.emit()


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if _t >= 0.5:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	notes_l.text = Shop._num(Market.notes)
	var sig := "%d|%d" % [int(Market.notes), Market.lamp_level]
	if sig == _sig:
		return
	_sig = sig
	for c in lamp_box.get_children():
		lamp_box.remove_child(c)
		c.queue_free()
	var nx := Market.next_lamp()
	if nx.is_empty():
		var l := _label(lamp_box, "등불 %d시간 — 가장 큰 등불이에요. 자리를 비워도 하루 내내 병이 흘러요." % Market.lamp_hours(), "Small")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var cost := float(nx["cost"])
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	lamp_box.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_label(col, "등불 %d시간 → %d시간" % [Market.lamp_hours(), int(nx["hours"])]).add_theme_font_override("font", UiTheme.font(true))
	var s := _label(col, "%s · 자리를 비운 동안 병이 흐르고 제물이 쌓이는 시간" % nx["name"], "Small")
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, UiTheme.TOUCH)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.text = Shop._num(cost)
	GameIcons.button_icon(b, "지폐", 20)
	b.disabled = not Market.can_pay(cost)
	b.pressed.connect(_on_lamp)
	row.add_child(b)


func has_lamp() -> bool:
	return lamp_box.get_child_count() > 0


## 등불 올리기 — 거인 쪽 (GameSave.buy_lamp_upgrade: 지폐를 내고 거인 묶음을 곧바로 저장). 저장 관리자가 없으면 장터만
func _on_lamp() -> void:
	var sm := GameSave.get_instance()
	var ok := sm.buy_lamp_upgrade() if sm != null else Market.buy_lamp_upgrade()
	if ok:
		GameAudio.fx("chime")
	_sig = ""
	_refresh()
