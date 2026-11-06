## 이주민 뽑기 (ROADMAP B2 — 기획서 11.2 · BALANCE v3 · SHOP 2.6 · BLOODLINES 5) — tests/run.gd가 부름 (`-- immigrant` = 이것만). 상점 시트를 띄우므로 장면 묶음.
## 값 300 ×1.5 · 하루 5번 · 날이 바뀌면 처음 값 (모든 병 합쳐서) · 2일차에 탭이 열림 · 공개 확률표와 실제 굴림이 맞음 (혼자 60% · 가족 크기 · 등급 · 혈통) ·
## 내려놓으면 주민이 생김 (영역 밖·집 위는 안 됨) · 가족 = 부부 + 아이 (가계도) · 같은 seed = 같은 사람 · 저장 (병 · 거인 묶음) ·
## 비운 동안엔 아무도 오지 않음 · 맞이 (반김 ↑ · 경계 ↓) · 주민 말·연대기에 숫자·금지어 없음, 깨닫기 전엔 거인 이야기 없음 · 밖에서 온 병 (B7: 잠복 → 앓음) · 상점 카드 + 확률 창.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "뽑기", "지폐"]
var TMP_DIR := "user://test_immigrant_save_%d" % OS.get_process_id()

var _old_aware := true
var _old_notes := 0.0
var _old_hand: Array = []
var _old_today := ""


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 이주민 뽑기 (B2)")
	_old_aware = Village.start_aware
	_old_notes = Market.notes
	_old_hand = Market.hand.duplicate(true)
	_old_today = Market.today_override
	Village.start_aware = true
	run.timed(self, ["test_price_and_limit", "test_odds", "test_land", "test_family", "test_same_seed", "test_save", "test_offline",
		"test_reaction", "test_words", "test_disease", "test_ui"])
	Village.start_aware = _old_aware
	Market.reset(_old_notes)
	Market.hand = _old_hand
	Market.today_override = _old_today


func world_lab(seed_v := 20261105) -> Village:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.water.offline = true
	return v


func fresh(notes := 10000.0) -> void:
	Market.reset(notes)
	Market.today_override = "2026-11-07"
	Market.mig_seed = 4242


## 마을 어귀의 빈 땅 (이주민을 내려놓을 수 있는 곳)
func spot(v: Village, from := 4.0) -> Vector2:
	for rr in range(int(from), 30):
		for i in 24:
			var a := TAU * i / 24.0
			var p := v.center + Vector2(cos(a), sin(a)) * rr
			if bool(SkyDrops.preview(v, Immigrants.ITEM, p)["ok"]):
				return p
	return Vector2.INF


## 손에 든 이주민 하나를 내려놓는다 → drop 결과
func drop_one(v: Village, p: Vector2) -> Dictionary:
	var b := Shop.buy(v, Immigrants.ITEM)
	if not bool(b["ok"]):
		return b
	var h := Shop.hand_item(int(b["hand_id"]))
	if not v.air.lid_open:
		v.open_lid()
	Shop.hand_remove(int(h["id"]))
	return SkyDrops.drop(v, Immigrants.ITEM, p, h)


func seed_of_size(n: int, from := 1) -> int:
	for s in range(from, from + 5000):
		if Immigrants.roll(s).size() == n:
			return s
	return -1


func bad_word(texts: Array, no_giant := false) -> String:
	var rx := RegEx.create_from_string("[0-9]")
	for tx: String in texts:
		for w: String in FORBID:
			if tx.contains(w):
				return "'%s' in %s" % [w, tx]
		if rx.search(tx) != null:
			return "숫자 in %s" % tx
		if no_giant and tx.contains("거인"):
			return "'거인' (깨닫기 전) in %s" % tx
	return ""


# ───────────────────────── 값 · 하루 5번 ─────────────────────────
func test_price_and_limit() -> void:
	fresh(10000.0)
	var v := world_lab()
	var u := world_lab(20261107)
	v.shop_open["이주민"] = v.t
	u.shop_open["이주민"] = u.t
	var want := [300.0, 450.0, 675.0, 1013.0, 1519.0]
	var got: Array = []
	var paid := 0.0
	for i in 5:
		var vv := v if i % 2 == 0 else u                      # 두 병이 함께 센다 (거인의 하루)
		got.append(Shop.price(vv, Immigrants.ITEM))
		var r := Shop.buy(vv, Immigrants.ITEM)
		if bool(r["ok"]):
			paid += float(got[i])
		Market.hand.clear()
	check(got == want, "값: 그날 300 · 450 · 675 · 1,013 · 1,519 (%s)" % str(got))
	check(is_equal_approx(Market.notes, 10000.0 - paid) and is_equal_approx(paid, 3957.0), "지폐가 그만큼 줄었다 (%.0f)" % paid)
	var sixth := Shop.can_buy(v, Immigrants.ITEM)
	check(not bool(sixth["ok"]) and String(sixth["why"]).contains("내일") and Immigrants.left_today() == 0, "여섯 번째는 안 됨 (\"%s\") — 하루 5번" % sixth["why"])
	check(not bool(Shop.can_buy(u, Immigrants.ITEM)["ok"]), "다른 병에서도 오늘은 안 됨 (모든 병 합쳐서)")
	Market.today_override = "2026-11-08"
	check(is_equal_approx(Shop.price(v, Immigrants.ITEM), 300.0) and Immigrants.left_today() == 5 and bool(Shop.can_buy(v, Immigrants.ITEM)["ok"]),
		"날이 바뀌면 처음 값 300 · 다시 5번")
	var r2 := Shop.buy(v, Immigrants.ITEM)
	check(bool(r2["ok"]) and is_equal_approx(Shop.price(v, Immigrants.ITEM), 450.0), "새 날 두 번째는 450")
	check(Shop.hand_item(int(r2["hand_id"])).has("seed"), "손에 든 꾸러미에 seed (누가 올지는 놓을 때)")
	# 진열: 1일차엔 '곧', 2일차에 열림 (SHOP 1)
	var w := world_lab(20261109)
	Shop.update_unlocks(w)
	check(not Shop.tab_open(w, "이주민") and String(Shop.card(w, Immigrants.ITEM)["lock"]) == "곧", "1일차: 이주민 탭은 '곧'")
	while w.cal_day(w.t) < 2:
		w.advance(Balance.HOUR)
	Shop.update_unlocks(w)
	check(Shop.tab_open(w, "이주민") and Shop.is_new(w, "이주민"), "2일차: 이주민 탭이 열림 (반짝임)")
	Market.hand.clear()


# ───────────────────────── 공개 확률 = 실제 굴림 ─────────────────────────
func test_odds() -> void:
	var n := 6000 if quick else 30000
	var sizes := {1: 0, 2: 0, 3: 0, 4: 0}
	var people := 0
	var grades := [0, 0, 0, 0, 0]
	var adults := 0
	var good := 0
	var bad := 0
	var kids := 0
	for s in n:
		var plan := Immigrants.roll(hash([s, 77]))
		sizes[plan.size()] += 1
		for q: Dictionary in plan:
			people += 1
			grades[int(q["grade"])] += 1
			if bool(q["child"]):
				kids += 1
				continue
			adults += 1
			for id: String in q["blood"]:
				if Bloodlines.get_def(id).get("good", false):
					good += 1
				else:
					bad += 1
	var so := Immigrants.size_odds()
	var ok_sizes := true
	var msg := ""
	for k: int in sizes:
		var got := float(sizes[k]) / n
		var tol := 3.5 * sqrt(float(so[k]) * (1.0 - float(so[k])) / n) + 0.003
		ok_sizes = ok_sizes and absf(got - float(so[k])) < tol
		msg += "%d명 %.3f/%.3f  " % [k, got, so[k]]
	check(ok_sizes, "몇 명이 오나 — 공개표와 같음 (%s)" % msg)
	check(absf(float(people) / n - 1.6) < 0.05, "한 번에 평균 약 1.6명 (%.2f — BALANCE v3)" % (float(people) / n))
	check(kids > 0 and absf(float(sizes[1]) / n - 0.6) < 0.03, "혼자 60%% · 아이 이주민도 온다 (아이 %d)" % kids)
	var go := Immigrants.grade_odds()
	var ok_g := true
	var gm := ""
	for g in 4:
		var p := float(go[g][1])
		var got := float(grades[g]) / people
		var tol := 3.5 * sqrt(p * (1.0 - p) / people) + 0.002
		ok_g = ok_g and absf(got - p) < tol
		gm += "%s %.4f/%.4f  " % [go[g][0], got, p]
	check(ok_g, "등급 (사람마다) — 기획서 7.2 표와 같음 (%s)" % gm)
	var pg := float(good) / adults
	var pb := float(bad) / adults
	var tb := 3.5 * sqrt(0.1 * 0.9 / adults) + 0.004
	check(absf(pg - Immigrants.BLOOD_GOOD_P) < tb and absf(pb - Immigrants.BLOOD_BAD_P) < tb + 0.01,
		"혈통 (어른마다) 좋은 %.3f · 나쁜 %.3f — 공개표 10%% · 10%%" % [pg, pb])
	# 공개표 자체: 합이 100%, 숫자가 코드 값 그대로
	var s1 := 0.0
	for k: int in so:
		s1 += float(so[k])
	var s2 := 0.0
	for g: Array in go:
		s2 += float(g[1])
	check(is_equal_approx(s1, 1.0) and is_equal_approx(s2, 1.0), "공개표: 사람 수 합 100% · 등급 합 100%")
	var rows := Immigrants.odds_rows()
	var flat := str(rows)
	check(rows.size() == 4 and flat.contains("60%") and flat.contains("24%") and flat.contains("재능") and flat.contains("10%") and flat.contains("0.3%"),
		"공개표 글: 혼자 60% · 둘 24% · 재능 10% · 영웅 0.3% …")
	check(not flat.contains("인종") and flat.contains("능력과는 상관없어요"), "겉모습은 능력과 상관없다고 적음 · 인종 이름 없음")


# ───────────────────────── 내려놓기 ─────────────────────────
func test_land() -> void:
	fresh(5000.0)
	var v := world_lab()
	v.shop_open["이주민"] = v.t
	var n0 := v.people.size()
	var far := v.center + Vector2(v.territory_r() + 6.0, 0.0)
	var pv_far := SkyDrops.preview(v, Immigrants.ITEM, far)
	check(not bool(pv_far["ok"]) and String(pv_far["why"]).contains("마을"), "마을 땅 밖은 안 됨 (\"%s\")" % pv_far.get("why", ""))
	var house: Building = null
	for b in v.buildings:
		if b.is_house():
			house = b
	var pv_h := SkyDrops.preview(v, Immigrants.ITEM, Vector2(house.x, house.y))
	check(not bool(pv_h["ok"]), "집 위는 안 됨 (\"%s\")" % pv_h.get("why", ""))
	var p := spot(v)
	check(p != Vector2.INF, "마을 어귀에 빈 땅이 있다")
	var bk := v.book.size()
	var r := drop_one(v, p)
	var ids: Array = r.get("people", [])
	check(bool(r["ok"]) and ids.size() >= 1 and v.people.size() == n0 + ids.size(), "내려놓으면 주민이 생김 (%d → %d)" % [n0, v.people.size()])
	var near := true
	var src := true
	for id: int in ids:
		var q := v.person(id)
		near = near and q != null and Vector2(q.x, q.y).distance_to(p) < 2.0
		for b: String in q.blood:
			src = src and String(q.blood_src.get(b, "")) in ["migrant", "mother", "father", "new", "grandmother", "grandfather"]
		src = src and q.genes.size() == Genetics.GENE_BYTES
	check(near and src, "내려놓은 자리에 · 겉모습 유전자 · 혈통 출처 '이주해 옴'")
	check(v.book.size() > bk and String(v.book[v.book.size() - 1]["text"]).contains("하늘에서 새"), "연대기: \"%s\"" % v.book[v.book.size() - 1]["text"])
	check(int(v.stats.get("migrants", 0)) == ids.size() and Market.hand.is_empty(), "마을 기록에 이주민 수 · 손에서 빠짐")
	check(v.drops.any(func(d: Dictionary) -> bool: return String(d["item"]) == Immigrants.ITEM), "뗏목 꾸러미가 그 자리에 (사그라듦)")
	v.advance(Immigrants.RAFT_DAYS * Balance.DAY + 120.0)
	check(not v.drops.any(func(d: Dictionary) -> bool: return String(d["item"]) == Immigrants.ITEM), "반나절 뒤 뗏목이 사라짐")
	var alive := ids.all(func(id: int) -> bool: return v.person(id) != null)
	check(alive and v.check_invariants().is_empty(), "이주민이 마을에서 지냄 · 마을 규칙 위반 없음 (%s)" % str(v.check_invariants()))
	var closed := world_lab(20261111)
	closed.shop_open["이주민"] = closed.t
	var b2 := Shop.buy(closed, Immigrants.ITEM)
	var rc := SkyDrops.drop(closed, Immigrants.ITEM, spot(closed), Shop.hand_item(int(b2["hand_id"])))
	check(not bool(rc["ok"]) and String(rc["why"]).contains("뚜껑"), "뚜껑이 닫혀 있으면 내려놓을 수 없다 (병의 법칙)")
	Market.hand.clear()


func test_family() -> void:
	var v := world_lab()
	var sd := seed_of_size(4)
	var p := spot(v)
	v.open_lid()
	var n_m := int(v.stats["marriages"])
	var made := Immigrants.land(v, p, sd)
	check(made.size() == 4, "넷 가족 (seed %d)" % sd)
	var dad := made[0]
	var mom := made[1]
	check(dad.partner == mom.id and mom.partner == dad.id and dad.is_adult() and mom.is_adult(), "부부: %s · %s" % [dad.name, mom.name])
	var kids_ok := true
	for k in [made[2], made[3]]:
		kids_ok = kids_ok and k.is_child() and k.parents.size() == 2 and dad.id in k.parents and mom.id in k.parents
	check(kids_ok, "아이 둘의 부모 = 함께 온 부부 (가계도)")
	check(int(v.stats["marriages"]) == n_m, "이 마을에서 맺은 혼인으로 세지 않음")
	var names := {}
	for q in v.people:
		names[q.name] = int(names.get(q.name, 0)) + 1
	var dup := made.any(func(q: Resident) -> bool: return int(names[q.name]) > 1)
	check(not dup, "이름이 마을 사람과 겹치지 않음 (%s)" % ", ".join(made.map(func(q: Resident) -> String: return q.name)))
	var same_home := mom.home == dad.home and (made[2].home == mom.home or mom.home < 0)
	check(same_home, "한 식구로 집을 얻는다 (빈자리 없으면 모닥불 곁 → 촌장이 짓는다) home %d" % mom.home)
	# 집이 없으면 촌장이 짓는다
	v.chief_off = false
	var had := v.houses().size()
	for i in 24:
		v.advance(Balance.HOUR)
	var all_home := made.all(func(q: Resident) -> bool: return q.home >= 0)
	check(all_home or v.houses().size() + v.buildings.filter(func(b: Building) -> bool: return b.is_site()).size() > had,
		"하루 안에 집을 얻거나 촌장이 집 터를 잡는다")
	var solo := Immigrants.land(v, spot(v), seed_of_size(1))
	check(solo.size() == 1 and solo[0].partner < 0 and solo[0].age >= Balance.AGE_ADULT, "혼자 온 사람은 어른 (짝 없음)")


func test_same_seed() -> void:
	var a := Immigrants.roll(123456)
	var b := Immigrants.roll(123456)
	check(str(a) == str(b), "같은 seed → 같은 사람들 (결정론)")
	var v1 := world_lab()
	var v2 := world_lab()
	var p := spot(v1)
	var m1 := Immigrants.land(v1, p, 98765)
	var m2 := Immigrants.land(v2, p, 98765)
	var same := m1.size() == m2.size()
	for i in mini(m1.size(), m2.size()):
		same = same and m1[i].name == m2[i].name and m1[i].grade == m2[i].grade and m1[i].genes == m2[i].genes and m1[i].blood == m2[i].blood
	check(same, "같은 마을 · 같은 seed → 같은 이름·등급·겉모습·혈통")
	v1.advance(Balance.HOUR * 3)
	v2.advance(Balance.HOUR * 3)
	check(v1.people.size() == v2.people.size() and v1.rng.state == v2.rng.state, "그 뒤 흐름도 같다")


# ───────────────────────── 저장 ─────────────────────────
func test_save() -> void:
	var v := world_lab()
	var made := Immigrants.land(v, spot(v), seed_of_size(3))
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	var kid := w.person(made[2].id)
	check(kid != null and kid.parents == made[2].parents and w.person(made[0].id).partner == made[1].id and w.migrants.get("kind", "") == v.migrants["kind"],
		"병 저장: 이주민 · 가계도 · 맞이 상태가 그대로")
	check(w.person(made[0].id).blood == made[0].blood and w.person(made[0].id).genes == made[0].genes and int(w.stats["migrants"]) == 3, "혈통 · 유전자 · 이주민 수 그대로")
	# 거인 묶음 (그날 횟수 · seed · 손에 든 꾸러미)
	var dir := ProjectSettings.globalize_path(TMP_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var sm := GameSave.new()
	sm.dir = TMP_DIR
	sm.start()
	fresh(3000.0)
	var u := world_lab(20261113)
	u.shop_open["이주민"] = u.t
	sm.register_jar(1, u, JarClock.new(u))
	sm.save_all(true)
	Shop.buy(u, Immigrants.ITEM)
	Shop.buy(u, Immigrants.ITEM)
	var h_seed := int(Market.hand[1]["seed"])
	var g := SaveFile.read_best(dir + "/giant.dat")
	var dr: Dictionary = g["payload"].get("draws", {}) if g["ok"] else {}
	check(g["ok"] and int(dr.get("n", 0)) == 2 and String(dr.get("day", "")) == "2026-11-07" and int(dr.get("seed", 0)) == 4242,
		"사면 곧바로 저장: 그날 횟수 2 · 날짜 · seed (%s)" % str(dr))
	Market.reset(0.0)
	Market.today_override = "2026-11-07"
	sm.load_all()
	check(Immigrants.today_count() == 2 and is_equal_approx(Shop.price(u, Immigrants.ITEM), 675.0) and Market.hand.size() == 2 and int(Market.hand[1]["seed"]) == h_seed,
		"불러오면: 오늘 2번 (다음 675) · 손에 꾸러미 둘 (seed 그대로)")
	sm.stop()
	sm.free()
	var da := DirAccess.open(dir)
	if da != null:
		for f in da.get_files():
			da.remove(f)
	Market.hand.clear()


# ───────────────────────── 비운 동안 ─────────────────────────
func test_offline() -> void:
	fresh(2000.0)
	var v := world_lab()
	v.shop_open["이주민"] = v.t
	Shop.buy(v, Immigrants.ITEM)
	var ids := {}
	for q in v.people:
		ids[q.id] = true
	v.watching = false
	v.advance(Balance.DAY)
	var newcomers := v.people.filter(func(q: Resident) -> bool: return not ids.has(q.id) and q.parents.is_empty())
	check(newcomers.is_empty() and int(v.stats.get("migrants", 0)) == 0 and Market.hand.size() == 1,
		"비운 동안엔 아무도 오지 않는다 — 손에 든 꾸러미는 그대로")
	Market.hand.clear()


# ───────────────────────── 맞이 ─────────────────────────
func test_reaction() -> void:
	var v := world_lab()
	for q in v.people:
		q.belief = 0.95
	v._update_belief(0.0)
	var h0 := v.avg_happiness()
	v._update_happiness()
	h0 = v.avg_happiness()
	Immigrants.land(v, spot(v), seed_of_size(1))
	v._update_happiness()
	var olds := v.people.filter(func(q: Resident) -> bool: return not q.id in v.migrants["ids"])
	var h1 := 0.0
	for q: Resident in olds:
		h1 += q.happiness
	h1 /= olds.size()
	check(String(v.migrants["kind"]) == "welcome" and h1 > h0 + 0.03, "믿음 높은 마을: 축제처럼 맞이 — 행복 ↑ (%.3f → %.3f)" % [h0, h1])
	var w := world_lab()
	for q in w.people:
		q.belief = 0.1
	w._update_belief(0.0)
	w._update_happiness()
	var g0 := w.avg_happiness()
	Immigrants.land(w, spot(w), seed_of_size(1))
	w._update_happiness()
	var g1 := 0.0
	var wo := w.people.filter(func(q: Resident) -> bool: return not q.id in w.migrants["ids"])
	for q: Resident in wo:
		g1 += q.happiness
	g1 /= wo.size()
	check(String(w.migrants["kind"]) == "wary" and g1 < g0 - 0.02, "믿음 낮은 마을: 경계 — 행복 잠깐 ↓ (%.3f → %.3f)" % [g0, g1])
	w.t += Immigrants.MOOD_DAYS * Balance.DAY + 1.0
	check(Immigrants.mood(w) == 0.0, "맞이의 들뜸·경계는 하루 뒤 잦아듦")


# ───────────────────────── 말 ─────────────────────────
func test_words() -> void:
	var texts: Array = []
	for aw: bool in [true, false]:
		for fam: bool in [true, false]:
			texts.append(Immigrants.newcomer_line(aw, fam))
			for kind: String in ["welcome", "wary", "unaware"]:
				texts.append(Immigrants.book_line(aw, kind, PackedStringArray(["브루노", "아다", "에밀"]) if fam else PackedStringArray(["클라라"]), fam))
	for kind: String in Immigrants.VILLAGE_SAY:
		texts.append_array(Immigrants.VILLAGE_SAY[kind])
	var bw := bad_word(texts)
	check(bw == "", "주민 말·연대기에 숫자·금지어 없음 %s" % bw)
	var un: Array = [Immigrants.newcomer_line(false, true), Immigrants.newcomer_line(false, false), Immigrants.book_line(false, "unaware", PackedStringArray(["클라라"]), false)]
	un.append_array(Immigrants.VILLAGE_SAY["unaware"])
	check(bad_word(un, true) == "", "깨닫기 전: 거인 이야기 없음 %s" % bad_word(un, true))
	# 실제로 깨닫기 전 마을에 내려놓기
	Village.start_aware = false
	var v := world_lab(20261115)
	Village.start_aware = true
	check(not v.aware, "깨닫기 전 마을")
	var bk := v.book.size()
	var w0 := v.wonder
	var made := Immigrants.land(v, spot(v), seed_of_size(3))
	var said: Array = []
	for q in v.people:
		if q.say != "":
			said.append(q.say)
	var lines: Array = v.book.slice(bk).map(func(e: Dictionary) -> String: return String(e["text"]))
	said.append_array(lines)
	check(not lines.is_empty() and bad_word(said, true) == "" and String(v.migrants["kind"]) == "unaware",
		"깨닫기 전 실제 연대기·말: \"%s\" %s" % [lines[0] if not lines.is_empty() else "", bad_word(said, true)])
	check(v.wonder > w0 and made.all(func(q: Resident) -> bool: return q.belief == 0.0), "목격 → 경이 · 아직 아무도 거인을 믿지 않는다")
	check(Immigrants.book_line(true, "welcome", PackedStringArray(["브루노", "아다"]), true).contains("브루노와 아다"), "이름 잇기: '브루노와 아다'")


# ───────────────────────── 밖에서 온 병 (B7 — WORLD_EVENTS 5 · HEALTH 2.6) ─────────────────────────
func test_disease() -> void:
	var v := world_lab(20261117)
	var n := 0
	var by := {}
	for k in 60:
		var made: Array[Resident] = []
		for i in 40:
			var r := Resident.new()
			r.id = 100000 + k * 40 + i
			made.append(r)
		Immigrants.carry_disease(v, made)
		for r in made:
			n += 1
			if r.latent != "":
				by[r.latent] = int(by.get(r.latent, 0)) + 1
	var pf := float(by.get("열병", 0)) / n
	var pp := float(by.get(Balance.PLAGUE, 0)) / n
	var want_f := Balance.MIGRANT_FEVER_P * Balance.MIGRANT_FEVER_LANDS
	print("  이주민 %d명: 열병 %.4f (기대 %.4f) · 역병 %.4f (기대 0.01)" % [n, pf, want_f, pp])
	check(pf > want_f * 0.4 and pf < want_f * 1.8 and pp > 0.004 and pp < 0.02, "이주민이 지니고 오는 병: 열병(열병이 사는 기후에서 온 사람의 5%%) · 역병 1%% — 드물다")
	# 실제로 내려놓은 사람이 병을 지니면: 하루 잠복 (창백한 얼굴빛 — 아프지도 옮기지도 않음) → 앓기 시작
	var w := world_lab(20261118)
	var made2 := Immigrants.land(w, spot(w), seed_of_size(2))
	var carrier: Resident = made2[0]
	carrier.latent = ""
	Health.make_latent(w, carrier, Balance.PLAGUE)
	check(carrier.latent == Balance.PLAGUE and carrier.sick_left <= 0.0 and carrier.immune.is_empty(), "내려온 사람: 잠복 중 · 이 마을이 겪은 병의 면역은 없다")
	w.advance(0.5 * Balance.DAY)
	check(carrier.sick_left <= 0.0 and not w.outbreaks.has(Balance.PLAGUE), "잠복 동안은 앓지도 옮기지도 않는다")
	w.advance(0.6 * Balance.DAY)
	check(carrier.disease == Balance.PLAGUE and w.outbreaks.has(Balance.PLAGUE), "하루 뒤 역병이 시작된다 ('%s')" % str(w.outbreaks.get(Balance.PLAGUE, {}).get("name", "")))
	var bw := bad_word(w.book.slice(w.book.size() - 6).map(func(e: Dictionary) -> String: return String(e["text"])))
	check(not bw.contains("상점") and not bw.contains("뽑기"), "연대기에 금지어 없음 %s" % bw)


# ───────────────────────── 화면 ─────────────────────────
func test_ui() -> void:
	fresh(1000.0)
	var v := world_lab()
	Shop.update_unlocks(v)
	v.shop_open["이주민"] = v.t
	var sh := ShopSheet.new()
	run.root.add_child(sh)
	sh.setup(v)
	sh.open()
	sh.select_tab("이주민")
	var cards := sh.cards()
	check(cards.size() == 1 and String(cards[0]["name"]) == Immigrants.ITEM and (cards[0]["btn"] as Button).text == "300", "이주민 카드: 값 300")
	check(not bool(sh.odds_visible()), "확률 창은 처음엔 닫힘")
	var ob: Button = null
	for b in sh.find_children("*", "Button", true, false):
		if (b as Button).text == "확률 보기":
			ob = b
	check(ob != null, "카드에 [확률 보기]")
	if ob != null:
		ob.pressed.emit()
	var tx := sh.odds_text()
	check(sh.odds_visible() and tx.contains("혼자") and tx.contains("60%") and tx.contains("재능") and tx.contains("300 → 450 → 675 → 1,013 → 1,519"),
		"확률 창: 혼자 60% · 등급 · 값 300 → … → 1,519")
	sh.hide_odds()
	sh.press(Immigrants.ITEM)
	sh._sig = ""
	sh._refresh()
	check(Market.hand.size() == 1 and (sh.cards()[0]["btn"] as Button).text == "450", "사면 손에 · 다음 값 450")
	sh.close()
	run.root.remove_child(sh)
	sh.free()
	var ic := GameIcons.tex(Immigrants.ITEM)
	var raft := SkyDropView.make_item(Immigrants.ITEM)
	check(ic != null and raft.get_child_count() > 6, "손 칸 아이콘 · 뗏목 꾸러미 모형")
	raft.free()
	Market.hand.clear()
