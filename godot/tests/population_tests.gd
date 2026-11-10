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
		"test_two_rate_aging", "test_old_age_rate", "test_little_cap", "test_little_floor", "test_little_floor_pick", "test_little_first_birth", "test_little_save"])


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
