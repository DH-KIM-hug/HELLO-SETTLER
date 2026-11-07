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
		s = minf(s, (W_MAX_GREEN if green else W_MAX) / maxf(0.5, maxf(sz.x, sz.z)))
		s = minf(s, 1.0)
		if name in TWIGS:
			s = 0.42                # 나뭇가지 더미 폭 약 2.2칸 (그루터기 자리)
		elif name.contains("fallen_leaf"):
			s = 0.3                 # 떨어진 큰 잎 (폭 약 2.2칸)
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
	"ginkgo": {"봄": ["foliage_spring"], "여름": ["foliage"], "가을": ["foliage_autumn", "carpet"], "겨울": []},
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
