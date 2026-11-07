## 제단 크기 (SAVE.md 3.1 · EVENTS_STAGING 2b · 2c — BALANCE v5). 순수 로직, 상태는 Village (altar_level · altar_rebuild_until · altar).
##  · 주민은 아침·저녁 기도 때 남는 물건의 반나절치를 제단에 올린다 (Village.evening_offering). 제단은 기도 몇 번치만 담는다:
##    1 돌무더기 = 반나절 · 2 판석 = 하루 · 3 꽃 = 이틀 · 4 작은 사당 = 사흘 (읍내부터). 가득 차면 주민은 계속 기도하지만 더 쌓지 않는다
##    (남는 물건은 창고에 그대로 — 거두면 다음 기도에 다시 올린다). 그래서 비운 동안 받는 공물 = 등불 시간과 제단 자리 중 작은 쪽.
##  · 넓히기 (지폐): 주민이 반나절 동안 제단을 다시 짓는다 (돌을 나르고 쌓음 — 간단한 판. 연출은 나중에 EVENTS_STAGING 2b).
class_name Altar
extends RefCounted


## 지금 단계가 담는 기도 수
static func slots(v: Village) -> int:
	return int(Balance.ALTAR_SLOTS[clampi(v.altar_level, 0, Balance.ALTAR_SLOTS.size() - 1)])


## 제단에 쌓인 기도 수 (같은 기도에 올린 물건은 한 번으로)
static func used(v: Village) -> int:
	var keys := {}
	for o: Dictionary in v.altar:
		keys[int(o.get("k", int(float(o["t"]) / 60.0)))] = true
	return keys.size()


static func full(v: Village) -> bool:
	return used(v) >= slots(v)


static func rebuilding(v: Village) -> bool:
	return v.t < v.altar_rebuild_until


static func level_name(v: Village) -> String:
	return String(Balance.ALTAR_NAMES[clampi(v.altar_level, 0, Balance.ALTAR_NAMES.size() - 1)])


## 담는 양 (날) — 화면 글 ("반나절치" …)
static func days(v: Village) -> float:
	return slots(v) * 0.5


## 다음 단계 {name, cost, lock} — 다 넓혔으면 {}
static func next(v: Village) -> Dictionary:
	if v.altar_level >= Balance.ALTAR_COST.size():
		return {}
	var lv := v.altar_level
	var lock := ""
	if not v.altar_built:
		lock = "제단이 생기면"
	elif v.era < int(Balance.ALTAR_ERA[lv]):
		lock = "%s 시대부터" % Balance.ERAS[int(Balance.ALTAR_ERA[lv])]
	elif rebuilding(v):
		lock = "다시 짓는 중"
	return {"name": Balance.ALTAR_NAMES[lv + 1], "cost": float(Balance.ALTAR_COST[lv]), "slots": int(Balance.ALTAR_SLOTS[lv + 1]), "lock": lock}


## 지폐를 내고 한 단계 넓힌다 — 주민이 반나절 동안 다시 짓는다. 못 하면 false
static func expand(v: Village) -> bool:
	var nx := next(v)
	if nx.is_empty() or String(nx["lock"]) != "" or not Market.pay(float(nx["cost"])):
		return false
	v.altar_level += 1
	v.altar_rebuild_until = v.t + Balance.ALTAR_REBUILD
	var c := v.chief()
	var nm := level_name(v)
	if v.aware:
		v.log_line("{w:이/가} 제단을 넓혀 주셨다. 사람들은 돌을 날라 %s%s 다시 쌓았다." % [nm, Village.josa(nm, "을", "를")])
	if c != null:
		v.speak(c, "다 함께 돌을 나르자! 제단을 더 크게 쌓는 거야.", 8)
	Awakening.gather_ring(v, Awakening.EVENING_RING, "제단을 다시 쌓는 중", false)
	v.giant_acted()
	return true
