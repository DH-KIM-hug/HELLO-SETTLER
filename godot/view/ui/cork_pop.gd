## 뚜껑이 저절로 열리고 닫히는 짧은 연출 (v3.3 — 뚜껑은 거인의 손짓마다 저절로, 따로 누르는 단추 없음).
## 화면 맨 위 가운데 (위 띠 바로 아래)에 코르크가 '퐁' 튀어 올랐다가 (열림) / 내려앉음 (닫힘). 0.6초.
class_name CorkPop
extends Control

const DUR := 0.6

var _t := -1.0
var _open := true
var top_y := 60.0


func _init() -> void:
	name = "CorkPop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func play(open: bool) -> void:
	_open = open
	_t = 0.0


func _process(dt: float) -> void:
	if _t < 0.0:
		return
	_t += dt
	if _t > DUR + 0.25:
		_t = -1.0
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var u := clampf(_t / DUR, 0.0, 1.0)
	var h := sin(u * PI) * 26.0 if _open else (1.0 - u) * 26.0
	var a := 1.0 - clampf((_t - DUR) / 0.25, 0.0, 1.0)
	var c := Vector2(size.x * 0.5, top_y + 14.0 - h)
	var cork := Color("b98d55", a)
	var rim := Color("7a5a35", a)
	draw_rect(Rect2(c + Vector2(-13, -9), Vector2(26, 18)), cork)
	draw_rect(Rect2(c + Vector2(-13, -9), Vector2(26, 18)), rim, false, 1.5)
	draw_line(c + Vector2(-8, -3), c + Vector2(8, -3), Color(rim, a * 0.5), 1.0)
	if _open:                                          # 퐁 — 작은 바람 줄기
		for i in 3:
			var x := -18.0 + 18.0 * i
			draw_line(Vector2(c.x + x, top_y + 30.0), Vector2(c.x + x * 1.4, top_y + 16.0 - h * 0.6), Color(1, 1, 1, 0.6 * a * (1.0 - u)), 2.0)
