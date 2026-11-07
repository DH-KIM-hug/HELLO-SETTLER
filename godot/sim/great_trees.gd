## 세상에 한 그루씩만 있는 큰 나무 다섯 (GAME_DESIGN 3.0 — 2026-11-07 사용자 결정, ROADMAP E3-3·E3-4).
## 세계수·소나무·과일나무·은행나무·단풍나무 — 분재 모양 랜드마크. 베지 않는다 (Village.trees에 넣지 않음 → 나무꾼·건물·길이 건드리지 않음).
## 세상을 만들 때(WorldGen.generate 끝) 시드로 정한 자리에 하나씩: 서로 멀리, 좋은 키트 자리(물가 마을 터)에서 멀리, 물가에서 떨어져.
## 키트 자리 고르기도 큰 나무 곁은 막는다 (어느 부락도 처음부터 곁에 있지 않음 — 탐험·이주의 목표).
## 과일나무는 여름~가을에 가끔 거대한 열매를 떨어뜨린다 (WorldWater.giant_fruits) — 지금은 데이터 + 화면만.
## TODO(E3-4): 주민이 열매를 주워 나르기 (여럿이 메고 오는 볼거리, 하나로 여러 날 먹는 큰 먹을거리 — BALANCE에 값 정하기)
class_name GreatTrees
extends RefCounted

const KINDS := ["world", "pine", "fruit", "ginkgo", "maple"]
const NAMES := {"world": "세계수", "pine": "소나무", "fruit": "과일나무", "ginkgo": "은행나무", "maple": "단풍나무"}
## 줄기 둘레 (칸) — 이 안에는 짓지 않고 숲(꽃숲)도 두지 않는다. 화면 크기 0.6배 모델의 뿌리·줄기 폭
const TRUNK_R := {"world": 22.0, "pine": 15.0, "fruit": 13.0, "ginkgo": 14.0, "maple": 15.0}
const KIT_APART := 70.0           # 키트(첫 마을 터 지름 64칸)는 큰 나무에서 이만큼 떨어져야
const SPOT_APART := 12.0          # 세상이 고른 좋은 키트 자리에서 kit_apart + 이만큼 (키트 막는 거리보다 넉넉히 — 추천 자리를 지우지 않게)
const DRY_R := 16.0               # 이 안에 호수·강이 없는 땅
## 거대한 열매 (과일나무 — 여름·가을)
const FRUIT_MONTHS := [6, 7, 8, 9, 10]
const FRUIT_PER_HOUR := 1.0 / 36.0     # 철이면 한 시간에 이만큼 (병의 하루 24시간 → 약 이틀 반에 하나)
const FRUIT_MAX := 3                   # 땅에 이만큼까지
const FRUIT_ROT_DAYS := 8.0            # 이 날 동안 아무도 안 주우면 썩어 사라짐
const FRUIT_FOOD := 60.0               # (안) 열매 하나 = 먹을거리 — 줍기가 생기면 BALANCE로


## 세상 만들기 끝에 (물이 자리 잡은 뒤) 다섯 그루를 세운다. 결정론: 같은 시드 → 같은 자리. 옛 저장은 불러올 때 ensure()
static func place(ww: WorldWater, avoid: Array = []) -> void:
	ww.great_trees.clear()
	ww.giant_fruits.clear()
	var R := ww.rr
	var rng := RandomNumberGenerator.new()
	rng.seed = ww.seed_v * 131 + 977
	var a0 := rng.randf() * TAU
	var min_apart := R * 0.45
	var spots: Array = []
	for s in ww.spots:
		spots.append(s)
	for p: Variant in avoid:
		spots.append(p)
	for i in KINDS.size():
		var kind: String = KINDS[i]
		var best := Vector2.ZERO
		var best_v := -INF
		for tries in 120:
			var jit := 0.45 + tries * 0.03            # 제 몫(다섯 등분)에서 못 찾으면 점점 넓게
			var a := a0 + TAU * i / KINDS.size() + rng.randf_range(-jit, jit)
			var rad := R * rng.randf_range(0.36, 0.8)
			var p := Vector2(cos(a), sin(a)) * rad
			var v := _score(ww, p, kind, spots, min_apart)
			if v > best_v:
				best_v = v
				best = p
			if v >= 0.0:
				break
		ww.great_trees.append({"kind": kind, "name": NAMES[kind], "x": best.x, "y": best.y, "r": float(TRUNK_R[kind]), "yaw": rng.randf() * TAU})
	# 큰 나무 줄기 둘레의 숲 무리는 비킨다 (분재 아래는 이끼·풀만 — 화면 장식)
	var kept: Array[Dictionary] = []
	for f: Dictionary in ww.forests:
		if near(ww, Vector2(f["x"], f["y"]), float(f["r"]) * 0.6).is_empty():
			kept.append(f)
	ww.forests = kept


## 자리 점수: 0 이상 = 조건을 모두 채움. 모자라면 얼마나 모자란지 (음수, 덜 나쁜 쪽을 고름 — 작은 세상에서도 꼭 다섯)
static func _score(ww: WorldWater, p: Vector2, kind: String, spots: Array, min_apart: float) -> float:
	var r: float = TRUNK_R[kind]
	var v := 0.0
	if not ww.inside(p.x, p.y, r + 24.0):
		v -= 1000.0
	for s: Vector2 in spots:
		v -= 20.0 * maxf(0.0, kit_apart(ww) + SPOT_APART + r - p.distance_to(s))      # 추천 키트 자리를 막지 않는 것이 가장 먼저
	for t: Dictionary in ww.great_trees:
		v -= 10.0 * maxf(0.0, min_apart - p.distance_to(Vector2(t["x"], t["y"])))     # 서로 멀리가 가장 먼저
	for d: Dictionary in ww.drips:
		v -= maxf(0.0, 30.0 + r - p.distance_to(Vector2(d["x"], d["y"])))
	if v < -2000.0:
		return v                    # 이미 멀리 어긋난 자리 — 물 칸 세기는 건너뜀
	var cells := ww.cells_near(p, r + 3.0)
	for i in range(0, cells.size(), 3):         # 줄기 둘레 칸 (셋 중 하나) — 줄기가 물에 잠기면 안 됨
		if ww.depth(cells[i]) > 0.004:
			v -= 150.0
	var wet := 0
	for k in 16:
		for rr: float in [r + DRY_R * 0.5, r + DRY_R]:
			var q := p + Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * rr
			if not ww.inside(q.x, q.y):
				continue
			var kk := ww.idx(q.x, q.y)
			if ww.depth(kk) > 0.004 or ww.is_river(kk):
				wet += 1
	v -= wet * 5.0
	return v


## 옛 저장 (큰 나무가 생기기 전) — 불러올 때 한 번 세운다 (무리 자리에서 멀리)
static func ensure(jw: JarWorld) -> void:
	var ww := jw.water
	if ww == null or not ww.great_trees.is_empty():
		return
	var avoid: Array = []
	for s in jw.settlements:
		avoid.append(s.center)
	place(ww, avoid)


## p에서 큰 나무 줄기 둘레(+pad) 안이면 그 나무 (아니면 빈 사전)
static func near(ww: JarWater, p: Vector2, pad := 0.0) -> Dictionary:
	if not ww is WorldWater:
		return {}
	for t: Dictionary in (ww as WorldWater).great_trees:
		if p.distance_to(Vector2(t["x"], t["y"])) < float(t["r"]) + pad:
			return t
	return {}


## 짓기·숲 퍼지기를 막는 곳인가
static func blocks(ww: JarWater, x: float, y: float, size: float) -> bool:
	return not near(ww, Vector2(x, y), size + 1.0).is_empty()


## 키트와 큰 나무 사이 (작은 세상 — 느린 기기·시험 — 은 줄여서: 다섯 그루와 추천 자리 넷이 모두 들어가게)
static func kit_apart(ww: WorldWater) -> float:
	return KIT_APART * clampf(ww.rr / 512.0, 0.6, 1.0)


## 키트 자리로 너무 가까운가 (JarWorld.kit_spot_ok)
static func too_close_for_kit(ww: WorldWater, p: Vector2) -> bool:
	for t: Dictionary in ww.great_trees:
		if p.distance_to(Vector2(t["x"], t["y"])) < kit_apart(ww) + float(t["r"]):
			return true
	return false


static func of_kind(ww: WorldWater, kind: String) -> Dictionary:
	for t: Dictionary in ww.great_trees:
		if t["kind"] == kind:
			return t
	return {}


## 한 시간에 한 번 (물을 흘리는 첫 무리가 — 병 하나에 한 번): 과일나무 열매가 떨어지고, 오래된 열매는 썩는다.
## 마을 난수(rng)를 쓰지 않는다 — 시간으로 정한 난수 (다른 시뮬레이션의 흐름을 바꾸지 않게)
static func hourly(v: Village) -> void:
	if not v.water is WorldWater:
		return
	var ww := v.water as WorldWater
	var ft := of_kind(ww, "fruit")
	if ft.is_empty():
		return
	var now := v.t
	var rot := FRUIT_ROT_DAYS * Balance.DAY
	ww.giant_fruits = ww.giant_fruits.filter(func(f: Dictionary) -> bool: return now - float(f["t"]) < rot)
	var month: int = Health.jar_date(v)["month"]
	if not month in FRUIT_MONTHS or ww.giant_fruits.size() >= FRUIT_MAX:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ww.seed_v * 7919 + int(now / 3600.0)
	if rng.randf() >= FRUIT_PER_HOUR:
		return
	drop_fruit(ww, rng, now)


## 열매 하나 떨어뜨림 (줄기 곁 잎 그늘 아래, 물이 아닌 땅)
static func drop_fruit(ww: WorldWater, rng: RandomNumberGenerator, now: float) -> Dictionary:
	var ft := of_kind(ww, "fruit")
	if ft.is_empty():
		return {}
	var c := Vector2(ft["x"], ft["y"])
	for k in 12:
		var a := rng.randf() * TAU
		var d := rng.randf_range(float(ft["r"]) + 4.0, float(ft["r"]) + 14.0)     # 잎 가장자리 아래 (가지 끝에서 떨어짐 — 잎에 가리지 않게)
		var p := c + Vector2(cos(a), sin(a)) * d
		if not ww.inside(p.x, p.y, 2.0) or ww.depth(ww.idx(p.x, p.y)) > 0.004:
			continue
		var f := {"x": p.x, "y": p.y, "t": now, "yaw": rng.randf() * TAU, "food": FRUIT_FOOD}
		ww.giant_fruits.append(f)
		return f
	return {}
