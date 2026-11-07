## 그림 초상 2차 (A20 2차, 2026-11-07) — 겹쳐 그리는 그림 조각을 코드로 그린다 (SVG 조각 · 바깥 그림 없음).
## 모든 조각은 같은 256 × 256 틀 (머리 + 어깨, 정면). 셀 채색: 짙은 갈색 외곽선 + 평면 색 + 오른쪽 아래 그늘 한 단계 (빛은 왼쪽 위).
## 조각 하나 = SVG <g> 문자열. PortraitComposer가 이 사람의 겉모습(유전자 · 나이 · 직업 옷 · 시대 · 표정)으로 골라 순서대로 쌓고,
## PortraitView가 한 장으로 그린다 (Image.load_svg_from_string).
## 원칙: 생김새만 그린다 (능력·특징과 무관) · 특정 작품의 인물을 따라 하지 않는다 · 점 눈에 가까운 작은 눈 + 하이라이트.
class_name PortraitArt
extends RefCounted

const INK := "#4a3426"            # 외곽선 (짙은 갈색 — 3D 외곽선과 같은 느낌)
const LINE := 2.6
const CX := 128.0
const SHIRT := "#eadfc6"          # 크림색 속옷 (3D LOOK_FIXED shirt)
const APRON := "#ece4d2"
const BELT := "#533727"
const MOUTH := "#9b5446"
const TONGUE := "#e58a7c"
const SEED := "#8a5a35"
const SEED_HI := "#c08a55"
const STRAW := "#deab43"
const STRAW_D := "#a6974b"
const SASH := "#b8453a"
const BAKER := "#f4f0e6"
const ACORN := ["#9b6b3d", "#7a5230", "#5e3f25", "#4d331e"]
const FLOWER := {"acc_flower": ["#f3a6b9", "#f6d35b"], "acc_flower_w": ["#f7f2e8", "#f2c14e"], "acc_flower_y": ["#f6c945", "#e0782f"]}

## 얼굴형 4종: [볼 반폭 W, 턱 반폭 J, 턱 끝 y C, 턱 둥글기, 볼 높이 M 보정]
const FACE := [[61.0, 47.0, 172.0, 19.0, 0.0], [55.0, 40.0, 180.0, 13.0, 2.0], [64.0, 54.0, 170.0, 25.0, -1.0], [60.0, 34.0, 178.0, 7.0, -2.0]]

static var _uid := 0


# ───────────────────────── 작은 도구 ─────────────────────────
static func f(x: float) -> String:
	return "%.1f" % x


static func hx(c: Color) -> String:
	return "#" + c.to_html(false)


## 그늘 색 (차가운 푸른 그늘 쪽으로 — 3D shade_tint와 비슷하게, 따뜻함을 조금 남김)
static func shade(c: Color, k := 1.0) -> Color:
	var s := Color(c.r * 0.8, c.g * 0.82, c.b * 0.9)
	return c.lerp(s.darkened(0.04), k)


static func light(c: Color, k := 0.25) -> Color:
	return c.lerp(Color(1, 0.98, 0.92), k)


static func _id(p: String) -> String:
	_uid += 1
	return "%s%d" % [p, _uid]


static func pt(p: Vector2) -> String:
	return f(p.x) + "," + f(p.y)


## 점들을 지나는 부드러운 곡선 (Catmull-Rom → 3차 베지어). closed면 닫힌 모양. move = M으로 시작 (아니면 L로 이어 붙임)
static func chain(pts: PackedVector2Array, closed := false, move := true) -> String:
	var n := pts.size()
	if n == 0:
		return ""
	var s := ("M" if move else "L") + pt(pts[0])
	var last := n if closed else n - 1
	for i in last:
		var p0 := pts[(i - 1 + n) % n] if (closed or i > 0) else pts[0]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n] if (closed or i + 2 < n) else pts[n - 1]
		var c1 := p1 + (p2 - p0) / 6.0
		var c2 := p2 - (p3 - p1) / 6.0
		s += " C" + pt(c1) + " " + pt(c2) + " " + pt(p2)
	if closed:
		s += " Z"
	return s


static func mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(2.0 * CX - pts[i].x, pts[i].y))
	return out


## 오른쪽 반쪽 점(위 → 아래) → 왼쪽까지 이어 닫힌 좌우 대칭 모양 (위 가운데에서 시작)
static func sym(half: PackedVector2Array) -> PackedVector2Array:
	var out := half.duplicate()
	var m := mirror(half)
	for i in m.size():
		var q := m[i]
		if absf(q.x - CX) < 0.01 and (i == 0 or i == m.size() - 1):
			continue
		out.append(q)
	return out


static func ell(cx: float, cy: float, rx: float, ry: float, fill: String, extra := "") -> String:
	return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s/>' % [f(cx), f(cy), f(rx), f(ry), fill, extra]


static func path(d: String, fill: String, extra := "") -> String:
	return '<path d="%s" fill="%s"%s/>' % [d, fill, extra]


static func stroke(d: String, col := INK, w := LINE, extra := "") -> String:
	return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>' % [d, col, f(w), extra]


static func outline() -> String:
	return ' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % [INK, f(LINE)]


## 셀 채색 모양 하나: 색 → 그늘(모양 안으로 잘림, shade_d = 그늘 모양) → 외곽선
static func cel(d: String, col: Color, shade_d := "", shade_col: Variant = null, inner := "") -> String:
	var s := path(d, hx(col))
	if shade_d != "" or inner != "":
		var id := _id("c")
		s += '<clipPath id="%s"><path d="%s"/></clipPath><g clip-path="url(#%s)">' % [id, d, id]
		if shade_d != "":
			s += path(shade_d, hx(shade_col if shade_col is Color else shade(col)))
		s += inner + "</g>"
	s += stroke(d)
	return s


## 그늘 모양: 왼쪽 위에서 빛 — (cx, cy) 둘레 타원의 바깥 = 그늘 (짝수-홀수 칠하기)
static func shade_out(cx: float, cy: float, rx: float, ry: float) -> String:
	return "M-20,-20 H280 V280 H-20 Z M%s,%s a%s,%s 0 1,0 %s,0 a%s,%s 0 1,0 %s,0 Z" % [f(cx - rx), f(cy), f(rx), f(ry), f(2 * rx), f(rx), f(ry), f(-2 * rx)]


static func g(body: String, extra := "") -> String:
	return "<g%s>%s</g>" % [extra, body]


# ───────────────────────── 머리 틀 (얼굴형 · 나이) ─────────────────────────
## 머리 틀: {T 정수리, M 볼 높이, C 턱, W 볼 반폭, J 턱 반폭, R 턱 둥글기, E 눈 높이, child, baby, elder}
static func frame(shape: int, age: float) -> Dictionary:
	var fs: Array = FACE[clampi(shape, 0, FACE.size() - 1)]
	var child := age < Balance.AGE_ADULT
	var baby := age < Balance.AGE_BABY
	var w: float = fs[0]
	var j: float = fs[1]
	var c: float = fs[2]
	var t := 46.0
	var m := 118.0 + float(fs[4])
	if child:                                  # 아이: 둥글고 큰 머리 · 짧은 턱 (얼굴형은 조금만)
		w = lerpf(64.0, w + 4.0, 0.4)
		j = lerpf(50.0, j + 6.0, 0.4)
		c = lerpf(174.0, c, 0.35)
		t = 50.0
		m = 126.0
	if baby:
		w = 54.0
		j = 44.0
		c = 172.0
		t = 76.0
		m = 136.0
	var e := m + (6.0 if child else 2.0)
	return {"T": t, "M": m, "C": c, "W": w, "J": j, "R": float(fs[3]) * (1.4 if child else 1.0), "E": e,
		"child": child, "baby": baby, "elder": age >= Balance.AGE_ELDER}


static func head_path(fr: Dictionary) -> String:
	var t: float = fr["T"]
	var m: float = fr["M"]
	var c: float = fr["C"]
	var w: float = fr["W"]
	var j: float = fr["J"]
	var r: float = fr["R"]
	var half := PackedVector2Array([Vector2(CX, t), Vector2(CX + w * 0.72, t + (m - t) * 0.18), Vector2(CX + w * 0.97, t + (m - t) * 0.62),
		Vector2(CX + w, m + 4.0), Vector2(CX + j, c - (c - m) * 0.36), Vector2(CX + r, c - 3.0), Vector2(CX, c)])
	return chain(sym(half), true)


# ───────────────────────── 몸 · 옷 ─────────────────────────
## 어깨 반폭 · 어깨 높이
static func body_frame(fr: Dictionary, sx: float) -> Dictionary:
	var child: bool = fr["child"]
	var s := (60.0 if child else 76.0) * sx
	var top := (minf(float(fr["C"]) + 22.0, 202.0) if child else minf(float(fr["C"]) + 20.0, 198.0))
	return {"S": s, "Y": top}


static func torso_path(bf: Dictionary, inset := 0.0, neck := 26.0) -> String:
	var s: float = bf["S"] - inset
	var y: float = bf["Y"] + inset * 0.3
	var half := PackedVector2Array([Vector2(CX + neck, y - 3.0), Vector2(CX + s * 0.7, y + 2.0), Vector2(CX + s - 2.0, y + 18.0), Vector2(CX + s, y + 40.0),
		Vector2(CX + s + 1.0, 262.0)])
	var all := half.duplicate()
	all.append_array(mirror(half))
	return chain(all, true)


static func neck(fr: Dictionary, bf: Dictionary, skin: Color) -> String:
	var c: float = fr["C"]
	var y: float = bf["Y"]
	var nw := 15.0 if not fr["child"] else 13.0
	var d := "M%s,%s L%s,%s L%s,%s L%s,%s Z" % [f(CX - nw), f(c - 14.0), f(CX + nw), f(c - 14.0), f(CX + nw + 3.0), f(y + 6.0), f(CX - nw - 3.0), f(y + 6.0)]
	return cel(d, skin, "M%s,%s Q%s,%s %s,%s L%s,%s L%s,%s Z" % [f(CX - 30), f(c - 6.0), f(CX), f(c + 16.0), f(CX + 30), f(c - 6.0), f(CX + 30), f(c - 30), f(CX - 30), f(c - 30)],
		shade(skin, 0.9))


static func sleeves(bf: Dictionary) -> String:
	var s: float = bf["S"]
	var y: float = bf["Y"]
	var out := ""
	for sd: float in [-1.0, 1.0]:
		var x := CX + sd * (s - 10.0)
		var d := chain(PackedVector2Array([Vector2(x - 20, y + 30), Vector2(x - 12, y + 9), Vector2(x + 2, y + 4), Vector2(x + 16, y + 12),
			Vector2(x + 22, y + 34), Vector2(x + 18, 262), Vector2(x - 18, 262)]), true)
		out += cel(d, Color(SHIRT), shade_out(x - 8.0 * sd - 6.0, y + 18.0, 24.0, 30.0))
	return out


## 몸통 옷. torso = cloth_tunic / tunic_tie / vest / dress / petal / robe / hood / child
static func torso(kind: String, bf: Dictionary, cloth: Color, era: int, child: bool) -> String:
	var s: float = bf["S"]
	var y: float = bf["Y"]
	var out := ""
	var robe := kind == "cloth_robe"
	if not robe and not child:
		out += sleeves(bf)
	var inset := 0.0 if (robe or child) else 13.0
	var d := torso_path(bf, inset, 24.0 if not robe else 28.0)
	var inner := ""
	# 엮은 풀 결 (개척기) · 꽃잎 결 · 천 결
	if era == 0 and kind in ["cloth_tunic", "cloth_tunic_tie", "cloth_vest", "cloth_child", "cloth_dress"]:
		var wv := ""
		for k in 14:
			var x0 := CX - s - 20.0 + k * 13.0
			wv += "M%s,%s l%s,%s " % [f(x0), f(y - 4), f(26), f(70)]
			wv += "M%s,%s l%s,%s " % [f(x0 + 26), f(y - 4), f(-26), f(70)]
		inner += stroke(wv, hx(light(cloth, 0.35)), 1.4, ' opacity="0.45"')
	var sh := shade_out(CX - 18.0, y + 18.0, s * 0.92, 70.0)
	out += cel(d, cloth, sh, null, inner)
	match kind:
		"cloth_tunic", "cloth_tunic_tie":
			var v := "M%s,%s L%s,%s L%s,%s Z" % [f(CX - 17), f(y - 3), f(CX + 17), f(y - 3), f(CX), f(y + 26)]
			out += cel(v, Color(SHIRT))
			if kind == "cloth_tunic_tie":
				out += stroke("M%s,%s L%s,%s M%s,%s L%s,%s M%s,%s L%s,%s M%s,%s L%s,%s" % [f(CX - 9), f(y + 4), f(CX + 7), f(y + 12), f(CX + 9), f(y + 4), f(CX - 7), f(y + 12),
					f(CX - 6), f(y + 12), f(CX + 4), f(y + 19), f(CX + 6), f(y + 12), f(CX - 4), f(y + 19)], hx(Color(BELT)), 1.8)
		"cloth_vest":
			var v := "M%s,%s L%s,%s L%s,%s L%s,%s Z" % [f(CX - 22), f(y - 3), f(CX + 22), f(y - 3), f(CX + 6), f(262), f(CX - 6), f(262)]
			out += cel(v, Color(SHIRT), shade_out(CX - 6, y + 20, 18, 60))
			out += stroke("M%s,%s L%s,%s" % [f(CX), f(y + 10), f(CX), f(262)], INK, 1.4, ' opacity="0.5"')
		"cloth_dress":
			var v := chain(PackedVector2Array([Vector2(CX - 26, y - 2), Vector2(CX, y + 1), Vector2(CX + 26, y - 2), Vector2(CX + 22, y + 13), Vector2(CX, y + 16), Vector2(CX - 22, y + 13)]), true)
			out += cel(v, Color(SHIRT))
			out += stroke("M%s,%s q4,4 8,0 q4,4 8,0 q4,4 8,0 q4,4 8,0 q4,4 8,0" % [f(CX - 20), f(y + 4)], hx(shade(Color(SHIRT), 1.6)), 1.2)
			out += stroke("M%s,%s L%s,%s M%s,%s L%s,%s" % [f(CX - 8), f(y + 22), f(CX + 8), f(y + 32), f(CX + 8), f(y + 22), f(CX - 8), f(y + 32)], hx(Color(BELT)), 1.6)
		"cloth_petal":
			out += petal_collar(bf, cloth)
		"cloth_robe":
			out += cel("M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" % [f(CX - 34), f(y - 6), f(CX), f(y + 24), f(CX + 34), f(y - 6), f(CX), f(y + 6), f(CX - 34), f(y - 6)],
				shade(cloth, 1.2))
			out += stroke("M%s,%s L%s,%s" % [f(CX), f(y + 14), f(CX), f(262)], INK, 1.4, ' opacity="0.45"')
		"cloth_hood":
			var hd := chain(PackedVector2Array([Vector2(CX - 44, y + 2), Vector2(CX - 26, y - 8), Vector2(CX, y - 4), Vector2(CX + 26, y - 8), Vector2(CX + 44, y + 2),
				Vector2(CX + 36, y + 16), Vector2(CX, y + 22), Vector2(CX - 36, y + 16)]), true)
			out += cel(hd, shade(cloth, 1.1), shade_out(CX - 12, y + 2, 40, 16), shade(cloth, 1.7))
			out += stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - 30), f(y + 8), f(CX), f(y + 18), f(CX + 30), f(y + 8)], INK, 1.3, ' opacity="0.5"')
		"cloth_child":
			for sd: float in [-1.0, 1.0]:
				var cd := "M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" % [f(CX), f(y + 1), f(CX + sd * 6), f(y + 16), f(CX + sd * 24), f(y + 12), f(CX + sd * 30), f(y), f(CX + sd * 14), f(y - 4)]
				out += cel(cd, Color(SHIRT))
	return out


## 꽃잎 옷깃: 목둘레에 둥근 꽃잎 여섯 장 (옷 색보다 밝게) + 잎맥 + 씨앗 단추
static func petal_collar(bf: Dictionary, cloth: Color) -> String:
	var y: float = bf["Y"]
	var out := ""
	var pc := light(cloth, 0.35)
	for k in [0, 5, 1, 4, 2, 3]:
		var a := lerpf(-2.5, -0.64, k / 5.0)
		var base := Vector2(CX + cos(a) * 20.0, y + 2.0 + sin(a) * -4.0)
		var dir := Vector2(cos(a) * 1.2, 0.9).normalized()
		var tip := base + dir * 22.0
		var nrm := Vector2(-dir.y, dir.x)
		var d := chain(PackedVector2Array([base - nrm * 6.0, base + dir * 12.0 - nrm * 10.0, tip, base + dir * 12.0 + nrm * 10.0, base + nrm * 6.0]), true)
		out += cel(d, pc, "", null, stroke("M%s L%s" % [pt(base), pt(base + dir * 17.0)], hx(shade(pc, 1.3)), 1.2))
	out += seeds(Vector2(CX, y + 30), 2)
	return out


static func seeds(at: Vector2, n: int) -> String:
	var out := ""
	for k in n:
		var c := at + Vector2(0, k * 14.0)
		out += ell(c.x, c.y, 4.2, 5.6, SEED, outline().replace(f(LINE), "1.6"))
		out += stroke("M%s,%s q-1.5,3 0,6" % [f(c.x - 1.0), f(c.y - 3.0)], SEED_HI, 1.4)
	return out


## 덧옷 · 꾸밈 (몸 위)
static func over(kind: String, bf: Dictionary, col: Color) -> String:
	var s: float = bf["S"]
	var y: float = bf["Y"]
	match kind:
		"over_apron":
			var d := "M%s,%s L%s,%s L%s,%s L%s,%s Z" % [f(CX - 27), f(y + 24), f(CX + 27), f(y + 24), f(CX + 30), f(262), f(CX - 30), f(262)]
			var st := stroke("M%s,%s L%s,%s M%s,%s L%s,%s" % [f(CX - 25), f(y + 26), f(CX - 32), f(y - 2), f(CX + 25), f(y + 26), f(CX + 32), f(y - 2)], INK, 5.4) \
				+ stroke("M%s,%s L%s,%s M%s,%s L%s,%s" % [f(CX - 25), f(y + 26), f(CX - 32), f(y - 2), f(CX + 25), f(y + 26), f(CX + 32), f(y - 2)], APRON, 2.6)
			return st + cel(d, Color(APRON), shade_out(CX - 8, y + 40, 26, 40))
		"over_sash":
			var d := "M%s,%s L%s,%s L%s,%s L%s,%s Z" % [f(CX - s + 6), f(y + 14), f(CX - s + 24), f(y + 6), f(CX + s - 4), f(262), f(CX + s - 30), f(262)]
			var badge := ell(CX + 10, y + 44, 7, 7, "#e9c46a", outline()) + stroke("M%s,%s l0,8 M%s,%s l-3,3 M%s,%s l3,3" % [f(CX + 10), f(y + 40), f(CX + 10), f(y + 44), f(CX + 10), f(y + 44)], "#8a6a2e", 1.4)
			return cel(d, Color(SASH), shade_out(CX - 20, y + 20, s, 50)) + badge
		"over_strap":
			var d := "M%s,%s L%s,%s L%s,%s L%s,%s Z" % [f(CX + s - 20), f(y + 4), f(CX + s - 8), f(y + 10), f(CX - s + 12), f(262), f(CX - s), f(262)]
			return cel(d, Color(BELT))
		"over_shawl":
			var d := chain(PackedVector2Array([Vector2(CX - s - 6, y + 46), Vector2(CX - s + 2, y + 10), Vector2(CX - 30, y - 6), Vector2(CX, y - 2), Vector2(CX + 30, y - 6),
				Vector2(CX + s - 2, y + 10), Vector2(CX + s + 6, y + 46), Vector2(CX + 14, y + 36), Vector2(CX, y + 30), Vector2(CX - 14, y + 36)]), true)
			var knit := ""
			for k in 9:
				knit += "M%s,%s q3,3 6,0 " % [f(CX - s + 10 + k * (s * 2 - 20) / 8.0), f(y + 14 + absf(k - 4) * 2.0)]
			var knot := ell(CX, y + 34, 8, 7, hx(shade(col, 1.0)), outline())
			return cel(d, col, shade_out(CX - 20, y + 10, s, 30), null, stroke(knit, hx(shade(col, 1.5)), 1.4, ' opacity="0.7"')) + knot
		"acc_scarf":
			var band := chain(PackedVector2Array([Vector2(CX - 26, y - 6), Vector2(CX, y - 2), Vector2(CX + 26, y - 6), Vector2(CX + 25, y + 4), Vector2(CX, y + 8), Vector2(CX - 25, y + 4)]), true)
			var tri := chain(PackedVector2Array([Vector2(CX - 22, y + 2), Vector2(CX, y + 4), Vector2(CX + 22, y + 2), Vector2(CX + 4, y + 30), Vector2(CX - 4, y + 30)]), true)
			var dots := ""
			for k in 5:
				dots += ell(CX - 10 + (k % 3) * 10.0, y + 9 + floorf(k / 3.0) * 9.0, 1.8, 1.8, hx(light(col, 0.6)))
			return cel(tri, col, shade_out(CX - 8, y + 8, 18, 18), null, dots) + cel(band, shade(col, 0.5)) + ell(CX + 12, y + 2, 6, 5, hx(shade(col, 1.0)), outline())
		"cape_leaf":
			return leaf_cape(bf, col, false)
		"buttons_seed":
			return seeds(Vector2(CX, y + 34), 2)
		"amulet":
			return stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - 14), f(y - 2), f(CX), f(y + 22), f(CX + 14), f(y - 2)], "#7a5636", 1.6) + ell(CX, y + 24, 5, 6, "#a0703e", outline())
	return ""


## 잎 망토: 어깨를 덮는 큰 잎 두 장 (잎맥) — 뒤쪽(back)은 어깨 너머로 보이는 잎 끝
static func leaf_cape(bf: Dictionary, col: Color, back: bool) -> String:
	var s: float = bf["S"]
	var y: float = bf["Y"]
	var out := ""
	for sd: float in [-1.0, 1.0]:
		var base := Vector2(CX + sd * 8.0, y - 4.0)
		var tip := Vector2(CX + sd * (s + 16.0), y + (52.0 if back else 40.0))
		if back:
			tip = Vector2(CX + sd * (s + 20.0), y + 64.0)
		var mid := base.lerp(tip, 0.5)
		var dir := (tip - base).normalized()
		var nrm := Vector2(-dir.y, dir.x) * (1.0 if sd > 0 else -1.0)
		var wdt := 20.0 if not back else 24.0
		var d := chain(PackedVector2Array([base, mid - nrm * wdt + dir * -8.0, tip, mid + nrm * (wdt * 0.7) + dir * 6.0]), true)
		var veins := "M%s L%s " % [pt(base + dir * 4.0), pt(tip - dir * 6.0)]
		for k in 4:
			var q := base.lerp(tip, 0.22 + k * 0.17)
			veins += "M%s L%s M%s L%s " % [pt(q), pt(q - nrm * 11.0 + dir * 7.0), pt(q), pt(q + nrm * 8.0 + dir * 6.0)]
		out += cel(d, col if not back else shade(col, 0.8), shade_out(mid.x - 6.0 * sd - 4.0, mid.y - 6.0, 30, 18), null,
			stroke(veins, hx(shade(col, 1.5)), 1.3, ' opacity="0.8"'))
	if not back:
		out += stroke("M%s,%s q6,-6 12,0 q-2,6 -8,5" % [f(CX - 6), f(y - 2)], hx(shade(col, 1.3)), 3.0)
	return out


# ───────────────────────── 머리 · 얼굴 ─────────────────────────
static func head(fr: Dictionary, skin: Color, piebald: int) -> String:
	var w: float = fr["W"]
	var m: float = fr["M"]
	var out := ""
	if not fr["baby"]:
		for sd: float in [-1.0, 1.0]:
			var ex := CX + sd * (w - 1.0)
			out += ell(ex, m + 6.0, 9.0, 13.0, hx(skin), outline())
			out += stroke("M%s,%s q%s,4 0,10" % [f(ex + sd * 1.0), f(m + 1.0), f(sd * 4.0)], hx(shade(skin, 1.6)), 1.6)
	var d := head_path(fr)
	var inner := ""
	if piebald >= 0:
		var a := float(piebald % 6) * 1.05
		var c := Vector2(CX + cos(a) * w * 0.55, m - 4.0 + sin(a) * 26.0)
		inner += path(chain(PackedVector2Array([c + Vector2(-16, -4), c + Vector2(-6, -15), c + Vector2(12, -10), c + Vector2(16, 6), c + Vector2(2, 14), c + Vector2(-12, 9)]), true),
			hx(Color(Genetics.PIEBALD_SKIN)))
	out += cel(d, skin, shade_out(CX - 12.0, m - 10.0, w * 0.98, (float(fr["C"]) - float(fr["T"])) * 0.52), shade(skin, 0.75), inner)
	return out


## 눈 한 쪽 (표정별)
static func eye(c: Vector2, rx: float, ry: float, iris: Color, expr: String, sd: float, lash: bool) -> String:
	match expr:
		"happy":
			return stroke("M%s,%s Q%s,%s %s,%s" % [f(c.x - rx - 1), f(c.y + 2), f(c.x), f(c.y - ry - 2), f(c.x + rx + 1), f(c.y + 2)], INK, 2.8)
		"sleep":
			return stroke("M%s,%s Q%s,%s %s,%s" % [f(c.x - rx - 1), f(c.y), f(c.x), f(c.y + ry * 0.7), f(c.x + rx + 1), f(c.y)], INK, 2.6)
	var r := Vector2(rx, ry)
	if expr == "surprised":
		r *= 1.12
	var out := ell(c.x, c.y, r.x, r.y, hx(iris.darkened(0.15)), outline().replace(f(LINE), "1.8"))
	out += ell(c.x + sd * 0.3, c.y + r.y * 0.18, r.x * (0.42 if expr == "surprised" else 0.58), r.y * (0.42 if expr == "surprised" else 0.6), hx(iris.darkened(0.72)))
	out += ell(c.x - r.x * 0.32, c.y - r.y * 0.36, r.x * 0.36, r.y * 0.3, "#ffffff")
	out += ell(c.x + r.x * 0.35, c.y + r.y * 0.38, r.x * 0.16, r.x * 0.16, "#ffffff", ' opacity="0.8"')
	if expr == "sick":                     # 졸린 눈꺼풀 (반쯤 감김)
		out += path("M%s,%s Q%s,%s %s,%s L%s,%s Q%s,%s %s,%s Z" % [f(c.x - r.x - 2), f(c.y - 1), f(c.x), f(c.y - r.y - 6), f(c.x + r.x + 2), f(c.y - 1),
			f(c.x + r.x + 2), f(c.y - r.y - 6), f(c.x), f(c.y - r.y - 10), f(c.x - r.x - 2), f(c.y - r.y - 6)], "skin")
		out += stroke("M%s,%s Q%s,%s %s,%s" % [f(c.x - r.x - 1), f(c.y - 1), f(c.x), f(c.y - 3), f(c.x + r.x + 1), f(c.y - 1)], INK, 2.2)
	if lash:
		out += stroke("M%s,%s l%s,-4" % [f(c.x + sd * (r.x - 0.5)), f(c.y - r.y * 0.45), f(sd * 4.0)], INK, 1.8)
	return out


## 얼굴 (눈 · 눈썹 · 코 · 입 · 볼 · 주근깨 · 주름) — fp = {expr, iris_l, iris_r, brow, nose, hair, cheek, freckle, elder, child, female}
static func face(fr: Dictionary, skin: Color, fp: Dictionary) -> String:
	var expr: String = fp.get("expr", "")
	var w: float = fr["W"]
	var e: float = fr["E"]
	var child: bool = fr["child"]
	var elder: bool = fr["elder"]
	var dx := w * (0.42 if not child else 0.43)
	var rx := 6.0 if not child else 7.0
	var ry := 7.8 if not child else 8.8
	if elder:
		rx *= 0.92
		ry *= 0.86
	var out := ""
	# 볼
	var cheek: Color = fp.get("cheek", Color(Genetics.CHEEK))
	for sd: float in [-1.0, 1.0]:
		out += ell(CX + sd * w * 0.56, e + 15.0, 10.0, 6.0, hx(cheek), ' opacity="%s"' % f(0.5 if expr != "sick" else 0.25))
	# 주근깨
	var fa: float = fp.get("freckle", 0.0)
	if fa > 0.0:
		var fc: Color = skin.lerp(Color(Genetics.FRECKLE), 0.8)
		var spots := [Vector2(-0.5, 10), Vector2(-0.38, 14), Vector2(-0.62, 15), Vector2(-0.46, 19), Vector2(-0.3, 9), Vector2(0.5, 10), Vector2(0.38, 14),
			Vector2(0.62, 15), Vector2(0.46, 19), Vector2(0.3, 9), Vector2(-0.12, 7), Vector2(0.12, 7)]
		for sp: Vector2 in spots:
			out += ell(CX + sp.x * w, e + sp.y, 1.5, 1.4, hx(fc), ' opacity="%s"' % f(clampf(fa, 0.35, 1.0)))
	# 눈
	var lash: bool = fp.get("female", false) and not child
	out += eye(Vector2(CX - dx, e), rx, ry, fp.get("iris_l", Color("4a2c1c")), expr, -1.0, lash).replace('fill="skin"', 'fill="%s"' % hx(skin))
	out += eye(Vector2(CX + dx, e), rx, ry, fp.get("iris_r", Color("4a2c1c")), expr, 1.0, lash).replace('fill="skin"', 'fill="%s"' % hx(skin))
	# 눈썹 (모양 3종 × 표정)
	var bc: Color = fp.get("hair", Color("5b3b29"))
	bc = bc.darkened(0.25) if bc.v > 0.35 else bc.lightened(0.05)
	var bw: float = [2.2, 3.6, 2.8][int(fp.get("brow", 0))]
	var arch: float = [1.5, 1.0, 4.0][int(fp.get("brow", 0))]
	var by := e - ry - 7.0
	var lift := 0.0
	var tilt := 0.0
	match expr:
		"surprised":
			lift = -5.0
			arch += 2.0
		"happy":
			lift = -2.0
		"sad", "sick":
			tilt = 4.5
	for sd: float in [-1.0, 1.0]:
		var bx := CX + sd * dx
		var inner_x := bx - sd * 8.0
		var outer_x := bx + sd * 8.0
		out += stroke("M%s,%s Q%s,%s %s,%s" % [f(inner_x), f(by + lift - tilt), f(bx), f(by + lift - arch - tilt * 0.3), f(outer_x), f(by + lift + 1.5)], hx(bc), bw)
	# 코
	var ny := e + 13.0
	var nc := shade(skin, 1.5)
	match int(fp.get("nose", 0)):
		0:
			out += stroke("M%s,%s q2.5,2 0,4" % [f(CX - 0.5), f(ny - 2)], hx(nc), 2.0)
		1:
			out += ell(CX, ny + 1, 5.0, 3.6, hx(shade(skin, 0.6)), ' stroke="%s" stroke-width="1.4"' % hx(nc))
			out += ell(CX - 1.5, ny, 1.6, 1.1, hx(light(skin, 0.6)))
		_:
			out += stroke("M%s,%s q4,7 1,10 q-3,1 -5,-1" % [f(CX + 0.5), f(ny - 9)], hx(nc), 2.0)
	# 입
	var my := e + 25.0 + (2.0 if not child else 0.0)
	match expr:
		"happy":
			out += path("M%s,%s Q%s,%s %s,%s Z" % [f(CX - 9), f(my - 2), f(CX), f(my + 13), f(CX + 9), f(my - 2)], MOUTH, outline().replace(f(LINE), "2"))
			out += path("M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" % [f(CX - 5), f(my + 5), f(CX), f(my + 2), f(CX + 5), f(my + 5), f(CX), f(my + 9), f(CX - 5), f(my + 5)], TONGUE)
		"sad":
			out += stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - 7), f(my + 4), f(CX), f(my - 3), f(CX + 7), f(my + 4)], INK, 2.2)
		"sick":
			out += stroke("M%s,%s q2.5,-3 5,0 q2.5,3 5,0 q2.5,-3 5,0" % [f(CX - 7.5), f(my + 1)], INK, 2.0)
			out += path("M%s,%s q-4,6 0,8 q4,-2 0,-8 Z" % [f(CX + w * 0.62), f(e - 20)], "#9fd3ea", outline().replace(f(LINE), "1.4"))
		"sleep":
			out += ell(CX, my + 1, 3.0, 2.4, MOUTH, outline().replace(f(LINE), "1.6"))
		"surprised":
			out += ell(CX, my + 2, 5.0, 6.5, MOUTH, outline().replace(f(LINE), "2"))
		"talking":
			out += path("M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" % [f(CX - 7), f(my), f(CX), f(my - 2), f(CX + 7), f(my), f(CX), f(my + 10), f(CX - 7), f(my)], MOUTH, outline().replace(f(LINE), "2"))
		_:
			out += stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - 7), f(my - 1), f(CX), f(my + 6), f(CX + 7), f(my - 1)], INK, 2.2)
	# 주름 (노인)
	if elder:
		var wc := hx(shade(skin, 1.7))
		out += stroke("M%s,%s q-4,5 -2,11 M%s,%s q4,5 2,11" % [f(CX - 13), f(my - 9), f(CX + 13), f(my - 9)], wc, 1.6, ' opacity="0.8"')
		for sd: float in [-1.0, 1.0]:
			var ox := CX + sd * (dx + rx + 3)
			out += stroke("M%s,%s l%s,-3 M%s,%s l%s,2" % [f(ox), f(e - 1), f(sd * 5), f(ox), f(e + 2), f(sd * 5)], wc, 1.3, ' opacity="0.8"')
		out += stroke("M%s,%s q10,-3 20,0" % [f(CX - 10), f(float(fr["T"]) + 30)], wc, 1.3, ' opacity="0.55"')
	return out


static func beard(kind: String, fr: Dictionary, col: Color) -> String:
	var w: float = fr["W"]
	var m: float = fr["M"]
	var c: float = fr["C"]
	var j: float = fr["J"]
	var my := float(fr["E"]) + 27.0
	var low := c + (12.0 if kind != "beard_long" else 46.0)
	var outer := PackedVector2Array([Vector2(CX + w - 1, m - 2), Vector2(CX + w + 2, m + 18), Vector2(CX + j + 8, c - 12), Vector2(CX + 18, low - 6), Vector2(CX, low)])
	var inner_y := my + (8.0 if kind != "beard_jaw" else 16.0)
	var inner := PackedVector2Array([Vector2(CX, inner_y), Vector2(CX + 14, inner_y - 2), Vector2(CX + w * 0.66, m + 14), Vector2(CX + w - 9, m)])
	if kind == "beard_jaw":
		inner = PackedVector2Array([Vector2(CX, c - 2), Vector2(CX + j * 0.7, c - 10), Vector2(CX + w - 8, m + 14), Vector2(CX + w - 7, m)])
	var d := chain(outer) + " " + chain(mirror(outer), false, false) + " " + chain(mirror(inner), false, false) + " " + chain(inner, false, false) + " Z"
	var out := cel(d, col, shade_out(CX - 10, m + 10, w * 0.9, (low - m) * 0.7))
	# 콧수염
	var ms := ""
	for sd: float in [-1.0, 1.0]:
		ms += cel("M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" % [f(CX), f(my - 7), f(CX + sd * 10), f(my - 11), f(CX + sd * 16), f(my - 1), f(CX + sd * 8), f(my - 2), f(CX), f(my - 4)], col)
	if kind == "beard_long":
		out += stroke("M%s,%s q-3,14 0,26 M%s,%s q3,14 0,26" % [f(CX - 10), f(c - 4), f(CX + 10), f(c - 4)], hx(shade(col, 1.5)), 1.4)
	return out + ms


# ───────────────────────── 머리카락 ─────────────────────────
## 앞머리 선 (얼굴 위 머리카락이 끝나는 곳) — 오른쪽 귀 위 → 왼쪽 귀 위
static func hairline(kind: String, fr: Dictionary, sv: int) -> PackedVector2Array:
	var t: float = fr["T"]
	var m: float = fr["M"]
	var w: float = fr["W"]
	var out := PackedVector2Array()
	var n := 13
	var side := 1.0 if sv % 2 == 0 else -1.0          # 가르마 쪽 (사람마다)
	for i in n:
		var u := 1.0 - 2.0 * i / (n - 1.0)             # +1 오른쪽 → −1 왼쪽
		var x := CX + u * w * 0.86
		var y := 0.0
		match kind:
			"bob", "twinbuns_kid":
				y = t + 44.0 + 3.0 * sin(u * 9.0) - 4.0 * u * u
			"side", "wave":
				var k := (u * side + 1.0) * 0.5          # 0 가르마 쪽 → 1 반대쪽
				y = t + 20.0 + k * 28.0 + 5.0 * pow(sin(u * 4.6 + 0.6), 2) * k
			"crop":
				y = t + 22.0 + 2.5 * pow(sin(u * 7.0), 2)
			"part":                                    # 가운데 가르마 — 양쪽으로 쓸어내린 앞머리
				y = t + 16.0 + absf(u) * 34.0 - 10.0 * u * u + 3.0 * pow(sin(u * 5.0), 2)
			"receding":
				y = t + 8.0 + absf(u) * 10.0
			_:
				y = t + 30.0
		if absf(u) > 0.82:
			y = lerpf(y, m - 10.0, (absf(u) - 0.82) / 0.18)
		out.append(Vector2(x, y))
	return out


## 머리 윗덮개 바깥 둘레 (정수리 위로 vol만큼 부푼 둥근 모양) — 왼쪽 아래 → 위 → 오른쪽 아래
static func crown(fr: Dictionary, vol: float, low: float, out_x := 6.0) -> PackedVector2Array:
	var t: float = fr["T"]
	var m: float = fr["M"]
	var w: float = fr["W"]
	var pts := PackedVector2Array()
	var cy := m - 4.0
	var ry := cy - t + vol
	for i in 11:
		var a := PI + PI * i / 10.0
		pts.append(Vector2(CX + cos(a) * (w + out_x), cy + sin(a) * ry))
	pts[0] = Vector2(CX - w - out_x + 1.0, low)
	pts[10] = Vector2(CX + w + out_x - 1.0, low)
	return pts


static func strands(fr: Dictionary, col: Color, n := 4) -> String:
	var t: float = fr["T"]
	var w: float = fr["W"]
	var s := ""
	for k in n:
		var x := CX - w * 0.6 + k * (w * 1.2 / maxf(n - 1, 1))
		s += "M%s,%s Q%s,%s %s,%s " % [f(CX + (x - CX) * 0.3), f(t + 2), f(x - 4), f(t + 14), f(x), f(t + 30)]
	return stroke(s, hx(shade(col, 1.3)), 1.5, ' opacity="0.7"') + stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - w * 0.55), f(t + 20), f(CX - w * 0.3), f(t + 4), f(CX + 2), f(t + 3)],
		hx(light(col, 0.45)), 4.0, ' opacity="0.55"')


## 앞 머리카락 (얼굴 위에 덮임). style = 3D 부품 이름 (hair_short …)
static func hair_front(style: String, fr: Dictionary, col: Color, sv: int, fore: bool, messy: bool) -> String:
	var m: float = fr["M"]
	var w: float = fr["W"]
	var t: float = fr["T"]
	var sh := shade_out(CX - 18.0, t + 26.0, w * 0.95, 48.0)
	var out := ""
	match style:
		"hair_curly", "hair_curly_long":
			return curly(fr, col, sv, style == "hair_curly_long", false) + _fore(fore, fr)
		"hair_receding":
			var d := chain(crown(fr, 4.0, m + 2.0, 4.0)) + " " + chain(hairline("receding", fr, sv), false, false) + " Z"
			return cel(d, col, sh)
		"hair_bald_ring":
			for sd: float in [-1.0, 1.0]:
				var x := CX + sd * (w + 2.0)
				out += cel(chain(PackedVector2Array([Vector2(x - sd * 4, m - 26), Vector2(x + sd * 5, m - 16), Vector2(x + sd * 4, m + 2), Vector2(x - sd * 8, m + 4), Vector2(x - sd * 9, m - 14)]), true), col)
			return out
	var kind := "side"
	var low := m - 2.0
	var vol := 8.0
	var side_drop := 0.0                       # 얼굴 옆으로 내려오는 머리 (긴 머리)
	match style:
		"hair_short", "hair_child":
			kind = "side"
		"hair_wave":
			kind = "wave"
			vol = 10.0
		"hair_crop":
			kind = "crop"
			vol = 4.0
			low = m - 8.0
		"hair_bob":
			kind = "bob"
			vol = 10.0
			side_drop = float(fr["C"]) - 8.0 - m
		"hair_long", "hair_wave_long", "hair_braids", "hair_pony", "hair_bun", "hair_twinbuns":
			kind = "part"
			if style in ["hair_long", "hair_wave_long"]:
				side_drop = 82.0
		_:
			kind = "side"
	if fr["child"] and style in ["hair_twinbuns", "hair_bob"]:
		kind = "bob" if style == "hair_bob" else "part"
	var outer := crown(fr, vol, low + side_drop, 7.0 if side_drop > 0.0 else 5.0)
	var hl := hairline(kind, fr, sv)
	if side_drop > 0.0:                         # 얼굴 옆 머리: 귀 앞으로 내려옴
		hl.insert(0, Vector2(CX + w - 4.0, low + side_drop))
		hl.insert(1, Vector2(CX + w - 8.0, m + side_drop * 0.4))
		hl.append(Vector2(CX - w + 8.0, m + side_drop * 0.4))
		hl.append(Vector2(CX - w + 4.0, low + side_drop))
		if style == "hair_wave_long":
			outer[0] = outer[0] + Vector2(-4, 0)
			outer[10] = outer[10] + Vector2(4, 0)
	var d := chain(outer) + " " + chain(hl, false, false) + " Z"
	var inner := strands(fr, col)
	if messy:
		inner += stroke("M%s,%s l-4,-8 M%s,%s l3,-9 M%s,%s l6,-6" % [f(CX - 10), f(t - 4), f(CX + 2), f(t - 6), f(CX + 14), f(t - 3)], hx(col), 3.0)
	out += cel(d, col, sh, null, inner)
	if style == "hair_braids":
		out += braids(fr, col)
	return out + _fore(fore, fr)


static func _fore(on: bool, fr: Dictionary) -> String:
	if not on:
		return ""
	var t: float = fr["T"]
	return stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - 14), f(t + 2), f(CX - 20), f(t + 20), f(CX - 16), f(t + 38)], "#f6f3ec", 7.0, ' opacity="0.9"')


## 곱슬: 둥근 송이를 겹쳐 (외곽선만 바깥에 — 두꺼운 선 먼저, 색은 위에)
static func curly(fr: Dictionary, col: Color, sv: int, long: bool, back: bool) -> String:
	var t: float = fr["T"]
	var m: float = fr["M"]
	var w: float = fr["W"]
	var cs: Array = []                          # [중심, 반지름]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + sv
	if back:
		var bottom := (float(fr["C"]) + 50.0) if long else (m + 16.0)
		var n := 9 if long else 6
		for i in n:
			var u := i / (n - 1.0)
			var y := lerpf(m - 14.0, bottom, u)
			for sd: float in [-1.0, 1.0]:
				cs.append([Vector2(CX + sd * (w + 8.0 + 8.0 * sin(u * PI) + rng.randf_range(-2, 2)), y), 15.0 + rng.randf_range(-1.5, 2.0)])
		if long:
			for k in 5:
				cs.append([Vector2(CX - w + k * w * 0.5, bottom + rng.randf_range(-4, 4)), 15.0])
	else:
		var cy := m - 6.0
		var ry := cy - t + 6.0
		for i in 9:
			var a := PI + PI * i / 8.0
			cs.append([Vector2(CX + cos(a) * (w + 4.0), cy + sin(a) * ry) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), 17.0 + rng.randf_range(-1.5, 2.5)])
		for i in 5:                             # 이마 위 곱슬 앞머리
			var x := CX - w * 0.62 + i * w * 0.31
			cs.append([Vector2(x, t + 26.0 + 4.0 * sin(i * 1.7) + rng.randf_range(-1, 1)), 12.5 + rng.randf_range(-1, 1.5)])
		for sd: float in [-1.0, 1.0]:
			cs.append([Vector2(CX + sd * (w + 1.0), m - 6.0), 12.0])
		cs.append([Vector2(CX, t + 10.0), 20.0])
		cs.append([Vector2(CX - w * 0.4, t + 12.0), 18.0])
		cs.append([Vector2(CX + w * 0.4, t + 12.0), 18.0])
	var lines := ""
	var fills := ""
	var clip := ""
	var swirls := ""
	for cr: Array in cs:
		var c: Vector2 = cr[0]
		var r: float = cr[1]
		lines += ell(c.x, c.y, r, r, INK, ' stroke="%s" stroke-width="%s"' % [INK, f(LINE * 2.0)])
		fills += ell(c.x, c.y, r, r, hx(col))
		clip += '<circle cx="%s" cy="%s" r="%s"/>' % [f(c.x), f(c.y), f(r)]
		swirls += "M%s,%s a%s,%s 0 1,1 %s,%s " % [f(c.x + r * 0.1), f(c.y + r * 0.35), f(r * 0.35), f(r * 0.35), f(r * 0.3), f(-r * 0.45)]
	var id := _id("k")
	var sh := shade_out(CX - 18.0, t + 30.0, w * 0.95, 52.0) if not back else "M0,0 H256 V256 H0 Z"
	return lines + fills + '<clipPath id="%s">%s</clipPath><g clip-path="url(#%s)">%s%s</g>' % [id, clip, id,
		path(sh, hx(shade(col, 1.0 if not back else 0.6))), stroke(swirls, hx(shade(col, 1.6)), 1.6, ' opacity="0.7"')]


## 뒤 머리카락 (머리·몸 뒤)
static func hair_back(style: String, fr: Dictionary, col: Color, sv: int) -> String:
	var m: float = fr["M"]
	var w: float = fr["W"]
	var t: float = fr["T"]
	var c: float = fr["C"]
	var dk := shade(col, 0.55)
	match style:
		"hair_curly":
			return curly(fr, dk, sv, false, true)
		"hair_curly_long":
			return curly(fr, dk, sv, true, true)
		"hair_long", "hair_wave_long":
			var wav := 6.0 if style == "hair_wave_long" else 0.0
			var half := PackedVector2Array([Vector2(CX, t - 6.0), Vector2(CX + w + 10.0, m - 20.0)])
			for k in 5:
				var y := m + k * 26.0
				half.append(Vector2(CX + w + 14.0 + k * 3.0 + (wav * (1 if k % 2 == 0 else -1)), y))
			half.append(Vector2(CX + w * 0.6, 238.0))
			half.append(Vector2(CX, 240.0))
			return cel(chain(sym(half), true), dk)
		"hair_bob":
			var half := PackedVector2Array([Vector2(CX, t - 8.0), Vector2(CX + w + 10.0, m - 20.0), Vector2(CX + w + 14.0, m + 10.0), Vector2(CX + w + 12.0, c - 10.0),
				Vector2(CX + w - 4.0, c - 2.0), Vector2(CX, c - 10.0)])
			return cel(chain(sym(half), true), dk)
		"hair_bun":
			var bc := Vector2(CX, t - 6.0)
			return cel(chain(PackedVector2Array([bc + Vector2(-23, 6), bc + Vector2(-18, -14), bc + Vector2(0, -22), bc + Vector2(18, -14), bc + Vector2(23, 6), bc + Vector2(0, 14)]), true),
				col, shade_out(bc.x - 6, bc.y - 6, 18, 16), null, stroke("M%s,%s q10,-8 18,2" % [f(bc.x - 12), f(bc.y - 2)], hx(shade(col, 1.4)), 1.6)) + _sides(fr, dk)
		"hair_twinbuns":
			var out := ""
			for sd: float in [-1.0, 1.0]:
				var bc := Vector2(CX + sd * (w - 4.0), t + 12.0)
				out += cel(chain(PackedVector2Array([bc + Vector2(-18, 4), bc + Vector2(-13, -13), bc + Vector2(2, -19), bc + Vector2(16, -9), bc + Vector2(18, 6), bc + Vector2(0, 14)]), true),
					col, shade_out(bc.x - 5, bc.y - 5, 15, 14), null, stroke("M%s,%s q8,-7 14,2" % [f(bc.x - 9), f(bc.y - 1)], hx(shade(col, 1.4)), 1.6))
			return out + _sides(fr, dk)
		"hair_pony":
			var sd := 1.0 if sv % 2 == 0 else -1.0
			var tail := PackedVector2Array([Vector2(CX + sd * w * 0.5, t + 4.0), Vector2(CX + sd * (w + 22.0), m - 26.0), Vector2(CX + sd * (w + 30.0), m + 20.0),
				Vector2(CX + sd * (w + 20.0), m + 66.0), Vector2(CX + sd * (w + 8.0), m + 30.0), Vector2(CX + sd * (w + 2.0), m - 10.0)])
			return cel(chain(tail, true), col, shade_out(CX + sd * (w + 14.0) - 6, m, 14, 40)) \
				+ ell(CX + sd * (w + 10.0), m - 30.0, 7.0, 6.0, hx(Color(Balance.LOOK_FIXED["scarf_b"])), outline()) + _sides(fr, dk)
		"hair_braids", "hair_short", "hair_wave", "hair_child", "hair_crop":
			return _sides(fr, dk)
	return ""


static func _sides(fr: Dictionary, dk: Color) -> String:
	var m: float = fr["M"]
	var w: float = fr["W"]
	var t: float = fr["T"]
	var half := PackedVector2Array([Vector2(CX, t - 4.0), Vector2(CX + w + 7.0, m - 24.0), Vector2(CX + w + 9.0, m + 6.0), Vector2(CX + w - 6.0, m + 12.0)])
	return cel(chain(sym(half), true), dk)


static func braids(fr: Dictionary, col: Color) -> String:
	var m: float = fr["M"]
	var w: float = fr["W"]
	var out := ""
	for sd: float in [-1.0, 1.0]:
		var x := CX + sd * (w + 2.0)
		var y := m + 8.0
		for k in 7:
			var r := 9.5 - k * 0.6
			out += cel(chain(PackedVector2Array([Vector2(x - r, y), Vector2(x, y - r * 0.8), Vector2(x + r, y), Vector2(x, y + r * 1.1)]), true), col,
				shade_out(x - 3, y - 3, r * 0.8, r * 0.7))
			y += r * 1.45
			x += sd * 1.5
		out += ell(x, y - 2, 6.0, 4.0, hx(Color(Balance.LOOK_FIXED["scarf_b"])), outline())
		out += cel("M%s,%s L%s,%s L%s,%s Z" % [f(x - 5), f(y + 1), f(x + 5), f(y + 1), f(x), f(y + 13)], col)
	return out


# ───────────────────────── 모자 · 꾸밈 ─────────────────────────
## 모자 밑으로 잘라 낼 선 (이보다 위의 머리카락은 모자에 가려짐)
static func hat_cut(hat: String, fr: Dictionary) -> float:
	var t: float = fr["T"]
	match hat:
		"hat_straw":
			return t + 24.0
		"hat_scarf", "hat_scarf_top":
			return t + 22.0
		"hat_fisher":
			return t + 34.0
		_:
			return t + 28.0


static func hat(kind: String, fr: Dictionary, col: Color, sv: int) -> String:
	var t: float = fr["T"]
	var w: float = fr["W"]
	var m: float = fr["M"]
	var out := ""
	match kind:
		"hat_straw":
			var by := t + 32.0
			var brim := "M%s,%s a%s,%s 0 1,0 %s,0 a%s,%s 0 1,0 %s,0 Z" % [f(CX - w - 40), f(by), f(w + 40), f(17), f(2 * (w + 40)), f(w + 40), f(17), f(-2 * (w + 40))]
			var weave := ""
			for k in 3:
				weave += "M%s,%s a%s,%s 0 0,0 %s,0 " % [f(CX - w - 30 + k * 8), f(by + 2), f(w + 30 - k * 8), f(11 - k * 3), f(2 * (w + 30 - k * 8))]
			out += cel(brim, Color(STRAW), shade_out(CX - 10, by - 3, w + 38, 17), null, stroke(weave, hx(shade(Color(STRAW), 1.3)), 1.2, ' opacity="0.7"'))
			var crown_d := chain(PackedVector2Array([Vector2(CX - w * 0.74, by + 2), Vector2(CX - w * 0.72, t - 4), Vector2(CX - w * 0.4, t - 22), Vector2(CX, t - 26),
				Vector2(CX + w * 0.4, t - 22), Vector2(CX + w * 0.72, t - 4), Vector2(CX + w * 0.74, by + 2), Vector2(CX, by + 8)]), true)
			out += cel(crown_d, Color(STRAW), shade_out(CX - 10, t - 4, w * 0.7, 36))
			out += cel("M%s,%s Q%s,%s %s,%s L%s,%s Q%s,%s %s,%s Z" % [f(CX - w * 0.74), f(by - 12), f(CX), f(by - 4), f(CX + w * 0.74), f(by - 12),
				f(CX + w * 0.75), f(by - 1), f(CX), f(by + 8), f(CX - w * 0.75), f(by - 1)], Color(STRAW_D))
		"hat_scarf", "hat_scarf_top":
			var half := PackedVector2Array([Vector2(CX, t - 10), Vector2(CX + w * 0.8, t + 2), Vector2(CX + w + 9, m - 18), Vector2(CX + w + 6, m + 12), Vector2(CX + w - 4, m + 10),
				Vector2(CX + w * 0.8, t + 30), Vector2(CX + w * 0.35, t + 22), Vector2(CX, t + 20)])
			var d := chain(sym(half), true)
			var dots := ""
			if sv % 3 == 0:
				for k in 10:
					dots += ell(CX - w * 0.7 + (k % 5) * w * 0.35, t + 2 + floorf(k / 5.0) * 14 + (k % 2) * 4, 2.4, 2.4, hx(light(col, 0.7)))
			out += cel(d, col, shade_out(CX - 16, t + 4, w * 0.95, 40), null, dots)
			out += stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - w * 0.78), f(t + 26), f(CX), f(t + 14), f(CX + w * 0.78), f(t + 26)], hx(shade(col, 1.3)), 1.6)
			if kind == "hat_scarf_top":
				for sd: float in [-1.0, 1.0]:
					out += cel(chain(PackedVector2Array([Vector2(CX, t - 6), Vector2(CX + sd * 14, t - 26), Vector2(CX + sd * 30, t - 20), Vector2(CX + sd * 16, t - 6)]), true), col,
						shade_out(CX + sd * 14 - 4, t - 18, 12, 8))
				out += ell(CX, t - 7, 8, 7, hx(shade(col, 0.7)), outline())
			else:
				var kx := CX + w + 6
				out += cel(chain(PackedVector2Array([Vector2(kx - 6, m + 6), Vector2(kx + 12, m + 14), Vector2(kx + 8, m + 30), Vector2(kx - 2, m + 18)]), true), col)
				out += ell(kx - 4, m + 8, 7, 6, hx(shade(col, 0.6)), outline())
		"hat_cap":
			var d := chain(PackedVector2Array([Vector2(CX - w - 6, t + 32), Vector2(CX - w - 2, t + 4), Vector2(CX - w * 0.4, t - 12), Vector2(CX + w * 0.3, t - 14),
				Vector2(CX + w + 6, t + 2), Vector2(CX + w + 8, t + 30), Vector2(CX, t + 26)]), true)
			out += cel(d, col, shade_out(CX - 16, t + 2, w * 0.95, 30))
			out += stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - w * 0.6), f(t + 2), f(CX), f(t - 10), f(CX + w * 0.4), f(t - 2)], hx(shade(col, 1.4)), 1.4)
			out += cel("M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" % [f(CX - w * 0.82), f(t + 30), f(CX), f(t + 20), f(CX + w * 0.82), f(t + 30), f(CX), f(t + 46), f(CX - w * 0.82), f(t + 30)],
				shade(col, 0.9))
		"hat_baker":
			var band := "M%s,%s L%s,%s L%s,%s Q%s,%s %s,%s Z" % [f(CX - w * 0.9), f(t + 12), f(CX + w * 0.9), f(t + 12), f(CX + w * 0.92), f(t + 34), f(CX), f(t + 40), f(CX - w * 0.92), f(t + 34)]
			var top := chain(PackedVector2Array([Vector2(CX - w * 0.95, t + 14), Vector2(CX - w * 1.05, t - 12), Vector2(CX - w * 0.6, t - 34), Vector2(CX - w * 0.1, t - 30),
				Vector2(CX + w * 0.3, t - 42), Vector2(CX + w * 0.8, t - 30), Vector2(CX + w * 1.05, t - 8), Vector2(CX + w * 0.95, t + 14)]), true)
			out += cel(top, Color(BAKER), shade_out(CX - 20, t - 18, w * 0.9, 26))
			out += stroke("M%s,%s q4,-12 2,-22 M%s,%s q-4,-12 4,-24" % [f(CX - w * 0.35), f(t + 10), f(CX + w * 0.3), f(t + 10)], hx(shade(Color(BAKER), 1.4)), 1.4)
			out += cel(band, shade(Color(BAKER), 0.25), shade_out(CX - 14, t + 20, w * 0.85, 16))
		"hat_fisher":
			var d := chain(PackedVector2Array([Vector2(CX - w - 4, t + 36), Vector2(CX - w - 2, t + 6), Vector2(CX - w * 0.5, t - 16), Vector2(CX, t - 20),
				Vector2(CX + w * 0.5, t - 16), Vector2(CX + w + 2, t + 6), Vector2(CX + w + 4, t + 36)]), true)
			var ribs := ""
			for k in 9:
				var x := CX - w * 0.8 + k * w * 0.2
				ribs += "M%s,%s Q%s,%s %s,%s " % [f(x), f(t + 30), f(CX + (x - CX) * 0.85), f(t + 4), f(CX + (x - CX) * 0.4), f(t - 14)]
			out += cel(d, col, shade_out(CX - 16, t + 2, w * 0.95, 34), null, stroke(ribs, hx(shade(col, 1.3)), 1.4, ' opacity="0.7"'))
			var band := "M%s,%s Q%s,%s %s,%s L%s,%s Q%s,%s %s,%s Z" % [f(CX - w - 6), f(t + 24), f(CX), f(t + 16), f(CX + w + 6), f(t + 24), f(CX + w + 6), f(t + 42),
				f(CX), f(t + 36), f(CX - w - 6), f(t + 42)]
			out += cel(band, shade(col, 0.7))
		"hat_acorn":
			var d := chain(PackedVector2Array([Vector2(CX - w - 8, t + 34), Vector2(CX - w - 4, t + 6), Vector2(CX - w * 0.5, t - 14), Vector2(CX, t - 18),
				Vector2(CX + w * 0.5, t - 14), Vector2(CX + w + 4, t + 6), Vector2(CX + w + 8, t + 34), Vector2(CX, t + 30)]), true)
			var sc := ""
			for k in 16:                         # 비늘 (마름모 격자)
				var x0 := CX - w * 1.4 + k * 12.0
				sc += "M%s,%s l%s,%s M%s,%s l%s,%s " % [f(x0), f(t - 20), f(40), f(60), f(x0 + 40), f(t - 20), f(-40), f(60)]
			out += cel(d, Color(ACORN[0]), shade_out(CX - 16, t + 2, w * 0.95, 30), Color(ACORN[1]), stroke(sc, ACORN[2], 1.6, ' opacity="0.75"'))
			out += cel("M%s,%s Q%s,%s %s,%s L%s,%s Q%s,%s %s,%s Z" % [f(CX - w - 9), f(t + 26), f(CX), f(t + 18), f(CX + w + 9), f(t + 26), f(CX + w + 9), f(t + 38),
				f(CX), f(t + 32), f(CX - w - 9), f(t + 38)], Color(ACORN[2]))
			out += stroke("M%s,%s q2,-10 10,-14" % [f(CX), f(t - 16)], INK, 8.0) + stroke("M%s,%s q2,-10 10,-14" % [f(CX), f(t - 16)], ACORN[3], 4.6)
	return out


static func flower(kind: String, fr: Dictionary) -> String:
	var cols: Array = FLOWER.get(kind, FLOWER["acc_flower"])
	var c := Vector2(CX + float(fr["W"]) * 0.78, float(fr["T"]) + 24.0)
	var out := ""
	for k in 5:
		var a := -PI / 2 + k * TAU / 5.0
		var p := c + Vector2(cos(a), sin(a)) * 8.0
		out += ell(p.x, p.y, 6.5, 6.5, cols[0], outline().replace(f(LINE), "1.8"))
	out += ell(c.x, c.y, 5.0, 5.0, cols[1], outline().replace(f(LINE), "1.6"))
	out += ell(c.x - 1.5, c.y - 1.5, 1.6, 1.6, "#ffffff", ' opacity="0.7"')
	return out


# ───────────────────────── 아기 ─────────────────────────
static func baby_blanket(fr: Dictionary, wrap: Color) -> String:
	var t: float = fr["T"]
	var w: float = fr["W"]
	var m: float = fr["M"]
	var hood := chain(PackedVector2Array([Vector2(CX, t - 18), Vector2(CX + w + 16, t + 14), Vector2(CX + w + 22, m + 30), Vector2(CX + w + 50, 262),
		Vector2(CX - w - 50, 262), Vector2(CX - w - 22, m + 30), Vector2(CX - w - 16, t + 14)]), true)
	return cel(hood, wrap, shade_out(CX - 14, m, w + 40, 112), shade(wrap, 0.5))


static func baby_front(fr: Dictionary, wrap: Color) -> String:
	var w: float = fr["W"]
	var c: float = fr["C"]
	var fold := chain(PackedVector2Array([Vector2(CX - w - 30, 262), Vector2(CX - w * 0.6, c - 4), Vector2(CX + 10, c + 8), Vector2(CX + w + 30, c + 20), Vector2(CX + w + 40, 262)]), true)
	return cel(fold, light(wrap, 0.15), shade_out(CX - 20, c + 30, w + 44, 60), shade(wrap, 0.45)) + stroke("M%s,%s Q%s,%s %s,%s" % [f(CX - w * 0.2), f(c + 20), f(CX + 10), f(c + 34), f(CX + w * 0.6), f(c + 40)], hx(shade(wrap, 1.4)), 1.6)


static func baby_tuft(fr: Dictionary, col: Color) -> String:
	var t: float = fr["T"]
	return stroke("M%s,%s q-2,-14 10,-14 q6,1 4,8" % [f(CX - 4), f(t + 4)], INK, 6.6) + stroke("M%s,%s q-2,-14 10,-14 q6,1 4,8" % [f(CX - 4), f(t + 4)], hx(col), 3.6)
