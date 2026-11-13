## 둥근 지도 (UI 09 '오른쪽 위 둥근 지도') — 넓은 세상 장면(view/world_village.gd) 오른쪽 위, 위 띠 아래.
## 병 전체가 동그란 지도 하나: 본 땅(풀·숲·호수·강·소금)은 색, 안 본 땅은 안개(흰 구름빛), 둘레는 유리벽.
## 무리마다 점(보고 있는 무리는 크게), 지금 화면이 보는 곳은 흰 테두리 원. 화면 위쪽이 지도 위쪽 (카메라 방향대로 돈다).
## 누르면 pressed_at(세상 좌표) — 장면이 그곳으로 카메라를 옮긴다. 그림은 안개가 바뀔 때 (2초에 한 번까지) + 30초마다 (물이 바뀜).
class_name WorldMinimap
extends Control

signal pressed_at(p: Vector2)
signal unfold_pressed                  # (Q29) 접힌 작은 지도를 누름 — 장면이 펼친다

const SIZE := 88.0                     # 지름 (기준 360 폭 화면 px)
## (Q29) 첫 병 첫날의 '접힌 지도' — 같은 지도 그림을 작은 동그라미로 (보이는 지름 NUB_VIS · 누르는 칸 NUB, 48 논리px = 엄지 칸)
const NUB := 48.0
const NUB_VIS := 38.0
const RES := 128                       # 지도 그림 한 변 (픽셀)
const REDRAW_MIN := 2.0
const REDRAW_EVERY := 30.0
const FOG_COL := Color("eceae2")
const RIM := Color("242121")

var world: JarWorld
var tex: ImageTexture
var img: Image
var _forest := PackedByteArray()
var _fog_v := -1
var _t := 0.0
var _since := 999.0
var _view_c := Vector2.ZERO
var _view_r := 40.0
var _angle := 0.0
var _focus: Village
var render_ms := 0.0
var folded := false


## (Q29) 접기 · 펴기 — 접히면 작은 동그라미 (무리 점 하나만), 누르면 unfold_pressed
func set_folded(on: bool) -> void:
	if folded == on:
		return
	folded = on
	var d := NUB if on else SIZE
	custom_minimum_size = Vector2(d, d)
	size = Vector2(d, d)
	queue_redraw()


func setup(jw: JarWorld) -> void:
	world = jw
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	img = Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	_mark_forests()
	redraw()


## 숲은 바뀌지 않으므로 한 번만 (지도 픽셀마다 숲인가)
func _mark_forests() -> void:
	var ww := world.water
	var step := float(ww.n) / RES
	_forest.resize(RES * RES)
	_forest.fill(0)
	for f: Dictionary in ww.forests:
		var cx := (float(f["x"]) + ww.rr) / step
		var cy := (float(f["y"]) + ww.rr) / step
		var r := float(f["r"]) / step
		for py in range(maxi(0, floori(cy - r)), mini(RES, ceili(cy + r) + 1)):
			for px in range(maxi(0, floori(cx - r)), mini(RES, ceili(cx + r) + 1)):
				if Vector2(px + 0.5 - cx, py + 0.5 - cy).length() <= r:
					_forest[py * RES + px] = 1


## 지도 그림을 다시 (본 땅 · 물 · 안개)
func redraw() -> void:
	var t0 := Time.get_ticks_usec()
	var ww := world.water
	var step := float(ww.n) / RES
	_fog_v = ww.fog_version
	_since = 0.0
	img.fill(Color(0, 0, 0, 0))
	var grass := Style.GRASS_COOL.lerp(Style.GRASS, 0.5)
	for py in RES:
		var y := -ww.rr + (py + 0.5) * step
		for px in RES:
			var x := -ww.rr + (px + 0.5) * step
			if not ww.inside(x, y, 0.5):
				continue
			if not ww.revealed(x, y):
				img.set_pixel(px, py, FOG_COL)
				continue
			var k := ww.idx(x, y)
			var col := grass.lerp(Style.GRASS_WET, clampf(ww.wet_k(k) - 0.3, 0.0, 0.6))
			if _forest[py * RES + px] == 1:
				col = Color("3f6b3a")
			if ww.is_lake(k):
				col = Color("6fb7c9").darkened(clampf(ww.depth(k) * 1.5, 0.0, 0.45))
			elif ww.is_river(k):
				col = Color("5aaab4")
			elif ww.is_salt_flat(k):
				col = Color("f2efe6")
			img.set_pixel(px, py, col)
	if tex == null:
		tex = ImageTexture.create_from_image(img)
	else:
		tex.update(img)
	render_ms = (Time.get_ticks_usec() - t0) / 1000.0
	queue_redraw()


## 장면이 매 화면: 지금 보는 곳(세상 좌표)·덮는 반지름·지도 돌림·보고 있는 무리
func update_view(c: Vector2, r: float, angle: float, focus: Village) -> void:
	var dt := get_process_delta_time()
	_since += dt
	if (world.water.fog_version != _fog_v and _since >= REDRAW_MIN) or _since >= REDRAW_EVERY:
		redraw()
	if c.distance_to(_view_c) > 0.5 or absf(r - _view_r) > 0.5 or absf(angle - _angle) > 0.001 or focus != _focus:
		_view_c = c
		_view_r = r
		_angle = angle
		_focus = focus
		queue_redraw()


## 세상 좌표 → 지도 위 점 (Control 안 px)
func to_map(p: Vector2) -> Vector2:
	var rr := world.water.rr
	var c := size * 0.5
	return c + (p / rr * (SIZE * 0.5 - 3.0)).rotated(_angle)


func from_map(q: Vector2) -> Vector2:
	var rr := world.water.rr
	var c := size * 0.5
	return ((q - c).rotated(-_angle)) / (SIZE * 0.5 - 3.0) * rr


func _draw() -> void:
	if folded:
		_draw_nub()
		return
	var c := size * 0.5
	var rad := SIZE * 0.5 - 3.0
	var hb := HudBatch.of(self)
	if hb != null:                         # (P1b) 테두리는 화면 UI 바탕 겹에 · 지도 위 표시는 삼각형 배열 하나로 (그림은 같음)
		var g := HudBatch.Geo.new()
		g.circle(c, rad + 3.0, RIM)
		g.circle(c, rad + 1.0, Color("dfe9ee"))
		hb.put_shapes(self, g)
	else:
		draw_circle(c, rad + 3.0, RIM)
		draw_circle(c, rad + 1.0, Color("dfe9ee"))           # 유리벽 (옅은 하늘빛 테)
	if tex != null:
		# 둥근 지도 = 원 다각형에 그림을 입힘 (지도 돌림 포함)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			var u := Vector2(cos(a), sin(a))
			pts.append(c + u.rotated(_angle) * rad)
			uvs.append(Vector2(0.5, 0.5) + u * 0.5)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	# 지금 보는 곳 · 무리 — 한 삼각형 배열로 (원·선마다 따로 그리면 그리기가 그만큼 는다)
	var top := HudBatch.Geo.new()
	var vr := clampf(_view_r / world.water.rr * rad, 2.5, rad)
	top.arc(to_map(_view_c), vr, 0.0, TAU, 32, Color.WHITE, 1.5, true)
	for q in world.settlements:
		var p := to_map(q.center)
		var big := q == _focus
		top.circle(p, 3.5 if big else 2.5, RIM)
		top.circle(p, 2.3 if big else 1.4, Color("e8b04a") if big else Color("c8743a"))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), top.pts, top.cols)


## 접힌 지도: 유리 테두리 안에 접힌 종이 지도 그림 (세 칸 지그재그 + 지금 무리 점) — 첫날엔 안 본 땅(안개)뿐이라
## 지도 그림을 줄여 넣으면 흰 동그라미로만 보여서, '지도'로 읽히는 모양을 그린다. 삼각형 배열 한두 번
func _draw_nub() -> void:
	var c := size * 0.5
	var rad := NUB_VIS * 0.5 - 2.5
	var g := HudBatch.Geo.new()
	g.circle(c, rad + 2.5, RIM)
	g.circle(c, rad + 1.0, Color("dfe9ee"))
	g.circle(c, rad - 0.5, Color("cfe3c4"))
	var hb := HudBatch.of(self)
	if hb != null:
		hb.put_shapes(self, g)
	else:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), g.pts, g.cols)
	var top := HudBatch.Geo.new()
	var w := 7.0                            # 한 칸 너비 (세 칸 = 21)
	var h := 16.0
	var x0 := c.x - w * 1.5
	var y0 := c.y - h * 0.5
	var lean := 2.0                          # 지그재그로 접힌 높낮이
	var paper := [Color("fbf6e6"), Color("e9dfc2"), Color("fbf6e6")]
	for i in 3:
		var l := x0 + w * i
		var dl := lean if i % 2 == 1 else 0.0
		var dr := lean if i % 2 == 0 else 0.0
		top.polygon(PackedVector2Array([Vector2(l, y0 + dl), Vector2(l + w, y0 + dr), Vector2(l + w, y0 + h + dr), Vector2(l, y0 + h + dl)]), paper[i])
	var outline := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0 + lean), Vector2(x0 + 2 * w, y0), Vector2(x0 + 3 * w, y0 + lean),
		Vector2(x0 + 3 * w, y0 + h + lean), Vector2(x0 + 2 * w, y0 + h), Vector2(x0 + w, y0 + h + lean), Vector2(x0, y0 + h), Vector2(x0, y0)])
	top.polyline(outline, RIM, 1.2, false)
	top.line(Vector2(x0 + w, y0 + lean), Vector2(x0 + w, y0 + h + lean), RIM, 1.0)
	top.line(Vector2(x0 + 2 * w, y0), Vector2(x0 + 2 * w, y0 + h), RIM, 1.0)
	top.line(Vector2(x0 + 2.0, y0 + 9.0), Vector2(x0 + w + 3.0, y0 + 6.5), Color("6fb7c9"), 1.6)     # 물줄기 한 가닥
	top.line(Vector2(x0 + w + 3.0, y0 + 6.5), Vector2(x0 + 3 * w - 2.0, y0 + 11.0), Color("6fb7c9"), 1.6)
	var dot := Vector2(c.x + 1.5, y0 + h * 0.62)
	top.circle(dot, 2.8, RIM)
	top.circle(dot, 1.9, Color("e8b04a"))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), top.pts, top.cols)


func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.INF
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (e as InputEventMouseButton).position
	elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		pos = (e as InputEventScreenTouch).position
	if pos == Vector2.INF:
		return
	if folded:                             # 접힌 지도: 누르는 칸(NUB) 어디든 = 펼치기
		if Rect2(Vector2.ZERO, size).has_point(pos):
			accept_event()
			GameAudio.ui_click()
			unfold_pressed.emit()
		return
	if pos.distance_to(size * 0.5) > SIZE * 0.5:
		return
	accept_event()
	GameAudio.ui_click()
	pressed_at.emit(from_map(pos))
