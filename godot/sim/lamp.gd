## 등불 옮기기 — 기획서 4.6 (v4.2: '병 돌리기'를 바꿈) · ROADMAP A11. 순수 계산 (화면은 view/lamp_ctl.gd).
## 등불(해)은 병 둘레 네 자리 중 하나 — 자리 번호 = 물(JarWater/WorldWater)의 rot (0 처음 창가 · 1 · 2 · 3, 한 번 옮길 때마다
## 빛이 (x, y) → (y, −x)로 돈다 — WorldWater.rotate_jar · JarWater.rotate_jar와 같은 뜻). 기본 카메라(방위 45°)에서 보면
## 0 = 뒤(북서) · 1 = 왼쪽(남서) · 2 = 앞(남동) · 3 = 오른쪽(북동).
## 미리보기 (preview): 옮긴 뒤의 빛으로 시뮬레이션과 같은 식을 미리 계산한다 — 볕·그늘 (WorldWater._sunw), 골마다 물
## (WorldWater._groove_rate · JarWater.hydro_step의 그늘^1.5 — 굵어짐 ↑ · 가늘어짐 ↓ · 새로 생김 · 마름), 호수 자리의 따뜻함 (증발 ▲▼),
## 마을의 밭 (Village.farm_mult와 같은 식), 집 (따뜻함), 마을 곁 강 (골에서 물길을 따라 내려가 마을에 닿는 골의 변화).
## 숫자는 보여 주지 않는다 — 화면은 화살표·색·말 (lines, 1~3문장).
class_name Lamp
extends RefCounted

const SPOT_NAMES := ["뒤", "왼쪽", "앞", "오른쪽"]
const MIN_FLUX := 0.03                  # 폭포가 보이는 물 (view/waterfalls.gd MIN_FLUX와 같은 값)
const DIRS8 := ["동", "남동", "남", "남서", "서", "북서", "북", "북동"]   # x 동쪽 · y 남쪽 (병 데이터 좌표)


## 지금 등불 자리 (0~3)
static func spot(w: JarWater) -> int:
	return posmod(w.rot, 4)


## 지금 빛 방향 (창가 쪽 — 볕 = 이 방향으로 갈수록) · 소형 병은 데이터가 돌고 빛은 그대로
static func light_of(w: JarWater) -> Vector2:
	return (w as WorldWater).light if w is WorldWater else JarWater.LIGHT


## dir 자리로 옮긴 뒤의 빛 (같은 물건 기준 — 소형 병은 데이터가 도는 만큼 빛을 거꾸로 돌린 것과 같다)
static func light_after(w: JarWater, dir: int) -> Vector2:
	var l := light_of(w)
	for i in posmod(dir - spot(w), 4):
		l = Vector2(l.y, -l.x)
	return l


## 빛 l 아래 (x, y)의 볕 −1 그늘 끝 ~ 1 창가
static func sun(w: JarWater, l: Vector2, x: float, y: float) -> float:
	return (x * l.x + y * l.y) / w.radius()


static func warm(s: float) -> float:
	return clampf(0.5 + 0.55 * s, 0.0, 1.0)


## 골 i의 물 (그늘 골 하나 = 1 기준, 골 배율 곱함) — 시뮬레이션이 골에 넣는 물과 같은 비율 (view/waterfalls.gd flux_norm)
static func groove_flux(w: JarWater, l: Vector2, i: int) -> float:
	var g: Vector2 = w.grooves[i]
	var wm := warm(sun(w, l, g.x, g.y))
	if w is WorldWater:
		var ww := w as WorldWater
		var mult := ww.groove_mult[i] if i < ww.groove_mult.size() else 1.0
		return (WorldWater.GROOVE_BASE + pow(1.0 - wm, 1.5)) * mult
	return pow(1.0 - wm, 1.5)


## 골의 변화: up(굵어짐) · down(가늘어짐) · new(새로 생김) · gone(마름) · same
static func change_of(now: float, nw: float) -> String:
	if now < MIN_FLUX and nw >= MIN_FLUX:
		return "new"
	if now >= MIN_FLUX and nw < MIN_FLUX:
		return "gone"
	if now < MIN_FLUX:
		return "same"
	var r := nw / now
	if r >= Balance.LAMP_UP:
		return "up"
	if r <= Balance.LAMP_DOWN:
		return "down"
	return "same"


## 방향 말 (병 데이터 좌표의 벡터 → "북서")
static func dir_word(d: Vector2) -> String:
	if d.length() < 1e-4:
		return ""
	var a := fposmod(atan2(d.y, d.x), TAU)
	return DIRS8[int(roundf(a / (TAU / 8.0))) % 8]


## 미리보기 — villages = 같은 병의 무리들 (소형 병은 [v]). dir = 옮길 자리 (0~3).
## {from, to, l0, l1, gain: "남동", lose: "북서", gullies: [{p, i, now, new, change, side}], lakes: [{p, name, change}],
##  places: [{p, kind: farm/house/river, change: up/down, text, sid}], lines: [1~3문장], up, down, new, gone}
static func preview(villages: Array, w: JarWater, dir: int) -> Dictionary:
	dir = posmod(dir, 4)
	var l0 := light_of(w)
	var l1 := light_after(w, dir)
	var out := {"from": spot(w), "to": dir, "l0": l0, "l1": l1, "gullies": [], "lakes": [], "places": [], "lines": [],
		"up": 0, "down": 0, "new": 0, "gone": 0}
	if dir == spot(w):
		return out
	var gain := dir_word(l1 - l0)
	var lose := dir_word(l0 - l1)
	out["gain"] = gain
	out["lose"] = lose
	# 골마다
	var up_s := Vector2.ZERO
	var down_s := Vector2.ZERO
	for i in w.grooves.size():
		var g: Vector2 = w.grooves[i]
		var a := groove_flux(w, l0, i)
		var b := groove_flux(w, l1, i)
		var ch := change_of(a, b)
		(out["gullies"] as Array).append({"p": g, "i": i, "now": a, "new": b, "change": ch, "side": dir_word(g)})
		if ch == "up" or ch == "new":
			up_s += g.normalized()
		elif ch == "down" or ch == "gone":
			down_s += g.normalized()
		if ch != "same":
			out[ch] = int(out[ch]) + 1
	# 호수 (증발 — 볕을 받으면 줄고, 그늘이 되면 는다)
	for lk: Dictionary in _lakes(w):
		var p: Vector2 = lk["p"]
		var dw := warm(sun(w, l1, p.x, p.y)) - warm(sun(w, l0, p.x, p.y))
		if absf(dw) >= Balance.LAMP_LAKE:
			(out["lakes"] as Array).append({"p": p, "name": lk["name"], "big": bool(lk.get("big", false)), "change": "down" if dw > 0.0 else "up"})
	# 마을
	var feeds := _feeding(w, villages)
	var village_line := ""
	var farm_line := ""
	var house_line := ""
	for v: Village in villages:
		# 마을 곁 강: 이 마을에 닿는 골의 물 합
		var a0 := 0.0
		var a1 := 0.0
		for gi: int in feeds.get(v.sid, []):
			a0 += groove_flux(w, l0, gi)
			a1 += groove_flux(w, l1, gi)
		if a0 > 0.0 or a1 > 0.0:
			var rc := change_of(a0, a1)
			if rc != "same":
				var upish := rc == "up" or rc == "new"
				var txt := "마을 곁 강이 굵어져요" if upish else "마을 곁 강이 가늘어져요"
				if rc == "new":
					txt = "마을 곁에 새 강이 흘러와요"
				elif rc == "gone":
					txt = "마을 곁 강이 말라요"
				(out["places"] as Array).append({"p": v.center, "kind": "river", "change": "up" if upish else "down", "text": txt, "sid": v.sid})
				if village_line == "":
					village_line = txt + (" (물고기·밭에 좋아요)" if upish else " (밭이 마를 수 있어요)") if villages.size() == 1 else "%s: %s" % [v.settlement_name, txt]
		# 밭
		var worst: Dictionary = {}
		for b in v.buildings:
			if b.type != "농장" or not b.built:
				continue
			var f0 := farm_pred(v, b.x, b.y, l0)
			var f1 := farm_pred(v, b.x, b.y, l1)
			var r := f1 / maxf(0.01, f0)
			if absf(r - 1.0) < Balance.LAMP_FARM:
				continue
			var owner := v.person(b.worker)
			var nm := ("%s네 밭" % owner.name) if owner != null else "마을 밭"
			var dn := r < 1.0
			var txt2 := ("%s이 그늘이 돼요 (농사 ↓)" if dn else "%s에 볕이 들어요 (농사 ↑)") % nm
			(out["places"] as Array).append({"p": Vector2(b.x, b.y), "kind": "farm", "change": "down" if dn else "up", "text": txt2, "sid": v.sid})
			if worst.is_empty() or absf(r - 1.0) > float(worst["d"]):
				worst = {"d": absf(r - 1.0), "text": txt2}
		if not worst.is_empty() and farm_line == "":
			farm_line = String(worst["text"])
		# 집 (따뜻함)
		var dw2 := warm(sun(w, l1, v.center.x, v.center.y)) - warm(sun(w, l0, v.center.x, v.center.y))
		if absf(dw2) >= 0.08:
			var cold := dw2 < 0.0
			for b in v.buildings:
				if b.is_house() and b.built:
					(out["places"] as Array).append({"p": Vector2(b.x, b.y), "kind": "house", "change": "down" if cold else "up",
						"text": "집이 서늘해져요" if cold else "집이 따뜻해져요", "sid": v.sid})
			if house_line == "":
				house_line = "마을이 그늘에 들어 집이 서늘해져요 (땔감 ↑)" if cold else "마을에 볕이 들어 집이 따뜻해져요"
	# 말 (1~3문장)
	var lines: Array = []
	if gain != "" and lose != "":
		lines.append("%s쪽이 그늘이 되고 %s쪽에 볕이 들어요." % [lose, gain])
	var rl := ""
	if int(out["up"]) + int(out["new"]) > 0:
		var side := dir_word(up_s)
		rl = "그늘이 된 %s쪽 벽에서 물이 많아져 강이 굵어져요." % side if side != "" else "그늘진 벽에서 물이 많아져 강이 굵어져요."
	if int(out["down"]) + int(out["gone"]) > 0:
		var side2 := dir_word(down_s)
		rl += (" " if rl != "" else "") + ("%s쪽 강은 말라요." % side2 if side2 != "" else "볕 든 쪽 강은 말라요.")
	if rl != "":
		lines.append(rl)
	for cand: String in [village_line, farm_line, house_line]:
		if cand != "" and lines.size() < 3:
			lines.append(cand + ("." if not cand.ends_with(")") and not cand.ends_with(".") else ""))
	if lines.size() < 3:
		for lk: Dictionary in out["lakes"]:
			var lp: Vector2 = lk["p"]
			lines.append(("볕을 받는 %s쪽 호수가 빨리 줄어요." if lk["change"] == "down" else "그늘이 된 %s쪽 호수가 천천히 불어요.") % dir_word(lp))
			break
	out["lines"] = lines
	return out


## 미리 셈한 밭 배율 (Village.farm_mult와 같은 식 — 볕만 l로 바꿔서)
static func farm_pred(v: Village, x: float, y: float, l: Vector2) -> float:
	var s := sun(v.water, l, x, y)
	var wm := warm(s)
	var m := clampf(0.12 + v.water.wet_k(v.water.idx(x, y)) * 0.9 - 0.1 * s, 0.0, 1.0)
	return clampf((0.6 + 0.6 * wm) * (0.65 + 0.7 * m) / (1.0 + v.salt_at(x, y) * 300.0), 0.15, 1.5)


## 호수 자리: 넓은 세상 = 이름 붙은 호수 (features), 소형 병 = 물방울 호수·큰 호수 (basins · drips)
static func _lakes(w: JarWater) -> Array:
	var out: Array = []
	if w is WorldWater:
		for f: Dictionary in (w as WorldWater).features:
			if String(f["kind"]) == "lake":
				out.append({"p": Vector2(float(f["x"]), float(f["y"])), "name": String(f["name"]), "big": float(f.get("r", 0.0)) >= 8.0})
		return out
	for b: Dictionary in w.basins:
		out.append({"p": Vector2(float(b["x"]), float(b["y"])), "name": String(b.get("name", "")), "big": true})
	return out


## 골에서 물길(가장 낮은 이웃 수면)을 따라 내려가 무리의 영역에 닿는 골 → {sid: [골 번호]}
static func _feeding(w: JarWater, villages: Array) -> Dictionary:
	var out := {}
	var stepl := 4.0 if w is WorldWater else 1.0
	var max_n := 260 if w is WorldWater else 90
	for i in w.grooves.size():
		var p: Vector2 = w.grooves[i]
		p -= p.normalized() * stepl          # 벽 바로 안쪽에서
		var seen := {}
		for n in max_n:
			for v: Village in villages:
				if not seen.has(v.sid) and p.distance_to(v.center) <= v.territory_r() + 4.0:
					seen[v.sid] = true
					if not out.has(v.sid):
						out[v.sid] = []
					(out[v.sid] as Array).append(i)
			var s0 := _surf(w, p)
			var best := p
			var bs := s0
			for k in 8:
				var a := TAU * k / 8.0
				var q := p + Vector2(cos(a), sin(a)) * stepl
				if not w.inside(q.x, q.y, 1.0):
					continue
				var sq := _surf(w, q)
				if sq < bs:
					bs = sq
					best = q
			if best == p:
				break
			p = best
	return out


static func _surf(w: JarWater, p: Vector2) -> float:
	var k := w.idx(p.x, p.y)
	return w.ground(k) + w.depth(k)


## 연대기 한 줄 (옮긴 뒤): "해가 서쪽으로 옮겨 갔다. 동쪽 벽의 샘이 불어나 새 강이 생겼다."
static func chronicle(pv: Dictionary) -> String:
	var gain := String(pv.get("gain", ""))
	var s := "땅이 흔들리지도 않았는데 해가 %s쪽으로 옮겨 갔다." % gain if gain != "" else "땅이 흔들리지도 않았는데 해가 하늘을 건너 옮겨 갔다."
	var ups := Vector2.ZERO
	for g: Dictionary in pv.get("gullies", []):
		if g["change"] == "up" or g["change"] == "new":
			ups += (g["p"] as Vector2).normalized()
	if int(pv.get("new", 0)) > 0:
		s += " %s쪽 벽의 샘이 불어나 새 강이 생겼다." % dir_word(ups)
	elif int(pv.get("up", 0)) > 0:
		s += " 그늘이 된 %s쪽 벽을 타고 물줄기가 굵게 흘러내리기 시작했다." % dir_word(ups)
	if int(pv.get("down", 0)) + int(pv.get("gone", 0)) > 0:
		s += " 볕이 든 쪽 강은 가늘어졌다."
	return s
