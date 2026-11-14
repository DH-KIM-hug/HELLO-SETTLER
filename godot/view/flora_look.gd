## 소인의 세상 꽃숲 (GAME_DESIGN 3.0 · ROADMAP E3-3) — 보통 나무 대신 거대한 꽃·풀대·고사리·이끼 덩이.
## 시뮬레이션의 나무(Village.trees — 칸·수·'나무 → 통나무' 경제는 그대로)를 화면에서 꽃숲 덩이로 그린다:
##   tree = 철마다 바뀌는 꽃 또는 늘 있는 풀·고사리·이끼 · stump(벤 자리) = 나뭇가지 더미 · sapling = 클로버·풀 싹.
## 모델은 art/models/flora/*.glb (주민 키 = 1, 진짜 크기 — 해바라기 36). 마을 칸에 맞게 높이를 √로 눌러 쓴다:
##   화면 높이 ≈ K·√(모델 높이) → 풀 4~5 · 작은 꽃 7~8 · 튤립 10 · 해바라기 14 (주민의 4~14배). 폭은 W_MAX를 넘지 않게.
## 같은 모양끼리 MultiMesh (VillageView._flush) — 철마다 꽃 6가지 + 초록 6가지만 써서 그리기 횟수를 옛 나무 숲과 비슷하게.
class_name FloraLook
extends RefCounted

const K := 2.3                    # 화면 높이 = K·√(모델 높이)
const W_MAX := 7.0                # 꽃 폭 상한 (칸)
const W_MAX_GREEN := 5.5          # 풀·고사리·이끼 폭 상한
const GREAT_SCALE := 0.6          # 큰 나무 다섯 (은행나무 높이 약 92 → 55칸)
const FRUIT_SCALE := 0.9          # 떨어진 거대한 열매
## 폭 상한을 따로 두는 것 (2026-11-08 "이끼, 고사리 크기") — 고사리는 키보다 넓게 펼쳐지는 풀이라 W_MAX로 누르면 무릎 높이 덤불이 된다.
##   props/pf_fern: 진짜 키 9 (45cm) → 화면 약 6.9 · 폭 약 9.4 (주민이 그 아래를 걷는 거대한 고사리 — 숲 가장자리에만)
const W_MAX_BY := {"props/pf_fern": 10.0}

## 철마다 꽃 (GD 3.0 꽃 표) — 앞쪽일수록 자주
const FLOWERS := {
	"봄": ["flora/dandelion_a", "flora/tulip_red", "flora/daffodil_a", "flora/violet_a", "flora/tulip_yellow", "flora/dandelion_puff"],
	"여름": ["flora/daisy_a", "flora/poppy_red", "flora/sunflower_a", "flora/hydrangea_blue", "flora/morning_glory_a", "flora/rose_pink"],
	"가을": ["flora/cosmos_pink", "flora/chrysanthemum_gold", "flora/cosmos_white", "flora/silver_grass_a", "flora/cosmos_magenta", "flora/chrysanthemum_rust"],
	"겨울": ["flora/silver_grass_b", "flora/foxtail_b", "flora/chrysanthemum_white"],
}
## 늘 있는 초록 (풀대·고사리·이끼·클로버)
const GREEN := ["flora/grass_a", "flora/grass_c", "flora/fern_a", "flora/moss_a", "flora/clover_a", "flora/moss_c"]
## 꽃이 될 몫 (나머지는 초록) — 겨울엔 거의 마른 풀·이끼
const FLOWER_SHARE := {"봄": 0.55, "여름": 0.6, "가을": 0.55, "겨울": 0.3}
## 멀리(마을 둘레 밖) 숲: 모양 가짓수를 줄여 그리기 횟수를 아낌
const FAR_FLOWERS := 3
const FAR_GREEN := ["flora/grass_a", "flora/fern_a", "flora/moss_a"]
const TWIGS := ["flora/twig_pile_a", "flora/twig_pile_b"]
const SPROUTS := ["flora/clover_a", "flora/grass_b"]
## 그림자를 드리우지 않는 것 (납작한 것)
const NO_SHADOW := ["flora/moss_a", "flora/moss_c", "flora/clover_a", "flora/twig_pile_a", "flora/twig_pile_b", "flora/grass_b"]

static var _base := {}            # 모델 이름 → 기본 크기 배율 (높이·폭에서 한 번 셈)


## 지금 철 ("봄"·"여름"·"가을"·"겨울") — 땅 셰이더와 같은 날짜 (GroundLook.month_override도 따름)
static func season_of(v: Village) -> String:
	return String(GroundLook.season_now(v).get("season", "봄"))


static func base_scale(name: String) -> float:
	if _base.has(name):
		return _base[name]
	var s := 1.0
	var m: Mesh = Art.model(name).get("mesh")
	if m != null:
		var sz := m.get_aabb().size
		var green := name in GREEN or name in SPROUTS or name in FAR_GREEN
		var h := maxf(sz.y, 0.5)
		s = K * sqrt(h) / h
		var w_max: float = W_MAX_BY.get(name, W_MAX_GREEN if green else W_MAX)
		s = minf(s, w_max / maxf(0.5, maxf(sz.x, sz.z)))
		s = minf(s, 1.0)
		if name in TWIGS:
			s = 0.42                # 나뭇가지 더미 폭 약 2.2칸 (그루터기 자리 — 잔가지 하나 10cm = 주민 2명 길이)
		elif name.contains("fallen_leaf"):
			s = 0.3                 # 떨어진 큰 잎 (폭 약 2.2칸 — 잎 한 장이 주민보다 큰 깔개)
	_base[name] = s
	return s


## 시뮬레이션 나무 한 그루 → [모델, 배율]. h = 0~1 자리 해시 (늘 같은 모양), far = 멀리 숲 (가짓수 적게)
static func clump(season: String, h: float, h2: float, far := false) -> Array:
	var fl: Array = FLOWERS.get(season, FLOWERS["봄"])
	var name: String
	if h < float(FLOWER_SHARE.get(season, 0.5)):
		var n := mini(fl.size(), FAR_FLOWERS) if far else fl.size()
		# 앞쪽 꽃이 자주 (h2² → 0 쪽으로 몰림)
		name = fl[mini(n - 1, int(h2 * h2 * n))]
	else:
		var g: Array = FAR_GREEN if far else GREEN
		name = g[int(h2 * g.size()) % g.size()]
	return [name, base_scale(name) * (0.82 + 0.36 * fposmod(h * 7.31 + h2 * 3.7, 1.0))]


## ───────── 군락 (design/gdd/flower-forest.md "### 군락", 사용자 2026-11-08 "꽃들이 중구난방 — 군락도 필요") ─────────
## 화면 규칙만 (시뮬 나무 칸·수 그대로 — ADR-0001). 꽃 종류를 그루마다 따로 뽑지 않고 땅 위 얼룩(군락)마다 주인 꽃을 정한다:
##   · 넓은 얼룩 (COLONY_CELL칸 격자의 흔들린 보로노이 + 굽은 경계) — 얼룩마다 주인 역할 (들판·트인 땅·덩굴·그늘) 하나, 약 30%는 섞인 들.
##     꽃 몫의 약 80%가 주인 꽃, 경계 BLEED칸 안에서는 이웃 얼룩 꽃이 번져 듦 + 군데군데 다른 꽃 (ACCENT).
##   · 키 큰 꽃 (해바라기 등): 작은 격자(TALL_CELL)의 일부 칸 한가운데에만 작은 무리.
##   · 자리 성질 (site = (젖음 0~1, 숲 짙기 0~1) — 부르는 쪽이 땅에서 읽음): 물가·깊은 그늘 = 그늘 꽃 (수국) + 이끼·고사리,
##     숲 가장자리 띠 = 가시덤불 (장미) 토막 띠, 그 곁 = 덩굴 (나팔꽃), 트인 땅 = 들판 꽃 (데이지·양귀비 / 민들레 / 코스모스).
##   · 철마다 역할 → 꽃 (ROLES) — 같은 얼룩이 철따라 그 철의 같은 역할 꽃으로 바뀐다 (봄 민들레 들판 → 여름 데이지 → 가을 코스모스).
##   · 얼룩 자리 = 위치 + 병 씨앗 (seed) 해시 — 병마다 다르고, 같은 병에서는 늘 같다.
##   · 모양 가짓수는 그대로 (철마다 꽃 6 + 초록 6 · 멀리 꽃 3 + 초록 3) → 같은 모양끼리 MultiMesh, 그리기 횟수 그대로.
enum { R_FIELD, R_OPEN, R_TALL, R_SHADE, R_VINE, R_THICKET }
## 철 → 역할별 꽃 (R_FIELD, R_OPEN, R_TALL, R_SHADE, R_VINE, R_THICKET) — 모두 FLOWERS[철] 안의 이름
const ROLES := {
	"봄": ["flora/dandelion_a", "flora/tulip_red", "flora/daffodil_a", "flora/violet_a", "flora/dandelion_puff", "flora/tulip_yellow"],
	"여름": ["flora/daisy_a", "flora/poppy_red", "flora/sunflower_a", "flora/hydrangea_blue", "flora/morning_glory_a", "flora/rose_pink"],
	"가을": ["flora/cosmos_pink", "flora/cosmos_white", "flora/chrysanthemum_gold", "flora/silver_grass_a", "flora/cosmos_magenta", "flora/chrysanthemum_rust"],
	"겨울": ["flora/silver_grass_b", "flora/foxtail_b", "flora/chrysanthemum_white", "flora/silver_grass_b", "flora/foxtail_b", "flora/chrysanthemum_white"],
}
## 넓은 얼룩의 주인 역할 몫 (들판·트인 땅이 넓게, 덩굴·그늘은 가끔) — 키 큰 꽃·가시덤불은 자리 규칙으로만
const DOMINANT_W := [[R_FIELD, 0.44], [R_OPEN, 0.36], [R_VINE, 0.12], [R_SHADE, 0.08]]
## 섞인 들에서 한 그루씩 뽑는 몫 (두 표 모두 합 1)
const MIXED_W := [[R_FIELD, 0.3], [R_OPEN, 0.25], [R_TALL, 0.08], [R_SHADE, 0.12], [R_VINE, 0.13], [R_THICKET, 0.12]]
const COLONY_CELL := 12.0         # 넓은 얼룩 격자 (칸) — 얼룩 지름 약 8~16칸
const GREEN_CELL := 9.0           # 초록 얼룩 격자
const TALL_CELL := 7.0            # 키 큰 꽃 무리 격자
const TALL_P := 0.3               # 그중 무리가 서는 칸 몫
const TALL_R := 2.2               # 무리 반지름 (칸, 칸마다 ×0.7~1.3)
const MIXED_P := 0.3              # 섞인 들 몫
const BLEED := 3.0                # 경계에서 이웃 얼룩이 번지는 너비 (칸)
const ACCENT := 0.1               # 얼룩 안 군데군데 다른 꽃
const WARP := 2.6                 # 경계를 굽히는 세기 (칸) — 바둑판 덩이가 되지 않게
const WET_AT := 0.42              # 이보다 젖으면 물가 (그늘 꽃·이끼·고사리)
const EDGE_BAND := Vector2(0.1, 0.26)   # 숲 짙기 이 사이 = 숲 가장자리 (가시덤불 띠)
const THICKET_P := 0.45          # 숲 가장자리 중 가시덤불 띠가 서는 토막 몫
const DEEP_SHADE := 0.82          # 이보다 짙으면 숲 속 (소형 병 숲은 대부분 1 — 그래서 그늘 숲은 얼룩 일부만)
const SHADE_GROVE := 0.18         # 숲 속 얼룩 중 그늘 꽃 숲이 되는 몫
const GREEN_OPEN := ["flora/grass_a", "flora/grass_c", "flora/clover_a"]
const GREEN_SHADE := ["flora/fern_a", "flora/moss_a", "flora/moss_c"]

static var _cells := {}           # (캐시) 격자 칸 → [흔들린 점, 해시 셋] — 씨앗이 바뀌면 비움
static var _cells_seed := -1


static func _hh(x: float, y: float, k: float) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7 + k * 74.7) * 43758.5453, 1.0)


## 격자 칸 (layer마다 따로) → [점, a, b, c] (a·b·c = 0~1 해시)
static func _cell(ix: int, iy: int, layer: int, size: float, sf: float) -> Array:
	var key := Vector3i(ix, iy, layer)
	var c: Variant = _cells.get(key)
	if c != null:
		return c
	var fx := float(ix) + sf * 0.37 + layer * 17.0
	var fy := float(iy) - sf * 0.61 + layer * 29.0
	var out := [Vector2(ix + 0.15 + 0.7 * _hh(fx, fy, 1.0), iy + 0.15 + 0.7 * _hh(fx, fy, 2.0)) * size,
		_hh(fx, fy, 3.0), _hh(fx, fy, 4.0), _hh(fx, fy, 5.0)]
	_cells[key] = out
	return out


## 흔들린 보로노이: [가장 가까운 칸, 거리, 두 번째 칸, 거리]
static func _near2(q: Vector2, layer: int, size: float, sf: float) -> Array:
	# 가까운 2×2 칸만 (흔들림이 칸의 15~85% 안이라 거의 늘 충분 — 9칸 대신 4칸으로 값을 반)
	var ix := floori(q.x / size - 0.5)
	var iy := floori(q.y / size - 0.5)
	var b1: Array = []
	var d1 := INF
	var b2: Array = []
	var d2 := INF
	for dy in 2:
		for dx in 2:
			var c := _cell(ix + dx, iy + dy, layer, size, sf)
			var d := q.distance_to(c[0])
			if d < d1:
				b2 = b1
				d2 = d1
				b1 = c
				d1 = d
			elif d < d2:
				b2 = c
				d2 = d
	return [b1, d1, b2, d2]


static func _pick(w: Array, u: float) -> int:
	var acc := 0.0
	for e: Array in w:
		acc += float(e[1])
		if u < acc:
			return int(e[0])
	return int(w[w.size() - 1][0])


## 얼룩의 역할 (섞인 들이면 −1)
static func _cell_role(c: Array) -> int:
	if float(c[1]) < MIXED_P:
		return -1
	return _pick(DOMINANT_W, float(c[2]))


## 군락 자리의 꽃숲 덩이 → [모델, 배율].
##   p = 처음 방향 땅 좌표 (병을 돌려도 같은 자리) · h, h2 = 0~1 자리 해시 (늘 같은 모양) · site = (젖음, 숲 짙기) · seed = 병 씨앗
##   far = 마을 둘레 밖 숲 (가짓수 적게 — FAR_FLOWERS·FAR_GREEN)
static func clump_at(season: String, p: Vector2, h: float, h2: float, site: Vector2, seed: int, far := false) -> Array:
	if seed != _cells_seed:
		_cells.clear()
		_cells_seed = seed
	var sf := float(posmod(seed, 9973))
	var h3 := fposmod(h * 91.7 + h2 * 47.3, 1.0)
	var wet := site.x
	var dense := site.y
	# 굽은 경계 (낮은 주파수 사인 합 — 씨앗마다 위상이 다름)
	var q := p + Vector2(sin(p.y * 0.21 + sf) + 0.6 * sin(p.x * 0.11 + p.y * 0.07 + sf * 1.7),
		sin(p.x * 0.19 - sf * 0.9) + 0.6 * sin(p.y * 0.13 - p.x * 0.05 + sf * 2.3)) * WARP
	var big := _near2(q, 0, COLONY_CELL, sf)
	var c1: Array = big[0]
	# 꽃 몫: 철 기본 × 얼룩마다 ±(꽃 많은 들 / 초록 많은 들) × 숲 속 그늘은 초록 쪽으로
	var share := float(FLOWER_SHARE.get(season, 0.5)) + (float(c1[3]) - 0.5) * 0.3
	share *= 1.08 - 0.16 * clampf((dense - 0.5) * 2.0, 0.0, 1.0)
	var name: String
	if h < share:
		var role := _cell_role(c1)
		var u := h2
		if role < 0:
			role = _pick(MIXED_W, h3)
		else:
			# 경계에서 이웃 얼룩이 번져 듦 · 얼룩 안 군데군데 다른 꽃
			var bleed := 0.5 * (1.0 - clampf((float(big[3]) - float(big[1])) / BLEED, 0.0, 1.0))
			if u < bleed:
				var r2 := _cell_role(big[2])
				role = r2 if r2 >= 0 else _pick(MIXED_W, h3)
			elif u < bleed + ACCENT:
				role = _pick(MIXED_W, h3)
		# 자리 성질 (땅의 젖음·숲 짙기는 부드럽게 변하므로 이웃 그루끼리 같은 판정 → 띠·무리)
		var thicket_on := false
		if dense > EDGE_BAND.x and dense < EDGE_BAND.y + 0.16:
			var band := _near2(q, 2, COLONY_CELL * 1.4, sf)    # 가시덤불 띠를 토막 내는 큰 칸 (가장자리 전체가 장미 울타리가 되지 않게)
			thicket_on = float((band[0] as Array)[1]) < THICKET_P
		if wet > WET_AT + 0.12 * (float(c1[3]) - 0.5) or (dense > DEEP_SHADE and float(c1[3]) < SHADE_GROVE):
			if h3 < 0.8:
				role = R_SHADE                                  # 물가·숲 속 그늘 숲 (그늘 숲은 얼룩의 일부만)
		elif dense > EDGE_BAND.x and dense < EDGE_BAND.y and thicket_on:
			role = R_THICKET if h3 < 0.75 else R_VINE
		elif dense >= EDGE_BAND.y and thicket_on and h3 < 0.55:
			role = R_VINE                                       # 가시덤불 곁 덩굴
		else:
			if role == R_THICKET or (role == R_SHADE and wet < 0.15 and dense < EDGE_BAND.x):
				role = R_FIELD if h3 < 0.6 else R_OPEN          # 트인 땅에 가시덤불·그늘 꽃은 없음
			# 키 큰 꽃 작은 무리
			var tq := _near2(q, 1, TALL_CELL, sf)
			var tc: Array = tq[0]
			if float(tc[1]) < TALL_P and float(tq[1]) < TALL_R * (0.7 + 0.6 * float(tc[2])) and h3 < 0.88:
				role = R_TALL
			elif role == R_TALL:
				role = R_FIELD
		var rl: Array = ROLES.get(season, ROLES["봄"])
		name = rl[role]
		if far:
			var fl: Array = FLOWERS.get(season, FLOWERS["봄"])
			var keep := fl.slice(0, mini(fl.size(), FAR_FLOWERS))
			if not name in keep:
				name = rl[R_FIELD] if role != R_OPEN and int(h3 * 3.0) != 0 else rl[R_OPEN]
				if not name in keep:
					name = keep[0]
	else:
		# 초록도 무리: 물가·그늘 = 고사리·이끼 · 트인 땅 = 풀대·클로버 (얼룩마다 주인 하나 80%)
		var g := _near2(q, 3, GREEN_CELL, sf)
		var gc: Array = g[0]
		var shady := wet > WET_AT or (dense > 0.6 and float(gc[3]) < 0.5)
		var gset: Array = GREEN_SHADE if shady else GREEN_OPEN
		var i := int(float(gc[1]) * gset.size()) % gset.size()
		if h2 > 0.8:
			i = int(h3 * gset.size()) % gset.size()
		name = gset[i]
		if far:
			name = FAR_GREEN[(0 if not shady else (1 if i == 0 else 2))]
	return [name, base_scale(name) * (0.82 + 0.36 * fposmod(h * 7.31 + h2 * 3.7, 1.0))]


static func twig(h: float) -> Array:
	var name: String = TWIGS[int(h * 2.0) % 2]
	return [name, base_scale(name) * (0.85 + 0.3 * h)]


static func sprout(h: float) -> Array:
	var name: String = SPROUTS[int(h * 2.0) % 2]
	return [name, base_scale(name) * 0.35]


## 큰 나무 모델 (철마다) — art/models/flora/tree_<kind>.glb 하나에 부품이 다 있고 (색만 다른 잎은 같은 모양), 철마다 보일 부품만 고른다.
## 부품마다 멀리 LOD "<부품>__far"도 있다 (GreatTreeView가 확대에 따라 바꿈). art/src/build_bonsai.py의 sets와 같게 둔다.
##   소나무: 봄 연두 새순 · 여름·가을 짙은 청록 · 겨울 방석 위 서리 (늘 푸름)
##   과일나무: 봄 크림 흰 꽃 · 여름 초록 + 덜 익은 열매 · 가을 익은 열매 · 겨울 맨가지 + 마른 열매 하나
##   은행나무: 봄 연두 · 여름 초록 · 가을 노랑 + 노란 융단 · 겨울 위로 뻗은 맨가지
##   단풍나무: 봄 붉은 기운 새잎 · 여름 초록 · 가을 붉은 손 · 겨울 맨가지 + 날개 씨앗
##   벚나무: 봄 분홍 꽃구름 + 꽃잎 · 여름 초록 + 버찌 · 가을 주황 · 겨울 맨가지 + 줄무늬 줄기
## 옛 저장의 "world"(세계수)는 벚나무로 (GreatTrees.LEGACY — 불러올 때 바꾸지만 화면도 받아 줌)
const GREAT_PARTS := {
	"pine": {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage"], "겨울": ["foliage_winter"]},
	"fruit": {"봄": ["foliage_bloom"], "여름": ["foliage", "fruit_green"], "가을": ["foliage_autumn", "fruit"], "겨울": ["fruit_dry"]},
	"ginkgo": {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn"], "겨울": []},
	"maple": {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn"], "겨울": ["seeds"]},
	"cherry": {"봄": ["blossom"], "여름": ["foliage", "cherries"], "가을": ["foliage_autumn"], "겨울": []},
}
const GREAT_MAX_H := 100.0        # 가장 큰 나무 높이 (모델 단위 — 은행나무 약 92, 화면 ×GREAT_SCALE)


## → {"parts": 모델 이름, "keep": [보일 부품]} (줄기는 늘)
static func great_model(kind: String, season: String) -> Dictionary:
	var k := String(GreatTrees.LEGACY.get(kind, kind))
	if not GREAT_PARTS.has(k):
		k = "cherry"
	var by_season: Dictionary = GREAT_PARTS[k]
	var keep: Array = ["trunk"]
	keep.append_array(by_season.get(season, by_season["여름"]))
	return {"parts": "flora/tree_" + k, "keep": keep}
