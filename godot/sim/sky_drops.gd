## 하늘에서 내려온 것 — 거인이 손에 든 물건을 뚜껑을 열고 떨어뜨린다 (SHOP.md 3 · WORLD_EVENTS 1.1 · 3 · 4.1 · 4.4 · 기획서 6.7).
## 순수 로직. 상태는 Village (drops · towers · algae · care · shop_*) — 이름 그대로 저장된다 (SaveCodec).
##  · 두 가지 크기 (WE 1.1): 먹을 것·재료는 '바깥 크기'로 떨어진다 — 주민에게는 산더미. 주민이 몰려와 조금씩 깎아 창고로 나른다
##    (나른 양 = 카드에 적힌 양 그대로, 물건이 눈에 띄게 작아진다). 식량은 마을 크기 비례 (떨어진 때의 인구 × 하루치 × 날 수).
##  · 뚜껑이 열려 있어야 떨어뜨릴 수 있다 (병의 법칙 — 날벌레·온기·물은 Village.open_lid가 맡음). 여러 개를 한 번 열 때 넣는 게 이득.
##  · 떨어지는 자리의 집은 부서지고 (창고·제단 위는 안 됨), 사람은 화들짝 피한다 (다치거나 죽지 않음). 나무는 밀려남.
##  · 떨어진 물건 = 목격한 기적 (깨닫기 전엔 경이 — Awakening.witness "drop", 깨달은 뒤엔 믿음↑). 주민은 '하늘에서 내려온 것'으로만 말한다.
##  · 돌봄 (WE 4.1): 알약 = 중증 모두 가벼움 + 3일 중증 확률 ×0.3 · 반창고 = 부상 모두 나음 + 5일 곪음 막음 · 마른 약초 = 약초 30 ·
##    소금 한 꼬집 = 곰팡이 무리가 녹음 + 소금 40 (밭 위면 그 땅이 짜짐).
##  · 영양제 앰플 (WE 4.4): 땅에 꽂힌 탑. 7일 동안 둘레가 날마다 넓게 비옥 (최대 20칸, 농사 ×1.5, 소금기 ×0.5) → 다 스민 뒤 14일에 걸쳐 원래대로.
##    처음 꽂힌 날 모두 몰려와 올려다봄 (믿음 크게↑), 저녁 기도를 탑 아래에서도. 둘째 탑이거나 물가면 가장 가까운 호수에 녹조 (10일 —
##    물고기 절반, 배앓이↑). 한 병에 동시에 2개까지.
##  · 광맥 돌 (SHOP 2.4): 땅에 눌러 박힌 돌 → 언덕이 솟고(땅 높이↑ — 물길이 바뀔 수 있음) 그 위에 바위 무리 (Village.rocks, ore = 돌·소금·철광석·석탄).
##    회색 = 돌 (채석장이 곧바로 캠) · 하양 = 소금 (땅속 암염 — 물이 닿으면 녹고, 주민이 소금을 안 뒤에야 채석장이 캠) ·
##    붉은 = 철광석 · 검정 = 석탄 (넓은 세상의 광맥 WorldWater.veins에도 — 광산이 생기기 전엔 묻혀 있음). 종류마다 한 병에 둘까지.
## 이 파일 밖의 고리: Village.step (step) · is_free (blocks) · _update_building (fert_mult) · rotate_jar · ResidentAI.decide/_do/run_op ("sky_") ·
##   ResidentAI._pray (tower_pray) · Health (severe_mult · fester_mult · ill_mult) · SaveCodec.ref_lists ("drops").
class_name SkyDrops
extends RefCounted

const UNLOCK_EVERY := 60.0             # 진열 확인 (병 초)
const CARVERS := 5                     # 물건 하나를 한 번에 깎는 사람 수
const CARVE_TIME := 90.0               # 한 번 깎는 시간 (병 초)
const CAP := {"빵": 10.0, "건량": 10.0, "밀": 10.0, "통나무": 2.0, "돌": 2.0, "약초": 3.0, "소금": 4.0, "철": 1.0}
const CAP_CHILD := 5.0               # 아이는 식량만 조금씩
const STUFF_PER_DAY := 40.0            # 재료(통나무·돌·약초·소금)는 하루에 이만큼까지 깎아 나름 (나무젓가락 = 이틀)
const CARRY := {"빵": "빵", "건량": "낟알", "밀": "밀", "통나무": "통나무", "돌": "돌", "약초": "버섯", "소금": "소금", "철": "돌"}
const PILL_SEVERE := 0.3
const TOWER_DAYS := 7.0
const TOWER_FADE_DAYS := 14.0
const TOWER_R0 := 3.0
const TOWER_R := 20.0
const TOWER_FARM := 1.5
const TOWER_SALT := 0.5
const TOWER_GATHER := 240.0            # 처음 꽂힌 날 올려다보는 시간 (병 초)
const TOWER_RING := 3.2
const TOWER_BELIEF := 0.15
const TOWER_WATER_NEAR := 10.0         # 물가 (이 안에 물이 있으면 녹조)
const ALGAE_DAYS := 10.0
const ALGAE_SEARCH := 70.0
const ALGAE_ILL := 1.3                 # 녹조가 마을 가까이 (배앓이 — 모든 발병 거르기 배율에 곱함)
const ALGAE_NEAR := 45.0
const DROP_BELIEF := 0.05
const SALT_FIELD := 0.004              # 밭에 떨어진 소금 한 꼬집 → 칸마다 소금기 (농사 ×0.5쯤)
const FLEE := 3.2
const HILL_H := 0.09                   # 광맥 돌 언덕 높이 (높이 단위 — 화면 ×6)
const VEIN_ROCK := 50.0                # 광맥 바위 하나에 든 양
const VEIN_KIND := {"철광석": "iron", "석탄": "coal"}      # 넓은 세상 광맥 이름 (WorldGen.VEIN_KINDS)
const VEIN_SEAM := 0.02
const WILD_FISH_R := 12.0              # 작은 물고기 한 줌을 놓을 수 있는 호숫가 (칸)                # 하얀 돌: 땅속 암염 (WorldGen 강 위 암염과 같은 양)

## 주민의 말 (금지어 없음 — '하늘에서 내려온 것'). [깨달은 뒤, 깨닫기 전]
const SAY := {
	"빵 부스러기": ["하늘에서 갈색 바위가 내려왔다!", "하늘에서 갈색 바위가 떨어졌어!"],
	"쌀 한 톨": ["하늘에서 하얀 통나무가 내려왔다!", "하얀 통나무가 하늘에서 떨어졌어!"],
	"각설탕": ["하늘에서 하얀 바위가 내려왔다!", "하늘에서 하얀 바위가 떨어졌어!"],
	"밀 이삭 한 줄기": ["하늘에서 황금 나무가 쓰러져 내려왔다!", "황금 나무가 하늘에서 쓰러졌어!"],
	"나무젓가락": ["하늘에서 거대한 통나무가 내려왔다!", "하늘에서 통나무가 떨어졌어!"],
	"자갈 한 알": ["하룻밤 새 바위산이 생겼다!", "하늘에서 바위산이 떨어졌어!"],
	"알약 부스러기": ["거인님의 약이다!", "하늘에서 하얀 돌이 내려왔어!"],
	"반창고 조각": ["하늘에서 하얀 천이 내려왔다!", "하늘에서 하얀 천이 떨어졌어!"],
	"마른 약초 한 잎": ["하늘에서 숲만 한 잎이 내려왔다!", "하늘에서 커다란 잎이 떨어졌어!"],
	"소금 한 꼬집": ["하늘에서 하얀 모래가 쏟아졌다!", "하늘에서 하얀 모래가 쏟아졌어!"],
	"영양제 앰플": ["하늘의 탑이다!", "하늘에서 유리 탑이 꽂혔어!"],
	"회색 돌멩이": ["하룻밤 새 바위산이 솟았다!", "땅에서 바위산이 솟았어!"],
	"하얀 돌": ["하늘에서 하얀 바위가 박혔다!", "하얀 바위가 땅에 박혔어!"],
	"붉은 돌멩이": ["하룻밤 새 붉은 바위산이 솟았다!", "붉은 줄무늬 바위가 솟았어!"],
	"검은 돌": ["하늘에서 검은 바위가 박혔다!", "검은 바위가 땅에 박혔어!"],
	# 들짐승 다시 넣기 (WILDLIFE 4): 깨달은 뒤 "하늘에서 사슴이 내려왔다!" · 깨닫기 전엔 그냥 놀람 (Wildlife.wonder_line과 같은 말)
	"작은 사슴 한 쌍": ["하늘에서 사슴이 내려왔다!", "어, 사슴이다! 어디서 왔을까…?"],
	"작은 토끼 한 쌍": ["하늘에서 토끼가 내려왔다!", "어, 토끼다! 어디서 왔을까…?"],
	"작은 물고기 한 줌": ["하늘에서 물고기가 내려왔다!", "어, 물고기다! 어디서 왔을까…?"],
}
## 연대기 한 줄
const BOOK := {
	"빵 부스러기": "하늘에서 갈색 바위가 내려왔다. 사람들은 그것을 깎아 창고에 날랐다. 고소한 냄새가 났다.",
	"쌀 한 톨": "하늘에서 하얀 통나무만 한 낟알이 내려왔다. 사람들은 그것을 쪼개어 창고에 쌓았다.",
	"각설탕": "하늘에서 하얀 돌집만 한 단 덩어리가 내려왔다. 사람들은 날마다 그것을 조금씩 깎아 먹었다.",
	"밀 이삭 한 줄기": "하늘에서 황금 나무가 쓰러져 내려왔다. 낟알 하나가 자루만 했다.",
	"나무젓가락": "하늘에서 거대한 통나무가 내려왔다. 사람들은 그것을 켜고 쪼개어 날랐다.",
	"자갈 한 알": "하룻밤 새 마을 곁에 바위산이 생겼다. 사람들은 그것을 깨어 돌을 날랐다.",
	"알약 부스러기": "하늘에서 하얀 바위가 내려왔다. 그것을 깎아 먹은 사람들의 열이 내렸다.",
	"반창고 조각": "하늘에서 하얀 천 더미가 내려왔다. 다친 사람들의 상처를 감싸자 곧 아물었다.",
	"마른 약초 한 잎": "하늘에서 숲만 한 마른 잎이 내려왔다. 약초꾼들이 기뻐하며 그것을 잘게 뜯었다.",
	"소금 한 꼬집": "하늘에서 하얀 모래 언덕이 쏟아졌다. 털뭉치 괴물들이 그것에 닿자 녹아 버렸다.",
	"영양제 앰플": "하늘에서 거대한 유리 탑이 내려와 땅에 꽂혔다. 사람들은 일손을 놓고 몰려와 탑을 올려다보았다.",
	"회색 돌멩이": "하룻밤 새 마을 곁에 회색 바위산이 솟았다. 석수들이 그 바위를 두드려 보고 고개를 끄덕였다.",
	"하얀 돌": "하늘에서 하얀 바위가 내려와 땅에 깊이 박혔다. 무엇인지 아는 사람은 아무도 없었다.",
	"붉은 돌멩이": "하룻밤 새 붉은 줄무늬 바위산이 솟았다. 바위에서 녹물 같은 냄새가 났다.",
	"검은 돌": "하늘에서 검은 바위가 내려와 땅에 박혔다. 만지면 손이 까매졌다.",
	"작은 사슴 한 쌍": "어디선가 사슴 한 쌍이 나타나 숲가로 뛰어갔다. 사라졌던 사슴이 다시 숲에 산다.",
	"작은 토끼 한 쌍": "어디선가 토끼 한 쌍이 나타나 들판으로 깡충깡충 뛰어갔다.",
	"작은 물고기 한 줌": "어디선가 작은 물고기들이 호수로 쏟아져 내려왔다. 물 위로 은빛이 반짝였다.",
}
const TOWER_LINES := ["하늘의 탑 아래 땅이 푸르러진다", "탑이 밤에도 빛나요", "하늘의 분이 내려 주신 탑이다", "탑 둘레의 밀이 참 잘 자라"]
const TOWER_DOUBT := "거인의 물병일 뿐이야. 땅이 좋아진 건 물이 스며서지."
const TOWER_DOUBT_UNAWARE := "하늘의 물병일 뿐이야. 땅이 좋아진 건 물이 스며서지."


static func def(item: String) -> Dictionary:
	return Shop.ITEMS.get(item, {})


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	v._sky_acc += dt
	if v._sky_acc >= UNLOCK_EVERY:
		v._sky_acc = 0.0
		Shop.update_unlocks(v)
		_tower_tick(v)
		v.algae = v.algae.filter(func(a: Dictionary) -> bool: return v.t < float(a["until"]))
	if v.drops.is_empty():
		return
	var gone := false
	for d: Dictionary in v.drops:
		if String(d["res"]) == "":                      # 효과만 있는 것 (알약·반창고): 사그라듦
			d["left"] = maxf(0.0, float(d["total"]) * (1.0 - (v.t - float(d["t"])) / maxf(1.0, float(d.get("dur", Balance.DAY)))))
		if float(d["left"]) <= 1e-4 and int(d["res_n"]) <= 0:
			gone = true
	if gone:
		v.drops = v.drops.filter(func(d: Dictionary) -> bool: return float(d["left"]) > 1e-4 or int(d["res_n"]) > 0)


## 짓는 자리를 막는가 (Village.is_free)
static func blocks(v: Village, x: float, y: float, size: float) -> bool:
	for d: Dictionary in v.drops:
		if Vector2(float(d["x"]) - x, float(d["y"]) - y).length() < float(d["size"]) * _shrink(d) + size + 0.4:
			return true
	for tw: Dictionary in v.towers:
		if Vector2(float(tw["x"]) - x, float(tw["y"]) - y).length() < Shop.ITEMS[Shop.AMPOULE]["size"] + size + 0.4:
			return true
	return false


## 남은 양에 따른 크기 (1 = 처음, 다 깎이면 0.3쯤) — 화면도 같은 값을 쓴다
static func _shrink(d: Dictionary) -> float:
	var tot := maxf(1e-4, float(d["total"]))
	return lerpf(0.3, 1.0, clampf(float(d["left"]) / tot, 0.0, 1.0))


static func shrink(d: Dictionary) -> float:
	return _shrink(d)


# ───────────────────────── 떨어뜨리기 ─────────────────────────
## 이 자리에 떨어뜨리면 어떻게 되나 (미리보기) → {ok, why, warn, crush: [건물], people: n, field: bool}
## ok = 떨어뜨릴 수 있음. warn = 붉게 (집이 부서짐·사람 위·밭에 소금) — 그래도 떨어뜨릴 수 있다
static func preview(v: Village, item: String, p: Vector2) -> Dictionary:
	if Shop.is_building(item):
		return preview_building(v, item, p)
	var d := def(item)
	var size := float(d.get("size", 1.5))
	var out := {"ok": true, "why": "", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	if not v.water.inside(p.x, p.y, size + 0.5):
		return {"ok": false, "why": "유리벽 가까이엔 떨어뜨릴 수 없어요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	var fish := String(d.get("species", "")) == "fish"         # 작은 물고기 한 줌: 물 위나 물가에 (가장 가까운 호수로)
	if v.water_at(p.x, p.y) and not fish:
		return {"ok": false, "why": "물 위에는 떨어뜨릴 수 없어요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	if fish and not v.water_at(p.x, p.y) and nearest_lake(v, p, WILD_FISH_R) == null:
		return {"ok": false, "why": "물고기는 호수 가까이에 놓아 주세요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	if Vector2(v.fire.x - p.x, v.fire.y - p.y).length() < size + 1.0:
		return {"ok": false, "why": "모닥불 위에는 떨어뜨릴 수 없어요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	if (v.altar_built or Awakening.altar_site(v) != null) and Vector2(v.altar_pos.x - p.x, v.altar_pos.y - p.y).length() < size + 1.6:
		return {"ok": false, "why": "제단 위에는 떨어뜨릴 수 없어요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	if item == Shop.AMPOULE and active_towers(v) >= Shop.AMPOULE_MAX:
		return {"ok": false, "why": "탑은 한 병에 둘까지예요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	if Shop.is_vein(item) and veins_placed(v, item) >= Shop.VEIN_MAX:
		return {"ok": false, "why": "이 돌은 한 병에 둘까지예요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	for o: Dictionary in v.drops:
		if Vector2(float(o["x"]) - p.x, float(o["y"]) - p.y).length() < float(o["size"]) * _shrink(o) + size:
			return {"ok": false, "why": "먼저 내려온 것 위에는 떨어뜨릴 수 없어요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	for tw: Dictionary in v.towers:
		if Vector2(float(tw["x"]) - p.x, float(tw["y"]) - p.y).length() < 1.8 + size:
			return {"ok": false, "why": "탑 위에는 떨어뜨릴 수 없어요", "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	var crush: Array = []
	for b in v.buildings:
		if Vector2(b.x - p.x, b.y - p.y).length() < b.size() + size * 0.85:
			if b.is_store or b.site_type() == Awakening.ALTAR:
				return {"ok": false, "why": "창고 위에는 떨어뜨릴 수 없어요" if b.is_store else "제단 위에는 떨어뜨릴 수 없어요",
					"warn": "", "crush": [], "people": 0, "field": false, "size": size}
			if b.type == "농장" and String(d.get("kind", "")) == "salt":
				out["field"] = true
				continue
			crush.append(b)
	var np := 0
	for r in v.people:
		if Vector2(r.x - p.x, r.y - p.y).length() < size + 0.6:
			np += 1
	out["crush"] = crush
	out["people"] = np
	var houses := 0
	for b: Building in crush:
		if b.is_house():
			houses += 1
	if houses > 0:
		out["warn"] = "여기 떨어뜨리면 집이 부서져요"
	elif not crush.is_empty():
		out["warn"] = "여기 떨어뜨리면 %s%s 부서져요" % [(crush[0] as Building).type, Village.josa((crush[0] as Building).type, "이", "가")]
	elif np > 0:
		out["warn"] = "사람들이 있어요 — 놀라서 달아나요"
	elif bool(out["field"]):
		out["warn"] = "밭에 떨어지면 땅이 짜져요"
	return out


## 건물 자리 미리보기 (6.7 — 영역 안, 자리의 농사 배율) → {ok, why, warn, good: 자리 말}
static func preview_building(v: Village, type: String, p: Vector2) -> Dictionary:
	var size := float(Balance.B[type]["size"])
	var out := {"ok": true, "why": "", "warn": "", "crush": [], "people": 0, "field": false, "size": size, "good": ""}
	if not v.is_free(p.x, p.y, size):
		var why := "여기엔 놓을 수 없어요"
		if not v.in_territory(p.x, p.y, size):
			why = "마을 땅 밖이에요"
		elif v.water_at(p.x, p.y):
			why = "물 위에는 놓을 수 없어요"
		else:
			why = "건물·나무·바위가 가까워요"
		out["ok"] = false
		out["why"] = why
		return out
	out["good"] = site_words(v, type, p)
	return out


## 자리의 말 (숫자 대신 말 — UI 원칙)
static func site_words(v: Village, type: String, p: Vector2) -> String:
	match type:
		"농장":
			var m := v.farm_mult(p.x, p.y) * fert_mult(v, p.x, p.y)
			return "밀이 아주 잘 자라는 땅" if m >= 1.15 else ("밀이 잘 자라는 땅" if m >= 0.85 else "밀이 잘 안 자라는 땅 — 마르거나 그늘져요")
		"나무꾼":
			var n := 0
			for tr: Dictionary in v.trees:
				if tr["s"] == "tree" and Vector2(float(tr["x"]) - p.x, float(tr["y"]) - p.y).length() < 10.0:
					n += 1
			return "숲이 가까워요" if n >= 8 else ("나무가 조금 있어요" if n >= 3 else "둘레에 나무가 거의 없어요")
		"채석장":
			var near := 1.0e9
			for rk: Dictionary in v.rocks:
				near = minf(near, Vector2(float(rk["x"]) - p.x, float(rk["y"]) - p.y).length())
			return "바위가 가까워요" if near < 8.0 else "바위가 멀어요"
		"우물":
			return "집들 가까이라 물 긷기 좋아요" if p.distance_to(v.center) < 8.0 else "마을에서 조금 멀어요"
		"창고":
			return "마을 가운데라 나르기 좋아요" if p.distance_to(v.center) < 8.0 else "마을에서 조금 멀어요"
	return "마을 가까이" if p.distance_to(v.center) < 10.0 else "마을에서 조금 멀어요"


## 떨어뜨린다 → {ok, why, drop(사전) 또는 building, crushed: 부서진 건물 수, fled: 달아난 사람 수}
## 뚜껑이 닫혀 있으면 안 된다 (병의 법칙). 손에서 빼는 것은 부르는 쪽 (Shop.hand_remove)
static func drop(v: Village, item: String, p: Vector2) -> Dictionary:
	if v.air == null or not v.air.lid_open:
		return {"ok": false, "why": "뚜껑을 먼저 열어 주세요"}
	if Shop.is_building(item):
		return place_building(v, item, p)
	var pv := preview(v, item, p)
	if not bool(pv["ok"]):
		return pv
	var d := def(item)
	var size := float(d.get("size", 1.5))
	v.begin_giant()
	var crushed := 0
	for b: Building in pv["crush"]:
		remove_building(v, b)
		crushed += 1
	if crushed > 0:
		v.log_line("하늘에서 내려온 것에 %s 깔려 부서졌다. 다친 사람은 없었다." % ("집이" if (pv["crush"] as Array).any(func(b: Building) -> bool: return b.is_house()) else "건물이"))
		v.raise_fear_all(0.05)
	var fled := _scatter(v, p, size + 0.6)
	v._clear_trees(p, size * 0.8)
	var kind := String(d.get("kind", ""))
	var res := String(d.get("res", ""))
	var total := 0.0
	match kind:
		"food":
			total = roundf(maxf(1.0, float(v.people.size())) * Balance.DAY / Balance.FOOD_IV * float(d["days"]))
		"stuff", "salt":
			total = float(d["amt"])
		"pill", "bandage":
			total = 1.0
	var o := {}
	if kind != "ampoule" and kind != "vein" and kind != "wild":
		v._drop_id += 1
		o = {"id": v._drop_id, "item": item, "x": p.x, "y": p.y, "res": res, "total": total, "left": total, "size": size,
			"res_n": 0, "t": v.t, "dur": float(d.get("days", 1.0)) * Balance.DAY}
		v.drops.append(o)
	match kind:
		"pill":
			v.care["pill"] = v.t + float(d["days"]) * Balance.DAY
			for r in v.people:
				if r.sick_left > 0.0 and r.severe:
					r.severe = false
		"bandage":
			v.care["bandage"] = v.t + float(d["days"]) * Balance.DAY
			for r in v.people:
				r.injured_left = 0.0
		"salt":
			var melted := 0
			for b in v.mold.blobs:
				if b.state != "tamed" and b.state != "gone":
					b.state = "gone"
					melted += 1
			v.mold.stats["melted"] = int(v.mold.stats["melted"]) + melted
			if melted > 0:
				v.log_line("하얀 모래가 닿자 털뭉치 괴물 %d마리가 녹아 버렸다." % melted)
			if bool(pv["field"]):
				_salt_ground(v, p, size + 1.0)
		"ampoule":
			_plant_tower(v, p)
		"vein":
			o = _plant_vein(v, item, p)
		"wild":
			if v.wild != null:
				v.wild.readd(v, String(d["species"]), int(d.get("n", 2)), p, true)
	_miracle(v, item, p)
	v.end_giant()
	return {"ok": true, "why": "", "drop": o, "crushed": crushed, "fled": fled}


## 건물을 고른 자리에 하늘에서 내린다 (이미 지폐를 냄 — 상점). 놓을 수 없으면 {ok: false}
static func place_building(v: Village, type: String, p: Vector2) -> Dictionary:
	if v.air == null or not v.air.lid_open:
		return {"ok": false, "why": "뚜껑을 먼저 열어 주세요"}
	var pv := preview_building(v, type, p)
	if not bool(pv["ok"]):
		return pv
	var b := v.buy_building(type, p, true)
	if b == null:
		return {"ok": false, "why": "여기엔 놓을 수 없어요"}
	return {"ok": true, "why": "", "building": b, "crushed": 0, "fled": 0}


## 기적: 목격 (깨닫기 전 경이) · 믿음 · 가까운 사람 둘의 말 · 연대기
static func _miracle(v: Village, item: String, p: Vector2) -> void:
	Awakening.witness(v, "drop")
	if v.aware:
		v.bless_all(TOWER_BELIEF if item == Shop.AMPOULE else DROP_BELIEF)
		v._update_belief(0.0)
	var near := v.people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5 and q.sick_left <= 0.0)
	near.sort_custom(func(a: Resident, c: Resident) -> bool: return Vector2(a.x, a.y).distance_squared_to(p) < Vector2(c.x, c.y).distance_squared_to(p))
	var lines: Array = SAY.get(item, ["하늘에서 무언가 내려왔다!", "하늘에서 무언가 떨어졌어!"])
	for i in mini(2, near.size()):
		var who: Resident = near[i]
		v.speak(who, String(lines[0]) if v.aware else String(lines[1]), 8)
		if i == 1:
			v.speak(who, "기적이다!" if v.aware else "저게 뭐지…?", 7)
	v.log_line(String(BOOK.get(item, "하늘에서 무언가 내려왔다.")))
	v.stats["sky_drops"] = int(v.stats.get("sky_drops", 0)) + 1


## 떨어지는 자리의 사람들이 화들짝 달아난다 (다치지 않음) — 달아난 수
static func _scatter(v: Village, p: Vector2, rad: float) -> int:
	var n := 0
	for r in v.people:
		var d := Vector2(r.x - p.x, r.y - p.y)
		if d.length() >= rad:
			continue
		n += 1
		if r.is_baby():
			continue
		ResidentAI.cancel(v, r)
		var dir := d.normalized() if d.length() > 0.05 else Vector2(1, 0).rotated(float(r.id) * 2.39)
		var q := p + dir * (rad + FLEE)
		if v.water_at(q.x, q.y):
			q = p - dir * (rad + FLEE)
		r.x = p.x + dir.x * (d.length() + 0.4)        # 화들짝 한 걸음 뛰어 비킨다
		r.y = p.y + dir.y * (d.length() + 0.4)
		r.steps.append(ResidentAI.walk(q.x, q.y))
		r.steps.append(ResidentAI.act(20.0, "idle"))
		r.doing = "화들짝 놀라 피한 중"
		v.raise_fear(r, 0.05)
		if r.age >= 2.5:
			v.speak(r, "으악! 하늘에서 떨어진다!", 4)
	v.recalc_fear()
	return n


## 건물을 없앤다 (깔려 부서짐) — 그 건물을 붙잡은 걸음은 그만두게, 일꾼·식구는 풀어 준다 (집은 assign_homes가 다시)
static func remove_building(v: Village, b: Building) -> void:
	for r in v.people + v.dead:
		var holds := false
		for s: Dictionary in r.steps:
			if _refs(s, b):
				holds = true
				break
		if holds and r in v.people:
			ResidentAI.cancel(v, r)
		elif holds:
			r.steps.clear()
		if r.job == b.id:
			r.job = -1
			v.stock["도구"] = float(v.stock.get("도구", 0.0)) + 1.0
		if r.home == b.id:
			r.home = -1
	v.buildings.erase(b)
	v._bld_by_id.erase(b.id)
	v.stats["crushed"] = int(v.stats.get("crushed", 0)) + 1
	v.assign_homes()


static func _refs(x: Variant, b: Building) -> bool:
	if x is Building:
		return x == b
	if x is Dictionary:
		for k: Variant in x:
			if _refs((x as Dictionary)[k], b):
				return true
	elif x is Array:
		for e: Variant in x:
			if _refs(e, b):
				return true
	return false


## 밭에 떨어진 소금 — 그 둘레 땅이 짜진다 (농사 배율을 다시 셈)
static func _salt_ground(v: Village, p: Vector2, rad: float) -> void:
	for k in v.water.cells_near(p, rad):
		v.water.take_salt(k, -SALT_FIELD)
	for b in v.buildings:
		if b.type == "농장" and Vector2(b.x - p.x, b.y - p.y).length() < rad + b.size():
			b.farm_mult = -1.0
	v.log_line("하얀 모래가 밭에 쏟아져 땅이 짜졌다. 농부들이 한숨을 쉬었다.")


# ───────────────────────── 깎아 나르기 (ResidentAI) ─────────────────────────
## 깎을 것이 있나 (남은 양이 있고 자리가 빈 것, 오늘 깎을 몫이 남은 것)
static func carve_open(v: Village) -> bool:
	for d: Dictionary in v.drops:
		if _can_carve(v, d):
			return true
	return false


## 천천히 깎는다 (WE 1.1 — 보이게 작아짐): 식량은 카드의 날 수에 걸쳐 (각설탕 = 일주일, 빵 부스러기 = 반나절),
## 재료는 하루 STUFF_PER_DAY씩. 지금까지 깎아도 되는 양 (떨어진 날부터 하루치씩)
static func carve_allowed(v: Village, d: Dictionary) -> float:
	var tot := float(d["total"])
	var it := def(String(d["item"]))
	var rate := tot / (maxf(0.25, float(it.get("days", 1.0))) * Balance.DAY) if String(it.get("kind", "")) == "food" else STUFF_PER_DAY / Balance.DAY
	var days := floorf((v.t - float(d["t"])) / Balance.DAY) + 1.0      # 그날 몫은 하루가 시작될 때 한꺼번에 — 주민이 몰려와 깎는다
	return minf(tot, rate * Balance.DAY * days)


## 지금 한 사람이 더 깎으러 가도 되나 — 오늘 몫 − 깎은 양 − 깎으러 간 사람들 몫
static func _can_carve(v: Village, d: Dictionary) -> bool:
	if String(d["res"]) == "" or float(d["left"]) <= 1e-4 or int(d["res_n"]) >= CARVERS:
		return false
	var cap := float(CAP.get(String(d["res"]), 4.0))
	var room := carve_allowed(v, d) - (float(d["total"]) - float(d["left"])) - cap * int(d["res_n"])
	return room >= minf(cap, float(d["left"])) - 1e-6


static func carve_task(v: Village, r: Resident) -> bool:
	var best: Dictionary = {}
	var bd := INF
	for d: Dictionary in v.drops:
		if not _can_carve(v, d):
			continue
		if not r.is_adult() and not String(d["res"]) in ["빵", "건량", "밀"]:
			continue
		var dd := Vector2(float(d["x"]) - r.x, float(d["y"]) - r.y).length()
		if dd < bd:
			bd = dd
			best = d
	if best.is_empty():
		return false
	var d := best
	d["res_n"] = int(d["res_n"]) + 1
	var k := String(d["res"])
	var cap: float = CAP.get(k, 4.0) if r.is_adult() else CAP_CHILD
	var s := v.store()
	var c := Vector2(float(d["x"]), float(d["y"]))
	var dir := (Vector2(r.x, r.y) - c)
	dir = dir.normalized() if dir.length() > 0.05 else Vector2(0, 1)
	var a := dir.rotated(v.rng.randf_range(-0.8, 0.8))
	var at := c + a * (float(d["size"]) * _shrink(d) + 0.35)
	r.doing = "하늘에서 내려온 것을 깎는 중" if k in ["빵", "건량", "밀"] else "하늘에서 내려온 것을 나르는 중"
	r.steps.append(ResidentAI.walk(at.x, at.y))
	r.steps.append(ResidentAI.act(CARVE_TIME, "work", ResidentAI.op("sky_carve", {"d": d, "cap": cap}), false, ResidentAI.op("sky_unres", {"d": d})))
	r.steps.append(ResidentAI.walk(s.x + 0.7, s.y + 0.6))
	r.steps.append(ResidentAI.act(4.0, "idle", ResidentAI.op("sky_put", {"k": k}), false, ResidentAI.op("sky_undo", {"d": d, "k": k})))
	return true


static func run_op(v: Village, r: Resident, o: Dictionary) -> void:
	match String(o["op"]):
		"sky_carve":
			var d: Dictionary = o["d"]
			var room := carve_allowed(v, d) - (float(d["total"]) - float(d["left"]))
			var take := clampf(minf(float(o["cap"]), float(d["left"])), 0.0, maxf(0.0, room))
			d["left"] = float(d["left"]) - take
			d["res_n"] = maxi(0, int(d["res_n"]) - 1)
			if take > 0.0:
				r.carry = String(CARRY.get(String(d["res"]), "낟알"))
				r.carry_amt = take
		"sky_unres":
			var d: Dictionary = o["d"]
			d["res_n"] = maxi(0, int(d["res_n"]) - 1)
		"sky_put":
			if r.carry_amt > 0.0:
				var k := String(o["k"])
				v.stock[k] = float(v.stock.get(k, 0.0)) + r.carry_amt
				v.stats["sky_hauled"] = float(v.stats.get("sky_hauled", 0.0)) + r.carry_amt
			r.carry = ""
			r.carry_amt = 0.0
		"sky_undo":                        # 나르다 그만둠 — 든 것은 물건에 되돌린다 (나른 양이 꼭 맞게)
			if r.carry_amt > 0.0:
				var d: Dictionary = o["d"]
				if d in v.drops:
					d["left"] = float(d["left"]) + r.carry_amt
				else:
					v.stock[String(o["k"])] = float(v.stock.get(String(o["k"]), 0.0)) + r.carry_amt
		_:
			push_error("SkyDrops.run_op: 모르는 할 일 %s" % o["op"])


## 물건에 남은 것 + 나르는 중인 것 (시험용)
static func in_flight(v: Village, res: String) -> float:
	var n := 0.0
	for r in v.people:
		if r.carry_amt > 0.0:
			for s: Dictionary in r.steps:
				var dn: Variant = s.get("done")
				if dn is Dictionary and String((dn as Dictionary).get("op", "")) == "sky_put" and String(dn["k"]) == res:
					n += r.carry_amt
					break
	return n


# ───────────────────────── 돌봄 (Health가 부름) ─────────────────────────
static func severe_mult(v: Village) -> float:
	return PILL_SEVERE if v.t < float(v.care.get("pill", -1.0)) else 1.0


static func fester_mult(v: Village) -> float:
	return 0.0 if v.t < float(v.care.get("bandage", -1.0)) else 1.0


## 녹조가 마을 가까이 있으면 배앓이↑ (발병 배율)
static func ill_mult(v: Village) -> float:
	for a: Dictionary in v.algae:
		if v.t < float(a["until"]) and Vector2(float(a["x"]), float(a["y"])).distance_to(v.center) < ALGAE_NEAR:
			return ALGAE_ILL
	return 1.0


# ───────────────────────── 영양제 앰플 탑 ─────────────────────────
static func tower_age_days(v: Village, tw: Dictionary) -> float:
	return (v.t - float(tw["t"])) / Balance.DAY


static func is_active(v: Village, tw: Dictionary) -> bool:
	return tower_age_days(v, tw) < TOWER_DAYS


static func active_towers(v: Village) -> int:
	var n := 0
	for tw: Dictionary in v.towers:
		if is_active(v, tw):
			n += 1
	return n


# ───────────────────────── 광맥 돌 (SHOP 2.4) ─────────────────────────
## 이 병에 박힌 같은 돌의 수
static func veins_placed(v: Village, item: String) -> int:
	var n := 0
	for vn: Dictionary in v.veins:
		if String(vn["item"]) == item:
			n += 1
	return n


## 돌을 눌러 박는다 → 언덕 + 바위 무리 (+ 넓은 세상의 광맥·암염). 남는 기록 {item, ore, x, y, amt, t}
static func _plant_vein(v: Village, item: String, p: Vector2) -> Dictionary:
	var d := def(item)
	var ore := String(d["ore"])
	var amt := float(d["amt"])
	var size := float(d["size"])
	raise_hill(v.water, p, size + 2.5, HILL_H)
	var n := maxi(1, int(ceilf(amt / VEIN_ROCK)))
	var each := int(roundf(amt / n))
	for i in n:                                   # 해바라기 씨 배열 — 언덕 위에 고르게
		var a := float(i) * 2.39996
		var rr := size * sqrt((float(i) + 0.5) / n)
		v.rocks.append({"x": p.x + cos(a) * rr, "y": p.y + sin(a) * rr, "amt": each, "res": 0, "ore": ore})
	var rec := {"item": item, "ore": ore, "x": p.x, "y": p.y, "amt": amt, "t": v.t}
	v.veins.append(rec)
	var ww := v.water as WorldWater
	if ww != null:
		if VEIN_KIND.has(ore):                    # 넓은 세상의 광맥 (창조의 암반 컵과 같은 기록 — 광산은 읍내에)
			ww.veins.append({"kind": VEIN_KIND[ore], "x": p.x, "y": p.y, "r": size, "amt": amt / 300.0, "sky": true})
		elif ore == "소금":                        # 땅속 암염 — 물이 닿으면 녹아 흐른다 (소금 발견 4.5와 같은 길)
			_bury_salt(ww, p, size)
	return rec


## 언덕: 땅 높이를 둥글게 올린다 (눈금에 — WorldPack). 넓은 세상은 둘레 거친 칸 표를 다시
static func raise_hill(w: JarWater, p: Vector2, r: float, hh: float) -> void:
	var ww := w as WorldWater
	for k in w.cells_near(p, r):
		var dd := Vector2(w.cx(k) - p.x, w.cy(k) - p.y).length() / r
		var bump := hh * (1.0 - dd * dd) * (1.0 - dd * dd)
		w.h[k] = WorldPack.snap(w.h[k] + bump) if ww != null else w.h[k] + bump
	if ww != null:
		ww.rebuild_coarse_around(p.x, p.y, r + WorldWater.F)


static func _bury_salt(ww: WorldWater, p: Vector2, r: float) -> void:
	var sm := {"x": p.x, "y": p.y, "r": r, "amt": VEIN_SEAM}
	ww.seams.append(sm)
	for k in ww.cells_near(p, r):
		var a := VEIN_SEAM * (1.0 - Vector2(ww.cx(k) - p.x, ww.cy(k) - p.y).length() / r)
		if ww.is_fine_k(k):
			ww.halite[k] += a
		else:
			var q := ww.coarse_of(k)
			ww.cHal[q] += a
			ww.cNH[q] += 1


## 채석장이 캘 수 있는 바위 — 회색(돌)은 언제나, 하양(소금)은 주민이 소금을 안 뒤, 철광석·석탄은 광산이 생겨야 (아직 없음)
static func rock_minable(v: Village, rk: Dictionary) -> bool:
	match String(rk.get("ore", "돌")):
		"돌":
			return true
		"소금":
			return v.salt_known
	return false


## 비옥한 둘레 반지름 (칸) — 날마다 넓어져 7일에 20칸
static func tower_radius(v: Village, tw: Dictionary) -> float:
	var a := tower_age_days(v, tw)
	return minf(TOWER_R, TOWER_R0 + (TOWER_R - TOWER_R0) * clampf(a / TOWER_DAYS, 0.0, 1.0))


## 그 탑의 농사 배율 (다 스민 뒤 14일에 걸쳐 1로)
static func tower_mult(v: Village, tw: Dictionary) -> float:
	var a := tower_age_days(v, tw)
	if a < TOWER_DAYS:
		return TOWER_FARM
	return lerpf(TOWER_FARM, 1.0, clampf((a - TOWER_DAYS) / TOWER_FADE_DAYS, 0.0, 1.0))


## 그 자리의 비옥함 (농사 ×) — 소금기도 이겨 냄 (×0.5: farm_mult의 소금 몫을 반으로)
static func fert_mult(v: Village, x: float, y: float) -> float:
	if v.towers.is_empty():
		return 1.0
	var best := 1.0
	for tw: Dictionary in v.towers:
		if Vector2(float(tw["x"]) - x, float(tw["y"]) - y).length() <= tower_radius(v, tw):
			var m := tower_mult(v, tw)
			if m > 1.0 + 1e-4:
				var s := v.salt_at(x, y) * 300.0
				m *= (1.0 + s) / (1.0 + s * TOWER_SALT)
			best = maxf(best, m)
	return best


## 비옥함 0~1 (화면: 땅이 푸르러지는 정도)
static func fertility_at(v: Village, x: float, y: float) -> float:
	return clampf((fert_mult(v, x, y) - 1.0) / (TOWER_FARM - 1.0), 0.0, 1.0)


static func _plant_tower(v: Village, p: Vector2) -> void:
	v._drop_id += 1
	var second := active_towers(v) >= 1
	v.towers.append({"id": v._drop_id, "x": p.x, "y": p.y, "t": v.t})
	for b in v.buildings:
		if b.type == "농장":
			b.farm_mult = -1.0
	# 모두 일을 멈추고 몰려와 올려다본다
	var ws := Awakening.witnesses(v)
	var n := maxi(1, ws.size())
	var i := 0
	for r in ws:
		ResidentAI.cancel(v, r)
		var a := TAU * float(i) / float(n) + 0.4
		var q := p + Vector2(cos(a), sin(a)) * (TOWER_RING + (0.8 if i % 2 == 1 else 0.0))
		if v.water_at(q.x, q.y):
			q = p + Vector2(cos(a), sin(a)) * 2.2
		r.action = "pray"
		r.doing = "하늘의 탑을 올려다보는 중"
		r.steps.append(ResidentAI.walk(q.x, q.y))
		var f := q + (p - q).normalized() * 0.03
		r.steps.append(ResidentAI.walk(f.x, f.y))
		r.steps.append(ResidentAI.act(TOWER_GATHER, "pray", ResidentAI.op("pray")))
		i += 1
	# 닫힌 병의 대가: 둘째 탑이거나 물가면 가장 가까운 호수에 녹조
	if second or _water_within(v, p, TOWER_WATER_NEAR):
		var lake: Variant = nearest_lake(v, p, ALGAE_SEARCH)
		if lake != null:
			_bloom(v, lake as Vector2)


static func _water_within(v: Village, p: Vector2, rad: float) -> bool:
	var r := 1.5
	while r <= rad:
		for i in 16:
			var a := TAU * i / 16.0
			if v.water_at(p.x + cos(a) * r, p.y + sin(a) * r):
				return true
		r += 1.5
	return false


## 가장 가까운 호수 (물 칸) — 없으면 null
static func nearest_lake(v: Village, p: Vector2, rad: float) -> Variant:
	var r := 1.5
	while r <= rad:
		var n := maxi(12, int(r * 2.0))
		for i in n:
			var a := TAU * i / float(n)
			var q := p + Vector2(cos(a), sin(a)) * r
			if v.water.inside(q.x, q.y) and v.water.is_lake(v.water.idx(q.x, q.y)):
				return q
		r += 1.5
	return null


static func _bloom(v: Village, q: Vector2) -> void:
	for a: Dictionary in v.algae:
		if Vector2(float(a["x"]), float(a["y"])).distance_to(q) < 12.0:
			a["until"] = v.t + ALGAE_DAYS * Balance.DAY
			return
	v.algae.append({"x": q.x, "y": q.y, "t": v.t, "until": v.t + ALGAE_DAYS * Balance.DAY})
	if v.wild != null and v.wild.algae_hit(q):       # [들짐승] 가까운 호수의 물고기 무리가 절반 (어부가 잡는 수도 — WILDLIFE 2)
		pass
	elif v.water is WorldWater:                      # (무리가 아직 없을 때) 창조가 놓은 물고기 수
		var ww := v.water as WorldWater
		var best := -1
		var bd := 40.0
		for i in ww.fish.size():
			var dd := Vector2(float(ww.fish[i]["x"]), float(ww.fish[i]["y"])).distance_to(q)
			if dd < bd:
				bd = dd
				best = i
		if best >= 0:
			ww.fish[best]["n"] = maxi(1, int(ww.fish[best]["n"]) / 2)
	v.log_line("탑에서 스민 것이 물을 따라 흘러 호수가 초록빛으로 탁해졌다. 물고기가 줄었다.")


static func algae_at(v: Village, x: float, y: float) -> bool:
	for a: Dictionary in v.algae:
		if Vector2(float(a["x"]) - x, float(a["y"]) - y).length() < 10.0:
			return true
	return false


## 정시마다: 눅눅한 병의 곰팡이 압력 (탑·각설탕) · 탑 둘레의 말 (믿는 사람·의심하는 사람) — 난수 없이 (다른 흐름을 흔들지 않게)
static func _tower_tick(v: Village) -> void:
	if v.towers.is_empty() and v.drops.is_empty():
		return
	var hr := int(v.t / Balance.HOUR)
	if int(v.t) % int(Balance.HOUR) >= int(UNLOCK_EVERY):
		return                                       # 정시마다 한 번
	if v.mold != null and v.mold.hw_now(v) > Balance.MOLD_PRESSURE_AT * 0.8:
		# 눅눅한 병: 탑 둘레 습기↑ · 단 덩어리(각설탕) → 곰팡이가 조금 더 잘 생김 (하루 +0.19씩)
		var sweet := v.drops.any(func(d: Dictionary) -> bool: return String(d["item"]) == "각설탕" and float(d["left"]) > 0.0)
		if active_towers(v) > 0:
			v.mold.pressure += 0.008
		if sweet:
			v.mold.pressure += 0.008
	if v.towers.is_empty():
		return
	var tw: Dictionary = v.towers[hr % v.towers.size()]
	var c := Vector2(float(tw["x"]), float(tw["y"]))
	for r in v.people:
		if r.sleeping or r.age < 2.5 or r.say_t > 0.0:
			continue
		if Vector2(r.x, r.y).distance_to(c) > 12.0:
			continue
		if r.belief < 0.25 and r.is_adult():
			v.speak(r, TOWER_DOUBT if v.aware else TOWER_DOUBT_UNAWARE, 7)
		elif hr % 3 == 0:
			v.speak(r, TOWER_LINES[(hr / 3) % TOWER_LINES.size()], 7)
		break


## 저녁 기도 자리: 탑이 있으면 기도하는 사람 몇은 탑 아래로 (성소 — WE 4.4). 탑 자리 또는 null
static func tower_pray(v: Village, r: Resident) -> Variant:
	if v.towers.is_empty():
		return null
	if (r.id + int(v.t / Balance.HOUR)) % 2 == 0:
		return null
	var tw: Dictionary = v.towers[r.id % v.towers.size()]
	return Vector2(float(tw["x"]), float(tw["y"]))
