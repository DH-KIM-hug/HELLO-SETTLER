## v4.0 — 영역·자율 건설·소원·길·제물·장터·분가 테스트 (tests/run.gd가 부름: 전체·quick·`-- economy`).
## 기획서 3.1 · 6.7 · 11.1, RESIDENT_AI 2.1 · 6.2, BALANCE v3.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []           # 오래 걸리는 통계 시험 — run.gd의 long·전체 모드에서만 (quick은 건너뜀)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	Market.today_override = "시험날"
	run.timed(self, ["test_market_saturation", "test_territory", "test_chief_autonomous", "test_wish", "test_offerings", "test_forced_taking", "test_buy_building", "test_footpath", "test_split", "test_v5_food_gift_altar"])
	Market.today_override = ""
	Market.reset()


static func lab(seed_v := 3) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.step_dt = 30.0
	return v


## BALANCE v5: 밀은 날로 못 먹음(죽 ×0.75) · 빵 사슬 · 거인이 준 몫은 제물로 안 나감 · 제단 크기 · 설계도로 아는 건물
func test_v5_food_gift_altar() -> void:
	print("== v5 — 죽·빵 · 거인이 준 몫 · 제단 크기 · 설계도")
	Market.reset(10000.0)
	var v := lab(21)
	for k: String in Balance.FOODS:
		v.stock[k] = 0.0
	v.manna.clear()
	v.manna_batches.clear()
	v.stock["밀"] = 100.0
	var left := v.consume_unmet(30.0)
	check(left < 1e-6 and is_equal_approx(float(v.stock["밀"]), 60.0) and not ("밀" in Balance.FOODS),
		"밀은 날로 못 먹는다 — 죽으로 끓이면 밀 40 → 먹을 것 30 (×%.2f)" % Balance.PORRIDGE_YIELD)
	check(is_equal_approx(v.food_total(), 60.0 * Balance.PORRIDGE_YIELD), "먹을 것 합 = 밀 × %.2f (%.1f)" % [Balance.PORRIDGE_YIELD, v.food_total()])
	check(float(Balance.B["화덕"]["out"]["빵"]) == Balance.BREAD_YIELD and Balance.BREAD_YIELD >= 2.0 * Balance.PORRIDGE_YIELD and Balance.label("화덕") == "공용 화덕"
		and int(Balance.B["맷돌간"]["era"]) == 0 and int(Balance.B["화덕"]["era"]) == 0 and String(Balance.B["방앗간"]["replaces"]) == "맷돌간" and String(Balance.B["빵집"]["replaces"]) == "화덕",
		"빵 사슬: 맷돌간·공용 화덕은 개척기부터 (밀 1 → 가루 1 → 빵 %.1f = 죽의 두 배) · 방앗간·빵집이 넓혀 지음" % Balance.BREAD_YIELD)
	check(float(Balance.SPOIL_DAY["빵"]) < float(Balance.SPOIL_DAY["밀"]) * 0.25 and float(Balance.PRICE["빵"]) > 3.0 * float(Balance.PRICE["밀"]),
		"빵은 오래 간다 (하루 %.1f%% vs 밀 %.0f%%) · 제물 값 ×%.1f" % [100.0 * float(Balance.SPOIL_DAY["빵"]), 100.0 * float(Balance.SPOIL_DAY["밀"]), float(Balance.PRICE["빵"])])
	# 거인이 준 몫은 제물로 되돌아가지 않는다 (가격 연구 3장 ⑥ — 되팔기 막기)
	var g := lab(22)
	g.add_building("농장", 12.0, 12.0, true)
	g.add_building("나무꾼", -12.0, 12.0, true)
	g.stock["통나무"] = 200.0
	Production.gift_add(g, "통나무", 200.0)
	g.stock["설탕"] = 3000.0
	Production.gift_add(g, "설탕", 3000.0)
	var sp := g.surplus()
	check(not sp.has("통나무") and not sp.has("설탕"), "하늘에서 내려와 나른 통나무·설탕은 남는 물건이 아니다 (%s)" % str(sp))
	g.stock["통나무"] = 260.0
	check(float(g.surplus().get("통나무", 0.0)) <= 60.0 - (g.enough("통나무") * Balance.OFFER_KEEP) + 1.0, "마을이 스스로 벤 몫만 남는 물건 (%.0f)" % float(g.surplus().get("통나무", 0.0)))
	Production.gift_add(g, "밀", 50.0)
	Production.gift_move(g, "밀", 50.0)
	Production.gift_move(g, "밀가루", 20.0)
	check(is_equal_approx(float(g.gift.get("밀가루", 0.0)), 30.0) and is_equal_approx(float(g.gift.get("빵", 0.0)), 20.0 * Balance.BREAD_YIELD),
		"가공하면 거인 몫도 따라감 (밀 50 → 가루 50 → 빵 %.0f)" % (20.0 * Balance.BREAD_YIELD))
	# 제단 크기 (SAVE.md 3.1)
	var a := lab(23)
	check(Altar.slots(a) == 1 and Altar.next(a)["cost"] == Balance.ALTAR_COST[0], "처음 돌무더기 제단 = 반나절치 (기도 1번) · 넓히기 %.0f" % Balance.ALTAR_COST[0])
	var n0 := Market.notes
	check(Altar.expand(a) and a.altar_level == 1 and Altar.slots(a) == 2 and Altar.rebuilding(a) and is_equal_approx(n0 - Market.notes, Balance.ALTAR_COST[0]),
		"넓히면 판석 제단 = 하루치 · 주민이 다시 쌓는 중 (지폐 %.0f)" % (n0 - Market.notes))
	check(String(Altar.next(a)["lock"]) != "", "다시 쌓는 동안·시대가 이르면 더 못 넓힘 (%s)" % Altar.next(a)["lock"])
	var b := through(a)
	check(b.altar_level == 1, "제단 단계는 저장된다")
	# 설계도 · 처음엔 우물을 모름 (스스로 깨치거나 설계도)
	var w := lab(24)
	check(not VillageEra.can_build(w, "우물") and VillageEra.can_build(w, "맷돌간") and VillageEra.can_build(w, "화덕"), "처음엔 우물을 모른다 — 맷돌간·공용 화덕은 안다")
	Production.give_blueprint(w, "우물")
	check(VillageEra.can_build(w, "우물") and w.count_type("우물") == 1 and w.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("그림 종이")),
		"설계도 → 지을 줄 알고 촌장이 곧바로 터를 잡음")
	check(through(w).blueprints.has("우물"), "받은 설계도는 병에 저장된다")
	Market.reset()


static func through(v: Village) -> Village:
	return Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))


## 같은 물건 MARKET_HALF개째에 반값 — 현실 하루, 모든 병 합산 (BALANCE v3-2 · v5: 60 → 600개 — 병 하루가 현실 5분이라 하루에 병 10일치가 팔림)
func test_market_saturation() -> void:
	print("== 장터 값 · 포화 (BALANCE v3-1·v3-2 · v5 반값 %d개)" % int(Balance.MARKET_HALF))
	Market.reset()
	var hh := int(Balance.MARKET_HALF)
	check(is_equal_approx(Market.unit_price("빵", 1), 3.2), "빵 첫 개 3.2지폐")
	check(is_equal_approx(Market.unit_price("빵", hh + 1), 1.6), "%d번째 단가 = 반값 (%.3f)" % [hh + 1, Market.unit_price("빵", hh + 1)])
	var got := Market.sell("빵", hh)
	check(is_equal_approx(Market.quote("빵", 1), 1.6) and Market.notes > 0.0, "%d개를 판 뒤 다음 하나는 1.6 (받은 %.1f지폐)" % [hh, got])
	var sum := 0.0
	for i in 50:
		sum += Market.unit_price("밀", i + 1)
	check(absf(Market.quote("밀", 50) - sum) < 1e-6, "한꺼번에 거둔 값 = 하나씩 거둔 값의 합 (등비 합 %.3f)" % sum)
	check(is_equal_approx(Market.quote("밀", 1), 1.0), "다른 물건은 따로 센다")
	var a := lab(1)
	var b := lab(2)
	a.add_building("나무꾼", 10.0, 10.0, true)
	b.add_building("나무꾼", 10.0, 10.0, true)
	a.altar.append({"item": "통나무", "amt": hh / 2, "t": a.t, "by": PackedInt32Array([a.people[0].id])})
	b.altar.append({"item": "통나무", "amt": hh / 2, "t": b.t, "by": PackedInt32Array([b.people[0].id])})
	a.take_offering("통나무")
	b.take_offering("통나무")
	check(int(Market.sold["통나무"]) == hh and is_equal_approx(Market.quote("통나무", 1), 0.9), "두 병이 같은 장터 — 합쳐서 %d개 → 다음 단가 반값" % hh)
	Market.today_override = "다음날"
	check(is_equal_approx(Market.quote("빵", 1), 3.2), "현실 날짜가 바뀌면 값이 돌아온다")
	Market.today_override = "시험날"
	Market.reset()


## 영역 (기획서 3.1): 시대별 지름 64/96/140/200 → 약 40/90/225/560명, 영역 밖에는 짓지 않고, 땅이 차면 새 집 없음 → 출산 멈춤, 분가 편지
func test_territory() -> void:
	print("== 부락 영역 (기획서 3.1)")
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	var caps: Array = []
	for e in 4:
		v.era = e
		caps.append(roundi(v.land_capacity()))
	v.era = 0
	check(is_equal_approx(v.territory_r(), 32.0) and caps[0] == 40 and caps[1] == 90 and abs(caps[2] - 225) <= 2 and abs(caps[3] - 560) <= 2,
		"영역 반지름 32 · 품는 인구 %s (약 40/90/225/560)" % str(caps))
	var p := Village.new_prototype(1)
	p.era = 2
	check(is_equal_approx(p.territory_r(), Village.R), "소형 병은 대지보다 넓을 수 없다 (%.0f)" % p.territory_r())
	# 사람이 넘치는 마을: 자재를 넉넉히 주고 촌장이 지을 수 있는 만큼 짓게 한다 (터는 바로 완공)
	v.water.offline = true
	for k in ["판자", "돌"]:
		v.stock[k] = 5000.0
	v.stock["도구"] = 200.0
	for i in 50:
		var a := v.add_person("이주%d" % i, "m" if i % 2 == 0 else "f", 6.0 + (i % 10), "", v.fire.x, v.fire.y, null, null)
		a.belief = 0.7
	var ps := v.people.filter(func(q: Resident) -> bool: return q.partner < 0 and q.age >= Balance.AGE_ADULT and q.age < 16.0)
	var men := ps.filter(func(q: Resident) -> bool: return q.sex == "m")
	var women := ps.filter(func(q: Resident) -> bool: return q.sex == "f")
	for i in mini(men.size(), women.size()):
		v.marry(men[i], women[i])
	for round_i in 120:
		v.chief_build()
		for b in v.buildings:
			if b.is_site():
				for k in ["판자", "돌"]:
					b.delivered[k] = b.need(k)
				v.on_built(b)
		v.assign_jobs()
		v.assign_homes()
	var outside := 0
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(v.center) + b.size() > v.territory_r() + 1e-3:
			outside += 1
	var homeless := v.people.filter(func(q: Resident) -> bool: return q.home < 0 and q.age >= Balance.AGE_ADULT).size()
	print("  인구 %d · 품는 인구 %.0f · 집 %d채 정원 %d · 건물 %d · 집 없는 어른 %d" % [v.people.size(), v.land_capacity(), v.houses().size(), v.house_capacity(), v.buildings.size(), homeless])
	check(outside == 0, "모든 건물이 영역 안 (밖 %d)" % outside)
	check(v.house_capacity() <= v.land_capacity() * Balance.HOUSE_SLACK + 0.01 and homeless > 0, "땅이 차면 새 집을 짓지 않는다 (정원 %d ≤ %.0f × 1.1, 집 없는 어른 %d)" % [v.house_capacity(), v.land_capacity(), homeless])
	# 집이 모두 꽉 찼으면 아이를 낳지 않는다 (집 크기 병목 = 영역 병목)
	var room := 0
	var occ := v.occupancy()
	for h in v.houses():
		room += h.cap() - int(occ.get(h.id, 0))
	var born0: int = v.stats["born"]
	if room == 0:
		for d in 3:
			v._births(Balance.DAY)
	check(room == 0 and v.stats["born"] == born0, "집이 모두 꽉 참 (빈자리 %d) → 3일 동안 출생 없음" % room)
	# 분가 편지: 90% 넘게 하루 이상
	v._check_split()
	check(v.open_letters("split").is_empty(), "찬 지 하루가 안 되면 편지 없음")
	v.t += Balance.DAY + 60.0
	v._check_split()
	var sl := v.open_letters("split")
	check(sl.size() == 1 and String(sl[0]["text"]).contains("새 땅"), "영역 %.0f%% → 하루 뒤 분가 편지 '%s'" % [v.territory_full() * 100.0, sl[0]["text"] if not sl.is_empty() else "-"])


## 촌장은 거인이 있든 없든 짓는다 — 터 지정·자율 건설 버튼 없음 (기획서 6.7)
func test_chief_autonomous() -> void:
	print("== 자율 건설 — 거인의 입력 없이 (기획서 6.7)")
	check(not ("auto_build" in Village.new()), "[주민 자율 건설] 끄는 값이 없다")
	for watched: bool in [true, false]:
		var v := lab(4)
		v.watching = watched
		var b0 := v.buildings.size()
		v.advance(20.0 * Balance.HOUR)          # (A28) 첫 한 시간 걸음 덤이 없어져 첫 터들이 늦게 섬 — 예전 12시간
		var built := v.buildings.filter(func(b: Building) -> bool: return b.built).size()
		check(v.buildings.size() >= b0 + 4 and built >= 4, "%s 20시간: 촌장이 터 %d곳을 잡고 %d채 완공" % ["거인이 볼 때" if watched else "거인이 없을 때", v.buildings.size() - b0, built - 1])


## 소원 편지 (기획서 6.7): v5 — 병 1.5~3일에 한 통 (병 하루 = 현실 5분이라 현실 하루 3~6통), 들어주면 믿음↑ · 우선순위 맨 위 · 짓는 속도 ×1.5
func test_wish() -> void:
	print("== 소원 편지 (기획서 6.7)")
	var v := lab(5)
	v.advance(6.0 * Balance.DAY)
	var wl := v.letters.filter(func(l: Dictionary) -> bool: return l["kind"] == "wish")
	var per_day := {}
	for l: Dictionary in wl:
		var d := v.cal_day(float(l["t"]))
		per_day[d] = int(per_day.get(d, 0)) + 1
	var most := 0
	for d: int in per_day:
		most = maxi(most, int(per_day[d]))
	check(wl.size() >= 2 and wl.size() <= 6 and most <= 2, "6일 동안 소원 편지 %d통, 하루 많아야 %d통 (병 1.5~3일에 한 통 — v5)" % [wl.size(), most])
	var texts: Array = []
	for l: Dictionary in wl:
		texts.append(l["text"])
	check(run.words_ok(texts) == "", "편지에 금지어 없음 %s" % run.words_ok(texts))
	# 새 마을: 우물 소원을 들어주면 다음 터가 우물, ×1.5
	var w := lab(6)
	w.advance(2.0 * Balance.HOUR)
	for b in w.buildings:          # 짓던 터는 끝낸 걸로 (우선순위만 보려고)
		if b.is_site():
			for k in ["판자", "돌"]:
				b.delivered[k] = b.need(k)
			w.on_built(b)
	w.stock["판자"] = 40.0
	w.stock["돌"] = 20.0
	var l := w.write_wish("우물")
	var f0 := w.faith
	check(w.grant_wish(int(l["id"])) and l["state"] == "granted", "[들어준다]")
	check(w.faith > f0 + 2.0, "믿음↑ (%.1f → %.1f)" % [f0, w.faith])      # (2026-11-09) 터를 끝낸 순간 첫 아기가 태어나 (Village.on_built) 평균이 조금 묽어짐 — 1.0에 닿은 믿음도 있음
	w.chief_build()
	var site: Building = null
	for b in w.buildings:
		if b.is_site():
			site = b
	check(site != null and site.type == "우물" and site.wished, "촌장이 우물 터부터 잡는다 (%s)" % (site.type if site != null else "-"))
	var other := Building.new()
	other.type = "나무꾼"
	check(site != null and is_equal_approx(w.build_mult(site), 1.5) and is_equal_approx(w.build_mult(other), 1.0), "소원 건물 짓는 속도 ×1.5")
	# 실제로 지어지는 시간: 같은 우물을 소원 없이 vs 소원으로
	var times: Array = []
	for wished: bool in [false, true]:
		var u := lab(6)
		u.chief_off = true
		u.advance(2.0 * Balance.HOUR)
		u.step_dt = 1.0
		var b := u.add_building("우물", -6.0, 8.0, false)
		b.wished = wished
		for k in ["판자", "돌"]:
			b.delivered[k] = b.need(k)
		var t0 := u.t
		while not b.built and u.t - t0 < 6.0 * Balance.HOUR:
			u.advance(5.0)
		times.append(u.t - t0)
	print("  우물 짓기: 보통 %.0f초 · 소원 %.0f초 (일 60초)" % [times[0], times[1]])
	check(times[1] < times[0], "소원 우물이 더 빨리 완공 (%.0f < %.0f초)" % [times[1], times[0]])


## 제물 (기획서 11.1): 남는 물건 × (0.3 + 0.7 × 믿음), 제단에는 이틀치까지, 받으면 지폐·좋아하시는 것
func test_offerings() -> void:
	print("== 제물 (기획서 11.1)")
	Market.reset()
	var got: Array = []
	for belief: float in [0.0, 1.0]:
		var v := lab(7)
		v.add_building("나무꾼", 12.0, 12.0, true)
		v.stock["통나무"] = 50.0
		for p in v.people:
			p.belief = belief
		v._update_belief(0.0)
		var sp := float(v.surplus().get("통나무", 0.0))
		var budget := v.people.size() * Balance.OFFER_VALUE_PER * 0.5 * v.offer_factor()
		var want := mini(floori(sp * Balance.OFFER_SHARE * v.offer_factor("통나무")), floori(budget / Balance.PRICE["통나무"]))
		var o := int(v.evening_offering().get("통나무", 0))
		check(o == want, "믿음 %.0f: 남는 통나무 %.0f × ½(아침·저녁) × 비율 · 값의 상한(사람 수 × %.0f) → %d개 (예상 %d)" % [belief, sp, Balance.OFFER_VALUE_PER, o, want])
		got.append(o)
	check(int(got[0]) >= 1 and int(got[1]) > int(got[0]) * 2, "믿음이 깊을수록 더 바친다 — 믿음 0: %d개 · 믿음 1: %d개 (v5: 넉넉함이 인구에 맞게 늘고 기도는 아침·저녁 두 번)" % [got[0], got[1]])
	var full := lab(8)
	full.add_building("나무꾼", 12.0, 12.0, true)
	full.stock["통나무"] = 50.0
	full.evening_offering()
	full.t += 0.5 * Balance.DAY
	full.stock["통나무"] = 50.0
	check(Altar.slots(full) == 1 and full.evening_offering().is_empty() and full.stock["통나무"] == 50.0,
		"돌무더기 제단(1단계)은 기도 한 번치만 — 가득 차면 남는 것은 창고에 그대로 (SAVE.md 3.1 v5)")
	var v := lab(8)
	v.add_building("나무꾼", 12.0, 12.0, true)
	v.altar_level = 3                    # 작은 사당 (사흘치) — 이틀 지난 제물이 창고로 돌아가는 규칙만 본다
	var counts: Array = []
	for d in 4:
		v._expire_offerings()           # 이틀 지난 제물은 창고로 (그다음 창고를 같은 양으로 맞춤)
		v.stock["통나무"] = 50.0
		v.evening_offering()
		counts.append(int(v.altar_items().get("통나무", 0)))
		v.t += Balance.DAY
	var one: int = counts[0]
	check(counts[1] == 2 * one and counts[2] == 2 * one and counts[3] == 2 * one and v.altar.size() == 2,
		"제단에는 이틀치까지 — 날마다 %s (오래된 제물은 창고로)" % str(counts))
	check(v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("되돌렸다")), "연대기: 받지 않으신 제물을 되돌림")
	var nobld := lab(9)
	nobld.stock["도구"] = 200.0
	check(nobld.evening_offering().is_empty(), "만드는 일터가 없는 물건(도구·건량)은 바치지 않는다")
	# 받기
	var bel := 0.0
	for p in v.people:
		bel += p.belief
	var n0 := Market.notes
	var take := v.take_offering("통나무")
	var bel1 := 0.0
	for p in v.people:
		bel1 += p.belief
	check(take > 0.0 and is_equal_approx(Market.notes - n0, take) and v.altar.is_empty(), "[받기] → %.1f지폐" % take)
	check(bel1 > bel, "바친 사람 믿음↑")
	v.stock["통나무"] = 50.0
	v.evening_offering()
	v.take_all()
	check(v.is_favourite("통나무") and v.enough("통나무") > Balance.ENOUGH["통나무"], "받은 물건은 '좋아하시는 것' → 더 만든다 (넉넉함 %.0f)" % v.enough("통나무"))
	# 좋아하시는 물건의 일터를 먼저 짓는다
	v.chief_off = true
	check(v._fav_want() == "나무꾼", "촌장 우선순위에 좋아하시는 물건의 일터 (%s)" % v._fav_want())
	# 굶주리는 마을은 식량을 바치지 않는다 (두려움이 높으면 바친다)
	var s := lab(10)
	s.add_building("농장", 12.0, 12.0, true)
	s.stock["밀"] = 2000.0
	s.deficit = 0.5
	s.last_short_t = s.t
	check(not s.evening_offering().has("밀"), "굶주리면 식량을 바치지 않는다")
	for p in s.people:
		p.fear = 0.8
	s.recalc_fear()
	check(s.evening_offering().has("밀"), "두려움이 높으면 굶으면서도 바친다")
	Market.reset()


## 강제로 거두기 (기획서 11.1): 100지폐어치마다 믿음 −0.01 · 두려움 +0.02, 굶주릴 때 식량이면 ×3
func test_forced_taking() -> void:
	print("== 강제로 거두기 (기획서 11.1)")
	Market.reset()
	var v := lab(11)
	v.stock["도구"] = 200.0
	var b0 := v.people[0].belief
	var f0 := v.fear
	var warn := v.force_preview("도구", 100)
	var worth := v.force_take("도구", 100)
	var k := worth / 100.0
	print("  도구 100개 → %.0f지폐 · 믿음 %.3f → %.3f · 두려움 %.2f → %.2f · 경고 '%s'" % [worth, b0, v.people[0].belief, f0, v.fear, warn])
	check(absf((b0 - v.people[0].belief) - 0.01 * k) < 1e-4, "믿음 −0.01 × %.1f (100지폐마다)" % k)
	check(absf((v.fear - f0) - 2.0 * k) < 0.05, "두려움 +0.02 × %.1f (마을 0~100으로 +%.1f)" % [k, v.fear - f0])
	check(warn.contains("두려움"), "거두기 전에 마을에 생기는 일을 보여 준다")
	# 굶주릴 때 식량 ×3
	var s := lab(11)
	s.deficit = 0.5
	s.last_short_t = s.t
	var sb0 := s.people[0].belief
	var w2 := s.force_take("건량", 100)
	var drop := sb0 - s.people[0].belief
	check(absf(drop - 0.01 * w2 / 100.0 * 3.0) < 1e-4, "굶주릴 때 식량이면 ×3 (믿음 −%.4f, %.0f지폐어치)" % [drop, w2])
	check(s.force_preview("건량", 200).contains("굶주리는"), "경고: '%s'" % s.force_preview("건량", 200))
	var lines: Array = []
	for e: Dictionary in s.book:
		lines.append(e["text"])
	for p in s.people:
		lines.append(p.say)
	check(run.words_ok(lines) == "", "연대기·말에 금지어 없음 %s" % run.words_ok(lines))
	Market.reset()


## 건물 사 주기 (기획서 6.7 · RESIDENT_AI 2.1): v5 — 다 지은 건물이 내려오는 것은 소원의 [하늘에서 내려 주기] (설계도 값 × 2.5 = 우물 500)
func test_buy_building() -> void:
	var cost := float(Balance.SHOP["우물"]) * Balance.WISH_DROP_MULT
	print("== 건물 사 주기 (우물 %.0f지폐 — 소원의 기적)" % cost)
	Market.reset(cost - 100.0)
	var v := lab(12)
	check(v.buy_building("우물") == null, "지폐가 모자라면 못 산다 (%.0f < %.0f)" % [cost - 100.0, cost])
	Market.notes = cost + 100.0
	v._update_belief(0.0)
	var f0 := v.faith
	var b := v.buy_building("우물")
	check(b != null and b.built and b.bought and is_equal_approx(Market.notes, 100.0) and v.blueprints.has("우물"), "우물이 완성된 채 내려옴 · 남은 지폐 %.0f · 짓는 법도 앎" % Market.notes)
	check(v.faith > f0 + 5.0 and v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("하늘에서 우물이")), "기적 — 믿음↑ (%.1f → %.1f)" % [f0, v.faith])
	Market.reset()


## 길은 발길이 만든다 (기획서 6.7): 자주 밟은 칸은 흙길(걸음 빠름), 안 다니면 옅어짐
func test_footpath() -> void:
	print("== 발길이 만든 길 (기획서 6.7)")
	var v := lab(13)
	var r := v.people[0]
	var a := Vector2(-20.0, -10.0)
	var b := Vector2(-14.0, -10.0)
	var mid := a.lerp(b, 0.5)
	var side := mid + Vector2(0.0, 3.0)
	check(not v.is_road(mid.x, mid.y), "처음엔 길 없음")
	r.x = a.x
	r.y = a.y
	r.steps.clear()
	for i in 12:
		r.steps.append(ResidentAI.walk(b.x, b.y))
		r.steps.append(ResidentAI.walk(a.x, a.y))
	r.steps.append(ResidentAI.act(1.0e9, "idle"))      # 다 걸으면 그 자리에 선다 (다른 행동을 고르지 않게)
	var n := 0
	while r.steps.size() > 1 and n < 60000:             # v5: 걸음이 현실 사람 걸음 (병 초로 240배 느림)
		ResidentAI.update(v, r, 10.0)       # 몰아서 계산하는 긴 걸음 (10초)에도 길이 끊기지 않는다
		n += 1
	print("  24번 오간 뒤 길 값 %.1f (기준 %.0f) · 옆 칸 %.1f" % [v.path_at(mid.x, mid.y), Balance.PATH_AT, v.path_at(side.x, side.y)])
	check(v.is_road(mid.x, mid.y) and v.is_road(a.lerp(b, 0.23).x, a.lerp(b, 0.23).y), "자주 걸은 칸이 흙길이 된다")
	check(not v.is_road(side.x, side.y), "옆 칸은 그대로")
	check(v.path_mult(mid.x, mid.y) > 1.0, "흙길 위 걸음 ×%.2f" % v.path_mult(mid.x, mid.y))
	var p0 := v.path_at(mid.x, mid.y)
	r.x = 0.0
	r.y = 0.0
	r.steps.clear()
	v.advance(18.0 * Balance.HOUR)
	check(v.path_at(mid.x, mid.y) < p0 * 0.2 and not v.is_road(mid.x, mid.y), "안 다니면 옅어진다 (%.1f → %.1f)" % [p0, v.path_at(mid.x, mid.y)])


## 분가 (기획서 3.1 · 13.1): 젊은 부부 1~3쌍과 아이들이 새 땅에 새 무리 (영역 64칸)
func test_split() -> void:
	print("== 분가 — 새 무리 (기획서 3.1 · 13.1)")
	var jw := JarWorld.create(5, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.water.offline = true
	v.step_dt = 30.0
	for i in 4:                      # 젊은 부부 넷 (+ 아이 하나씩)
		var m := v.add_person("신랑%d" % i, "m", 7.0 + i, "", v.fire.x, v.fire.y, null, null)
		var f := v.add_person("신부%d" % i, "f", 6.0 + i, "", v.fire.x, v.fire.y, null, null)
		v.marry(m, f)
		var kid := v.add_person("아기%d" % i, "f", 1.5, "", v.fire.x, v.fire.y, f, m)
		kid.parents = PackedInt32Array([f.id, m.id])
	v.assign_homes()
	var movers := v.split_movers()
	var n0 := v.people.size()
	var spot: Variant = jw.split_spot(v)
	check(spot != null, "가까운 좋은 자리 %s" % str(spot))
	var nv := jw.split_out(v, (spot as Vector2).x, (spot as Vector2).y)
	check(nv != null and jw.settlements.size() == 2 and nv.people.size() == movers.size() and v.people.size() == n0 - movers.size(),
		"%d명이 떠나 새 무리 (남은 %d명)" % [movers.size(), v.people.size()])
	var couples := 0
	for p in nv.people:
		if p.sex == "f" and p.partner >= 0:
			couples += 1
	check(couples >= 1 and couples <= 3 and nv.people.any(func(p: Resident) -> bool: return p.is_child()), "젊은 부부 %d쌍 + 아이들" % couples)
	check(nv.met.has(v.sid) and v.met.has(nv.sid) and is_equal_approx(nv.territory_r(), 32.0), "서로 아는 사이로 시작 · 새 영역 64칸")
	check(not movers.any(func(p: Resident) -> bool: return v.person(p.id) != null) and movers.all(func(p: Resident) -> bool: return nv.person(p.id) == p), "옛 마을 명부에서 빠지고 새 무리 명부로")
	jw.advance(6.0 * Balance.HOUR)
	var bad := v.check_invariants()
	bad.append_array(nv.check_invariants())
	check(bad.is_empty() and nv.buildings.size() >= 2, "6시간 뒤 두 무리 모두 정상 · 새 무리가 터를 잡음 (건물 %d) %s" % [nv.buildings.size(), "" if bad.is_empty() else str(bad.slice(0, 3))])
