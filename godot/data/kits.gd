## 스타터킷 (가칭 '사람 키우기 키트') — 기획서 v3.8 5.5 · 5.1 단계 8. 거인이 세상 지도에서 고른 자리에 푼다.
## 기본 키트: 두 가족 10명 · 오두막 2채 · 살림 · 모닥불 · 도구 꾸러미 · 씨앗 한 자루 (안). 업그레이드는 키트 안의 것을 키운다 (21장).
## 자리 = 키트 중심(창고)에서의 거리 (칸). 이름·내용·가격은 밸런스 v3에서 정함 — 지금 값은 (정함).
class_name Kits
extends RefCounted

const BASE := {
	"name": "기본 키트",
	"buildings": [["창고", 0.0, 0.0], ["오두막", -4.2, 3.2], ["오두막", 4.4, 3.0]],
	"fire": [2.2, 1.6],
	"people": "first_settlers",          # Balance.FIRST_SETTLERS (두 가족 + 노인 + 젊은이)
	"stock": "start",                    # Balance.START_STOCK (건량·판자·돌·도구 꾸러미)
	"seeds": 1,                          # 씨앗 한 자루 (지금은 표시용 — 농장은 씨앗 없이도 지음)
}

## 영구 업그레이드 (선반 화면 — ROADMAP C1, 지폐로 산다, 모든 새 세상에 적용). 값은 BALANCE v3-4 통합표.
## 기획서 21장 '키트 업그레이드 범위': **스타터킷 안의 것만** (주민·집·씨앗·도구·암반 컵) — 채석장·마을 시대 건물·가축은 상점에서 하나씩.
##   price = 지폐 (배열이면 n번째 살 때 값) · max = 살 수 있는 횟수 · what = 키트의 어느 것을 키우나
##   add = 더하는 건물 [종류, dx, dy] · swap = [옛 집, 새 집] (키트의 집을 바꿈) · family = 더하는 가족 (혈통 없음) · cups = 고를 수 있는 암반 컵
const UPGRADES := {
	"밀밭": {"price": 1500, "max": 1, "what": "씨앗", "add": [["농장", 7.0, -5.0]]},
	"목조 주택": {"price": 7500, "max": 1, "what": "집", "swap": ["오두막", "목조주택"]},          # 오두막 2채 → 목조 주택 2채
	"가족 하나 더": {"price": [8000, 12000], "max": 2, "what": "주민", "family": true},           # 5명 + 오두막 한 채
	"암반 컵 하나 더": {"price": 4000, "max": 4, "what": "암반 컵", "cups": ["철", "석탄", "금", "암염"]},   # 컵마다 (창조 2단계 — 색: 붉은·검정·반짝이·하양)
}
## '가족 하나 더' — 혈통 없는 다섯 식구 (두 번째 가족은 다른 이름). [이름, 성, 나이(일), 특징] (Balance.FIRST_SETTLERS와 같은 꼴)
const EXTRA_FAMILIES := [
	[["요한", "m", 13.0, "말수가 적음"], ["안나", "f", 12.0, "손이 야무짐"], ["미아", "f", 3.0, ""], ["파울", "m", 1.5, ""], ["로자", "f", 18.0, "옛이야기를 많이 앎"]],
	[["루카스", "m", 14.0, "잘 웃음"], ["클라라", "f", 12.5, "새벽형"], ["벤", "m", 2.8, ""], ["이다", "f", 1.0, ""], ["마틴", "m", 20.0, "느긋함"]],
]
const FAMILY_HUTS := [["오두막", 0.2, 6.2], ["오두막", -0.4, -5.6]]


## 업그레이드 값 (n = 이미 산 횟수) — 더 살 수 없으면 −1
static func upgrade_price(name: String, n := 0) -> int:
	if not UPGRADES.has(name):
		return -1
	var u: Dictionary = UPGRADES[name]
	if n >= int(u.get("max", 1)):
		return -1
	var p: Variant = u["price"]
	if p is Array:
		return int((p as Array)[mini(n, (p as Array).size() - 1)])
	return int(p)


## 추가 키트 종류 (기획서 5.5 · BLOODLINES 5장) — 가족 전원이 정해진 좋은 혈통 1~2개 (나쁜 혈통은 키트에 없다).
## "looks" = 사람마다 거인이 고른 겉모습 (Genetics.from_look 칸 — 빠진 칸·null은 무작위 추천값 "가족끼리 닮게").
## 순서는 people과 같다: [0] 한스 [1] 마르타 [2] 리나 [3] 토미 [4] 오토 [5] 엘자 [6] 펠릭스 [7] 베른 [8] 그레타 [9] 카를
const VARIANTS := {
	"힘센 가족": {"blood": ["strong"], "looks": [{"build": 0.85, "height": 0.7}, {"build": 0.75}, null, null, {"build": 0.8}]},
	"날랜 가족": {"blood": ["swift"], "looks": [{"height": 0.75, "build": 0.3}, {"height": 0.7, "build": 0.3}]},
	"장인 가문": {"blood": ["master", "handy"]},
	"다산 가족": {"blood": ["fertile"]},
	"경건한 가족": {"blood": ["pious"]},
	"탐험가 가족": {"blood": ["explorer"]},
	"강인한 가족": {"blood": ["sturdy", "long_lived"]},
}


## 기본 키트 + 고른 업그레이드 (+ 추가 키트 종류). 같은 업그레이드를 여러 번 넣으면 그만큼 (가족 둘·암반 컵 여럿 — max까지)
static func make(upgrades: Array = [], variant := "") -> Dictionary:
	var k := BASE.duplicate(true)
	var bl: Array = k["buildings"]
	var seen := {}
	var families := 0
	var cups: Array = []
	for u: String in upgrades:
		if not UPGRADES.has(u):
			continue
		var ud: Dictionary = UPGRADES[u]
		seen[u] = int(seen.get(u, 0)) + 1
		if int(seen[u]) > int(ud.get("max", 1)):
			continue
		bl.append_array((ud.get("add", []) as Array).duplicate(true))
		if bool(ud.get("family", false)) and families < EXTRA_FAMILIES.size():
			bl.append((FAMILY_HUTS[families] as Array).duplicate())
			families += 1
		if ud.has("cups"):
			cups.append(String((ud["cups"] as Array)[cups.size() % (ud["cups"] as Array).size()]))
	if seen.has("목조 주택"):
		var sw: Array = UPGRADES["목조 주택"]["swap"]
		for b: Array in bl:
			if b[0] == sw[0]:
				b[0] = sw[1]
	if families > 0:
		var ppl := Balance.FIRST_SETTLERS.duplicate(true)
		for i in families:
			ppl.append_array((EXTRA_FAMILIES[i] as Array).duplicate(true))
		k["people"] = ppl
	if not cups.is_empty():
		k["cups"] = cups                  # 창조 때 더 부을 암반 컵 (창조 화면이 쓸 자리 — 아직 WorldGen은 시드로)
	k["upgrades"] = upgrades.duplicate()
	if VARIANTS.has(variant):
		k["name"] = variant
		k.merge((VARIANTS[variant] as Dictionary).duplicate(true), true)
	return k


## 가족 전원의 혈통 (기본 키트 = 없음)
static func blood(kit: Dictionary) -> PackedStringArray:
	return PackedStringArray(kit.get("blood", []))


## 고른 겉모습 (사람 순서대로, 없으면 빈 배열)
static func looks(kit: Dictionary) -> Array:
	return kit.get("looks", [])


static func people(kit: Dictionary) -> Array:
	return Balance.FIRST_SETTLERS if kit["people"] is String else kit["people"]


static func stock(kit: Dictionary) -> Dictionary:
	return Balance.START_STOCK.duplicate() if kit["stock"] is String else (kit["stock"] as Dictionary).duplicate()
