## 넓은 세상의 물·소금 — 기획서 v3.8 3.1·4.2~4.6 (6단계). JarWater(소형 병, 64칸)를 잇고 같은 규칙을 넓은 세상에 쓴다.
## 화면과 분리된 순수 로직 (Node 없음). 지름 n칸 (기본 1024) 원반.
##
## 두 단계 계산 (물·소금 총량은 늘 보존):
##   · 고운 칸 (1칸) — 마을 둘레 조각(64×64)만. JarWater.hydro_step과 같은 규칙·같은 칸 순서.
##   · 거친 칸 (8×8칸 = 1 거친 칸) — 나머지 세상 전부. 거친 칸 하나는 물 '부피'를 갖고, 안의 고운 칸 높이를 정렬한 표로
##     수면 높이(L)와 젖은 칸 수(K)를 구한다 (낮은 칸부터 찬다). 흐름은 이웃 거친 칸의 수면으로, 증발은 젖은 칸 수만큼,
##     스며듦은 얕은 칸(수면 − 땅 < SEEP_DEPTH) 수만큼. 8칸씩 묶었으므로 8배 긴 간격(같은 흐름 빠르기)으로, 8줄 묶음씩 번갈아 계산.
##   · 경계: 고운 칸 ↔ 이웃 거친 칸은 (고운 칸 수면) vs (거친 칸 수면 L)으로 서로 주고받는다 (한쪽이 잃은 만큼 다른 쪽이 얻음).
##   · 조각이 고운 ↔ 거친으로 바뀔 때: 거친 → 고운 = 수면 L까지 낮은 칸부터 채움 (부피 정확히 같음), 고운 → 거친 = 합.
## 좌표: 병 중심 기준 세상 좌표 (x 동서, y 남북), 1칸 = 1. 병 돌리기는 데이터를 돌리지 않고 빛(창가 방향)을 반대로 돌린다
##       (같은 뜻 — 화면은 병 노드를 −90°×rot 돌린다). 넓은 세상의 데이터를 통째로 돌리면 백만 칸 복사라 느리다.
class_name WorldWater
extends JarWater

const CH := 64                          # 조각 (고운 칸 64×64)
const F := 8                            # 거친 칸 = 고운 칸 8×8
const CPC := CH / F                     # 조각 한 변의 거친 칸 수
const SLICES := 8                       # 거친 칸은 8줄 묶음씩 번갈아 (고운 계산 한 번마다 한 묶음) → 거친 칸마다 8배 간격
const FOG := 4                          # 안개 칸 = 고운 칸 4×4
const FOG_BLOCK := 32                   # 안개 화면 묶음 (안개 칸 32×32)
const GROOVE_BASE := 0.25               # (정함) 넓은 세상의 골: 볕 드는 쪽도 조금은 흐른다 → 비율 (0.25 + 그늘^1.5)
const GROOVE_SPOT := 12.0               # (정함) 좋은 키트 자리로 흘러가는 강의 골 배율 — 150~220칸을 흘러 물방울 호수에 닿게
const GROOVE_BIG := 12.0                # (정함) 넓은 세상의 골은 강이 먼 길(200칸 넘게)을 흐르도록 소형 병보다 많이
const DRIP_BIG := 1.2                   # (정함) 넓은 세상의 물방울 돌기 (호수 크기 약 60~250칸)
const SEP := 0.000001
const FINE_SEEP := 0.3                  # (정함) 넓은 세상 고운 칸의 스며듦 배율 — 강이 마을 둘레(40~60칸)를 지나 호수에 닿게
const COARSE_SEEP := 0.12               # (정함) 거친 칸의 스며듦 배율 — 거친 칸은 강물을 낮은 칸에 고인 얕은 웅덩이로 보므로
                                        # 그대로 스며들게 하면 강이 거친 칸 두세 개 만에 사라진다 (고운 칸의 강은 좁고 깊어 덜 스며듦)
const OFFLINE_EVERY_BIG := 600.0        # (정함) 넓은 세상을 몰아서 계산할 때 고운 칸 간격 (소형 병 300초의 두 배 — 하루 1.5초 안에 들게)

# 크기
var n := 1024                           # 고운 칸 한 변 (지름)
var rr := 512.0                         # 반지름
var m := 128                            # 거친 칸 한 변
var nc := 16                            # 조각 한 변
var fn := 256                           # 안개 칸 한 변
var seed_v := 0
var row_i0 := PackedInt32Array()        # 줄마다 원 안 칸의 처음 i
var row_i1 := PackedInt32Array()        # 끝 i (+1)

# 거친 칸 (부피 단위 = 고운 칸 1개 × 깊이 1)
var cA := PackedInt32Array()            # 원 안 고운 칸 수
var cV := PackedFloat64Array()          # 물 부피
var cS := PackedFloat64Array()          # 소금 (녹은 + 땅에 남은)
var cHal := PackedFloat64Array()        # 암염
var cNH := PackedInt32Array()           # 암염 있는 고운 칸 수
var cFL := PackedFloat64Array()         # 최근 흐른 양
var cL := PackedFloat64Array()          # 수면 높이 (마른 칸은 가장 낮은 땅)
var cK := PackedInt32Array()            # 젖은 고운 칸 수
var cwarm := PackedFloat32Array()
var cwet := PackedFloat32Array()        # 거친 습기 (0~1)
var hs := PackedFloat32Array()          # 거친 칸마다 고운 칸 높이 정렬 (64개씩, 빈 자리는 큰 값)
var pre := PackedFloat32Array()         # 정렬 높이 누적합 (65개씩)
var c_nbs := PackedInt32Array()         # 거친 이웃 표
var c_nbl := PackedInt32Array()
var c_nbf := PackedInt32Array()         # 그 이웃이 고운 조각일 때 물을 넘겨줄 경계 고운 칸 (−1 = 아니거나 없음)
var c_edge := PackedByteArray()         # 고운 조각과 맞닿은 거친 칸 (1)
var bmode := PackedByteArray()          # 거친 칸(8×8)마다: 0 거친 · 1 고운 (고운 범위는 마을 둘레 원 모양)
var cslices: Array[PackedInt32Array] = []
var _slice_i := 0

# 고운 칸 (h·w·flux·salt·halite·wet_c는 JarWater의 배열을 n×n으로 씀 — 고운 조각 안에서만 살아 있다)
var fcells := PackedInt32Array()
var fwarm := PackedFloat32Array()
var f_nbs := PackedInt32Array()
var f_nbl := PackedInt32Array()         # ≥0 고운 이웃 · <0 = −(거친 칸)−1 (거친 이웃)
var fine_chunks := PackedInt32Array()   # 고운 칸이 하나라도 있는 조각 (습기 계산 단위)
var interest: Array[Dictionary] = []    # 고운 계산이 필요한 곳 {x, y, r} (마을)
var _wet_rr := 0

# 물이 들어오는 곳 (JarWater.drips·grooves에 더해)
var drip_k := PackedInt32Array()
var drip_mult := PackedFloat32Array()
var groove_k := PackedInt32Array()
var groove_mult := PackedFloat32Array()   # 골마다 배율 (키트 자리로 가는 강의 골은 더 많이)

# 빛 (병 좌표에서의 창가 방향 — 병을 돌리면 반대로 돈다)
var light := LIGHT

# 기록
var added := 0.0                        # 들어온 물 (물방울·골)
var removed := 0.0                      # 나간 물 (증발·스며듦)
var cscale := 1.0                       # 마지막 거친 계산 sc

# 세상 (WorldGen이 채움)
var spots: Array[Vector2] = []          # 좋은 키트 자리 (물방울 호수·강·숲 곁)
var forests: Array[Dictionary] = []     # {x, y, r, dens}
var rock_spots: Array[Vector2] = []
var seams: Array[Dictionary] = []       # 암염 {x, y, r, amt}
var kits: Array[Dictionary] = []        # 놓인 키트 {x, y, sid}
# 창조 오프닝의 선택이 남긴 것 (OPENING 2 — WorldGen.generate의 opts["create"] · WorldGen.apply_life). 아직 쓰는 시뮬레이션이 없는 것도 데이터로 둔다
var core := 1                           # 핵 크기 0 작게 · 1 보통 · 2 크게
var mineral_rich := 1.0                 # 광물 풍부도 (핵 크기)
var volcano: Dictionary = {}            # 핵이 '크게'면 화산 자리 {x, y} (재해 시뮬레이션은 나중)
var veins: Array[Dictionary] = []       # 광맥 {kind: iron/coal/gold, x, y, r, amt}
var meadows: Array[Dictionary] = []     # 풀씨를 뿌린 들판 {x, y, r}
var moss: Array[Dictionary] = []        # 이끼를 뿌린 곳 {x, y, r}
var wildlife: Array[Dictionary] = []    # 들짐승 무리 {kind: deer/rabbit/wolf/boar/sheep/aurochs, x, y, n} (WILDLIFE.md 1)
var fish: Array[Dictionary] = []        # 물고기 {name, x, y, n} — 민물 호수만
var creation: Dictionary = {}           # 창조 요약 (핵·물·돌기·씨앗·창세 신화 줄들 — 지구 카드·연대기용)

# 안개·발견
var fog := PackedByteArray()            # 안개 칸마다 본 무리 (비트 = sid)
var fog_center := PackedByteArray()     # 이 칸을 가운데로 이미 걷혔음 (비트 = sid)
var features: Array[Dictionary] = []    # {kind: lake/river/salt, name, x, y, r, seen(비트)}
var feat_idx := {}                      # 안개 칸 → [feature 번호]
var fog_dirty := {}                     # 안개 묶음 번호 → true (화면이 가져가고 지움)
var fog_version := 0


# ───────────────────────── 만들기 ─────────────────────────
## 빈 세상 (높이 0) — WorldGen.generate가 채운다
func setup(size: int) -> void:
	n = size
	rr = n * 0.5
	m = n / F
	nc = n / CH
	fn = n / FOG
	for a: PackedFloat32Array in [h, w, flux, wet_c, salt, halite]:
		a.resize(n * n)
		a.fill(0.0)
	row_i0.resize(n)
	row_i1.resize(n)
	for j in n:
		var y := -rr + j + 0.5
		var lim := rr - 0.4
		if absf(y) > lim:
			row_i0[j] = n
			row_i1[j] = n
			continue
		var half := sqrt(lim * lim - y * y)
		var i0 := ceili(rr - half - 0.5)
		var i1 := floori(rr + half - 0.5)
		while i0 <= i1 and Vector2(-rr + i0 + 0.5, y).length() > lim:
			i0 += 1
		while i1 >= i0 and Vector2(-rr + i1 + 0.5, y).length() > lim:
			i1 -= 1
		row_i0[j] = i0
		row_i1[j] = i1 + 1
	for a: PackedFloat64Array in [cV, cS, cHal, cFL, cL]:
		a.resize(m * m)
		a.fill(0.0)
	for a: PackedInt32Array in [cA, cK, cNH]:
		a.resize(m * m)
		a.fill(0)
	cwarm.resize(m * m)
	cwet.resize(m * m)
	cwet.fill(0.0)
	bmode.resize(m * m)
	bmode.fill(0)
	fog.resize(fn * fn)
	fog.fill(0)
	fog_center.resize(fn * fn)
	fog_center.fill(0)


## 높이를 모두 1/65536 눈금에 (WorldPack — 저장할 때 높이를 정수 차이로 누른다). 화면 ×6으로 0.0001칸 — 보이지 않는다
func snap_heights() -> void:
	for k in h.size():
		h[k] = WorldPack.snap(h[k])


## 높이가 정해진 뒤: 거친 표·이웃·따뜻함
func build_world_tables() -> void:
	hs.resize(m * m * 64)
	pre.resize(m * m * 65)
	for c in m * m:
		_build_coarse_cell(c)
	# 거친 이웃 (8방향, 원 안)
	c_nbs.resize(m * m + 1)
	c_nbl.clear()
	for c in m * m:
		c_nbs[c] = c_nbl.size()
		if cA[c] == 0:
			continue
		var ci := c % m
		var cj := c / m
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if di == 0 and dj == 0:
					continue
				var ii := ci + di
				var jj := cj + dj
				if ii < 0 or jj < 0 or ii >= m or jj >= m:
					continue
				var q := jj * m + ii
				if cA[q] > 0:
					c_nbl.append(q)
	c_nbs[m * m] = c_nbl.size()
	c_nbf.resize(c_nbl.size())
	c_nbf.fill(-1)
	c_edge.resize(m * m)
	c_edge.fill(0)
	_update_warm()
	for c in m * m:
		_relevel(c)
	_rebuild_slices()


## 저장: 거친 칸 높이 정렬표(hs·pre)는 높이(h)에서 다시 만든다 (저장 크기 35 → 27 MB, 압축 전). 큰 격자는 파일에 쓸 때 WorldPack이 누른다
func _save_skip() -> Array:
	return ["hs", "pre"]


func _after_load() -> void:
	hs.resize(m * m * 64)
	pre.resize(m * m * 65)
	for c in m * m:
		_build_coarse_cell(c)


func _build_coarse_cell(c: int) -> void:
	var ci := c % m
	var cj := c / m
	var vals := PackedFloat32Array()
	for jj in F:
		var j := cj * F + jj
		var a := maxi(row_i0[j], ci * F)
		var b := mini(row_i1[j], ci * F + F)
		if b > a:
			vals.append_array(h.slice(j * n + a, j * n + b))
	vals.sort()
	var cnt := vals.size()
	cA[c] = cnt
	var base := c * 64
	var pb := c * 65
	var s := 0.0
	pre[pb] = 0.0
	for i in 64:
		if i < cnt:
			hs[base + i] = vals[i]
			s += vals[i]
		else:
			hs[base + i] = 1.0e6
		pre[pb + i + 1] = s


## 거친 칸의 부피 → 수면 L, 젖은 칸 수 K (낮은 칸부터 찬다)
func _relevel(c: int) -> void:
	var a := cA[c]
	if a == 0:
		return
	var base := c * 64
	var v := cV[c]
	if v <= SEP:
		cK[c] = 0
		cL[c] = hs[base]
		return
	var pb := c * 65
	# k칸을 hs[k−1] 높이까지 채우는 부피 = k·hs[k−1] − pre[k] (k가 클수록 큼) → 이 값 ≤ v 인 가장 큰 k
	var lo := 1
	var hi := a
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if mid * hs[base + mid - 1] - pre[pb + mid] <= v:
			lo = mid
		else:
			hi = mid - 1
	cK[c] = lo
	cL[c] = (v + pre[pb + lo]) / lo


## 수면 L 아래 얕은 칸 수 (L − 땅 < d)
func _shallow(c: int, d: float) -> int:
	var k := cK[c]
	if k == 0:
		return 0
	var base := c * 64
	var lim := cL[c] - d
	# hs[0..k) 중 lim 이하인 개수
	var lo := 0
	var hi := k
	while lo < hi:
		var mid := (lo + hi) >> 1
		if hs[base + mid] <= lim:
			lo = mid + 1
		else:
			hi = mid
	return k - lo


func _update_warm() -> void:
	for c in m * m:
		cwarm[c] = clampf(0.5 + 0.55 * _sunw(-rr + (c % m + 0.5) * F, -rr + (c / m + 0.5) * F), 0.0, 1.0)
	fwarm.resize(fcells.size())
	for i in fcells.size():
		var k := fcells[i]
		fwarm[i] = clampf(0.5 + 0.55 * _sunw(cx(k), cy(k)), 0.0, 1.0)


func _sunw(x: float, y: float) -> float:
	return (x * light.x + y * light.y) / rr


# ───────────────────────── 좌표·읽기 (JarWater와 같은 모양) ─────────────────────────
func idx(x: float, y: float) -> int:
	var i := clampi(floori(x + rr), 0, n - 1)
	var j := clampi(floori(y + rr), 0, n - 1)
	return j * n + i


func cx(k: int) -> float:
	return -rr + (k % n) + 0.5


func cy(k: int) -> float:
	return -rr + (k / n) + 0.5


func is_inside_k(k: int) -> bool:
	var i := k % n
	var j := k / n
	return i >= row_i0[j] and i < row_i1[j]


func chunk_of(k: int) -> int:
	return ((k / n) / CH) * nc + (k % n) / CH


func coarse_of(k: int) -> int:
	return ((k / n) / F) * m + (k % n) / F


func is_fine_k(k: int) -> bool:
	return bmode[((k / n) / F) * m + (k % n) / F] == 1


func depth(k: int) -> float:
	var c := ((k / n) / F) * m + (k % n) / F
	if bmode[c] == 1:
		return w[k]
	return maxf(0.0, cL[c] - h[k]) if cK[c] > 0 else 0.0


func ground(k: int) -> float:
	return h[k]


func salt_k(k: int) -> float:
	if is_fine_k(k):
		return salt[k]
	var c := coarse_of(k)
	var s := cS[c]
	if s <= 0.0:
		return 0.0
	if cK[c] > 0:
		return s / cK[c] if h[k] < cL[c] else 0.0
	# 마른 거친 칸: 소금은 가장 낮은 1/4 칸에 남아 있다고 본다
	var low := maxi(1, cA[c] / 4)
	return s / low if h[k] <= hs[c * 64 + low - 1] else 0.0


func wet_k(k: int) -> float:
	if is_fine_k(k):
		return wet_c[k]
	return cwet[coarse_of(k)]


func take_salt(k: int, amt: float) -> void:
	if is_fine_k(k):
		salt[k] -= amt
	else:
		var c := coarse_of(k)
		cS[c] = maxf(0.0, cS[c] - amt)


func warm_at(x: float, y: float) -> float:
	return clampf(0.5 + 0.55 * _sunw(x, y), 0.0, 1.0)


func sun_at(x: float, y: float) -> float:
	return _sunw(x, y)


func radius() -> float:
	return rr


func inside(x: float, y: float, margin := 0.0) -> bool:
	return Vector2(x, y).length() <= rr - 0.4 - margin


func is_lake(k: int) -> bool:
	return depth(k) > LAKE_DEPTH


func is_river(k: int) -> bool:
	if is_fine_k(k):
		return w[k] <= LAKE_DEPTH and flux[k] > RIVER_FLUX * scale
	var c := coarse_of(k)
	if cK[c] == 0:
		return false
	var d := cL[c] - h[k]
	return d > 0.0 and d <= LAKE_DEPTH and cFL[c] > RIVER_FLUX * cscale * F


func is_salt_flat(k: int) -> bool:
	return depth(k) < SEEP_DEPTH and salt_k(k) > SALT_FLAT


func cells_near(c: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var j0 := maxi(0, floori(c.y - r + rr))
	var j1 := mini(n - 1, floori(c.y + r + rr))
	for j in range(j0, j1 + 1):
		var y := -rr + j + 0.5
		var i0 := maxi(row_i0[j], floori(c.x - r + rr))
		var i1 := mini(row_i1[j] - 1, floori(c.x + r + rr))
		for i in range(i0, i1 + 1):
			if Vector2(-rr + i + 0.5 - c.x, y - c.y).length() < r:
				out.append(j * n + i)
	return out


func village_cells(c: Vector2, r: float) -> PackedInt32Array:
	return cells_near(c, r)


func has_fog() -> bool:
	return true


func basin_area(b: Dictionary) -> int:
	var cnt := 0
	for k in cells_near(Vector2(b["x"], b["y"]), b["r"]):
		if depth(k) > LAKE_DEPTH:
			cnt += 1
	return cnt


func salt_flat_in(c: Vector2, r: float) -> Variant:
	var best: Variant = null
	var bv := 0.004
	for k in cells_near(c, r):
		if depth(k) < 0.004:
			var s := salt_k(k)
			if s > bv:
				bv = s
				best = Vector2(cx(k), cy(k))
	return best


func salt_flat() -> Variant:
	return null                     # 세상 전체 찾기는 너무 넓다 — salt_flat_in을 쓴다


## 물 총량 (부피) — 고운 조각 + 거친 칸
func total_water() -> float:
	var s := 0.0
	for k in fcells:
		s += w[k]
	for sl: PackedInt32Array in cslices:
		for c in sl:
			s += cV[c]
	return s


func total_salt() -> float:
	var s := 0.0
	for k in fcells:
		s += salt[k] + halite[k]
	for sl: PackedInt32Array in cslices:
		for c in sl:
			s += cS[c] + cHal[c]
	return s


## 넓은 세상의 '호수 칸' 수 (원 안 전체 — 테스트용, 거친 칸은 K 중 깊은 칸)
func lake_cells_in(c: Vector2, r: float) -> int:
	return basin_area({"x": c.x, "y": c.y, "r": r})


# ───────────────────────── 시간 ─────────────────────────
func advance(seconds: float) -> void:
	var left := seconds
	while left > 1e-6:
		var dt := minf(SUBSTEP, left)
		left -= dt
		t += dt
		_hydro_acc += dt
		var every := OFFLINE_EVERY_BIG if offline else ONLINE_EVERY
		while _hydro_acc >= every:
			world_tick(every / 60.0)
			_hydro_acc -= every
		var hr := hour_now()
		if hr >= 7.0 and hr < 18.0:
			humid = minf(1.0, humid + dt / (DAY * 0.45))
		else:
			humid = maxf(0.2, humid - dt / (DAY * 0.9))


## 한 번: 고운 조각 한 걸음 + 거친 칸 한 묶음 (거친 칸마다 SLICES번에 한 번 = sc × SLICES)
func world_tick(sc: float) -> void:
	if not fcells.is_empty():
		fine_step(sc)
	coarse_slice(sc * SLICES, _slice_i)
	_slice_i = (_slice_i + 1) % SLICES
	tick += 1


func fine_step(sc: float) -> void:
	var hh := h
	var ww := w
	var fl := flux
	var sl := salt
	var nbs := f_nbs
	var nbl := f_nbl
	var V := cV
	var L := cL
	var S := cS
	var FL := cFL
	var cells_l := fcells
	var nf := cells_l.size()
	# 들어오는 물
	for i in drip_k.size():
		var k := drip_k[i]
		if is_fine_k(k):
			var a := DRIP_RATE * drip_mult[i] * sc * (0.6 + humid)
			ww[k] += a
			added += a
	for i in groove_k.size():
		var k := groove_k[i]
		if is_fine_k(k):
			var a := _groove_rate(k) * groove_mult[i] * sc
			ww[k] += a
			added += a
	for i in nf:
		fl[cells_l[i]] *= FLUX_DECAY
	var touched := {}
	for pass_i in FLOW_PASSES:
		for i in nf:
			var k := cells_l[i]
			var wk := ww[k]
			if wk <= 1e-7:
				continue
			var s0 := hh[k] + wk
			var best := -1
			var bs := s0
			for q in range(nbs[i], nbs[i + 1]):
				var nn := nbl[q]
				var sn := 0.0
				if nn >= 0:
					sn = hh[nn] + ww[nn]
				else:
					sn = L[-nn - 1]
				if sn < bs:
					bs = sn
					best = nn
			if best == -1:
				continue
			var mv := minf(wk, (s0 - bs) * 0.5)
			var sm := 0.0
			if sl[k] > 0.0 and wk > 0.0005:
				sm = sl[k] * (mv / wk)
				sl[k] -= sm
			ww[k] -= mv
			fl[k] += mv
			if best >= 0:
				ww[best] += mv
				sl[best] += sm
			else:
				var c := -best - 1
				V[c] += mv
				S[c] += sm
				FL[c] += mv
				_relevel(c)
	# 암염
	var ha := halite
	for i in nf:
		var k := cells_l[i]
		var hv := ha[k]
		if hv <= 0.0:
			continue
		var wet := ww[k] + fl[k] * 40.0
		if wet < 0.0008:
			continue
		var d := minf(hv, DISSOLVE * minf(1.0, wet * 20.0) * sc)
		ha[k] -= d
		sl[k] += d
	# 증발·스며듦
	var fw := fwarm
	var ev := EVAP * evap_k()                # 거인의 손 (B6): 커튼·감싼 손
	for i in nf:
		var k := cells_l[i]
		var v := ww[k]
		if v <= 0.0:
			continue
		var v0 := v
		v -= ev * (0.35 + fw[i]) * sc
		if v < SEEP_DEPTH:
			v -= SEEP * FINE_SEEP * sc
		if v < 0.0:
			v = 0.0
		ww[k] = v
		removed += v0 - v
	scale = sc
	# 습기: 네 번에 한 번, 고운 칸이 있는 조각 하나씩 번갈아 (습기는 천천히 바뀐다)
	if not fine_chunks.is_empty() and tick % 4 == 0:
		_wet_rr = (_wet_rr + 1) % fine_chunks.size()
		update_wet_chunk(fine_chunks[_wet_rr])


func _groove_rate(k: int) -> float:
	var wm := clampf(0.5 + 0.55 * _sunw(cx(k), cy(k)), 0.0, 1.0)
	return GROOVE_RATE * GROOVE_BIG * (GROOVE_BASE + pow(1.0 - wm, 1.5))


func coarse_slice(sc: float, slice: int) -> void:
	var ev := EVAP * evap_k()                # 거인의 손 (B6): 커튼·감싼 손
	var V := cV
	var L := cL
	var K := cK
	var S := cS
	var FL := cFL
	var nbs := c_nbs
	var nbl := c_nbl
	var nbf := c_nbf
	var hh := h
	var ww := w
	var mode := bmode
	var edge := c_edge
	var list := cslices[slice]
	# 들어오는 물 (이 묶음의 거친 칸에 있는 돌기·골)
	for i in drip_k.size():
		var k := drip_k[i]
		var c := coarse_of(k)
		if (c / m) % SLICES == slice and not is_fine_k(k):
			var a := DRIP_RATE * drip_mult[i] * sc * (0.6 + humid)
			V[c] += a
			added += a
			_relevel(c)
	for i in groove_k.size():
		var k := groove_k[i]
		var c := coarse_of(k)
		if (c / m) % SLICES == slice and not is_fine_k(k):
			var a := _groove_rate(k) * groove_mult[i] * sc
			V[c] += a
			added += a
			_relevel(c)
	for c in list:
		FL[c] *= FLUX_DECAY
	for pass_i in FLOW_PASSES:
		for c in list:
			var v := V[c]
			if v <= SEP:
				continue
			var s0 := L[c]
			var best := -1
			var bf := -1
			var bs := s0 - 1e-7
			if edge[c] == 0:
				for q in range(nbs[c], nbs[c + 1]):
					var nn := nbl[q]
					if L[nn] < bs:
						bs = L[nn]
						best = nn
			else:
				for q in range(nbs[c], nbs[c + 1]):
					var nn := nbl[q]
					var fk := nbf[q]
					if fk >= 0:
						var sf := hh[fk] + ww[fk]
						if sf < bs:
							bs = sf
							best = -1
							bf = fk
					elif mode[nn] == 0 and L[nn] < bs:
						bs = L[nn]
						best = nn
						bf = -1
			if best < 0 and bf < 0:
				continue
			var kc := maxi(K[c], 1)
			var dv := 0.0
			if best >= 0:
				dv = minf(v, (s0 - bs) * 0.5 / (1.0 / kc + 1.0 / maxi(K[best], 1)))
			else:
				dv = minf(v, (s0 - bs) * 0.5 / (1.0 / kc + 1.0))
			if dv <= 0.0:
				continue
			var sm := 0.0
			if S[c] > 0.0 and v / kc > 0.0005:
				sm = S[c] * (dv / v)
				S[c] -= sm
			V[c] = v - dv
			FL[c] += dv
			_relevel(c)
			if best >= 0:
				V[best] += dv
				S[best] += sm
				_relevel(best)
			else:
				ww[bf] += dv
				salt[bf] += sm
	# 암염 · 증발 · 스며듦 · 습기
	var cw := cwarm
	for c in list:
		var hv := cHal[c]
		if hv > 0.0 and (K[c] > 0 or FL[c] > 0.0):
			var frac := minf(1.0, float(K[c]) / cA[c] * 2.0 + FL[c] * 40.0 / cA[c])
			var d := minf(hv, DISSOLVE * sc * cNH[c] * frac)
			cHal[c] = hv - d
			S[c] += d
		var v := V[c]
		if v > SEP:
			var loss := ev * (0.35 + cw[c]) * sc * K[c] + SEEP * COARSE_SEEP * sc * _shallow(c, SEEP_DEPTH)
			var nv := maxf(0.0, v - loss)
			removed += v - nv
			V[c] = nv
			_relevel(c)
	if (tick / SLICES) % 4 != 0:          # 습기는 천천히 바뀐다 — 네 바퀴에 한 번
		cscale = sc
		return
	for c in list:
		var ci := c % m
		var cj := c / m
		var s := 0.0
		var cnt := 0
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ii := ci + di
				var jj := cj + dj
				if ii < 0 or jj < 0 or ii >= m or jj >= m:
					continue
				var q := jj * m + ii
				if cA[q] == 0:
					continue
				s += minf(1.0, float(K[q]) / cA[q] * 3.0 + FL[q] * 600.0 / cA[q])
				cnt += 1
		cwet[c] = minf(1.0, s / maxi(cnt, 1) * 2.2)
	cscale = sc


## 고운 조각 하나의 습기 (JarWater.update_wet과 같은 7칸 상자 흐림 두 번, 가장자리 3칸은 이웃(거친 포함)에서 읽음)
func update_wet_chunk(ch: int) -> void:
	var x0 := (ch % nc) * CH - 6
	var y0 := (ch / nc) * CH - 6
	var sz := CH + 12
	var src := PackedFloat32Array()
	src.resize(sz * sz)
	for jj in sz:
		var j := y0 + jj
		if j < 0 or j >= n:
			continue
		for ii in sz:
			var i := x0 + ii
			if i < row_i0[j] or i >= row_i1[j]:
				continue
			var k := j * n + i
			if is_fine_k(k):
				src[jj * sz + ii] = minf(1.0, w[k] * 12.0 + flux[k] * 9000.0)
			else:
				src[jj * sz + ii] = minf(1.0, depth(k) * 12.0)
	var tmp := PackedFloat32Array()
	tmp.resize(sz * sz)
	# 가로 (미끄럼 합)
	for jj in sz:
		var row := jj * sz
		var s := 0.0
		for ii in range(0, 3):
			s += src[row + ii]
		for ii in sz:
			if ii + 3 < sz:
				s += src[row + ii + 3]
			if ii - 4 >= 0:
				s -= src[row + ii - 4]
			tmp[row + ii] = s / (mini(ii + 3, sz - 1) - maxi(ii - 3, 0) + 1)
	# 세로 → 안쪽 64×64만 씀
	for ii in range(6, 6 + CH):
		var s := 0.0
		for jj in range(0, 3):
			s += tmp[jj * sz + ii]
		for jj in sz:
			if jj + 3 < sz:
				s += tmp[(jj + 3) * sz + ii]
			if jj - 4 >= 0:
				s -= tmp[(jj - 4) * sz + ii]
			if jj >= 6 and jj < 6 + CH:
				var j := y0 + jj
				var i := x0 + ii
				wet_c[j * n + i] = minf(1.0, s / (mini(jj + 3, sz - 1) - maxi(jj - 3, 0) + 1) * 2.2)


# ───────────────────────── 고운 ↔ 거친 ─────────────────────────
## 마을 둘레 (x, y, r)를 고운 계산으로 (거친 칸 8×8 단위의 원). 바뀐 칸만 옮긴다.
func set_interest(list: Array[Dictionary]) -> void:
	interest = list
	var want := {}
	for it: Dictionary in interest:
		var c := Vector2(float(it["x"]), float(it["y"]))
		var r := float(it["r"])
		var x0 := maxi(0, floori((c.x - r + rr) / F))
		var x1 := mini(m - 1, floori((c.x + r + rr) / F))
		var y0 := maxi(0, floori((c.y - r + rr) / F))
		var y1 := mini(m - 1, floori((c.y + r + rr) / F))
		for cj in range(y0, y1 + 1):
			for ci in range(x0, x1 + 1):
				var q := cj * m + ci
				if cA[q] > 0 and Vector2(-rr + (ci + 0.5) * F, -rr + (cj + 0.5) * F).distance_to(c) < r + F * 0.5:
					want[q] = true
	var changed := false
	for q: int in want:
		if bmode[q] == 0:
			_to_fine(q)
			changed = true
	for q in m * m:
		if bmode[q] == 1 and not want.has(q):
			_to_coarse(q)
			changed = true
	if changed:
		_rebuild_fine()
		_rebuild_slices()


func _coarse_fine_cells(c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ci := c % m
	var cj := c / m
	for jj in F:
		var j := cj * F + jj
		var a := maxi(row_i0[j], ci * F)
		var b := mini(row_i1[j], ci * F + F)
		for i in range(a, b):
			out.append(j * n + i)
	return out


func _to_fine(c: int) -> void:
	bmode[c] = 1
	var ks := _coarse_fine_cells(c)
	var lv := cL[c]
	var wet := cK[c] > 0
	var vsum := 0.0
	for k in ks:
		var d := maxf(0.0, lv - h[k]) if wet else 0.0
		w[k] = d
		vsum += d
		flux[k] = 0.0
	# 반올림 차이는 가장 깊은 칸에 (부피 정확히 같게)
	if wet and ks.size() > 0:
		var deepest := ks[0]
		for k in ks:
			if w[k] > w[deepest]:
				deepest = k
		w[deepest] = maxf(0.0, w[deepest] + (cV[c] - vsum))
	# 소금: 전에 고운 칸이었으면 그 무늬를 늘이고, 아니면 물 깊이(마른 칸은 낮은 1/4)에 나눈다
	_spread(ks, salt, cS[c], c, true)
	# 암염: 무늬(창조 때의 암염 자리)를 그대로 늘인다
	_spread_halite(ks, cHal[c])
	cV[c] = 0.0
	cS[c] = 0.0
	cHal[c] = 0.0
	cFL[c] = 0.0
	_relevel(c)


func _spread(ks: PackedInt32Array, arr: PackedFloat32Array, total_v: float, c: int, by_water: bool) -> void:
	var old := 0.0
	for k in ks:
		old += arr[k]
	if total_v <= 0.0:
		for k in ks:
			arr[k] = 0.0
		return
	if old > 1e-9:
		var f := total_v / old
		for k in ks:
			arr[k] *= f
		return
	var wsum := 0.0
	if by_water:
		for k in ks:
			wsum += w[k]
	if wsum > 1e-9:
		for k in ks:
			arr[k] = total_v * w[k] / wsum
		return
	var low := maxi(1, ks.size() / 4)
	var lim := hs[c * 64 + low - 1]
	var cnt := 0
	for k in ks:
		if h[k] <= lim:
			cnt += 1
	for k in ks:
		arr[k] = total_v / cnt if h[k] <= lim else 0.0


func _spread_halite(ks: PackedInt32Array, total_v: float) -> void:
	var pat := PackedFloat32Array()
	pat.resize(ks.size())
	var s := 0.0
	for i in ks.size():
		pat[i] = seam_at(cx(ks[i]), cy(ks[i]))
		s += pat[i]
	for i in ks.size():
		halite[ks[i]] = total_v * pat[i] / s if s > 1e-9 else 0.0


func seam_at(x: float, y: float) -> float:
	var v := 0.0
	for sm: Dictionary in seams:
		var d := Vector2(x - float(sm["x"]), y - float(sm["y"])).length()
		if d < float(sm["r"]):
			v += float(sm["amt"]) * (1.0 - d / float(sm["r"]))
	return v


func _to_coarse(c: int) -> void:
	bmode[c] = 0
	var v := 0.0
	var s := 0.0
	var hl := 0.0
	var fl := 0.0
	for k in _coarse_fine_cells(c):
		v += w[k]
		s += salt[k]
		hl += halite[k]
		fl += flux[k]
	cV[c] = v
	cS[c] = s
	cHal[c] = hl
	cFL[c] = fl
	_relevel(c)


func _rebuild_fine() -> void:
	fine_chunks.clear()
	var lst := PackedInt32Array()
	var chs := {}
	for c in m * m:
		if bmode[c] == 1:
			lst.append_array(_coarse_fine_cells(c))
			chs[((c / m) / CPC) * nc + (c % m) / CPC] = true
	for ch: int in chs:
		fine_chunks.append(ch)
	fine_chunks.sort()
	lst.sort()
	fcells = lst
	f_nbs.resize(fcells.size() + 1)
	f_nbl.clear()
	for idx_i in fcells.size():
		f_nbs[idx_i] = f_nbl.size()
		var k := fcells[idx_i]
		var i := k % n
		var j := k / n
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if di == 0 and dj == 0:
					continue
				var ii := i + di
				var jj := j + dj
				if jj < 0 or jj >= n or ii < row_i0[jj] or ii >= row_i1[jj]:
					continue
				var q := jj * n + ii
				var qc := (jj / F) * m + ii / F
				if bmode[qc] == 1:
					f_nbl.append(q)
				else:
					f_nbl.append(-qc - 1)
	f_nbs[fcells.size()] = f_nbl.size()
	# 거친 칸 → 고운 칸 경계: 이웃 (고운) 거친 칸 안에서 맞닿은 가장 낮은 고운 칸
	c_nbf.fill(-1)
	c_edge.fill(0)
	for c in m * m:
		if cA[c] == 0 or bmode[c] == 1:
			continue
		for q in range(c_nbs[c], c_nbs[c + 1]):
			var nn := c_nbl[q]
			if bmode[nn] == 0:
				continue
			var di := nn % m - c % m
			var dj := nn / m - c / m
			var xs: Array = [nn % m * F] if di == 1 else ([nn % m * F + F - 1] if di == -1 else range(nn % m * F, nn % m * F + F))
			var ys: Array = [nn / m * F] if dj == 1 else ([nn / m * F + F - 1] if dj == -1 else range(nn / m * F, nn / m * F + F))
			var best := -1
			for y: int in ys:
				for x: int in xs:
					if x < row_i0[y] or x >= row_i1[y]:
						continue
					var k := y * n + x
					if best < 0 or h[k] < h[best]:
						best = k
			c_nbf[q] = best
			c_edge[c] = 1
	_update_warm()
	for ch in fine_chunks:
		update_wet_chunk(ch)


func _rebuild_slices() -> void:
	cslices.clear()
	for s in SLICES:
		cslices.append(PackedInt32Array())
	for c in m * m:
		if cA[c] == 0 or bmode[c] == 1:
			continue
		cslices[(c / m) % SLICES].append(c)


## 땅을 고쳤을 때 (키트 자리 고르기) 그 둘레 거친 표를 다시
func rebuild_coarse_around(x: float, y: float, r: float) -> void:
	var c0i := maxi(0, floori((x - r + rr) / F))
	var c1i := mini(m - 1, floori((x + r + rr) / F))
	var c0j := maxi(0, floori((y - r + rr) / F))
	var c1j := mini(m - 1, floori((y + r + rr) / F))
	for cj in range(c0j, c1j + 1):
		for ci in range(c0i, c1i + 1):
			var c := cj * m + ci
			_build_coarse_cell(c)
			_relevel(c)


# ───────────────────────── 병 돌리기 ─────────────────────────
## 데이터는 그대로, 빛만 반대로 돈다 (JarWater.rotate_jar와 같은 뜻: 병 기준 (x, y) → (−y, x)).
func rotate_jar() -> void:
	light = Vector2(light.y, -light.x)
	rot = (rot + 1) % 4
	_update_warm()


## 화면용: 병 좌표 (x, y)가 지금 돌린 상태에서 놓이는 자리 (JarWater 데이터 회전과 같은 결과)
func turned(p: Vector2) -> Vector2:
	var q := p
	for i in rot:
		q = rot_pt(q)
	return q


# ───────────────────────── 안개 ─────────────────────────
func fog_idx(x: float, y: float) -> int:
	var fx := clampi(floori((x + rr) / FOG), 0, fn - 1)
	var fy := clampi(floori((y + rr) / FOG), 0, fn - 1)
	return fy * fn + fx


func revealed(x: float, y: float, sid := -1) -> bool:
	var f := fog[fog_idx(x, y)]
	return f != 0 if sid < 0 else (f & (1 << sid)) != 0


func revealed_k(k: int) -> bool:
	return fog[((k / n) / FOG) * fn + (k % n) / FOG] != 0


## 무리 sid가 (x, y) 둘레 rad칸을 본다. 돌려주는 것: 처음 본 것들 [{kind, name, x, y, other}]
## kind = lake / river / salt (발견) · contact (다른 무리가 본 땅을 처음 밟음, other = 그 무리 sid)
func reveal(sid: int, x: float, y: float, rad: float, force := false) -> Array:
	var ci := fog_idx(x, y)
	var bit := 1 << sid
	if fog_center[ci] & bit and not force:
		return []
	fog_center[ci] |= bit
	var ev: Array = []
	var fx := ci % fn
	var fy := ci / fn
	var rf := ceili(rad / FOG)
	var r2 := (rad / FOG) * (rad / FOG)
	for dy in range(-rf, rf + 1):
		var yy := fy + dy
		if yy < 0 or yy >= fn:
			continue
		for dx in range(-rf, rf + 1):
			var xx := fx + dx
			if xx < 0 or xx >= fn or dx * dx + dy * dy > r2:
				continue
			var q := yy * fn + xx
			var f := fog[q]
			if f & bit:
				continue
			var other := f & ~bit
			if other != 0:
				for s in 8:
					if other & (1 << s):
						ev.append({"kind": "contact", "other": s, "x": -rr + (xx + 0.5) * FOG, "y": -rr + (yy + 0.5) * FOG})
			fog[q] = f | bit
			fog_dirty[(yy / FOG_BLOCK) * (fn / FOG_BLOCK) + xx / FOG_BLOCK] = true
			if feat_idx.has(q):
				for fi: int in feat_idx[q]:
					var ft: Dictionary = features[fi]
					if int(ft["seen"]) & bit:
						continue
					ft["seen"] = int(ft["seen"]) | bit
					ev.append({"kind": ft["kind"], "name": ft["name"], "x": ft["x"], "y": ft["y"], "other": -1})
	fog_version += 1
	return ev


## 발견할 것을 안개 칸에 걸어 둔다 (호수는 둘레 원, 강은 지나는 점들)
func add_feature(kind: String, name: String, pts: Array, r: float) -> void:
	var fi := features.size()
	var c: Vector2 = pts[pts.size() / 2]
	features.append({"kind": kind, "name": name, "x": c.x, "y": c.y, "r": r, "seen": 0})
	var seen := {}
	for p: Vector2 in pts:
		var rf := maxi(0, ceili(r / FOG))
		var cfi := fog_idx(p.x, p.y)
		for dy in range(-rf, rf + 1):
			for dx in range(-rf, rf + 1):
				var xx := cfi % fn + dx
				var yy := cfi / fn + dy
				if xx < 0 or yy < 0 or xx >= fn or yy >= fn:
					continue
				var q := yy * fn + xx
				if seen.has(q):
					continue
				seen[q] = true
				if not feat_idx.has(q):
					feat_idx[q] = []
				(feat_idx[q] as Array).append(fi)


## 탐험할 곳: from에서 아무 방향으로 걸어 나가다 무리 sid가 아직 못 본 땅이 나오는 첫 자리 (물 위는 피함)
func fog_target(sid: int, from: Vector2, rng: RandomNumberGenerator, max_d := 260.0) -> Variant:
	var bit := 1 << sid
	for tries in 10:
		var a := rng.randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		var d := 6.0
		while d < max_d:
			var p := from + dir * d
			if not inside(p.x, p.y, 3.0):
				break
			if (fog[fog_idx(p.x, p.y)] & bit) == 0:
				# 안개 가장자리를 넘어 조금 더 (EXPLORE_PAST) 들어간다 — 물이면 그 앞까지
				var q := p
				var e := 0.0
				while e < WorldCfg.EXPLORE_PAST:
					var nq := q + dir * 4.0
					if not inside(nq.x, nq.y, 3.0) or depth(idx(nq.x, nq.y)) >= 0.01:
						break
					q = nq
					e += 4.0
				if depth(idx(q.x, q.y)) < 0.01:
					return q
				break
			d += 4.0
	return null


## 무리 sid가 본 땅의 끝까지 거리 (center에서) — 카메라 한계용
func revealed_radius(center: Vector2) -> float:
	var best := 0.0
	for q in fn * fn:
		if fog[q] != 0:
			var p := Vector2(-rr + (q % fn + 0.5) * FOG, -rr + (q / fn + 0.5) * FOG)
			best = maxf(best, p.distance_to(center))
	return best + FOG
