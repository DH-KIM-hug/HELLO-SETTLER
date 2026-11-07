## 거인의 수첩 쪽지 (OPENING 3.1b — sim/notebook.gd). 화면 왼쪽 위 (배속 칩 아래) 작은 종이 한 장 — 막지 않고, 모서리에 작은 별이 반짝임.
## 쪽지를 누르면 pressed → 장면이 그 일의 자리로 카메라를 옮기고 단추·자리를 가리킨다 (가리키기는 pointer — 같은 층의 화살표·고리).
## 새 쪽지가 뜨면 살짝 떨어지듯 나타나고, 끝내면 "+30 지폐"가 잠깐 떠오른다.
## 쓰는 법: root.add_child(NotebookNote.new()) → setup(village) → 매 화면 장면이 point(…) 로 가리킬 곳을 준다.
class_name NotebookNote
extends PanelContainer

signal pressed

const W := 194.0

var village: Village
var title_l: Label
var text_l: Label
var step_l: Label
var pointer: Control                 # 화살표·고리 (부모의 맨 위 — 쪽지와 같은 층)
var _shown := ""                     # 지금 보이는 쪽지 id
var _t := 0.0
var _in := 0.0
var _reward := ""                    # "+50 지폐" 떠오름
var _reward_t := 0.0
var _last_i := -1
var _arrow := Rect2()                # 가리킬 단추 (화면 좌표) — 크기 0이면 없음
var _ring := Vector2(-1, -1)         # 가리킬 땅 자리 (화면 좌표)
var _ring_label := ""
var _done_text := ""                # 방금 끝낸 쪽지 (보상이 떠오르는 동안 '했다!'와 함께)
var site_marks: Array = []           # 짓는 터 위 작은 진행 고리 [[화면 점, 0~1]] (첫 병 첫날 — 장면이 줌)
var hidden_by_sheet := false        # 큰 시트(제단·상점·연대기·아기 이름…)가 열린 동안은 숨김 (장면이 정함)


func _init() -> void:
	name = "NotebookNote"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fdf6dc")
	sb.border_color = UiTheme.PARCHMENT_EDGE
	sb.set_border_width_all(1)
	sb.border_width_left = 4                       # 수첩 쪽지의 왼쪽 묶음 자리
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.16)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(1, 2)
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	title_l = Label.new()
	title_l.text = "거인의 수첩"
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.add_theme_font_override("font", UiTheme.font(true))
	title_l.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	title_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	head.add_child(title_l)
	step_l = Label.new()
	step_l.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL - 1)
	step_l.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	head.add_child(step_l)
	text_l = Label.new()
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.custom_minimum_size.x = W - 20.0
	text_l.add_theme_font_override("font", UiTheme.hand_font())
	text_l.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND_SMALL)
	text_l.add_theme_constant_override("line_spacing", -2)
	text_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	col.add_child(text_l)
	gui_input.connect(_on_input)
	draw.connect(_draw_sparkle)


func setup(v: Village) -> void:
	village = v


func _ready() -> void:
	pointer = Control.new()
	pointer.name = "NotebookPointer"
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pointer.draw.connect(_draw_pointer)
	get_parent().add_child.call_deferred(pointer)


func _on_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		accept_event()
		GameAudio.fx("paper", "Room", -8.0)
		pressed.emit()


## 장면이 매 화면 주는 가리킬 곳 (단추 화면 사각형 · 땅의 화면 점 + 짧은 말)
func point(button_rect: Rect2, ring: Vector2 = Vector2(-1, -1), ring_label := "") -> void:
	_arrow = button_rect
	_ring = ring
	_ring_label = ring_label


func _process(dt: float) -> void:
	_t += dt
	var tk := Notebook.shown(village) if village != null else {}
	var id := String(tk.get("id", ""))
	var i := Notebook.index(village) if village != null and Notebook.on_now(village) else -1
	if _last_i >= 0 and i != _last_i and village != null:
		var done_i := _last_i
		if done_i < Notebook.TASKS.size() and Notebook.is_done(village, String(Notebook.TASKS[done_i]["id"])) and not bool(village.notebook.get("replay", false)):
			_reward = "+%d 지폐" % int(Notebook.TASKS[done_i].get("reward", 30))
			_reward_t = 2.2
			_done_text = String(Notebook.TASKS[done_i]["text"])
			GameAudio.fx("chime", "Room", -10.0)
	_last_i = i
	if id != _shown:
		_shown = id
		_in = 0.0
		text_l.text = String(tk.get("text", ""))
		step_l.text = "%d / %d" % [i + 1, Notebook.TASKS.size()] if id != "" else ""
		reset_size()
	visible = (id != "" or _reward_t > 0.0) and not hidden_by_sheet
	if id == "" and _reward_t > 0.0 and text_l.text != _done_text:
		text_l.text = _done_text
		step_l.text = "했다!"
		reset_size()
	_in = minf(1.0, _in + dt / 0.45)
	var k := 1.0 - pow(1.0 - _in, 3.0)
	modulate.a = k
	pivot_offset = Vector2(size.x * 0.5, 0)
	rotation = deg_to_rad(-1.5 + 1.5 * (1.0 - k) * 3.0)
	_reward_t = maxf(0.0, _reward_t - dt)
	queue_redraw()
	if pointer != null:
		pointer.queue_redraw()


## 모서리의 작은 별 (반짝임만 — 빨간 점 금지) + 떠오르는 보상
func _draw_sparkle() -> void:
	var p := Vector2(size.x - 6.0, 4.0)
	var k := 0.5 + 0.5 * sin(_t * 3.2)
	var r := 3.0 + 3.5 * k
	var c := Color(UiTheme.GLOW.lightened(0.2), 0.45 + 0.55 * k)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.28, -r * 0.28), p + Vector2(r, 0), p + Vector2(r * 0.28, r * 0.28),
		p + Vector2(0, r), p + Vector2(-r * 0.28, r * 0.28), p + Vector2(-r, 0), p + Vector2(-r * 0.28, -r * 0.28)]), c)
	if _reward_t > 0.0:
		var u := 1.0 - _reward_t / 2.2
		var f := UiTheme.font(true)
		var col := Color(UiTheme.PRIMARY, clampf(_reward_t / 0.6, 0.0, 1.0))
		draw_string(f, Vector2(size.x - 70.0, size.y + 14.0 - 18.0 * u), _reward, HORIZONTAL_ALIGNMENT_RIGHT, 66.0, UiTheme.SIZE, col)


## 가리키기: 단추 위에서 통통 뛰는 화살표 + 금빛 테두리 · 땅 자리엔 숨 쉬는 고리와 짧은 말
func _draw_pointer() -> void:
	for m: Array in site_marks:                     # 짓는 터 위 진행 고리 (쪽지와 상관없이)
		var c: Vector2 = m[0]
		var f: float = m[1]
		pointer.draw_circle(c, 11.0, Color(1, 0.98, 0.9, 0.85))
		pointer.draw_arc(c, 9.0, 0.0, TAU, 28, Color(UiTheme.INK_BROWN, 0.25), 3.0)
		pointer.draw_arc(c, 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(f, 0.0, 1.0), 28, UiTheme.PRIMARY, 3.0)
	if not visible or _shown == "":
		return
	var gold := UiTheme.GLOW
	var bob := 4.0 * sin(_t * 5.0)
	if _arrow.size.x > 1.0:
		var g := _arrow.grow(2.0)
		pointer.draw_rect(g, Color(gold, 0.55 + 0.35 * sin(_t * 4.0)), false, 2.5)
		var tip := Vector2(g.get_center().x, g.position.y - 3.0 + bob)
		var up := tip.y > 60.0                       # 화살표는 단추 위에서 아래로 (단추가 화면 맨 위면 아래에서 위로)
		var d := 1.0 if up else -1.0
		if not up:
			tip = Vector2(g.get_center().x, g.end.y + 3.0 - bob)
		var pts := PackedVector2Array([tip, tip + Vector2(-9, -12 * d), tip + Vector2(-3.5, -12 * d), tip + Vector2(-3.5, -24 * d),
			tip + Vector2(3.5, -24 * d), tip + Vector2(3.5, -12 * d), tip + Vector2(9, -12 * d)])
		pointer.draw_colored_polygon(pts, Color(gold, 0.95))
		pointer.draw_polyline(pts + PackedVector2Array([tip]), UiTheme.INK_BROWN, 1.2)
	if _ring.x >= 0.0:
		var rr := 22.0 + 5.0 * sin(_t * 3.5)
		pointer.draw_arc(_ring, rr, 0.0, TAU, 40, Color(gold, 0.9), 3.0)
		pointer.draw_arc(_ring, rr + 7.0, 0.0, TAU, 40, Color(gold, 0.35), 2.0)
		if _ring_label != "":
			var f := UiTheme.hand_font()
			var w := f.get_string_size(_ring_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_HAND_SMALL).x
			var at := _ring + Vector2(-w * 0.5, -rr - 10.0)
			pointer.draw_rect(Rect2(at + Vector2(-5, -15), Vector2(w + 10, 20)), Color(1, 0.98, 0.9, 0.9))
			pointer.draw_string(f, at, _ring_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_HAND_SMALL, UiTheme.INK_BROWN)
