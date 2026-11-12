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
var prog_l: Label                    # 지켜보기 쪽지의 진행 한 줄 ("제단 돌 6/24" — Notebook.progress) + 아래 작은 막대
var prog_f := -1.0                   # 막대 (0~1, −1 = 없음)
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
var ground_layer: CanvasItem = null  # 땅 고리를 그릴 장면의 낮은 화면 층 (draw_ground_ring을 부름)
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
	title_l.text = "별지기의 수첩"
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.add_theme_font_override("font", UiTheme.font(true))
	title_l.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
	title_l.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	head.add_child(title_l)
	step_l = Label.new()
	step_l.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)      # (Q23 ㊿) 가장 작은 글 11
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
	prog_l = Label.new()
	prog_l.name = "Progress"
	prog_l.visible = false
	prog_l.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)      # (Q23 ㊿) 가장 작은 글 11
	prog_l.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	prog_l.custom_minimum_size.y = 22.0              # 아래 6px은 막대 자리
	prog_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(prog_l)
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
	_update_progress(id)
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
	if ground_layer != null:
		ground_layer.queue_redraw()


## 지켜보기 쪽지의 진행 한 줄 (바뀔 때만 크기를 다시)
func _update_progress(id: String) -> void:
	var pg: Dictionary = Notebook.progress(village) if village != null and id != "" else {}
	var tx := String(pg.get("text", ""))
	prog_f = float(pg.get("f", -1.0)) if not pg.is_empty() else -1.0
	if tx != prog_l.text or prog_l.visible != (tx != ""):
		prog_l.text = tx
		prog_l.visible = tx != ""
		reset_size()


## 모서리의 작은 별 (반짝임만 — 빨간 점 금지) + 떠오르는 보상 + 진행 막대
func _draw_sparkle() -> void:
	if prog_l.visible and prog_f >= 0.0:
		var r := Rect2(prog_l.position + Vector2(0, prog_l.size.y - 6.0), Vector2(W - 22.0, 4.0))
		r.position += (prog_l.get_parent() as Control).position
		draw_rect(r, Color(UiTheme.INK_BROWN, 0.18))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(prog_f, 0.0, 1.0), r.size.y)), UiTheme.PRIMARY)
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


## 짓는 터 위 진행 고리 [[화면 점, 0~1, (짧은 말)]] (첫 병 첫날 · 제단 "6/24"). 장면의 화면 층(띠·시트 아래)에 그린다 — 이 쪽지 층(시트 위)이 아니라.
static func draw_site_marks(ci: CanvasItem, marks: Array) -> void:
	for m: Array in marks:
		var c: Vector2 = m[0]
		var f: float = m[1]
		if f < 0.0:                       # 작은 말풍선 "!" (하늘을 올려다보는 아이 — 몇 초마다 톡)
			var k := fposmod(Time.get_ticks_msec() / 1000.0 + c.x * 0.013, 2.4)
			var pop := clampf(k / 0.18, 0.0, 1.0) * (1.0 if k < 1.8 else clampf((2.4 - k) / 0.3, 0.0, 1.0))
			if pop > 0.01:
				var r := 7.5 * pop
				ci.draw_circle(c, r, Color(1, 0.98, 0.9, 0.95))
				ci.draw_arc(c, r, 0.0, TAU, 18, Color(UiTheme.INK_BROWN, 0.6), 1.2)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.5, r - 1.0), c + Vector2(2.5, r - 1.0), c + Vector2(-1.0, r + 4.0)]), Color(1, 0.98, 0.9, 0.95))
				ci.draw_rect(Rect2(c + Vector2(-1.1, -4.6) * pop, Vector2(2.2, 5.6) * pop), UiTheme.INK_BROWN)
				ci.draw_rect(Rect2(c + Vector2(-1.1, 2.2) * pop, Vector2(2.2, 2.0) * pop), UiTheme.INK_BROWN)
			continue
		ci.draw_circle(c, 11.0, Color(1, 0.98, 0.9, 0.85))
		ci.draw_arc(c, 9.0, 0.0, TAU, 28, Color(UiTheme.INK_BROWN, 0.25), 3.0)
		ci.draw_arc(c, 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(f, 0.0, 1.0), 28, UiTheme.PRIMARY, 3.0)
		if m.size() > 2 and String(m[2]) != "":
			var fnt := UiTheme.font(true)
			var fs := UiTheme.SIZE_SMALL          # (Q23 ㊿) 가장 작은 글 11 (예전 9)
			var w := fnt.get_string_size(String(m[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := c + Vector2(-w * 0.5, 13.0 + fs)          # 고리 바로 아래 가운데 (화면 가장자리에서 잘리지 않게)
			ci.draw_rect(Rect2(at + Vector2(-3, -fs - 1), Vector2(w + 6, fs + 6)), Color(1, 0.98, 0.9, 0.85))
			ci.draw_string(fnt, at, String(m[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.INK_BROWN)


## 가리키기: 단추 위에서 통통 뛰는 화살표 + 금빛 테두리 (땅 자리 고리는 draw_ground_ring — 낮은 층)
func _draw_pointer() -> void:
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


## 땅 자리의 숨 쉬는 고리 + 짧은 말 (제단·짓는 터·첫 밭…). 장면의 화면 층(띠·시트 아래, ground_layer)에 그린다 —
## 쪽지 층(시트 위)에 그리면 주민 상세 같은 시트 위로 떠 보인다.
func draw_ground_ring(ci: CanvasItem) -> void:
	if not visible or _shown == "" or _ring.x < 0.0:
		return
	var gold := UiTheme.GLOW
	var rr := 22.0 + 5.0 * sin(_t * 3.5)
	ci.draw_arc(_ring, rr, 0.0, TAU, 40, Color(gold, 0.9), 3.0)
	ci.draw_arc(_ring, rr + 7.0, 0.0, TAU, 40, Color(gold, 0.35), 2.0)
	if _ring_label != "":
		var f := UiTheme.hand_font()
		var w := f.get_string_size(_ring_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_HAND_SMALL).x
		var at := _ring + Vector2(-w * 0.5, -rr - 10.0)
		ci.draw_rect(Rect2(at + Vector2(-5, -15), Vector2(w + 10, 20)), Color(1, 0.98, 0.9, 0.9))
		ci.draw_string(f, at, _ring_label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SIZE_HAND_SMALL, UiTheme.INK_BROWN)
