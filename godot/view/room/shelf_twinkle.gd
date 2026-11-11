## (Q19 · Q20) 화면 가장자리의 작은 종이 꼬리표 — 아직 안 본 기념품이 선 쪽 (선반을 그쪽으로 밀어 본 적 없는 것).
## (Q20 ㉟) 예전에는 선반 높이의 호박빛 별이었는데 오른쪽은 설탕 그릇, 왼쪽은 등불 위에 겹쳐 그 소품의 반짝임으로 읽혔다.
## 지금은 화면 끝에 붙은 종이 꼬리표 (띠·단추와 같은 종이색·먹 테두리) 안에 작은 호박빛 별과 바깥을 가리키는 꺾쇠 —
## "저쪽에 새것이 있다". 높이는 방 소품(화분·물뿌리개·핀셋·설탕 그릇·등불)과 띠·단추를 비켜, 선반 높이에서 가장 가까운 빈 곳.
## 몇 초마다 한 번 별이 밝아지며 꼬리표가 바깥쪽으로 살짝 두 번 밀린다 (그 사이엔 가만히). 누르면 tapped(쪽).
## 넓은 세상 장면의 방(view/world_village.gd)과 타이틀(view/start/title.gd)이 같이 쓴다. 숫자·글 없음.
## 움직임 줄이기(JarCamera.reduce_motion)면 밀리지도 깜박이지도 않고 가만히.
class_name ShelfTwinkle
extends Control

signal tapped(side: int)

const TAB_H := 28.0                   # 꼬리표 높이 (px)
const TAB_TUCK := 8.0                 # 화면 밖으로 넘겨 그리는 만큼 (바깥 모서리가 안 보이게 — 밀릴 때도)
const NUDGE := 4.0                    # 바깥쪽으로 밀리는 폭 (px)
const PAD := 2.0                      # 소품·띠와 띄우는 틈 (px)
const STEP := 2.0                     # 빈 높이를 찾는 걸음 (px)
const REST := 0.42                    # 쉬는 동안 별의 밝기 (0~1)
const PAPER := Color("fbf6e6")        # UiTheme.PAPER
const LINE := Color("4a3424")         # UiTheme.INK_BROWN
const STAR := Color(0.96, 0.62, 0.16) # 호박빛 별
const CORE := Color(1.0, 0.97, 0.82)

var still := false                    # 움직임 줄이기 (장면이 넣어 줌)
var clear := true                     # 지금 높이에서 꼬리표가 비킬 것과 겹치지 않나 (시험·캡처용)
var _on := {1: false, -1: false}
var _y := 0.0
var _t := 0.0
var _hit := {}                        # 쪽 → 누르는 칸 (Control)
var _box: StyleBoxFlat
var _key := ""                        # 높이를 고른 때의 입력 (같으면 다시 찾지 않는다)


func _init() -> void:
	name = "ShelfTwinkle"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = StyleBoxFlat.new()
	_box.bg_color = PAPER
	_box.border_color = LINE
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(9)
	_box.shadow_color = Color(0.1, 0.07, 0.04, 0.22)
	_box.shadow_size = 3
	_box.shadow_offset = Vector2(0, 1)
	_box.anti_aliasing = true
	for side: int in [1, -1]:
		var h := Control.new()
		h.name = "Hit%s" % ("R" if side > 0 else "L")
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		h.visible = false
		h.gui_input.connect(_on_hit.bind(side, h))
		add_child(h)
		_hit[side] = h


## 소품을 살필 화면 끝 띠의 폭 (꼬리표 길이 + 틈) — GiantRoom.prop_edge_rects에 넘긴다
static func strip_w() -> float:
	return tab_w() + PAD


func _vs() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(360, 640)


## 꼬리표 길이 (화면 안으로 나온 만큼, px)
static func tab_w() -> float:
	return Balance.SOUVENIR_TWINKLE_PX


## 보일 쪽과 높이를 맞춘다 (매 화면). right·left = 그쪽에 안 본 기념품이 있나, y = 선반 높이 (화면) — 바라는 높이,
## lo·hi = 꼬리표 가운데가 머물 수 있는 세로 범위 (위 띠 아래 ~ 아래 띠·버튼 위),
## avoid = 비킬 화면 네모들 (Rect2 또는 {rect} — 방 소품 GiantRoom.prop_edge_rects · 띠 · 단추).
## 높이는 양쪽이 같다 (한쪽만 보여도 — 한쪽을 보고 나서 남은 쪽이 튀지 않게): 바라는 높이에서 가장 가까운, 양쪽 꼬리표가 아무것도
## 덮지 않는 곳. 그런 곳이 없으면 가장 덜 겹치는 곳 (clear = false)
func place(right: bool, left: bool, y: float, lo: float, hi: float, avoid: Array = []) -> void:
	var was_any := shown(1) or shown(-1)
	_on[1] = right
	_on[-1] = left
	hi = maxf(lo, hi)
	var vs := _vs()
	var rects: Array = []
	for a: Variant in avoid:
		var r: Rect2 = (a as Dictionary).get("rect", Rect2()) if a is Dictionary else a
		if r.size.x > 0.0 and r.size.y > 0.0:
			rects.append(r)
	var key := "%.1f|%.1f|%.1f|%s|%s" % [y, lo, hi, vs, rects]
	if key != _key:
		_key = key
		_y = _pick_y(clampf(y, lo, hi), lo, hi, rects, vs)
	if not was_any and (right or left):
		_t = Balance.SOUVENIR_TWINKLE_EVERY - 0.4          # 나타나면 곧 한 번 반짝
	var tw := Balance.SOUVENIR_TWINKLE_TOUCH
	for side: int in [1, -1]:
		var h: Control = _hit[side]
		h.visible = bool(_on[side])
		h.size = Vector2(tw, tw)
		h.position = Vector2(vs.x - tw if side > 0 else 0.0, _y - tw * 0.5)
	queue_redraw()


## 바라는 높이 want에서 위아래로 번갈아 찾아, 양쪽 꼬리표(틈 PAD 포함)가 rects 어느 것도 덮지 않는 가장 가까운 높이.
## 없으면 겹친 넓이가 가장 작은 높이
func _pick_y(want: float, lo: float, hi: float, rects: Array, vs: Vector2) -> float:
	clear = true
	if rects.is_empty():
		return want
	var best := want
	var best_a := INF
	var n := int(ceil((hi - lo) / STEP)) + 1
	for i in n:
		for sgn: float in [-1.0, 1.0]:                      # 위쪽 먼저 (소품은 선반에서 위로 솟아 있다)
			var y := want + sgn * float(i) * STEP
			if y < lo or y > hi or (i == 0 and sgn > 0.0):
				continue
			var a := 0.0
			for side: int in [1, -1]:
				var m := _tab_rect(side, y, vs).grow(PAD)
				for r: Rect2 in rects:
					var x := m.intersection(r)
					a += x.size.x * x.size.y
			if a <= 0.0:
				return y
			if a < best_a:
				best_a = a
				best = y
	clear = false
	return best


## 같은 층에 놓인 띠·단추·칩의 화면 네모 (보이는 것만) — 장면이 avoid에 보탠다. 화면을 다 덮는 판(말풍선 층 등)과 안 보이는 것은 뺀다
func hud_rects() -> Array:
	var out: Array = []
	var p := get_parent()
	if p == null:
		return out
	var vs := _vs()
	for c: Node in p.get_children():
		if c == self or not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		var r := (c as Control).get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0 or (r.size.x >= vs.x * 0.9 and r.size.y >= vs.y * 0.9):
			continue
		out.append(r)
	return out


func hide_all() -> void:
	if shown(1) or shown(-1):
		_on[1] = false
		_on[-1] = false
		for side: int in [1, -1]:
			(_hit[side] as Control).visible = false
		queue_redraw()


func shown(side: int) -> bool:
	return bool(_on.get(side, false))


func _tab_rect(side: int, y: float, vs: Vector2) -> Rect2:
	var w := tab_w()
	return Rect2(vs.x - w if side > 0 else 0.0, y - TAB_H * 0.5, w, TAB_H)


## 꼬리표가 화면에서 차지하는 네모 (밀리지 않은 자리 — 밀릴 때는 바깥쪽으로만 가므로 이 안에 머문다)
func mark_rect(side: int) -> Rect2:
	return _tab_rect(side, _y, _vs())


## 꼬리표 가운데 (화면) — 시험·캡처용
func center_of(side: int) -> Vector2:
	return mark_rect(side).get_center()


## 누르는 칸 (화면)
func rect_of(side: int) -> Rect2:
	var h: Control = _hit[side]
	return Rect2(h.position, h.size)


func _phase() -> float:
	return (_t - Balance.SOUVENIR_TWINKLE_EVERY) / Balance.SOUVENIR_TWINKLE_SECS


## 지금 별의 밝기 (0~1): 쉬는 동안 REST, SOUVENIR_TWINKLE_EVERY마다 한 번 1까지 올랐다 내려온다
func glow() -> float:
	if still:
		return 0.75
	var u := _phase()
	if u <= 0.0 or u >= 1.0:
		return REST
	return REST + (1.0 - REST) * sin(u * PI)


## 지금 꼬리표가 바깥쪽으로 밀린 만큼 (px, 0~NUDGE): 별이 밝아지는 동안 두 번 살짝. 움직임 줄이기면 늘 0
func nudge() -> float:
	if still:
		return 0.0
	var u := _phase()
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return NUDGE * absf(sin(u * TAU))


## 캡처·시험: 반짝임을 u(0~1) 자리로
func seek(u: float) -> void:
	_t = Balance.SOUVENIR_TWINKLE_EVERY + Balance.SOUVENIR_TWINKLE_SECS * clampf(u, 0.0, 1.0)
	queue_redraw()


func _process(dt: float) -> void:
	if not (shown(1) or shown(-1)):
		return
	if still:
		return
	_t += dt
	if _t >= Balance.SOUVENIR_TWINKLE_EVERY + Balance.SOUVENIR_TWINKLE_SECS:
		_t = 0.0
	queue_redraw()


func _draw() -> void:
	var g := glow()
	var push := nudge()
	for side: int in [1, -1]:
		if not shown(side):
			continue
		var out := float(side)                              # 바깥쪽 (+1 오른쪽)
		var m := mark_rect(side)
		m.position.x += out * push
		# 종이 꼬리표: 바깥 끝은 화면 밖으로 넘겨 (둥근 모서리는 안쪽만 보인다)
		var body := m
		if side > 0:
			body.size.x += TAB_TUCK
		else:
			body.position.x -= TAB_TUCK
			body.size.x += TAB_TUCK
		draw_style_box(_box, body)
		var c := m.get_center()
		# 작은 호박빛 별 (안쪽) — 밝기만 오르내린다
		var sc := c - Vector2(out * 6.0, 0.0)
		var px := 13.0 + 3.0 * g
		draw_circle(sc, px * 0.52, Color(STAR, 0.16 + 0.2 * g))
		_star(sc, px * 0.5, Color(STAR, 0.8 + 0.2 * g))
		_star(sc, px * 0.24, Color(CORE, 0.55 + 0.45 * g))
		# 바깥을 가리키는 꺾쇠
		var tip := c + Vector2(out * 11.0, 0.0)
		var arm := Vector2(-out * 5.0, 6.0)
		draw_polyline(PackedVector2Array([tip + arm * Vector2(1, -1), tip, tip + arm]), LINE, 2.4, true)


## 네 갈래 별 (가운데 c, 긴 갈래 r)
func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := float(i) * TAU / 8.0 - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.36))
	draw_colored_polygon(pts, col)


func _on_hit(e: InputEvent, side: int, h: Control) -> void:
	var press := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if press and shown(side):
		h.accept_event()
		tapped.emit(side)
