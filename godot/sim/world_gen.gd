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


const SCULPT_H := 0.24                  # 창조 3단계 흙 빚기: 손가락으로 올리고 판 높이 (빚기 값 ±1 → 높이 ±0.24)
const CORE_RICH := [0.65, 1.0, 1.45]    # 핵 크기 → 광물 풍부도
const CORE_VEINS := [4, 6, 9]           # 핵 크기 → 광맥 수
const VEIN_KINDS := ["iron", "iron", "coal", "iron", "coal", "gold", "coal", "iron", "coal"]


## 바탕 높이의 잡음 두 겹 (창조 화면의 미리보기와 세상 만들기가 같은 것을 쓴다)
static func noises(seed_v: int) -> Array:
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
	return [nz, nz2]


## 바탕 높이 한 점 (세상 좌표 x, y · 반지름 R): 둘레가 높은 그릇 + 언덕 잡음
static func base_h(nzs: Array, x: float, y: float, R: float) -> float:
	var r := Vector2(x, y).length() / R
	return 0.42 * r * r + 0.16 * (nzs[0] as FastNoiseLite).get_noise_2d(x, y) + 0.035 * (nzs[1] as FastNoiseLite).get_noise_2d(x, y) + 0.2


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
	# 1) 바탕 높이: 4칸 간격으로 그릇 + 잡음 (+ 창조 때 손가락으로 빚은 높낮이) → 고운 칸으로 늘림 (Image.resize, 엔진 안에서 빠르게)
	var cr: Dictionary = o.get("create", {})
	var nzs := noises(seed_v)
	var sculpt: PackedFloat32Array = CreationPlan.sculpt_of(cr)
	var st := 4
	var gs := size / st
	var base := PackedFloat32Array()
	base.resize(gs * gs)
	for gj in gs:
		for gi in gs:
			var x := -R + (gi + 0.5) * st
			var y := -R + (gj + 0.5) * st
			base[gj * gs + gi] = base_h(nzs, x, y, R) + (SCULPT_H * CreationPlan.sample(sculpt, x / R, y / R) if not sculpt.is_empty() else 0.0)
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
	var crng := RandomNumberGenerator.new()        # 창조 선택에 쓰는 난수 (선택이 없으면 쓰지 않음 — 옛 시드의 세상 그대로)
	crng.seed = seed_v * 7 + 11
	var wamt := float(cr.get("water", 0.5))
	# 2b) 창조 6단계: 거인이 뚜껑 안쪽에 찍은 물방울 돌기 (그 아래가 물방울 호수) — 키트 자리와 겹치면 살짝 비켜 둔다
	for dv: Variant in cr.get("drips", []):
		var p := Vector2(float(dv[0]), float(dv[1])) * R * 0.86
		for S in spots:
			if p.distance_to(S) < 48.0:
				p = S + (p - S).normalized() * 48.0 if p.distance_to(S) > 0.01 else S + Vector2(48.0, 0)
		if not ww.inside(p.x, p.y, 30.0):
			p = p.normalized() * (R - 30.0)
		_dip(ww, p, crng.randf_range(5.5, 7.0), crng.randf_range(5.0, 6.5), crng.randf() * PI, 0.36)
		drips.append({"x": p.x, "y": p.y, "name": _name(crng, used_names, NAME_LAKE), "mult": 1.7, "spot": -1, "player": true})
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
	if not cr.is_empty():                          # 창조 4단계: 부은 물의 양 → 큰 분지 수 (물을 많이 부으면 호수가 많다)
		n_p = int(round(lerpf(2.0, 5.0, wamt)))
	var blobs: Array = CreationPlan.water_blobs(cr, seed_v, size) if not cr.is_empty() else []
	tries = 0
	while pours.size() < n_p and tries < 500:
		tries += 1
		var p := Vector2.ZERO
		var mine := false
		if not pours.is_empty() and not blobs.is_empty():   # 거인이 판 골짜기에 고인 물 → 그 자리가 큰 호수
			var bl: Dictionary = blobs.pop_front()
			p = Vector2(float(bl["u"]), float(bl["v"])) * R
			mine = true
			if not ww.inside(p.x, p.y, 40.0) or _near_any(p, spots, 60.0) or _near_drips(p, drips, 40.0) or _near_pours(p, pours, 60.0):
				continue
		elif pours.is_empty():
			var aa := rng.randf() * TAU
			p = spots[0] + Vector2(cos(aa), sin(aa)) * rng.randf_range(52.0, 70.0)
			if not ww.inside(p.x, p.y, 40.0) or _near_drips(p, drips, 35.0) or _near_any(p, spots, 45.0):
				continue
		else:
			p = _rand_disc(rng, R * 0.8)
			if _near_any(p, spots, 70.0) or _near_drips(p, drips, 45.0) or _near_pours(p, pours, 90.0):
				continue
		var gr := crng if mine else rng
		var sx := gr.randf_range(9.0, 15.0) if pours.is_empty() else gr.randf_range(10.0, 20.0)
		var sy := sx * gr.randf_range(0.45, 0.8)
		var dep := gr.randf_range(0.5, 0.62)
		_dip(ww, p, sx, sy, gr.randf() * PI, dep)
		var salty := pours.size() == 0 or gr.randf() < (0.25 if mine else 0.4)
		var add := gr.randf_range(0.36, 0.44)
		if not cr.is_empty():
			add = lerpf(0.30, 0.47, wamt) + gr.randf_range(-0.03, 0.03)
		pours.append({"x": p.x, "y": p.y, "sx": sx, "sy": sy, "add": add, "salty": salty, "name": _name(gr, used_names, NAME_LAKE)})
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
		ww.drip_mult.append(float(d["mult"]) * WorldWater.DRIP_BIG * (lerpf(0.85, 1.2, wamt) if not cr.is_empty() else 1.0))
	ww.grooves = grooves
	ww.groove_k.clear()
	ww.groove_mult.clear()
	for gi in grooves.size():
		var g := grooves[gi]
		ww.groove_k.append(ww.idx(g.x, g.y))
		ww.groove_mult.append(WorldWater.GROOVE_SPOT if gi < river_paths.size() else 1.0)
	# 9) 높이를 1/65536 눈금에 (저장이 작아진다 — WorldPack) → 거친 표 → 처음 물 (물방울 분지·부은 분지를 수면까지) · 암염
	ww.snap_heights()
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
	# 10b) 핵 · 광맥 · 화산 (창조 1단계 — 선택이 없으면 보통 핵)
	_minerals(ww, int(cr.get("core", 1)), seed_v, drips)
	# 11) 뚜껑 닫기 타임랩스: 거친 칸만으로 며칠 (오프라인 간격)
	ww.offline = true
	ww.start_clock = Balance.START_CLOCK
	ww.climate = String(o.get("climate", Balance.CLIMATE_DEFAULT))     # 창조 때 고른 기후대 (HEALTH.md 1.2)
	var days: float = o["settle_days"]
	if days > 0.0:
		ww.advance(days * JarWater.DAY)
	ww.t = 0.0
	ww._hydro_acc = 0.0
	ww.offline = false
	ww.added = 0.0
	ww.removed = 0.0
	ww.close_vapour()                   # 뚜껑이 닫힘 — 이때부터 물은 보존 (water.md: 증발 → 김 → 이슬, 병 밖으로는 뚜껑으로만)
	for b: Dictionary in ww.basins:
		b["area0"] = ww.basin_area(b)
	GreatTrees.place(ww)                # 큰 나무 다섯 (GD 3.0) — 물이 자리 잡은 뒤, 서로·키트 자리·물가에서 멀리
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
		ww.h[k] = WorldPack.snap(lerpf(ww.h[k], mean, f))      # 눈금에 (저장 — WorldPack)


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


# ───────────────────────── 창조 오프닝의 선택 (OPENING 2 · 단계 1·7·7b) ─────────────────────────
## 핵 크기 → 광물 풍부도 · 광맥 (철·석탄·금 — 높은 땅에 드러남) · '크게'면 화산 자리. 암반 컵 단계는 첫 병에서 빠짐 → 광맥은 시드로
static func _minerals(ww: WorldWater, core: int, seed_v: int, drips: Array) -> void:
	core = clampi(core, 0, 2)
	ww.core = core
	ww.mineral_rich = CORE_RICH[core]
	ww.veins.clear()
	ww.volcano = {}
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 13 + 5
	var R := ww.rr
	var cands: Array = []
	for i in 160:
		var p := _rand_disc(r, R * 0.85)
		if _near_any(p, ww.spots, 45.0) or _near_drips(p, drips, 20.0):
			continue
		cands.append([ww.h[ww.idx(p.x, p.y)], p])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var picked: Array[Vector2] = []
	for c: Array in cands:
		if ww.veins.size() >= CORE_VEINS[core]:
			break
		var p: Vector2 = c[1]
		if _near_any(p, picked, 50.0):
			continue
		picked.append(p)
		var kind: String = VEIN_KINDS[ww.veins.size() % VEIN_KINDS.size()]
		ww.veins.append({"kind": kind, "x": p.x, "y": p.y, "r": r.randf_range(4.0, 7.0), "amt": ww.mineral_rich * (0.5 if kind == "gold" else 1.0)})
	if core == 2:
		for c: Array in cands:
			var p: Vector2 = c[1]
			if not _near_any(p, ww.spots, 110.0) and not _near_any(p, picked, 20.0):
				ww.volcano = {"x": p.x, "y": p.y}
				break


## 씨앗 · 들짐승 · 물고기 (단계 7·7b) — 세상이 다 만들어진 뒤에 얹는다 (물이 다시 흐를 필요 없음). 결정론: 같은 선택 + 시드 → 같은 결과.
## cr = CreationPlan.gen_opts()["create"] (씨앗 {moss, grass, tree: [[u, v]…]} · animals [u, v] · fish [u, v] — 비면 알아서)
static func apply_life(ww: WorldWater, cr: Dictionary) -> void:
	var R := ww.rr
	var r := RandomNumberGenerator.new()
	r.seed = ww.seed_v * 17 + 3
	var seeds: Dictionary = cr.get("seeds", {})
	# 나무 → 숲 (가까운 점은 한 숲으로). 거인이 뿌린 숲이 있으면 먼 무작위 숲을 그만큼 줄인다
	var mine: Array[Dictionary] = []
	for pt: Array in _clusters(seeds.get("tree", []), 0.09):
		var p := Vector2(float(pt[0]), float(pt[1])) * R * CreationPlan.REACH
		if not ww.inside(p.x, p.y, 8.0) or ww.depth(ww.idx(p.x, p.y)) > 0.01 or _near_any(p, ww.spots, 22.0):
			continue
		if not GreatTrees.near(ww, p, 6.0).is_empty():      # 큰 나무 줄기 둘레는 비움
			continue
		mine.append({"x": p.x, "y": p.y, "r": clampf(6.0 + float(pt[2]) * 1.6, 6.0, 16.0), "dens": 0.85, "spot": -1, "sown": true})
	if not mine.is_empty():
		var keep_far := maxi(10, 40 - mine.size() * 2)
		var kept: Array[Dictionary] = []
		var far_n := 0
		for f in ww.forests:
			if int(f.get("spot", -1)) >= 0:
				kept.append(f)
			elif far_n < keep_far:
				kept.append(f)
				far_n += 1
		kept.append_array(mine)
		ww.forests = kept
	ww.meadows.clear()
	for pt: Array in _clusters(seeds.get("grass", []), 0.08):
		var p := Vector2(float(pt[0]), float(pt[1])) * R * CreationPlan.REACH
		ww.meadows.append({"x": p.x, "y": p.y, "r": clampf(8.0 + float(pt[2]) * 2.0, 8.0, 22.0)})
	if ww.meadows.is_empty():                       # 풀씨를 안 뿌리면 키트 자리 둘레에 들판 (기본)
		for S in ww.spots:
			ww.meadows.append({"x": S.x, "y": S.y, "r": 26.0})
	ww.moss.clear()
	for pt: Array in _clusters(seeds.get("moss", []), 0.08):
		var p := Vector2(float(pt[0]), float(pt[1])) * R * CreationPlan.REACH
		ww.moss.append({"x": p.x, "y": p.y, "r": clampf(6.0 + float(pt[2]) * 1.5, 6.0, 16.0)})
	# 들짐승 (WILDLIFE.md 1 — 서식지대로): 놓은 곳에서 가까운 숲부터
	var drop := Vector2.ZERO
	var av: Array = cr.get("animals", [])
	if av.size() == 2:
		drop = Vector2(float(av[0]), float(av[1])) * R * CreationPlan.REACH
	elif not ww.spots.is_empty():
		drop = ww.spots[0]
	ww.wildlife = wildlife_plan(ww, drop, r)
	# 물고기: 기울인 호수(민물)에 많이 + 다른 민물 호수에도 조금씩 (강을 따라 퍼진다)
	ww.fish.clear()
	var fv: Array = cr.get("fish", [])
	var lakes := fresh_lakes(ww)
	var best := -1
	if fv.size() == 2:
		var fp := Vector2(float(fv[0]), float(fv[1])) * R * CreationPlan.REACH
		for i in lakes.size():
			if best < 0 or (lakes[i]["p"] as Vector2).distance_to(fp) < (lakes[best]["p"] as Vector2).distance_to(fp):
				best = i
	elif not lakes.is_empty():
		best = 0
	for i in lakes.size():
		var c: Vector2 = lakes[i]["p"]
		ww.fish.append({"name": lakes[i]["name"], "x": c.x, "y": c.y, "n": 30 if i == best else 8 + r.randi() % 6})
	ww.creation = cr.duplicate(true)
	ww.creation.erase("sculpt")
	ww.creation["myth"] = CreationPlan.myth_of(cr)


## 들짐승 무리 자리: 사슴·토끼 = 놓은 곳 가까운 숲·숲 가장자리 · 늑대 = 깊은 숲(큰 숲, 키트 자리에서 먼) · 멧돼지 = 숲 ·
## 들양 = 높은 언덕 · 들소 = 넓은 초원(숲에서 먼 평지)
static func wildlife_plan(ww: WorldWater, drop: Vector2, r: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fs := ww.forests.duplicate()
	fs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a["x"], a["y"]).distance_to(drop) < Vector2(b["x"], b["y"]).distance_to(drop))
	for i in mini(3, fs.size()):
		var f: Dictionary = fs[i]
		out.append({"kind": "deer", "x": float(f["x"]), "y": float(f["y"]), "n": 4 + r.randi() % 3})
	for i in mini(2, fs.size()):
		var f: Dictionary = fs[i]
		var a := r.randf() * TAU
		var p := Vector2(f["x"], f["y"]) + Vector2(cos(a), sin(a)) * (float(f["r"]) + 6.0)
		out.append({"kind": "rabbit", "x": p.x, "y": p.y, "n": 6 + r.randi() % 4})
	if not fs.is_empty():
		var f: Dictionary = fs[mini(3, fs.size() - 1)]
		out.append({"kind": "boar", "x": float(f["x"]), "y": float(f["y"]), "n": 3 + r.randi() % 2})
	var deep: Dictionary = {}
	var deep_s := -1.0
	for f: Dictionary in ww.forests:
		var p := Vector2(f["x"], f["y"])
		var far := 1.0e9
		for S in ww.spots:
			far = minf(far, p.distance_to(S))
		var s := float(f["r"]) * minf(far, 250.0)
		if s > deep_s:
			deep_s = s
			deep = f
	if not deep.is_empty():
		out.append({"kind": "wolf", "x": float(deep["x"]), "y": float(deep["y"]), "n": 3 + r.randi() % 3})
	var hill := Vector2.ZERO
	var hill_h := -1.0e9
	var plain := Vector2.ZERO
	var plain_s := -1.0e9
	for i in 120:
		var p := _rand_disc(r, ww.rr * 0.85)
		var k := ww.idx(p.x, p.y)
		if ww.depth(k) > 0.002:
			continue
		var hh := ww.h[k]
		if hh > hill_h:
			hill_h = hh
			hill = p
		var nf := 1.0e9
		for f: Dictionary in ww.forests:
			nf = minf(nf, Vector2(f["x"], f["y"]).distance_to(p) - float(f["r"]))
		var s := minf(nf, 60.0) - absf(hh - 0.35) * 80.0
		if s > plain_s:
			plain_s = s
			plain = p
	out.append({"kind": "sheep", "x": hill.x, "y": hill.y, "n": 5 + r.randi() % 3})
	out.append({"kind": "aurochs", "x": plain.x, "y": plain.y, "n": 3 + r.randi() % 2})
	return out


## 민물 호수들 [{name, p: Vector2}] (물방울 호수 + 부은 분지 중 짜지 않은 것)
static func fresh_lakes(ww: WorldWater) -> Array:
	var out: Array = []
	for d: Dictionary in ww.drips:
		var p := Vector2(d["x"], d["y"])
		if ww.depth(ww.idx(p.x, p.y)) > 0.01 and not lake_salty(ww, p):
			out.append({"name": d["name"], "p": p})
	for b: Dictionary in ww.basins:
		var p := Vector2(b["x"], b["y"])
		if ww.depth(ww.idx(p.x, p.y)) > 0.01 and not lake_salty(ww, p):
			out.append({"name": b["name"], "p": p})
	return out


## 그 자리 물이 짠가 (물고기가 못 삶) — 주민의 나루터 판정과 같은 문턱
static func lake_salty(ww: WorldWater, p: Vector2) -> bool:
	for k in ww.cells_near(p, 4.0):
		if ww.depth(k) > 0.004 and ww.salt_k(k) > 0.0015:
			return true
	return false


## 점들([u, v]…)을 가까운 것끼리 묶는다 → [[u, v, 개수]…] (먼저 온 순서 — 결정론)
static func _clusters(pts: Array, d: float) -> Array:
	var out: Array = []
	for pv: Variant in pts:
		var p := Vector2(float(pv[0]), float(pv[1]))
		var hit := false
		for c: Array in out:
			var cc := Vector2(float(c[0]), float(c[1]))
			if cc.distance_to(p) < d:
				var n := float(c[2])
				var m := (cc * n + p) / (n + 1.0)
				c[0] = m.x
				c[1] = m.y
				c[2] = n + 1.0
				hit = true
				break
		if not hit:
			out.append([p.x, p.y, 1.0])
	return out
