## 가계도용 작은 얼굴 — 3D 초상 대신 2D로 (피부 톤·머리색·머리결·대머리·흰머리·점박이, 보이는 것만). 잠든 사람은 회색.
## 그림 초상 층(PortraitComposer)이 다 있으면 그 그림의 머리 부분을 보이고, 없으면 아래 간단한 그림.
class_name FaceIcon
extends Control

const HEAD_VIEW := Rect2(0.13, 0.1, 0.74, 0.74)    # 그림 초상에서 머리·어깨 위
var paper: PortraitView

var skin := Color("e6b88b")
var hair := Color("5b3b29")
var eye := Color("4a2c1c")
var bald := 0
var curl := 0
var long_hair := false
var piebald := false
var empty := false          # 모르는 사람 (빈 얼굴)


func _init() -> void:
	custom_minimum_size = Vector2(UiTheme.FACE_PX, UiTheme.FACE_PX)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_resident(r: Resident) -> void:
	empty = r == null
	var ls: Array = PortraitComposer.layers_for(r) if r != null else []
	if not ls.is_empty():
		if paper == null:
			paper = PortraitView.new()
			paper.view = HEAD_VIEW
			paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(paper)
		paper.set_layers(ls)
	if paper != null:
		paper.visible = not ls.is_empty()
	if r != null and r.genes.size() >= Genetics.MIN_BYTES:
		var g := r.genes
		var tones := ResidentModel.tones_of(ResidentModel.look_of(r))     # (A23) 피부·머리 8단계 · 점 눈 하나
		skin = tones["skin"]
		hair = tones["hair"]
		eye = Style.EYE_DOT
		bald = Genetics.bald_stage(g, r.sex, r.age)
		curl = Genetics.curl(g)
		piebald = Genetics.piebald(g)
		long_hair = r.sex == "f"
	queue_redraw()


func _draw() -> void:
	var s := size
	var c := s * 0.5 + Vector2(0, 1)
	var rad := minf(s.x, s.y) * 0.4
	var line := UiTheme.INK
	if paper != null and paper.visible:
		draw_rect(Rect2(Vector2.ZERO, s), UiTheme.PORTRAIT_BG)
		return
	if empty:
		draw_arc(c, rad, 0, TAU, 20, UiTheme.PAPER_LINE, 1.0)
		return
	if long_hair and bald == 0:
		draw_rect(Rect2(c.x - rad * 1.05, c.y - rad * 0.3, rad * 2.1, rad * 1.25), hair)
	draw_circle(c, rad, skin)
	if piebald:
		draw_circle(c + Vector2(rad * 0.35, rad * 0.25), rad * 0.32, Color(Genetics.PIEBALD_SKIN))
	# 머리카락 (위쪽 반달) — 대머리 단계만큼 정수리를 비움
	if bald < 2:
		var pts := PackedVector2Array()
		var a0 := PI + 0.15
		var a1 := TAU - 0.15
		var n := 12
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			var rr := rad * (1.12 + (0.08 * sin(i * 2.3) if curl > 0 else 0.0))
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		for i in n + 1:
			var a := lerpf(a1, a0, float(i) / n)
			pts.append(c + Vector2(cos(a) * rad * 0.95, sin(a) * rad * 0.35 - rad * 0.12))
		draw_colored_polygon(pts, hair)
		if bald == 1:
			draw_circle(c - Vector2(0, rad * 0.78), rad * 0.32, skin)
	draw_arc(c, rad, 0, TAU, 24, line, 1.0)
	draw_rect(Rect2(c.x - rad * 0.4, c.y + rad * 0.12, 2, 2), eye)
	draw_rect(Rect2(c.x + rad * 0.4 - 2, c.y + rad * 0.12, 2, 2), eye)
