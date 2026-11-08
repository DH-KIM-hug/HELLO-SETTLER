## 촌장의 자리 고르기 — 점수 매기기 (docs/BUILDINGS.md '자리 잡기 다시', 2026-11-08 사용자: "알아서 나무 필요한 곳 근처에 벌목장 짓고"
## · "집 짓는 세팅도 알아서 잘해 보면 좋겠음" · "이쁘게, 사람들이 보고 '야, 이쁘게 잘 지었다' 하게").
##
## 순수 계산 (static 함수만, static var 없음 — ADR-0001). 같은 마을 상태 → 같은 자리 (난수 없음, 흔들림은 무리 번호·칸 해시).
## 자원 지도(나무·바위·호수·물·약초 땅·큰 버섯)는 (안개와 상관없이 — 후보 자리만 드러난 땅) 마을 둘레 2·path_r 정사각형을 1칸 격자로 — 개수(적분 그림)와 가장 가까운 거리(챔퍼).
##   Village._site_cache에 한 시간(+ 나무 수·바위 양·등불)마다 한 번만 만든다 (저장 안 함 — 순수 함수라 불러온 뒤 다시 만들면 같다).
##
## 자원 일터 (RES 표): 후보 = 격자 칸 가운데 (영역 안·드러난 땅·자원 MAX_D 안) → 싼 점수로 줄 세우고 위 TOP개만 건물 항목까지 → is_free 통과한 첫 칸.
##   점수 = 자원 가장자리(want 거리) + 둘레 자원 양(stock) − 창고까지 (나르기) − 집 고리 안쪽 (일터는 마을 가) − 같은 일터 곁 (자원 나눠 먹기)
##          − 비탈 − 물가(홍수, 어부 제외) − 발길 위 − 붐빔 (+ 짝 일터 곁: 산림관 ↔ 나무꾼).
## 집·마을 건물 (VillagePlan 큰길): 후보 = 광장 둘레 고리 + 큰길 양쪽 '마을 터 자리'(무리 번호로 2~3채씩 모인 작은 뜸, 뜸 사이 마당) +
##   큰길가 아무 자리 (덜 좋게). 점수 = 모닥불까지 (고리 지어 바깥으로) + 뜸 채우기 + 시끄러운 일터에서 떨어짐 − 물가·비탈·발길.
##   종류별: 마을의 얼굴(창고·교회·치료소·광장) = 광장 둘레 · 빵집 = 방앗간·창고 곁 · 제재소 = 나무꾼·창고 쪽 마을 가 · 대장간 = 마을 가.
class_name Siting
extends RefCounted

const CELL := 1.0
const TOP := 160               # 건물 항목·is_free까지 볼 후보 수
const NOISY := ["제재소", "대장간", "채석장"]
const NOISE_R := 7.0           # 집은 시끄러운 일터에서 이만큼은 떨어지려 한다
const FLOOD_R := 3.0           # 집·일터는 물에서 이만큼 안이면 덜 좋다 (물이 드는 곳)
const ROAD_PEN := 3.0          # 발길(흙길) 위 자리
const SLOPE_W := 1.5           # 비탈 무게 — 높이 차 SLOPE_REF(넓은 세상 둘레 90% 칸이 이보다 평평)마다
const SLOPE_REF := 0.03
const FOG_PEN := 1.0e6

## 자원 일터 표 — res: 자원 지도 · want: 자원 가장자리에서 바라는 거리 · max_d: 이보다 멀면 후보 아님 · box: 둘레 양을 세는 반폭 ·
## need: 이만큼이면 넉넉 · w_res/w_stock/w_store/w_core: 무게 · pair: 곁에 두면 좋은 일터 · wet: 습한 땅 보너스
const RES := {
	"나무꾼": {"res": "tree", "want": 2.2, "max_d": 12.0, "box": 7, "need": 18.0, "w_res": 1.0, "w_stock": 4.0, "w_store": 0.4, "w_core": 0.5, "same_r": 12.0},
	"산림관": {"res": "tree", "want": 2.6, "max_d": 12.0, "box": 6, "need": 6.0, "w_res": 0.8, "w_stock": 2.0, "w_store": 0.12, "w_core": 0.9, "same_r": 10.0, "pair": "나무꾼"},
	"채석장": {"res": "rock", "want": 2.0, "max_d": 10.0, "box": 6, "need": 2.0, "w_res": 1.2, "w_stock": 3.0, "w_store": 0.15, "w_core": 0.9, "same_r": 8.0},
	"어부": {"res": "lake", "want": 1.6, "max_d": 8.0, "box": 6, "need": 40.0, "w_res": 1.5, "w_stock": 3.0, "w_store": 0.15, "w_core": 0.6, "same_r": 10.0, "wet_ok": true},
	"약초꾼": {"res": "herb", "want": 1.0, "max_d": 12.0, "box": 6, "need": 40.0, "w_res": 0.8, "w_stock": 3.0, "w_store": 0.12, "w_core": 0.9, "same_r": 10.0},
	"버섯꾼": {"res": "shroom", "want": 2.4, "max_d": 14.0, "box": 7, "need": 2.0, "w_res": 0.9, "w_stock": 2.5, "w_store": 0.12, "w_core": 0.7, "same_r": 10.0, "wet": 2.0},
}


static func is_resource_type(type: String) -> bool:
	return RES.has(type)


## 점수 자리 잡기를 쓰는가 — 첫날(OPENING 첫 10분 대본: 첫 오두막·밭·벌목장·제단까지의 걸음과 빠르기가 맞춰져 있음)은 옛 방식,
## 첫날이 지나면 점수. (2026-11-09 자리 잡기 — 대본 시험 notebook이 옛 자리에 맞춰져 있어서)
static func active(v: Village) -> bool:
	return v.t >= Balance.DAY


# ───────────────────────── 자원 지도 ─────────────────────────
## 땅 지도 (물·호수까지 거리 · 높이 · 병 안) — 한 시간·등불·마을 자리마다 한 번. 자원 지도는 resource_field로 필요할 때만
static func fields(v: Village) -> Dictionary:
	var tr_r := v.territory_r() + 2.0
	var key := "%d|%.0f|%.2f,%.2f|%d|%.0f" % [int(v.t / Balance.HOUR), v.lamp_moved_t, v.center.x, v.center.y, v.sid, tr_r]
	var c: Dictionary = v._site_cache
	if c.get("key", "") == key:
		return c
	var half := ceilf(minf(v.path_r, tr_r))          # 격자 = 영역을 덮는 정사각형 (마을 둘레 2·path_r까지)
	var n := int(2.0 * half / CELL)
	var o := v.center - Vector2(half, half)
	var f := {"key": key, "n": n, "o": o}
	var lake := PackedInt32Array()
	lake.resize(n * n)
	var wat := PackedInt32Array()
	wat.resize(n * n)
	var hgt := PackedFloat32Array()
	hgt.resize(n * n)
	var inside := PackedByteArray()
	inside.resize(n * n)
	for gy in n:
		for gx in n:
			var i := gy * n + gx
			var p := o + Vector2(gx + 0.5, gy + 0.5) * CELL
			if p.distance_to(v.center) > tr_r or not v.water.inside(p.x, p.y, 0.5):      # 영역 밖은 볼 일 없음
				continue
			inside[i] = 1
			var k := v.water.idx(p.x, p.y)
			hgt[i] = v.water.ground(k)
			if v.water.is_lake(k):
				lake[i] = 1
				wat[i] = 1
			elif v.water.is_river(k):
				wat[i] = 1
	f["lake_n"] = _integral(lake, n)
	f["lake_d"] = _dist(lake, n)
	f["water_d"] = _dist(wat, n)
	f["h"] = hgt
	f["in"] = inside
	v._site_cache = f
	return f


## 자원 지도 res (tree · rock · shroom · herb · lake): {"n": 적분 그림, "d": 가장 가까운 거리}. 자원이 바뀌면 (수·양 열쇠) 다시
static func resource_field(v: Village, f: Dictionary, res: String) -> Dictionary:
	if res == "lake":
		return {"n": f["lake_n"], "d": f["lake_d"]}
	var pts: Array = []
	match res:
		"tree", "herb":
			for tr: Dictionary in v.trees:
				if tr["s"] == "tree":
					pts.append(Vector2(tr["x"], tr["y"]))
		"rock":
			for r: Dictionary in v.rocks:
				if r["amt"] > 0 and SkyDrops.rock_minable(v, r):
					pts.append(Vector2(r["x"], r["y"]))
		"shroom":
			if v.flora != null:
				for sh: Dictionary in v.flora.shrooms:
					if v.flora.mature(sh):
						pts.append(Vector2(sh["x"], sh["y"]))
	var sig := pts.size()
	for q: Vector2 in pts:
		sig = (sig * 31 + int(q.x * 4.0) * 7 + int(q.y * 4.0)) & 0x3FFFFFFF
	var fk := "res_" + res
	if f.has(fk) and int(f[fk]["sig"]) == sig:
		return f[fk]
	var n: int = f["n"]
	var grid := PackedInt32Array()
	grid.resize(n * n)
	for q: Vector2 in pts:
		var i := _cell(f, q)
		if i >= 0:
			grid[i] += 1
	if res == "herb":              # 약초 땅 = 숲 가 3칸 또는 습한 땅 (VillageEra.herb_ok와 같은 뜻)
		var tn := _integral(grid, n)
		var o: Vector2 = f["o"]
		var ins: PackedByteArray = f["in"]
		var wd: PackedFloat32Array = f["water_d"]
		var herb := PackedInt32Array()
		herb.resize(n * n)
		for gy in n:
			for gx in n:
				var i := gy * n + gx
				if ins[i] == 0 or wd[i] < 0.5:
					continue
				var p := o + Vector2(gx + 0.5, gy + 0.5) * CELL
				if _box(tn, n, gx, gy, 3) > 0 or v.wetness(p.x, p.y) >= Balance.HERB_WET:
					herb[i] = 1
		grid = herb
	var out := {"sig": sig, "n": _integral(grid, n), "d": _dist(grid, n)}
	f[fk] = out
	return out


static func _cell(f: Dictionary, p: Vector2) -> int:
	var n: int = f["n"]
	var q: Vector2 = (p - (f["o"] as Vector2)) / CELL
	var gx := floori(q.x)
	var gy := floori(q.y)
	if gx < 0 or gy < 0 or gx >= n or gy >= n:
		return -1
	return gy * n + gx


## 적분 그림 ((n+1)² — 상자 합을 한 번에)
static func _integral(a: PackedInt32Array, n: int) -> PackedInt32Array:
	var s := PackedInt32Array()
	s.resize((n + 1) * (n + 1))
	for y in n:
		var row := 0
		for x in n:
			row += a[y * n + x]
			s[(y + 1) * (n + 1) + x + 1] = s[y * (n + 1) + x + 1] + row
	return s


## (gx, gy) 둘레 반폭 r 정사각형 안의 합
static func _box(s: PackedInt32Array, n: int, gx: int, gy: int, r: int) -> int:
	var x0 := clampi(gx - r, 0, n)
	var y0 := clampi(gy - r, 0, n)
	var x1 := clampi(gx + r + 1, 0, n)
	var y1 := clampi(gy + r + 1, 0, n)
	var w := n + 1
	return s[y1 * w + x1] - s[y0 * w + x1] - s[y1 * w + x0] + s[y0 * w + x0]


## 가장 가까운 자원 칸까지 거리 (챔퍼 3-4, 칸 단위 · 없으면 큰 값)
static func _dist(a: PackedInt32Array, n: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(n * n)
	var big := 1.0e6
	for i in n * n:
		d[i] = 0.0 if a[i] > 0 else big
	for y in n:
		for x in n:
			var i := y * n + x
			var m := d[i]
			if x > 0:
				m = minf(m, d[i - 1] + 1.0)
			if y > 0:
				m = minf(m, d[i - n] + 1.0)
				if x > 0:
					m = minf(m, d[i - n - 1] + 1.4142)
				if x < n - 1:
					m = minf(m, d[i - n + 1] + 1.4142)
			d[i] = m
	for y in range(n - 1, -1, -1):
		for x in range(n - 1, -1, -1):
			var i := y * n + x
			var m := d[i]
			if x < n - 1:
				m = minf(m, d[i + 1] + 1.0)
			if y < n - 1:
				m = minf(m, d[i + n] + 1.0)
				if x < n - 1:
					m = minf(m, d[i + n + 1] + 1.4142)
				if x > 0:
					m = minf(m, d[i + n - 1] + 1.4142)
			d[i] = m
	return d


## 칸 i 둘레 비탈 (이웃 칸과 높이 차의 가장 큰 값 ÷ SLOPE_REF — 1 = 꽤 기운 땅, 2 = 벼랑 곁)
static func slope(f: Dictionary, i: int) -> float:
	var n: int = f["n"]
	var h: PackedFloat32Array = f["h"]
	var ins: PackedByteArray = f["in"]
	var gx := i % n
	var gy := i / n
	var s := 0.0
	for dxy: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x := gx + dxy.x
		var y := gy + dxy.y
		if x >= 0 and y >= 0 and x < n and y < n and ins[y * n + x] == 1:
			s = maxf(s, absf(h[y * n + x] - h[i]))
	return s / SLOPE_REF


## 자리 p의 비탈 (격자 밖이면 0)
static func slope_at(v: Village, p: Vector2) -> float:
	var f := fields(v)
	var i := _cell(f, p)
	return slope(f, i) if i >= 0 else 0.0


## 자리 p 둘레 (반폭 r칸 정사각형) 선 나무 수 — tf = resource_field(v, fields(v), "tree") (여러 번 물을 때 한 번만 만들어 넘김)
static func trees_at(v: Village, p: Vector2, r: int, tf: Dictionary = {}) -> int:
	var f := fields(v)
	var i := _cell(f, p)
	if i < 0:
		return 0
	if tf.is_empty():
		tf = resource_field(v, f, "tree")
	var n: int = f["n"]
	return _box(tf["n"], n, i % n, i / n, r)


static func _hash(a: int, b: int, c: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ 0x27d4eb2d
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## 집들이 이룬 마을 고리의 반지름 (모닥불에서 가장 먼 집 + 1, 광장 둘레보다는 크게) — 일터는 이 바깥 (마을 가)
static func core_r(v: Village) -> float:
	var r := VillagePlan.RP + 5.0
	for b in v.buildings:
		if b.is_house() or b.is_store:
			r = maxf(r, Vector2(b.x, b.y).distance_to(v.fire) + b.size() + 1.0)
	return r


# ───────────────────────── 자원 일터 ─────────────────────────
## 자원 일터의 자리 (RES 표). 후보가 없으면 null → Village의 옛 나선 방식. 자리의 나무는 치우지 않는다 (부르는 쪽이)
static func resource_spot(v: Village, type: String) -> Variant:
	if not RES.has(type):
		return null
	var rule: Dictionary = RES[type]
	var f := fields(v)
	var rf := resource_field(v, f, String(rule["res"]))
	var dist: PackedFloat32Array = rf["d"]
	var cnt: PackedInt32Array = rf["n"]
	var n: int = f["n"]
	var o: Vector2 = f["o"]
	var fog := v._fog_on and v.water is WorldWater
	var ins: PackedByteArray = f["in"]
	var wd: PackedFloat32Array = f["water_d"]
	var size: float = Balance.B[type]["size"]
	var tr_r := v.territory_r()
	var store := v.store()
	var sp := Vector2(store.x, store.y) if store != null else v.fire
	var core := core_r(v)
	var want: float = rule["want"]
	var max_d: float = rule["max_d"]
	var box: int = rule["box"]
	var need: float = rule["need"]
	var cands: Array = []
	for gy in n:
		for gx in n:
			var i := gy * n + gx
			if ins[i] == 0:
				continue
			var dr := dist[i]
			if dr > max_d:
				continue
			var p := o + Vector2(gx + 0.5, gy + 0.5) * CELL
			if p.distance_to(v.center) + size > tr_r:
				continue
			if fog and not v.water.revealed(p.x, p.y, v.sid):      # 안개 속은 모른다 (드러난 땅만)
				continue
			var s := 0.0
			s -= float(rule["w_res"]) * maxf(0.0, dr - want) + 1.5 * maxf(0.0, want - dr)
			s += float(rule["w_stock"]) * minf(1.0, _box(cnt, n, gx, gy, box) / need)
			s -= float(rule["w_store"]) * p.distance_to(sp)
			var df := p.distance_to(v.fire)
			s -= float(rule["w_core"]) * maxf(0.0, core - df)
			s -= SLOPE_W * slope(f, i)
			if not rule.get("wet_ok", false):
				s -= 1.2 * maxf(0.0, FLOOD_R - wd[i])
			if rule.has("wet"):
				s += float(rule["wet"]) * v.wetness(p.x, p.y)
			s += (_hash(v.sid, gx, gy) - 0.5) * 0.3          # 칸마다 작은 흔들림 (같은 마을 = 같은 값)
			cands.append([s, p])
	return _best(v, type, size, cands, func(p: Vector2) -> float: return _bld_terms(v, type, rule, p, size))


## 건물 항목: 붐빔(다른 건물 곁) · 같은 일터 곁(자원 나눠 먹기) · 짝 일터 곁 · 발길 위
static func _bld_terms(v: Village, type: String, rule: Dictionary, p: Vector2, size: float) -> float:
	var s := 0.0
	var pair := String(rule.get("pair", ""))
	var pair_d := INF
	for b in v.buildings:
		var d := Vector2(b.x, b.y).distance_to(p)
		var gap := d - b.size() - size
		if gap < 2.2:
			s -= (2.2 - gap) * 0.8
		if b.type == type and d < float(rule["same_r"]):
			s -= (float(rule["same_r"]) - d) * 0.5
		if pair != "" and b.type == pair:
			pair_d = minf(pair_d, d)
	if pair_d < INF:
		s -= 0.15 * pair_d
	if v.is_road(p.x, p.y):
		s -= ROAD_PEN
	return s


## 싼 점수로 줄 세우고 위 TOP개에 건물 항목을 더해 다시 줄 세운 뒤 is_free를 통과한 첫 자리 (같은 점수 = 먼저 들어온 칸 — 결정적)
static func _best(v: Village, type: String, size: float, cands: Array, extra: Callable) -> Variant:
	if cands.is_empty():
		return null
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var top: Array = []
	for j in mini(TOP, cands.size()):
		var c: Array = cands[j]
		top.append([float(c[0]) + float(extra.call(c[1])), c[1]])
	top.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for c: Array in top:             # 먼저 이웃과 벽 사이 GAP 이상 (붐비지 않게 — 집 마당을 파고들지 않음)
		var p: Vector2 = c[1]
		if v.is_free(p.x, p.y, size) and VillagePlan._spaced(v, p, size, VillagePlan.GAP):
			return p
	for c: Array in top:
		var p: Vector2 = c[1]
		if v.is_free(p.x, p.y, size):
			return p
	# 위 TOP이 모두 막히면 나머지를 차례로 (드묾)
	for j in range(TOP, cands.size()):
		var p: Vector2 = cands[j][1]
		if v.is_free(p.x, p.y, size):
			return p
	return null


# ───────────────────────── 집·마을 건물 (큰길 계획 위) ─────────────────────────
## 큰길 양쪽 '마을 터 자리' — 큰길 k·쪽 side마다 2~3채씩 작은 뜸(무리 번호 해시), 뜸 사이 마당. [{p, k, side, g (뜸 번호), d}]
## 자리 간격 PITCH는 넓혀 지은 집(1.2)까지 벽 사이 GAP이 남게.
const PITCH := 3.6
const YARD := 2.2              # 뜸 사이 마당 (더하는 길이)
const RIM := 11.0              # 시끄러운 일터: 광장 가에서 적어도 이만큼 (마을이 자랄 것까지)
const RING_HOUSE_PEN := 3.0    # 집이 RING_OPEN_HOUSES채를 넘으면 광장 둘레 고리는 마을 건물 몫
const RING_OPEN_HOUSES := 4    # 첫 집들(키트 둘 + 처음 지은 둘)은 예전처럼 광장 둘레 — 첫날 대본의 걸음·빠르기가 그대로
static func hamlet_slots(v: Village, pl: Dictionary, size: float) -> Array:
	var out: Array = []
	var off := VillagePlan.HALF_W + VillagePlan.GARDEN + size
	for k in VillagePlan.STREETS:
		for si in 2:
			var side := 1.0 if si == 0 else -1.0
			var d := VillagePlan.RP + 1.2 + 1.2 + _hash(v.sid, k * 2 + si, 900) * 1.2
			var g := 0
			while d < VillagePlan.STREET_LEN - 2.0:
				var gn := 2 if _hash(v.sid, k * 2 + si, g) < 0.55 else 3
				for j in gn:
					out.append({"p": VillagePlan._side_pt(pl, k, d, side * off), "k": k, "side": si, "g": g, "d": d})
					d += PITCH
				d += YARD + _hash(v.sid, k * 2 + si, g + 500) * 1.6
				g += 1
	return out


## 큰길 사이 고리 자리 — 고리 반지름 WEDGE_R마다, 이웃한 두 큰길 사이(그 반지름에서 잰 각)에 PITCH 간격으로 (큰길 앞마당 띠는 뺌).
## 같은 고리·같은 사이 = 한 뜸 (열쇠 "w|사이|고리"). 반지름에 무리 번호로 작은 흔들림
const WEDGE_R := [9.0, 13.0]
const ALLEY_MAX := 8.5          # 고리 자리에서 가장 가까운 길까지 (골목 길이)
static func wedge_slots(v: Village, pl: Dictionary, size: float) -> Array:
	var out: Array = []
	var fire: Vector2 = pl["fire"]
	var clear := VillagePlan.HALF_W + VillagePlan.GARDEN + size + 0.6
	for ri in WEDGE_R.size():
		var r: float = float(WEDGE_R[ri]) + (_hash(v.sid, ri, 31) - 0.5) * 1.2
		var angs: Array = []
		for k in VillagePlan.STREETS:
			var q := VillagePlan.street_at(pl, k, r) - fire
			angs.append(atan2(q.y, q.x))
		angs.sort()
		for w in angs.size():
			var a0: float = angs[w]
			var a1: float = angs[(w + 1) % angs.size()] + (TAU if w == angs.size() - 1 else 0.0)
			var lo := a0 + clear / r
			var hi := a1 - clear / r
			if hi <= lo:
				continue
			var cnt := int(floor((hi - lo) * r / PITCH)) + 1
			var span := (cnt - 1) * PITCH / r
			var start := (lo + hi) * 0.5 - span * 0.5
			for j in cnt:
				var a := start + j * PITCH / r
				var p := fire + Vector2(cos(a), sin(a)) * r
				var nd := float(VillagePlan.nearest_plan(pl, p)["dist"])
				if nd >= clear + 0.6 and nd <= ALLEY_MAX:       # 큰길 앞줄과 섞이지 않는 뒷줄 · 골목이 길지 않게
					out.append({"p": p, "key": "w|%d|%d" % [w, ri]})
	return out


## 종류별 자리 성격 — civic: 광장 둘레 · noisy: 마을 가 · near: 곁에 두고 싶은 종류
const STREET_RULES := {
	"창고": {"civic": 2.0}, "교회": {"civic": 2.0}, "치료소": {"civic": 1.2}, "광장": {"civic": 2.0}, "방직소": {"civic": 0.4},
	"빵집": {"civic": 0.8, "near": ["방앗간", "맷돌간", "창고"]},
	"제재소": {"noisy": true, "near": ["나무꾼", "창고"]},
	"대장간": {"noisy": true, "near": ["채석장", "창고"]},
}


## 집·마을 건물의 자리 — 점수가 가장 좋은, is_free · 이웃 간격(GAP)을 지키는 자리. 없으면 null
static func street_spot(v: Village, size: float, type: String) -> Variant:
	var pl := VillagePlan.plan(v)
	var house: bool = int(Balance.B[type].get("cap", 0)) > 0 or type in Balance.ERA_HOUSE
	var rule: Dictionary = STREET_RULES.get(type, {})
	var f := fields(v)
	var wd: PackedFloat32Array = f["water_d"]
	var core := maxf(core_r(v), VillagePlan.RP + RIM)       # 시끄러운 일터는 마을이 자랄 것까지 보고 가에
	var n_house := 0
	for b in v.buildings:
		if b.is_house():
			n_house += 1
	# 광장 둘레 첫 고리 = 마을의 얼굴 (창고·교회·치료소 · 키트 집 둘). 그 뒤 집은 큰길의 뜸으로 → 광장 둘레가 붐비지 않게
	var ring_s := 1.0 + float(rule.get("civic", 0.0)) - (RING_HOUSE_PEN if house and n_house >= RING_OPEN_HOUSES else 0.0)
	var cands: Array = []       # [점수, p, 뜸 열쇠, 이웃과 벽 사이 최소]
	var rs: Array = VillagePlan._ring_spots(v, pl, size)
	for ri in rs.size():                   # 고리는 옛 차례 그대로 (키트 건물 자리가 예전과 같게 — 같은 거리면 앞 자리부터)
		cands.append([ring_s - 0.001 * ri, rs[ri], "ring", VillagePlan.GAP])
	for sl: Dictionary in hamlet_slots(v, pl, size):
		cands.append([0.8, sl["p"], "%d|%d|%d" % [sl["k"], sl["side"], sl["g"]], VillagePlan.GAP])
	# 큰길 사이 고리 (광장을 바라보는 둘째·셋째 고리 — 별 모양 대신 둥근 마을). 고리마다 큰길 사이 한 칸이 한 뜸
	for wr: Dictionary in wedge_slots(v, pl, size):
		cands.append([0.3 + float(rule.get("civic", 0.0)) * 0.5, wr["p"], wr["key"], VillagePlan.GAP + 0.4])
	# 큰길가 아무 자리 (뜸 자리가 다 막혔을 때) — 뜸 사이 마당을 메우지 않게 이웃과 더 떨어져야
	var off := VillagePlan.HALF_W + VillagePlan.GARDEN + size
	var d := VillagePlan.RP + size + 0.8
	while d < VillagePlan.STREET_LEN - 1.0:
		for k in VillagePlan.STREETS:
			for side: float in [1.0, -1.0]:
				cands.append([-2.0, VillagePlan._side_pt(pl, k, d, side * off), "", VillagePlan.GAP + YARD])
		d += VillagePlan.SCAN * 2.0
	# 뜸마다 이미 선 집 수 (집이 있는 뜸부터 채운다 → 2~3채씩 모인 작은 마을들)
	var filled := {}
	if house:
		var all_sl: Array = []
		for sl: Dictionary in hamlet_slots(v, pl, 1.0):
			all_sl.append([sl["p"], "%d|%d|%d" % [sl["k"], sl["side"], sl["g"]]])
		for wr: Dictionary in wedge_slots(v, pl, 1.0):
			all_sl.append([wr["p"], wr["key"]])
		for sl: Array in all_sl:
			var sp: Vector2 = sl[0]
			for b in v.buildings:
				if b.is_house() and Vector2(b.x, b.y).distance_to(sp) < 1.2:
					filled[sl[1]] = int(filled.get(sl[1], 0)) + 1
	var scored: Array = []
	for c: Array in cands:
		var p: Vector2 = c[1]
		var i := _cell(f, p)
		if i < 0:
			continue
		var df := p.distance_to(v.fire)
		var s := float(c[0])
		if rule.get("noisy", false):
			s -= 0.25 * df + 1.2 * maxf(0.0, core - 1.0 - df)        # 마을 가, 그래도 너무 멀지 않게
		else:
			s -= df * (1.0 + float(rule.get("civic", 0.0)) * 0.3)    # 안쪽부터 고리 지어 바깥으로
		var hk := String(c[2])
		if house and hk != "" and filled.has(hk):
			s += 1.6                                                  # 뜸 채우기
		s -= SLOPE_W * slope(f, i)
		s -= 1.0 * maxf(0.0, FLOOD_R - wd[i])
		if hk != "ring":             # 광장 둘레 고리는 옛 차례 (같은 거리면 앞 자리부터)
			s += (_hash(v.sid, int(p.x * 3.0), int(p.y * 3.0)) - 0.5) * 0.2
		scored.append([s, p, c[3]])
	var near: Array = rule.get("near", [])
	var extra := func(p: Vector2) -> float:
		var e := 0.0
		for nt: String in near:
			var bd := INF
			for b in v.buildings:
				if b.type == nt or (nt == "창고" and b.is_store):
					bd = minf(bd, Vector2(b.x, b.y).distance_to(p))
			if bd < INF:
				e -= 0.35 * bd
		if house:
			for b in v.buildings:
				if b.type in NOISY:
					var dn := Vector2(b.x, b.y).distance_to(p)
					if dn < NOISE_R:
						e -= (NOISE_R - dn) * 0.9
		if v.is_road(p.x, p.y):
			e -= ROAD_PEN
		return e
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var top: Array = []
	for j in mini(TOP, scored.size()):
		var c: Array = scored[j]
		top.append([float(c[0]) + float(extra.call(c[1])), c[1], c[2]])
	top.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for c: Array in top:
		var p: Vector2 = c[1]
		if v.is_free(p.x, p.y, size) and VillagePlan._spaced(v, p, size, float(c[2])):
			return p
	for j in range(TOP, scored.size()):
		var p: Vector2 = scored[j][1]
		if v.is_free(p.x, p.y, size) and VillagePlan._spaced(v, p, size, float(scored[j][2])):
			return p
	for c: Array in scored:          # 마지막: 마당을 줄여서라도 (큰길이 거의 찼을 때)
		var p: Vector2 = c[1]
		if v.is_free(p.x, p.y, size) and VillagePlan._spaced(v, p, size, VillagePlan.GAP):
			return p
	return null
