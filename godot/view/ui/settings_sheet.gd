## 설정 · 문의 — docs/UI.md 화면 10 + "10 문의하기 (v1)". 위 띠 오른쪽 끝 톱니(⚙)로 연다.
## 한 장짜리 시트 두 쪽: [설정] 소리(음악·효과음) · 진동 · 언어(한국어만, 보여 주기만) · 알림 → user://settings.cfg (GameSettings)
##                       + [문의하기] + 작은 크레딧(audio/LICENSES.csv — 비어 있으면 안 보임)
##                      [문의하기] 종류 하나 고르기(버그·멈춤 / 결제 / 제안 / 그 밖) · 안내 한 줄 · 받는 주소 + [복사] · [메일 쓰기](이끼 초록)
## 세로 화면 = 아래 시트, 가로 창 = 오른쪽 패널. 색·글꼴은 view/ui/ui_theme.gd. 빨간 점·배지 없음.
## 쓰는 법: add_child(SettingsSheet.new()) → setup(village) → open(). 신호: closed.
class_name SettingsSheet
extends Control

signal closed

const SHEET_FRAC := 0.66
const LICENSES := "res://audio/LICENSES.csv"
const TOAST_TIME := 2.6

var village: Village
var jars := 1                            # 병 수 (선반이 생기면 거기서)
var page := "settings"                   # settings · inquiry
var kind := ""                           # 고른 문의 종류
var portrait_mode := true
var settings: GameSettings

var panel: PanelContainer
var title_l: Label
var settings_page: VBoxContainer
var inquiry_page: VBoxContainer
var scroll: ScrollContainer
var toggles := {}                        # 키 → Button
var kind_btns := {}                      # 종류 → Button
var send_btn: Button
var back_btn: Button
var close_btn: Button
var credit_l: Label
var info_l: Label
var toast: Label
var _toast_t := 0.0


func _init() -> void:
	name = "SettingsSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	settings = GameSettings.get_current()
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
	title_l = _label(outer, "설정", "Title")
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	settings_page = _page(pages)
	inquiry_page = _page(pages)
	_build_settings(settings_page)
	_build_inquiry(inquiry_page)
	var foot := HBoxContainer.new()
	outer.add_child(foot)
	back_btn = _button(foot, "뒤로")
	back_btn.pressed.connect(func() -> void: show_page("settings"))
	send_btn = _button(foot, "메일 쓰기")
	send_btn.theme_type_variation = "Primary"
	send_btn.size_flags_stretch_ratio = 2.0
	send_btn.pressed.connect(send_mail)
	close_btn = _button(foot, "닫기")
	close_btn.pressed.connect(close)
	toast = Label.new()
	toast.theme_type_variation = "Toast"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	add_child(toast)


func _page(parent: Node) -> VBoxContainer:
	var p := VBoxContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_constant_override("separation", UiTheme.GAP)
	parent.add_child(p)
	return p


func _build_settings(body: VBoxContainer) -> void:
	_section(body, "소리")
	_toggle_row(body, "music", "음악")
	_toggle_row(body, "sfx", "효과음")
	_section(body, "기기")
	_toggle_row(body, "vibration", "진동")
	_toggle_row(body, "notify", "알림")
	var lang := _row(body, "언어")
	var ll := _label(lang, GameSettings.LANGS.get(settings.language, "한국어"))
	ll.custom_minimum_size = Vector2(84, UiTheme.TOUCH)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label(body, "다른 언어는 준비하고 있어요.", "Small")
	_section(body, "도움")
	var ask := _button(body, "문의하기")
	ask.pressed.connect(func() -> void: show_page("inquiry"))
	credit_l = _label(body, credits_text(), "Small")
	credit_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit_l.visible = credit_l.text != ""


func _build_inquiry(body: VBoxContainer) -> void:
	_section(body, "무엇에 대한 문의인가요?")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UiTheme.GAP)
	grid.add_theme_constant_override("v_separation", UiTheme.GAP)
	body.add_child(grid)
	for k: String in Inquiry.KINDS:
		var b := _button(grid, k)
		b.pressed.connect(pick_kind.bind(k))
		kind_btns[k] = b
	var guide := _label(body, "메일 앱이 열립니다. 화면 사진을 붙여 주시면 빨리 살펴볼 수 있어요.")
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_section(body, "받는 주소")
	var addr := HBoxContainer.new()
	body.add_child(addr)
	var al := _label(addr, Inquiry.ADDRESS)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	al.mouse_filter = Control.MOUSE_FILTER_PASS
	var copy := _button(addr, "복사", false)
	copy.custom_minimum_size.x = 72
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Inquiry.ADDRESS)
		show_toast("주소를 복사했어요."))
	info_l = _label(body, "", "Small")
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 버튼 — 스크롤 안에서도 끌면 스크롤되게 PASS (부모 패널이 STOP이라 화면 뒤로 새지 않음)
func _button(parent: Node, text: String, expand := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b


func _section(parent: Node, title: String) -> void:
	if parent.get_child_count() > 0:
		parent.add_child(HSeparator.new())
	_label(parent, title, "Section")


func _row(parent: Node, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(row, text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row


## 켜고 끄는 줄: 이름 ··· [켜짐]/[꺼짐]
func _toggle_row(parent: Node, key: String, text: String) -> void:
	var row := _row(parent, text)
	var b := _button(row, "", false)
	b.custom_minimum_size.x = 84
	b.pressed.connect(func() -> void:
		settings.set(key, not bool(settings.get(key)))
		settings.save()
		settings.apply()
		_sync_toggles())
	toggles[key] = b


func _sync_toggles() -> void:
	for key: String in toggles:
		var on := bool(settings.get(key))
		var b: Button = toggles[key]
		b.text = "켜짐" if on else "꺼짐"
		b.theme_type_variation = "FollowOn" if on else ""


## 세로 = 아래 시트, 가로 = 오른쪽 패널. 아래 제스처 막대만큼 내용 여백
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


# ───────────────────────── 열기·닫기 ─────────────────────────
func open() -> void:
	visible = true
	show_page("settings")
	_layout()


func close() -> void:
	visible = false
	toast.visible = false
	closed.emit()


func show_page(p: String) -> void:
	page = p
	var inq := p == "inquiry"
	settings_page.visible = not inq
	inquiry_page.visible = inq
	title_l.text = "문의하기" if inq else "설정"
	back_btn.visible = inq
	send_btn.visible = inq
	close_btn.visible = not inq
	scroll.scroll_vertical = 0
	if inq:
		pick_kind(kind if kind != "" else Inquiry.KINDS[0])
	_sync_toggles()


func pick_kind(k: String) -> void:
	kind = k
	for kk: String in kind_btns:
		(kind_btns[kk] as Button).theme_type_variation = "FollowOn" if kk == k else ""
	var inf := current_info()
	info_l.text = "메일 아래에 함께 적히는 것: 버전 %s · 기기 %s · 언어 %s · 문의 번호 %s · 병 %d개 · %d일째\n이름·연락처 같은 개인 정보는 넣지 않아요. 보내기 전에 지울 수 있어요." % [
		inf["version"], inf["device"], inf["locale"], inf["ticket"], int(inf["jars"]), int(inf["day"])]


func current_info() -> Dictionary:
	return Inquiry.info(jars, village.day_no() if village != null else 1)


func send_mail() -> void:
	if kind == "":
		kind = Inquiry.KINDS[0]
	if not Inquiry.send(kind, current_info()):
		show_toast(Inquiry.FAIL_TOAST)


func show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	_toast_t = TOAST_TIME
	_place_toast()


func _place_toast() -> void:
	var vs := get_viewport_rect().size
	var w := minf(vs.x - 32.0, 300.0)
	toast.custom_minimum_size.x = w
	toast.size = Vector2(w, 0)
	toast.reset_size()
	var top := panel.get_global_rect().position.y if portrait_mode else vs.y * 0.5
	var x := (vs.x - w) * 0.5 if portrait_mode else panel.get_global_rect().position.x + (panel.size.x - w) * 0.5
	toast.position = Vector2(roundf(x), roundf(top - toast.size.y - 10.0))


func _process(dt: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= dt
		_place_toast()
		if _toast_t <= 0.0:
			toast.visible = false


# ───────────────────────── 크레딧 ─────────────────────────
## audio/LICENSES.csv (file,title,author,pixabay_url,download_date,content_id) → '소리: 제목 — 지은이 (Pixabay)'. 줄이 없으면 ""
static func credits_text(p := LICENSES) -> String:
	if not FileAccess.file_exists(p):
		return ""
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	var head := f.get_csv_line()
	var ti := head.find("title")
	var ai := head.find("author")
	var out := PackedStringArray()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() <= maxi(ti, ai) or ti < 0 or ai < 0:
			continue
		var t := row[ti].strip_edges()
		var a := row[ai].strip_edges()
		if t == "" and a == "":
			continue
		out.append("%s — %s" % [t, a] if a != "" else t)
	if out.is_empty():
		return ""
	return "소리: " + " · ".join(out) + " (Pixabay)"
