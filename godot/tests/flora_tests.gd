## 하늘의 것 — 큰 버섯 · 큰 민들레 · 첫 제물 웃돈 · 밀의 넉넉한 양 (WORLD_EVENTS 1.1 · 2.6 · 2.7, BALANCE v4-4 · OPENING T2~T4).
## tests/run.gd가 부름 (`-- flora` = 이것만, 1분 안). 확률은 고르는 함수를 직접 많이 불러 재고, 한살이·꽃씨는 Flora 걸음만 돌린다 (빠름).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const H := Balance.HOUR
const D := Balance.DAY
var texts: Array = []                 # 금지어 확인용 (연대기·말)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 하늘의 것 — 큰 버섯 · 큰 민들레 · 첫 제물 · 밀 (WORLD_EVENTS 2.6 · 2.7, BALANCE v4-4)")
	Market.today_override = "시험날"
	run.timed(self, ["test_shroom_where", "test_grove_and_growth", "test_picker", "test_poison_skill", "test_poison_eat", "test_shade_cotton",
		"test_sky_trust", "test_dand_lifecycle", "test_dand_winter", "test_seeds_to_shade", "test_weeds", "test_blow", "test_ride",
		"test_first_offering", "test_wheat_bounded", "test_determinism", "test_words"])
	Market.today_override = ""
	Market.reset()


static func village(climate := "온대", month := 4, day := 15, seed_v := 5) -> Village:
	var keep := Village.default_created
	Village.default_created = {"year": 2026, "month": month, "day": day}
	var v := Village.new_prototype(seed_v)
	Village.default_created = keep
	v.climate_override = climate
	v.water.offline = true
	return v


## 첫 걸음 (공기·꽃 자리를 정함) 뒤의 마을
static func settled(climate := "온대", month := 4, seed_v := 5) -> Village:
	var v := village(climate, month, 15, seed_v)
	v.step(1.0)
	return v


func _keep_texts(v: Village) -> void:
	for e: Dictionary in v.book:
		texts.append(e["text"])
	for p in v.people:
		texts.append(p.say)
		texts.append(p.doing)


## 땅 위 자리들의 볕 평균 (비교용)
static func land_sun(v: Village) -> float:
	var s := 0.0
	var n := 0
	for i in 600:
		var a := i * 2.39996
		var r := sqrt((i + 0.5) / 600.0) * (v.water.radius() - 3.0)
		var p := Vector2(cos(a), sin(a)) * r
		if v.water_at(p.x, p.y):
			continue
		s += v.water.sun_at(p.x, p.y)
		n += 1
	return s / n


# ───────────────────────── 큰 버섯 ─────────────────────────
## 습한 병에서는 축축한 자리(그늘·물가·숲 바닥)에만, 마른 병에서는 나지 않는다
func test_shroom_where() -> void:
	var v := settled("열대")
	var f := v.flora
	v.t = 2.0 * D
	for i in 60:
		f._spawn_single(v, D, 0.75)
	var n := f.live_shrooms()
	var ok := true
	var sun := 0.0
	var worst := 9.0
	for s: Dictionary in f.shrooms:
		var dm := f.damp_at(v, s["x"], s["y"])
		worst = minf(worst, dm)
		ok = ok and dm >= Balance.SHROOM_DAMP_MIN and not v.water_at(s["x"], s["y"])
		sun += v.water.sun_at(s["x"], s["y"])
	sun /= maxi(1, n)
	check(n >= 10 and ok, "습한 병: 버섯 %d개 모두 축축한 자리 (가장 마른 자리 축축함 %.2f ≥ %.2f)" % [n, worst, Balance.SHROOM_DAMP_MIN])
	check(sun < land_sun(v) - 0.1, "버섯은 그늘 쪽에 (버섯 자리 볕 %.2f < 땅 평균 %.2f)" % [sun, land_sun(v)])
	var touching := false
	for b in v.buildings:
		for s: Dictionary in f.shrooms:
			if Vector2(b.x - s["x"], b.y - s["y"]).length() < b.size() + 0.8:
				touching = true
	check(not touching and n <= Balance.SHROOM_MAX, "집 위에 나지 않고 상한 %d개를 넘지 않음" % Balance.SHROOM_MAX)
	var dry := settled("사막")
	dry.t = 2.0 * D
	for i in 60:
		dry.flora._spawn_single(dry, D, dry.air.humid)
	dry.flora._on_dawn(dry)
	check(dry.flora.live_shrooms() == 0 and dry.air.humid < Balance.SHROOM_HUMID_MIN, "마른 병(김 %.2f)에는 버섯이 나지 않는다" % dry.air.humid)
	# 같은 병이라도 김이 기준 아래면 없음
	var v2 := settled("열대")
	v2.t = 2.0 * D
	for i in 60:
		v2.flora._spawn_single(v2, D, Balance.SHROOM_HUMID_MIN - 0.01)
	check(v2.flora.live_shrooms() == 0, "김이 %.2f 아래면 열대 병에도 없음" % Balance.SHROOM_HUMID_MIN)
	# 집은 큰 버섯의 대 둘레에 짓지 않는다
	var s0: Dictionary = f.shrooms[0]
	check(not v.is_free(s0["x"], s0["y"], 1.0), "큰 버섯 자리에는 집을 짓지 않음 (is_free)")


## 하나씩 천천히 자라고, 습한 밤 뒤 새벽엔 하룻밤 버섯 숲 · 김이 빠지면 시듦 · 부채버섯은 다시 자람
func test_grove_and_growth() -> void:
	var v := settled("열대", 4, 7)
	var f := v.flora
	v.t = 3.5 * D
	var s := f.add_shroom(v, Vector2(-14, 14), "흰갓버섯")
	var t0 := v.t
	while float(s["g"]) < 1.0 and v.t - t0 < 3.0 * D:
		v.t += 60.0
		f._grow_shrooms(v, 60.0, 0.7)
	check(absf(v.t - t0 - 0.98 * float(Balance.SHROOM["흰갓버섯"]["grow"])) < 120.0, "흰갓버섯은 하루에 걸쳐 다 자람 (%.2f일)" % ((v.t - t0) / D))
	# 습한 밤 → 새벽 버섯 숲
	f.grove_last = -1.0e9
	var before := f.live_shrooms()
	var made := 0
	for i in 20:                      # 확률이 있으니 몇 번 (밤 평균 김 0.72)
		f._night_sum = 0.72 * 400.0
		f._night_n = 400
		f.grove_last = -1.0e9
		var n0 := f.live_shrooms()
		f._on_dawn(v)
		made = f.live_shrooms() - n0
		if made > 0:
			break
	check(made >= Balance.GROVE_N[0] and f.stats["groves"] >= 1, "습한 밤 다음 새벽 '하룻밤 버섯 숲' — 다 자란 버섯 %d개가 한꺼번에 (전 %d)" % [made, before])
	var all_mature := true
	for e: Dictionary in f.shrooms:
		if float(e["born"]) == v.t and float(e["g"]) < 1.0:
			all_mature = false
	check(all_mature and v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("집채만 한 버섯이 솟았다")), "솟은 버섯은 다 자란 채 · 연대기 '밤새 … 집채만 한 버섯이 솟았다'")
	var dry := settled("열대", 4, 8)
	dry.t = 4.0 * D
	dry.flora._night_sum = 0.3 * 400.0
	dry.flora._night_n = 400
	dry.flora._on_dawn(dry)
	check(dry.flora.live_shrooms() == 0, "마른 밤 뒤에는 버섯 숲이 없음")
	# 김이 빠지면 4배 빨리 시듦
	var w1 := settled("열대", 4, 9)
	w1.t = 4.0 * D
	var a := w1.flora.add_shroom(w1, Vector2(-14, 14), "흰갓버섯", 1.0)
	var b := w1.flora.add_shroom(w1, Vector2(14, -14), "흰갓버섯", 1.0)
	var tw := 0.0
	while not a["gone"] and tw < 6.0 * D:
		tw += 60.0
		w1.t += 60.0
		w1.flora._grow_shrooms(w1, 60.0, 0.3)
	check(a["gone"] and absf(tw - Balance.SHROOM_LIFE / 4.0) < 300.0 and b["gone"], "김이 빠진 병(뚜껑): 다 자란 버섯이 %.2f일 만에 시듦 (보통 %.0f일)" % [tw / D, Balance.SHROOM_LIFE / D])
	# 부채버섯: 다 베면 밑동에서 다시
	var fan := w1.flora.add_shroom(w1, Vector2(-10, 18), "부채버섯", 1.0)
	fan["food"] = 0.0
	w1.flora._spent(fan)
	check(not fan["gone"] and float(fan["g"]) < 0.5 and is_equal_approx(float(fan["food"]), 30.0), "부채버섯은 베어도 다시 자란다 (반나절)")


## 버섯꾼: 큰 버섯을 베어 창고로 · 갈색갓버섯은 말림대에서 반나절 → 말린 버섯
func test_picker() -> void:
	var v := settled("열대", 4, 11)
	v.chief_off = true
	v.step_dt = 10.0
	var f := v.flora
	f.trust = true
	v.advance(2.0 * H)                 # 09:00
	var hut := v.add_building("버섯꾼", -6.0, 8.0, true)
	var near := [Vector2(-9.5, 10.5), Vector2(-3.0, 12.0)]
	f.add_shroom(v, near[0], "흰갓버섯", 1.0)
	var brown := f.add_shroom(v, near[1], "갈색갓버섯", 1.0)
	v.assign_jobs()
	var w := v.person(hut.worker)
	check(w != null, "버섯꾼 일꾼이 정해짐 (%s)" % (w.name if w != null else "-"))
	var food0 := float(v.stock["버섯"])
	v.advance(4.0 * H)
	var got := float(v.stock["버섯"]) - food0
	check(got >= Balance.PICK_CHUNK * 2.0 and f.stats["picked"] >= got, "4시간에 버섯 %.0f개를 베어 창고로 (나무꾼처럼 조각내 나름)" % got)
	check(float(brown["food"]) < 60.0 and f.drying.size() + int(float(f.stats["dried"]) > 0.0) > 0, "갈색갓버섯 조각은 말림대로 (말리는 중 %.0f)" % f.drying_at(hut.id))
	v.advance(Balance.DRY_TIME + 2.0 * H)
	var dried := float(v.stock["말린 버섯"]) + float(hut.out.get("말린 버섯", 0.0))
	check(dried > 0.0 and f.stats["dried"] > 0.0, "반나절 말리면 말린 버섯 %.0f개 (창고·오두막 앞)" % dried)
	_keep_texts(v)


## 독버섯 가려내기: 숙련이 오를수록 얼룩버섯을 섞어 오는 일이 줄어든다
func test_poison_skill() -> void:
	var v := settled("열대", 4, 12)
	var f := v.flora
	f.trust = true
	v.stock["붉은 물감"] = 999.0       # 물감은 넉넉 — 알아보면 피한다
	var hut := v.add_building("버섯꾼", 10.0, -12.0, true)
	f.add_shroom(v, Vector2(12.0, -14.0), "얼룩버섯", 1.0)
	f.add_shroom(v, Vector2(15.0, -18.0), "흰갓버섯", 1.0)
	var r: Resident = null
	for p in v.people:
		if p.is_adult() and not p.is_elder():
			r = p
			break
	var n := 4000 if not quick else 2000
	var rates: Array = []
	for sk: float in [0.0, 4.0, 8.0, 10.0]:
		r.skills["버섯꾼"] = sk
		var mix := 0
		for i in n:
			var c := f.choose(v, r, hut)
			if not c.is_empty() and c[1] == "mix":
				mix += 1
		rates.append(float(mix) / n)
	var exp0 := (1.0 - Balance.POISON_SPOT) * Balance.POISON_MIX_P
	check(absf(float(rates[0]) - exp0) < 0.03, "숙련 0: 얼룩버섯을 섞어 옴 %.3f (기대 %.3f)" % [rates[0], exp0])
	check(float(rates[1]) < float(rates[0]) and float(rates[2]) < float(rates[1]) and float(rates[3]) <= float(rates[2]), "숙련이 오를수록 줄어듦 %s" % str(rates.map(func(x: float) -> String: return "%.3f" % x)))
	check(float(rates[3]) == 0.0, "숙련 10이면 섞어 오지 않음")
	# 마을이 독버섯을 알면 (한 번 탈이 난 뒤) 숙련 0도 덜 섞음
	r.skills["버섯꾼"] = 0.0
	f.poison_known = true
	var mix2 := 0
	for i in n:
		var c := f.choose(v, r, hut)
		if not c.is_empty() and c[1] == "mix":
			mix2 += 1
	check(float(mix2) / n < float(rates[0]) * 0.7, "마을이 얼룩버섯을 안 뒤 숙련 0: %.3f" % (float(mix2) / n))
	# 물감이 모자라면 알아본 얼룩버섯을 일부러 벤다 (붉은 물감)
	v.stock["붉은 물감"] = 0.0
	r.skills["버섯꾼"] = 10.0
	var c2 := f.choose(v, r, hut)
	check(not c2.is_empty() and c2[1] == "dye", "물감이 모자라면 얼룩버섯 → 붉은 물감")


## 섞여 온 얼룩버섯을 먹으면: 배앓이 ×5 (그날) · 아이 중증 ×2 · 한 사람은 바로 탈 · 노인이 알아봄
func test_poison_eat() -> void:
	var v := settled("온대", 4, 13)
	var f := v.flora
	v.stock["건량"] = 0.0
	v.stock["버섯"] = 16.0
	f.tainted = 8.0
	var left := v.consume(8.0)
	check(left == 0.0 and f.tainted < 8.0 and f.poison_until > v.t, "생버섯을 먹으면 섞인 조각도 같은 몫 (남은 독 조각 %.1f)" % f.tainted)
	check(is_equal_approx(Flora.ill_mult(v), Balance.POISON_ILL), "그날 배앓이 ×%.0f" % Flora.ill_mult(v))
	var kid: Resident = null
	var adult: Resident = null
	for p in v.people:
		if p.is_child() and kid == null:
			kid = p
		if p.is_adult() and adult == null:
			adult = p
	check(is_equal_approx(Flora.severe_mult(v, kid, "배앓이"), 2.0) and is_equal_approx(Flora.severe_mult(v, adult, "배앓이"), 1.0) and is_equal_approx(Flora.severe_mult(v, kid, "고뿔"), 1.0), "아이만 중증 ×2 (배앓이)")
	var sick0 := int((v.stats.get("sick_by", {}) as Dictionary).get("배앓이", 0))
	v.t += 1.0
	f._tick(v, 60.0)
	var sick1 := int((v.stats.get("sick_by", {}) as Dictionary).get("배앓이", 0))
	check(sick1 == sick0 + 1 and f.poison_known, "먹은 사람 하나가 바로 배앓이 · 마을이 얼룩버섯을 알게 됨")
	check(v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("흰 점")) and f.tainted == 0.0, "연대기: 노인이 알아봄 · 남은 조각은 골라내 물감으로")
	# 시험: 독을 먹은 날의 배앓이 발병 — Health._hourly가 ×5를 쓴다 (같은 굴림, 배율만 다름)
	var on := 0
	var off := 0
	for trial in 2:
		var hv := settled("온대", 4, 30 + trial)
		for p in hv.people:
			p.immune = {}
		hv.flora.poison_until = 1.0e12 if trial == 0 else -1.0
		var cnt := 0
		for hr in (300 if quick else 600):
			for p in hv.people:
				p.sick_left = 0.0
				p.disease = ""
			Health._hourly(hv, [])
			for p in hv.people:
				if p.sick_left > 0.0 and p.disease == "배앓이":
					cnt += 1
		if trial == 0:
			on = cnt
		else:
			off = cnt
	check(on > off * 3, "독을 먹은 날 배앓이가 훨씬 잦음 (%d vs 보통 %d)" % [on, off])
	_keep_texts(v)


## 큰 갓 아래 그늘 (더위 ×0.6) · 민들레 솜옷 (추위 ×0.8)
func test_shade_cotton() -> void:
	var v := settled("열대", 7, 14)
	var r: Resident = v.people[0]
	r.x = 14.0
	r.y = -14.0
	r.home = -1
	var pr0 := Health.protection(v, r, 1.0)
	v.flora.add_shroom(v, Vector2(14.3, -13.6), "흰갓버섯", 1.0)
	var pr1 := Health.protection(v, r, 1.0)
	check(is_equal_approx(float(pr0[1]), 1.0) and is_equal_approx(float(pr1[1]), Balance.SHROOM_SHADE), "갓 아래 더위 노출 ×%.1f (밖 %.1f)" % [pr1[1], pr0[1]])
	v.stock["솜"] = v.people.size() * Balance.COTTON_PER
	var pr2 := Health.protection(v, r, 0.0)
	check(is_equal_approx(float(pr2[0]), Balance.COTTON_COLD), "솜이 넉넉하면 추위 ×%.1f" % pr2[0])
	v.stock["솜"] = 0.0
	check(is_equal_approx(float(Health.protection(v, r, 0.0)[0]), 1.0), "솜이 없으면 그대로")


## 하늘의 것: 처음엔 두려워하다가 (따지 않음) 하루쯤 지나 담대한 사람이 맛본 뒤 익숙해짐 — 연대기 한 줄
func test_sky_trust() -> void:
	var v := village("온대", 4, 15, 16)
	v.step_dt = 30.0
	v.advance(6.0 * H)
	var f := v.flora
	check(f.seen_t >= 0.0 and not f.trust, "하늘의 것을 알아봄 (%s) · 아직 두려움" % v.fmt_time(f.seen_t))
	var kid: Resident = null
	for p in v.people:
		if p.is_child() and p.age >= 2.5:
			kid = p
	var tried := false
	for i in 50:
		tried = tried or Flora.decide(v, kid)
	check(not tried and float(v.stock["꽃잎"]) == 0.0, "익숙해지기 전엔 따지 않는다")
	v.advance(1.2 * D)
	var lines := v.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("두려워하지 않았다"))
	check(f.trust and lines.size() == 1, "하루쯤 뒤 익숙해짐 — 연대기 한 줄: %s" % (lines[0]["text"] if not lines.is_empty() else "-"))
	v.advance(1.0 * D)
	check(float(f.stats["petals"]) + float(f.stats["cotton"]) > 0.0, "그 뒤로 꽃잎·솜을 딴다 (꽃잎 %.0f · 솜 %.0f)" % [f.stats["petals"], f.stats["cotton"]])
	check(v.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("두려워하지 않았다")).size() == 1, "발견 줄은 한 번뿐")
	_keep_texts(v)


# ───────────────────────── 큰 민들레 ─────────────────────────
## Flora 걸음만 (60초·5초) 돌린다 — 마을의 다른 일은 멈춤 (빠름)
static func flora_run(v: Village, secs: float, on_tick := Callable()) -> void:
	var t_end := v.t + secs
	while v.t < t_end - 1e-6:
		v.t += 5.0
		Flora.step(v, 5.0)
		if on_tick.is_valid():
			on_tick.call()


## 싹 → 노란 꽃 (2일) → 닫힘 (반나절) → 솜털 공 (1일) → 꽃씨 → 3~4일 뒤 새 싹
func test_dand_lifecycle() -> void:
	var v := settled("온대", 4, 17)
	var f := v.flora
	f.dands.clear()
	f.pending.clear()
	var spot := Vector2.ZERO               # 물에서 먼 볕 드는 들판
	for i in 200:
		var a := i * 2.39996
		var p := Vector2(cos(a), sin(a)) * (8.0 + (i % 7) * 2.0)
		if v.water.sun_at(p.x, p.y) > 0.15 and f._dand_ok(v, p) and not f._near_water(v, p, 9.0):
			spot = p
			break
	var d := f._add_dand(v, spot, "sprout")
	var seen := {"sprout": v.t}
	var last := "sprout"
	var landed: Array = []
	var tick := func() -> void:
		if d["st"] != last:
			last = d["st"]
			if not seen.has(last):
				seen[last] = v.t
	flora_run(v, 5.0 * D, tick)
	var ok_order := seen.has("flower") and seen.has("closed") and seen.has("puff") and seen.has("leaf")
	check(ok_order, "싹 → 꽃 → 닫힘 → 솜털 공 → 잎 (%s)" % str(seen.keys()))
	if ok_order:
		var fl := float(seen["closed"]) - float(seen["flower"])
		var cl := float(seen["puff"]) - float(seen["closed"])
		var pf := float(seen["leaf"]) - float(seen["puff"])
		check(absf(fl - 2.0 * D) <= 120.0 and absf(cl - 0.5 * D) <= 120.0 and absf(pf - D) <= 120.0,
			"노란 꽃 %.2f일 · 닫힘 %.2f일 · 솜털 공 %.2f일 (기획 2 · 0.5 · 1)" % [fl / D, cl / D, pf / D])
		check(absf(float(seen["flower"]) - float(seen["sprout"]) - Balance.DAND_SPROUT) <= 120.0, "봄: 싹은 하루 만에 꽃")
	check(int(f.stats["released"]) == Balance.DAND_SEEDS, "솜털 공 하나 = 꽃씨 %d개 날림" % f.stats["released"])
	# 날던 꽃씨가 모두 내려앉고 3~4일 뒤 새 싹
	flora_run(v, 6.0 * D)
	var gaps: Array = []
	for e: Dictionary in f.dands:
		if e.has("landed"):
			gaps.append(float(e["born"]) - float(e["landed"]))
	var gaps_ok := not gaps.is_empty()
	for g: float in gaps:
		gaps_ok = gaps_ok and g >= 3.0 * D - 120.0 and g <= 4.0 * D + 120.0
	check(gaps_ok, "내려앉은 꽃씨가 3~4일 뒤 싹 (%d포기: %s일)" % [gaps.size(), str(gaps.map(func(g: float) -> String: return "%.2f" % (g / D)))])
	check(f.seeds.is_empty() and int(f.stats["landed"]) == int(f.stats["released"]), "날린 꽃씨는 모두 내려앉음 (%d)" % f.stats["landed"])


## 겨울(거인의 방 1월)엔 잎만 — 새 꽃이 피지 않는다. 봄(3~5월)에 가장 많이
func test_dand_winter() -> void:
	var v := settled("온대", 1, 18)
	var f := v.flora
	var flowers := 0
	var tick := func() -> void:
		flowers = maxi(flowers, f.count_st("flower") + f.count_st("closed") + f.count_st("puff"))
	flora_run(v, 6.0 * D, tick)
	check(f.dands.size() >= Balance.DAND_START - 2 and flowers == 0, "1월: 민들레 %d포기 모두 잎만 (꽃 %d)" % [f.dands.size(), flowers])
	var sp := settled("온대", 4, 18)
	var n_sp := sp.flora.count_st("flower") + sp.flora.count_st("closed") + sp.flora.count_st("puff")
	var su := settled("온대", 8, 18)
	var b_sp := sp.flora.bloom_w(sp)
	check(n_sp >= Balance.DAND_START - 2 and b_sp > su.flora.bloom_w(su) * 2.0, "4월엔 처음부터 꽃이 핀 포기 %d · 피는 정도 봄 %.2f > 여름 %.2f" % [n_sp, b_sp, su.flora.bloom_w(su)])


## 닫힌 병엔 바람이 없다: 볕 쪽에서 오르고 그늘 쪽에 내려앉는 둥근 기류 (결정론)
func test_seeds_to_shade() -> void:
	var res: Array = []
	for rep in 2:
		var v := settled("온대", 4, 19)
		var f := v.flora
		f.dands.clear()
		f.pending.clear()
		var rel := 0.0
		var n := 0
		for i in 24:
			var a := i * 2.39996
			var r := 6.0 + (i % 6) * 3.5
			var p := Vector2(cos(a), sin(a)) * r
			if v.water_at(p.x, p.y):
				continue
			var d := f._add_dand(v, p, "puff")
			d["seeds"] = Balance.DAND_SEEDS
			f.release(v, d)
			rel += v.water.sun_at(p.x, p.y) * Balance.DAND_SEEDS
			n += Balance.DAND_SEEDS
		var high := 0.0
		f.land_log = []
		var t0 := v.t
		while not f.seeds.is_empty() and v.t - t0 < Balance.SEED_FLIGHT_MAX + 60.0:
			for s: Dictionary in f.seeds:
				high = maxf(high, float(s["z"]))
			v.t += Balance.SEED_TICK
			f._seed_tick(v, Balance.SEED_TICK)
		var land := 0.0
		var cnt := 0
		for p: Vector2 in f.land_log:
			land += v.water.sun_at(p.x, p.y)
			cnt += 1
		rel /= maxi(1, n)
		land /= maxi(1, cnt)
		res.append([rel, land, cnt, high, f.stats.duplicate(), v.t - t0])
	var r0: Array = res[0]
	check(int(r0[2]) >= 100, "꽃씨 %d개가 모두 내려앉음 (%.0f분)" % [r0[2], float(r0[5]) / 60.0])
	check(float(r0[1]) < float(r0[0]) - 0.25, "꽃씨는 그늘 쪽에 내려앉는다 (볕: 날린 자리 %.2f → 내려앉은 자리 %.2f)" % [r0[0], r0[1]])
	check(float(r0[3]) > Balance.SEED_START_Z + 2.0, "볕 쪽에서는 떠오른다 (가장 높이 %.1f)" % r0[3])
	check(str(res[0]) == str(res[1]), "같은 병이면 꽃씨 길이 똑같다 (난수 없는 기류)")


## 밭에 내려앉은 꽃씨 = 잡초 → 그 밭 ×0.8, 농부가 뽑으면 원래대로 (뽑은 잎은 쓴 나물)
func test_weeds() -> void:
	var outs: Array = []
	for weedy in [false, true]:
		var v := settled("온대", 4, 20)
		v.chief_off = true
		var farm := v.add_building("농장", 8.0, -6.0, true)
		farm.ready_at = 0.0
		farm.worker = v.people[0].id
		if weedy:
			v.flora._land(v, Vector2(farm.x + 0.5, farm.y))
			check(int(v.flora.weeds.get(farm.id, 0)) == 1 and is_equal_approx(Flora.weed_mult(v, farm), Balance.WEED_MULT), "밭에 내려앉은 꽃씨 → 잡초 (×%.1f)" % Flora.weed_mult(v, farm))
		for i in 3600:
			v._update_building(farm, 1.0)
		outs.append(float(farm.out.get("밀", 0.0)))
	check(absf(float(outs[1]) / float(outs[0]) - Balance.WEED_MULT) < 0.04, "한 시간 밀: 잡초 없음 %.0f · 잡초 %.0f (×%.2f)" % [outs[0], outs[1], float(outs[1]) / float(outs[0])])
	# 농부가 뽑는다
	var v2 := settled("온대", 4, 21)
	v2.chief_off = true
	v2.step_dt = 5.0
	v2.advance(2.0 * H)
	var farm2 := v2.add_building("농장", 8.0, -6.0, true)
	farm2.ready_at = 0.0
	v2.assign_jobs()
	var w := v2.person(farm2.worker)
	v2.flora.weeds[farm2.id] = 2
	v2.advance(2.0 * H)
	check(w != null and not v2.flora.weeds.has(farm2.id) and float(v2.stock["민들레 잎"]) >= 4.0, "농부가 잡초를 뽑음 → 쓴 나물 %.0f" % v2.stock["민들레 잎"])
	_keep_texts(v2)


## 거인이 뚜껑을 열고 불기: 솜털 공의 꽃씨가 한꺼번에 · 믿음↑ · "하늘에 눈이 내린다!" · 뚜껑이 닫혀 있으면 못 붊
func test_blow() -> void:
	var v := settled("온대", 4, 22)
	var f := v.flora
	v.advance(3.0 * H)
	var np := mini(6, f.dands.size())
	for i in np:
		f.dands[i]["st"] = "puff"
		f.dands[i]["seeds"] = Balance.DAND_SEEDS
	check(f.blow_seeds(v, Vector2(1, 0)) == -1, "뚜껑이 닫혀 있으면 불 수 없다")
	v.open_lid()
	var b0 := v.faith
	var x0 := 0.0
	var n := f.blow_seeds(v, Vector2(1, 0))
	for s: Dictionary in f.seeds:
		x0 += float(s["x"])
	x0 /= maxf(1.0, f.seeds.size())
	check(np >= 3 and n >= np * Balance.DAND_SEEDS and f.count_st("puff") == 0, "솜털 공 %d포기의 꽃씨 %d개가 한꺼번에" % [np, n])
	check(v.faith > b0 and v.people.any(func(p: Resident) -> bool: return p.say == Balance.BLOW_LINE), "믿음↑ (%.1f → %.1f) · \"%s\"" % [b0, v.faith, Balance.BLOW_LINE])
	for i in 24:
		v.t += Balance.SEED_TICK
		f._seed_tick(v, Balance.SEED_TICK)
	var x1 := 0.0
	var z1 := 0.0
	for s: Dictionary in f.seeds:
		x1 += float(s["x"])
		z1 = maxf(z1, float(s["z"]))
	x1 /= maxf(1.0, f.seeds.size())
	check(x1 > x0 + 3.0 and z1 > Balance.SEED_START_Z + 1.5, "분 쪽으로 날아감 (x %.1f → %.1f, 높이 %.1f)" % [x0, x1, z1])
	check(v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("하늘 가득 꽃씨")), "연대기: 하늘 가득 꽃씨")
	_keep_texts(v)


## 드문 일: 아이가 꽃씨에 매달려 조금 날아갔다가 걸어서 돌아온다 (연대기 한 줄)
func test_ride() -> void:
	var v := settled("온대", 4, 23)
	v.advance(3.0 * H)
	var f := v.flora
	f.trust = true
	var kid: Resident = null
	for p in v.people:
		if p.is_child() and p.age >= 2.5:
			kid = p
	var d: Dictionary = f.dands[0]
	d["st"] = "puff"
	d["seeds"] = 6
	kid.x = float(d["x"]) + 0.6
	kid.y = float(d["y"])
	var from := Vector2(kid.x, kid.y)
	f._start_ride(v, kid, d)
	check(kid.action == "dand_ride" and f.riders.size() == 1, "%s%s 꽃씨에 매달려 떠오름" % [kid.name, Village.josa(kid.name, "이", "가")])
	var top := 0.0
	for i in int(Balance.RIDE_TIME):
		v.step(1.0)
		top = maxf(top, float(f.ride_h.get(kid.id, 0.0)))
	var flew := Vector2(kid.x, kid.y).distance_to(from)
	check(flew >= Balance.RIDE_DIST[0] * 0.5 and top > 3.0 and f.riders.is_empty(), "%.1f칸을 날아 내려앉음 (가장 높이 %.1f)" % [flew, top])
	var t0 := v.t
	while v.t - t0 < 2.0 * H and not v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("꽃씨를 타고")):
		v.step(1.0)
	var line: Array = v.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("꽃씨를 타고"))
	check(not line.is_empty() and Vector2(kid.x, kid.y).distance_to(v.fire) < 4.0, "걸어서 돌아옴 — %s" % (line[0]["text"] if not line.is_empty() else "-"))
	_keep_texts(v)


# ───────────────────────── 첫 제물 · 밀 (BALANCE v4-4) ─────────────────────────
## 보통 시작: 1일차 저녁 첫 기도 → 2일차 아침까지 받으면 지폐 600 이상 → 우물을 사 줄 수 있다 (OPENING T3 → T4)
func test_first_offering() -> void:
	for seed_v in ([1, 2, 3] if not quick else [1, 2]):
		Market.reset()
		var v := Village.new_prototype(seed_v)
		v.water.offline = true
		v.step_dt = 20.0
		v.advance(23.0 * H)                # 2일차 06:00
		var items := v.altar_items()
		var got := v.take_all()
		check(not items.is_empty() and Market.notes >= Balance.SHOP["우물"], "시드 %d: 첫 저녁 기도 제물 %s → 2일차 아침 지폐 %.0f (우물 %d)" % [seed_v, str(items), Market.notes, Balance.SHOP["우물"]])
		if seed_v == 1:
			var well := v.buy_building("우물")
			check(well != null and well.built and Market.notes < Balance.FIRST_OFFER_BONUS, "첫 지폐로 우물을 사 줌")
			v.altar.append({"item": "통나무", "amt": 5, "t": v.t, "by": PackedInt32Array([v.people[0].id])})
			var n0 := Market.notes
			var got2 := v.take_offering("통나무")
			check(got2 < 20.0 and is_equal_approx(Market.notes - n0, got2), "웃돈은 처음 한 번뿐 (다음 제물 %.1f지폐)" % got2)
		_keep_texts(v)
	Market.reset()


## 밀의 넉넉한 양: 농장도 넉넉하면 멈춘다 → 쌓이는 밀·날마다 바치는 밀이 인구에 묶인다 (굶지 않음)
func test_wheat_bounded() -> void:
	Market.reset()
	var v := Village.new_prototype(2)
	v.water.offline = true
	v.step_dt = 30.0
	v.auto_reveal = true
	var worst := 0.0
	var offered: Array = []
	var days := 8 if not quick else 6
	var farmer_rest := false
	for d in days:
		for hh in 24:
			v.advance(H)
			var w := float(v.stock["밀"])
			for b in v.buildings:
				w += float(b.out.get("밀", 0.0))
				if b.type == "농장" and b.worker >= 0 and v.person(b.worker) != null:
					farmer_rest = farmer_rest or not ResidentAI.work_task(v, v.person(b.worker), true)
			worst = maxf(worst, w / v.enough("밀"))
		var it := v.altar_items()
		offered.append(int(it.get("밀", 0)))
		v.take_all()
	var need := v._food_people() * D / Balance.FOOD_IV
	var max_off := 0
	for o: int in offered:
		max_off = maxi(max_off, o)
	check(worst <= 1.3, "밀(창고 + 밭)이 넉넉한 양을 크게 넘지 않음 — 인구가 줄면 기준도 줄어듦 (최대 ×%.2f, 넉넉한 양 %.0f = 인구 %d × %.1f일치)" % [worst, v.enough("밀"), v.people.size(), Balance.FARM_ENOUGH_DAYS])
	check(max_off < 1000 and max_off <= need * 0.35, "날마다 바친 밀 %s — 1,000개 넘게 쌓여 바치지 않음 (하루 먹는 양 %.0f)" % [str(offered), need])
	check(v.stats["starved"] == 0 and v.last_short_t < 0.0, "농장이 멈춰도 굶지 않음")
	check(farmer_rest, "넉넉하면 농부도 일을 쉰다")
	Market.reset()


# ───────────────────────── 결정성 · 말 ─────────────────────────
static func sig(v: Village) -> String:
	var f := v.flora
	var s := "%s|%d|%d|%d|%d|%s|" % [str(v.t), v.people.size(), v.book.size(), f.rng.state, v.rng.state, str(v.stock["버섯"])]
	for e: Dictionary in f.shrooms:
		s += "%s,%s,%s,%s;" % [str(e["x"]), str(e["g"]), str(e["food"]), str(e["res"])]
	for e: Dictionary in f.dands:
		s += "%s,%s,%d;" % [e["st"], str(e["st_t"]), int(e["seeds"])]
	for e: Dictionary in f.seeds:
		s += "%s,%s,%s;" % [str(e["x"]), str(e["y"]), str(e["z"])]
	for p in v.people:
		s += "%s,%s;" % [str(p.x), str(p.y)]
	return s


## ×1과 ×8 — 같은 병 시간이면 버섯·민들레·꽃씨·주민이 똑같다 (걸음은 늘 병 시계 1초)
func test_determinism() -> void:
	var sigs: Array = []
	var hours := 1.5 if not quick else 1.0
	for sp: int in [0, 3]:
		var v := village("열대", 4, 15, 24)
		v.water.offline = false
		v.flora.trust = true
		v.flora._ready = true
		v.flora._settle(v)
		v.t = 0.0
		v.flora.grove_last = -1.0e9
		var c := JarClock.new(v)
		c.set_speed(sp)
		c.tick(1.0)
		v.flora.grove(v)                     # 다 자란 버섯 숲 + 솜털 공 몇 포기
		for i in 4:
			v.flora.dands[i]["st"] = "puff"
			v.flora.dands[i]["st_t"] = v.t - Balance.DAND_PUFF + 600.0 + i * 300.0
			v.flora.dands[i]["seeds"] = Balance.DAND_SEEDS
		var steps := int(hours * H / Balance.WATCH_STEP)
		while c.steps_done < steps:
			c.tick(1.0 / 30.0 if sp == 0 else 0.25)
		sigs.append(sig(v))
		check(v.flora.stats["released"] > 0, "×%d: 꽃씨가 날았다 (%d)" % [int(c.speed()), v.flora.stats["released"]])
	check(sigs[0] == sigs[1], "×1 · ×8 결과가 같다 (버섯·민들레·꽃씨·주민 — %d자)" % String(sigs[0]).length())


func test_words() -> void:
	texts.append_array([Balance.BLOW_LINE, "하늘의 것이다… 가까이 가지 마!", "하늘의 것이야… 무서워", "먹을 만한데?"])
	for k: String in Village.WISH_REASON:
		texts.append(Village.WISH_REASON[k])
	check(run.words_ok(texts) == "", "하늘의 것 연대기·말에 금지어 없음 (%d줄) %s" % [texts.size(), run.words_ok(texts)])
