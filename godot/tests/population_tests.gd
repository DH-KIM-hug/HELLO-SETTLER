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
	run.timed(self, ["test_rates", "test_rates_mc", "test_fertile_couples", "test_offline_spare", "test_hints", "test_hint_words", "test_homeless_note"])


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
	check(absf(ratio - Balance.HINT_P) <= 0.05 + 1e-6 and order.size() == carriers.size(), "어른 이주민 %d명 중 조각 %d명 (%.3f, 목표 0.25 ± 0.05) · 사건 %d" % [n, carriers.size(), ratio, order.size()])
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
