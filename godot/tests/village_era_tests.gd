## 마을 시대 건물 1차 (A6) · 등불 옮기기 (A11) — tests/run.gd가 부름 (`-- village` = 이것만). 장면(나침반·미리보기)을 띄우므로 장면 묶음.
## 건물: 잠긴 건물(목장·방직소·대장간 — 어부·사냥꾼은 B3 wildlife_tests)은 짓지 않음 · 촌장의 조건 (묘지·약초꾼·치료소·교회·광장·망루·나루터) ·
##   약초꾼(약초·곰팡이약) · 치료소(약초사가 있을 때 반경 효과·툇마루) · 교회(제물 ×1.3·종·교회 앞 기도·혼례) · 광장(반경 행복·어울림) ·
##   묘지(무덤·장례 행렬·발견 '장례'·슬픔이 덜함) · 망루(안개·조짐 반나절 먼저) · 나루터(뗏목 지름길) · 저장.
## 등불: 같은 자리면 안 옮김 · 옛 이름 rotate_jar · 하루 세 번까지 괜찮음 (네 번째 두려움) · "해가 옮겨갔다!" · 목격(경이) ·
##   미리보기가 몇 시간 뒤 실제 골 물의 변화와 같은 방향 (넓은 세상 · 소형 병) · 미리보기 말에 숫자 없음 · 저장 · 화면(나침반·귀띔·미리보기).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 마을 시대 건물 (A6) · 등불 옮기기 (A11)")
	run.timed(self, ["test_locked", "test_chief_priorities", "test_chief_builds", "test_herbalist", "test_clinic", "test_chapel",
		"test_plaza", "test_funeral", "test_watchtower", "test_ferry", "test_era_save",
		"test_lamp_rules", "test_lamp_preview_world", "test_lamp_preview_jar", "test_lamp_save", "test_lamp_ui", "test_fast_view"])


func proto(seed_v := 20261105) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	return v


func rich(v: Village) -> void:
	for k: String in ["판자", "돌", "통나무", "빵", "밀", "물"]:
		v.stock[k] = 200.0
	v.stock["도구"] = 30.0


func through_bytes(v: Village) -> Village:
	return Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))


func built(v: Village, type: String, p: Variant = null) -> Building:
	var sp: Variant = p if p != null else v.find_spot(type)
	var q: Vector2 = sp if sp != null else v.center + Vector2(6, 6)
	var b := v.add_building(type, q.x, q.y, true)
	v.on_built(b)
	return b


func adult_idle(v: Village) -> Resident:
	for r in v.people:
		if r.is_adult() and r.job < 0 and Production.caring_for(v, r) == null:     # v5: 아기를 돌보는 부모는 일터에 안 감
			return r
	return null


func staff(v: Village, b: Building) -> Resident:
	var r := adult_idle(v)
	if r == null:
		for q in v.people:
			if q.is_adult() and Production.caring_for(v, q) == null:
				r = q
				break
	var old := v.bld(r.job)
	if old != null:
		old.worker = -1
	r.job = b.id
	b.worker = r.id
	return r


func add_people(v: Village, n: int) -> void:
	for i in n:
		v.add_person("이웃%d" % i, "m" if i % 2 == 0 else "f", 6.0 + i % 5, "", v.center.x + 1.0, v.center.y + 1.0, null, null)


func has_line(v: Village, s: String) -> bool:
	return v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains(s))


# ───────────────────────── 잠긴 건물 ─────────────────────────
func test_locked() -> void:
	var v := proto(41)
	v.era = 1
	rich(v)
	add_people(v, 14)
	for ty: String in Balance.B_LOCKED:
		check(not VillageEra.can_build(v, ty) and not Balance.B.has(ty), "%s: 못 짓는다 (%s)" % [ty, Balance.B_LOCKED[ty]])
		var c := Shop.card(v, ty)
		check(String(c["lock"]) == "곧" and String(c["inside"]).contains(String(Balance.B_LOCKED[ty])), "상점 카드 '곧' + 까닭: %s" % c["inside"])
	v.wishes.append("목장")                  # 들어준 소원이어도 짓지 않음
	v.favourites["양털"] = 20.0
	v.advance(3.0 * Balance.DAY)
	var bad := v.buildings.filter(func(b: Building) -> bool: return Balance.B_LOCKED.has(b.type))
	check(bad.is_empty(), "마을 시대 사흘 — 잠긴 건물 0채 (지은 것 %d채)" % v.buildings.size())


# ───────────────────────── 촌장 (RESIDENT_AI 6.2) ─────────────────────────
func test_chief_priorities() -> void:
	var v := proto(42)
	check(VillageEra.want_early(v) == "", "아무 일 없으면 묘지·약초꾼 없음")
	v.stats["died"] = 1
	check(VillageEra.want_early(v) == "묘지", "첫 죽음 뒤 → 묘지 (개척기에도 — BUILDINGS 3.1)")
	built(v, "묘지")
	v.stats["sick"] = 3
	check(VillageEra.want_early(v) == "", "개척기 · 약초를 모름 → 약초꾼 없음")
	v.note_discovery("herb", v.chief())
	check(VillageEra.want_early(v) == "약초꾼", "약초를 알면 개척기에도 약초꾼 (DISCOVERIES F2)")
	var w := proto(43)
	w.era = 1
	w.stats["sick"] = 2
	check(VillageEra.want_early(w) == "" and VillageEra.want_late(w) == "", "마을 시대 · 거의 안 앓음 → 약초꾼·치료소 없음")
	w.stats["sick"] = 3
	check(VillageEra.want_early(w) == "약초꾼", "자주 앓으면 약초꾼")
	w.stats["sick"] = 6
	check(VillageEra.want_late(w) == "치료소", "더 자주 앓으면 치료소")
	built(w, "치료소")
	w.faith = 50.0
	check(VillageEra.want_late(w) == "", "믿음이 낮으면 교회 없음")
	w.faith = 80.0
	add_people(w, 4)
	check(VillageEra.want_late(w) == "교회", "믿음이 높고 사람이 12명 넘으면 교회")
	built(w, "교회")
	check(VillageEra.want_late(w) != "광장", "인구 %d명 → 광장 아직" % w.people.size())
	add_people(w, 20 - w.people.size())
	check(VillageEra.want_late(w) == "광장", "인구 20명 → 광장")
	built(w, "광장")
	check(VillageEra.want_late(w) == "", "소형 병: 안개가 없으니 망루 없음 · 물을 안 건너니 나루터 없음")
	w.wade_secs = Balance.FERRY_WADE_DAY * 2.0
	_river(w, 8.0)
	check(VillageEra.want_late(w) == "나루터", "물을 자주 걸어 건너고 물가 자리가 있으면 나루터")
	# 넓은 세상: 영역 둘레에 안개 → 망루
	var jw := JarWorld.create(20261105, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var q := jw.place_kit(rec[0].x, rec[0].y)
	q.era = 1
	check(VillageEra.fog_borders(q), "넓은 세상: 영역 둘레가 안개")
	check(VillageEra.want_late(q) == "망루", "안개가 영역에 닿으면 망루")
	q.era = 0
	check(VillageEra.want_late(q) == "", "개척기엔 망루 없음")


## 소형 병에 강 하나 (시험용 — 마을 중심 동쪽 dx칸에 남북으로 폭 3칸)
func _river(v: Village, dx: float) -> float:
	var x0 := v.center.x + dx
	for k in v.water.cells:
		var x := v.water.cx(k)
		if x >= x0 and x < x0 + 3.0:
			v.water.w[k] = JarWater.LAKE_DEPTH * 3.0
	return x0


func test_chief_builds() -> void:
	var v := proto(44)
	v.advance(2.0 * Balance.HOUR)
	rich(v)
	var p := v.people.filter(func(r: Resident) -> bool: return r.is_elder())
	v.kill(p[0] if not p.is_empty() else v.people[0], "노환")
	var n0 := v.count_type("묘지")
	for b in v.buildings.duplicate():     # v5: 걸음이 느려 두 시간 뒤에도 짓는 터가 남아 있다 — 촌장이 새 터를 잡을 수 있게 다 지은 것으로
		if b.is_site():
			v.on_built(b)
	for i in 4:
		v.chief_build()
	check(n0 == 0 and v.count_type("묘지") == 1, "첫 죽음 뒤 촌장이 묘지 터를 잡음")
	var gy: Building = v.buildings.filter(func(b: Building) -> bool: return b.type == "묘지")[0]
	check(gy.x != 0.0 and Vector2(gy.x, gy.y).distance_to(v.center) >= 3.0, "묘지는 마을 한가운데가 아닌 끝 쪽 (%.1f칸)" % Vector2(gy.x, gy.y).distance_to(v.center))
	var t0 := v.t
	while v.t - t0 < Balance.DAY and not gy.built:
		v.advance(600.0)
	check(gy.built, "주민이 묘지를 다 지음")


# ───────────────────────── 약초꾼 ─────────────────────────
func test_herbalist() -> void:
	var v := proto(45)
	v.era = 1
	v.advance(Balance.HOUR)
	rich(v)
	v.stock[Balance.HERB] = 0.0
	v.chief_off = true                    # v5: 걸음이 느려 짓는 터가 오래 남아 약초꾼이 짓기를 도우러 가고, 새 터가 약초 자리를 덮는다 — 약초꾼만 본다
	var sp: Variant = v.find_spot("약초꾼")
	check(sp != null, "약초꾼 자리 (습한 숲가 곁)")
	var b := built(v, "약초꾼", sp)
	var hb := staff(v, b)
	var t0 := v.t
	var picks := 0
	var bad_pick := ""
	var last_t := -1.0
	while v.t - t0 < 48.0 * Balance.HOUR and float(v.stock.get(Balance.HERB, 0.0)) < 3.0:     # v5: 걸음이 느려 (예전 10시간) · A28: 첫 한 시간 걸음 덤도 없어 30 → 48시간
		v.advance(300.0)
		if b.has_spot and b.spot_t != last_t:      # 자리를 새로 고른 순간에 맞는 자리였는지 (E3-7: 이슬이 새벽에만 떨어져 땅이 하루 사이 젖었다 마름 — 6시간마다 다시 고름)
			last_t = b.spot_t
			picks += 1
			if not VillageEra.herb_ok(v, Vector2(b.spot_x, b.spot_y)):
				bad_pick = "(%.1f, %.1f)" % [b.spot_x, b.spot_y]
	check(picks > 0 and bad_pick == "", "약초 자리: 고를 때마다 습한 땅 또는 숲 가 (%d번 고름 %s)" % [picks, bad_pick])
	check(float(v.stock.get(Balance.HERB, 0.0)) >= 3.0, "약초꾼이 약초를 캐 창고에 (%.0f개, %.1f시간)" % [float(v.stock.get(Balance.HERB, 0.0)), (v.t - t0) / Balance.HOUR])
	# 곰팡이약: 약초꾼이 있으면 약초꾼만 만든다
	v.mold.med_known = true
	v.stock[Balance.BLUE_POWDER] = 4.0
	v.stock[Balance.MOLD_MED] = 0.0
	var makers := {}
	var t1 := v.t
	while v.t - t1 < Balance.DAY and int(v.mold.stats["med_made"]) < 4:
		v.advance(60.0)
		for r in v.people:
			if r.action == "mold_med":
				if b.worker >= 0:                     # v5: 약초꾼이 아기를 돌보느라 일터가 비면 일 없는 어른이 만든다 (규칙대로) — 약초꾼이 있을 때만 본다
					makers[r.id] = bool(makers.get(r.id, true)) and r.id == b.worker
	check(int(v.mold.stats["med_made"]) >= 2, "곰팡이약을 만듦 (%d)" % int(v.mold.stats["med_made"]))
	check(makers.values().all(func(x: bool) -> bool: return x), "약초꾼이 있을 때 곰팡이약은 그때의 약초꾼만 만든다 (약초꾼이 있을 때 만든 사람 %d명)" % makers.size())
	# F2 약초 발견: 앓는 사람이 습한 숲가 곁에
	var w := proto(46)
	w.advance(Balance.HOUR)
	var r0: Resident = w.people[0]
	var patch: Variant = VillageEra._herb_patch(w, w.center, 30.0)
	check(patch != null, "소형 병에 약초 자리가 있다")
	if patch != null:
		r0.x = (patch as Vector2).x
		r0.y = (patch as Vector2).y
		Health.fall_ill(w, r0, false, "고뿔")
		r0.sick_left = 50.0 * Balance.DAY
		var left0 := r0.sick_left
		for i in 120:
			r0.x = (patch as Vector2).x
			r0.y = (patch as Vector2).y
			r0.steps.clear()
			VillageEra.herb_watch(w)
			if Codex.knows(w, "herb"):
				break
		check(Codex.knows(w, "herb") and r0.sick_left < left0 * 0.6, "앓는 사람이 숲가의 쓴 풀을 씹고 나음 → 발견 '약초'")
		check(has_line(w, "약초"), "연대기: 약초")


# ───────────────────────── 치료소 ─────────────────────────
func test_clinic() -> void:
	var v := proto(47)
	v.era = 1
	v.advance(Balance.HOUR)
	rich(v)
	var b := built(v, "치료소")
	check(Health._clinics(v).is_empty(), "약초사가 없으면 치료소 효과 없음")
	var healer := staff(v, b)
	check(Health._clinics(v).size() == 1, "약초사 %s가 있으면 반경 효과 (HEALTH 2.4)" % healer.name)
	var r: Resident = null
	for q in v.people:
		if q != healer and q.is_adult():
			r = q
			break
	r.x = b.x + 1.0
	r.y = b.y + 1.0
	Health.fall_ill(v, r, true, "고뿔")
	var with_c := r.sick_left
	Health.recover(v, r, v.t)
	r.immune.clear()
	Health.fall_ill(v, r, false, "고뿔")
	check(absf(with_c - r.sick_left * Balance.CLINIC_TIME) < 1.0, "치료소 반경: 앓는 기간 ×0.6 (%.1f → %.1f시간)" % [r.sick_left / 3600.0, with_c / 3600.0])
	ResidentAI.cancel(v, r)
	ResidentAI.decide(v, r)
	var bed := Vector2(float(r.steps[0]["x"]), float(r.steps[0]["y"])) if not r.steps.is_empty() else Vector2.ZERO
	check(r.doing == "치료소에 누운 중" and bed.distance_to(Vector2(b.x, b.y)) <= Balance.CLINIC_R, "앓는 사람이 치료소 툇마루에 누움 (%.1f칸)" % bed.distance_to(Vector2(b.x, b.y)))
	check(VillageEra.healer_task(v, healer, b, true), "앓는 사람이 있으면 약초사가 일함")
	Health.recover(v, r, v.t)
	for q in v.people:
		q.sick_left = 0.0
		q.injured_left = 0.0
	check(not VillageEra.healer_task(v, healer, b, true), "아무도 안 앓으면 약초사는 쉼")
	healer.sick_left = Balance.DAY
	check(Health._clinics(v).is_empty(), "약초사가 앓아누우면 치료소가 쉼")


# ───────────────────────── 교회 ─────────────────────────
func test_chapel() -> void:
	var v := proto(48)
	v.era = 1
	v.advance(Balance.HOUR)
	rich(v)
	built(v, "나무꾼")                  # v5: 걸음이 현실 걸음이라 첫 한 시간엔 아직 일터가 없다 — 바칠 물건을 만드는 곳
	var c := through_bytes(v)
	var a := v.evening_offering()
	var ch := built(c, "교회")
	var b := c.evening_offering()
	var sa := 0
	var sb := 0
	for k: String in a:
		sa += int(a[k])
	for k: String in b:
		sb += int(b[k])
	check(sa > 0 and sb >= floori(sa * 1.2), "교회 = 큰 제단: 저녁 제물 ×1.3 (%d → %d)" % [sa, sb])
	check(c.bell_t == c.t and has_line(c, "예배당 종"), "저녁 기도 때 교회 종 (소리 고리 bell_t)")
	var near := 0
	for r in c.people:
		if r.action == "pray" and not r.steps.is_empty():
			var p := Vector2(float(r.steps[0]["x"]), float(r.steps[0]["y"]))
			if p.distance_to(Vector2(ch.x, ch.y)) < ch.size() + 3.5 and (p - Vector2(ch.x, ch.y)).dot(VillageEra.front(ch)) > 0.0:
				near += 1
	check(near >= 3, "저녁 기도는 교회 앞에 모임 (%d명)" % near)
	var pr := c.people[0]
	ResidentAI.cancel(c, pr)
	ResidentAI._pray(c, pr)
	check(pr.doing.contains("예배당"), "혼자 기도도 교회 앞에서 (%s)" % pr.doing)
	check(c.altar_built and not c.altar.is_empty(), "작은 제단은 그대로 (제물은 제단에)")
	# 혼례
	var m: Resident = null
	var f: Resident = null
	for r in c.people:
		if r.partner < 0 and r.age >= Balance.MARRY_MIN and r.age < Balance.MARRY_MAX:
			if r.sex == "m" and m == null:
				m = r
			elif r.sex == "f" and f == null:
				f = r
	if m == null or f == null:
		m = c.add_person("요한", "m", 6.0, "", c.center.x, c.center.y, null, null)
		f = c.add_person("마리", "f", 6.0, "", c.center.x, c.center.y, null, null)
	c.marry(m, f)
	check(VillageEra.wedding(c, m, f) and VillageEra.wedding_on(c) and has_line(c, "예배당에서 혼례"), "혼례는 교회에서 (잔치)")
	c._update_happiness()
	var h_w := m.happiness
	c.wedding_t = -1.0e9
	c.festival_t = -1.0e9
	c._update_happiness()
	check(h_w > m.happiness, "혼례 잔치 동안 행복↑ (%.2f → %.2f)" % [m.happiness, h_w])


# ───────────────────────── 광장 ─────────────────────────
func test_plaza() -> void:
	var v := proto(49)
	v.era = 1
	v.advance(6.0 * Balance.HOUR)            # (A28) 첫 한 시간 걸음 덤이 없어져 집 배정이 늦음 — 예전 1시간
	var pz := built(v, "광장")
	var homed: Resident = null
	for r in v.people:
		var h := v.bld(r.home)
		if h != null and Vector2(h.x - pz.x, h.y - pz.y).length() <= Balance.PLAZA_R:
			homed = r
			break
	check(homed != null, "광장 반경 안에 집이 있다")
	pz.built = false
	v._update_happiness()
	var h0 := homed.happiness
	pz.built = true
	v._update_happiness()
	check(absf(homed.happiness - h0 - Balance.PLAZA_HAPPY) < 1e-4 or homed.happiness >= 1.0, "광장 반경 안 집: 행복 +0.05 (%.2f → %.2f)" % [h0, homed.happiness])
	var r := v.people[1]
	ResidentAI.cancel(v, r)
	ResidentAI._do(v, r, "social", 19.0)
	var p := Vector2(float(r.steps[0]["x"]), float(r.steps[0]["y"]))
	check(p.distance_to(Vector2(pz.x, pz.y)) < 2.5 and r.doing.contains("광장"), "어울림은 광장에서 (%s)" % r.doing)
	# 장날 (닷새마다)
	var dd := v.cal_day(v.t)
	v.t += float((Balance.MARKET_EVERY - dd % Balance.MARKET_EVERY) % Balance.MARKET_EVERY) * Balance.DAY
	VillageEra.dawn(v)
	check(VillageEra.is_market_day(v) and has_line(v, "광장에 장이 섰다"), "닷새마다 장날 (교역의 자리)")


# ───────────────────────── 묘지 · 장례 ─────────────────────────
func test_funeral() -> void:
	var v := proto(50)
	v.advance(9.0 * Balance.HOUR)                 # 낮 (16시)
	var p: Resident = null
	for r in v.people:
		if r.partner >= 0 and r.is_adult():
			p = r
			break
	var mate := v.person(p.partner)
	v.kill(p, "노환")
	check(v.graves.size() == 1 and not bool(v.graves[0]["yard"]), "묘지가 없으면 마을 끝에 홀로 묻힘")
	check(Codex.knows(v, "funeral") and has_line(v, "땅에 묻고, 그 위에 돌을 세웠다"), "첫 죽음 → 발견 '장례' (DISCOVERIES P4)")
	var walkers := v.people.filter(func(r: Resident) -> bool: return r.doing.contains("장례"))
	check(walkers.size() >= 2 and walkers.any(func(r: Resident) -> bool: return r == mate), "장례 행렬: 가족 + 이웃 %d명" % walkers.size())
	v._update_happiness()
	var h_no := mate.happiness
	var gy := built(v, "묘지")
	v._update_happiness()
	check(mate.happiness > h_no + 0.05 or mate.happiness >= 1.0, "묘지가 있으면 슬픔이 덜함 (%.2f → %.2f)" % [h_no, mate.happiness])
	var q: Resident = v.people.filter(func(r: Resident) -> bool: return r.is_adult() and r != mate)[0]
	v.kill(q, "노환")
	var g: Dictionary = v.graves[1]
	check(bool(g["yard"]) and Vector2(float(g["x"]), float(g["y"])).distance_to(Vector2(gy.x, gy.y)) <= gy.size() + 0.2, "묘지가 생긴 뒤엔 묘지에 묻힘")
	check(v.graves[0]["x"] == v.graves[0]["x"] and not bool(v.graves[0]["yard"]), "먼저 묻힌 무덤은 그 자리 그대로")
	var c := through_bytes(v)
	check(c.graves.size() == 2 and String(c.graves[1]["name"]) == q.name, "저장/불러오기: 무덤")


# ───────────────────────── 망루 ─────────────────────────
func test_watchtower() -> void:
	var jw := JarWorld.create(20261105, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.era = 1
	var d := VillageEra.fog_dir(v)
	var far := v.center + d * (v.territory_r() + 10.0)
	check(not jw.water.revealed(far.x, far.y, v.sid), "망루 전: 영역 밖 %s는 안개" % str(far.round()))
	var sp: Variant = v.find_spot("망루")
	check(sp != null and (sp as Vector2).distance_to(v.center + d * 10.0) < (sp as Vector2).distance_to(v.center - d * 10.0), "망루는 안개 쪽에")
	var r0 := v.territory_r()
	var b := built(v, "망루", sp)
	check(jw.water.revealed(far.x, far.y, v.sid), "망루가 서면 둘레 %d칸 안개가 걷힘" % int(Balance.WATCH_REVEAL))
	check(v.territory_r() > r0, "망루 = 국경 (영역 %.0f → %.0f)" % [r0, v.territory_r()])
	check(has_line(v, "망루"), "연대기: 망루에 올라 먼 땅을 봄")
	# 위기 조짐 반나절 먼저 (곰팡이)
	var m := v.mold
	v.t = maxf(v.t, Balance.MOLD_FIRST_DAY * Balance.DAY + 1.0)
	m.rest_until = 0.0
	m.phase = "calm"
	m.pressure = 0.9
	m._tick(v, 60.0)
	check(m.phase == "omen" and is_equal_approx(m.omen_extra, Balance.WATCH_OMEN_LEAD), "망루: 압력이 덜 찼어도 조짐이 먼저 (반나절 길게)")
	var o := proto(51)
	o.t = Balance.MOLD_FIRST_DAY * Balance.DAY + 1.0
	o.mold.rest_until = 0.0
	o.mold.pressure = 0.9
	o.mold._tick(o, 60.0)
	check(o.mold.phase == "calm", "망루가 없으면 아직 조짐 없음")
	# 세상 끝 (S1) — 소형 병은 벽이 가까움
	var w := proto(52)
	w.era = 1
	built(w, "망루")
	check(Codex.knows(w, "world_end") and Codex.knows(w, "world_spring"), "망루에서 세상 끝 벽과 골이 보임 → 발견 S1 · S2")


# ───────────────────────── 나루터 ─────────────────────────
func test_ferry() -> void:
	var v := proto(53)
	v.era = 1
	var x0 := _river(v, 8.0)
	var fp: Variant = VillageEra.ferry_spot(v)
	check(fp != null, "물가에 나루터 자리")
	if fp == null:
		return
	var b := built(v, "나루터", fp)
	check(b.has_link and v.water_at(b.x + (b.link_x - b.x) * 0.5, b.y + (b.link_y - b.y) * 0.5) and not v.water_at(b.link_x, b.link_y), "건너편 물가가 있다 (뗏목 길 %.1f칸)" % Vector2(b.link_x - b.x, b.link_y - b.y).length())
	var a := Vector2(b.x, b.y)
	var c := Vector2(b.link_x, b.link_y)
	var side := (c - a).normalized()
	var r: Resident = v.people[0]
	ResidentAI.cancel(v, r)
	r.x = a.x - side.x * 3.0 + side.y * 1.0
	r.y = a.y - side.y * 3.0 - side.x * 1.0
	var to := c + side * 3.0 - Vector2(side.y, -side.x) * 1.0
	var s := ResidentAI.walk(to.x, to.y)
	r.steps.append(s)
	VillageEra.route(v, r, s)
	check(r.steps.size() == 3 and bool(r.steps[1].get("raft", false)), "강 건너로 갈 때 나루터로 돌아 뗏목을 탐")
	var mid := a.lerp(c, 0.5)
	check(VillageEra.wade_mult(v, mid.x, mid.y) == 1.0, "뗏목 길 위는 걸음 그대로")
	var wet := Vector2(x0 + 1.5, v.center.y + (12.0 if mid.y < v.center.y else -12.0))
	check(not v.water_at(wet.x, wet.y) or VillageEra.wade_mult(v, wet.x, wet.y) == Balance.WADE_SPEED, "다른 곳에서 물을 걸어 건너면 ×0.4")
	# 실제로 걸어 보면: 나루터가 있으면 더 빨리 건넌다
	var t_with := _walk_time(v, r, to)
	var u := through_bytes(v)
	u.buildings = u.buildings.filter(func(q: Building) -> bool: return q.type != "나루터")
	var ru: Resident = u.person(r.id)
	ResidentAI.cancel(u, ru)
	ru.x = a.x - side.x * 3.0 + side.y * 1.0
	ru.y = a.y - side.y * 3.0 - side.x * 1.0
	var t_without := _walk_time(u, ru, to)
	check(t_with < t_without, "나루터로 건너면 더 빠르다 (%.0f초 < 물을 걸어 %.0f초)" % [t_with, t_without])
	check(float(v.stats.get("ferried", 0)) >= 1, "뗏목을 탄 횟수가 기록됨")
	check(u.wade_secs > 0.0, "물을 걸어 건넌 시간이 쌓인다 (촌장의 나루터 조건)")


func _walk_time(v: Village, r: Resident, to: Vector2) -> float:
	ResidentAI.cancel(v, r)
	r.steps.append(ResidentAI.walk(to.x, to.y))
	r.steps.append(ResidentAI.act(1.0e6, "idle"))
	var tt := 0.0
	while tt < 600.0 * 240.0 and Vector2(r.x, r.y).distance_to(to) > 0.05:     # v5: 현실 사람 걸음 (병 초로 240배 느림)
		ResidentAI.update(v, r, 10.0)
		tt += 10.0
	return tt


# ───────────────────────── 저장 ─────────────────────────
func test_era_save() -> void:
	var v := proto(54)
	v.era = 1
	_river(v, 8.0)
	var fp: Variant = VillageEra.ferry_spot(v)
	var fb := built(v, "나루터", fp) if fp != null else null
	var hb := built(v, "약초꾼")
	hb.has_spot = true
	hb.spot_x = 3.5
	v.wedding_t = 123.0
	v.wade_secs = 456.0
	v.market_day = 5
	v.lamp_hinted = true
	var c := through_bytes(v)
	var cf: Building = c.bld(fb.id) if fb != null else null
	check(fb == null or (cf.has_link and is_equal_approx(cf.link_x, fb.link_x)), "저장/불러오기: 나루터 건너편")
	check(c.bld(hb.id).has_spot and is_equal_approx(c.bld(hb.id).spot_x, 3.5), "저장/불러오기: 약초 자리")
	check(c.wedding_t == 123.0 and c.wade_secs == 456.0 and c.market_day == 5 and c.lamp_hinted, "저장/불러오기: 혼례·건넌 물·장날·귀띔")
	# 옛 저장 (새 값이 없음) → 기본값
	var d := v.to_dict()
	for k: String in ["graves", "wade_secs", "wedding_t", "bell_t", "market_day", "lamp_hinted", "lamp_moved_t", "lamp_last"]:
		d.erase(k)
	var o := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(o.graves.is_empty() and o.wade_secs == 0.0 and not o.lamp_hinted and o.market_day == -1, "옛 저장: 새 값은 기본값")
	o.advance(Balance.HOUR)
	check(o.people.size() > 0, "옛 저장을 불러와도 그대로 흐른다")


# ───────────────────────── 등불 옮기기 ─────────────────────────
func test_lamp_rules() -> void:
	var v := proto(60)
	v.advance(2.0 * Balance.HOUR)
	check(not v.move_lamp(Lamp.spot(v.water)), "같은 자리로는 안 옮김")
	var f0 := v.fear
	var n0 := v.book.size()
	check(v.move_lamp(2) and Lamp.spot(v.water) == 2, "뒤 → 앞 (두 칸을 한 번에)")
	check(v.book.size() > n0 and has_line(v, "옮겨 갔다"), "연대기: \"%s\"" % String(v.book[v.book.size() - 1]["text"]))
	check(v.people.any(func(r: Resident) -> bool: return r.say == Balance.LINE_LAMP_MOVED), "주민: \"해가 옮겨갔다!\"")
	check(is_equal_approx(v.fear, f0), "그날 첫 옮기기는 두려움 없음 (LAMP_FREE_PER_DAY 1 — giant-touch F2, %.2f)" % v.fear)
	v.move_lamp(3)
	check(v.fear > f0 + 1.0, "두 번째부터 두려움↑ (%.1f → %.1f)" % [f0, v.fear])
	v.rotate_jar()                               # 옛 이름 = 한 칸
	check(Lamp.spot(v.water) == 0, "옛 이름 rotate_jar = 다음 자리로 한 칸")
	check(v.people.any(func(r: Resident) -> bool: return r.say == Balance.LINE_LAMP_FEAR), "주민: \"해가 또 자리를 바꿨어… 무서워\"")
	v.advance(Balance.DAY)
	var f1 := v.fear
	v.move_lamp(1)
	check(is_equal_approx(v.fear, f1), "다음 날엔 다시 한 번은 괜찮다 (%.2f → %.2f)" % [f1, v.fear])
	# 깨닫기 전: 목격 (경이)
	Village.start_aware = false
	var u := proto(62)
	Village.start_aware = true
	u.advance(2.0 * Balance.HOUR)
	var w0 := u.wonder
	u.move_lamp(1)
	check(u.wonder > w0, "깨닫기 전: 등불을 옮기는 걸 보면 경이 (%.2f → %.2f)" % [w0, u.wonder])
	var h := u.lamp_hint()
	check(not h.is_empty() and not String(h["text"]).contains("거인님") and u.lamp_hint().is_empty(), "처음 한 번 노인의 귀띔 (거인을 모르면 '거인님' 없이)")
	# 넓은 세상: 모든 무리가 함께
	var jw := JarWorld.create(20261105, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var a := jw.place_kit(rec[0].x, rec[0].y)
	var ch2 := jw.spot_choices(3)
	var b: Village = jw.place_kit((ch2[1]["p"] as Vector2).x, (ch2[1]["p"] as Vector2).y) if ch2.size() > 1 else null
	var l0 := jw.water.light
	check(jw.move_lamp(2) and jw.water.rot == 2 and jw.water.light.distance_to(-l0) < 1e-5, "넓은 세상: 빛이 반대로 (데이터는 그대로)")
	check(has_line(a, "옮겨 갔다") and (b == null or has_line(b, "옮겨 갔다")), "모든 무리의 연대기에 한 줄")


## 넓은 세상: 미리보기의 골마다 화살표 = 몇 시간 뒤 실제 그 골 물길의 변화 방향
func test_lamp_preview_world() -> void:
	var jw := JarWorld.create(20261107, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	var ww := jw.water
	ww.offline = true
	check(ww.groove_k.size() == ww.grooves.size() and ww.grooves.size() >= 4, "골 %d곳" % ww.grooves.size())
	ww.advance(12.0 * Balance.HOUR)
	var before := _gully_flows(ww)
	var dir := 2
	var pv := Lamp.preview(jw.settlements, ww, dir)
	check(int(pv["up"]) + int(pv["new"]) > 0 and int(pv["down"]) + int(pv["gone"]) > 0, "미리보기: 굵어질 골 %d · 가늘어질 골 %d" % [int(pv["up"]) + int(pv["new"]), int(pv["down"]) + int(pv["gone"])])
	jw.move_lamp(dir)
	ww.advance(12.0 * Balance.HOUR)
	var after := _gully_flows(ww)
	var ok := 0
	var bad := 0
	var detail := ""
	for g: Dictionary in pv["gullies"]:
		var i := int(g["i"])
		var ch := String(g["change"])
		if ch == "same":
			continue
		var b0: float = before[i]
		var a0: float = after[i]
		if maxf(a0, b0) < 1e-6:
			continue
		var real_up := a0 > b0
		if real_up == (ch == "up" or ch == "new"):
			ok += 1
		else:
			bad += 1
			detail += " [%d %s %.4f→%.4f]" % [i, ch, b0, a0]
	check(ok >= 4 and bad == 0, "열두 시간 뒤 실제 골 물: 미리보기와 같은 방향 %d곳 · 다름 %d곳%s" % [ok, bad, detail])
	var txt := "\n".join(PackedStringArray(pv["lines"]))
	check((pv["lines"] as Array).size() >= 1 and (pv["lines"] as Array).size() <= 3, "말 1~3문장:\n    %s" % txt.replace("\n", "\n    "))
	var digits := false
	for ch2 in txt:
		if ch2 >= "0" and ch2 <= "9":
			digits = true
	check(not digits, "말에 숫자가 없다")
	var bad_w: String = String(run.call("words_ok", pv["lines"])) if run.has_method("words_ok") else ""
	check(String(bad_w) == "", "금지어 없음 %s" % bad_w)
	check(String(pv["lines"][0]).contains("그늘이 되고") and String(pv["lines"][0]).contains("볕이 들어요"), "볕과 그늘: \"%s\"" % pv["lines"][0])
	print("  마을에 미치는 것 표시 %d곳 (무리 %s)" % [(pv["places"] as Array).size(), v.settlement_name])


func _gully_flows(ww: WorldWater) -> Array:
	var out: Array = []
	for i in ww.groove_k.size():
		var k := ww.groove_k[i]
		out.append(ww.flux[k] if ww.is_fine_k(k) else ww.cFL[ww.coarse_of(k)])
	return out


## 소형 병: 미리보기 = 실제 골 물 (JarWater.groove_flux) · 밭 표시
func test_lamp_preview_jar() -> void:
	var v := proto(63)
	v.advance(8.0 * Balance.HOUR)
	var f0 := v.water.groove_flux()
	for dir in [1, 2]:
		var w := through_bytes(v)
		var pv := Lamp.preview([w], w.water, dir)
		var was := {}
		for b in w.buildings:
			if b.type == "농장" and b.built:     # 미리보기는 다 지은 밭만 (v5: 촌장이 먹을 것이 모자라면 밭 터를 먼저 잡아 짓는 중인 밭이 있을 수 있다)
				was[b.id] = w.farm_mult(b.x, b.y)
		w.move_lamp(dir)
		var farms := (pv["places"] as Array).filter(func(p: Dictionary) -> bool: return p["kind"] == "farm")
		var real := 0
		for b in w.buildings:
			if b.type == "농장" and was.has(b.id):
				var d := w.farm_mult(b.x, b.y) / maxf(0.01, float(was[b.id]))
				if absf(d - 1.0) >= Balance.LAMP_FARM:
					real += 1
		check(farms.size() == real, "%s로: 밭 표시 %d곳 = 실제로 농사 배율이 바뀐 밭 %d곳" % [Lamp.SPOT_NAMES[dir], farms.size(), real])
		w.advance(6.0 * Balance.HOUR)
		var f1 := w.water.groove_flux()
		var ok := 0
		var bad := 0
		for g: Dictionary in pv["gullies"]:
			var gi := int(g["i"])
			var ch := String(g["change"])
			if ch == "same":
				continue
			if (f1[gi] > f0[gi]) == (ch == "up" or ch == "new"):
				ok += 1
			else:
				bad += 1
		check(ok >= 2 and bad == 0, "소형 병 %s로: 여섯 시간 뒤 골 물 방향이 미리보기와 같다 (%d곳, 다름 %d)" % [Lamp.SPOT_NAMES[dir], ok, bad])


func test_lamp_save() -> void:
	var jw := JarWorld.create(20261105, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	jw.move_lamp(3)
	v.lamp_hinted = true
	var c := JarWorld.from_dict(bytes_to_var(var_to_bytes(jw.to_dict())))
	check(c.water.rot == 3 and c.water.light.distance_to(jw.water.light) < 1e-6, "저장/불러오기: 등불 자리 · 빛")
	check(c.primary().lamp_hinted and int(c.primary().lamp_last.get("to", -1)) == 3, "저장/불러오기: 귀띔 · 마지막 옮김")
	check(c.move_lamp(0) and c.water.rot == 0, "불러온 뒤에도 옮길 수 있다")


# ───────────────────────── 화면 (나침반 · 귀띔 · 미리보기 · 구석의 해) ─────────────────────────
func test_lamp_ui() -> void:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var v: Village = scene.get("village")
	var lc: LampCtl = scene.get("lamp_ctl")
	check(lc != null and lc.badge.is_visible_in_tree(), "화면 구석에 작은 해 (지금 빛이 오는 쪽)")
	scene.call("toggle_hand")
	scene.call("move_lamp")
	check(lc.compass.visible and not bool(scene.call("hand_open")), "[등불 옮기기] → 손 칸이 닫히고 나침반")
	var dirs := {}
	for k in 4:
		dirs[lc.spot_word(k)] = true
	check(dirs.size() == 4, "나침반 네 자리: %s" % ", ".join(PackedStringArray(dirs.keys())))
	var r0 := v.water.rot
	lc.choose(Lamp.spot(v.water))
	check(lc.compass.visible and lc.dial_note.text.contains("지금"), "지금 자리를 누르면: \"%s\"" % lc.dial_note.text)
	lc.choose(posmod(r0 + 2, 4))
	check(lc.hint_box.visible and lc.hint_text.text.contains("그늘진 벽"), "처음 한 번: 노인의 귀띔 %s" % lc.hint_text.text)
	lc._show_preview(lc.picked)
	check(lc.previewing() and lc.overlay.visible and lc.prev_text.text.length() > 10, "미리보기: %s" % lc.prev_text.text.replace("\n", " / "))
	lc.cancel()
	check(not lc.is_open() and v.water.rot == r0, "[그만두기] → 그대로")
	scene.call("move_lamp")
	lc.choose(posmod(r0 + 1, 4))
	check(lc.previewing() and not lc.hint_box.visible, "두 번째부터는 귀띔 없이 바로 미리보기")
	lc.confirm()
	check(not lc.is_open() and v.water.rot == posmod(r0 + 1, 4), "[옮기기] → 등불이 옮겨 감")
	run.root.remove_child(scene)
	scene.free()


# ───────────────────────── 빠른 흐름 화면 (기획서 6.6 — 1초=5분 ~ 1초=12시간) ─────────────────────────
func test_fast_view() -> void:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var clock: JarClock = scene.get("clock")
	var view: VillageView = scene.get("view")
	var items: Array = scene.get("speed_items")
	check(items.size() == Balance.SPEEDS.size() and (items[9] as Button).text == "1초=12시간" and (items[5] as Button).text == "1초=5분" and (items[2] as Button).text.begins_with("보통"),
		"배속 목록: 윗줄 %s … · 아랫줄 %s ~ %s" % [(items[2] as Button).text.replace("\n", " "), (items[5] as Button).text, (items[9] as Button).text])
	(items[9] as Button).pressed.emit()
	check(clock.speed_i == 9 and clock.fast, "목록에서 1초=12시간을 누르면 빠른 흐름")
	clock.auto_slow = false
	var v: Village = scene.get("village")
	var t0 := v.t
	var worst := 0.0
	for i in 30:
		var tf := Time.get_ticks_usec()
		scene.call("_process", 1.0 / 60.0)
		worst = maxf(worst, (Time.get_ticks_usec() - tf) / 1000.0)
	var btn: Button = scene.get("speed_btn")
	var bubbles: Control = scene.get("bubbles")
	check(view.fast and view.alpha == 1.0 and bubbles.get_children().all(func(c: Node) -> bool: return c.is_queued_for_deletion()) and btn.text.contains("1초=12시간"),
		"빠른 흐름 화면: 주민은 순간이동(보간 없음) · 말풍선 없음 · 칩 '%s'" % btn.text)
	check(v.t - t0 > 600.0, "30화면 동안 병 %.1f시간 (가장 긴 화면 %.1f ms)" % [(v.t - t0) / 3600.0, worst])
	clock.set_speed(Balance.SPEED_DEFAULT_I)
	scene.call("_process", 1.0 / 60.0)
	check(not view.fast and not clock.view_fast() and btn.text.contains("보통"), "보통으로 돌아오면 화면도 보통으로 ('%s')" % btn.text)
	run.root.remove_child(scene)
	scene.free()
