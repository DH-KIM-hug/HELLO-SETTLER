## 스타터킷 (가칭 '사람 키우기 키트') — 기획서 v3.8 5.5 · 5.1 단계 8. 거인이 세상 지도에서 고른 자리에 푼다.
## 기본 키트: 두 가족 10명 · 오두막 2채 · 살림 · 모닥불 · 도구 꾸러미 · 씨앗 한 자루 (안). 업그레이드는 건물을 더한다.
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

## 영구 업그레이드 (지폐로 산다, 모든 새 세상에 적용) — 더하는 건물 [종류, dx, dy]
const UPGRADES := {
	"제재소": [["제재소", -6.5, -4.0]],
	"밀밭": [["농장", 7.0, -5.0]],
	"우물": [["우물", 0.5, 5.5]],
	"방앗간": [["방앗간", -7.0, 6.0]],
}


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


## 기본 키트 + 고른 업그레이드 (+ 추가 키트 종류)
static func make(upgrades: Array = [], variant := "") -> Dictionary:
	var k := BASE.duplicate(true)
	for u: String in upgrades:
		if UPGRADES.has(u):
			(k["buildings"] as Array).append_array((UPGRADES[u] as Array).duplicate(true))
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
