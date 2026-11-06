## 건강·기후·두려움 테스트 — docs/HEALTH.md (sim/health.gd). tests/run.gd가 부름 (`-- health` = 이것만).
## 확률은 마을 시뮬레이션 없이 굴림 함수를 직접 많이 불러 잰다 (빠름). 겨울 시험만 마을을 10일 돌린다.
extends RefCounted

var run: SceneTree
var quick := false
const H := Balance.HOUR
const D := Balance.DAY


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 건강·기후·두려움 (HEALTH.md)")
	test_calendar_and_temperature()
	test_illness_rates()
	test_exposure()
	test_firewood()
	test_injury()
	test_fear()
	test_deaths_and_text()
	test_blood_src()
	test_offline_protection()
	test_winter_speed_equal()
	test_seasons()


## 날짜를 정해 새 마을 (Village.default_created를 잠깐 바꿈)
static func village_on(month: int, day: int, seed_v := 1) -> Village:
	var keep := Village.default_created
	Village.default_created = {"year": 2026, "month": month, "day": day}
	var v := Village.new_prototype(seed_v)
	Village.default_created = keep
	return v


## 병 시계를 이 시각으로 (온도·날짜 계산만 — 시뮬레이션은 걷지 않음)
static func set_clock(v: Village, day_offset: int, hour: float) -> void:
	v.t = day_offset * D + hour * H - v.start_clock


# ───────────────────────── 1. 날짜·온도 ─────────────────────────
func test_calendar_and_temperature() -> void:
	var v := village_on(1, 15)
	set_clock(v, 1, 4.0)                 # 1월 16일 04:00
	var c := Vector2(0, 0)
	var dawn := v.temperature_at(c.x, c.y)
	set_clock(v, 0, 14.0)
	var jan_noon := v.temperature_at(c.x, c.y)
	var s := village_on(7, 15)
	set_clock(s, 0, 14.0)
	var july := s.temperature_at(c.x, c.y)
	var k := village_on(1, 15)
	k.climate_override = "냉대"
	set_clock(k, 1, 4.0)
	var boreal := k.temperature_at(c.x, c.y)
	var spot := Balance.SPOT_WARM * v.water.warm_at(c.x, c.y)
	print("  온대 1월 새벽 %.1f° · 1월 한낮 %.1f° · 7월 한낮 %.1f° · 냉대 1월 새벽 %.1f° (자리 +%.1f)" % [dawn, jan_noon, july, boreal, spot])
	check(dawn < 0.0 and absf(dawn - spot - (-3.0)) < 0.3, "온대 1월 새벽 < 0 (자리 빼면 ≈ −3: %.1f)" % (dawn - spot))
	check(july > 24.0 and absf(july - spot - 27.0) < 0.3, "온대 7월 한낮 > 24 (자리 빼면 ≈ 27: %.1f)" % (july - spot))
	check(boreal < dawn - 10.0 and absf(boreal - spot - (-16.0)) < 0.3, "냉대가 더 춥다 (1월 새벽 자리 빼면 ≈ −16: %.1f)" % (boreal - spot))
	var warm_side := v.temperature_at(-20.0, -20.0)
	var shade_side := v.temperature_at(20.0, 20.0)
	check(warm_side > shade_side, "창가 쪽이 그늘 쪽보다 따뜻하다 (%.1f > %.1f)" % [warm_side, shade_side])
	# 병 날짜
	var a := village_on(4, 15)
	var d0 := a.jar_date()
	set_clock(a, 1, 0.5)
	var d1 := a.jar_date()
	check(d0["month"] == 4 and d0["day"] == 15 and d0["season"] == "봄" and d1["day"] == 16, "병 날짜: 만든 날 4월 15일(봄) → 자정 지나 16일 (%s → %s)" % [str(d0), str(d1)])
	var b := village_on(12, 31)
	set_clock(b, 1, 8.0)
	var db := b.jar_date()
	check(db["year"] == 2027 and db["month"] == 1 and db["day"] == 1 and db["season"] == "겨울", "12월 31일 + 1일 → 이듬해 1월 1일 겨울")
	var seasons_ok := Health.season_of(3) == "봄" and Health.season_of(6) == "여름" and Health.season_of(9) == "가을" and Health.season_of(12) == "겨울" and Health.season_of(2) == "겨울"
	check(seasons_ok, "계절: 3~5 봄 · 6~8 여름 · 9~11 가을 · 12~2 겨울")
	check(v.climate() == "온대", "기후대 기본 온대")


# ───────────────────────── 2. 질병 ─────────────────────────
## 실험실 마을: 다른 사람은 없고, 우물 곁 석조주택(8명)마다 n명. 집끼리는 멀리 (전염 반경 밖)
static func lab(houses: int, per_house: int, month := 4, day := 15, seed_v := 1) -> Village:
	var v := village_on(month, day, seed_v)
	v.people.clear()
	v._people_by_id.clear()
	v.add_building("우물", 0.0, -6.0, true)
	for i in houses:
		var a := TAU * i / houses
		var hb := v.add_building("석조주택", cos(a) * 9.0, -6.0 + sin(a) * 9.0, true)
		for j in per_house:
			var r := v.add_person("시험%d" % (i * per_house + j), "m" if j % 2 == 0 else "f", 10.0, "", hb.x, hb.y, null, null)
			r.home = hb.id
	v._health_hour = 1 << 40           # tick이 정시 굴림을 하지 않게 (굴림은 직접 부름)
	return v


## 정시 굴림을 hours번 — 앓기 시작한 사람 수. keep_sick = 이 사람들은 늘 앓는 중 (전염원)
func onsets(v: Village, hours: int, keep_sick: Array = []) -> int:
	var n := 0
	for i in hours:
		for r in keep_sick:
			(r as Resident).sick_left = D
		Health._hourly(v, [])
		for r in v.people:
			if r.sick_left > 0.0 and not r in keep_sick:
				n += 1
				r.sick_left = 0.0
	return n


func test_illness_rates() -> void:
	var days := 1000 if quick else 2500     # 발병 1%/일 — 표본 오차를 ±10% 안으로
	var v := lab(5, 4)
	var n_base := onsets(v, days * 24)
	var base := float(n_base) / (v.people.size() * days)
	check(absf(base - Balance.ILL_DAY) < Balance.ILL_DAY * 0.15, "기본 발병 하루 %.4f ≈ 1%% (%d명 × %d일, %d번)" % [base, v.people.size(), days, n_base])
	var rates := {}
	for bl: String in ["sturdy", "frail"]:
		var w := lab(5, 4)
		for r in w.people:
			r.set_blood(PackedStringArray([bl]))
		rates[bl] = float(onsets(w, days * 24)) / (w.people.size() * days)
	check(absf(rates["sturdy"] / base - 0.7) < 0.12, "강인한 ×%.2f ≈ ×0.7" % (rates["sturdy"] / base))
	check(absf(rates["frail"] / base - 1.3) < 0.15, "병약 ×%.2f ≈ ×1.3" % (rates["frail"] / base))
	# 같은 집 식구가 앓으면 하루 +15%
	var cdays := days / 4
	var hh := lab(5, 4)
	var src: Array = []
	for i in 5:
		src.append(hh.people[i * 4])
	var n_c := onsets(hh, cdays * 24, src)
	var crate := float(n_c) / ((hh.people.size() - src.size()) * cdays)
	check(crate > base * 5.0 and absf(crate - (Balance.ILL_DAY + Balance.CONTAGION_HOME)) < 0.03, "식구가 앓으면 발병 하루 %.3f (≈ 0.01 + 0.08)" % crate)
	# 배율: 아기·노인 ×1.5, 굶주림 ×2, 우물 반경 밖 ×1.3
	var e := lab(5, 4)
	for r in e.people:
		r.age = 22.0
	var erate := float(onsets(e, days * 24)) / (e.people.size() * days)
	check(absf(erate / base - 1.5) < 0.18, "노인 ×%.2f ≈ ×1.5" % (erate / base))
	var hu := lab(5, 4)
	for r in hu.people:
		r.hunger = 3.5
	var hrate := float(onsets(hu, days * 24)) / (hu.people.size() * days)
	check(absf(hrate / base - 2.0) < 0.25, "굶주림 ×%.2f ≈ ×2" % (hrate / base))
	# 앓는 기간 3일 (병약 ×1.5), 그동안 건강 하루 −0.15, 일하지 않음
	var s := lab(1, 2)
	var p := s.people[0]
	var q := s.people[1]
	q.set_blood(PackedStringArray(["frail"]))
	Health.fall_ill(s, p)
	Health.fall_ill(s, q)
	check(is_equal_approx(p.sick_left, 3.0 * D) and is_equal_approx(q.sick_left, 4.5 * D), "앓는 기간 3일 · 병약 4.5일 (%.2f · %.2f일)" % [p.sick_left / D, q.sick_left / D])
	var h0 := p.health
	for i in 24 * 60:
		Health.tick(s, 60.0, s.t)
	check(absf((h0 - p.health) - 0.15) < 0.005 and absf(p.sick_left - 2.0 * D) < 1.0, "앓는 하루: 건강 −%.3f (0.15), 남은 기간 %.2f일" % [h0 - p.health, p.sick_left / D])
	check(not Health.can_heal(p), "앓는 동안은 저절로 낫지 않는다")
	ResidentAI.decide(s, p)
	check(p.action == "sick" and p.doing.contains("앓아누운"), "앓는 사람은 집에 눕는다 (%s)" % p.doing)
	# 약초: 남은 기간 절반, 한 번만
	s.stock["약초"] = 2.0
	var left := p.sick_left
	Health.tick(s, 60.0, s.t)
	check(absf(p.sick_left - (left * 0.5 - 60.0)) < 1.0 and p.herb_used and float(s.stock["약초"]) < 2.0, "약초 하나 → 남은 기간 절반 (%.2f → %.2f일)" % [left / D, p.sick_left / D])


# ───────────────────────── 1.3·1.4 노출 ─────────────────────────
func test_exposure() -> void:
	var v := lab(1, 4, 1, 15)
	set_clock(v, 1, 4.0)                 # 1월 새벽
	var spot := Vector2(-2.0, 18.0)      # 모닥불·집·나무에서 먼 밖
	v.trees.clear()
	var ids := ["", "cold_hardy", "cold_weak", "cold_hardy+cold_weak"]
	for i in 4:
		var r := v.people[i]
		r.x = spot.x + i * 0.3
		r.y = spot.y
		r.home = -1
		if ids[i] != "":
			r.set_blood(PackedStringArray(String(ids[i]).split("+")))
	var h0: Array = []
	for r in v.people:
		h0.append(r.health)
	for i in 60:
		Health.tick(v, 60.0, v.t)
	var loss: Array = []
	for i in 4:
		loss.append(float(h0[i]) - v.people[i].health)
	var deg := v.people[0].cold
	var want := Balance.EXPOSE_HEALTH_DAY * deg / 24.0
	print("  1월 새벽 밖: 추위 정도 %.2f · 한 시간 건강 −%.4f (보통) / %.4f (견딤) / %.4f (탐) / %.4f (둘 다 = 상쇄)" % [deg, loss[0], loss[1], loss[2], loss[3]])
	check(deg > 0.5 and absf(float(loss[0]) - want) < want * 0.02, "추위 정도 %.2f로 한 시간 → 건강 −%.4f (0.25/일 × 정도)" % [deg, loss[0]])
	check(float(loss[1]) == 0.0, "추위 견딤: 추위로 건강이 줄지 않는다")
	check(absf(float(loss[2]) / float(loss[0]) - 2.0) < 0.01, "추위 탐: ×%.2f" % (float(loss[2]) / float(loss[0])))
	check(absf(float(loss[3]) / float(loss[0]) - 1.0) < 0.03, "짝을 함께 가지면 상쇄 (보통과 같음)")
	check(not Health.can_heal(v.people[0]) and Health.can_heal(v.people[1]), "떨고 있으면 저절로 낫지 않음 (견딤은 낫는다)")
	# 노인 ×1.5
	v.people[0].age = 22.0
	var he := v.people[0].health
	for i in 60:
		Health.tick(v, 60.0, v.t)
	check(absf((he - v.people[0].health) / float(loss[0]) - 1.5) < 0.01, "노인 ×1.5")
	# 막아 주는 것: 모닥불 ×0.5, 집(땔감 없음) ×0.6
	var r0 := v.people[1]
	r0.set_blood(PackedStringArray())
	r0.x = v.fire.x + 1.0
	r0.y = v.fire.y
	Health.tick(v, 60.0, v.t)
	var raw := Health.cold_of(v.temperature_at(r0.x, r0.y))
	check(absf(r0.cold - raw * 0.5) < 1e-4, "모닥불 곁 추위 ×0.5 (%.2f → %.2f)" % [raw, r0.cold])
	# 더위: 7월 한낮 사막, 나무 그늘 ×0.6, 더위 견딤 ×0
	var hv := lab(1, 2, 7, 15)
	hv.climate_override = "사막"
	set_clock(hv, 0, 14.0)
	hv.trees = [{"x": 0.0, "y": 20.0, "s": "tree", "g": 0.0, "res": 0}]
	var a := hv.people[0]
	var b := hv.people[1]
	a.home = -1
	b.home = -1
	a.x = 0.5
	a.y = 20.0
	b.x = 5.0
	b.y = 20.0
	Health.tick(hv, 60.0, hv.t)
	check(b.heat > 0.0 and absf(a.heat - Health.heat_of(hv.temperature_at(a.x, a.y)) * 0.6) < 1e-4, "사막 7월 한낮 더위 %.2f · 나무 그늘 ×0.6 → %.2f" % [b.heat, a.heat])
	b.set_blood(PackedStringArray(["heat_hardy"]))
	var hb := b.health
	Health.tick(hv, 60.0, hv.t)
	check(b.health == hb, "더위 견딤: 더위로 건강이 줄지 않는다")
	# 행동: 밖이 0.5보다 추우면 집·불가로
	var w := lab(1, 2, 1, 15)
	set_clock(w, 1, 6.2)
	var m := w.people[0]
	m.x = 20.0
	m.y = 20.0                         # 그늘 쪽 밖
	var od := Health.outdoor(w, m.x, m.y)
	w.stock["통나무"] = 0.0
	var got_shelter := false
	for i in 20:
		m.steps.clear()
		m.last_action = ""
		ResidentAI.decide(w, m)
		got_shelter = got_shelter or m.action == "shelter"
	check(od.x > 0.5 and got_shelter, "1월 아침 밖 추위 %.2f → 몸을 녹이러 감 (%s)" % [od.x, m.doing])


# ───────────────────────── 땔감 ─────────────────────────
func test_firewood() -> void:
	var v := lab(2, 2, 1, 15)
	set_clock(v, 1, 2.0)
	var houses := v.houses()
	houses[0].in_buf["통나무"] = 20.0
	houses[1].type = "목조주택"
	for r in v.people:
		var hm := v.bld(r.home)
		r.x = hm.x
		r.y = hm.y + 0.3
	for i in 60:
		Health.tick(v, 60.0, v.t)
	var used0 := 20.0 - float(houses[0].in_buf["통나무"])
	var inside := v.people[0]
	var cold_no := v.people[2]
	check(absf(used0 - 3.0) <= 1.0, "석조 주택: 추운 동안 20분마다 통나무 1개 (한 시간 %.0f개 — 보통 집 6개 × 0.5)" % used0)
	check(houses[0].fuel_on and absf(inside.cold - Health.cold_of(v.temperature_at(inside.x, inside.y)) * 0.2) < 1e-4, "땔감 있는 집 안 추위 ×0.2 (%.2f)" % inside.cold)
	check(not houses[1].fuel_on and absf(cold_no.cold - Health.cold_of(v.temperature_at(cold_no.x, cold_no.y)) * 0.6) < 1e-4, "땔감 없는 집 안 ×0.6 (%.2f)" % cold_no.cold)
	houses[1].in_buf["통나무"] = 20.0
	for i in 60:
		Health.tick(v, 60.0, v.t)
	check(absf((20.0 - float(houses[1].in_buf["통나무"])) - 6.0) <= 1.0, "목조 주택: 10분마다 1개 (한 시간 %.0f개)" % (20.0 - float(houses[1].in_buf["통나무"])))
	# 운반: 추운 철이면 창고 통나무를 집으로 (기존 운반 일)
	v.cold_season = Health._cold_ahead(v, v.t)
	v.stock["통나무"] = 30.0
	houses[1].in_buf["통나무"] = 0.0
	var hauler := v.people[1]
	hauler.steps.clear()
	var n_req := ResidentAI.haul_requests(v)
	var ok := ResidentAI.haul_task(v, hauler)
	check(v.cold_season and n_req >= 1 and ok and hauler.doing == "땔감 나르는 중" and float(houses[1].in_inc.get("통나무", 0.0)) > 0.0, "추운 철 운반 일에 땔감 나르기 (요청 %d)" % n_req)
	check(v.enough("통나무") > Balance.ENOUGH["통나무"], "추운 철엔 나무꾼이 통나무를 더 쌓는다 (넉넉함 %.0f)" % v.enough("통나무"))
	var spring := lab(2, 2, 4, 15)
	set_clock(spring, 1, 4.0)
	spring.cold_season = Health._cold_ahead(spring, spring.t)
	check(not spring.cold_season and spring.enough("통나무") == Balance.ENOUGH["통나무"], "4월 중순 온대: 땔감 철 아님")


# ───────────────────────── 3. 부상 ─────────────────────────
func test_injury() -> void:
	var v := lab(5, 4)
	var hours := 2000 if quick else 5000
	var n := 0
	for i in hours:
		for r in v.people:
			r.heavy_secs = H
			r.injured_left = 0.0
			r.health = 1.0
		Health._hourly(v, [])
		for r in v.people:
			if r.injured_left > 0.0:
				n += 1
	var rate := float(n) / (v.people.size() * hours)
	check(absf(rate - Balance.INJURY_HOUR) < Balance.INJURY_HOUR * 0.15, "힘쓰는 일 한 시간 부상 %.4f ≈ 0.3%%" % rate)
	var r := v.people[0]
	r.injured_left = 2.0 * D
	r.age = 10.0
	var ws := r.walk_speed()
	var js := r.job_speed("제재소")
	r.injured_left = 0.0
	check(is_equal_approx(ws, r.walk_speed() * 0.5) and is_equal_approx(js, r.job_speed("제재소") * 0.5), "다치면 걸음·일 속도 ×0.5")
	r.injured_left = 2.0 * D
	r.health = 0.05
	r.injured_left = 0.0
	r.heavy_secs = H * 1.0e6
	Health._hourly(v, [])
	check(r.injured_left > 0.0 and r.health > 0.0, "부상만으로는 죽지 않는다 (건강 %.2f)" % r.health)


# ───────────────────────── 4. 두려움 ─────────────────────────
func test_fear() -> void:
	var v := lab(1, 3)
	var n := v.people[0]
	var bold := v.people[1]
	var timid := v.people[2]
	bold.set_blood(PackedStringArray(["bold"]))
	timid.set_blood(PackedStringArray(["timid"]))
	v.tap_glass(true)
	check(is_equal_approx(n.fear, 0.2) and is_equal_approx(bold.fear, 0.1) and is_equal_approx(timid.fear, 0.3), "지진 톡 +0.2 · 담대 ×0.5 · 겁 많음 ×1.5 (%.2f · %.2f · %.2f)" % [n.fear, bold.fear, timid.fear])
	check(absf(v.fear - 20.0) < 1e-3, "부락의 두려움 = 평균 × 100 (%.1f)" % v.fear)
	v = lab(1, 3)                       # 새 날 (지진 톡도 그날 톡 횟수에 들어가므로)
	n = v.people[0]
	for i in 3:
		v.tap_glass()
	var after3 := n.fear
	v.tap_glass()
	check(after3 == 0.0 and is_equal_approx(n.fear, Balance.FEAR_TAP), "유리 톡: 그날 3번까지는 괜찮고 4번째부터 +0.05")
	for i in 4:
		v.rotate_jar()
	check(is_equal_approx(n.fear, Balance.FEAR_TAP + Balance.FEAR_ROTATE), "병 돌리기: 4번째부터 +0.1 (%.2f)" % n.fear)
	# 반감기 12시간 (기도·축제 중엔 두 배)
	bold = v.people[1]
	bold.set_blood(PackedStringArray(["bold"]))
	n.fear = 0.8
	bold.fear = 0.8
	bold.action = "pray"
	n.action = ""
	for i in 12 * 60:
		Health.tick(v, 60.0, v.t)
	check(absf(n.fear - 0.4) < 0.002 and absf(bold.fear - 0.2) < 0.002, "반감기 12시간 (0.8 → %.3f), 기도하면 두 배 빨리 (→ %.3f)" % [n.fear, bold.fear])
	# 죽음: 가족 +0.2, 곁에서 본 사람 +0.05
	var f := lab(1, 4)
	var dad := f.people[0]
	var kid := f.people[1]
	var nb := f.people[2]
	var far := f.people[3]
	kid.parents = PackedInt32Array([dad.id, -1])
	far.x += 30.0
	f.kill(dad, "노환")
	check(is_equal_approx(kid.fear, 0.2) and is_equal_approx(nb.fear, 0.05) and far.fear == 0.0, "죽음: 가족 +0.2 · 반경 6칸 +0.05 · 먼 사람 0")
	# 효과: 0.6 이상 → 일 점수 ×0.7, 행복 −0.1 × 두려움
	nb.fear = 1.0
	f._update_happiness()
	var h_af := nb.happiness
	nb.fear = 0.0
	f._update_happiness()
	check(absf(nb.happiness - h_af - 0.1) < 1e-4, "행복 −0.1 × 두려움")
	# 굶주릴 때 식량을 거둠 +0.1
	var g := lab(1, 1)
	g.on_food_taken()
	var calm := g.people[0].fear
	g.last_short_t = g.t
	g.on_food_taken()
	check(calm == 0.0 and is_equal_approx(g.people[0].fear, Balance.FEAR_TAKE_FOOD), "식량을 거두면: 배부를 땐 그대로, 굶주릴 땐 +0.1")


# ───────────────────────── 사망 원인·연대기 ─────────────────────────
func test_deaths_and_text() -> void:
	var v := lab(1, 4, 1, 20)
	v.people[0].harm = {"추위": 0.8, "굶주림": 0.1}
	v.people[1].harm = {"병": 0.5}
	v.people[2].harm = {"더위": 0.4, "병": 0.1}
	v.people[3].harm = {"굶주림": 0.5}
	var want := ["추위", "병", "더위"]
	var ok := true
	for i in 3:
		ok = ok and Health.death_cause(v.people[i]) == want[i]
	check(ok, "사망 원인 = 최근 건강을 가장 많이 깎은 것 (추위·병·더위)")
	for r in v.people.duplicate():
		r.health = -0.1
	v.watching = true
	v._deaths(60.0)                  # 지켜보는 중: 모두 위기 사망
	var texts: Array = []
	for e: Dictionary in v.book:
		texts.append(e["text"])
	for e: Dictionary in v.crises:
		texts.append(e["text"])
	var joined := "\n".join(PackedStringArray(texts))
	check(joined.contains("그 겨울,") and joined.contains("끝내 따뜻해지지 못했다") and joined.contains("앓아누운 끝에") and joined.contains("더위를 이기지 못했다"), "연대기가 원인마다 다르다 (추위·병·더위)")
	check(joined.count("굶주림 끝에") == 1, "'굶주림' 문구는 굶주려 죽은 한 사람에게만")
	var deaths := {}
	for r in v.dead:
		deaths[r.death_why] = int(deaths.get(r.death_why, 0)) + 1
	check(deaths.get("추위", 0) == 1 and deaths.get("병", 0) == 1 and deaths.get("더위", 0) == 1, "death_why: %s" % str(deaths))
	check(int(v.stats.get("died_cold", 0)) == 1 and int(v.stats.get("died_sick", 0)) == 1 and v.stats["starved"] <= 1, "통계: 추위 %d · 병 %d" % [v.stats.get("died_cold", 0), v.stats.get("died_sick", 0)])
	texts.append_array([Balance.LINE_FEAR, Balance.LINE_SICK_WARN, "몸이 으슬으슬해…", "아야, 다리를 삐었어…", "마을에 기침 소리가 늘었다. 앓아누운 집이 하나둘이 아니었다."])
	for st: String in ["앓아누운 중", "모닥불 곁에 앓아누운 중", "집에서 몸을 녹이는 중", "집 안에서 더위를 피하는 중", "모닥불 곁에서 몸을 녹이는 중", "집에 숨어 있는 중", "땔감 나르는 중"]:
		texts.append(st)
	check(run.words_ok(texts) == "", "새 연대기·말에 금지어(게임·앱·플레이어·휴대폰·키트·상자·구매) 없음 %s" % run.words_ok(texts))


# ───────────────────────── 혈통 출처 ─────────────────────────
func test_blood_src() -> void:
	var v := village_on(4, 15)
	var mom := v.people[1]
	var dad := v.people[0]
	mom.set_blood(PackedStringArray(["sturdy"]))
	dad.set_blood(PackedStringArray(["swift"]))
	var seen := {}
	var ok := true
	for i in 300:
		var kid := Resident.new()
		kid.id = 1000 + i
		v._inherit_look(kid, mom, dad)
		for id in kid.blood:
			var s: String = kid.blood_src.get(id, "")
			seen[s] = true
			if id == "sturdy":
				ok = ok and s == "mother"
			elif id == "swift":
				ok = ok and s == "father"
			else:
				ok = ok and s == "new"
	check(ok and seen.has("mother") and seen.has("father"), "아이 혈통 출처: 엄마 것은 mother, 아빠 것은 father, 새로 생긴 것은 new (%s)" % str(seen.keys()))
	# 격세유전: 부모엔 없고 할머니가 가짐
	var p1 := Resident.new()
	var p2 := Resident.new()
	p1.sex = "f"
	p2.sex = "m"
	p1.parent_blood = PackedStringArray(["fertile"])
	p1.parent_blood_sex = {"fertile": "f"}
	var gm := false
	for i in 3000:
		var kid := Resident.new()
		kid.id = i
		v._inherit_look(kid, p1, p2)
		if "fertile" in kid.blood:
			gm = kid.blood_src["fertile"] == "grandmother"
			break
	check(gm, "격세유전 출처 grandmother")
	var jw := JarWorld.create(424242, 512)
	var rec := jw.recommended_kit_spots()
	var kv := jw.place_kit(rec[0].x, rec[0].y, Kits.make([], "강인한 가족"))
	var all_kit := true
	for r in kv.people:
		for id in r.blood:
			all_kit = all_kit and r.blood_src.get(id, "") == "kit"
	check(all_kit and not kv.people[0].blood.is_empty(), "키트 가족 혈통 출처 kit")


# ───────────────────────── 오프라인 멸망 방지 ─────────────────────────
func test_offline_protection() -> void:
	var v := village_on(1, 20)
	v.watching = false
	for r in v.people:
		r.health = -0.5
		r.harm = {"추위": 1.0}
	v._deaths(60.0)
	v._deaths(60.0)
	var d1: int = v.stats["died"]
	check(d1 <= 1, "거인이 없을 때 추위 사망은 하루 1명까지 (%d)" % d1)
	var w := village_on(1, 20)
	w.watching = false
	for r in w.people:
		r.health = -0.5
		r.harm = {"병": 1.0}
	for d in 10:
		w.t += D
		w._deaths(60.0)
	var couples := 0
	for p in w.people:
		if p.sex == "f" and p.partner >= 0:
			couples += 1
	check(couples >= Balance.OFFLINE_MIN_COUPLES, "병으로도 부부 %d쌍 아래로는 죽지 않음 (남은 부부 %d · 사망 %d)" % [Balance.OFFLINE_MIN_COUPLES, couples, w.stats["died"]])


# ───────────────────────── ×1 = ×8 (겨울 — 땔감·노출·발병이 도는 중) ─────────────────────────
func sig(v: Village) -> String:
	var s: String = run.clock_sig(v)
	s += "|%s|%s|%s|" % [str(v.fear), str(v.health_rng.state), str(v.stats.get("firewood", 0.0))]
	for p in v.people:
		s += "%s,%s,%s,%s;" % [str(p.health), str(p.fear), str(p.cold), str(p.sick_left)]
	return s


func test_winter_speed_equal() -> void:
	var hours := 2.0
	var steps := int(hours * H / Balance.WATCH_STEP)
	var sigs: Array = []
	for spec: Array in [[0, 1.0 / 30.0], [3, 0.25]]:
		var v := village_on(1, 20, 3)
		v.tap_glass(true)
		var c := JarClock.new(v)
		c.set_speed(spec[0])
		while c.steps_done < steps:
			c.tick(spec[1])
		sigs.append(sig(v))
	check(sigs[0] == sigs[1], "겨울 병 %.0f시간: ×1과 ×8 결과가 같다 (건강·두려움·땔감·건강 난수 포함)" % hours)
	# 밤 건너뛰기 = 몰아서 계산 (겨울)
	var mk := func() -> Village:
		var vv := village_on(1, 20, 5)
		vv.water.offline = true
		vv.advance(15.0 * H)
		vv.water.offline = false
		vv.crises.clear()
		return vv
	var va: Village = mk.call()
	var vb: Village = mk.call()
	var ca := JarClock.new(va)
	var cb := JarClock.new(vb)
	for i in 3600:
		if ca.can_skip_night():
			break
		ca.tick(1.0)
		cb.tick(1.0)
	if ca.start_skip_night():
		var span := ca.skip_span
		while ca.skipping:
			ca.tick(1.0 / 24.0)
		vb.water.offline = true
		vb.advance(span)
		vb.water.offline = false
		check(sig(va) == sig(vb), "겨울 밤 건너뛰기 = 같은 시간을 몰아서 계산 (%s)" % va.fmt_time(va.t))
	else:
		check(true, "겨울 밤 건너뛰기: 모두 잠들지 않아 건너뛰지 않음 (%s)" % va.fmt_time(va.t))


# ───────────────────────── 봄 vs 겨울 마을 10일 ─────────────────────────
func run_village(month: int, day: int, seed_v: int, days: int) -> Dictionary:
	var v := village_on(month, day, seed_v)
	v.watch_hours = [20, 21]
	v.auto_reveal = true
	v.step_dt = 30.0
	v.water.offline = true
	var t0 := Time.get_ticks_usec()
	var bad := 0
	for d in days:
		v.advance(D)
		bad += v.check_invariants().size()
	var deaths := {}
	for r in v.dead:
		deaths[r.death_why] = int(deaths.get(r.death_why, 0)) + 1
	var person_days := float(v.stats.get("person_secs", 0.0)) / D
	return {"v": v, "pop": v.people.size(), "deaths": deaths, "born": v.stats["born"], "sick": int(v.stats.get("sick", 0)),
		"injured": int(v.stats.get("injured", 0)), "firewood": float(v.stats.get("firewood", 0.0)), "person_days": person_days,
		"sick_frac": float(v.stats.get("sick_secs", 0.0)) / maxf(1.0, float(v.stats.get("person_secs", 0.0))),
		"cold_house_h": float(v.stats.get("cold_house_secs", 0.0)) / H, "spared": int(v.stats.get("spared", 0)),
		"bad": bad, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "date": v.jar_date(), "fear": v.fear, "houses": v.houses().size()}


func test_seasons() -> void:
	var seeds := [1] if quick else [1, 2, 3]
	var days := 10
	print("  마을 %d일 (하루 2시간 지켜봄 · 30초 걸음) — 봄(4월 15일) vs 겨울(온대 1월 30일)" % days)
	var winter_ok := true
	var spring_pop := 0.0
	var winter_pop := 0.0
	var ill_rate := 0.0
	for sd: int in seeds:
		for spec: Array in [[4, 15], [1, 30]]:
			var res := run_village(spec[0], spec[1], sd, days)
			var nm := "봄" if spec[0] == 4 else "겨울"
			print("  시드 %d %s → %s: 인구 %d (출생 %d) · 사망 %s · 앓음 %d번 (사람-일 %.0f, 하루 %.3f, 앓는 시간 %.1f%%) · 부상 %d · 땔감 %.0f개 (집 %d채, 불 꺼진 집 %.0f집-시간) · 살려 둠 %d · 두려움 %.0f · %.0f ms" % [
				sd, nm, "%d/%d" % [res["date"]["month"], res["date"]["day"]], res["pop"], res["born"], str(res["deaths"]), res["sick"], res["person_days"],
				res["sick"] / maxf(1.0, res["person_days"]), res["sick_frac"] * 100.0, res["injured"], res["firewood"], res["houses"], res["cold_house_h"], res["spared"], res["fear"], res["ms"]])
			if spec[0] == 4:
				spring_pop += res["pop"]
				ill_rate += res["sick"] / maxf(1.0, res["person_days"])
			else:
				winter_pop += res["pop"]
				winter_ok = winter_ok and res["pop"] >= 10 and res["bad"] == 0
	check(winter_ok, "겨울(온대 1월 30일) 10일: 마을이 망하지 않는다 (처음 10명 이상 남음, 값 정상)")
	# 시드 3개로는 봄·겨울 인구 차이가 우연(±5명)보다 작다 → 비교는 정보로만 출력 (2026-11-06, 메인 세션)
	print("  info 봄 평균 인구 %.1f · 겨울 평균 인구 %.1f" % [spring_pop / seeds.size(), winter_pop / seeds.size()])
	var r := ill_rate / seeds.size()
	if not quick:     # 빠른 모드는 시드 1개·10일이라 앓는 사람이 0~3명 — 비율 판정은 전체 모드에서만
		check(r > 0.001 and r < 0.03, "봄 마을 발병 하루 %.3f (기본 0.01 × 배율·전염)" % r)
