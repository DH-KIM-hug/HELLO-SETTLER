## 고비 도장 줄 + 다음 고비 한 줄 (docs/PROGRESSION.md 4.5 — 거인 UI라 숫자를 써도 된다).
## 병의 고비 기록(sim/milestones.gd)을 읽기만 한다. 넘은 고비 = 붉은 잉크 도장, 아직 = 흐린 빈 동그라미.
## 쓰는 법: parent.add_child(MilestoneStamps.make(village, true)) — ChronicleSheet 머리(제목과 탭 사이)의 얇은 띠: 어느 탭에서나 보인다
## (2026-11-11 사용자 결정 — '창세 신화' 탭 맨 아래에 있던 것을 올림). compact = false는 큰 도장 + 이름을 아래에 (넓은 자리용).
class_name MilestoneStamps
extends VBoxContainer

const INK := Color("b4463a")                       # 도장 잉크
const FAINT := Color(0.45, 0.35, 0.24, 0.32)       # 아직 못 넘은 자리
const PAPER := Color("fdf6dc")                     # 수첩 종이 (도장 안 흰 줄)
const STAMP := 46.0                                # 도장 한 칸 (px)
const STAMP_SMALL := 30.0                          # 얇은 띠의 도장 한 칸 (px)
const TILT := [-0.10, 0.07, -0.05, 0.11]           # 손으로 찍은 듯한 기울기


static func make(v: Village, compact := false) -> MilestoneStamps:
	var m := MilestoneStamps.new()
	m.name = "MilestoneStamps"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("separation", 1 if compact else 2)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2 if compact else 4)
	m.add_child(row)
	var i := 0
	for s: Dictionary in Milestones.stamps(v):
		var cell: BoxContainer = HBoxContainer.new() if compact else VBoxContainer.new()     # 얇은 띠: 도장 옆에 이름 (한 줄)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if compact:
			cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 3 if compact else 0)
		row.add_child(cell)
		var st := Stamp.new()
		st.id = String(s["id"])
		st.passed = bool(s["passed"])
		st.tilt = float(TILT[i % TILT.size()])
		st.name = "Stamp_" + st.id
		if compact:
			st.custom_minimum_size = Vector2(STAMP_SMALL, STAMP_SMALL)
			st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(st)
		var l := Label.new()
		l.text = String(s["label"])
		l.theme_type_variation = "Small"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_color", UiTheme.INK_BROWN if st.passed else UiTheme.INK_BROWN.lightened(0.45))
		if compact:
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(l)
		i += 1
	if not compact:
		var gap := Control.new()                      # 도장 이름과 다음 고비 줄 사이 (손글씨는 윗자리가 좁아 붙어 보인다)
		gap.custom_minimum_size.y = 7
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(gap)
	var nx := Label.new()
	nx.name = "Next"
	nx.text = Milestones.next_line(v)
	nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nx.add_theme_font_override("font", UiTheme.hand_font())
	nx.add_theme_font_size_override("font_size", UiTheme.SIZE_HAND_SMALL)
	nx.add_theme_color_override("font_color", UiTheme.INK_BROWN)
	if compact:
		nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nx.add_theme_constant_override("line_spacing", -2)
	m.add_child(nx)
	if not compact:
		var rule := ColorRect.new()
		rule.color = UiTheme.PARCHMENT_EDGE
		rule.color.a = 0.55
		rule.custom_minimum_size = Vector2(0, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(rule)
	return m


## 도장 하나 — 살짝 기울인 동그라미 + 작은 그림
class Stamp extends Control:
	var id := ""
	var passed := false
	var tilt := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(MilestoneStamps.STAMP, MilestoneStamps.STAMP)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5 - (3.0 if size.y >= MilestoneStamps.STAMP else 2.0)
		if not passed:
			for k in 12:                                # 점선 동그라미 (빈 자리)
				var a := TAU * float(k) / 12.0
				draw_arc(c, rad, a, a + TAU / 24.0, 6, MilestoneStamps.FAINT, 1.5, true)
			return
		draw_set_transform(c, tilt, Vector2.ONE)
		var ink := MilestoneStamps.INK
		ink.a = 0.9
		var paper := MilestoneStamps.PAPER
		var s := rad / 20.0
		var w := clampf(s, 0.62, 1.0)                 # 작은 도장(얇은 띠)에서는 줄도 가늘게
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 40, ink, 2.5 * w, true)
		if s >= 0.8:
			draw_arc(Vector2.ZERO, rad - 4.0, 0.0, TAU, 40, Color(ink, 0.55), 1.0, true)
		match id:
			"bread":                                    # 둥근 빵 + 칼집 셋
				var pts := PackedVector2Array()
				for k in 17:
					var a := PI + PI * float(k) / 16.0
					pts.append(Vector2(cos(a) * 11.0, sin(a) * 8.5 + 3.0) * s)
				pts.append(Vector2(11.0, 6.0) * s)
				pts.append(Vector2(-11.0, 6.0) * s)
				draw_colored_polygon(pts, ink)
				for k in 3:
					var x := (-5.0 + 5.0 * float(k)) * s
					draw_line(Vector2(x - 1.5 * s, -3.5 * s), Vector2(x + 1.5 * s, 0.5 * s), paper, 1.6 * w, true)
			"pop12":                                    # 표지판 (기둥 + 판)
				draw_line(Vector2(0.0, -2.0) * s, Vector2(0.0, 11.0) * s, ink, 2.6 * w, true)
				draw_rect(Rect2(Vector2(-10.0, -10.0) * s, Vector2(20.0, 9.0) * s), ink)
				draw_line(Vector2(-6.0, -5.5) * s, Vector2(6.0, -5.5) * s, paper, 1.5 * w, true)
			"winter":                                   # 눈꽃
				for k in 3:
					var a := PI / 2.0 + PI * float(k) / 3.0
					var d := Vector2(cos(a), sin(a))
					draw_line(-d * 11.0 * s, d * 11.0 * s, ink, 2.2 * w, true)
					for sg: float in [-1.0, 1.0]:
						var tip := d * 7.0 * s * sg
						draw_line(tip, tip + d.rotated(0.9) * 3.5 * s * sg, ink, 1.6 * w, true)
						draw_line(tip, tip + d.rotated(-0.9) * 3.5 * s * sg, ink, 1.6 * w, true)
			"pop20":                                    # 지붕 둘 (북적이는 마을)
				for ox: float in [-6.0, 6.0]:
					var o := Vector2(ox, 1.0 if ox < 0.0 else -1.0) * s
					draw_colored_polygon(PackedVector2Array([o + Vector2(-6.5, 0.0) * s, o + Vector2(0.0, -7.0) * s, o + Vector2(6.5, 0.0) * s]), ink)
					draw_rect(Rect2(o + Vector2(-4.5, 0.0) * s, Vector2(9.0, 8.0) * s), ink)
					draw_rect(Rect2(o + Vector2(-1.2, 3.5) * s, Vector2(2.4, 4.5) * s), paper)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
