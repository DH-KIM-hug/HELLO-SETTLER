## 창고 띠 — 위 띠 아래 왼쪽, 시각·배속 칩 밑의 작은 알약 (사용자 요청 "게임 화면에서 자원 현황").
##   펼침: [식량 · 통나무 · 판자 · 돌 (+ 시대에 따라 소금·양털·철…)] 아이콘 + 짧은 숫자 + 지난 하루 ▲▼ · 끝의 ◂ = 접기
##   접힘: [창고 ▸] 하나 (식량이 모자라면 그 글자만 주의 색). 접힘/펼침은 user://hud.cfg에 기억
##   누르면 창고 시트 (pressed) · 보여 주는 무리 = 장면의 focus_village() · 1초에 두 번만 새로 씀 (화면마다 만들지 않음)
## 쓰는 법: var s := StoreStrip.new() → s.setup(scene) (scene: focus_village() · village_views()) → root.add_child(s) → s.max_width = …
class_name StoreStrip
extends PanelContainer

signal pressed

const MAX_SLOTS := 8
const ICON := 16
const EVERY := 0.5                       # 초 — 1초에 두 번
const WARM := Color("b06a1f")            # 식량 주의 (부드러운 호박색 — 빨강 금지)
const WARM_BG := Color(0.98, 0.86, 0.6, 0.95)
const UP := Color("4e9a5b")
const DOWN := Color("98663f")

static var cfg_path := "user://hud.cfg"   # 시험은 다른 파일로

var scene: Object
var book := StoreBook.new()
var collapsed := false
var max_width := 1000.0
var slots: Array = []                    # [{box, icon, label, mark, key}]
var row: HBoxContainer
var title_l: Label
var caret: Control
var _t := 0.0
var _down := false
var _warm_box: StyleBoxFlat
var _empty_box := StyleBoxEmpty.new()
var shown_village: Village = null


func _init() -> void:
	name = "StoreStrip"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.BAR_PAPER
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 6
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	add_theme_stylebox_override("panel", sb)
	_warm_box = StyleBoxFlat.new()
	_warm_box.bg_color = WARM_BG
	_warm_box.set_corner_radius_all(8)
	_warm_box.content_margin_left = 3
	_warm_box.content_margin_right = 3
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	title_l = _label("창고")
	row.add_child(title_l)
	for i in MAX_SLOTS:
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", _empty_box)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(h)
		var ic := GameIcons.rect("", ICON)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := _label("")
		h.add_child(l)
		var m := TrendMark.new()
		h.add_child(m)
		box.visible = false
		row.add_child(box)
		slots.append({"box": box, "icon": ic, "label": l, "mark": m, "key": ""})
	caret = Caret.new()
	row.add_child(caret)
	collapsed = load_collapsed()


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.font(true))
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiTheme.INK)
	return l


func setup(s: Object) -> void:
	scene = s


func _ready() -> void:
	refresh()


func _process(dt: float) -> void:
	_t += dt
	if _t < EVERY:
		return
	_t = 0.0
	refresh()


## 모든 무리를 장부에 적고 (1시간에 한 번만 실제로 적힘), 띠를 보여 주는 무리로 새로 씀
func refresh() -> void:
	if scene == null:
		return
	for vv: Array in scene.call("village_views"):
		book.sample(vv[0])
	var v: Village = scene.call("focus_village")
	shown_village = v
	if v == null:
		return
	var warn := StoreBook.food_warn(v)
	(caret as Caret).open = not collapsed
	caret.queue_redraw()
	title_l.visible = collapsed
	title_l.add_theme_color_override("font_color", WARM if warn and collapsed else UiTheme.INK)
	var keys: Array = [] if collapsed else StoreBook.strip_keys(v)
	for i in MAX_SLOTS:
		var s: Dictionary = slots[i]
		var box: PanelContainer = s["box"]
		if i >= keys.size():
			box.visible = false
			continue
		var k: String = keys[i]
		if s["key"] != k:
			s["key"] = k
			(s["icon"] as TextureRect).texture = GameIcons.tex("빵" if k == StoreBook.FOOD else k)
		var val := StoreBook.amount(v, k)
		var lbl: Label = s["label"]
		lbl.text = StoreBook.short(val)
		var w := warn and k == StoreBook.FOOD
		lbl.add_theme_color_override("font_color", WARM if w else UiTheme.INK)
		box.add_theme_stylebox_override("panel", _warm_box if w else _empty_box)
		var m: TrendMark = s["mark"]
		m.dir = StoreBook.trend(book.day_change(v, k), val)
		m.visible = m.dir != 0
		m.queue_redraw()
		box.visible = true
	# 자리가 모자라면 뒤의 것(시대 물건)부터 뺀다 — 기본 넷은 남김
	var n := keys.size()
	while n > StoreBook.BASE.size() and get_combined_minimum_size().x > max_width:
		n -= 1
		(slots[n]["box"] as PanelContainer).visible = false
	reset_size()


## 지금 띠에 보이는 칸: {이름: 보이는 글자} (시험용)
func shown() -> Dictionary:
	var d := {}
	for s: Dictionary in slots:
		if (s["box"] as Control).visible:
			d[s["key"]] = (s["label"] as Label).text
	return d


func set_collapsed(on: bool) -> void:
	collapsed = on
	save_collapsed(on)
	refresh()


static func load_collapsed() -> bool:
	var cf := ConfigFile.new()
	if cf.load(cfg_path) != OK:
		return false
	return bool(cf.get_value("store_strip", "collapsed", false))


static func save_collapsed(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(cfg_path)
	cf.set_value("store_strip", "collapsed", on)
	cf.save(cfg_path)


## 누르기: 접혀 있으면 펼침 · 끝의 ◂ 쪽이면 접음 · 그 밖 = 창고 시트
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_down = true
		elif _down:
			_down = false
			tap(mb.position)
		accept_event()


func tap(local: Vector2) -> void:
	GameAudio.ui_click()
	if collapsed:
		set_collapsed(false)
	elif local.x >= caret.position.x + row.position.x - 6.0:
		set_collapsed(true)
	else:
		pressed.emit()


## 지난 하루 ▲ (늘었음) · ▼ (줄었음) — 글꼴에 기대지 않고 직접 그림
class TrendMark extends Control:
	var dir := 0

	func _init() -> void:
		custom_minimum_size = Vector2(7, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var c := size * 0.5
		if dir > 0:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(3.5, 2.5), c + Vector2(-3.5, 2.5)]), UP)
		elif dir < 0:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 4), c + Vector2(3.5, -2.5), c + Vector2(-3.5, -2.5)]), DOWN)


## 접기 ◂ / 펼치기 ▸
class Caret extends Control:
	var open := true

	func _init() -> void:
		custom_minimum_size = Vector2(16, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := 3.5
		var pts := PackedVector2Array([c + Vector2(s * 0.5, -s), c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.5, s)]) if open \
			else PackedVector2Array([c + Vector2(-s * 0.5, -s), c + Vector2(s * 0.5, 0), c + Vector2(-s * 0.5, s)])
		draw_polyline(pts, UiTheme.INK_SOFT, 1.6, true)
