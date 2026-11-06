## 혈통 — docs/BLOODLINES.md 1~5장 (v1, 안). 혈통 하나 = 능력 하나. 좋은 혈통 18 · 나쁜 혈통 15.
## 한 사람당 최대 2칸. 짝인 좋은·나쁜 혈통을 함께 가지면 둘 다 효과 없음 (칸은 차지).
## 유전: 부모 한쪽 50% · 둘 다 90% · 부모엔 없고 조부모가 가짐 5% · 새로 생김 좋은 2% / 나쁜 3%.
## 겉모습 유전자(data/genetics.gd)와 따로 — 능력은 여기만 바꾼다.
##
## 항목: id · name · good · pair(짝 id, 없으면 "") · stat(바꾸는 능력) · value(배율 또는 값) · extra(같은 능력의 딸린 값) · look(겉모습 표시) ·
##       stub(true = 그 능력이 시뮬레이션에 아직 없음 — 효과는 fx에 담기지만 아무도 읽지 않음)
## 능력 이름 (Resident.fx 의 키, 기본값):
##   illness 병·부상 확률 ×(1) · heal 회복 빠르기 ×(1) · lifespan 수명 ×(1) · carry 한 번에 나르는 짐 ×(1) ·
##   carry_work 짐 나르며 걷기·힘쓰는 일(나무꾼·채석장·짓기) ×(1) · walk 걸음 ×(1) · craft 공방 일(제재소·방앗간·빵집) ×(1) ·
##   skill_growth 숙련 성장 ×(1) · fert 개인 출산 배율 [하한, 상한]으로 타고남 · food 식량 소비 ×(1) ·
##   cold / heat 추위·더위 불이익 ×(1, 0 = 없음) · fear_rise 두려움 오름 ×(1) · belief_up / belief_down 믿음 오름·떨어짐 ×(1) ·
##   happiness 본인 행복 +(0) · house_happy 같은 집 식구 행복 +(0) · work_aura 근처 일꾼 작업 +(0) · festival 축제 효과 ×(1) ·
##   farm 농장 ×(1) · forestry 벌목·채석 ×(1) · water 우물(물 긷기) ×(1) · fishing 어업 ×(1) · fog 안개 걷는 반경 ×(1) ·
##   explore 탐험 나서는 빈도 ×(1) · wander 방랑 (0/1) · wake_late 늦게 일어나는 시간 +(0)
class_name Bloodlines
extends RefCounted

const MAX_SLOTS := 2
const PASS_ONE := 0.5            # 부모 한쪽만 가짐
const PASS_BOTH := 0.9           # 부모 둘 다
const PASS_GRAND := 0.05         # 부모엔 없고 조부모가 가짐 (격세유전)
const NEW_GOOD := 0.02           # 새로 생김 (부모에게 없던 혈통 하나)
const NEW_BAD := 0.03
const WANDER_P := 0.08           # 방랑벽: 일하는 시간에 결정할 때마다 이 확률로 멀리 걸어감
const WANDER_DIST := [14.0, 26.0]
const WAKE_LATE_H := 1.0
const SINGER_RANGE := 8.0        # 노래꾼이 일하는 곳에서 이 거리 안의 일터

const LIST := [
	# ── 짝 (12쌍) ──
	{"id": "sturdy", "name": "강인한", "good": true, "pair": "frail", "stat": "illness", "value": 0.7, "look": "red_cheeks", "stub": true},
	{"id": "frail", "name": "병약", "good": false, "pair": "sturdy", "stat": "illness", "value": 1.3, "extra": {"heal": 0.75}, "look": "pale", "stub": true},
	{"id": "long_lived", "name": "장수", "good": true, "pair": "short_lived", "stat": "lifespan", "value": 1.15, "look": "silver_early"},
	{"id": "short_lived", "name": "단명", "good": false, "pair": "long_lived", "stat": "lifespan", "value": 0.8, "look": "skinny"},
	{"id": "strong", "name": "힘센", "good": true, "pair": "weak", "stat": "carry", "value": 1.5, "look": "broad_shoulders"},
	{"id": "weak", "name": "허약", "good": false, "pair": "strong", "stat": "carry_work", "value": 0.8, "look": "narrow_shoulders"},
	{"id": "swift", "name": "날랜", "good": true, "pair": "sluggish", "stat": "walk", "value": 1.2, "look": "slim_legs"},
	{"id": "sluggish", "name": "굼뜬", "good": false, "pair": "swift", "stat": "walk", "value": 0.8, "look": "slow_gait"},
	{"id": "handy", "name": "손재주", "good": true, "pair": "clumsy", "stat": "craft", "value": 1.15, "look": "apron"},
	{"id": "clumsy", "name": "서툰 손", "good": false, "pair": "handy", "stat": "craft", "value": 0.85, "look": "bandage"},
	{"id": "master", "name": "장인", "good": true, "pair": "forgetful", "stat": "skill_growth", "value": 1.25, "look": "brow_wrinkle"},
	{"id": "forgetful", "name": "잊음 많은", "good": false, "pair": "master", "stat": "skill_growth", "value": 0.75, "look": "vacant_eyes"},
	{"id": "fertile", "name": "다산", "good": true, "pair": "barren", "stat": "fert", "value": [1.2, 1.6], "look": "round_face"},
	{"id": "barren", "name": "난산", "good": false, "pair": "fertile", "stat": "fert", "value": [0.4, 0.8], "look": ""},
	{"id": "light_eater", "name": "소식", "good": true, "pair": "glutton", "stat": "food", "value": 0.85, "look": "slender"},
	{"id": "glutton", "name": "대식가", "good": false, "pair": "light_eater", "stat": "food", "value": 1.2, "look": "belly"},
	{"id": "cold_hardy", "name": "추위 견딤", "good": true, "pair": "cold_weak", "stat": "cold", "value": 0.0, "look": "thick_brows", "stub": true},
	{"id": "cold_weak", "name": "추위 탐", "good": false, "pair": "cold_hardy", "stat": "cold", "value": 2.0, "look": "neck_scarf", "stub": true},
	{"id": "heat_hardy", "name": "더위 견딤", "good": true, "pair": "heat_weak", "stat": "heat", "value": 0.0, "look": "tanned", "stub": true},
	{"id": "heat_weak", "name": "더위 탐", "good": false, "pair": "heat_hardy", "stat": "heat", "value": 2.0, "look": "brim_hat", "stub": true},
	{"id": "bold", "name": "담대", "good": true, "pair": "timid", "stat": "fear_rise", "value": 0.5, "look": "upright", "stub": true},
	{"id": "timid", "name": "겁 많음", "good": false, "pair": "bold", "stat": "fear_rise", "value": 1.5, "look": "hunched", "stub": true},
	{"id": "pious", "name": "경건", "good": true, "pair": "doubting", "stat": "belief_up", "value": 1.3, "extra": {"belief_down": 0.7}, "look": "amulet"},
	{"id": "doubting", "name": "의심 많은", "good": false, "pair": "pious", "stat": "belief_up", "value": 0.7, "extra": {"belief_down": 1.3}, "look": "frown"},
	# ── 짝 없는 좋은 혈통 (6) ──
	{"id": "cheerful", "name": "명랑", "good": true, "pair": "", "stat": "happiness", "value": 0.05, "extra": {"house_happy": 0.02}, "look": "smile"},
	{"id": "singer", "name": "노래꾼", "good": true, "pair": "", "stat": "work_aura", "value": 0.03, "extra": {"festival": 1.2}, "look": "pipe"},
	{"id": "farmer", "name": "농사꾼", "good": true, "pair": "", "stat": "farm", "value": 1.15, "look": "straw_hat"},
	{"id": "woodcutter", "name": "나무꾼", "good": true, "pair": "", "stat": "forestry", "value": 1.15, "look": "thick_arms"},
	{"id": "waterfolk", "name": "물가 사람", "good": true, "pair": "", "stat": "water", "value": 1.2, "extra": {"fishing": 1.2}, "look": "barefoot"},
	{"id": "explorer", "name": "탐험가", "good": true, "pair": "", "stat": "fog", "value": 1.5, "extra": {"explore": 1.67}, "look": "staff"},
	# ── 짝 없는 나쁜 혈통 (3) ──
	{"id": "melancholy", "name": "우울", "good": false, "pair": "", "stat": "happiness", "value": -0.05, "extra": {"festival": 0.5}, "look": "droopy_eyes"},
	{"id": "wanderer", "name": "방랑벽", "good": false, "pair": "", "stat": "wander", "value": 1.0, "look": "cloak"},
	{"id": "sleepyhead", "name": "잠꾸러기", "good": false, "pair": "", "stat": "wake_late", "value": 1.0, "look": "messy_hair"},
]
## 더하는 값 (나머지는 곱하는 배율)
const ADDITIVE := {"happiness": true, "house_happy": true, "work_aura": true, "wander": true, "wake_late": true}
## 아직 시뮬레이션에 없는 능력 (효과는 fx에 담기지만 읽는 곳이 없음)
const STUB_STATS := ["illness", "cold", "heat", "fear_rise", "fishing"]

static var _by_id: Dictionary = {}
static var _good: PackedStringArray = []
static var _bad: PackedStringArray = []


static func _index() -> void:
	if not _by_id.is_empty():
		return
	for d: Dictionary in LIST:
		_by_id[d["id"]] = d
		if d["good"]:
			_good.append(d["id"])
		else:
			_bad.append(d["id"])


static func get_def(id: String) -> Dictionary:
	_index()
	return _by_id.get(id, {})


static func good_ids() -> PackedStringArray:
	_index()
	return _good


static func bad_ids() -> PackedStringArray:
	_index()
	return _bad


static func name_of(id: String) -> String:
	return get_def(id).get("name", id)


static func pair_of(id: String) -> String:
	return get_def(id).get("pair", "")


## 효과가 있는 혈통 (짝이 함께 있으면 둘 다 빠짐)
static func active(blood: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for id in blood:
		var p := pair_of(id)
		if p != "" and p in blood:
			continue
		out.append(id)
	return out


## 효과 사전 {능력: 값} — 곱하는 능력은 곱해서, 더하는 능력은 더해서. 'fert'는 [하한, 상한]
static func effects(blood: PackedStringArray) -> Dictionary:
	var fx := {}
	for id in active(blood):
		var d := get_def(id)
		var all := {d["stat"]: d["value"]}
		all.merge(d.get("extra", {}))
		for k: String in all:
			var val: Variant = all[k]
			if val is Array:
				fx[k] = val
			elif ADDITIVE.has(k):
				fx[k] = float(fx.get(k, 0.0)) + float(val)
			else:
				fx[k] = float(fx.get(k, 1.0)) * float(val)
	return fx


## 겉모습 표시 (가진 혈통 모두 — 상쇄돼도 생김새는 남는다)
static func looks(blood: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for id in blood:
		var lk: String = get_def(id).get("look", "")
		if lk != "":
			out.append(lk)
	return out


## 아이의 혈통 — mom/dad = 부모의 혈통, grand = 조부모 넷이 가졌던 혈통 (합집합)
static func inherit(rng: RandomNumberGenerator, mom: PackedStringArray, dad: PackedStringArray, grand: PackedStringArray) -> PackedStringArray:
	var got := PackedStringArray()
	var seen := {}
	for id in mom + dad:
		if seen.has(id):
			continue
		seen[id] = true
		var p := PASS_BOTH if (id in mom and id in dad) else PASS_ONE
		if rng.randf() < p:
			got.append(id)
	for id in grand:
		if seen.has(id):
			continue
		seen[id] = true
		if rng.randf() < PASS_GRAND:
			got.append(id)
	# 새로 생김 — 부모에게 없던 혈통 하나
	if rng.randf() < NEW_GOOD:
		var n := _new_one(rng, good_ids(), mom + dad + got)
		if n != "":
			got.append(n)
	if rng.randf() < NEW_BAD:
		var n := _new_one(rng, bad_ids(), mom + dad + got)
		if n != "":
			got.append(n)
	return cap_slots(rng, got)


static func _new_one(rng: RandomNumberGenerator, pool: PackedStringArray, have: PackedStringArray) -> String:
	var c := PackedStringArray()
	for id in pool:
		if not id in have:
			c.append(id)
	return c[rng.randi() % c.size()] if not c.is_empty() else ""


## 칸이 넘치면 무작위로 2개만
static func cap_slots(rng: RandomNumberGenerator, blood: PackedStringArray) -> PackedStringArray:
	var b := blood.duplicate()
	while b.size() > MAX_SLOTS:
		b.remove_at(rng.randi() % b.size())
	return b


## 짧은 설명 (확인용)
static func describe(blood: PackedStringArray) -> String:
	if blood.is_empty():
		return "혈통 없음"
	var act := active(blood)
	var parts := PackedStringArray()
	for id in blood:
		parts.append(name_of(id) + ("" if id in act else "(상쇄)"))
	return ", ".join(parts)
