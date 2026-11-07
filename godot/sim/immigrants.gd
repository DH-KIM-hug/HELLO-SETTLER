## 이주민 뽑기 — 기획서 11.2 · BALANCE v3 (이주민) · SHOP 2.6 · BLOODLINES 5 · 7.3 · ROADMAP B2. 순수 로직.
## 값: 그날 첫 번 300 지폐, 같은 날 다시 뽑을 때마다 ×1.5 (300 · 450 · 675 · 1,013 · 1,519), **하루 5번**. '그날' = 현실 하루 (Market._today — 모든 병 합쳐서).
## 누가 올지는 모른다: 혼자 60% · 2~4명 가족 40% (가족 안: 둘 60% · 셋 30% · 넷 10% → 한 번에 평균 1.6명). 둘 = 부부, 셋·넷 = 부부 + 아이.
##   등급은 기획서 7.2 표 그대로 (Balance.GRADE_P — 사람마다). 혈통 (BLOODLINES 5 '무작위 — 좋은·나쁜 모두'): 어른마다 좋은 10% · 나쁜 10% (안 — 개발에서 정함).
##   겉모습은 모두 무작위 (Genetics.random_genes — 드문 변이·점박이도 같은 확률). 아이는 함께 온 부모를 닮는다 (Village._inherit_look).
##   겉모습은 능력과 상관없다 (BLOODLINES 7 원칙 ①). 인종 이름은 쓰지 않는다.
## 확률은 상점 카드의 [확률 보기]에 그대로 공개한다 (odds_rows). 주민 말·연대기에는 숫자·상점·구매·뽑기 같은 말을 쓰지 않는다.
## 흐름: Shop.buy → 손에 '이주민 뽑기' {seed} (누가 올지는 놓을 때 드러남 — 같은 seed면 같은 사람들) → SkyDrops.drop → land:
##   거인의 손이 마을 어귀(영역 안)에 작은 뗏목 꾸러미와 사람들을 내려놓는다. 집이 없으면 모닥불 곁에서 지내며 촌장이 집을 짓는다 (Village.chief_build).
##   마을의 맞이: 깨달은 뒤 믿음이 높으면 축제처럼 (행복 잠깐↑), 낮으면 경계 (행복 잠깐↓) · 깨닫기 전엔 낯선 사람에 술렁임 (거인 이야기 없음).
## 비운 동안(따라잡기)에는 아무도 오지 않는다 — 거인이 손으로 내려놓을 때만.
## 밖에서 온 병 (HEALTH 2.6 · WORLD_EVENTS 5 — ROADMAP B7): carry_disease — 열병·역병을 지니고 와 하루 잠복 (창백한 얼굴빛).
class_name Immigrants
extends RefCounted

const ITEM := "이주민 뽑기"
const PRICE0 := 300.0
const PRICE_MULT := 1.5
const DAILY_MAX := 5
const SOLO_P := 0.6
const FAMILY_SIZES := [[2, 0.6], [3, 0.3], [4, 0.1]]
const BLOOD_GOOD_P := 0.10
const BLOOD_BAD_P := 0.10
const SOLO_ELDER_P := 0.1
const SEED_SALT := 7_340_033
const MOOD_DAYS := 1.0
const WELCOME_FAITH := 50.0           # 깨달은 뒤 믿음 (0~100) 이 위 = 축제처럼 맞이
const MOOD_WELCOME := 0.08
const MOOD_WARY := -0.06
const MOOD_UNAWARE := -0.03
const WELCOME_BELIEF := 0.03
const RAFT_DAYS := 0.5                # 뗏목 꾸러미가 그 자리에 남아 있는 시간 (사그라듦)
const SIZE := 1.3                     # 내려놓는 자리 반지름 (칸)


# ───────────────────────── 값 · 하루 횟수 (거인 — 모든 병) ─────────────────────────
static func _roll_day() -> void:
	var d := Market._today()
	if d != Market.mig_day:
		Market.mig_day = d
		Market.mig_n = 0


## 오늘 뽑은 횟수
static func today_count() -> int:
	_roll_day()
	return Market.mig_n


## 다음 한 번의 값 (오늘 n번 뽑았으면 300 × 1.5^n). 원 단위로 반올림 (1,012.5 → 1,013)
static func price() -> float:
	return price_at(today_count())


static func price_at(n: int) -> float:
	return roundf(PRICE0 * pow(PRICE_MULT, n))


static func left_today() -> int:
	return maxi(0, DAILY_MAX - today_count())


## 산 것으로 센다 (Shop.buy) → 손에 들 꾸러미의 seed
static func note_bought() -> int:
	_roll_day()
	Market.mig_n += 1
	Market.mig_serial += 1
	if Market.mig_seed == 0:
		Market.mig_seed = int(Time.get_ticks_usec() % 1_000_000_007) + 1
	return hash([Market.mig_seed, Market.mig_serial, SEED_SALT])


# ───────────────────────── 누가 오나 (seed → 같은 사람들) ─────────────────────────
## seed → [{sex, age, grade, trait, blood, genes, name, child, mom, dad}] (mom/dad = 이 목록 안의 자리, 없으면 -1)
static func roll(seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := 1
	if rng.randf() >= SOLO_P:
		var u := rng.randf()
		for fs: Array in FAMILY_SIZES:
			n = int(fs[0])
			if u < float(fs[1]):
				break
			u -= float(fs[1])
	var out: Array = []
	var used := {}
	if n == 1:
		var sex := "m" if rng.randf() < 0.5 else "f"
		var age := rng.randf_range(Balance.AGE_ELDER + 0.5, Balance.AGE_ELDER + 4.0) if rng.randf() < SOLO_ELDER_P else rng.randf_range(4.5, 16.0)
		out.append(_person(rng, sex, age, false, used))
		return out
	var dad_age := rng.randf_range(5.5, 13.0)
	var mom_age := clampf(dad_age + rng.randf_range(-2.0, 1.5), 5.0, 13.0)
	out.append(_person(rng, "m", dad_age, false, used))
	out.append(_person(rng, "f", mom_age, false, used))
	for i in n - 2:
		var kid := _person(rng, "m" if rng.randf() < 0.5 else "f", rng.randf_range(0.3, minf(3.8, mom_age - 4.0)), true, used)
		kid["dad"] = 0
		kid["mom"] = 1
		out.append(kid)
	return out


static func _person(rng: RandomNumberGenerator, sex: String, age: float, child: bool, used: Dictionary) -> Dictionary:
	var pool: Array = Balance.NAMES_M if sex == "m" else Balance.NAMES_F
	var nm: String = pool[rng.randi() % pool.size()]
	var guard := 0
	while used.has(nm) and guard < pool.size():
		nm = pool[(pool.find(nm) + 1) % pool.size()]
		guard += 1
	used[nm] = true
	var tr: Array = Balance.TRAITS[rng.randi() % Balance.TRAITS.size()]
	var blood := PackedStringArray()
	if not child:
		if rng.randf() < BLOOD_GOOD_P:
			var g := Bloodlines.good_ids()
			blood.append(g[rng.randi() % g.size()])
		if rng.randf() < BLOOD_BAD_P:
			var b := Bloodlines.bad_ids()
			var pick := b[rng.randi() % b.size()]
			if blood.is_empty() or Bloodlines.pair_of(blood[0]) != pick:
				blood.append(pick)
	return {"sex": sex, "age": age, "grade": roll_grade(rng), "trait": String(tr[0]), "blood": blood,
		"genes": Genetics.random_genes(rng), "name": nm, "child": child, "mom": -1, "dad": -1}


## 등급 — 기획서 7.2 표 (Balance.GRADE_P)
static func roll_grade(rng: RandomNumberGenerator) -> int:
	var u := rng.randf()
	for g in range(Balance.GRADE_P.size() - 1, 0, -1):
		if u < Balance.GRADE_P[g]:
			return g
		u -= Balance.GRADE_P[g]
	return 0


# ───────────────────────── 공개 확률표 (상점 카드 [확률 보기]) ─────────────────────────
## 오는 사람 수의 확률 {1: 0.6, 2: 0.24, 3: 0.12, 4: 0.04}
static func size_odds() -> Dictionary:
	var d := {1: SOLO_P}
	for fs: Array in FAMILY_SIZES:
		d[int(fs[0])] = (1.0 - SOLO_P) * float(fs[1])
	return d


## 등급마다 확률 [이름, p] (일반 = 나머지)
static func grade_odds() -> Array:
	var rest := 1.0
	for g in range(1, Balance.GRADE_P.size()):
		rest -= float(Balance.GRADE_P[g])
	var out: Array = [[Balance.GRADES[0], rest]]
	for g in range(1, Balance.GRADE_P.size()):
		out.append([Balance.GRADES[g], float(Balance.GRADE_P[g])])
	return out


static func pct(p: float) -> String:
	var s := "%.2f" % (p * 100.0)
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s + "%"


## 화면에 그대로 쓰는 공개표 — [[머리말, [[칸, 확률 글]...]]...]
static func odds_rows() -> Array:
	var so := size_odds()
	var sizes: Array = [["혼자", pct(so[1])], ["둘 (부부)", pct(so[2])], ["셋 (부부 + 아이)", pct(so[3])], ["넷 (부부 + 아이 둘)", pct(so[4])]]
	var grades: Array = []
	for g: Array in grade_odds():
		grades.append([String(g[0]), pct(float(g[1]))])
	var blood: Array = [["좋은 혈통 하나", pct(BLOOD_GOOD_P)], ["나쁜 혈통 하나", pct(BLOOD_BAD_P)]]
	var looks: Array = [["짝짝이 눈 · 흰 앞머리", pct(Genetics.RARE_P)], ["눈송이 무늬", pct(Genetics.PIEBALD_NEW_P)]]
	return [["몇 명이 오나 (한 번에)", sizes], ["등급 (사람마다)", grades], ["혈통 (어른마다, 아이는 부모에게서)", blood], ["드문 겉모습 (사람마다 — 능력과는 상관없어요)", looks]]


# ───────────────────────── 내려놓기 ─────────────────────────
## 이 자리에 내려놓을 수 있나 → SkyDrops.preview가 공통 검사를 한 뒤 부름. {ok, why}
static func spot_ok(v: Village, p: Vector2, crush: Array) -> Dictionary:
	if not v.in_territory(p.x, p.y, 0.0):
		return {"ok": false, "why": "마을 어귀에 내려 주세요 — 마을 땅 밖이에요"}
	if not crush.is_empty():
		return {"ok": false, "why": "집 위에는 내려놓을 수 없어요 — 빈 땅에"}
	return {"ok": true, "why": ""}


## 사람들을 내려놓는다 → 새 주민 목록. 연대기 · 맞이 · 가계도 (부모 id) · 집 (빈자리 → 없으면 모닥불 곁, 촌장이 짓는다)
static func land(v: Village, p: Vector2, seed_v: int) -> Array[Resident]:
	var plan := roll(seed_v)
	var made: Array[Resident] = []
	var taken := {}
	for q in v.people:
		taken[q.name] = true
	for i in plan.size():
		var s: Dictionary = plan[i]
		var nm := String(s["name"])
		var pool: Array = Balance.NAMES_M if String(s["sex"]) == "m" else Balance.NAMES_F
		var k := 0
		while taken.has(nm) and k < pool.size():            # 마을에 같은 이름이 살아 있으면 다음 이름
			nm = String(pool[(pool.find(nm) + 1) % pool.size()])
			k += 1
		taken[nm] = true
		var a := TAU * float(i) / maxf(1.0, float(plan.size())) + 0.4
		var r := v.add_person(nm, String(s["sex"]), float(s["age"]), String(s["trait"]), p.x + cos(a) * 0.7, p.y + sin(a) * 0.7, null, null)
		r.grade = int(s["grade"])
		r.genes = s["genes"]
		r.belief = (Balance.BELIEF_START * 0.6) if v.aware else 0.0      # 막 내려온 사람은 아직 마을만큼 믿지 않는다
		r.facing = a
		if not bool(s["child"]):
			v.set_blood(r, s["blood"], "migrant")
		made.append(r)
	for i in plan.size():
		var s: Dictionary = plan[i]
		if int(s["mom"]) >= 0:
			var kid := made[i]
			var mom := made[int(s["mom"])]
			var dad := made[int(s["dad"])]
			kid.parents = PackedInt32Array([mom.id, dad.id])
			v._inherit_look(kid, mom, dad)                   # 아이는 함께 온 부모를 닮는다 (혈통도 부모에게서)
	if plan.size() >= 2:
		v.marry(made[0], made[1])
		v.stats["marriages"] = int(v.stats["marriages"]) - 1   # 이 마을에서 맺은 혼인이 아니다
	v.assign_homes()
	v.stats["migrants"] = int(v.stats.get("migrants", 0)) + made.size()
	carry_disease(v, made)
	_greet(v, made, p)
	give_hints(v, made)
	return made


## 밖에서 온 병 (HEALTH 2.6 · WORLD_EVENTS 5 — ROADMAP B7): 열병이 사는 기후(열대·아열대)에서 온 사람의 5%가 열병, 누구든 1%가 역병을 지니고 온다.
## 어디서 왔는지·누가 지녔는지는 보이지 않는다 (숫자 없음) — 하루 잠복 (아프지도 옮기지도 않음) 동안 거인에게는 창백한 얼굴빛으로만 보인다.
## 굴림은 건강 난수 흐름 (Village.health_rng). 다른 병에서 온 사람은 이 마을이 겪은 병의 면역이 없다 (Resident.immune이 빈 채로 온다).
static func carry_disease(v: Village, made: Array[Resident]) -> void:
	var fever_land := v.health_rng.randf() < Balance.MIGRANT_FEVER_LANDS
	for r in made:
		var u := v.health_rng.randf()
		if u < Balance.MIGRANT_PLAGUE_P:
			Health.make_latent(v, r, Balance.PLAGUE)
		elif fever_land and u < Balance.MIGRANT_PLAGUE_P + Balance.MIGRANT_FEVER_P:
			Health.make_latent(v, r, "열병")


## 마을의 맞이 — 말 둘 · 연대기 한 줄 · 행복 잠깐 (숫자·상점 말 없음, 깨닫기 전엔 거인 이야기 없음)
static func _greet(v: Village, made: Array[Resident], p: Vector2) -> void:
	var names := PackedStringArray()
	for r in made:
		names.append(r.name)
	var mood := MOOD_UNAWARE
	var kind := "unaware"
	if v.aware:
		kind = "welcome" if v.faith >= WELCOME_FAITH else "wary"
		mood = MOOD_WELCOME if kind == "welcome" else MOOD_WARY
	v.migrants = {"t": v.t, "until": v.t + MOOD_DAYS * Balance.DAY, "mood": mood, "kind": kind, "ids": made.map(func(r: Resident) -> int: return r.id)}
	if kind == "welcome":
		v.bless_all(WELCOME_BELIEF)
	v.log_line(book_line(v.aware, kind, names, made.size() > 1))
	var first: Resident = made[0]
	v.speak(first, newcomer_line(v.aware, made.size() > 1), 8)
	var near := v.people.filter(func(q: Resident) -> bool: return not q in made and not q.sleeping and q.age >= 2.5)
	near.sort_custom(func(a: Resident, c: Resident) -> bool: return Vector2(a.x, a.y).distance_squared_to(p) < Vector2(c.x, c.y).distance_squared_to(p))
	for i in mini(2, near.size()):
		v.speak(near[i], village_line(kind, i), 8)
	Awakening.witness(v, "drop")


## 마을 사람의 말 [깨달은 뒤 반김, 깨달은 뒤 경계, 깨닫기 전]
const VILLAGE_SAY := {
	"welcome": ["{w:이/가} 새 이웃을 보내 주셨다!", "어서 와요, 잔치를 열어야겠어!"],
	"wary": ["하늘에서 사람이 내려왔어… 믿어도 될까?", "낯선 얼굴이네. 지켜보자."],
	"unaware": ["하늘에서 사람이 내려왔어!", "누구지…? 어디서 온 사람일까?"],
}


static func village_line(kind: String, i: int) -> String:
	var l: Array = VILLAGE_SAY.get(kind, VILLAGE_SAY["unaware"])
	return String(l[clampi(i, 0, l.size() - 1)])


## 갓 온 사람의 첫 말 — 깨달은 마을이어도 지켜보는 이를 말하지 않는다 (population.md R6-7 · 사용자 결정 2026-11-08): 낯선 곳의 말만.
## aware는 옛 부르는 쪽과 같은 모양으로 남겨 둔다 (깨달은 마을 사람들이 반기면 조금 놓인 말)
static func newcomer_line(aware: bool, family: bool) -> String:
	if aware:
		return "여긴 어디지…? 우리 식구도 여기서 지내도 될까요?" if family else "여긴 어디지…? 여기서 지내도 될까요?"
	return "여긴 어디지…? 우리 식구가 쉴 곳이 있을까요?" if family else "여긴 어디지…? 쉴 곳이 있을까요?"


## 연대기 한 줄 (숫자 없음)
static func book_line(aware: bool, kind: String, names: PackedStringArray, family: bool) -> String:
	var who := _join(names)
	var head := "하늘에서 새 사람이 내려왔다." if not family else "하늘에서 새 가족이 내려왔다."
	if not aware:
		head = "어느 날 마을 어귀에 낯선 사람이 서 있었다." if not family else "어느 날 마을 어귀에 낯선 식구가 서 있었다."
		return "%s 이름은 %s. 어디서 왔는지는 아무도 몰랐다." % [head, who]
	var them := "새 이웃을" if not family else "새 식구들을"
	var tail := ("마을은 잔치를 열어 %s 맞았다." if kind == "welcome" else "사람들은 한동안 %s 멀찍이서 지켜보았다.") % them
	return "%s 이름은 %s. %s" % [head, who, tail]


static func _join(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return names[0] if names.size() == 1 else ""
	var a := ", ".join(names.slice(0, names.size() - 1))
	var last := names[names.size() - 1]
	return "%s%s %s" % [a, Village.josa(names[names.size() - 2], "과", "와"), last]


## 맞이의 행복 (Village._update_happiness가 사람마다 더함) — 하루 동안 잦아든다
static func mood(v: Village) -> float:
	if v.migrants.is_empty():
		return 0.0
	var until := float(v.migrants.get("until", -1.0))
	if v.t >= until:
		return 0.0
	var k := clampf((until - v.t) / (MOOD_DAYS * Balance.DAY), 0.0, 1.0)
	return float(v.migrants.get("mood", 0.0)) * k


# ───────────────────────── 조각 (숨은 진실 — STORY 1 · population.md R6-6) ─────────────────────────
## 어른 이주민마다 Balance.HINT_P로 조각 하나. 네 가지가 한 번씩 다 나온 뒤에야 다시 섞어 채운다 (v.hint_bag).
## 굴림은 v.pop_rng만 (혼인·출산·건강 흐름을 흔들지 않게). 연대기 한 줄 + 사건 immigrant_hint, 말풍선은 say_hints가 한 번.
static func give_hints(v: Village, made: Array[Resident]) -> void:
	for r in made:
		if r.age < Balance.AGE_ADULT:      # 아이는 조각을 지니지 않는다 (어른·노인만)
			continue
		if v.pop_rng.randf() >= Balance.HINT_P:
			continue
		var id := next_hint(v)
		r.hint = id
		r.hint_said = false
		v.log_line(hint_text(String(Balance.IMMIGRANT_HINTS[id]["book"]), r.name))
		v.emit(&"immigrant_hint", {"who": r.id, "v": {"hint": id}})


## 다음 조각 id — 주머니가 비면 네 가지를 pop_rng로 섞어 채운다 (한 번씩 다 나온 뒤에야 되풀이)
static func next_hint(v: Village) -> String:
	if v.hint_bag.is_empty():
		var bag: Array = Balance.HINT_ORDER.duplicate()
		for i in range(bag.size() - 1, 0, -1):
			var j := v.pop_rng.randi() % (i + 1)
			var tmp: Variant = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		v.hint_bag = bag
	return String(v.hint_bag.pop_front())


## {n} = 이름 · {n:은/는} = 이름 + 받침에 맞는 조사
static func hint_text(tpl: String, nm: String) -> String:
	var out := tpl
	var i := out.find("{n:")
	while i >= 0:
		var j := out.find("}", i)
		var pair := out.substr(i + 3, j - i - 3).split("/")
		out = out.substr(0, i) + nm + Village.josa(nm, pair[0], pair[1] if pair.size() > 1 else pair[0]) + out.substr(j + 1)
		i = out.find("{n:")
	return out.replace("{n}", nm)


## 조각을 지닌 사람이 말풍선이 비어 있을 때 한 번 (Village.idle_chatter — 하루 몇 번 도는 말 차례, 난수 없음). 한 차례에 한 사람
static func say_hints(v: Village) -> void:
	for r in v.people:
		if r.hint == "" or r.hint_said or r.sleeping or r.say_t > 0.0 or not Balance.IMMIGRANT_HINTS.has(r.hint):
			continue
		v.speak(r, String(Balance.IMMIGRANT_HINTS[r.hint]["say"]), 7)
		r.hint_said = true
		return


## 거인 UI (사람 상세): 이 사람이 지닌 조각 [이름, 설명] — 없으면 []
static func hint_ui(r: Resident) -> Array:
	if r == null or r.hint == "" or not Balance.IMMIGRANT_HINTS.has(r.hint):
		return []
	var h: Dictionary = Balance.IMMIGRANT_HINTS[r.hint]
	return [String(h["label"]), String(h["desc"])]


# ───────────────────────── 빈 집 자리 (상점 카드 — population.md R6-8 · 사용자 결정 2026-11-08) ─────────────────────────
## 지은 집의 빈자리 합. 0이어도 뽑기는 막지 않는다 — 카드에 HOMELESS_NOTE 한 줄 (Shop.card "note")
const HOMELESS_NOTE := "모닥불 곁에서 지내게 돼요"


static func free_house_slots(v: Village) -> int:
	var occ := v.occupancy()
	var n := 0
	for h in v.houses():
		n += maxi(0, h.cap() - int(occ.get(h.id, 0)))
	return n
