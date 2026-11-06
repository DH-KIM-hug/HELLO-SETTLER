## 둥근 지도 (UI 09 '오른쪽 위 둥근 지도') — 넓은 세상 장면(view/world_village.gd) 오른쪽 위, 위 띠 아래.
## 병 전체가 동그란 지도 하나: 본 땅(풀·숲·호수·강·소금)은 색, 안 본 땅은 안개(흰 구름빛), 둘레는 유리벽.
## 무리마다 점(보고 있는 무리는 크게), 지금 화면이 보는 곳은 흰 테두리 원. 화면 위쪽이 지도 위쪽 (카메라 방향대로 돈다).
## 누르면 pressed_at(세상 좌표) — 장면이 그곳으로 카메라를 옮긴다. 그림은 안개가 바뀔 때 (2초에 한 번까지) + 30초마다 (물이 바뀜).
class_name WorldMinimap
extends Control

signal pressed_at(p: Vector2)

const SIZE := 88.0                     # 지름 (기준 360 폭 화면 px)
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
	var c := size * 0.5
	var rad := SIZE * 0.5 - 3.0
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
	# 지금 보는 곳
	var vr := clampf(_view_r / world.water.rr * rad, 2.5, rad)
	draw_arc(to_map(_view_c), vr, 0.0, TAU, 32, Color.WHITE, 1.5, true)
	# 무리
	for q in world.settlements:
		var p := to_map(q.center)
		var big := q == _focus
		draw_circle(p, 3.5 if big else 2.5, RIM)
		draw_circle(p, 2.3 if big else 1.4, Color("e8b04a") if big else Color("c8743a"))


func _gui_input(e: InputEvent) -> void:
	var pos := Vector2.INF
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (e as InputEventMouseButton).position
	elif e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		pos = (e as InputEventScreenTouch).position
	if pos == Vector2.INF:
		return
	if pos.distance_to(size * 0.5) > SIZE * 0.5:
		return
	accept_event()
	GameAudio.ui_click()
	pressed_at.emit(from_map(pos))
