## 가계도용 작은 얼굴 — 3D 초상 대신 2D로 (피부 톤·머리색·머리결·대머리·흰머리·점박이, 보이는 것만). 잠든 사람은 회색.
class_name FaceIcon
extends Control

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
	if r != null and r.genes.size() >= Genetics.GENE_BYTES:
		var g := r.genes
		var cues := Bloodlines.looks(r.blood)
		var st := Genetics.skin_step(g)
		if "tanned" in cues:
			st = mini(st + 2, Genetics.SKIN_TONES.size() - 1)
		skin = Color(Genetics.SKIN_TONES[st])
		hair = Genetics.hair_color(g, r.age, "silver_early" in cues)
		eye = Color(Genetics.EYE_COLORS[Genetics.eye(g)])
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
