## 말풍선 곁의 작은 그림 (마을의 삶 — view/social_stage.gd): 사랑 = 하트 · 화남 = 성난 표시 · 노래 = 음표 · 환호 = 반짝 · 시무룩 = 땀방울.
## 글꼴에 없는 기호를 쓰지 않으려고 직접 그린다 (휴대폰 글꼴에 ♥ ♪가 없을 수 있음).
class_name SocialEmote
extends Control

const KINDS := ["love", "angry", "song", "cheer", "sad"]
var kind := "love"


func _init() -> void:
	size = Vector2(14, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ink := Color("252122")
	match kind:
		"love":
			var c := Color("e2557a")
			var pts := PackedVector2Array()
			for i in 24:
				var t := TAU * float(i) / 24.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(Vector2(7.0 + x * 0.42, 7.0 + y * 0.42))
			draw_colored_polygon(pts, c)
			draw_polyline(pts + PackedVector2Array([pts[0]]), ink, 1.0, true)
		"angry":                       # 네 갈래 성난 표시
			var c := Color("d23a22")
			for k in 4:
				var a := PI * 0.25 + k * PI * 0.5
				var d := Vector2(cos(a), sin(a))
				var e := Vector2(-d.y, d.x)
				var o := Vector2(7, 7) + d * 2.0
				draw_polyline(PackedVector2Array([o + e * 2.5, o + d * 3.5, o - e * 2.5]), c, 2.0, true)
		"song":
			var c := Color("3d6fb0")
			draw_circle(Vector2(4, 11), 2.6, c)
			draw_circle(Vector2(11, 9), 2.6, c)
			draw_line(Vector2(6.4, 11), Vector2(6.4, 2.5), c, 1.6)
			draw_line(Vector2(13.4, 9), Vector2(13.4, 0.5), c, 1.6)
			draw_line(Vector2(6.4, 2.5), Vector2(13.4, 0.5), c, 2.2)
		"cheer":
			var c := Color("e0a21c")
			var pts := PackedVector2Array()
			for i in 8:
				var a := TAU * float(i) / 8.0 - PI * 0.5
				var rr := 6.5 if i % 2 == 0 else 2.4
				pts.append(Vector2(7, 7) + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, c)
		"sad":
			var c := Color("7fb2e0")
			var pts := PackedVector2Array([Vector2(7, 1)])
			for i in 13:
				var a := PI * float(i) / 12.0
				pts.append(Vector2(7, 9) + Vector2(cos(a), sin(a)) * 3.6)
			draw_colored_polygon(pts, c)
