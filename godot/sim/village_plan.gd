## 마을 배치와 길 (기획서 6.7 '길은 발길이 만든다' + 촌장의 자리 고르기) — 순수 계산, 저장할 새 상태 없음.
##
## 배치: 모닥불이 마을 한가운데 둥근 광장(반지름 RP). 광장에서 굽은 큰길 n개(3~5)가 바깥으로 뻗는다 (방향 = 창고 쪽을 기준으로
##   45° 비켜서 — 창고·제단은 큰길 사이 광장 가에). 집은 광장 둘레(첫 고리)와 큰길 양쪽에 앞마당을 두고 길을 바라보며
##   안쪽부터 바깥으로 고리 지어 선다 (같은 간격). 밭은 집들 너머 큰길가에 가지런히 줄지어. 자원 일터(나무꾼·채석장 …)는
##   옛 방식대로 자원 곁이되 큰길 위는 피한다. 촌장이 고르는 자리일 뿐 — 시뮬레이션 규칙(영역·물·건물 간격)은 Village.is_free 그대로.
##   옛 저장의 건물은 자리 그대로 (새 건물만 계획을 따른다). 계획은 (모닥불, 창고 방향, 무리 번호, 저장된 길 씨앗 Village.layout_seed)만으로 정해진다 → 결정론.
##   새 마을은 길 씨앗으로 큰길 3~5갈래·휨·광장 크기가 세상마다 다르다 (옛 저장 = 길 씨앗 -1 = 옛 4갈래).
##
## 길 그래프: 뿌리 = 광장. 큰길(쓰는 만큼만) · 건물 문 → 길 (짧은 골목) — 나무 모양 (고리 없음 → 경로 찾기가 거의 공짜).
##   주민의 걸음(4칸 넘게)은 길로 가는 게 많이 돌아가지 않으면 길을 따라 걷는다 (ResidentAI.update의 한 줄) → 발길이 선으로 모인다.
##   길에서 먼 곳(숲속 벨 나무·바위)은 TRAIL_CELL칸 격자 한가운데로 모이는 오솔길을 거친다 → 같은 숲가로 다니면 같은 오솔길.
##   그래프는 건물 목록의 순수 함수 (캐시 열쇠 = 모닥불·건물 수·번호 합) — 저장·불러오기를 끼워도 같은 길 (결정론 시험).
##
## 그림: 발길 지도(Village.paths)는 그대로 시뮬레이션 값. 화면용 오솔길 텍스처는 그래프의 선을 따라 발길을 읽어
##   매끈한 띠(가장자리 부드러움)로 그린다 — 덜 다닌 길 = 닳은 풀 자국 → 흙길 → (돌길 마을) 가운데가 자갈인 큰길.
##   그래프 밖 발길은 닳은 풀 자국까지만 (흙 얼룩 덩어리가 생기지 않게). 문 앞은 작게 밟힌 자리.
class_name VillagePlan
extends RefCounted

const RP := 3.2                 # 광장 반지름 (모닥불 둘레 빈 땅) — 옛 마을(길 씨앗 없음). 새 마을은 plan(v)["rp"] (RP_MIN~RP_MAX)
const STREETS := 4              # 옛 마을의 큰길 수. 새 마을은 plan(v)["n"] (3~5)
## 마을마다 다른 길 모양 (2026-11-09 1.2 — Village.layout_seed: 세상 씨앗 + 무리 번호로 처음 한 번 정해 저장. 옛 저장(-1) = 옛 4갈래 그대로)
const RP_MIN := 2.8
const RP_MAX := 4.0
const BEND_MIN := 0.10
const BEND_MAX := 0.34
const STREET_W3 := 0.25         # 큰길 3갈래가 될 몫 (그다음 4갈래 STREET_W4까지, 나머지 5갈래)
const STREET_W4 := 0.70
const HALF_W := 1.0             # 큰길 반폭 (건물이 들어서지 않는 띠)
const GARDEN := 0.9             # 앞마당 (길 가장자리 ~ 집 벽)
const GAP := 1.1                # 길을 따라 이웃 건물 사이 (벽과 벽)
const STREET_LEN := 44.0
const BEND := 0.2               # 큰길이 휘는 정도 (라디안)
const FARM_FROM := 8.0          # 밭은 광장 가에서 이만큼 바깥부터 (집들 너머)
const SCAN := 0.5               # 자리 훑는 간격
const ROUTE_MIN := 4.0          # 이보다 짧은 걸음은 그냥 곧장
const ROUTE_SLACK := 1.3        # 길로 가는 값(길 위는 ROAD_W배로 침)이 곧장의 이 배수 안이면 길로
const ROAD_W := 0.75
const CARRY_SLACK := 1.9        # 짐을 들었으면 (짐 나르기는 늘 길로 — 밭·방앗간·화덕·창고 사이가 가장 먼저 길이 된다)
const TRAIL_D := 3.0            # 길에서 이보다 먼 목적지 → 오솔길 (TRAIL_CELL 격자 한가운데를 거쳐)
const TRAIL_CELL := 4.0
const TRAIL_W := 0.8
const TRAIL_MAX := 16.0          # 이보다 긴 오솔길은 만들지 않는다 (먼 탐험은 곧장)
const FACE_JITTER := 0.12       # 건물 방향 흔들림 (라디안 — 2026-11-09 자리 잡기: 줄 맞춘 격자가 아니게 조금 더)

## 띠 그리기
const K := 1.6                 # 가장자리 기울기 (값/칸) — 클수록 또렷
const RAW_CAP := 0.22           # 그래프 밖 발길은 닳은 풀까지만 (셰이더 길 문턱 0.5 아래)
const RAW_K := 0.45

## 계획 종류: 집·마을 건물 = 길가 · 밭 = 길가 너머 줄지어 · 나머지(자원 일터·나루터·묘지·망루·제단) = 옛 방식(null)
const STREET_TYPES := ["오두막", "목조주택", "석조주택", "창고", "제재소", "빵집", "치료소", "교회", "대장간", "방직소", "광장"]
## 밀 → 가루 → 빵 고리 (아기자기하게 짐을 들고 길 따라): 밭(마을 가 큰길가) → 방앗간·맷돌간(그 큰길, 밭과 집들 사이) →
## 공용 화덕(광장 가, 모닥불 곁) → 집·창고(광장 둘레)
const MILL_TYPES := ["방앗간", "맷돌간"]
const FARM_TYPES := ["농장", "목장"]
const PLAZA_EDGE := ["우물", "공용 화덕"]

static var enabled := true       # 끄면 옛 방식 그대로 (비교·시험용)
static var _plans := {}         # 열쇠 → 큰길 선 (모닥불·기준 방향·무리 번호)
static var _graphs := {}        # 마을 instance id → {"key", "g"}
static var _trails := {}        # 마을 instance id → {격자 열쇠: {"pts", "t"}} (그림 전용 — 시뮬레이션은 읽지 않음)


# ───────────────────────── 계획 (큰길) ─────────────────────────
static func _store(v: Village) -> Building:
	for b in v.buildings:
		if b.is_store:
			return b
	return null


## 큰길 기준 방향 = 모닥불 → 창고 (병을 돌려도 함께 돈다)
static func base_angle(v: Village) -> float:
	var s := _store(v)
	if s == null or Vector2(s.x, s.y).distance_to(v.fire) < 0.1:
		return 0.0
	return atan2(s.y - v.fire.y, s.x - v.fire.x)


static func _h(seed_v: int, k: int) -> float:
	var h := (seed_v * 73856093) ^ (k * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## 길 모양 흔들림에 쓰는 씨앗 — 새 마을 = 저장된 길 씨앗, 옛 마을 = 무리 번호 (예전 그대로)
static func lseed(v: Village) -> int:
	return v.layout_seed if v.layout_seed >= 0 else v.sid


## 세상 씨앗 + 무리 번호 → 길 씨앗 (0 이상, 30비트). Village._init_world가 한 번 정해 저장한다
static func make_layout_seed(seed_v: int, sid_v: int) -> int:
	var h := (seed_v * 2654435761 + sid_v * 40503 + 0x51ed27) & 0x7FFFFFFF
	h = ((h ^ (h >> 15)) * 2246822519) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 3266489917) & 0x7FFFFFFF
	return (h ^ (h >> 16)) & 0x3FFFFFFF


## 길 모양 (큰길 수 n · 광장 반지름 rp · 휨 bend · 굽이 길이 freq · 큰길 첫 방향 a0[]). 옛 마을(layout_seed < 0)은 옛 모양 그대로
static func _shape(v: Village, base: float) -> Dictionary:
	var a0s: Array = []
	if v.layout_seed < 0:
		for k in STREETS:
			a0s.append(base + PI / STREETS + k * TAU / STREETS + (_h(v.sid, k) - 0.5) * 0.3)
		return {"n": STREETS, "rp": RP, "freq": 11.0, "a0": a0s, "bends": [], "legacy": true}
	var s := v.layout_seed
	var u := _h(s, 101)
	var n := 3 if u < STREET_W3 else (4 if u < STREET_W4 else 5)
	var step := TAU / n
	var rp := lerpf(RP_MIN, RP_MAX, _h(s, 102))
	var bend_max := lerpf(BEND_MIN, BEND_MAX, _h(s, 103))
	var freq := lerpf(8.5, 14.0, _h(s, 104))
	var jit := lerpf(0.10, 0.30, _h(s, 105)) * step         # 큰길 사이 각이 고르지 않게 (±jit/2)
	var phase := (0.5 + (_h(s, 106) - 0.5) * 0.16) * step    # 창고(base)는 큰길 사이 가운데쯤
	var clear := 0.36 * step                                  # 창고 곁 두 큰길은 창고에서 이 각 이상 (광장 가 창고를 길이 막지 않게)
	for k in n:
		var a := phase + k * step + (_h(s, k) - 0.5) * jit
		if k == 0:
			a = maxf(a, clear)
		elif k == n - 1:
			a = minf(a, TAU - clear)
		a0s.append(base + a)
	var bends: Array = []
	for k in n:
		bends.append((_h(s, k + 10) - 0.5) * 2.0 * bend_max)
	return {"n": n, "rp": rp, "freq": freq, "a0": a0s, "bends": bends, "legacy": false}


## 큰길 n개 — 각각 1칸 간격 점 (0 = 모닥불, i = 모닥불에서 i칸).
## {"streets": [PackedVector2Array], "fire", "base", "n", "rp", "mids" (큰길 사이 가운데 각 — 광장 둘레 고리), "gaps" (그 사이의 반각), "legacy"}
static func plan(v: Village) -> Dictionary:
	var base := base_angle(v)
	var key := "%.3f,%.3f|%.4f|%d|%d" % [v.fire.x, v.fire.y, base, v.sid, v.layout_seed]
	if _plans.has(key):
		return _plans[key]
	if _plans.size() > 32:
		_plans.clear()
	var sh := _shape(v, base)
	var n: int = sh["n"]
	var rp: float = sh["rp"]
	var freq: float = sh["freq"]
	var ls := lseed(v)
	var streets: Array = []
	var shrink := 1.0
	for attempt in 8:                 # 새 마을: 이웃한 두 큰길이 마주 휘어 좁아지면 휨을 줄여 다시 (결정적)
		streets = []
		var angs: Array = []
		for k in n:
			var a0: float = sh["a0"][k]
			var bend: float = (_h(v.sid, k + 10) - 0.5) * 2.0 * BEND if bool(sh["legacy"]) else float(sh["bends"][k]) * shrink
			var ph := _h(ls, k + 20) * 6.0
			var pts := PackedVector2Array()
			var al := PackedFloat32Array()
			for i in int(STREET_LEN) + 1:
				var d := float(i)
				var a := a0 + bend * (sin(maxf(0.0, d - rp) / freq + ph) - sin(ph))
				pts.append(v.fire + Vector2(cos(a), sin(a)) * d)
				al.append(a)
			streets.append(pts)
			angs.append(al)
		if bool(sh["legacy"]) or _gaps_ok(angs, n):
			break
		shrink *= 0.7
	# 광장 둘레 고리 자리의 기준 각 (큰길 사이 가운데). 옛 마을: base + q·90° (예전 그대로), 새 마을: 창고 쪽 사이부터 차례로
	var mids: Array = []
	var gaps: Array = []
	if bool(sh["legacy"]):
		for q in STREETS:
			mids.append(base + q * TAU / STREETS)
			gaps.append(PI / STREETS)
	else:
		var a0s: Array = sh["a0"]
		for q in n:
			var lo: float = float(a0s[q - 1]) - (TAU if q == 0 else 0.0)
			var hi: float = a0s[q]
			mids.append((lo + hi) * 0.5)
			gaps.append((hi - lo) * 0.5)
	var p := {"streets": streets, "fire": v.fire, "base": base, "n": n, "rp": rp, "mids": mids, "gaps": gaps, "legacy": bool(sh["legacy"])}
	_plans[key] = p
	return p


## 이웃한 큰길 사이 각이 어디서나 MIN_GAP·(360°/n) 이상이고 광장 가 너머 거리도 STREET_CLEAR칸 이상인가 (angs[k][i] = 큰길 k의 i칸 자리 각)
const MIN_GAP := 0.62
const STREET_CLEAR := 3.6
static func _gaps_ok(angs: Array, n: int) -> bool:
	var m := (angs[0] as PackedFloat32Array).size()
	for i in range(4, m, 2):
		for k in n:
			var a: float = (angs[k] as PackedFloat32Array)[i]
			var b: float = (angs[(k + 1) % n] as PackedFloat32Array)[i] + (TAU if k == n - 1 else 0.0)
			if b - a < MIN_GAP * TAU / n or (b - a) * i < STREET_CLEAR:
				return false
	return true


## 광장 반지름 (마을마다)
static func plaza_r(v: Village) -> float:
	return float(plan(v)["rp"])


## 큰길 k의 매개 d (모닥불에서 칸) 자리
static func street_at(pl: Dictionary, k: int, d: float) -> Vector2:
	var pts: PackedVector2Array = pl["streets"][k]
	var i := clampi(floori(d), 0, pts.size() - 2)
	return pts[i].lerp(pts[i + 1], clampf(d - i, 0.0, 1.0))


static func _seg_proj(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-9:
		return 0.0
	return clampf((p - a).dot(ab) / l2, 0.0, 1.0)


## 계획된 길(광장 가 + 큰길)에서 가장 가까운 곳 → {"kind": "plaza"|"street", "k", "d", "pt", "dist"}
static func nearest_plan(pl: Dictionary, p: Vector2) -> Dictionary:
	var fire: Vector2 = pl["fire"]
	var to := p - fire
	var rp: float = pl["rp"]
	var pr := rp * 0.85
	var best := {"kind": "plaza", "k": -1, "d": 0.0, "pt": fire + (to.normalized() if to.length() > 1e-4 else Vector2.RIGHT) * pr,
		"dist": absf(to.length() - pr)}
	for k in pl["streets"].size():
		var pts: PackedVector2Array = pl["streets"][k]
		for i in range(int(rp), pts.size() - 1):
			var u := _seg_proj(p, pts[i], pts[i + 1])
			var q := pts[i].lerp(pts[i + 1], u)
			var dd := q.distance_to(p)
			if dd < float(best["dist"]):
				best = {"kind": "street", "k": k, "d": i + u, "pt": q, "dist": dd}
	return best


## 이 자리가 큰길(앞으로 날 길 포함) 위·광장 위인가 — Village.is_free가 부른다 (건물이 길을 막지 않게)
static func blocks(v: Village, x: float, y: float, size: float) -> bool:
	if not enabled:
		return false
	var p := Vector2(x, y)
	var pl := plan(v)
	var rp: float = pl["rp"]
	if p.distance_to(v.fire) < rp + size * 0.5:
		return true
	var lim := HALF_W + size * 0.75
	for k in pl["streets"].size():
		var pts: PackedVector2Array = pl["streets"][k]
		# 큰길은 모닥불에서 곧게 뻗어 나가므로 거리로 먼저 거른다
		var dd := p.distance_to(v.fire)
		var i0 := clampi(floori(dd - lim - 2.0), int(rp), pts.size() - 2)
		var i1 := clampi(ceili(dd + lim + 2.0), int(rp), pts.size() - 2)
		for i in range(i0, i1 + 1):
			var q := pts[i].lerp(pts[i + 1], _seg_proj(p, pts[i], pts[i + 1]))
			if q.distance_to(p) < lim:
				return true
	return false


## 산림관이 묘목을 심어도 되는 자리 — 광장·큰길 위, 건물 곁(앞마당)은 비운다
static func plantable(v: Village, p: Vector2) -> bool:
	if not enabled:
		return true
	if blocks(v, p.x, p.y, 0.6):
		return false
	var core := 9.0                   # 마을 한가운데 (광장 둘레 집들) 안쪽은 숲으로 덮지 않는다
	for b in v.buildings:
		if b.type in STREET_TYPES:
			core = maxf(core, Vector2(b.x, b.y).distance_to(v.fire) + 3.0)
	if p.distance_to(v.fire) < core:
		return false
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(p) < b.size() + 1.6:
			return false
	return true


# ───────────────────────── 자리 고르기 (촌장) ─────────────────────────
## 계획에 맞는 자리 (없거나 계획 밖 종류면 null → Village.find_spot의 옛 방식). 자리의 나무는 치운다
static func find_spot(v: Village, type: String) -> Variant:
	if not enabled:
		return null
	if not Balance.B.has(type):
		return null
	var size: float = Balance.B[type]["size"]
	var p: Variant = null
	if type in STREET_TYPES:
		p = _street_spot(v, size, type)
	elif type in FARM_TYPES:
		p = _farm_spot(v, size, type == "농장")
	elif type in MILL_TYPES:
		p = _mill_spot(v, size)
		if p == null:
			p = _street_spot(v, size, type)
	elif type in PLAZA_EDGE:
		p = _plaza_edge_spot(v, size)
		if p == null:
			p = _street_spot(v, size, type)
	if p != null:
		v._clear_trees(p, size)
	return p


## 이웃 건물과 길을 따라 고른 간격 (Village.is_free의 0.6보다 넉넉하게)
static func _spaced(v: Village, p: Vector2, size: float, gap: float) -> bool:
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(p) < b.size() + size + gap:
			return false
	return true


## 광장 둘레 첫 고리 (큰길 사이마다 가운데 → 양옆) — 모닥불을 바라본다
static func _ring_spots(v: Village, pl: Dictionary, size: float) -> Array:
	var out: Array = []
	var rp: float = pl["rp"]
	var rr := rp + GARDEN * 0.7 + size
	var step := 0.6 * (rp + 2.0) / rr              # 고리 위 이웃 자리 사이 각 (옛 마을: 사이마다 둘, ±0.3)
	var margin := (HALF_W + size + 0.5) / rr        # 큰길 가에서 이만큼은 비움
	for q in (pl["mids"] as Array).size():
		var mid: float = pl["mids"][q]
		var cnt := 2
		if not bool(pl["legacy"]):                  # 넓은 사이(큰길 3갈래)는 셋, 좁은 사이(5갈래)는 하나까지
			cnt = clampi(int(floor(2.0 * (float(pl["gaps"][q]) - margin) / step)) + 1, 1, 3)
		for j in cnt:
			var a := mid + (float(j) - (cnt - 1) * 0.5) * step
			out.append(v.fire + Vector2(cos(a), sin(a)) * rr)
	return out


static func _street_spot(v: Village, size: float, type: String) -> Variant:
	if Siting.active(v):
		return Siting.street_spot(v, size, type)      # [자리 잡기] 점수 (sim/siting.gd) — 고리 · 2~3채 뜸 · 시끄러운 일터와 떨어짐
	return _street_spot_first(v, size, type)


## (옛 방식 — 첫날 대본 동안) 광장 둘레 첫 고리 → 큰길 양쪽 안쪽부터 첫 빈 자리
static func _street_spot_first(v: Village, size: float, type: String) -> Variant:
	var pl := plan(v)
	var ns: int = pl["n"]
	# 첫 고리: 광장 둘레 (창고·교회·집 — 마을의 얼굴)
	if true:
		for p: Vector2 in _ring_spots(v, pl, size):
			if v.is_free(p.x, p.y, size) and _spaced(v, p, size, GAP):
				return p
	# 큰길 양쪽, 안쪽부터 (고리 지어 바깥으로). 같은 거리면 큰길·쪽을 번갈아 (무리 번호로 시작을 비틈)
	var off := HALF_W + GARDEN + size
	var d := float(pl["rp"]) + size + 0.8
	var start := int(_h(lseed(v), 77) * ns * 2)
	while d < STREET_LEN - 1.0:
		for j in ns * 2:
			var c := (start + j) % (ns * 2)
			var k := c / 2
			var side := 1.0 if c % 2 == 0 else -1.0
			var p := _side_pt(pl, k, d, side * off)
			if v.is_free(p.x, p.y, size) and _spaced(v, p, size, GAP):
				return p
		d += SCAN
	return null


## 큰길 k의 매개 d에서 옆으로 o만큼 (o > 0 = 왼쪽)
static func _side_pt(pl: Dictionary, k: int, d: float, o: float) -> Vector2:
	var a := street_at(pl, k, d)
	var b := street_at(pl, k, d + 0.5)
	var t := (b - a).normalized()
	return a + Vector2(-t.y, t.x) * o


## 밭: 집들 너머 큰길가 — 볕·물기 좋은 곳 + 이미 있는 밭 곁 (가지런한 줄)
## tall = 밀밭 (목장이 아님): 익은 밀은 주민보다 커서, 이미 있는 무덤·묘지를 가리는 자리는 피한다 (Q8 ⑧ — VillageEra.field_by_grave).
## 그런 자리뿐이면 예전 규칙대로. 무덤이 하나도 없는 마을은 예전과 같은 자리 (주사위 없음).
static func _farm_spot(v: Village, size: float, tall := true) -> Variant:
	var pl := plan(v)
	var on := Siting.active(v)
	var tf: Dictionary = Siting.resource_field(v, Siting.fields(v), "tree") if on else {}
	var off := HALF_W + 0.4 + size
	var best: Variant = null
	var bv := -INF
	var graves := tall and VillageEra.has_graves(v)
	var clear: Variant = null          # 무덤을 가리지 않는 자리 가운데 가장 좋은 곳
	var cv := -INF
	var rp: float = pl["rp"]
	for k in int(pl["n"]):
		for side: float in [1.0, -1.0]:
			var d := rp + FARM_FROM
			while d < rp + FARM_FROM + 22.0:
				var p := _side_pt(pl, k, d, side * off)
				if v.is_free(p.x, p.y, size) and _spaced(v, p, size, 0.5) and (not on or _house_clear(v, p, size)):
					var val := v.farm_mult(p.x, p.y) - d * Balance.FARM_DIST_W      # (2026-11-09 0.025 → 0.06: 비탈 벌점이 밭을 먼 평지로 밀어 먹을 것 바닥 22 → 10 — 광장 쪽으로 당김)
					if on:                                   # [자리 잡기] 평평한 땅 · 숲은 벌목장 몫
						val -= Siting.SLOPE_W * Siting.slope_at(v, p) + 0.05 * Siting.trees_at(v, p, 2, tf)
					for b in v.buildings:
						if b.type == "농장" and Vector2(b.x, b.y).distance_to(p) < size * 2.0 + 1.6:
							val += 0.25          # 밭 곁 → 밭이 모여 줄을 이룬다
							break
					if val > bv:
						bv = val
						best = p
					if graves and val > cv and not VillageEra.field_by_grave(v, p):
						cv = val
						clear = p
				d += SCAN
	return clear if clear != null else best


## 밭이 집 마당을 파고들지 않게 (집과 벽 사이 GAP)
static func _house_clear(v: Village, p: Vector2, size: float) -> bool:
	for b in v.buildings:
		if b.is_house() and Vector2(b.x, b.y).distance_to(p) < b.size() + size + GAP:
			return false
	return true


## 방앗간·맷돌간: 밭이 가장 많은 큰길에서 밭 바로 안쪽 (밭 → 방앗간 → 광장 화덕이 한 길로 이어지게)
static func _mill_spot(v: Village, size: float) -> Variant:
	var pl := plan(v)
	var cnt := {}
	for b in v.buildings:
		if b.type in FARM_TYPES:
			var np := nearest_plan(pl, Vector2(b.x, b.y))
			if np["kind"] == "street":
				cnt[np["k"]] = int(cnt.get(np["k"], 0)) + 1
	var best_k := -1
	for k: int in cnt:
		if best_k < 0 or int(cnt[k]) > int(cnt[best_k]) or (int(cnt[k]) == int(cnt[best_k]) and k < best_k):
			best_k = k
	if best_k < 0:
		return null
	# 앞줄(길가)이 집으로 찼으면 (큰길이 셋뿐인 마을) 한 줄 뒤 · 두 줄 뒤 — 그래도 같은 큰길을 바라본다
	for back: float in [0.0, 1.8, 3.6]:
		var off := HALF_W + GARDEN + size + back
		var d := float(pl["rp"]) + FARM_FROM - 0.5
		while d > float(pl["rp"]) + size + 0.8:
			for side: float in [1.0, -1.0]:
				var p := _side_pt(pl, best_k, d, side * off)
				if v.is_free(p.x, p.y, size) and _spaced(v, p, size, GAP) and (back == 0.0 or int(nearest_plan(pl, p)["k"]) == best_k):
					return p
			d -= SCAN
	return null


## 우물·공용 화덕: 광장 가 (큰길 사이)
static func _plaza_edge_spot(v: Village, size: float) -> Variant:
	var pl := plan(v)
	var rr := float(pl["rp"]) + size * 0.55
	for q in (pl["mids"] as Array).size():
		for off: float in [0.45, -0.45]:
			var a: float = float(pl["mids"][q]) + off
			var p := v.fire + Vector2(cos(a), sin(a)) * rr
			if _well_free(v, p, size):
				return p
	return null


## 광장 가 자리 — 광장 막기(blocks)만 빼고 is_free와 같은 조건
static func _well_free(v: Village, p: Vector2, size: float) -> bool:
	if not v.water.inside(p.x, p.y, size + 1.2) or v.water_at(p.x, p.y) or not v.in_territory(p.x, p.y, size):
		return false
	if p.distance_to(v.altar_pos) < size + Village.ALTAR_CLEAR or p.distance_to(v.fire) < size + 1.2:
		return false
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(p) < b.size() + size + 0.6:
			return false
	for r: Dictionary in v.rocks:
		if Vector2(r["x"], r["y"]).distance_to(p) < size + 0.8:
			return false
	var pl := plan(v)
	for k in int(pl["n"]):
		var q := street_at(pl, k, p.distance_to(v.fire))
		if q.distance_to(p) < HALF_W + size:
			return false
	return true


## 새 마을 (키트를 막 내려놓았을 때): 창고는 광장 가로, 오두막은 광장 둘레 첫 고리로 옮긴다. 제단은 그 뒤에 고른다
static func found(v: Village) -> void:
	if not enabled:
		return
	var st := _store(v)
	if st == null:
		return
	var dir := Vector2(st.x, st.y) - v.fire
	if dir.length() < 0.1:
		return
	var rs := plaza_r(v) + GARDEN * 0.7 + st.size()
	var sp := v.fire + dir.normalized() * rs
	st.x = sp.x
	st.y = sp.y
	v._clear_trees(sp, st.size())
	var others: Array = []
	for b in v.buildings:
		if b != st:
			others.append(b)
	for b: Building in others:
		v.buildings.erase(b)
	for b: Building in others:
		var p: Variant = find_spot(v, b.type)
		v.buildings.append(b)
		if p != null:
			b.x = (p as Vector2).x
			b.y = (p as Vector2).y
	# 원래 순서 (번호 순) 그대로
	v.buildings.sort_custom(func(a: Building, b: Building) -> bool: return a.id < b.id)


# ───────────────────────── 문·방향 ─────────────────────────
## 건물이 바라보는 쪽 (단위 벡터, 데이터 좌표) — 가장 가까운 계획된 길(광장 가·큰길) 쪽
static func face_dir(v: Village, b: Building) -> Vector2:
	var pl := plan(v)
	var p := Vector2(b.x, b.y)
	var np := nearest_plan(pl, p)
	var f := (np["pt"] as Vector2) - p
	if f.length() < 1e-3:
		f = p - v.fire
	if f.length() < 1e-3:
		f = Vector2(1, 1)
	return f.normalized()


## 화면 방향 (rotation.y — 모델 앞 = +z). 작은 흔들림
static func facing(v: Village, b: Building) -> float:
	var f := face_dir(v, b)
	var j := 0.0 if b.is_store else (_h(b.id, 5) - 0.5) * 2.0 * FACE_JITTER
	return atan2(f.x, f.y) + j


static func door(v: Village, b: Building) -> Vector2:
	return Vector2(b.x, b.y) + face_dir(v, b) * (b.size() + 0.25)


# ───────────────────────── 길 그래프 ─────────────────────────
## 노드: {"pos", "parent", "depth", "pts" (이 노드 → 부모 쪽 끝, 부모가 뿌리면 광장 가에서 끝남), "kind", "b" (건물 id 또는 -1)}
static func graph(v: Village) -> Dictionary:
	var iid := v.get_instance_id()
	var idsum := 0
	for b in v.buildings:
		idsum += b.id * 31 + int(b.x * 7.0) + int(b.y * 13.0)
	var key := "%.3f,%.3f|%d|%d|%.4f" % [v.fire.x, v.fire.y, v.buildings.size(), idsum, base_angle(v)]
	var c: Dictionary = _graphs.get(iid, {})
	if not c.is_empty() and c["key"] == key:
		return c["g"]
	if _graphs.size() > 32:
		_graphs.clear()
	var g := _build(v)
	_graphs[iid] = {"key": key, "g": g}
	return g


static func _build(v: Village) -> Dictionary:
	var pl := plan(v)
	var nodes: Array = [{"pos": v.fire, "parent": -1, "depth": 0, "pts": PackedVector2Array([v.fire]), "kind": "root", "b": -1}]
	var attach := {}                 # 큰길 k → [[d, 건물 노드 자리 정보]]
	var plaza_doors: Array = []
	var doors := {}
	for b in v.buildings:
		var p := Vector2(b.x, b.y)
		var dr := door(v, b)
		doors[b.id] = dr
		var np := nearest_plan(pl, dr)
		if np["kind"] == "plaza":
			plaza_doors.append([b.id, dr, np["pt"]])
		else:
			var k: int = np["k"]
			if not attach.has(k):
				attach[k] = []
			(attach[k] as Array).append([float(np["d"]), b.id, dr, np["pt"]])
	# 광장 가의 문 → 뿌리
	for e: Array in plaza_doors:
		nodes.append({"pos": e[1], "parent": 0, "depth": 1, "pts": _bent(e[1], e[2], int(e[0])), "kind": "door", "b": e[0]})
	# 큰길: 입구(광장 가) → 붙은 자리들 (매개 순) — 줄줄이
	for k: int in attach.keys():
		var lst: Array = attach[k]
		lst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var mouth_d := float(pl["rp"]) * 0.85
		var prev := 0
		var prev_d := mouth_d
		# 입구 노드 (부모 = 뿌리, 선은 입구 한 점)
		nodes.append({"pos": street_at(pl, k, mouth_d), "parent": 0, "depth": 1, "pts": PackedVector2Array([street_at(pl, k, mouth_d)]), "kind": "street", "b": -1})
		prev = nodes.size() - 1
		for e: Array in lst:
			var d: float = maxf(float(e[0]), mouth_d)
			var sn := prev
			if d - prev_d > 0.05:
				var pts := PackedVector2Array()
				pts.append(street_at(pl, k, d))
				var i := floori(d)
				while i > prev_d:
					if float(i) < d - 0.05:
						pts.append(street_at(pl, k, float(i)))
					i -= 1
				pts.append(street_at(pl, k, prev_d))
				nodes.append({"pos": pts[0], "parent": prev, "depth": int(nodes[prev]["depth"]) + 1, "pts": pts, "kind": "street", "b": -1})
				sn = nodes.size() - 1
				prev = sn
				prev_d = d
			nodes.append({"pos": e[2], "parent": sn, "depth": int(nodes[sn]["depth"]) + 1, "pts": _bent(e[2], e[3], int(e[1])), "kind": "door", "b": e[1]})
	# 선분 목록 + 칸 통 (투영을 빨리)
	var sa := PackedVector2Array()
	var sb := PackedVector2Array()
	var sn_ := PackedInt32Array()
	var s0 := PackedFloat32Array()
	var buckets := {}
	for n in range(1, nodes.size()):
		var pts: PackedVector2Array = nodes[n]["pts"]
		var acc := 0.0
		for i in pts.size() - 1:
			sa.append(pts[i])
			sb.append(pts[i + 1])
			sn_.append(n)
			s0.append(acc)
			acc += pts[i].distance_to(pts[i + 1])
			var si := sa.size() - 1
			var lo := Vector2(minf(pts[i].x, pts[i + 1].x), minf(pts[i].y, pts[i + 1].y))
			var hi := Vector2(maxf(pts[i].x, pts[i + 1].x), maxf(pts[i].y, pts[i + 1].y))
			for by in range(floori(lo.y / 4.0), floori(hi.y / 4.0) + 1):
				for bx in range(floori(lo.x / 4.0), floori(hi.x / 4.0) + 1):
					var bk := Vector2i(bx, by)
					if not buckets.has(bk):
						buckets[bk] = PackedInt32Array()
					var arr: PackedInt32Array = buckets[bk]
					arr.append(si)
					buckets[bk] = arr
		nodes[n]["len"] = acc
	return {"nodes": nodes, "sa": sa, "sb": sb, "sn": sn_, "s0": s0, "buckets": buckets, "doors": doors, "fire": v.fire, "rp": float(pl["rp"])}


## 문 → 길 골목: 살짝 휜 선 (건물마다 같은 휨)
static func _bent(a: Vector2, b: Vector2, id: int) -> PackedVector2Array:
	var l := a.distance_to(b)
	var out := PackedVector2Array([a])
	if l > 2.5:
		var t := (b - a) / l
		var m := a.lerp(b, 0.5) + Vector2(-t.y, t.x) * (_h(id, 9) - 0.5) * minf(1.2, l * 0.15)
		out.append(m)
	out.append(b)
	return out


## 그래프 위 가장 가까운 점 → {"n", "s" (노드 끝에서 선을 따라), "pt", "dist"} (선분이 없으면 빈 사전)
static func project(g: Dictionary, p: Vector2) -> Dictionary:
	var sa: PackedVector2Array = g["sa"]
	if sa.is_empty():
		return {}
	var sb: PackedVector2Array = g["sb"]
	var buckets: Dictionary = g["buckets"]
	var best := -1
	var bd := INF
	var bu := 0.0
	var cx := floori(p.x / 4.0)
	var cy := floori(p.y / 4.0)
	for r in 4:
		for by in range(cy - r, cy + r + 1):
			for bx in range(cx - r, cx + r + 1):
				if maxi(absi(bx - cx), absi(by - cy)) != r:
					continue
				var arr: Variant = buckets.get(Vector2i(bx, by))
				if arr == null:
					continue
				for si: int in arr:
					var u := _seg_proj(p, sa[si], sb[si])
					var d := sa[si].lerp(sb[si], u).distance_to(p)
					if d < bd:
						bd = d
						best = si
						bu = u
		if best >= 0 and bd <= r * 4.0:
			break
	if best < 0:
		for si in sa.size():
			var u := _seg_proj(p, sa[si], sb[si])
			var d := sa[si].lerp(sb[si], u).distance_to(p)
			if d < bd:
				bd = d
				best = si
				bu = u
	var s0: PackedFloat32Array = g["s0"]
	return {"n": int(g["sn"][best]), "s": s0[best] + sa[best].distance_to(sb[best]) * bu, "pt": sa[best].lerp(sb[best], bu), "dist": bd}


## 노드 n의 선을 매개 s0 → s1로 따라간 점들 (끝점 포함, 시작점 제외)
static func _walk_edge(pts: PackedVector2Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	if s1 > s0:
		for i in pts.size():
			if cum[i] > s0 + 1e-4 and cum[i] < s1 - 1e-4:
				out.append(pts[i])
	else:
		for i in range(pts.size() - 1, -1, -1):
			if cum[i] < s0 - 1e-4 and cum[i] > s1 + 1e-4:
				out.append(pts[i])
	out.append(_at(pts, cum, s1))
	return out


static func _at(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	for i in range(1, pts.size()):
		if s <= cum[i]:
			var seg := cum[i] - cum[i - 1]
			return pts[i - 1].lerp(pts[i], (s - cum[i - 1]) / seg if seg > 1e-6 else 0.0)
	return pts[pts.size() - 1]


## 그래프 위 두 점 사이 길 (점들, 출발점 제외). 광장(뿌리)을 지나면 모닥불을 비켜 광장 가를 돈다
static func path_between(g: Dictionary, na: int, sa: float, nb: int, sb: float) -> PackedVector2Array:
	var nodes: Array = g["nodes"]
	if na == nb:
		return _walk_edge(nodes[na]["pts"], sa, sb)
	# 가장 가까운 공통 조상
	var a := na
	var b := nb
	var up_a: Array = [a]
	var up_b: Array = [b]
	while int(nodes[a]["depth"]) > int(nodes[b]["depth"]):
		a = nodes[a]["parent"]
		up_a.append(a)
	while int(nodes[b]["depth"]) > int(nodes[a]["depth"]):
		b = nodes[b]["parent"]
		up_b.append(b)
	while a != b:
		a = nodes[a]["parent"]
		b = nodes[b]["parent"]
		up_a.append(a)
		up_b.append(b)
	var lca := a
	var out := PackedVector2Array()
	if lca == na:
		# b가 a 아래: a의 선을 노드 a 쪽으로 내려간 뒤 b 쪽 길을 거꾸로
		out.append_array(_walk_edge(nodes[na]["pts"], sa, 0.0))
		out.append_array(_down(g, up_b, nb, sb))
		return out
	if lca == nb:
		out.append_array(_up(g, up_a, na, sa))
		out.append_array(_walk_edge(nodes[nb]["pts"], 0.0, sb))
		return out
	out.append_array(_up(g, up_a, na, sa))
	if lca == 0:
		var from := out[out.size() - 1] if not out.is_empty() else (nodes[na]["pts"] as PackedVector2Array)[0]
		var dn: PackedVector2Array = _down(g, up_b, nb, sb)
		var first: Vector2 = _first_up(g, up_b)
		out.append_array(_arc(g["fire"], from, first, float(g.get("rp", RP))))
		out.append_array(dn)
	else:
		out.append_array(_down(g, up_b, nb, sb))
	return out


## 노드 사슬 up (na … lca)을 따라 매개 s에서 lca 자리까지 (lca 자리는 마지막 점; 뿌리면 마지막 선의 끝 = 광장 가)
static func _up(g: Dictionary, up: Array, n: int, s: float) -> PackedVector2Array:
	var nodes: Array = g["nodes"]
	var out := PackedVector2Array()
	var pts: PackedVector2Array = nodes[n]["pts"]
	out.append_array(_walk_edge(pts, s, float(nodes[n]["len"])))
	for i in range(1, up.size() - 1):
		var m: int = up[i]
		var mp: PackedVector2Array = nodes[m]["pts"]
		for j in range(1, mp.size()):
			out.append(mp[j])
	return out


## lca 아래에서 b 쪽으로 내려가는 점들 (up_b를 거꾸로) — lca 다음 노드의 선 끝(부모 쪽)에서 시작해 매개 sb까지
static func _down(g: Dictionary, up_b: Array, nb: int, sb: float) -> PackedVector2Array:
	var nodes: Array = g["nodes"]
	var out := PackedVector2Array()
	for i in range(up_b.size() - 2, 0, -1):
		var m: int = up_b[i]
		var mp: PackedVector2Array = nodes[m]["pts"]
		for j in range(mp.size() - 2, -1, -1):
			out.append(mp[j])
	var pts: PackedVector2Array = nodes[nb]["pts"]
	out.append_array(_walk_edge(pts, float(nodes[nb]["len"]), sb))
	return out


## b 쪽 사슬에서 뿌리 바로 아래 노드 선의 끝 (광장 가 점)
static func _first_up(g: Dictionary, up_b: Array) -> Vector2:
	var nodes: Array = g["nodes"]
	var m: int = up_b[up_b.size() - 2] if up_b.size() >= 2 else up_b[0]
	var mp: PackedVector2Array = nodes[m]["pts"]
	return mp[mp.size() - 1]


## 광장 가를 도는 점들 (모닥불 둘레 RP*0.75) a → b
static func _arc(fire: Vector2, a: Vector2, b: Vector2, rp := RP) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a0 := (a - fire).angle()
	var a1 := (b - fire).angle()
	var da := wrapf(a1 - a0, -PI, PI)
	var n := int(absf(da) / 0.45)
	var rr := rp * 0.75
	for i in range(1, n + 1):
		var t := a0 + da * float(i) / (n + 1)
		out.append(fire + Vector2(cos(t), sin(t)) * rr)
	return out


# ───────────────────────── 걸음 길 찾기 ─────────────────────────
## 걸음 하나(s)를 길을 따라 걷도록 사이 걸음을 끼운다 (ResidentAI.update — 처음 걷기 시작할 때 한 번). 결정론: 그래프·위치만 읽음
static func route(v: Village, r: Resident, s: Dictionary) -> void:
	if not enabled:
		return
	var a := Vector2(r.x, r.y)
	var b := Vector2(s["x"], s["y"])
	var straight := a.distance_to(b)
	if straight < ROUTE_MIN:
		return
	var g := graph(v)
	var ea := _end(v, g, a)
	if ea.is_empty():
		return
	var eb := _end(v, g, b)
	var mid := path_between(g, int(ea["n"]), float(ea["s"]), int(eb["n"]), float(eb["s"]))
	var along := 0.0
	var prev: Vector2 = ea["pt"]
	for q in mid:
		along += prev.distance_to(q)
		prev = q
	var cost := float(ea["cost"]) + float(eb["cost"]) + along * ROAD_W
	if cost > straight * (CARRY_SLACK if r.carry != "" else ROUTE_SLACK):     # 짐을 든 사람은 더 기꺼이 길로 (밀·가루·빵 나르기)
		return
	var way := PackedVector2Array()
	way.append_array(ea["off"])            # a → (오솔길) → 길
	way.append_array(mid)
	var ob: PackedVector2Array = eb["off"]
	for i in range(ob.size() - 1, -1, -1):  # 길 → (오솔길) → b
		way.append(ob[i])
	for e: Dictionary in [ea, eb]:
		if e.has("trail"):
			_note_trail(v, e["cell"], e["trail"])
	var i := r.steps.find(s)
	var last := a
	var ins: Array = []
	for q in way:
		if q.distance_to(last) < 0.35 or q.distance_to(b) < 0.35:
			continue
		ins.append({"k": "walk", "x": q.x, "y": q.y, "rt": true})
		last = q
	for j in range(ins.size() - 1, -1, -1):
		r.steps.insert(i, ins[j])


## 걸음 끝 p를 그래프에 잇기 → {"n", "s", "pt", "off" (p 쪽 → 그래프 점, p 제외), "cost"}
static func _end(v: Village, g: Dictionary, p: Vector2) -> Dictionary:
	var pr := project(g, p)
	if pr.is_empty():
		return {}
	var dist: float = pr["dist"]
	if dist <= TRAIL_D:
		return {"n": pr["n"], "s": pr["s"], "pt": pr["pt"], "off": PackedVector2Array([pr["pt"]]), "cost": dist}
	# 오솔길: TRAIL_CELL 격자 한가운데로 모인다
	var cell := Vector2i(floori(p.x / TRAIL_CELL), floori(p.y / TRAIL_CELL))
	var c := (Vector2(cell) + Vector2(0.5, 0.5)) * TRAIL_CELL
	var pc := project(g, c)
	if float(pc["dist"]) > dist + 1.5 or c.distance_to(p) > dist:
		return {"n": pr["n"], "s": pr["s"], "pt": pr["pt"], "off": PackedVector2Array([pr["pt"]]), "cost": dist}
	var gp: Vector2 = pc["pt"]
	if c.distance_to(gp) > TRAIL_MAX:
		return {"n": pr["n"], "s": pr["s"], "pt": pr["pt"], "off": PackedVector2Array([pr["pt"]]), "cost": dist}
	var trail := _bent(gp, c, cell.x * 92821 + cell.y)
	var off := PackedVector2Array()
	for i in range(trail.size() - 1, -1, -1):     # c → … → 그래프 점
		off.append(trail[i])
	return {"n": pc["n"], "s": pc["s"], "pt": gp, "off": off, "cost": c.distance_to(p) + float(pc["dist"]) * TRAIL_W,
		"cell": cell, "trail": trail}


static func _note_trail(v: Village, cell: Vector2i, pts: PackedVector2Array) -> void:
	var iid := v.get_instance_id()
	if not _trails.has(iid):
		if _trails.size() > 32:
			_trails.clear()
		_trails[iid] = {}
	var m: Dictionary = _trails[iid]
	m[cell] = {"pts": pts, "t": v.t}


static func trails(v: Village) -> Array:
	var m: Dictionary = _trails.get(v.get_instance_id(), {})
	return m.values()


# ───────────────────────── 그림: 오솔길 텍스처 ─────────────────────────
## 발길 지도 칸 값 (격자 밖 0) — 둘레 3×3 최댓값 (선이 칸 사이를 지나도)
static func _raw_max(v: Village, p: Vector2) -> float:
	var gx := floori((p.x - v.center.x + v.path_r) / (2.0 * v.path_r) * v.path_n)
	var gy := floori((p.y - v.center.y + v.path_r) / (2.0 * v.path_r) * v.path_n)
	var m := 0.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := gx + dx
			var y := gy + dy
			if x >= 0 and y >= 0 and x < v.path_n and y < v.path_n:
				m = maxf(m, v.paths[y * v.path_n + x])
	return m


## 선을 0.7칸 간격으로 나눈 점들 + 점마다 닳음 (0~1, 이웃과 고르게)
static func _wear_line(v: Village, pts: PackedVector2Array, sm: float) -> Array:
	var dense := PackedVector2Array()
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		var n := maxi(1, ceili(l / 0.7))
		for j in n:
			dense.append(pts[i].lerp(pts[i + 1], float(j) / n))
	dense.append(pts[pts.size() - 1])
	var raw := PackedFloat32Array()
	for q in dense:
		raw.append(_raw_max(v, q))
	var w := PackedFloat32Array()
	w.resize(dense.size())
	for i in dense.size():
		var s := 0.0
		var c := 0
		for j in range(maxi(0, i - 3), mini(dense.size(), i + 4)):
			s += raw[j]
			c += 1
		w[i] = GroundLook.path_value(s / c * sm)
	return [dense, w]


static func _half_w(w: float, kind: String) -> float:
	var t := smoothstep(0.42, 1.0, w)
	var hw := lerpf(0.2, 0.58, t)
	if kind == "door":
		hw *= 0.72
	elif kind == "trail":
		hw *= 0.65
	return hw


## 띠 하나 그리기 (값 = min(닳음, 0.5 + (반폭 − 거리)·K) — 셰이더가 0.5에서 끊고 그 위는 흙, STONE_V 위는 자갈)
static func _stamp_line(buf: PackedFloat32Array, n: int, o: Vector2, cell: float, dense: PackedVector2Array, w: PackedFloat32Array, kind: String) -> void:
	for i in dense.size() - 1:
		var a := dense[i]
		var b := dense[i + 1]
		var wm := maxf(w[i], w[i + 1])
		if wm < 0.12:
			continue
		var hw := _half_w(wm, kind)
		var reach := hw + 0.5 / K
		var x0 := maxi(0, floori((minf(a.x, b.x) - reach - o.x) / cell))
		var x1 := mini(n - 1, ceili((maxf(a.x, b.x) + reach - o.x) / cell))
		var y0 := maxi(0, floori((minf(a.y, b.y) - reach - o.y) / cell))
		var y1 := mini(n - 1, ceili((maxf(a.y, b.y) + reach - o.y) / cell))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p := o + Vector2((x + 0.5) * cell, (y + 0.5) * cell)
				var u := _seg_proj(p, a, b)
				var d := a.lerp(b, u).distance_to(p)
				var ww := lerpf(w[i], w[i + 1], u)
				var hwu := _half_w(ww, kind)
				var val := minf(ww, 0.5 + (hwu - d) * K)
				var k := y * n + x
				if val > buf[k]:
					buf[k] = val


static func _stamp_disc(buf: PackedFloat32Array, n: int, o: Vector2, cell: float, c: Vector2, r: float, w: float) -> void:
	var reach := r + 0.5 / K
	var x0 := maxi(0, floori((c.x - reach - o.x) / cell))
	var x1 := mini(n - 1, ceili((c.x + reach - o.x) / cell))
	var y0 := maxi(0, floori((c.y - reach - o.y) / cell))
	var y1 := mini(n - 1, ceili((c.y + reach - o.y) / cell))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := o + Vector2((x + 0.5) * cell, (y + 0.5) * cell)
			var val := minf(w, 0.5 + (r - p.distance_to(c)) * K)
			var k := y * n + x
			if val > buf[k]:
				buf[k] = val


## 무리의 오솔길 텍스처 값 (path_n², 0~1) — 그래프 띠 + 광장 + 문 앞 + 숲 오솔길 + (닳은 풀까지만) 그래프 밖 발길
static func road_values(v: Village, sm: float) -> PackedFloat32Array:
	var n := v.path_n
	var buf := PackedFloat32Array()
	buf.resize(n * n)
	var cell := 2.0 * v.path_r / n
	var o := v.center - Vector2(v.path_r, v.path_r)
	for i in mini(v.paths.size(), n * n):
		var raw := v.paths[i]
		if raw > 0.0:
			buf[i] = minf(RAW_CAP, GroundLook.path_value(raw * sm) * RAW_K)
	if v.buildings.is_empty():
		return buf
	var g := graph(v)
	var nodes: Array = g["nodes"]
	var plaza_w := 0.0
	for nn in range(1, nodes.size()):
		var nd: Dictionary = nodes[nn]
		var pts: PackedVector2Array = nd["pts"]
		if pts.size() < 2:
			continue
		var lw: Array = _wear_line(v, pts, sm)
		var w: PackedFloat32Array = lw[1]
		_stamp_line(buf, n, o, cell, lw[0], w, nd["kind"])
		if nd["kind"] == "door":
			_stamp_disc(buf, n, o, cell, pts[0], 0.5, minf(w[0], 0.75))
		if int(nd["parent"]) == 0 or (int(nd["parent"]) > 0 and int(nodes[int(nd["parent"])]["parent"]) == 0 and nd["kind"] == "street"):
			plaza_w = maxf(plaza_w, w[w.size() - 1])
	# 광장: 모이는 길들만큼 닳은 둥근 빈 땅 (광장이 서면·읍내면 자갈 — GroundLook.stone_roads)
	var pz := VillageEra.first_built(v, "광장") != null
	_stamp_disc(buf, n, o, cell, v.fire, plaza_r(v) * (1.05 if pz else 0.8), minf(1.0, plaza_w + (0.15 if pz else 0.03)))
	# 숲 오솔길 (안 다니면 발길이 옅어져 사라진다)
	var m: Dictionary = _trails.get(v.get_instance_id(), {})
	for ck: Vector2i in m.keys():
		var tr: Dictionary = m[ck]
		var lw: Array = _wear_line(v, tr["pts"], sm)
		var w: PackedFloat32Array = lw[1]
		var mx := 0.0
		for x in w:
			mx = maxf(mx, x)
		if mx < 0.08 and v.t - float(tr["t"]) > Balance.HOUR:
			m.erase(ck)
			continue
		_stamp_line(buf, n, o, cell, lw[0], w, "trail")
	return buf


## 텍스처 이미지 (L8) — view/world_terrain.gd · jar_terrain.gd
static func road_image(v: Village, sm: float) -> Image:
	var buf := road_values(v, sm)
	var data := PackedByteArray()
	data.resize(buf.size())
	for i in buf.size():
		data[i] = clampi(int(clampf(buf[i], 0.0, 1.0) * 255.0), 0, 255)
	return Image.create_from_data(v.path_n, v.path_n, false, Image.FORMAT_L8, data)


# ───────────────────────── 디버그 그림 ─────────────────────────
## 위에서 본 길 그래프 (ppu 픽셀/칸, 마을 둘레 2·path_r 정사각형): 물 파랑 · 발길 회색 · 계획 큰길 옅은 선 · 그래프 띠(닳음 = 진하기) ·
## 건물 원(집 주황·일터 갈색·밭 노랑) + 바라보는 쪽 · 문 점 · 오솔길 초록 · 광장 원
static func debug_image(v: Village, ppu: int) -> Image:
	var span := 2.0 * v.path_r
	var sz := int(span * ppu)
	var img := Image.create(sz, sz, false, Image.FORMAT_RGB8)
	img.fill(Color(0.86, 0.9, 0.78))
	var o := v.center - Vector2(v.path_r, v.path_r)
	var to_px := func(p: Vector2) -> Vector2i: return Vector2i(int((p.x - o.x) * ppu), int((p.y - o.y) * ppu))
	# 물·발길
	for py in range(0, sz, 2):
		for px in range(0, sz, 2):
			var p := o + Vector2(px + 1, py + 1) / float(ppu)
			var c := Color(0.86, 0.9, 0.78)
			if v.water.inside(p.x, p.y) and v.water_at(p.x, p.y):
				c = Color(0.45, 0.65, 0.9)
			var raw := v.path_at(p.x, p.y)
			if raw > 0.0:
				c = c.lerp(Color(0.55, 0.45, 0.35), clampf(GroundLook.path_value(raw * WorldTerrain.path_sum(v)), 0.0, 1.0) * 0.6)
			img.fill_rect(Rect2i(px, py, 2, 2), c)
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			_dot(img, to_px.call(Vector2(tr["x"], tr["y"])), 2, Color(0.25, 0.5, 0.3))
	var pl := plan(v)
	for k in pl["streets"].size():
		var pts: PackedVector2Array = pl["streets"][k]
		for i in pts.size() - 1:
			_line(img, to_px.call(pts[i]), to_px.call(pts[i + 1]), Color(0.7, 0.72, 0.65), 1)
	var g := graph(v)
	var sm := WorldTerrain.path_sum(v)
	for nd: Dictionary in g["nodes"]:
		var pts: PackedVector2Array = nd["pts"]
		if pts.size() < 2:
			continue
		var lw: Array = _wear_line(v, pts, sm)
		var dense: PackedVector2Array = lw[0]
		var w: PackedFloat32Array = lw[1]
		for i in dense.size() - 1:
			var col := Color(0.75, 0.6, 0.4).lerp(Color(0.35, 0.2, 0.1), clampf(w[i], 0.0, 1.0))
			_line(img, to_px.call(dense[i]), to_px.call(dense[i + 1]), col, 1 + int(w[i] * 3.0))
	for tr: Dictionary in trails(v):
		var pts: PackedVector2Array = tr["pts"]
		for i in pts.size() - 1:
			_line(img, to_px.call(pts[i]), to_px.call(pts[i + 1]), Color(0.1, 0.55, 0.15), 1)
	_circle(img, to_px.call(v.fire), int(plaza_r(v) * ppu), Color(0.5, 0.35, 0.2))
	_dot(img, to_px.call(v.fire), 3, Color(1, 0.4, 0))
	for b in v.buildings:
		var c := Color(0.9, 0.55, 0.25) if b.is_house() else (Color(0.95, 0.85, 0.3) if b.type == "농장" else Color(0.55, 0.35, 0.25))
		if b.is_store:
			c = Color(0.3, 0.3, 0.8)
		var bp: Vector2i = to_px.call(Vector2(b.x, b.y))
		_dot(img, bp, int(b.size() * ppu), c)
		var f := face_dir(v, b)
		_line(img, bp, to_px.call(Vector2(b.x, b.y) + f * b.size()), Color(0, 0, 0), 1)
		_dot(img, to_px.call(g["doors"][b.id]), 2, Color(0.8, 0, 0))
	return img


static func _dot(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var p := c + Vector2i(x, y)
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(p, col)


static func _circle(img: Image, c: Vector2i, r: int, col: Color) -> void:
	for i in 96:
		var a := TAU * i / 96.0
		var p := c + Vector2i(int(cos(a) * r), int(sin(a) * r))
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(p, col)


static func _line(img: Image, a: Vector2i, b: Vector2i, col: Color, w: int) -> void:
	var n := maxi(1, maxi(absi(b.x - a.x), absi(b.y - a.y)))
	for i in n + 1:
		var p := Vector2(a).lerp(Vector2(b), float(i) / n)
		_dot(img, Vector2i(p), maxi(0, w - 1), col)
