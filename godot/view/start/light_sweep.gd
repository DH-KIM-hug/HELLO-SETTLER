## 유리를 통과하는 빛 (UI.md 00 #4 · GIANT_ROOM 4) — 비스듬한 반사광 띠가 화면을 쓸고 지나가고(sweep 0→1), 끝에 빛으로 덮임(fade).
class_name LightSweep
extends Control

var sweep := 0.0
var fade := 0.0
var tint := Color(1.0, 0.98, 0.93)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if sweep > 0.0 and sweep < 1.0:
		var cx := lerpf(-0.7 * w, 1.7 * w, sweep)
		var skew := h * 0.45
		for band: Array in [[w * 0.42, 0.18], [w * 0.20, 0.35], [w * 0.06, 0.55]]:
			var bw: float = band[0]
			var a: float = band[1] * sin(sweep * PI)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - bw * 0.5 + skew, 0), Vector2(cx + bw * 0.5 + skew, 0),
				Vector2(cx + bw * 0.5 - skew, h), Vector2(cx - bw * 0.5 - skew, h)]), Color(1, 1, 1, a))
	if fade > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(tint, fade))
