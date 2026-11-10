## 아이들 장면의 그림 말풍선 (ROADMAP Q2-b 귀여움 묶음 ⑤ — 저녁 이야기 · 사방치기). 글·숫자 없이 그림만: 별 · 달 · 큰 물고기 · 나무 · 쿨쿨 · 조약돌.
## 화면만 (ADR-0001): KidsView가 매 화면 비우고(clear) 채우면(add) 여기서 머리 위에 그린다 — 시뮬레이션은 읽지도 바꾸지도 않는다.
## 크기는 화면 화소로 일정 (글 말풍선처럼 — 멀리서도 읽힘).
class_name KidBubbles
extends Control

const CREAM := Color("fffbea")
const INK := Color("252122")
const SIZE := Vector2(31.0, 26.0)      # 말풍선 (논리 화소)
const TAIL := 5.0
const GAP := 2.0                       # 머리와 꼬리 사이
const SMALL := 0.72                     # 작은 풍선 (쿨쿨)
const PICS := ["star", "moon", "fish", "tree", "zzz", "pebble"]
const DODGE_GAP := 3.0                  # 작은 풍선이 큰 풍선에서 띄우는 틈 (화소)
const STONE := Color("b9b2a4")
const YELLOW := Color("f6c945")
const MOON := Color("f7dc7a")
const BLUE := Color("6aa9d8")
const GREEN := Color("6fae5a")
const BARK := Color("8a5a3c")
const SLEEP := Color("5a7fb0")

var items: Array = []                  # [모델, 그림, 그림 속 0~1, 작게, 시계]
var boxes: Array = []                  # (시험) 마지막으로 그린 풍선들 [몸통 네모, 작게]
var _box := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_border_width_all(1)
	_box.anti_aliasing = true


func clear() -> void:
	if not items.is_empty():
		items.clear()
		queue_redraw()


## m 머리 위에 그림 하나 (u = 그 그림이 떠 있는 동안의 0~1 — 처음엔 톡 커지고 끝엔 옅어짐)
func add(m: Node3D, pic: String, u: float, small := false, t := 0.0) -> void:
	items.append([m, pic, u, small, t])
	queue_redraw()


## 머리 꼭대기의 화면 자리 (카메라 뒤면 INF)
static func head_px(cam: Camera3D, m: Node3D) -> Vector2:
	var feet := m.global_position
	var doll: Variant = m.get("doll")
	if doll is Node3D and is_instance_valid(doll):
		feet = (doll as Node3D).global_position
	if cam.is_position_behind(feet):
		return Vector2.INF
	var top := float(m.call("react_top")) if m.has_method("react_top") else 2.4 * m.scale.y
	return cam.unproject_position(feet) + TapReact.up_px(cam, feet) * top


func _draw() -> void:
	if items.is_empty() or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := get_viewport_rect().size
	var heads: Array = []                         # 보이는 것만: [머리 자리, 항목]
	var bigs: Array = []                          # 큰 풍선의 몸통 네모
	for it: Array in items:
		var m: Node3D = it[0]
		if not is_instance_valid(m) or not m.is_visible_in_tree():
			continue
		var p := head_px(cam, m)
		if p == Vector2.INF or p.x < 0.0 or p.x > vs.x or p.y < 0.0 or p.y > vs.y:
			continue
		heads.append([p, it])
		if not bool(it[3]):
			var b := box_of(p, float(it[2]), false, float(it[4]), vs)
			if not b.is_empty():
				bigs.append(b[0])
	boxes.clear()
	for h: Array in heads:
		var it: Array = h[1]
		var small := bool(it[3])
		var b := box_of(h[0], float(it[2]), small, float(it[4]), vs)
		if b.is_empty():
			continue
		var rc: Rect2 = b[0]
		if small:                                     # 작은 풍선(쿨쿨·조약돌·별)은 큰 풍선(어르신의 그림)을 비켜 옆으로 — 꼬리는 머리에 그대로
			rc.position.x += dodge(rc, bigs)
		boxes.append([rc, small])
		paint(h[0], rc, String(it[1]), float(b[1]), float(b[2]), float(it[4]))


## 꼬리 끝이 p (머리 꼭대기)인 말풍선의 몸통 → [네모, 크기 배율, 짙기] (아직/이미 안 보이면 [])
static func box_of(p: Vector2, u: float, small: bool, t: float, vs: Vector2) -> Array:
	var pop := smoothstep(0.0, 0.1, u)
	var a := pop * (1.0 - smoothstep(0.88, 1.0, u))
	if a <= 0.01:
		return []
	var k := (SMALL if small else 1.0) * (0.7 + 0.3 * pop + 0.06 * sin(clampf(u / 0.16, 0.0, 1.0) * PI))
	var sz := SIZE * k
	var c := Vector2(p.x, p.y - GAP - TAIL * k - sz.y * 0.5 + sin(t * 2.2) * 0.6)
	if c.x - sz.x * 0.5 < 2.0:                    # 화면 밖으로 나가지 않게 (꼬리는 머리 위에 그대로)
		c.x = 2.0 + sz.x * 0.5
	elif c.x + sz.x * 0.5 > vs.x - 2.0:
		c.x = vs.x - 2.0 - sz.x * 0.5
	if c.y - sz.y * 0.5 < 2.0:                    # 위가 모자라면 머리 옆으로
		c.y = 2.0 + sz.y * 0.5
	return [Rect2(c - sz * 0.5, sz), k, a]


## 작은 풍선 rc가 큰 풍선들과 겹치거나 닿으면 옆으로 얼마나 비킬까 (화소 — 가까운 쪽으로, 틈 DODGE_GAP). 안 겹치면 0
static func dodge(rc: Rect2, bigs: Array) -> float:
	var shift := 0.0
	for pass_i in 3:
		var moved := false
		for b: Rect2 in bigs:
			var r := Rect2(rc.position + Vector2(shift, 0.0), rc.size)
			if not r.grow(DODGE_GAP).intersects(b):
				continue
			var left := b.position.x - DODGE_GAP - r.end.x          # 왼쪽으로 비킬 때 (음수)
			var right := b.end.x + DODGE_GAP - r.position.x         # 오른쪽으로 비킬 때 (양수)
			var to_right := r.get_center().x >= b.get_center().x
			if shift != 0.0:                          # 이미 비키는 중이면 같은 쪽으로 계속
				to_right = shift > 0.0
			shift += right if to_right else left
			moved = true
		if not moved:
			break
	return shift


## 몸통 rc + 머리 p로 뻗은 꼬리 + 그림 (몸통이 옆으로 비켜 있으면 꼬리가 비스듬)
func paint(p: Vector2, rc: Rect2, pic: String, k: float, a: float, t: float) -> void:
	var sz := rc.size
	var bc := rc.get_center()
	var ink := Color(INK, a)
	var cream := Color(CREAM, a)
	var rad := int(minf(sz.x, sz.y) * 0.42)
	_box.bg_color = cream
	_box.border_color = ink
	_box.set_corner_radius_all(rad)
	draw_style_box(_box, rc)
	var ty := rc.end.y - 1.0
	var tw := 3.2 * k
	var tx := clampf(p.x, rc.position.x + float(rad) + tw, rc.end.x - float(rad) - tw)     # 꼬리 뿌리: 몸통 밑변 안에서 머리와 가장 가까운 곳
	var tip := Vector2(p.x, maxf(p.y - GAP, ty + 2.0)) if absf(p.x - tx) > 0.5 else Vector2(tx, ty + TAIL * k + 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - tw, ty), Vector2(tx + tw, ty), tip]), cream)
	draw_polyline(PackedVector2Array([Vector2(tx - tw, ty + 1.0), tip, Vector2(tx + tw, ty + 1.0)]), ink, 1.0, true)
	draw_pic(bc, pic, a, k, t)


## 그림 (가운데 c, 크기 배율 k)
func draw_pic(c: Vector2, pic: String, a: float, k: float, t: float) -> void:
	var ink := Color(INK, a)
	match pic:
		"star":
			var pts := PackedVector2Array()
			var tw := 1.0 + 0.06 * sin(t * 5.0)
			for i in 10:
				var ang := -PI * 0.5 + TAU * float(i) / 10.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * (8.6 if i % 2 == 0 else 3.9) * k * tw)
			draw_colored_polygon(pts, Color(YELLOW, a))
			pts.append(pts[0])
			draw_polyline(pts, ink, 1.0, true)
			for d: Vector2 in [Vector2(-10.5, -6.0), Vector2(10.0, 5.5)]:     # 곁의 작은 반짝임
				var s := (1.3 + 0.5 * sin(t * 6.0 + d.x)) * k
				draw_line(c + d * k - Vector2(s, 0), c + d * k + Vector2(s, 0), Color(YELLOW, a), 1.0, true)
				draw_line(c + d * k - Vector2(0, s), c + d * k + Vector2(0, s), Color(YELLOW, a), 1.0, true)
		"moon":
			var r1 := 8.2 * k
			var r2 := 7.0 * k
			var cut := c + Vector2(3.7, -2.4) * k
			draw_circle(c, r1, Color(MOON, a))
			draw_circle(cut, r2, Color(CREAM, a))
			var d := (cut - c).length()
			var th := acos(clampf((d * d + r1 * r1 - r2 * r2) / (2.0 * d * r1), -1.0, 1.0))
			var ph := acos(clampf((d * d + r2 * r2 - r1 * r1) / (2.0 * d * r2), -1.0, 1.0))
			var a0 := (cut - c).angle()
			draw_arc(c, r1, a0 + th, a0 - th + TAU, 28, ink, 1.0, true)
			draw_arc(cut, r2, a0 + PI - ph, a0 + PI + ph, 22, ink, 1.0, true)
			draw_circle(c + Vector2(8.5, -6.5) * k, 1.0 * k, Color(YELLOW, a))
		"fish":
			var o := c + Vector2(-1.6, 0.4 + 0.5 * sin(t * 3.0)) * k
			var wag := sin(t * 5.0) * 1.3 * k
			var tail := PackedVector2Array([o + Vector2(6.0, 0.0) * k, o + Vector2(12.0 * k, -5.0 * k + wag), o + Vector2(10.4 * k, wag * 0.5), o + Vector2(12.0 * k, 5.0 * k + wag)])
			draw_colored_polygon(tail, Color(BLUE.darkened(0.12), a))
			tail.append(tail[0])
			draw_polyline(tail, ink, 1.0, true)
			var body := PackedVector2Array()
			for i in 20:
				var ang := TAU * float(i) / 20.0
				body.append(o + Vector2(cos(ang) * 8.6, sin(ang) * 5.4) * k)
			draw_colored_polygon(body, Color(BLUE, a))
			body.append(body[0])
			draw_polyline(body, ink, 1.0, true)
			draw_arc(o + Vector2(-0.5, 0.0) * k, 3.6 * k, -0.9, 0.9, 8, Color(BLUE.darkened(0.25), a), 1.0, true)     # 아가미·비늘 한 줄
			draw_circle(o + Vector2(-5.2, -1.4) * k, 1.1 * k, ink)
			draw_arc(o + Vector2(-10.6, -5.2) * k, 1.2 * k, 0.0, TAU, 10, Color(BLUE, a), 1.0, true)     # 뽀글
		"tree":
			var o := c + Vector2(0.0, 0.5) * k
			draw_rect(Rect2(o + Vector2(-2.3, 2.0) * k, Vector2(4.6, 8.0) * k), ink)
			draw_rect(Rect2(o + Vector2(-1.4, 2.0) * k, Vector2(2.8, 7.1) * k), Color(BARK, a))
			var sway := sin(t * 1.8) * 0.5 * k
			var blobs := [Vector2(-4.2, -0.6), Vector2(4.2, -0.6), Vector2(0.0, -5.0), Vector2(0.0, -1.0)]
			for b: Vector2 in blobs:
				draw_circle(o + b * k + Vector2(sway, 0), 5.3 * k, ink)
			for b: Vector2 in blobs:
				draw_circle(o + b * k + Vector2(sway, 0), 4.4 * k, Color(GREEN, a))
			draw_circle(o + Vector2(-2.6, -3.2) * k + Vector2(sway, 0), 1.5 * k, Color(GREEN.lightened(0.25), a))
		"pebble":
			var o := c + Vector2(0.0, 1.0 + 0.5 * sin(t * 4.0)) * k
			var pts := PackedVector2Array()
			for i in 18:
				var ang := TAU * float(i) / 18.0
				pts.append(o + Vector2(cos(ang) * 7.6, sin(ang) * 5.0 * (0.86 if sin(ang) > 0.0 else 1.0)) * k)
			draw_colored_polygon(pts, Color(STONE, a))
			pts.append(pts[0])
			draw_polyline(pts, ink, 1.0, true)
			draw_arc(o + Vector2(-1.5, -0.6) * k, 4.2 * k, PI * 1.05, PI * 1.5, 6, Color(STONE.lightened(0.45), a), 1.2, true)     # 반들반들
			for d: Vector2 in [Vector2(-10.5, -5.0), Vector2(10.5, -3.0)]:     # 톡 — 튀는 금
				draw_line(o + d * k, o + d * k + Vector2(signf(d.x) * 2.2, -2.2) * k, ink, 1.0, true)
		"zzz":
			var col := Color(SLEEP, a)
			var zs := [[Vector2(-5.5, 3.5), 2.2], [Vector2(0.0, -0.5), 2.9], [Vector2(6.0, -4.5), 3.6]]
			for i in zs.size():
				var o: Vector2 = c + (zs[i][0] as Vector2) * k + Vector2(0, sin(t * 3.0 + float(i) * 1.3) * 0.7)
				var h: float = float(zs[i][1]) * k
				draw_polyline(PackedVector2Array([o + Vector2(-h, -h), o + Vector2(h, -h), o + Vector2(-h, h), o + Vector2(h, h)]), col, 1.3, true)
