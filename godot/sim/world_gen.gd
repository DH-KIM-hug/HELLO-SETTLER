## 넓은 세상 만들기 — 기획서 v3.8 3.1·3.3(메이슨 자)·4.2·4.3·4.5·5.1 (창조할 때마다 새 무작위 시드). 6단계.
## 시드가 같으면 늘 같은 세상 (테스트는 정한 시드). 새 세상을 만들 때는 new_seed()로 새 시드를 뽑는다.
##
## 만드는 것 (모두 WorldWater에):
##   높이: 둘레가 높은 그릇 + 언덕(잡음 두 겹) + 물방울 호수 분지 + 창조 때 물을 부은 큰 분지 + 강 골짜기
##   좋은 키트 자리 (spots, 기본 4곳): 곁에 물방울 호수 하나 + 세상 끝 벽에서 흘러와 그 호수로 드는 강 하나 + 숲 두 무리 + 바위
##   물방울 돌기 8~12 (메이슨 자) · 유리벽의 골 · 처음 호수 · 암염(일부 큰 분지 밑, 강 하나 위) · 먼 숲 · 발견할 것(호수·강·흰 바위)
##   마지막에 '뚜껑 닫기 타임랩스'(기획서 5.1 단계 6): 거친 칸으로 며칠을 흘려 호수가 차고 강이 생기게 한다.
class_name WorldGen
extends RefCounted

const NAME_A := ["푸른", "고요한", "둥근", "깊은", "작은", "긴", "하얀", "별빛", "안개", "달빛", "버들", "갈대", "맑은", "은빛", "바람", "이슬", "조약돌", "새벽", "노을", "구름"]
const NAME_LAKE := ["호수", "못", "늪", "거울 호수"]
const NAME_RIVER := ["강", "내", "시내"]
const MAX_CUT := 0.25                   # 강 골짜기를 땅보다 가장 깊이 파는 정도 (높이 단위, 화면 ×6)
const VALLEY_R := 16.0                 # 골짜기 둘레 (완만한 비탈)


static func new_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return int(r.randi() & 0x7fffffff)


static func default_opts() -> Dictionary:
	return {"bumps": 10, "grooves": 14, "spots": 4, "pours": 4, "forests": 40, "settle_days": 2.0}


static func generate(seed_v: int, size := 1024, opts: Dictionary = {}) -> WorldWater:
	var o := default_opts()
	o.merge(opts, true)
	var ww := WorldWater.new()
	ww.seed_v = seed_v
	ww.setup(size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var used_names := {}
	var R := ww.rr
	# 1) 바탕 높이: 4칸 간격으로 그릇 + 잡음 → 고운 칸으로 늘림 (Image.resize, 엔진 안에서 빠르게)
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 1.0 / 170.0
	nz.fractal_octaves = 3
	var nz2 := FastNoiseLite.new()
	nz2.seed = seed_v + 7
	nz2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz2.frequency = 1.0 / 45.0
	nz2.fractal_octaves = 2
	var st := 4
	var gs := size / st
	var base := PackedFloat32Array()
	base.resize(gs * gs)
	for gj in gs:
		for gi in gs:
			var x := -R + (gi + 0.5) * st
			var y := -R + (gj + 0.5) * st
			var r := Vector2(x, y).length() / R
			base[gj * gs + gi] = 0.42 * r * r + 0.16 * nz.get_noise_2d(x, y) + 0.035 * nz2.get_noise_2d(x, y) + 0.2
	var img := Image.create_from_data(gs, gs, false, Image.FORMAT_RF, base.to_byte_array())
	img.resize(size, size, Image.INTERPOLATE_CUBIC)
	ww.h = img.get_data().to_float32_array()
	var H := ww.h
	# 2) 좋은 키트 자리
	var spots: Array[Vector2] = []
	var a0 := rng.randf() * TAU
	var n_sp: int = o["spots"]
	for i in n_sp:
		var a := a0 + TAU * i / n_sp + rng.randf_range(-0.3, 0.3)
		var rad := R * rng.randf_range(0.56, 0.74)
		spots.append(Vector2(cos(a), sin(a)) * rad)
	var drips: Array[Dictionary] = []
	var river_paths: Array = []
	var orig := ww.h.duplicate()        # 강 골짜기는 판 적 없는 땅 높이를 기준으로 (겹쳐 파며 점점 깊어지지 않게)
	for si in spots.size():
		var S := spots[si]
		var out := S.normalized()
		# 물방울 호수: 자리에서 27칸 (벽 쪽이 아닌 옆으로)
		var la := atan2(out.y, out.x) + PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0) + rng.randf_range(-0.6, 0.6)
		var D := S + Vector2(cos(la), sin(la)) * 27.0
		_dip(ww, D, rng.randf_range(6.0, 7.5), rng.randf_range(5.0, 6.5), rng.randf() * PI, 0.34)
		drips.append({"x": D.x, "y": D.y, "name": _name(rng, used_names, NAME_LAKE), "mult": 1.5, "spot": si})
		# 강: 자리 쪽 세상 끝 벽의 골 → 자리 옆을 지나 → 물방울 호수로
		var ga := atan2(out.y, out.x) + rng.randf_range(-0.22, 0.22)
		var G := Vector2(cos(ga), sin(ga)) * (R - 1.5)
		var side := (D - S).normalized()
		var P := S + Vector2(-side.y, side.x) * (14.0 if rng.randf() < 0.5 else -14.0) + side * 4.0
		var pts := _carve_river(ww, orig, rng, [G, P, D + (P - D).normalized() * 5.0])   # 호수 가장자리까지 (호수는 둥글게 남김)
		river_paths.append({"pts": pts, "groove": G, "name": _name(rng, used_names, NAME_RIVER)})
		# 숲 두 무리 + 바위
		for f in 2:
			var fa := atan2(-side.y, -side.x) + rng.randf_range(-0.9, 0.9)
			var fp := S + Vector2(cos(fa), sin(fa)) * rng.randf_range(12.0, 18.0)
			ww.forests.append({"x": fp.x, "y": fp.y, "r": rng.randf_range(5.5, 7.5), "dens": 0.75, "spot": si})
		for k in 3:
			var ra := rng.randf() * TAU
			ww.rock_spots.append(S + Vector2(cos(ra), sin(ra)) * rng.randf_range(10.0, 17.0))
	ww.spots = spots
	# 3) 나머지 물방울 돌기 (메이슨 자 8~12)
	var n_b: int = o["bumps"]
	var tries := 0
	while drips.size() < n_b and tries < 500:
		tries += 1
		var p := _rand_disc(rng, R * 0.88)
		if _near_any(p, spots, 60.0) or _near_drips(p, drips, 50.0):
			continue
		_dip(ww, p, rng.randf_range(4.5, 6.5), rng.randf_range(4.0, 6.0), rng.randf() * PI, rng.randf_range(0.26, 0.36))
		drips.append({"x": p.x, "y": p.y, "name": _name(rng, used_names, NAME_LAKE), "mult": rng.randf_range(1.0, 1.8), "spot": -1})
	# 4) 창조 때 물을 부은 큰 분지 (물이 안 들어오면 언젠가 마른다). 첫 자리 곁 하나는 암염 위 — 마르면 소금 들판
	var pours: Array[Dictionary] = []
	var n_p: int = o["pours"]
	tries = 0
	while pours.size() < n_p and tries < 500:
		tries += 1
		var p := Vector2.ZERO
		if pours.is_empty():
			var aa := rng.randf() * TAU
			p = spots[0] + Vector2(cos(aa), sin(aa)) * rng.randf_range(52.0, 70.0)
			if not ww.inside(p.x, p.y, 40.0) or _near_drips(p, drips, 35.0) or _near_any(p, spots, 45.0):
				continue
		else:
			p = _rand_disc(rng, R * 0.8)
			if _near_any(p, spots, 70.0) or _near_drips(p, drips, 45.0) or _near_pours(p, pours, 90.0):
				continue
		var sx := rng.randf_range(9.0, 15.0) if pours.is_empty() else rng.randf_range(10.0, 20.0)
		var sy := sx * rng.randf_range(0.45, 0.8)
		var dep := rng.randf_range(0.5, 0.62)
		_dip(ww, p, sx, sy, rng.randf() * PI, dep)
		var salty := pours.size() == 0 or rng.randf() < 0.4
		pours.append({"x": p.x, "y": p.y, "sx": sx, "sy": sy, "add": rng.randf_range(0.36, 0.44), "salty": salty, "name": _name(rng, used_names, NAME_LAKE)})
		if salty:
			ww.seams.append({"x": p.x, "y": p.y, "r": sx * 0.75, "amt": 0.03})
	# 5) 나머지 골 (세상 끝 벽)
	var grooves: Array[Vector2] = []
	for rp: Dictionary in river_paths:
		grooves.append(rp["groove"])
	var n_g: int = o["grooves"]
	tries = 0
	while grooves.size() < n_g and tries < 300:
		tries += 1
		var ga := rng.randf() * TAU
		var G := Vector2(cos(ga), sin(ga)) * (R - 1.5)
		var close := false
		for g in grooves:
			if g.distance_to(G) < 70.0:
				close = true
		if close:
			continue
		grooves.append(G)
	# 강 하나 위에 암염 (짠 강 → 그 끝 호수가 짜진다)
	if river_paths.size() > 1:
		var pts: Array = river_paths[1]["pts"]
		var sp: Vector2 = pts[pts.size() / 3]
		ww.seams.append({"x": sp.x, "y": sp.y, "r": 4.0, "amt": 0.02})
	# 6) 키트 자리 평평하게 (호수 수면보다 높게)
	for si in spots.size():
		var D := Vector2(drips[si]["x"], drips[si]["y"])
		var lake_top := H[ww.idx(D.x, D.y)] + 0.3
		flatten(ww, spots[si], 7.0, lake_top + 0.15)
	# 7) 먼 숲
	var n_f: int = o["forests"]
	tries = 0
	while ww.forests.size() < n_f + spots.size() * 2 and tries < 400:
		tries += 1
		var p := _rand_disc(rng, R * 0.92)
		if _near_drips(p, drips, 14.0) or _near_any(p, spots, 40.0):
			continue
		ww.forests.append({"x": p.x, "y": p.y, "r": rng.randf_range(5.0, 14.0), "dens": rng.randf_range(0.4, 0.8), "spot": -1})
	# 8) 물이 들어오는 곳
	ww.drips.clear()
	ww.drip_k.clear()
	ww.drip_mult.clear()
	for d: Dictionary in drips:
		ww.drips.append({"x": d["x"], "y": d["y"], "name": d["name"]})
		ww.drip_k.append(ww.idx(d["x"], d["y"]))
		ww.drip_mult.append(float(d["mult"]) * WorldWater.DRIP_BIG)
	ww.grooves = grooves
	ww.groove_k.clear()
	ww.groove_mult.clear()
	for gi in grooves.size():
		var g := grooves[gi]
		ww.groove_k.append(ww.idx(g.x, g.y))
		ww.groove_mult.append(WorldWater.GROOVE_SPOT if gi < river_paths.size() else 1.0)
	# 9) 거친 표 → 처음 물 (물방울 분지·부은 분지를 수면까지) · 암염
	ww.build_world_tables()
	for d: Dictionary in drips:
		_pour(ww, Vector2(d["x"], d["y"]), 9.0, H[ww.idx(d["x"], d["y"])] + 0.26)
	ww.basins.clear()
	for p: Dictionary in pours:
		var c := Vector2(p["x"], p["y"])
		_pour(ww, c, float(p["sx"]) * 1.6, H[ww.idx(c.x, c.y)] + float(p["add"]))
		ww.basins.append({"name": p["name"], "x": c.x, "y": c.y, "r": float(p["sx"]) * 1.4, "area0": 0})
	for sm: Dictionary in ww.seams:
		_seam(ww, sm)
	# 10) 발견할 것 (안개 칸에 걸어 둠)
	for d: Dictionary in drips:
		ww.add_feature("lake", d["name"], [Vector2(d["x"], d["y"])], 9.0)
	for p: Dictionary in pours:
		ww.add_feature("lake", p["name"], [Vector2(p["x"], p["y"])], float(p["sx"]))
	for rp: Dictionary in river_paths:
		var sample: Array = []
		var pts: Array = rp["pts"]
		for i in range(0, pts.size(), 10):
			sample.append(pts[i])
		ww.add_feature("river", rp["name"], sample, 3.0)
	for g in grooves.slice(river_paths.size()):
		var tr := _trace(ww, g, 500)
		if tr.size() > 30:
			var sample: Array = []
			for i in range(0, tr.size(), 10):
				sample.append(tr[i])
			ww.add_feature("river", _name(rng, used_names, NAME_RIVER), sample, 3.0)
	for sm: Dictionary in ww.seams:
		ww.add_feature("salt", "하얀 바위", [Vector2(sm["x"], sm["y"])], float(sm["r"]))
	# 11) 뚜껑 닫기 타임랩스: 거친 칸만으로 며칠 (오프라인 간격)
	ww.offline = true
	ww.start_clock = Balance.START_CLOCK
	var days: float = o["settle_days"]
	if days > 0.0:
		ww.advance(days * JarWater.DAY)
	ww.t = 0.0
	ww._hydro_acc = 0.0
	ww.offline = false
	ww.added = 0.0
	ww.removed = 0.0
	for b: Dictionary in ww.basins:
		b["area0"] = ww.basin_area(b)
	return ww


## 분지 (기울어진 타원 가우스)
static func _dip(ww: WorldWater, c: Vector2, sxx: float, syy: float, ang: float, d: float) -> void:
	var ext := maxf(sxx, syy) * 3.2
	var cs := cos(ang)
	var sn := sin(ang)
	for k in ww.cells_near(c, ext):
		var dx := ww.cx(k) - c.x
		var dy := ww.cy(k) - c.y
		var u := (dx * cs + dy * sn) / sxx
		var v := (-dx * sn + dy * cs) / syy
		ww.h[k] -= d * exp(-(u * u + v * v) / 2.0)


## 강 골짜기: 꺾은선을 따라 바닥이 늘 내려가게 판다 (강물이 끝까지 흐르도록) → 지나는 점들
static func _carve_river(ww: WorldWater, orig: PackedFloat32Array, rng: RandomNumberGenerator, way: Array) -> Array:
	var pts: Array = []
	var bed := 1.0e9
	var ph := rng.randf() * TAU
	var travelled := 0.0
	for wi in way.size() - 1:
		var a: Vector2 = way[wi]
		var b: Vector2 = way[wi + 1]
		var L := a.distance_to(b)
		var dir := (b - a) / L
		var perp := Vector2(-dir.y, dir.x)
		var steps := int(L / 0.5)
		for s in steps:
			var t := s * 0.5
			var amp := 6.0 * minf(1.0, minf(t, L - t) / 30.0)
			var p := a + dir * t + perp * sin(travelled * 0.045 + ph) * amp
			travelled += 0.5
			if not ww.inside(p.x, p.y, 0.5):
				continue
			var hk := orig[ww.idx(p.x, p.y)]
			# 바닥은 늘 내려가되 땅보다 MAX_CUT 넘게 깊이 파지 않는다 (언덕을 넘을 땐 그 앞에 작은 못이 생겼다가 넘친다)
			bed = maxf(minf(hk - 0.03, bed - 0.0004), hk - MAX_CUT)
			for k in ww.cells_near(p, VALLEY_R):
				var d := Vector2(ww.cx(k) - p.x, ww.cy(k) - p.y).length()
				var target := bed + d * 0.03 if d < 3.0 else bed + 0.09 + (d - 3.0) * 0.016     # V자 바닥 (물이 한 줄로 모여 덜 스며듦)
				if ww.h[k] > target:
					ww.h[k] = target
			if s % 2 == 0:
				pts.append(p)
	return pts


## 자리 둘레를 높이 lv(이상)로 평평하게 — 가장자리는 부드럽게
static func flatten(ww: WorldWater, c: Vector2, r: float, at_least := -1.0e9) -> void:
	var ks := ww.cells_near(c, r)
	if ks.is_empty():
		return
	var mean := 0.0
	for k in ks:
		mean += ww.h[k]
	mean = maxf(mean / ks.size(), at_least)
	for k in ww.cells_near(c, r * 1.8):
		var d := Vector2(ww.cx(k) - c.x, ww.cy(k) - c.y).length()
		var f := 1.0 if d <= r else 1.0 - smoothstep(r, r * 1.8, d)
		ww.h[k] = lerpf(ww.h[k], mean, f)


## 처음 물: 원 (c, rad) 안의 거친 칸을 수면 lv까지
static func _pour(ww: WorldWater, c: Vector2, rad: float, lv: float) -> void:
	var c0i := maxi(0, floori((c.x - rad + ww.rr) / WorldWater.F))
	var c1i := mini(ww.m - 1, floori((c.x + rad + ww.rr) / WorldWater.F))
	var c0j := maxi(0, floori((c.y - rad + ww.rr) / WorldWater.F))
	var c1j := mini(ww.m - 1, floori((c.y + rad + ww.rr) / WorldWater.F))
	for cj in range(c0j, c1j + 1):
		for ci in range(c0i, c1i + 1):
			var q := cj * ww.m + ci
			var a := ww.cA[q]
			if a == 0:
				continue
			var base := q * 64
			var k := 0
			while k < a and ww.hs[base + k] < lv:
				k += 1
			var v := k * lv - ww.pre[q * 65 + k]
			if v > ww.cV[q]:
				ww.cV[q] = v
				ww._relevel(q)


static func _seam(ww: WorldWater, sm: Dictionary) -> void:
	var c := Vector2(sm["x"], sm["y"])
	var r: float = sm["r"]
	for k in ww.cells_near(c, r):
		var d := Vector2(ww.cx(k) - c.x, ww.cy(k) - c.y).length()
		var a := float(sm["amt"]) * (1.0 - d / r)
		var q := ww.coarse_of(k)
		ww.cHal[q] += a
		ww.cNH[q] += 1
	# 물에 잠긴 암염은 처음부터 조금 녹아 있다 (JarWater와 같음)
	for k in ww.cells_near(c, r):
		var q := ww.coarse_of(k)
		if ww.cK[q] > 0 and ww.cHal[q] > 0.0:
			var d := minf(ww.cHal[q] * 0.5, ww.cV[q] * 0.05) / ww.cA[q]
			ww.cHal[q] -= d
			ww.cS[q] += d


## 가장 낮은 이웃을 따라 내려가는 길 (발견할 강의 자리)
static func _trace(ww: WorldWater, from: Vector2, max_n: int) -> Array:
	var out: Array = []
	var k := ww.idx(from.x, from.y)
	for s in max_n:
		out.append(Vector2(ww.cx(k), ww.cy(k)))
		var i := k % ww.n
		var j := k / ww.n
		var best := k
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ii := i + di
				var jj := j + dj
				if jj < 0 or jj >= ww.n or ii < ww.row_i0[jj] or ii >= ww.row_i1[jj]:
					continue
				var q := jj * ww.n + ii
				if ww.h[q] < ww.h[best]:
					best = q
		if best == k:
			break
		k = best
	return out


static func _rand_disc(rng: RandomNumberGenerator, r: float) -> Vector2:
	var a := rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * r


static func _near_any(p: Vector2, list: Array, d: float) -> bool:
	for q: Vector2 in list:
		if q.distance_to(p) < d:
			return true
	return false


static func _near_drips(p: Vector2, list: Array, d: float) -> bool:
	for q: Dictionary in list:
		if Vector2(q["x"], q["y"]).distance_to(p) < d:
			return true
	return false


static func _near_pours(p: Vector2, list: Array, d: float) -> bool:
	return _near_drips(p, list, d)


static func _name(rng: RandomNumberGenerator, used: Dictionary, kinds: Array) -> String:
	for i in 40:
		var nm: String = NAME_A[rng.randi() % NAME_A.size()] + " " + kinds[rng.randi() % kinds.size()]
		if not used.has(nm):
			used[nm] = true
			return nm
	return NAME_A[rng.randi() % NAME_A.size()] + " " + kinds[0]
