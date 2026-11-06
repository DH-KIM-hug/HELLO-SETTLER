## 거인의 방 그림 (docs/GIANT_ROOM.md 1 · UI.md 00) — 창가 선반 위 유리병. 타이틀과 짧은 창조가 함께 쓴다.
## 그림 파일(art/title/ — 그림 서브에이전트)이 있으면 그것을, 없으면 여기서 직접 그린다 (크림 벽·창문·선반·화분·등불·병).
##   title_bg_morning/sunset/night.png (없으면 room.png) = 방 전체 · jar.png / jar_green.png = 병 · 병 안·빛·손 흔드는 주민은 늘 여기서.
## 병 안: soil(흙 0~1) · water(물 0~1) · green(풀·나무 0~1) · houses(작은 마을 — 이어하기) · lid(뚜껑 0 닫힘 ~ 1 위로 벗어남) ·
##   sky(병 안 하늘 타임랩스 0 = 끔) · glow(병이 은은히 빛남).
## 좌표는 UI 기준 px (넓히기 비율: 폭 360, 높이 640~800). 병 자리는 jar_center()·jar_size().
class_name RoomArt
extends Control

const WALL := {"morning": [Color("f6eee0"), Color("e9d8bd")], "sunset": [Color("f4cfa6"), Color("d99b7b")], "night": [Color("2d3152"), Color("3d3658")]}
const SKY := {"morning": [Color("b9dcef"), Color("f3efd6")], "sunset": [Color("e98f63"), Color("f7d69c")], "night": [Color("141c38"), Color("2c3864")]}
const BEAM := {"morning": Color(1.0, 0.97, 0.85, 0.20), "sunset": Color(1.0, 0.72, 0.45, 0.20), "night": Color(0.72, 0.80, 1.0, 0.10)}
const WOOD := Color("a8734c")
const WOOD_DARK := Color("7f5236")
const WOOD_LIGHT := Color("c38f62")
const SOIL := Color("8a5a3b")
const SOIL_DARK := Color("6b4229")
const SOIL_TOP := Color("a7704a")
const ROCK := Color("8d8a86")
const WATER := Color(0.36, 0.62, 0.80, 0.92)
const WATER_TOP := Color(0.72, 0.88, 0.95, 1.0)
const GRASS := Color("5f9c4f")
const GRASS_LIGHT := Color("8cc46a")
const TREE := Color("3e7745")
const TREE_LIGHT := Color("62a35a")
const CORK := Color("c99d6d")
const CORK_DARK := Color("a77a4e")

var tod := "morning"
var close_up := false                 # 창조: 병을 크게 (방은 흐릿하게 뒤로)
var soil := 0.0
var water := 0.0
var green := 0.0
var houses := false
var lid := 0.0
var sky := 0.0                        # 병 안 하늘 타임랩스 위상 (0 = 끔)
var sky_on := false
var glow := 1.0
var pour := ""                        # "soil" · "water" — 지금 붓는 중 (위에서 떨어지는 알갱이·물줄기)
var waving := 0.0                     # 손 흔드는 주민 남은 초 (타이틀이 켬)
var lid_hint := false                 # 뚜껑이 살짝 오르내림 (끌어내리라는 뜻)
var dim := 0.0                        # 방을 어둡게 (창조 화면 — 병에 눈이 가게)
var t := 0.0

var bg_tex: Texture2D
var bg_has_jar := false               # 배경 그림에 병(마을)이 그려져 있음 → 병은 그리지 않고 빛·반짝임만
var bg_tint := Color.WHITE            # room.png(아침 방 하나)를 노을·밤에 쓸 때 색
var art_jar := Rect2()                # 배경 그림 속 병 몸통 자리 (그림 비율 0~1)
var art_waver := Vector2.ZERO         # 배경 그림 속 주민 자리 (손 흔들기 대신 반짝임)
var jar_tex: Texture2D
var _motes: Array = []
static var _radial: GradientTexture2D


## 부드러운 둥근 빛 (가운데 흰색 → 가장자리 투명) — 색은 modulate로
static func radial() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 128
		_radial.height = 128
	return _radial


func _light(c: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(radial(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 9:
		_motes.append(Vector3(r.randf(), r.randf(), r.randf() * TAU))


## 그림 속 병 몸통 자리·주민 자리 (1080×2400 그림 기준 비율 — 그림을 바꾸면 여기만 맞춘다)
const ART_JAR := {"title_bg_morning.png": Rect2(0.283, 0.38, 0.661, 0.3025), "title_bg_sunset.png": Rect2(0.278, 0.37, 0.678, 0.365),
	"title_bg_night.png": Rect2(0.333, 0.38, 0.633, 0.30), "room.png": Rect2(0.295, 0.45, 0.37, 0.23)}
const ART_WAVER := {"title_bg_morning.png": Vector2(0.711, 0.575), "title_bg_sunset.png": Vector2(0.597, 0.535), "title_bg_night.png": Vector2(0.555, 0.61)}
const ROOM_TINT := {"morning": Color.WHITE, "sunset": Color(1.0, 0.82, 0.72), "night": Color(0.42, 0.46, 0.70)}


## 그림 파일 고르기 (있으면): 이어하기 = title_bg_<시각>.png (병 속 마을까지 그려진 방) ·
## 처음(빈 병) = room.png (병 없는 방 — 노을·밤은 색을 입힘) + 빈 병은 직접. 창조(가까이)는 늘 직접 그림.
func load_art(green_jar: bool) -> void:
	bg_tex = null
	jar_tex = null
	bg_has_jar = false
	bg_tint = Color.WHITE
	if close_up:
		return
	var f := "title_bg_%s.png" % tod
	if green_jar:
		bg_tex = StartFlow.art(f)
	if bg_tex != null:
		bg_has_jar = true
		art_jar = ART_JAR[f]
		art_waver = ART_WAVER[f]
		return
	bg_tex = StartFlow.art("room.png")
	if bg_tex != null:
		art_jar = ART_JAR["room.png"]
		bg_tint = ROOM_TINT[tod]
		if green_jar:
			jar_tex = StartFlow.art("jar_green.png")
			if jar_tex == null:
				jar_tex = StartFlow.art("jar.png")
		else:
			jar_tex = StartFlow.art("jar_empty.png")    # 빈 병 그림이 생기면 (없으면 직접 그린 유리병)


func _process(dt: float) -> void:
	t += dt
	if waving > 0.0:
		waving = maxf(0.0, waving - dt)
	queue_redraw()


# ───────────────────────── 자리 ─────────────────────────
func shelf_y() -> float:
	return size.y * (0.80 if close_up else 0.735)


func jar_size() -> Vector2:
	if bg_tex != null:
		return jar_body().size
	var w := minf(size.x * (0.70 if close_up else 0.44), size.y * (0.36 if close_up else 0.21))
	return Vector2(w, w * 1.18)


## 병 몸통 가운데
func jar_center() -> Vector2:
	if bg_tex != null:
		return jar_body().get_center()
	var s := jar_size()
	return Vector2(size.x * 0.5, shelf_y() - 2.0 - s.y * 0.5)


## 배경 그림 좌표(비율) → 화면 (cover — 아래 가운데 맞춤)
func _cover_map(n: Vector2) -> Vector2:
	var ts := bg_tex.get_size()
	var k := maxf(size.x / ts.x, size.y / ts.y)
	var d := ts * k
	return (size - d) * Vector2(0.5, 1.0) + n * d


func jar_body() -> Rect2:
	if bg_tex != null:
		var a := _cover_map(art_jar.position)
		return Rect2(a, _cover_map(art_jar.end) - a)
	var s := jar_size()
	var c := jar_center()
	return Rect2(c - s * 0.5, s)


func lid_rect() -> Rect2:
	var b := jar_body()
	var w := b.size.x * 0.66
	var h := b.size.x * 0.17
	var neck_top := b.position.y - b.size.x * 0.10
	var y := neck_top - h + 3.0 - lid * (b.size.x * 0.75) + (sin(t * 3.0) * 4.0 if lid_hint else 0.0)
	return Rect2(b.get_center().x - w * 0.5 + lid * b.size.x * 0.25, y, w, h)


# ───────────────────────── 그리기 ─────────────────────────
func _draw() -> void:
	if bg_tex != null:
		_draw_cover(bg_tex)
	else:
		_draw_room()
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.08, 0.12, dim * 0.55))
	if bg_has_jar:                              # 그림 속 병: 은은한 빛 + 주민 곁 반짝임만
		glow *= 0.5
		_draw_glow()
		glow /= 0.5
		if waving > 0.0:
			_draw_sparkle(_cover_map(art_waver))
		return
	_draw_glow()
	if jar_tex != null:
		_draw_inside()
		var b := jar_body()
		var s := jar_tex.get_size()
		var w := b.size.x * 1.18
		var h := w * s.y / s.x
		draw_texture_rect(jar_tex, Rect2(b.get_center().x - w * 0.5, b.end.y - h + b.size.y * 0.02, w, h), false)
	else:
		_draw_jar()
	_draw_pour()


func _draw_cover(tex: Texture2D) -> void:
	var s := tex.get_size()
	var k := maxf(size.x / s.x, size.y / s.y)
	var d := s * k
	draw_texture_rect(tex, Rect2((size - d) * Vector2(0.5, 1.0), d), false, bg_tint)


## 그림 속 주민이 하늘(거인)을 향해 반짝 — 그림 위에 다른 그림체의 주민을 얹지 않으려고 손 흔들기 대신
func _draw_sparkle(p: Vector2) -> void:
	var a := clampf(minf(waving, 2.6 - waving) * 3.0, 0.0, 1.0)
	_light(p + Vector2(0, -6), 22.0, Color(1.0, 0.95, 0.70, 0.45 * a))
	for i in 3:
		var ph := t * 4.0 + i * 2.1
		var q := p + Vector2(-9 + i * 9, -18 - 4 * sin(ph))
		var r := (2.0 + 1.2 * sin(ph)) * a
		draw_line(q - Vector2(r * 1.8, 0), q + Vector2(r * 1.8, 0), Color(1, 1, 0.85, a), 1.2)
		draw_line(q - Vector2(0, r * 1.8), q + Vector2(0, r * 1.8), Color(1, 1, 0.85, a), 1.2)


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_room() -> void:
	var w := size.x
	var h := size.y
	var wall: Array = WALL[tod]
	_vgrad(Rect2(0, 0, w, h), wall[0], wall[1])
	# 벽지 결 (아주 옅은 세로줄)
	for i in range(0, int(w), 24):
		draw_rect(Rect2(i, 0, 1, shelf_y()), Color(1, 1, 1, 0.035 if tod != "night" else 0.02))
	# 창문 (왼쪽 위)
	var win := Rect2(w * 0.06, h * 0.30, w * 0.40, h * 0.25)
	if close_up:
		win = Rect2(-w * 0.04, h * 0.08, w * 0.34, h * 0.30)
	var skyc: Array = SKY[tod]
	_vgrad(win, skyc[0], skyc[1])
	_draw_window_sky(win)
	var f := 5.0
	draw_rect(Rect2(win.position - Vector2(f, f), win.size + Vector2(f, f) * 2.0), WOOD, false, f * 2.0)
	draw_rect(Rect2(win.position.x + win.size.x * 0.5 - 2, win.position.y, 4, win.size.y), WOOD)
	draw_rect(Rect2(win.position.x, win.position.y + win.size.y * 0.48 - 2, win.size.x, 4), WOOD)
	draw_rect(Rect2(win.position.x - f - 3, win.end.y + f, win.size.x + f * 2 + 6, 5), WOOD_LIGHT)    # 창턱
	# 커튼 (오른쪽에 반쯤 묶음)
	var cur := Color("e7b9a2") if tod != "night" else Color("8e6f86")
	var cx := win.position.x - f + 6.0
	var cpts := PackedVector2Array([Vector2(cx - 16, win.position.y - f - 6), Vector2(cx + 10, win.position.y - f - 6),
		Vector2(cx + 8, win.position.y + win.size.y * 0.55), Vector2(cx + 14, win.end.y + f + 4), Vector2(cx - 6, win.end.y + f + 4),
		Vector2(cx - 2, win.position.y + win.size.y * 0.55), Vector2(cx - 22, win.position.y + win.size.y * 0.2)])
	draw_colored_polygon(cpts, cur)
	draw_rect(Rect2(cx - 6, win.position.y + win.size.y * 0.52, 16, 4), cur.darkened(0.25))
	draw_rect(Rect2(win.position.x - 14, win.position.y - f - 9, win.size.x + 44, 3), WOOD_DARK)        # 커튼 봉
	# 창으로 들어온 빛 → 병 한쪽
	var b := jar_body()
	var beam: Color = BEAM[tod]
	draw_polygon(PackedVector2Array([Vector2(win.position.x + win.size.x * 0.3, win.end.y), win.end,
		Vector2(b.end.x + 10, shelf_y()), Vector2(b.position.x - 4, shelf_y())]),
		PackedColorArray([beam, beam, Color(beam, 0.0), Color(beam, 0.0)]))
	# 선반
	var sy := shelf_y()
	_vgrad(Rect2(0, sy + 14, w, h - sy - 14), wall[1].darkened(0.18), wall[1].darkened(0.30))
	draw_rect(Rect2(0, sy - 4, w, 8), WOOD_LIGHT)
	draw_rect(Rect2(0, sy + 4, w, 12), WOOD)
	draw_rect(Rect2(0, sy + 16, w, 3), WOOD_DARK)
	for bx: float in [w * 0.12, w * 0.88]:
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 5, sy + 16), Vector2(bx + 5, sy + 16), Vector2(bx + 5, sy + 48), Vector2(bx - 5, sy + 30)]), WOOD_DARK)
	_draw_props(sy)


func _draw_window_sky(win: Rect2) -> void:
	match tod:
		"morning":
			draw_circle(win.position + win.size * Vector2(0.78, 0.30), win.size.x * 0.09, Color(1.0, 0.98, 0.86))
			for c: Vector2 in [Vector2(0.25, 0.42), Vector2(0.36, 0.38), Vector2(0.46, 0.43)]:
				draw_circle(win.position + win.size * c, win.size.x * 0.08, Color(1, 1, 1, 0.85))
			draw_rect(Rect2(win.position.x, win.end.y - win.size.y * 0.16, win.size.x, win.size.y * 0.16), Color("a9cf9a"))
		"sunset":
			draw_circle(win.position + win.size * Vector2(0.62, 0.78), win.size.x * 0.14, Color(1.0, 0.86, 0.55))
			draw_rect(Rect2(win.position.x, win.end.y - win.size.y * 0.14, win.size.x, win.size.y * 0.14), Color("8d5a63"))
		"night":
			var r := RandomNumberGenerator.new()
			r.seed = 3
			for i in 14:
				var p := win.position + Vector2(r.randf(), r.randf() * 0.8) * win.size
				var tw := 0.55 + 0.45 * sin(t * 1.7 + i)
				draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 1, 0.9, tw))
			var m := win.position + win.size * Vector2(0.72, 0.28)
			draw_circle(m, win.size.x * 0.08, Color(0.98, 0.95, 0.80))
			draw_circle(m + Vector2(win.size.x * 0.035, -win.size.x * 0.02), win.size.x * 0.07, SKY["night"][0])


func _draw_props(sy: float) -> void:
	var w := size.x
	var b := jar_body()
	var k := b.size.x / 160.0
	# 화분 (창조 흙을 퍼 온 곳 — 이끼·민들레)
	var px := minf(w * 0.15, b.position.x - 34.0 * k)
	var pw := 34.0 * k
	var ph := 28.0 * k
	draw_colored_polygon(PackedVector2Array([Vector2(px - pw * 0.5, sy - ph), Vector2(px + pw * 0.5, sy - ph), Vector2(px + pw * 0.38, sy), Vector2(px - pw * 0.38, sy)]), Color("c4693f"))
	draw_rect(Rect2(px - pw * 0.56, sy - ph - 5 * k, pw * 1.12, 6 * k), Color("d77d52"))
	for i in 5:
		var lx := px - pw * 0.35 + i * pw * 0.17
		draw_line(Vector2(lx, sy - ph - 4 * k), Vector2(lx + (i - 2) * 3 * k, sy - ph - (14 + (i % 2) * 8) * k), Color("4f8a45"), 2.5 * k)
	draw_circle(Vector2(px + 2 * k, sy - ph - 22 * k), 4 * k, Color("f2d24b"))
	# 등불 (병 옆 — 밤엔 노란 빛)
	var lx2 := maxf(w * 0.86, b.end.x + 30.0 * k)
	var on := tod != "morning"
	if on:
		_light(Vector2(lx2, sy - 30 * k), 70 * k, Color(1.0, 0.78, 0.40, 0.30 if tod == "night" else 0.18))
	draw_rect(Rect2(lx2 - 12 * k, sy - 6 * k, 24 * k, 6 * k), Color("6a5a4c"))
	draw_colored_polygon(PackedVector2Array([Vector2(lx2 - 9 * k, sy - 6 * k), Vector2(lx2 + 9 * k, sy - 6 * k), Vector2(lx2 + 6 * k, sy - 18 * k), Vector2(lx2 - 6 * k, sy - 18 * k)]), Color("8a7462"))
	draw_rect(Rect2(lx2 - 7 * k, sy - 44 * k, 14 * k, 26 * k), Color(0.92, 0.95, 0.98, 0.35))
	draw_rect(Rect2(lx2 - 7 * k, sy - 44 * k, 14 * k, 26 * k), Color(1, 1, 1, 0.5), false, 1.0)
	draw_rect(Rect2(lx2 - 8 * k, sy - 48 * k, 16 * k, 4 * k), Color("6a5a4c"))
	if on:
		var fl := 1.0 + 0.08 * sin(t * 9.0) + 0.05 * sin(t * 13.0)
		draw_circle(Vector2(lx2, sy - 28 * k), 4.0 * k * fl, Color(1.0, 0.70, 0.30))
		draw_circle(Vector2(lx2, sy - 29 * k), 2.2 * k * fl, Color(1.0, 0.95, 0.70))


func _draw_glow() -> void:
	if glow <= 0.0:
		return
	var c := jar_center()
	var s := jar_size()
	var pulse := 0.85 + 0.15 * sin(t * 1.3)
	var col := Color(1.0, 0.93, 0.62) if not houses else Color(0.85, 1.0, 0.70)
	_light(c + Vector2(0, s.y * 0.08), s.x * 1.15, Color(col, 0.30 * glow * pulse * (1.5 if tod == "night" else 1.0)))


## 둥근 모서리 사각형 (위·아래 모서리 반지름 따로) — 시계 방향 점
static func rounded(r: Rect2, rt: float, rb: float, seg := 6) -> PackedVector2Array:
	var p := PackedVector2Array()
	var corners := [[Vector2(r.end.x - rt, r.position.y + rt), rt, -PI * 0.5], [Vector2(r.end.x - rb, r.end.y - rb), rb, 0.0],
		[Vector2(r.position.x + rb, r.end.y - rb), rb, PI * 0.5], [Vector2(r.position.x + rt, r.position.y + rt), rt, PI]]
	for c: Array in corners:
		for i in seg + 1:
			var a: float = c[2] + PI * 0.5 * i / seg
			p.append(c[0] + Vector2(cos(a), sin(a)) * float(c[1]))
	return p


func inner_poly() -> PackedVector2Array:
	var b := jar_body().grow(-3.0)
	return rounded(b, b.size.x * 0.24, b.size.x * 0.11)


## 흙 겉면 높이 (u = 병 안 왼쪽 0 ~ 오른쪽 1) — 언덕 둘 + 호수 자리 하나
func surface_y(u: float) -> float:
	var b := jar_body().grow(-3.0)
	var base := b.end.y - soil * 0.40 * b.size.y
	var hill := 0.05 * sin(u * 6.0 + 0.6) + 0.07 * exp(-pow((u - 0.2) / 0.12, 2.0)) - 0.10 * exp(-pow((u - 0.66) / 0.13, 2.0))
	return base - hill * b.size.y * soil


func water_y() -> float:
	var b := jar_body().grow(-3.0)
	var base := b.end.y - soil * 0.40 * b.size.y
	return lerpf(surface_y(0.66) + 1.0, base + 2.0, clampf(water, 0.0, 1.0))


func _clip(poly: PackedVector2Array, col: Color) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, inner_poly()):
		if piece.size() >= 3:
			draw_colored_polygon(piece, col)


func _soil_poly(off := 0.0) -> PackedVector2Array:
	var b := jar_body().grow(-3.0)
	var p := PackedVector2Array()
	var n := 32
	for i in n + 1:
		var u := float(i) / n
		p.append(Vector2(b.position.x - 4 + u * (b.size.x + 8), surface_y(u) + off))
	p.append(Vector2(b.end.x + 4, b.end.y + 4))
	p.append(Vector2(b.position.x - 4, b.end.y + 4))
	return p


## 병 안 (흙·물·풀·나무·집·하늘) — 그림 병을 쓸 때도 이것은 직접
func _draw_inside() -> void:
	var b := jar_body().grow(-3.0)
	var inner := inner_poly()
	draw_colored_polygon(inner, Color(0.85, 0.93, 0.97, 0.16 if tod != "night" else 0.10))
	if sky_on:
		var day := 0.5 + 0.5 * sin(sky)
		var c := Color("1c2547").lerp(Color("cfe8f2"), day)
		draw_colored_polygon(inner, Color(c, 0.8))
		var sp := Vector2(b.get_center().x + cos(sky) * b.size.x * 0.32, b.get_center().y - sin(sky) * b.size.y * 0.25)
		if sin(sky) > -0.1:
			draw_circle(sp, b.size.x * 0.04, Color(1.0, 0.94, 0.70, clampf(sin(sky) + 0.1, 0.0, 1.0)))
	if not houses and soil <= 0.0:
		for m: Vector3 in _motes:                   # 빈 병의 빛 알갱이
			var y := fposmod(m.y - t * 0.03 * (0.5 + m.x), 1.0)
			var p := Vector2(b.position.x + b.size.x * (0.15 + 0.7 * m.x) + sin(t + m.z) * 4.0, b.position.y + b.size.y * (0.2 + 0.75 * y))
			draw_circle(p, 1.6, Color(1.0, 0.97, 0.75, 0.55 * sin(y * PI)))
	if soil > 0.0:
		_clip(_soil_poly(), SOIL)
		_clip(_soil_poly(b.size.y * 0.05 * soil), SOIL_DARK)
		_clip(_soil_poly(b.size.y * 0.13 * soil), SOIL)
		_clip(_soil_poly(b.size.y * 0.30 * soil), ROCK)
		# 겉면 밝은 줄
		var top := PackedVector2Array()
		for i in 33:
			var u := float(i) / 32.0
			top.append(Vector2(b.position.x + u * b.size.x, surface_y(u) + 1.0))
		draw_polyline(top, SOIL_TOP, 2.0)
	if water > 0.0 and soil > 0.0:
		var wy := water_y()
		var wr := PackedVector2Array([Vector2(b.position.x, wy), Vector2(b.end.x, wy), Vector2(b.end.x, b.end.y), Vector2(b.position.x, b.end.y)])
		for piece: PackedVector2Array in Geometry2D.clip_polygons(wr, _soil_poly()):
			for p2: PackedVector2Array in Geometry2D.intersect_polygons(piece, inner):
				draw_colored_polygon(p2, WATER)
		var x0 := INF
		var x1 := -INF
		for i in 65:
			var u := float(i) / 64.0
			if surface_y(u) > wy + 0.5:
				var x := b.position.x + u * b.size.x
				x0 = minf(x0, x)
				x1 = maxf(x1, x)
		if x1 > x0:
			draw_line(Vector2(x0, wy), Vector2(x1, wy), WATER_TOP, 1.5)
			var sh := fposmod(t * 12.0, x1 - x0 + 1.0)
			draw_line(Vector2(x0 + sh * 0.6, wy + 2), Vector2(minf(x1, x0 + sh * 0.6 + 6), wy + 2), Color(1, 1, 1, 0.6), 1.0)
	if green > 0.0 and soil > 0.0:
		_draw_life(b)
	if houses:
		_draw_houses(b)
	if waving > 0.0 and houses:
		_draw_waver(b)


func _draw_life(b: Rect2) -> void:
	var wy := water_y() if water > 0.0 else INF
	var half := clampf(green, 0.0, 1.0) * 0.62
	var seg := PackedVector2Array()
	for i in 49:
		var u := float(i) / 48.0
		var y := surface_y(u)
		if absf(u - 0.45) > half or y > wy - 0.5:
			_grass(seg)
			seg = PackedVector2Array()
			continue
		seg.append(Vector2(b.position.x + u * b.size.x, y + 1.0))
	_grass(seg)
	var k := b.size.x / 160.0
	for tr: Vector2 in [Vector2(0.10, 0.45), Vector2(0.17, 0.62), Vector2(0.25, 0.78), Vector2(0.88, 0.70), Vector2(0.94, 0.85), Vector2(0.31, 0.95)]:
		var g := clampf((green - tr.y * 0.9) * 5.0, 0.0, 1.0)
		if g <= 0.0:
			continue
		var x := b.position.x + tr.x * b.size.x
		var y := surface_y(tr.x)
		var hh := 14.0 * k * g
		draw_rect(Rect2(x - 1.2 * k, y - hh, 2.4 * k, hh), Color("6a4a32"))
		draw_circle(Vector2(x, y - hh - 3 * k * g), 6.0 * k * g, TREE)
		draw_circle(Vector2(x - 1.5 * k, y - hh - 5 * k * g), 3.2 * k * g, TREE_LIGHT)


func _grass(seg: PackedVector2Array) -> void:
	if seg.size() < 2:
		return
	var k := maxf(1.0, jar_size().x / 160.0)
	draw_polyline(seg, GRASS, 4.0 * k)
	var hi := PackedVector2Array()
	for p in seg:
		hi.append(p - Vector2(0, 1.5 * k))
	draw_polyline(hi, GRASS_LIGHT, 1.5 * k)


func _draw_houses(b: Rect2) -> void:
	var k := b.size.x / 160.0
	for hx: float in [0.40, 0.50]:
		var x := b.position.x + hx * b.size.x
		var y := surface_y(hx) + 1.0
		var hw := 11.0 * k
		var hh := 8.0 * k
		draw_rect(Rect2(x - hw * 0.5, y - hh, hw, hh), Color("eadcc0"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - hw * 0.65, y - hh), Vector2(x + hw * 0.65, y - hh), Vector2(x, y - hh - 7 * k)]), Color("b5533c"))
		var lit := tod == "night" or (sky_on and sin(sky) < 0.0)
		draw_rect(Rect2(x - 1.5 * k, y - hh * 0.65, 3 * k, 3 * k), Color("ffd66b") if lit else Color("5b4636"))
	# 모닥불 연기
	var fx := b.position.x + 0.56 * b.size.x
	var fy := surface_y(0.56)
	draw_circle(Vector2(fx, fy - 1.5 * k), 1.8 * k, Color(1.0, 0.6, 0.25))
	for i in 3:
		var a := fposmod(t * 0.4 + i / 3.0, 1.0)
		draw_circle(Vector2(fx + sin(a * 6.0) * 2 * k, fy - 4 * k - a * 18 * k), (1.5 + a * 2.5) * k, Color(0.9, 0.9, 0.9, 0.35 * (1.0 - a)))


## 손 흔드는 작은 주민 (아이콘 L_2의 장면) — 유리 가까이 앞쪽
func _draw_waver(b: Rect2) -> void:
	var k := b.size.x / 115.0
	var a := clampf(minf(waving, 2.6 - waving) * 3.0, 0.0, 1.0)      # 나타났다 사라짐
	var x := b.position.x + 0.30 * b.size.x
	var y := surface_y(0.30)
	var body := Color("4c6fa8", a)
	draw_rect(Rect2(x - 2.2 * k, y - 8 * k, 4.4 * k, 6 * k), body)
	draw_rect(Rect2(x - 1.8 * k, y - 2 * k, 1.4 * k, 2 * k), Color("3b3030", a))
	draw_rect(Rect2(x + 0.4 * k, y - 2 * k, 1.4 * k, 2 * k), Color("3b3030", a))
	draw_circle(Vector2(x, y - 10.5 * k), 2.6 * k, Color("f2c9a5", a))
	draw_rect(Rect2(x - 2.6 * k, y - 13.2 * k, 5.2 * k, 1.8 * k), Color("5a3b2a", a))
	var sw := sin(t * 10.0) * 0.6
	var sh := Vector2(x + 2.2 * k, y - 7.5 * k)
	draw_line(sh, sh + Vector2(cos(-1.2 + sw), sin(-1.2 + sw)) * 5.5 * k, Color("f2c9a5", a), 1.6 * k)


func _draw_jar() -> void:
	var b := jar_body()
	var k := b.size.x / 160.0
	# 선반 위 그림자
	draw_colored_polygon(rounded(Rect2(b.position.x - 6, b.end.y - 3, b.size.x + 30, 7), 3, 3, 3), Color(0, 0, 0, 0.12))
	_draw_inside()
	var outer := rounded(b, b.size.x * 0.25, b.size.x * 0.12)
	draw_colored_polygon(outer, Color(0.90, 0.97, 1.0, 0.08))
	var loop := outer.duplicate()
	loop.append(outer[0])
	draw_polyline(loop, Color(0.36, 0.47, 0.52, 0.55), 2.0 * maxf(1.0, k))
	draw_polyline(loop, Color(1, 1, 1, 0.35), 1.0)
	# 목 (메이슨 자 나사산)
	var nw := b.size.x * 0.72
	var nh := b.size.x * 0.12
	var neck := Rect2(b.get_center().x - nw * 0.5, b.position.y - nh + 4, nw, nh)
	draw_rect(neck, Color(0.88, 0.96, 1.0, 0.22))
	draw_rect(neck, Color(0.36, 0.47, 0.52, 0.55), false, 1.5)
	for i in 2:
		var yy := neck.position.y + nh * (0.35 + i * 0.3)
		draw_line(Vector2(neck.position.x + 2, yy), Vector2(neck.end.x - 2, yy + 2), Color(1, 1, 1, 0.45), 1.0)
	# 반사광 (왼쪽 긴 줄 둘 · 오른쪽 위 점)
	draw_rect(Rect2(b.position.x + b.size.x * 0.10, b.position.y + b.size.y * 0.18, b.size.x * 0.05, b.size.y * 0.62), Color(1, 1, 1, 0.38))
	draw_rect(Rect2(b.position.x + b.size.x * 0.18, b.position.y + b.size.y * 0.24, b.size.x * 0.02, b.size.y * 0.42), Color(1, 1, 1, 0.28))
	draw_circle(Vector2(b.end.x - b.size.x * 0.17, b.position.y + b.size.y * 0.16), b.size.x * 0.025, Color(1, 1, 1, 0.6))
	# 코르크 뚜껑
	if lid < 1.2:
		var lr := lid_rect()
		draw_colored_polygon(rounded(lr, 4 * k, 2 * k, 3), CORK)
		draw_rect(Rect2(lr.position.x, lr.end.y - lr.size.y * 0.3, lr.size.x, lr.size.y * 0.3), CORK_DARK)
		var r := RandomNumberGenerator.new()
		r.seed = 11
		for i in 10:
			draw_rect(Rect2(lr.position + Vector2(r.randf() * (lr.size.x - 3), r.randf() * lr.size.y * 0.6), Vector2(1.5, 1.5) * maxf(1.0, k)), CORK_DARK)


## 붓는 중: 병 위에서 흙 알갱이 / 물줄기
func _draw_pour() -> void:
	if pour == "":
		return
	var b := jar_body()
	var x := b.get_center().x - b.size.x * 0.05
	var top := b.position.y - b.size.x * 0.55
	var bottom := surface_y(0.45) if soil > 0.0 else b.end.y - 4
	if pour == "water":
		var wob := sin(t * 20.0) * 1.0
		draw_rect(Rect2(x - 3 + wob, top, 6, bottom - top), Color(WATER, 0.85))
		draw_rect(Rect2(x - 1 + wob, top, 2, bottom - top), Color(1, 1, 1, 0.5))
		for i in 4:
			var a := fposmod(t * 3.0 + i * 0.25, 1.0)
			draw_circle(Vector2(x + (i - 1.5) * 6 * a, bottom - 2 - a * 6), 1.6, Color(WATER_TOP, 1.0 - a))
	else:
		var r := RandomNumberGenerator.new()
		r.seed = 5
		for i in 90:
			var ph := r.randf()
			var a := fposmod(t * 1.4 + ph, 1.0)
			var px := x + (r.randf() - 0.5) * (8.0 + a * a * 40.0)
			var py := lerpf(top, bottom, a)
			var sz := 2.0 + r.randf() * 2.5
			draw_rect(Rect2(px, py, sz, sz), [SOIL_TOP, SOIL, SOIL_DARK][i % 3])
		# 쌓이는 곳의 흙먼지
		for i in 6:
			var a2 := fposmod(t * 2.0 + i / 6.0, 1.0)
			draw_circle(Vector2(x + (i - 2.5) * 7.0 * a2, bottom - 3.0 - a2 * 8.0), 3.0 + a2 * 3.0, Color(SOIL_TOP, 0.35 * (1.0 - a2)))
