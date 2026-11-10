## 인구 (design/gdd/population.md — 사용자 결정 2026-11-08) — tests/run.gd가 부름 (`-- population` = 이것만, 몇 초).
## 혼인·출산 확률은 병 하루 비율 → 걸음마다 1 − exp(−비율 × dt / DAY) (F2·F3: 늘 0~1, 걸음 크기와 무관 — AC2·AC4) ·
## 보지 않을 때 아끼기는 가임 부부만 센다 (R4-2 · AC10) · 이주민의 조각: 25% · 네 가지가 한 번씩 다 나온 뒤 되풀이 · pop_rng만 씀 (R6-6 · AC15) ·
## 주민 말·연대기에 지구·거인·숫자·금지어 없음 (R6-7 · AC14) · 빈 집 자리 없으면 상점 카드에 '모닥불 곁' 한 줄, 뽑기는 그대로 (R6-8).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const FORBID := ["지구", "거인", "게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "뽑기", "지폐"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 인구 (population.md)")
	run.timed(self, ["test_rates", "test_rates_mc", "test_fertile_couples", "test_offline_spare", "test_hints", "test_hint_words", "test_homeless_note",
		"test_two_rate_aging", "test_old_age_rate", "test_little_cap", "test_little_floor", "test_little_floor_pick", "test_little_first_birth", "test_little_save",
		"test_forage_gate", "test_forage_trip", "test_forage_pool", "test_forage_words_save"])


func _bad(texts: Array) -> String:
	var rx := RegEx.create_from_string("[0-9]")
	for tx: String in texts:
		for w: String in FORBID:
			if tx.contains(w):
				return "'%s' in %s" % [w, tx]
		if rx.search(tx) != null:
			return "숫자 in %s" % tx
	return ""


# ───────────────────────── F2·F3 확률 ─────────────────────────
func test_rates() -> void:
	check(Balance.MARRY_RATE == 0.5 and Balance.BIRTH_RATE == 0.6, "기획서 값: 혼인 0.5 · 출산 0.6 (병 하루 비율)")
	var p_day := Village.day_rate_p(Balance.MARRY_RATE, Balance.DAY)
	check(absf(p_day - (1.0 - exp(-0.5))) < 1e-9, "혼인: 병 하루 한 걸음 p = 1 − e^−0.5 = %.4f" % p_day)
	# 걸음 크기와 무관: 10초 걸음 8,640번 = 80초 걸음 1,080번 = 하루 한 걸음
	for dt: float in [10.0, 60.0, 80.0]:
		var n := Balance.DAY / dt
		var p_n := 1.0 - pow(1.0 - Village.day_rate_p(Balance.MARRY_RATE, dt), n)
		check(absf(p_n - p_day) < 1e-6, "걸음 %d초로 하루 → %.5f (하루 한 걸음 %.5f와 같음)" % [int(dt), p_n, p_day])
	# λ 최대 1.278 (0.6 × 1.6 × 1.331) — 큰 걸음(따라잡기 하루·사흘)에서도 p ≤ 1
	var lam_max := Balance.BIRTH_RATE * Balance.FERT_HI * float(Balance.ENV_FOOD[2]) * float(Balance.ENV_HAPPY[2]) * Balance.ENV_FESTIVAL
	var ok := true
	for dt: float in [60.0, Balance.DAY, 3.0 * Balance.DAY, 100.0 * Balance.DAY]:
		var p := Village.day_rate_p(lam_max, dt)
		ok = ok and p >= 0.0 and p <= 1.0
	check(lam_max > 1.0 and ok, "출산 λ 최대 %.3f > 1이어도 어떤 걸음에서든 0 ≤ p ≤ 1" % lam_max)
	var lam := Balance.BIRTH_RATE * 1.2 * 1.1 * 1.0 * 1.1
	check(absf(Village.day_rate_p(lam, Balance.DAY) - 0.5815) < 0.001, "F3 예: λ 0.871 → 병 하루 출생 %.3f (≈ 0.58)" % Village.day_rate_p(lam, Balance.DAY))
	check(Village.day_rate_p(0.5, -5.0) == 0.0 and Village.day_rate_p(-1.0, 60.0) == 0.0, "음수 걸음·비율은 0")


## AC2: 미혼 한 쌍 1,000번 × 병 하루 (60초 걸음) → 0.39 ± 0.03 — 같은 식을 쓰는 rng 굴림
func test_rates_mc() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var n := 1000
	var hit := 0
	var hit80 := 0
	for i in n:
		for dt: float in [60.0, 80.0]:
			var steps := int(Balance.DAY / dt)
			var p := Village.day_rate_p(Balance.MARRY_RATE, dt)
			for k in steps:
				if rng.randf() < p:
					if dt == 60.0:
						hit += 1
					else:
						hit80 += 1
					break
	var a := float(hit) / n
	var b := float(hit80) / n
	check(absf(a - 0.393) < 0.03 and absf(b - 0.393) < 0.03, "혼인 1,000쌍 × 병 하루: 60초 걸음 %.3f · 80초 걸음 %.3f (목표 0.39 ± 0.03)" % [a, b])


# ───────────────────────── 가임 부부 (R4-2) ─────────────────────────
func _proto() -> Village:
	var v := Village.new_prototype(424242)
	v.water.offline = true
	return v


func _couple(v: Village, wife_age: float, man_age: float) -> Array:
	var m := v.add_person("가람", "m", man_age, "", v.fire.x, v.fire.y, null, null)
	var f := v.add_person("나래", "f", wife_age, "", v.fire.x, v.fire.y, null, null)
	v.marry(m, f)
	return [m, f]


func _all_couples(v: Village) -> int:
	return v.people.filter(func(q: Resident) -> bool: return q.sex == "f" and q.partner >= 0).size()


func test_fertile_couples() -> void:
	var v := _proto()
	var f0 := v.fertile_couples()
	check(f0 == _all_couples(v) and f0 == 2, "첫 정착민: 부부 2쌍 모두 가임 (%d)" % f0)
	_couple(v, 21.0, 22.0)                      # 노인 부부
	_couple(v, 18.5, 17.0)                      # 아내만 가임 끝 (Edge 7)
	var young := _couple(v, 3.5, 6.0)           # 아내가 아직 어른 아님 (혼인 전 나이 — 셈 밖)
	check(v.fertile_couples() == 2 and _all_couples(v) == 5, "노인 부부·아내 가임 끝·아내 어림은 셈에서 빠짐 (가임 %d / 부부 %d)" % [v.fertile_couples(), _all_couples(v)])
	(young[1] as Resident).age = 4.0
	check(v.fertile_couples() == 3, "아내 4일(BIRTH_WIFE_MIN)부터 셈")
	(young[0] as Resident).age = 3.0
	check(v.fertile_couples() == 2, "남편이 어른이 아니면 셈 밖")


## AC10: 보지 않음 + 노인 부부 3쌍 + 가임 부부 2쌍 → 건강 0이어도 아낌 (옛 코드는 부부 5쌍으로 세어 죽었다). 가임 3쌍이면 죽음
func test_offline_spare() -> void:
	var v := _proto()
	for i in 3:
		_couple(v, 21.0, 21.5)
	v.watching = false
	v.watch_hours = []
	var p := v.add_person("다온", "m", 8.0, "", v.fire.x, v.fire.y, null, null)
	p.health = 0.0
	v._deaths(1.0)
	check(not p.dead and p.health > 0.0 and _all_couples(v) == 5 and v.fertile_couples() == 2,
		"보지 않음: 부부 5쌍이어도 가임 2쌍이면 아낌 (건강 %.2f)" % p.health)
	var w := _proto()
	for i in 3:
		_couple(w, 21.0, 21.5)
	_couple(w, 8.0, 9.0)
	w.watching = false
	w.watch_hours = []
	var q := w.add_person("다온", "m", 8.0, "", w.fire.x, w.fire.y, null, null)
	q.health = 0.0
	w._deaths(1.0)
	check(q.dead and w.fertile_couples() == 3, "가임 3쌍이면 아끼지 않음 (위기 죽음)")


# ───────────────────────── 조각 (R6-6) ─────────────────────────
func _adults(v: Village, n: int, age := 8.0) -> Array[Resident]:
	var out: Array[Resident] = []
	for i in n:
		out.append(v.add_person("라온", "m" if i % 2 == 0 else "f", age, "", v.fire.x, v.fire.y, null, null))
	return out


func test_hints() -> void:
	var v := _proto()
	var n := 400
	var made := _adults(v, n)
	var kids := _adults(v, 40, 2.0)
	var all_made: Array[Resident] = []
	all_made.append_array(made)
	all_made.append_array(kids)
	var s_rng := v.rng.state
	var s_health := v.health_rng.state
	var s_gene := v.gene_rng.state
	var s_econ := v.econ_rng.state
	var s_social := v.social_rng.state
	var s_pop := v.pop_rng.state
	var ev0 := v.events.serial
	var bk := v.book.size()
	Immigrants.give_hints(v, all_made)
	check(v.rng.state == s_rng and v.health_rng.state == s_health and v.gene_rng.state == s_gene and v.econ_rng.state == s_econ and v.social_rng.state == s_social
		and v.pop_rng.state != s_pop, "조각 굴림은 pop_rng만 — 혼인·출산·건강·유전·소원·사이 흐름은 그대로")
	check(kids.all(func(r: Resident) -> bool: return r.hint == ""), "아이는 조각을 지니지 않음")
	var order: Array = []
	for ev: Dictionary in v.events.since(ev0):
		if ev["kind"] == &"immigrant_hint":
			order.append(String(ev["v"]["hint"]))
	var carriers := made.filter(func(r: Resident) -> bool: return r.hint != "")
	var ratio := float(carriers.size()) / n
	check(absf(ratio - Balance.HINT_P) <= Balance.HINT_P * 0.5 + 1e-6 and order.size() == carriers.size(), "어른 이주민 %d명 중 조각 %d명 (%.3f, 목표 %.2f ± %.3f) · 사건 %d" % [n, carriers.size(), ratio, Balance.HINT_P, Balance.HINT_P * 0.5, order.size()])
	var once := true
	for i in range(0, order.size() - order.size() % 4, 4):
		var blk := {}
		for k in 4:
			blk[order[i + k]] = true
		once = once and blk.size() == 4
	check(once, "네 가지가 한 번씩 다 나온 뒤에야 되풀이 (네 개 묶음마다 모두 다름 · %d개)" % order.size())
	var counts := {}
	for h: String in order:
		counts[h] = int(counts.get(h, 0)) + 1
	var spread: int = counts.values().max() - counts.values().min() if counts.size() == 4 else 99
	check(counts.size() == 4 and spread <= 1, "네 가지가 고루 %s" % counts)
	check(v.book.size() - bk == carriers.size(), "조각마다 연대기 한 줄")
	# 말풍선 한 번 (말풍선이 빌 때)
	var c0: Resident = carriers[0]
	c0.say_t = 0.0
	for q in v.people:
		if q != c0:
			q.say_t = 99.0
	Immigrants.say_hints(v)
	var said := c0.say
	check(c0.hint_said and said == String(Balance.IMMIGRANT_HINTS[c0.hint]["say"]), "조각 말풍선: \"%s\"" % said)
	c0.say = ""
	c0.say_t = 0.0
	Immigrants.say_hints(v)
	check(c0.say == "", "말풍선은 한 번만")
	check(Immigrants.hint_ui(c0).size() == 2 and Immigrants.hint_ui(kids[0]).is_empty(), "거인 UI: 지닌 조각 [%s]" % ", ".join(Immigrants.hint_ui(c0)))
	# 같은 seed → 같은 조각 · 저장하고 불러도 주머니가 이어짐
	var w := _proto()
	Immigrants.give_hints(w, _adults(w, n))
	var order2: Array = []
	for r in w.people:
		if r.hint != "":
			order2.append(r.hint)
	check(order2 == order, "같은 병 seed → 같은 조각 차례")
	var d := v.to_dict()
	var v2 := Village.from_dict(d, v.water)
	check(v2.hint_bag == v.hint_bag and v2.pop_rng.state == v.pop_rng.state and v2.person(c0.id).hint == c0.hint and v2.person(c0.id).hint_said,
		"저장: 조각 주머니 · pop_rng · 사람의 조각")


# ───────────────────────── 말 규칙 (R6-7 · AC14) ─────────────────────────
func test_hint_words() -> void:
	var texts: Array = []
	for id: String in Balance.HINT_ORDER:
		var h: Dictionary = Balance.IMMIGRANT_HINTS[id]
		for nm: String in ["클라라", "브루노"]:
			texts.append(Immigrants.hint_text(String(h["book"]), nm))
		texts.append(String(h["say"]))
	check(Balance.IMMIGRANT_HINTS.size() == 4 and Balance.HINT_ORDER.size() == 4, "조각 네 가지")
	var bw := _bad(texts)
	check(bw == "", "조각 연대기·말에 지구·거인·숫자·금지어 없음 %s" % bw)
	check(not texts.any(func(tx: String) -> bool: return tx.contains("{")), "조각 글에 채우지 않은 자리 없음")
	check(Immigrants.hint_text("{n:은/는} 노래했다", "클라라") == "클라라는 노래했다" and Immigrants.hint_text("{n:은/는} 노래했다", "브루노") == "브루노는 노래했다"
		and Immigrants.hint_text("{n:은/는} 웃었다", "한스") == "한스는 웃었다" and Immigrants.hint_text("{n:은/는} 웃었다", "마르탱") == "마르탱은 웃었다", "조사: 클라라는 · 마르탱은")
	var nl: Array = []
	for aw: bool in [true, false]:
		for fam: bool in [true, false]:
			nl.append(Immigrants.newcomer_line(aw, fam))
	check(_bad(nl) == "" and not nl.any(func(tx: String) -> bool: return tx.contains("{w")), "갓 온 사람은 지켜보는 이를 말하지 않음 (깨달은 마을에서도): \"%s\"" % nl[0])
	var bl: Array = []
	for aw: bool in [true, false]:
		for kind: String in ["welcome", "wary", "unaware"]:
			bl.append(Immigrants.book_line(aw, kind, PackedStringArray(["클라라"]), false))
	for kind: String in Immigrants.VILLAGE_SAY:
		bl.append_array(Immigrants.VILLAGE_SAY[kind])
	check(_bad(bl) == "", "맞이 연대기·마을 사람 말에 거인·지구 없음 %s" % _bad(bl))


# ───────────────────────── 빈 집 자리 (R6-8) ─────────────────────────
func test_homeless_note() -> void:
	var v := _proto()
	v.shop_open["이주민"] = v.t
	var free0 := Immigrants.free_house_slots(v)
	var c0 := Shop.card(v, Immigrants.ITEM)
	check((free0 <= 0) == c0.has("note"), "빈 집 자리 %d → 카드 한 줄 %s" % [free0, "있음" if c0.has("note") else "없음"])
	# 집을 사람으로 꽉 채움 → 한 줄, 뽑기는 막지 않음 (lock 그대로)
	var h := v.add_building("오두막", v.fire.x + 6.0, v.fire.y, true)
	var lock_free := String(Shop.card(v, Immigrants.ITEM)["lock"])
	check(Immigrants.free_house_slots(v) > 0 and not Shop.card(v, Immigrants.ITEM).has("note"), "빈자리 있으면 한 줄 없음")
	var occ := v.occupancy()
	for b in v.houses():
		var left := b.cap() - int(occ.get(b.id, 0))
		for i in left:
			var r := v.add_person("마루", "m", 8.0, "", h.x, h.y, null, null)
			r.home = b.id
	var c1 := Shop.card(v, Immigrants.ITEM)
	check(Immigrants.free_house_slots(v) == 0 and String(c1.get("note", "")) == "모닥불 곁에서 지내게 돼요" and String(c1["lock"]) == lock_free,
		"빈 집 자리 0 → \"%s\" · 뽑기 잠금 그대로 ('%s')" % [c1.get("note", ""), c1["lock"]])


# ───────────────────────── 어른·노년 ×3 · 어린것은 늘 넷에서 여섯 (2026-11-10 — docs/measure/lifespan_2026-11-10.md 6장 · BALANCE.md) ─────────────────────────
## 어린 시절은 병 4일에 일생 한 날 (Balance.AGE_K), 어른·노인은 병 12일에 한 날 (AGE_K_ADULT)
func test_two_rate_aging() -> void:
	check(Balance.age_k(0.0) == Balance.AGE_K and Balance.age_k(Balance.AGE_ADULT - 0.01) == Balance.AGE_K and Balance.age_k(Balance.AGE_ADULT) == Balance.AGE_K_ADULT
		and Balance.age_k(Balance.AGE_ELDER + 3.0) == Balance.AGE_K_ADULT and Balance.AGE_K == 4.0 and Balance.AGE_K_ADULT == 12.0,
		"나이 먹는 빠르기: 어린 시절 병 %.0f일 · 어른·노인 병 %.0f일에 일생 한 날" % [Balance.AGE_K, Balance.AGE_K_ADULT])
	var v := _proto()
	v.step_dt = 30.0
	var kid := v.add_person("다온", "m", 1.0, "", v.fire.x, v.fire.y, null, null)
	var edge := v.add_person("새봄", "f", 3.9, "", v.fire.x, v.fire.y, null, null)
	var grown := v.add_person("라온", "m", 8.0, "", v.fire.x, v.fire.y, null, null)
	var old := v.add_person("한울", "f", 20.5, "", v.fire.x, v.fire.y, null, null)
	v.advance(4.0 * Balance.DAY)
	check(absf(kid.age - 2.0) < 0.01, "아이: 병 4일에 일생 한 날 (1.0 → %.3f)" % kid.age)
	check(absf(grown.age - (8.0 + 4.0 / 12.0)) < 0.01, "어른: 병 12일에 일생 한 날 (8.0 → %.3f)" % grown.age)
	check(absf(old.age - (20.5 + 4.0 / 12.0)) < 0.01, "노인도 어른과 같은 빠르기 (20.5 → %.3f)" % old.age)
	check(absf(edge.age - (4.0 + 3.6 / 12.0)) < 0.01, "어른이 되는 날을 지나면 그때부터 천천히 (3.9 → %.3f)" % edge.age)


## 노환: 일생 날 하루 확률은 그대로, 병 하루엔 ÷ 12 — 병 6일을 한 걸음에 굴리면 저마다 (0.05 + 0.06 × (나이 − 20)) × 6 ÷ 12
func test_old_age_rate() -> void:
	var v := _proto()
	var made: Array[Resident] = _adults(v, 400, 22.0)
	var want := 0.0
	var want_old := 0.0
	for p in made:
		var la: float = p.age / p.f("lifespan")
		var pd: float = Balance.DEATH_BASE + Balance.DEATH_SLOPE * (la - Balance.DEATH_FROM)
		want += 1.0 if la > Balance.DEATH_MAX_AGE else clampf(pd * 6.0 / Balance.AGE_K_ADULT, 0.0, 1.0)
		want_old += 1.0 if la > Balance.DEATH_MAX_AGE else clampf(pd * 6.0 / Balance.AGE_K, 0.0, 1.0)
	v._deaths(6.0 * Balance.DAY)
	var gone := made.filter(func(r: Resident) -> bool: return r.dead and r.death_why == "노환").size()
	check(absf(gone - want) <= 4.0 * sqrt(want) and gone < want_old * 0.6, "노인 400명 · 병 6일: 노환 %d명 (어른 빠르기로 기대 %.1f · 옛 빠르기였다면 %.1f)" % [gone, want, want_old])


## 출산만 보는 빈 마을: 처음 사람은 모두 떠나보내고, 목조주택 한 채에 부부 하나 + 어린것 littles명 + 어른으로 pop명을 채운다. 첫 출생 보장은 지난 뒤 (병 5일)
func _pace_village(pop: int, littles: int) -> Dictionary:
	var v := _proto()
	v.chief_off = true
	for p in v.people.duplicate():
		v.kill(p, "노환")
	v.t = 5.0 * Balance.DAY
	var house := v.add_building("목조주택", 4.0, -3.0, true)
	var pair := _couple(v, 8.0, 9.0)
	var wife: Resident = pair[1]
	wife.fert = 1.0
	for q: Resident in pair:
		q.home = house.id
	for i in littles:
		v.add_person("다온", "m", 2.0, "", v.fire.x, v.fire.y, null, null)
	_adults(v, pop - v.people.size())
	return {"v": v, "wife": wife, "house": house}


## 창고의 먹을 것을 '하루 먹는 양 × days'로 맞춘다 (먹을 것 문: BIRTH_FOOD_DAYS)
func _set_food(v: Village, days: float) -> void:
	for k: String in Balance.FOODS_ALL:
		v.stock[k] = 0.0
	v.stock[Balance.PORRIDGE] = 0.0
	v.stock["밀가루"] = 0.0
	v.manna.clear()
	v.manna_batches.clear()
	for b in v.buildings:
		b.out.clear()
	v.stock[Balance.FOODS[0]] = days * Production.day_need(v)


func _littles(v: Village) -> int:
	return v.people.filter(func(q: Resident) -> bool: return q.age < Balance.AGE_ADULT).size()


## 규칙 1: 어린것이 여섯이면 다음 아기는 기다린다. 다섯이면 낳을 수 있고, 한 걸음 안에서도 여섯에서 멈춘다
func test_little_cap() -> void:
	var big := 100.0 * Balance.DAY            # 굴림이 거의 반드시 나오는 큰 걸음 (p ≈ 1)
	var a := _pace_village(30, Balance.BIRTH_LITTLE_MAX)
	var v: Village = a["v"]
	_set_food(v, 10.0)
	var s0 := v.rng.state
	for i in 3:
		v._births(big)
	check(v.food_total() >= Balance.BIRTH_FOOD_DAYS * Production.day_need(v) and v.occupants(a["house"]) < (a["house"] as Building).cap() and _littles(v) == Balance.BIRTH_LITTLE_MAX,
		"(준비) 먹을 것 넉넉 · 집에 빈자리 · 어린것 %d명" % _littles(v))
	check(v.stats["born"] == 0, "어린것이 %d명이면 아무도 낳지 않는다 (출생 %d)" % [Balance.BIRTH_LITTLE_MAX, v.stats["born"]])
	check(v.rng.state != s0, "굴림은 예전처럼 한다 (난수 차례가 바뀌지 않게) — 상한은 굴린 뒤에 본다")
	var b := _pace_village(30, Balance.BIRTH_LITTLE_MAX - 1)
	var w: Village = b["v"]
	_set_food(w, 10.0)
	w._births(big)
	check(w.stats["born"] == 1 and _littles(w) == Balance.BIRTH_LITTLE_MAX, "어린것이 %d명이면 낳을 수 있다 (출생 %d)" % [Balance.BIRTH_LITTLE_MAX - 1, w.stats["born"]])
	w._births(big)
	check(w.stats["born"] == 1, "그 아기로 여섯이 되면 다시 기다린다 (출생 %d)" % w.stats["born"])
	# 한 걸음에 두 집이 함께 굴려도 여섯에서 멈춘다
	var c := _pace_village(40, Balance.BIRTH_LITTLE_MAX - 1)
	var u: Village = c["v"]
	var house2 := u.add_building("목조주택", -4.0, -3.0, true)
	var pair2 := _couple(u, 7.0, 8.0)
	(pair2[1] as Resident).fert = 1.0
	for q: Resident in pair2:
		q.home = house2.id
	_set_food(u, 10.0)
	u._births(big)
	check(u.stats["born"] == 1 and _littles(u) == Balance.BIRTH_LITTLE_MAX, "두 부부가 한 걸음에 굴려도 아기는 하나 (출생 %d)" % u.stats["born"])
	check(u.violations.is_empty() and v.violations.is_empty() and w.violations.is_empty(), "집 정원 위반 없음")


## 규칙 2: 먹을 것 문이 닫혀 있고 · 마을이 24명 이상이고 · 어린것이 넷보다 적을 때만 — 한 집이 아기를 맞는다, 병 하루에 하나까지
func test_little_floor() -> void:
	var tiny := 60.0
	var a := _pace_village(Balance.BIRTH_LITTLE_MIN_POP - 1, 0)
	var v: Village = a["v"]
	_set_food(v, 0.0)
	v._births(tiny)
	check(v.food_total() < Balance.BIRTH_FOOD_DAYS * Production.day_need(v) and v.stats["born"] == 0 and v.birth_floor_t < 0.0,
		"먹을 것이 없고 어린것 0명이어도 %d명 마을은 오늘 그대로 — 낳지 않는다" % v.people.size())
	_adults(v, 1)
	_set_food(v, 0.0)
	var bk := v.book.size()
	var s0 := v.rng.state
	v._births(tiny)
	check(v.people.size() == Balance.BIRTH_LITTLE_MIN_POP + 1 and v.stats["born"] == 1 and v.birth_floor_t == v.t,
		"%d명이 되면 한 집이 아기를 맞는다 (출생 %d)" % [Balance.BIRTH_LITTLE_MIN_POP, v.stats["born"]])
	var baby: Resident = v.people[v.people.size() - 1]
	check(baby.age == 0.0 and baby.parents.size() == 2 and baby.parents[0] == (a["wife"] as Resident).id and baby.home == (a["house"] as Building).id and v.violations.is_empty(),
		"아기는 그 부부의 집에서 태어난다 (집 정원 위반 없음)")
	var lines: Array = []
	for i in range(bk, v.book.size()):
		lines.append(String(v.book[i]["text"]))
	check(lines.size() >= 2 and "웃음소리" in String(lines[0]) and _bad(lines) == "", "연대기: \"%s\" — 숫자·금지어 없음 (%s)" % [lines[0] if lines.size() > 0 else "", _bad(lines)])
	check(v.rng.state != s0, "(아기의 성별·이름은 여느 출생처럼 굴린다)")
	v._births(tiny)
	v.t += 0.5 * Balance.DAY
	v._births(tiny)
	check(v.stats["born"] == 1, "병 하루에 하나까지 — 반나절 뒤에는 맞지 않는다 (출생 %d)" % v.stats["born"])
	v.t += 0.6 * Balance.DAY
	bk = v.book.size()
	v._births(tiny)
	check(v.stats["born"] == 2, "병 하루가 지나면 또 한 집 (출생 %d)" % v.stats["born"])
	var again := false
	for i in range(bk, v.book.size()):
		again = again or "웃음소리" in String(v.book[i]["text"])
	check(not again, "'웃음소리' 줄은 되풀이하지 않는다 (병 %.0f일 안 — 낳았다는 줄만)" % Balance.BIRTH_LITTLE_NOTE_DAYS)
	# 어린것이 넷이면 맞지 않는다
	var b := _pace_village(30, Balance.BIRTH_LITTLE_MIN)
	var w: Village = b["v"]
	_set_food(w, 0.0)
	w._births(tiny)
	check(w.stats["born"] == 0, "어린것이 %d명이면 빠듯한 때엔 기다린다 (출생 %d)" % [Balance.BIRTH_LITTLE_MIN, w.stats["born"]])
	w.kill(w.people.filter(func(q: Resident) -> bool: return q.age < Balance.AGE_ADULT)[0], "노환")
	_set_food(w, 0.0)
	w._births(tiny)
	check(w.stats["born"] == 1, "%d명이 되면 맞는다 (출생 %d)" % [Balance.BIRTH_LITTLE_MIN - 1, w.stats["born"]])
	# 먹을 것 문이 열려 있으면 이 규칙은 쓰지 않는다 (여느 굴림뿐 — 아주 짧은 걸음이라 굴림은 나오지 않는다)
	var c := _pace_village(30, 0)
	var u: Village = c["v"]
	_set_food(u, 10.0)
	u._births(1.0e-6)
	check(u.stats["born"] == 0 and u.birth_floor_t < 0.0, "먹을 것이 넉넉하면 여느 굴림만 (출생 %d)" % u.stats["born"])
	# 집에 빈자리가 없으면 맞지 않는다 (이사하지 않는다)
	var d := _pace_village(30, 0)
	var x: Village = d["v"]
	for q in _adults(x, 4):
		q.home = (d["house"] as Building).id
	_set_food(x, 0.0)
	x._births(tiny)
	check(x.occupants(d["house"]) == (d["house"] as Building).cap() and x.stats["born"] == 0 and x.birth_floor_t < 0.0, "제 집이 꽉 찬 부부는 맞지 않는다 (출생 %d)" % x.stats["born"])


## 규칙 2의 집 고르기: 살아 있는 아이가 가장 적은 부부 (같으면 먼저 온 부부) — 난수를 쓰지 않는다
func test_little_floor_pick() -> void:
	var a := _pace_village(30, 0)
	var v: Village = a["v"]
	var first: Resident = a["wife"]
	var house2 := v.add_building("목조주택", -4.0, -3.0, true)
	var pair2 := _couple(v, 7.0, 8.0)
	var second: Resident = pair2[1]
	for q: Resident in pair2:
		q.home = house2.id
	for i in 2:                               # 첫 부부에게 다 자란 자식 둘
		var grown := v.add_person("라온", "m", 5.0, "", v.fire.x, v.fire.y, null, null)
		grown.parents = PackedInt32Array([first.id, first.partner])
	_set_food(v, 0.0)
	v._births(60.0)
	var baby: Resident = v.people[v.people.size() - 1]
	check(v.stats["born"] == 1 and baby.parents.size() == 2 and baby.parents[0] == second.id and baby.home == house2.id, "아이가 없는 부부가 먼저 맞는다")
	v.t += 1.1 * Balance.DAY
	v._births(60.0)
	baby = v.people[v.people.size() - 1]
	check(v.stats["born"] == 2 and baby.parents[0] == second.id, "아직도 아이가 더 적은 부부 (하나 대 둘)")
	v.t += 1.1 * Balance.DAY
	v._births(60.0)
	baby = v.people[v.people.size() - 1]
	check(v.stats["born"] == 3 and baby.parents[0] == first.id, "같아지면 먼저 온 부부")


## 첫 출생 보장은 그대로 — 기본 마을의 첫날, 그리고 어린것이 여섯이어도
func test_little_first_birth() -> void:
	var v := _proto()
	v.step_dt = 30.0
	v.advance(1.0 * Balance.DAY)
	check(v.stats["born"] >= 1, "기본 마을: 첫날에 첫 아기 (출생 %d)" % v.stats["born"])
	var w := _proto()
	w.step_dt = 30.0
	for i in Balance.BIRTH_LITTLE_MAX:
		w.add_person("다온", "m", 2.0, "", w.fire.x, w.fire.y, null, null)
	w.advance(1.0 * Balance.DAY)
	check(_littles(w) > Balance.BIRTH_LITTLE_MAX and w.stats["born"] >= 1, "어린것이 이미 여섯을 넘어도 첫 아기는 온다 (출생 %d · 어린것 %d)" % [w.stats["born"], _littles(w)])


## 저장 → 불러오기: 마지막으로 그렇게 아기를 맞은 때가 그대로 — 쉬는 하루도 이어진다. 옛 저장(값 없음)은 '아직 없음'
func test_little_save() -> void:
	var a := _pace_village(30, 0)
	var v: Village = a["v"]
	_set_food(v, 0.0)
	v._births(60.0)
	var d: Dictionary = bytes_to_var(var_to_bytes(v.to_dict()))
	check(d.has("birth_floor_t") and float(d["birth_floor_t"]) == v.birth_floor_t and not d.has("birth_pace"), "저장에 마지막 때가 들어간다 (%.0f)" % v.birth_floor_t)
	var w := Village.from_dict(d)
	check(w.birth_floor_t == v.birth_floor_t and w.stats["born"] == 1 and w.people.size() == v.people.size(), "불러오면 같은 값")
	for q: Village in [v, w]:
		q.t += 0.5 * Balance.DAY
		q._births(60.0)
	check(v.stats["born"] == 1 and w.stats["born"] == 1, "불러온 마을도 쉬는 하루를 지킨다")
	for q: Village in [v, w]:
		q.t += 0.6 * Balance.DAY
		q._births(60.0)
	var b1: Resident = v.people[v.people.size() - 1]
	var b2: Resident = w.people[w.people.size() - 1]
	check(v.stats["born"] == 2 and w.stats["born"] == 2 and b1.name == b2.name and b1.sex == b2.sex and b1.home == b2.home, "하루 뒤 두 마을에서 같은 아기 (%s · %s)" % [b1.name, b2.name])
	var od: Dictionary = bytes_to_var(var_to_bytes(v.to_dict()))
	od.erase("birth_floor_t")
	var o := Village.from_dict(od)
	check(o.birth_floor_t == -1.0, "옛 저장 (값 없음) → 아직 없음 (%.1f)" % o.birth_floor_t)


# ───────────────────────── 맨손 채집 (design/gdd/daily-schedule.md R4.6 · 2026-11-10) ─────────────────────────
## 일터 없는 어른 열둘 (부부 하나 포함), 낮 10시, 창고 먹을 것 days날치, 남은 연장 tools개, 둘레엔 바구니 열 개치
func _forage_village(tools: float, days: float) -> Village:
	var a := _pace_village(12, 0)
	var v: Village = a["v"]
	v.t = 6.0 * Balance.DAY + 10.0 * Balance.HOUR - fmod(v.start_clock, Balance.DAY)
	v.stock["도구"] = tools
	_set_food(v, days)
	v.wild_food = 10.0 * Balance.FORAGE_LOAD
	return v


func _loose(v: Village) -> Array:
	return v.people.filter(func(q: Resident) -> bool: return q.is_adult() and q.job < 0 and q.home < 0)


## 나가는 때: 일터 없는 어른이 남은 연장보다 많고 창고가 모자랄 때만. 노인·아이·다친 사람·일터 있는 어른·밤·첫 한 시간은 나가지 않는다
func test_forage_gate() -> void:
	var v := _forage_village(3.0, 0.5)
	check(is_equal_approx(v.hour_now(), 10.0) and v.is_work_time() and not v.in_opening(), "낮 10시 · 일하는 시간 (%.1f시)" % v.hour_now())
	check(v.forage_open(), "일터 없는 어른이 남은 연장보다 많고 먹을 것이 모자라면 나간다")
	var w := _forage_village(12.0, 0.5)
	check(not w.forage_open(), "남은 연장이 일터 없는 어른만큼 있으면 나가지 않는다 (연장을 쥘 차례)")
	var x := _forage_village(3.0, Balance.FORAGE_ENOUGH_DAYS + 0.2)
	check(not x.forage_open(), "창고가 넉넉하면 나가지 않는다")
	var pool0 := v.wild_food
	var went := 0
	var loose := _loose(v)
	for r: Resident in loose:
		ResidentAI.decide(v, r)
		if r.action == "forage":
			went += 1
	check(went >= loose.size() - 2 and is_equal_approx(v.wild_food, pool0 - went * Balance.FORAGE_LOAD),
		"낮에 일터 없는 어른 %d명 가운데 %d명이 바구니를 들고 나감 · 둘레의 몫이 그만큼 줄어듦" % [loose.size(), went])
	for q: Village in [w, x]:
		var n := 0
		for r: Resident in _loose(q):
			ResidentAI.decide(q, r)
			if r.action == "forage":
				n += 1
		check(n == 0 and is_equal_approx(q.wild_food, 10.0 * Balance.FORAGE_LOAD), "연장이 남거나 창고가 넉넉한 마을에선 아무도 나가지 않음")
	var y := _forage_village(3.0, 0.5)
	var ys := _loose(y)
	var elder: Resident = ys[0]
	elder.age = Balance.AGE_ELDER + 1.0
	var hurt: Resident = ys[1]
	hurt.injured_left = 3.0 * Balance.DAY
	var worker: Resident = ys[2]
	worker.job = y.store().id
	var kid := y.add_person("다온", "m", 3.0, "", y.fire.x, y.fire.y, null, null)
	var bad := 0
	for r: Resident in [elder, hurt, worker, kid]:
		ResidentAI.decide(y, r)
		if r.action == "forage":
			bad += 1
	check(bad == 0, "노인·다친 사람·일터 있는 어른·아이는 나가지 않는다")
	# 배고픈 사람: 창고가 비었으면 그 앞에서 기다리지 않고 나간다 (둘레에 거둘 것이 있을 때만)
	var hungry: Resident = ys[4]
	hungry.hunger = 2.0
	hungry.last_action = "forage"
	_set_food(y, 0.0)
	ResidentAI.decide(y, hungry)
	check(hungry.action == "forage", "배고픈데 창고가 비었으면 바구니를 들고 나간다 (%s)" % hungry.action)
	var hungry2: Resident = ys[5]
	hungry2.hunger = 2.0
	y.wild_food = 0.0
	ResidentAI.decide(y, hungry2)
	check(hungry2.action == "eat", "둘레에도 거둘 것이 없으면 창고 앞에서 먹을 것을 찾는다 (%s)" % hungry2.action)
	y.wild_food = 10.0 * Balance.FORAGE_LOAD
	y.t = 6.0 * Balance.DAY + 23.0 * Balance.HOUR - fmod(y.start_clock, Balance.DAY)
	var late: Resident = ys[3]
	ResidentAI.decide(y, late)
	check(late.action != "forage", "밤에는 나가지 않는다 (%s)" % late.action)
	var o := _proto()                        # 첫 한 시간: 연장을 다 치워도 나가지 않는다 (첫날 대본 그대로)
	o.stock["도구"] = 0.0
	o.wild_food = 10.0 * Balance.FORAGE_LOAD
	var n_o := 0
	for r: Resident in o.people:
		if r.is_adult():
			ResidentAI.decide(o, r)
			if r.action == "forage":
				n_o += 1
	check(o.in_opening() and n_o == 0 and is_equal_approx(o.wild_food, 10.0 * Balance.FORAGE_LOAD), "첫 한 시간엔 나가지 않는다")


## 한 번 다녀오기: 떠날 때 둘레에서 바구니만큼 잡아 두고 → 숙여 거두고 (gather) → 바구니를 안고 (carry) → 창고에. 도중에 그만두면 되돌린다
func test_forage_trip() -> void:
	var v := _forage_village(0.0, 0.3)
	var loose := _loose(v)
	var r: Resident = loose[0]
	var pool0 := v.wild_food
	var m0 := float(v.stock.get(Balance.FORAGE_ITEM, 0.0))
	check(ResidentAI._forage(v, r), "나갈 수 있다")
	r.action = "forage"
	var spot := Vector2(float(r.steps[0]["x"]), float(r.steps[0]["y"]))
	check(r.steps.size() == 4 and r.steps[0]["k"] == "walk" and r.steps[1]["anim"] == "gather" and is_equal_approx(float(r.steps[1]["left"]), Balance.FORAGE_TIME)
		and spot.distance_to(v.fire) <= Balance.FORAGE_RANGE + 1.3 and not v.water_at(spot.x, spot.y),
		"걸음: 둘레의 들·숲 가(모닥불에서 %.1f칸)로 걸어가 숙여 거두고 창고로" % spot.distance_to(v.fire))
	check(is_equal_approx(v.wild_food, pool0 - Balance.FORAGE_LOAD) and r.carry == "", "떠날 때 둘레의 몫에서 바구니 하나만큼 잡아 둔다")
	var seen := {}
	var from := Vector2(r.x, r.y)
	var jump := 0.0
	var guard := 0
	while float(v.stock.get(Balance.FORAGE_ITEM, 0.0)) <= m0 and guard < 2000:
		guard += 1
		ResidentAI.update(v, r, 30.0)
		jump = maxf(jump, from.distance_to(Vector2(r.x, r.y)))
		from = Vector2(r.x, r.y)
		seen[r.anim + ("+" + r.carry if r.carry != "" else "")] = true
	check(seen.has("walk") and seen.has("gather") and seen.has("carry+" + Balance.FORAGE_ITEM), "모습: 걷기 → 숙여 거두기 → 바구니를 안고 걷기 (%s)" % str(seen.keys()))
	check(jump <= r.walk_speed() * 30.0 * 2.0 + 0.01, "순간 이동 없음 (한 걸음에 가장 멀리 %.2f칸)" % jump)
	check(is_equal_approx(float(v.stock[Balance.FORAGE_ITEM]), m0 + Balance.FORAGE_LOAD) and int(v.stats.get("forage_trips", 0)) == 1
		and is_equal_approx(float(v.stats.get("forage_food", 0.0)), Balance.FORAGE_LOAD),
		"창고에 바구니 하나만큼 (%.0f) — 한 사람 하루치(%.0f)보다 적다" % [Balance.FORAGE_LOAD, Balance.DAY / Balance.FOOD_IV])
	check(guard * 30.0 < 0.3 * Balance.DAY and guard * 30.0 > Balance.FORAGE_TIME, "한 번 다녀오는 데 병 %.1f시간" % (guard * 30.0 / Balance.HOUR))
	# 거두기 전에 그만둠 → 둘레에 되돌림
	var a: Resident = loose[1]
	var pool1 := v.wild_food
	var m1 := float(v.stock[Balance.FORAGE_ITEM])
	check(ResidentAI._forage(v, a) and is_equal_approx(v.wild_food, pool1 - Balance.FORAGE_LOAD), "두 번째 사람도 제 몫을 잡는다")
	ResidentAI.cancel(v, a)
	check(is_equal_approx(v.wild_food, pool1) and is_equal_approx(float(v.stock[Balance.FORAGE_ITEM]), m1) and a.steps.is_empty(), "거두기 전에 그만두면 둘레의 몫이 그대로 돌아온다")
	# 거둔 뒤에 그만둠 → 든 것은 창고로
	var b: Resident = loose[2]
	check(ResidentAI._forage(v, b), "세 번째 사람")
	ResidentAI.run_op(v, b, b.steps[1]["done"])
	b.steps.pop_front()
	b.steps.pop_front()
	check(b.carry == Balance.FORAGE_ITEM and is_equal_approx(b.carry_amt, Balance.FORAGE_LOAD), "거두면 바구니에 (%s %.0f)" % [b.carry, b.carry_amt])
	ResidentAI.cancel(v, b)
	check(is_equal_approx(v.wild_food, pool1 - Balance.FORAGE_LOAD) and is_equal_approx(float(v.stock[Balance.FORAGE_ITEM]), m1 + Balance.FORAGE_LOAD) and b.carry == "",
		"거둔 뒤에 그만두면 든 것은 창고로 (사라지지도 두 번 생기지도 않음)")
	# 둘레에 남은 것이 적을 때
	var c: Resident = loose[3]
	v.wild_food = Balance.FORAGE_LOAD * 0.7
	check(ResidentAI._forage(v, c) and v.wild_food == 0.0 and is_equal_approx(float(c.steps[1]["done"]["amt"]), Balance.FORAGE_LOAD * 0.7), "남은 것이 바구니보다 적으면 남은 만큼만")
	var d: Resident = loose[4]
	v.wild_food = Balance.FORAGE_LOAD * (Balance.FORAGE_LOAD_MIN - 0.1)
	check(not ResidentAI._forage(v, d) and d.steps.is_empty() and is_equal_approx(v.wild_food, Balance.FORAGE_LOAD * (Balance.FORAGE_LOAD_MIN - 0.1)), "반 바구니도 안 되면 나가지 않는다")


## 둘레의 땅이 내는 만큼만: 하루에 forage_day, 거두지 않으면 FORAGE_KEEP_DAYS 날치에서 멈춤, 추운 철엔 덜, 나무가 많으면 조금 더 (상한)
func test_forage_pool() -> void:
	var v := _forage_village(0.0, 0.3)
	var day := v.forage_day()
	check(v.forage_season() == 1.0 and day >= Balance.FORAGE_GROUND and day <= Balance.FORAGE_GROUND + Balance.FORAGE_PER_TREE * Balance.FORAGE_TREES_MAX,
		"첫 빵 전: 철 몫 1 · 하루 %.0f (사람 %.0f명 하루치)" % [day, day / (Balance.DAY / Balance.FOOD_IV)])
	v.wild_food = 0.0
	v._wild_grow(0.25 * Balance.DAY)
	check(is_equal_approx(v.wild_food, day * 0.25), "병 6시간에 하루 몫의 4분의 1")
	v._wild_grow(10.0 * Balance.DAY)
	check(is_equal_approx(v.wild_food, day * Balance.FORAGE_KEEP_DAYS), "거두지 않으면 %.1f날치에서 멈춘다" % Balance.FORAGE_KEEP_DAYS)
	v._wild_grow(0.0)
	v._wild_grow(-5.0)
	check(is_equal_approx(v.wild_food, day * Balance.FORAGE_KEEP_DAYS), "걸음 0·음수는 아무 일 없음")
	# 하루에 거둘 수 있는 것은 둘레가 내는 만큼 — 사람이 아무리 많아도
	var per_head := Balance.DAY / Balance.FOOD_IV
	check(day / per_head < 100.0 and Balance.FORAGE_LOAD < per_head * 0.5, "둘레는 끝없는 사람을 먹이지 못한다 (하루 %.0f명치 · 바구니 하나 = 한 사람 하루의 %.0f%%)" % [day / per_head, 100.0 * Balance.FORAGE_LOAD / per_head])
	# 철: 밭 자람이 가장 낮을 때 FORAGE_WINTER, 1 이상이면 1
	v.stats["first_bread"] = 1
	v._sg_day = int(floor((v.start_clock + v.t) / Balance.DAY))
	v._sg = Balance.SEASON_GROW_MIN
	check(is_equal_approx(v.forage_season(), Balance.FORAGE_WINTER) and is_equal_approx(v.forage_day(), day * Balance.FORAGE_WINTER), "가장 추운 철: 따뜻한 철의 %.0f%%" % (100.0 * Balance.FORAGE_WINTER))
	v._sg = Balance.SEASON_GROW_MAX
	check(v.forage_season() == 1.0, "한여름에도 1을 넘지 않는다")
	v._sg = 0.5 * (Balance.SEASON_GROW_MIN + 1.0)
	check(is_equal_approx(v.forage_season(), 0.5 * (Balance.FORAGE_WINTER + 1.0)), "그 사이는 고르게")
	# 나무: 둘레의 서 있는 나무만, 상한까지
	v._sg = 1.0
	var keep := v.trees.duplicate(true)
	v.trees.clear()
	check(is_equal_approx(v.forage_day(), Balance.FORAGE_GROUND), "나무가 없으면 들이 내는 만큼만")
	for i in Balance.FORAGE_TREES_MAX + 20:
		var tr: Dictionary = (keep[0] as Dictionary).duplicate(true)
		tr["x"] = v.fire.x + 3.0
		tr["y"] = v.fire.y + 0.01 * i
		tr["s"] = "tree"
		v.trees.append(tr)
	check(is_equal_approx(v.forage_day(), Balance.FORAGE_GROUND + Balance.FORAGE_PER_TREE * Balance.FORAGE_TREES_MAX), "나무는 %d그루까지만 센다" % Balance.FORAGE_TREES_MAX)
	for tr: Dictionary in v.trees:
		tr["x"] = v.fire.x + Balance.FORAGE_RANGE + 5.0
	check(is_equal_approx(v.forage_day(), Balance.FORAGE_GROUND), "둘레 밖의 나무는 세지 않는다")
	# 주사위를 쓰지 않는다 (자람)
	var s0 := v.rng.state
	var s1 := v.pop_rng.state
	v._wild_grow(3600.0)
	check(v.rng.state == s0 and v.pop_rng.state == s1, "자람은 주사위를 굴리지 않는다")


## 연대기·말: 숫자·금지어 없음, 한 달에 한 번만. 저장 → 불러오기에 둘레의 몫과 마지막 줄 때가 그대로
func test_forage_words_save() -> void:
	var v := _forage_village(0.0, 0.3)
	var loose := _loose(v)
	var n0 := v.book.size()
	var r: Resident = loose[0]
	check(ResidentAI._forage(v, r), "나감")
	var lines: Array = []
	for i in range(n0, v.book.size()):
		lines.append(String(v.book[i]["text"]))
	check(lines.size() == 1 and String(lines[0]).contains(r.name) and String(lines[0]).contains("바구니"), "연대기 한 줄: %s" % str(lines))
	check(r.say != "" and _bad(lines + [r.say, r.doing]) == "", "연대기·말·하는 일에 숫자·금지어 없음 (%s%s)" % [_bad(lines + [r.say, r.doing]), r.say])
	var n1 := v.book.size()
	var r1: Resident = loose[1]
	check(ResidentAI._forage(v, r1) and v.book.size() == n1, "곧이어 나간 사람은 줄을 더하지 않는다")
	v.t += (Balance.FORAGE_NOTE_DAYS + 0.1) * Balance.DAY
	check(ResidentAI._forage(v, loose[2]) and v.book.size() == n1 + 1, "한 달쯤 뒤엔 다시 한 줄")
	ResidentAI.run_op(v, r1, r1.steps[1]["done"])
	check(_bad([r1.doing]) == "", "돌아오는 길의 하는 일에도 없음 (%s)" % r1.doing)
	var d: Dictionary = bytes_to_var(var_to_bytes(v.to_dict()))
	check(d.has("wild_food") and d.has("forage_note_t") and not d.has("_fg_t") and not d.has("_fg_ok"), "저장에 둘레의 몫과 마지막 줄 때 (세어 둔 값은 넣지 않음)")
	var w := Village.from_dict(d)
	check(is_equal_approx(w.wild_food, v.wild_food) and w.forage_note_t == v.forage_note_t, "불러오면 같은 값 (%.0f)" % w.wild_food)
	d.erase("wild_food")
	d.erase("forage_note_t")
	var o := Village.from_dict(d)
	check(o.wild_food == 0.0 and o.forage_note_t < -1.0e8, "옛 저장 (값 없음) → 빈 둘레에서 다시 자란다")
	o._wild_grow(Balance.DAY)
	check(o.wild_food > 0.0, "옛 저장도 하루 뒤엔 거둘 것이 있다 (%.0f)" % o.wild_food)
