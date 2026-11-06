## 거인의 상점 — docs/SHOP.md (진열 1 · 물건 2 · 손의 흐름 3) · ROADMAP A7. 순수 로직 (화면은 view/ui/shop_sheet.gd).
## 진열 탭은 병(Village)마다 열린다: 1일차 건물 + 빵 부스러기 → 2일차 먹을 것·재료 전부 → 첫 병자·첫 위기 조짐이 생긴 날 돌봄 →
##   첫 수확 다음 날 땅. 생물·이주민·꾸미기는 아직 '곧'. 열린 때는 Village.shop_open (탭 → 병 시각)에 걸어 둔다 (한 번 열리면 그대로).
## 산 물건은 **거인의 손** (Market.hand — 모든 병이 함께, 최대 5개, 거인 묶음에 저장)에 들린다. 떨어뜨리기는 sim/sky_drops.gd.
## 건물은 같은 병에서 또 사면 ×1.5 (Village.shop_bought). 영양제 앰플은 한 병에 동시에 2개까지 (손에 든 것 포함).
## 카드 글: '거인에게는 / 병 안에서는' 두 줄 (SHOP 4). 주민 말·연대기에는 상점·구매·키트·상자를 쓰지 않는다 (sky_drops.gd가 맡음).
class_name Shop
extends RefCounted

const HAND_MAX := 5
const TABS := ["건물", "먹을 것·재료", "돌봄", "땅", "생물", "이주민", "꾸미기"]
const TAB_ICON := {"건물": "마을로 가기", "먹을 것·재료": "각설탕", "돌봄": "반창고 조각", "땅": "영양제 앰플",
	"생물": "작은 양", "이주민": "이주민 뽑기", "꾸미기": "조약돌"}
const FOOD_FULL := "먹을 것·재료+"      # 2일차에 먹을 것·재료가 모두 열림 (반짝임이 한 번 더)
const AMPOULE := "영양제 앰플"
const AMPOULE_MAX := 2

## 건물 사 주기 (SHOP 2.1) — 값은 Balance.SHOP, 열리는 시대는 이 표 (제재소·방앗간·빵집·목조주택 = 마을 시대).
## 어부는 시뮬레이션에 아직 없는 건물이라 '곧'으로 보인다.
const BUILDINGS := ["우물", "창고", "농장", "나무꾼", "채석장", "어부", "제재소", "방앗간", "빵집", "목조주택"]
const BUILDING_ERA := {"우물": 0, "창고": 0, "농장": 0, "나무꾼": 0, "채석장": 0, "어부": 0, "제재소": 1, "방앗간": 1, "빵집": 1, "목조주택": 1}
const BUILDING_REPEAT := 1.5
const BUILDING_LINE := {"우물": "맑은 물을 길어요. 배앓이가 줄어요", "창고": "식량과 자재를 넉넉히 쌓아요", "농장": "밀이 자라는 밭",
	"나무꾼": "나무를 베어 통나무를 날라요", "채석장": "바위를 깨 돌을 날라요", "어부": "물가에서 물고기를 잡아요",
	"제재소": "통나무를 켜서 판자로", "방앗간": "밀을 빻아 밀가루로", "빵집": "밀가루와 물로 빵을", "목조주택": "여섯 식구가 사는 큰 집"}

## 물건 (SHOP 2.2~2.4 · WORLD_EVENTS 4.1 · 4.4). kind: food(식량 days일치 — 마을 크기 비례) · stuff(자원 amt) · pill · bandage · salt · ampoule.
## res = 주민이 깎아 나르는 창고 물건. size = 병 안에서의 반지름 (칸). lock = 아직 못 사는 까닭 (비면 살 수 있음)
const ITEMS := {
	"빵 부스러기": {"tab": "먹을 것·재료", "price": 100, "giant": "손톱만 한 부스러기", "inside": "갈색 바위 — 식량 반나절치",
		"kind": "food", "res": "빵", "days": 0.5, "size": 1.3, "day1": true},
	"쌀 한 톨": {"tab": "먹을 것·재료", "price": 150, "giant": "쌀 한 톨", "inside": "하얀 통나무만 한 낟알 — 식량 하루치",
		"kind": "food", "res": "건량", "days": 1.0, "size": 1.4},
	"각설탕": {"tab": "먹을 것·재료", "price": 500, "giant": "각설탕 한 조각", "inside": "하얀 돌집 — 마을 사람들의 일주일 양식",
		"kind": "food", "res": "건량", "days": 7.0, "size": 1.7},
	"밀 이삭 한 줄기": {"tab": "먹을 것·재료", "price": 400, "giant": "밀 이삭 하나", "inside": "쓰러진 황금 나무 — 식량 나흘치, 밀가루 재료",
		"kind": "food", "res": "밀", "days": 4.0, "size": 2.2},
	"나무젓가락": {"tab": "먹을 것·재료", "price": 450, "giant": "나무젓가락 한 짝", "inside": "거대한 통나무 — 통나무 여든 개",
		"kind": "stuff", "res": "통나무", "amt": 80, "size": 2.0},
	"자갈 한 알": {"tab": "먹을 것·재료", "price": 300, "giant": "자갈 한 알", "inside": "바위산 — 돌 마흔 개",
		"kind": "stuff", "res": "돌", "amt": 40, "size": 1.8},
	"녹슨 못": {"tab": "먹을 것·재료", "price": 700, "giant": "못 하나", "inside": "붉은 쇠기둥 — 쇠",
		"kind": "stuff", "res": "철", "amt": 20, "size": 1.0, "lock": "철기 시대에"},
	"알약 부스러기": {"tab": "돌봄", "price": 900, "giant": "알약 가루 한 톨", "inside": "하얀 바위만 한 약 덩어리 — 몹시 아픈 사람이 가벼워져요",
		"kind": "pill", "size": 1.2, "days": 3.0},
	"반창고 조각": {"tab": "돌봄", "price": 300, "giant": "반창고 귀퉁이", "inside": "하얀 천 더미 — 다친 사람이 낫고 상처가 곪지 않아요",
		"kind": "bandage", "size": 1.5, "days": 5.0},
	"마른 약초 한 잎": {"tab": "돌봄", "price": 400, "giant": "마른 잎 한 장", "inside": "숲만 한 잎 — 약초 서른 묶음",
		"kind": "stuff", "res": "약초", "amt": 30, "size": 2.0},
	"소금 한 꼬집": {"tab": "돌봄", "price": 450, "giant": "소금 한 꼬집", "inside": "하얀 모래 언덕 — 털뭉치 괴물이 녹고 소금 마흔 줌. 밭에 떨어지면 땅이 짜져요",
		"kind": "salt", "res": "소금", "amt": 40, "size": 1.7},
	"소독약 한 방울": {"tab": "돌봄", "price": 700, "giant": "소독약 한 방울", "inside": "호수만 한 냄새나는 웅덩이", "lock": "곧"},
	"성냥개비": {"tab": "돌봄", "price": 400, "giant": "성냥개비 하나", "inside": "통나무 산과 붉은 머리", "lock": "곧"},
	"털실 한 가닥": {"tab": "돌봄", "price": 600, "giant": "털실 한 가닥", "inside": "끝없는 밧줄", "lock": "곧"},
	"이끼 한 줌": {"tab": "돌봄", "price": 350, "giant": "이끼 한 줌", "inside": "새 숲", "lock": "곧"},
	"영양제 앰플": {"tab": "땅", "price": 1500, "giant": "손가락만 한 약병", "inside": "하늘에서 꽂힌 유리 탑 — 이레 동안 둘레 땅이 기름져요",
		"kind": "ampoule", "size": 1.8},
	"회색 돌멩이": {"tab": "땅", "price": 1200, "giant": "엄지만 한 돌", "inside": "바위 언덕", "lock": "곧"},
	"작은 양 한 쌍": {"tab": "생물", "price": 800, "giant": "작은 양 한 쌍", "inside": "목장의 양털과 고기", "lock": "곧"},
	"작은 닭 다섯": {"tab": "생물", "price": 500, "giant": "작은 닭 다섯", "inside": "달걀", "lock": "곧"},
	"작은 당나귀": {"tab": "생물", "price": 1000, "giant": "작은 당나귀", "inside": "짐 나르기", "lock": "곧"},
	"이주민 뽑기": {"tab": "이주민", "price": 300, "giant": "작은 사람 하나", "inside": "마을 어귀에 내려앉는 새 이웃", "lock": "곧"},
	"조약돌": {"tab": "꾸미기", "price": 200, "giant": "조약돌 하나", "inside": "광장 장식", "lock": "곧"},
	"병 받침": {"tab": "꾸미기", "price": 800, "giant": "병 받침", "inside": "흔들림이 줄어요", "lock": "곧"},
}


# ───────────────────────── 진열 (탭이 열리는 때) ─────────────────────────
## 지금 조건을 보고 새로 열린 탭을 걸어 둔다 (SkyDrops.step이 1분마다 · 상점을 열 때). 새로 열린 이름 목록
static func update_unlocks(v: Village) -> PackedStringArray:
	var out := PackedStringArray()
	var day := v.cal_day(v.t)
	var want := {"건물": true, "먹을 것·재료": true}
	if day >= 2:
		want[FOOD_FULL] = true
	if int(v.stats.get("sick", 0)) > 0 or (v.mold != null and (v.mold.phase != "calm" or v.mold.episodes > 0)):
		want["돌봄"] = true
	if v.first_harvest_t >= 0.0 and day > v.cal_day(v.first_harvest_t):
		want["땅"] = true
	for k: String in want:
		if not v.shop_open.has(k):
			v.shop_open[k] = v.t
			out.append(k)
	return out


static func tab_open(v: Village, tab: String) -> bool:
	return v.shop_open.has(tab)


## 닫힌 탭의 말 ('곧' · 언제 열리나)
static func tab_hint(v: Village, tab: String) -> String:
	match tab:
		"돌봄":
			return "누가 처음 앓거나 위기의 조짐이 보이면 열려요"
		"땅":
			return "첫 곡식을 거둔 다음 날 열려요" if v.first_harvest_t < 0.0 else "내일 열려요"
	return "새 물건이 들어오면 여기 진열돼요"


## 상점 버튼 옆 반짝임: 열렸는데 아직 들여다보지 않은 탭이 있다 (빨간 점 금지 — 작은 반짝임)
static func has_new(v: Village) -> bool:
	for k: String in v.shop_open:
		if not k in v.shop_seen:
			return true
	return false


static func is_new(v: Village, tab: String) -> bool:
	if tab == "먹을 것·재료" and v.shop_open.has(FOOD_FULL) and not FOOD_FULL in v.shop_seen:
		return true
	return v.shop_open.has(tab) and not tab in v.shop_seen


static func mark_seen(v: Village, tab: String) -> void:
	for k: String in [tab, FOOD_FULL if tab == "먹을 것·재료" and v.shop_open.has(FOOD_FULL) else ""]:
		if k != "" and v.shop_open.has(k) and not k in v.shop_seen:
			v.shop_seen.append(k)


## 탭 안의 물건 이름 (보이는 순서)
static func items_in(tab: String) -> PackedStringArray:
	var out := PackedStringArray()
	if tab == "건물":
		for b: String in BUILDINGS:
			out.append(b)
		return out
	for k: String in ITEMS:
		if String(ITEMS[k]["tab"]) == tab:
			out.append(k)
	return out


static func is_building(item: String) -> bool:
	return item in BUILDINGS


## 물건 하나의 카드 값 {name, icon, giant, inside, price, ok(살 수 있음), lock(못 사는 까닭 — 비면 없음)}
static func card(v: Village, item: String) -> Dictionary:
	if is_building(item):
		var lock := ""
		if not Balance.SHOP.has(item) or not Balance.B.has(item):
			lock = "곧"
		elif int(BUILDING_ERA.get(item, 0)) > v.era:
			lock = "%s 시대에" % Balance.ERAS[mini(int(BUILDING_ERA[item]), Balance.ERAS.size() - 1)]
		var n := int(v.shop_bought.get(item, 0))
		var inside := "완성된 %s — %s" % [item, BUILDING_LINE.get(item, "")]
		if n > 0:
			inside += " (또 사면 값이 올라요)"
		return {"name": item, "icon": item, "giant": "손톱만 한 %s" % item, "inside": inside,
			"price": price(v, item), "lock": lock, "building": true}
	var d: Dictionary = ITEMS[item]
	var lock2 := String(d.get("lock", ""))
	if lock2 == "" and not tab_open(v, String(d["tab"])):
		lock2 = "곧"
	if lock2 == "" and String(d["tab"]) == "먹을 것·재료" and not bool(d.get("day1", false)) and not v.shop_open.has(FOOD_FULL):
		lock2 = "2일차에"
	return {"name": item, "icon": item, "giant": String(d["giant"]), "inside": String(d["inside"]), "price": price(v, item),
		"lock": lock2, "building": false}


## 값 (지폐) — 건물은 이 병에서 산 만큼 ×1.5씩
static func price(v: Village, item: String) -> float:
	if is_building(item):
		return float(Balance.SHOP.get(item, 0)) * pow(BUILDING_REPEAT, int(v.shop_bought.get(item, 0)))
	return float(ITEMS[item]["price"])


## 영양제 앰플: 이 병에 서 있는 (아직 다 스미지 않은) 탑 + 손에 든 앰플
static func ampoules_used(v: Village) -> int:
	return SkyDrops.active_towers(v) + hand_count(AMPOULE)


static func hand_count(item: String) -> int:
	var n := 0
	for h: Dictionary in Market.hand:
		if String(h["item"]) == item:
			n += 1
	return n


## 지금 살 수 있나 → {ok, why, need(모자란 지폐)}
static func can_buy(v: Village, item: String) -> Dictionary:
	var c := card(v, item)
	if String(c["lock"]) != "":
		return {"ok": false, "why": String(c["lock"]), "need": 0.0}
	if Market.hand.size() >= HAND_MAX:
		return {"ok": false, "why": "손이 가득 찼어요 (%d개)" % HAND_MAX, "need": 0.0}
	if item == AMPOULE and ampoules_used(v) >= AMPOULE_MAX:
		return {"ok": false, "why": "탑은 한 병에 둘까지예요", "need": 0.0}
	var cost := float(c["price"])
	if not Market.can_pay(cost):
		var need := ceilf(cost - Market.notes)
		return {"ok": false, "why": "지폐가 %s 모자라요" % _num(need), "need": need}
	return {"ok": true, "why": "", "need": 0.0}


## 산다 → 거인의 손에 든다. 저장은 거인의 행동 (Village.giant_acted → 거인 묶음 + 그 병). 결과 {ok, why, hand_id}
static func buy(v: Village, item: String) -> Dictionary:
	var c := can_buy(v, item)
	if not bool(c["ok"]):
		return c
	var cost := price(v, item)
	Market.pay(cost)
	if is_building(item):
		v.shop_bought[item] = int(v.shop_bought.get(item, 0)) + 1
	Market.hand_serial += 1
	Market.hand.append({"id": Market.hand_serial, "item": item, "paid": cost})
	v.giant_acted()
	return {"ok": true, "why": "", "hand_id": Market.hand_serial}


static func hand_item(id: int) -> Dictionary:
	for h: Dictionary in Market.hand:
		if int(h["id"]) == id:
			return h
	return {}


static func hand_remove(id: int) -> void:
	for i in Market.hand.size():
		if int(Market.hand[i]["id"]) == id:
			Market.hand.remove_at(i)
			return


static func _num(v: float) -> String:
	var n := int(roundf(v))
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
