## 고비 도장 줄 + 다음 고비 한 줄 (docs/PROGRESSION.md 4.5 — 거인 UI라 숫자를 써도 된다).
## 병의 고비 기록(sim/milestones.gd)을 읽기만 한다. 넘은 고비 = 붉은 잉크 도장, 아직 = 흐린 빈 동그라미.
## 쓰는 법: parent.add_child(MilestoneStamps.make(village, true)) — ChronicleSheet 머리(제목과 탭 사이)의 얇은 띠: 어느 탭에서나 보인다
## (2026-11-11 메인 판단, 사용자 위임 — '창세 신화' 탭 맨 아래에 있던 것을 올림). compact = false는 큰 도장 (넓은 자리용).
## 도장 여섯 (Q9 ⑦ 2026-11-11 — 첫걸음마 · 첫 어른이 늘어): 얇은 띠도 도장 아래에 이름 — 옆에 쓰면 540 px에 여섯이 안 들어간다.
## 넘는 차례(Milestones.ORDER)대로 왼쪽부터, 도장 사이는 가는 점선으로 잇고, 다음 고비 자리는 점선 동그라미를 조금 진하게.
## 도장 일곱 (Q9 ⑭ 2026-11-11 — 첫 푸른 밀 고개 '첫 고개'가 늘어): 일곱까지는 같은 크기로 한 줄에 들어간다 (540 px 화면 — 한 칸에 이름 한 줄).
## 일곱을 넘으면(여덟까지 봄) 도장과 글씨를 한 단계 줄인다 (MANY).
## 도장 열하나 (Q27 2026-11-13 — 일터 스물 · 첫 돌집 · 삼대 · 큰 마을이 늘어): 열하나는 540 px 화면의 얇은 띠에 한 줄로 들어가지 않는다
##   (이름이 서로 붙고 띠가 화면 밖으로 밀림 — 캡처로 확인). 얇은 띠는 일곱 칸 창(SHOW)만 보인다: 다음 고비가 가운데쯤 오게 (앞쪽 셋 · 다음 · 뒤쪽 셋,
##   양 끝에서는 끝에 붙임). 창 밖 앞쪽 도장은 첫 칸의 점선 꼬리로 이어짐만 보인다. 큰 도장 줄(넓은 자리용)은 모두 — 한 단계 작게.
class_name MilestoneStamps
extends VBoxContainer

const INK := Color("b4463a")                       # 도장 잉크
const FAINT := Color(0.45, 0.35, 0.24, 0.32)       # 아직 못 넘은 자리
const PAPER := Color("fdf6dc")                     # 수첩 종이 (도장 안 흰 줄)
const STAMP := 46.0                                # 도장 한 칸 (px)
const STAMP_SMALL := 30.0                          # 얇은 띠의 도장 한 칸 (px)
const STAMP_TINY := 28.0                           # 도장이 MANY를 넘을 때 얇은 띠의 한 칸
const STAMP_MANY := 40.0                           # (Q27) 도장이 MANY를 넘을 때 큰 도장 줄의 한 칸
const STAMP_CROWD := 36.0                          # (Q31) 큰 도장 줄이 CROWD를 넘을 때 (열둘 — 500 px 안)
const CROWD := 11
const SHOW := 7                                    # (Q27) 얇은 띠에 한 번에 보이는 도장 수 (다음 고비 둘레의 창)
const MANY := 7                                    # 이보다 많으면 한 단계 작게
const LABEL_TINY := 11                             # 그때의 이름 글씨 (px) — (Q23 ㊿) 가장 작은 글 11 (예전 10)
const NEXT_RING := Color(0.45, 0.35, 0.24, 0.62)   # 다음 고비 자리의 점선 동그라미
const TILT := [-0.10, 0.07, -0.05, 0.11, -0.08, 0.05, 0.09, -0.06]     # 손으로 찍은 듯한 기울기


static func make(v: Village, compact := false) -> MilestoneStamps:
	return build(Milestones.stamps(v), Milestones.next_line(v), compact)


## 도장 목록([{id, label, passed}] — 넘는 차례대로)과 다음 고비 한 줄로 띠를 만든다 (make가 부름 · 시험은 여덟 개짜리도 넣어 본다)
static func build(all: Array, next_text: String, compact := false) -> MilestoneStamps:
	var m := MilestoneStamps.new()
	m.name = "MilestoneStamps"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("separation", 0 if compact else 2)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2 if compact or all.size() > CROWD else 4)
	m.add_child(row)
	var from := 0
	var upto := all.size()
	if compact and all.size() > SHOW:                 # (Q27) 다음 고비 둘레 일곱 칸만
		var nx := all.size() - 1
		for k in all.size():
			if not bool((all[k] as Dictionary)["passed"]):
				nx = k
				break
		from = clampi(nx - SHOW / 2, 0, all.size() - SHOW)
		upto = from + SHOW
	var many := (upto - from) > MANY
	var next_found := false
	var i := 0
	for s: Dictionary in all:
		if i < from or i >= upto:
			next_found = next_found or not bool(s["passed"])
			i += 1
			continue
		var cell := VBoxContainer.new()               # 도장 아래에 이름 (얇은 띠도 — 여섯이 한 줄에 들어가게)
		cell.name = "Cell_" + String(s["id"])
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", -3 if compact else 0)
		row.add_child(cell)
		var st := Stamp.new()
		st.id = String(s["id"])
		st.passed = bool(s["passed"])
		st.next = not st.passed and not next_found
		next_found = next_found or not st.passed
		st.link = i > 0
		st.tilt = float(TILT[i % TILT.size()])
		st.name = "Stamp_" + st.id
		if compact:
			var px := STAMP_TINY if many else STAMP_SMALL
			st.custom_minimum_size = Vector2(px, px)
		elif many:                                    # (Q27) 큰 도장 줄도 열이면 한 단계 작게 (500 px 안) · (Q31) 열둘이면 한 단계 더
			var bx := STAMP_CROWD if (upto - from) > CROWD else STAMP_MANY
			st.custom_minimum_size = Vector2(bx, bx)
		cell.add_child(st)
		var l := Label.new()
		l.text = String(s["label"])
		l.theme_type_variation = "Small"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_color", UiTheme.INK_BROWN if st.passed else (UiTheme.INK_BROWN_SOFT if st.next else UiTheme.INK_BROWN_FAINT))     # (Q23 ㊿) 빈 도장 이름도 3:1
		if many:
			l.add_theme_font_size_override("font_size", LABEL_TINY)
		cell.add_child(l)
		i += 1
	if not compact:
		var gap := Control.new()                      # 도장 이름과 다음 고비 줄 사이 (손글씨는 윗자리가 좁아 붙어 보인다)
		gap.custom_minimum_size.y = 7
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(gap)
	var nx := Label.new()
	nx.name = "Next"
	nx.text = next_text
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
	var next := false                 # 다음에 넘을 고비 (점선 동그라미를 조금 진하게)
	var link := false                 # 앞 도장과 가는 점선으로 잇는다 (넘는 차례가 읽히게)
	var tilt := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(MilestoneStamps.STAMP, MilestoneStamps.STAMP)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5 - (3.0 if size.y >= MilestoneStamps.STAMP else 2.0)
		if link:                                        # 앞 도장 쪽으로 가는 점 셋 (칸 사이)
			var gap := (get_parent() as Control).size.x * 0.5 - rad - 3.0 if get_parent() is Control else 0.0
			for k in 3:
				var x := c.x - rad - 3.0 - gap * 2.0 * (float(k) + 0.5) / 3.0
				draw_circle(Vector2(x, c.y), 1.0, MilestoneStamps.FAINT)
		if not passed:
			for k in 12:                                # 점선 동그라미 (빈 자리)
				var a := TAU * float(k) / 12.0
				draw_arc(c, rad, a, a + TAU / 24.0, 6, MilestoneStamps.NEXT_RING if next else MilestoneStamps.FAINT, 1.8 if next else 1.5, true)
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
			"steps":                                    # 바람개비 (날개 넷 + 대)
				draw_line(Vector2(0.0, -2.0) * s, Vector2(0.0, 12.0) * s, ink, 2.0 * w, true)
				for k in 4:
					var a := TAU * float(k) / 4.0 - 0.35
					var o := Vector2(0.0, -3.0) * s
					var tip := o + Vector2(cos(a), sin(a)) * 9.5 * s
					var wing := o + Vector2(cos(a + 1.05), sin(a + 1.05)) * 6.0 * s
					draw_colored_polygon(PackedVector2Array([o, tip, wing]), ink)
				draw_circle(Vector2(0.0, -3.0) * s, 1.7 * s, paper)
			"grown":                                    # 키 재는 기둥 (눈금 셋) + 곁에 선 아이
				draw_line(Vector2(3.5, -11.0) * s, Vector2(3.5, 11.0) * s, ink, 3.4 * w, true)
				for k in 3:
					var y := (-7.0 + 6.0 * float(k)) * s
					draw_line(Vector2(3.5, y / s) * s, Vector2(9.5 - float(k), y / s) * s, ink, 1.8 * w, true)
				draw_circle(Vector2(-5.0, -2.5) * s, 3.0 * s, ink)
				draw_colored_polygon(PackedVector2Array([Vector2(-8.5, 11.0) * s, Vector2(-5.0, 1.0) * s, Vector2(-1.5, 11.0) * s]), ink)
			"green":                                    # 햇밀 이삭 (대 + 낟알 네 쌍 + 끝 낟알)
				draw_line(Vector2(0.0, 12.0) * s, Vector2(0.0, -8.0) * s, ink, 1.8 * w, true)
				for k in 4:
					var y := -6.0 + 4.2 * float(k)
					for sg: float in [-1.0, 1.0]:
						draw_line(Vector2(0.8 * sg, y + 2.4) * s, Vector2(5.6 * sg, y - 2.6) * s, ink, 3.0 * w, true)
				draw_line(Vector2(0.0, -8.0) * s, Vector2(0.0, -12.5) * s, ink, 3.0 * w, true)
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
			"gen3":                                     # (Q27) 삼대 — 키가 다른 세 사람이 나란히 (어른 · 어른 · 아이)
				for f: Vector3 in [Vector3(-7.0, -6.0, 1.0), Vector3(0.5, -4.0, 0.92), Vector3(7.5, 1.5, 0.7)]:
					var o := Vector2(f.x, f.y) * s
					draw_circle(o, 2.8 * f.z * s, ink)
					draw_colored_polygon(PackedVector2Array([o + Vector2(-3.6 * f.z, 13.0 - f.y) * s, o + Vector2(0.0, 2.6 * f.z) * s,
						o + Vector2(3.6 * f.z, 13.0 - f.y) * s]), ink)
			"work20":                                   # (Q27) 일터 스물 — 망치 (머리 + 자루)
				draw_set_transform(c, tilt + 0.6, Vector2.ONE)
				draw_line(Vector2(0.0, -4.0) * s, Vector2(0.0, 12.0) * s, ink, 2.6 * w, true)
				draw_rect(Rect2(Vector2(-8.5, -10.5) * s, Vector2(17.0, 7.5) * s), ink)
				draw_line(Vector2(-5.5, -7.0) * s, Vector2(5.5, -7.0) * s, paper, 1.3 * w, true)
			"pop35":                                    # (Q27) 큰 마을 — 지붕 셋 (식구 스물의 지붕 둘에 하나 더, 가운데가 높게)
				for f: Vector3 in [Vector3(-8.0, 3.0, 0.8), Vector3(8.0, 3.0, 0.8), Vector3(0.0, -1.5, 1.0)]:
					var o := Vector2(f.x, f.y) * s
					var k := f.z
					draw_colored_polygon(PackedVector2Array([o + Vector2(-5.5, 0.0) * k * s, o + Vector2(0.0, -6.0) * k * s, o + Vector2(5.5, 0.0) * k * s]), ink)
					draw_rect(Rect2(o + Vector2(-4.0, 0.0) * k * s, Vector2(8.0, 7.0) * k * s), ink)
					draw_rect(Rect2(o + Vector2(-1.1, 3.0) * k * s, Vector2(2.2, 4.0) * k * s), paper)
			"stone":                                    # (Q27) 첫 돌집 — 지붕 + 돌 쌓은 벽(가로 줄 둘 · 엇갈린 이음) + 문
				draw_colored_polygon(PackedVector2Array([Vector2(-11.0, -1.5) * s, Vector2(0.0, -11.5) * s, Vector2(11.0, -1.5) * s]), ink)
				draw_rect(Rect2(Vector2(-8.5, -1.5) * s, Vector2(17.0, 12.0) * s), ink)
				for y: float in [2.5, 6.5]:
					draw_line(Vector2(-8.0, y) * s, Vector2(8.0, y) * s, paper, 1.0 * w, true)
				for e: Vector2 in [Vector2(-4.5, -1.5), Vector2(4.5, -1.5), Vector2(-6.5, 2.5), Vector2(6.5, 2.5), Vector2(-4.5, 6.5), Vector2(4.5, 6.5)]:
					draw_line(e * s, (e + Vector2(0.0, 4.0)) * s, paper, 1.0 * w, true)
				draw_rect(Rect2(Vector2(-2.2, 3.5) * s, Vector2(4.4, 7.0) * s), paper)
			"names":                                    # (Q31) 첫 이름 부르기 — 벚꽃 한 송이 (꽃잎 다섯 · 끝이 살짝 갈라짐) + 떨어지는 꽃잎 하나
				var o := Vector2(-1.5, -1.5) * s
				for k in 5:
					var a := -PI / 2.0 + TAU * float(k) / 5.0
					var d := Vector2(cos(a), sin(a))
					draw_circle(o + d * 5.6 * s, 4.4 * s, ink)
					draw_line(o + d * 8.2 * s, o + d * 10.2 * s, paper, 1.1 * w, true)     # 꽃잎 끝의 작은 홈
				draw_circle(o, 2.4 * s, paper)
				draw_circle(o, 1.1 * s, ink)
				var pp := Vector2(9.0, 9.5) * s
				draw_colored_polygon(PackedVector2Array([pp + Vector2(0.0, -3.2) * s, pp + Vector2(2.4, 0.0) * s, pp + Vector2(0.0, 3.2) * s,
					pp + Vector2(-2.4, 0.0) * s]), ink)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
