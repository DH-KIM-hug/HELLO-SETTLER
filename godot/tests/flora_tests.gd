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
	run.timed(self, ["test_shroom_where", "test_shroom_giant_scale", "test_grove_and_growth", "test_picker", "test_poison_skill", "test_poison_eat", "test_shade_cotton",
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


## 노드 아래 모든 도형의 상자 (노드 자신의 변환·배율 포함 — 장면 밖이라 global_transform 대신 부모를 따라 곱함)
static func _world_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var xf := mi.transform
		var p := mi.get_parent()
		while p != null and p != n.get_parent():
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var bb: AABB = xf * mi.mesh.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


## 넓은 세상에서도 큰 버섯이 난다 (온대 세상의 김 ≥ 버섯 기준) · 다 자란 먹는 버섯은 진짜 거인 크기 —
## 갓이 오두막 바닥보다 넓고 주민 키의 몇 배 (WORLD_EVENTS 1.1 두 축척 · 2.6) · 어린 버섯은 작게 시작해 자라며 커짐
func test_shroom_giant_scale() -> void:
	var jw := JarWorld.create_with_kit(20261106)          # 본 게임 크기 (작은 세상은 물이 가까워 늘 축축함)
	var v := jw.primary()
	jw.advance(0.25 * D)
	check(v.air.humid_target(v) >= Balance.SHROOM_HUMID_MIN,
		"넓은 세상(온대)의 김 목표 %.2f ≥ 버섯 기준 %.2f — 큰 버섯이 날 수 있다 (전엔 0.27~0.37이라 빛버섯만 났음)" % [v.air.humid_target(v), Balance.SHROOM_HUMID_MIN])
	var fv := FloraView.new(v)
	run.root.add_child(fv)
	v.flora.shrooms.clear()
	var c := v.center + Vector2(8.0, 8.0)
	var big := v.flora.add_shroom(v, c, "흰갓버섯", 1.0)
	var brown := v.flora.add_shroom(v, c + Vector2(10.0, 0.0), "갈색갓버섯", 1.0)
	var young := v.flora.add_shroom(v, c + Vector2(0.0, 10.0), "흰갓버섯", 0.02)
	for i in 40:
		fv._sync_shrooms(v.flora, 0.1)       # 버섯만 (장면 밖 — 꽃씨·잡초 노드 없이)
	var cap_w := _world_aabb(fv._sh[big["id"]]["root"]).size.x
	var brown_w := _world_aabb(fv._sh[brown["id"]]["root"]).size.x
	var young_w0 := _world_aabb(fv._sh[young["id"]]["root"]).size.x
	young["g"] = 0.6
	for i in 40:
		fv._sync_shrooms(v.flora, 0.1)       # 버섯만 (장면 밖 — 꽃씨·잡초 노드 없이)
	var young_w1 := _world_aabb(fv._sh[young["id"]]["root"]).size.x
	# 오두막 (모델 바닥 너비 × 건물 배율)
	var cot := 0.0
	for nm: String in VillageView.BUILDING_MODELS["오두막"]:
		var mb: AABB = (Art.model(nm)["mesh"] as Mesh).get_aabb()
		cot = maxf(cot, maxf(mb.size.x, mb.size.z) * VillageView.BUILDING_SCALE)
	# 어른 주민 키 (실제 모델 × RESIDENT_SCALE)
	var rm := ResidentModel.new()
	run.root.add_child(rm)
	rm.build(0, 0, 0, 0, 0, 0, 30.0, "m")
	rm.set_anim("idle")
	rm.tick(0.0)
	var rh := _world_aabb(rm).size.y
	rm.queue_free()
	fv.queue_free()
	check(cot > 1.0 and rh > 0.5, "비교 크기 잼: 오두막 바닥 %.2f · 주민 키 %.2f" % [cot, rh])
	check(cap_w > cot and brown_w > cot * 1.5, "다 자란 버섯 갓이 오두막보다 넓다 (흰갓 %.2f · 갈색갓 %.2f > 오두막 %.2f)" % [cap_w, brown_w, cot])
	check(cap_w > 4.0 * rh and brown_w > 5.0 * rh, "갓 너비 = 주민 키의 몇 배 (흰갓 %.1f배 · 갈색갓 %.1f배)" % [cap_w / rh, brown_w / rh])
	check(young_w0 < cap_w * 0.4 and young_w1 > young_w0 * 1.8 and young_w1 < cap_w,
		"어린 버섯은 작게 시작해 자람 (%.2f → %.2f, 다 자라면 %.2f)" % [young_w0, young_w1, cap_w])


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
	var brown := f.add_shroom(v, near[0], "갈색갓버섯", 1.0)     # v5: 걸음이 느려 갈색갓을 가까이 (먼저 베어 말림대로) — 흰갓은 그다음
	f.add_shroom(v, near[1], "흰갓버섯", 1.0)
	v.assign_jobs()
	var w := v.person(hut.worker)
	check(w != null, "버섯꾼 일꾼이 정해짐 (%s)" % (w.name if w != null else "-"))
	var food0 := float(v.stock["버섯"])
	v.advance(20.0 * H)                # v5: 걸음이 현실 사람 걸음 — 오가는 데 병 시간이 더 든다 (예전 4시간 — 흰갓을 다 베고 갈색갓까지, 길·마을 배치에 따라 오감이 다름)
	var got := float(v.stock["버섯"]) - food0
	check(float(f.stats["picked"]) >= Balance.PICK_CHUNK * 2.0, "20시간에 버섯 %.0f개를 베어 창고로 (나무꾼처럼 조각내 나름 — 창고에 %.0f)" % [float(f.stats["picked"]), got])
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
	var left := v.consume_unmet(8.0)
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
	v2.advance(6.0 * H)        # A29: 걸음 0.7칸/초 (병 한 시간에 약 9칸) — 하던 일을 마치고 밭까지 오는 데 오래 걸려 낮 동안 넉넉히 (예전 2시간)
	check(w != null and not v2.flora.weeds.has(farm2.id) and float(v2.stock["민들레 잎"]) >= 4.0, "농부가 잡초를 뽑음 → 쓴 나물 %.0f" % v2.stock["민들레 잎"])
	_keep_texts(v2)


## 뚜껑 바람 (불기 손짓은 없앰 — flower-forest AC8): 솜털 공의 꽃씨가 한꺼번에 · 믿음 그대로 · "하늘에 눈이 내린다!" · 뚜껑이 닫혀 있으면 없음
func test_blow() -> void:
	var v := settled("온대", 4, 22)
	var f := v.flora
	v.advance(3.0 * H)
	var np := mini(6, f.dands.size())
	for i in np:
		f.dands[i]["st"] = "puff"
		f.dands[i]["seeds"] = Balance.DAND_SEEDS
	check(not f.has_method("blow_seeds") and not "blown" in f, "Flora에 blow_seeds·blown 없음 (AC8)")
	var old := f.to_dict() if f.has_method("to_dict") else {}
	old["blown"] = 3
	var back := Flora.from_dict(old)
	check(back != null and not "blown" in back, "옛 저장의 blown 키는 읽고 버림")
	check(f.lid_breeze(v, Vector2(1, 0)) == -1, "뚜껑이 닫혀 있으면 바람이 들지 않는다")
	v.open_lid()
	var b0 := v.faith
	var x0 := 0.0
	var n := f.lid_breeze(v, Vector2(1, 0))
	for s: Dictionary in f.seeds:
		x0 += float(s["x"])
	x0 /= maxf(1.0, f.seeds.size())
	check(np >= 3 and n >= np * Balance.DAND_SEEDS and f.count_st("puff") == 0, "솜털 공 %d포기의 꽃씨 %d개가 한꺼번에" % [np, n])
	check(is_equal_approx(v.faith, b0) and v.people.any(func(p: Resident) -> bool: return p.say == Balance.BLOW_LINE), "믿음 그대로 (뚜껑은 손짓이 아님 — %.2f → %.2f) · \"%s\"" % [b0, v.faith, Balance.BLOW_LINE])
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
	# 짓던 터는 다 지어 둔다 — 돌아오는 길에 터가 다 지어지면 모두 모여 기뻐하느라(ResidentAI.cancel) 돌아오는 일이 끊긴다.
	# 언제 다 지어지는지는 마을 배치(자리 잡기 — sim/siting.gd)에 따라 달라 이 시험이 볼 것이 아니다
	for b in v.buildings:
		if not b.built:
			b.built = true
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
	# 4시간까지 — 내려앉는 자리(꽃 자리·바람)에 따라 모닥불까지 20칸 넘게 걸어야 할 때가 있다 (돌아오면 바로 끝남)
	while v.t - t0 < 4.0 * H and not v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("꽃씨를 타고")):
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
	var days := 8 if not quick else 6
	var a := _wheat_run(2, days)
	var v: Village = a["v"]
	var worst: float = a["worst"]
	var offered: Array = a["offered"]
	var farmer_rest: bool = a["farmer_rest"]
	var need := v._food_people() * D / Balance.FOOD_IV
	var max_off := 0
	for o: int in offered:
		max_off = maxi(max_off, o)
	check(worst <= 1.3, "밀(창고 + 밭)이 넉넉한 양을 크게 넘지 않음 — 인구가 줄면 기준도 줄어듦 (최대 ×%.2f, 넉넉한 양 %.0f = 인구 %d × %.1f일치)" % [worst, v.enough("밀"), v.people.size(), Balance.FARM_ENOUGH_DAYS])
	check(max_off < 1000 and max_off <= need * 0.35, "날마다 바친 밀 %s — 1,000개 넘게 쌓여 바치지 않음 (하루 먹는 양 %.0f)" % [str(offered), need])
	# 굶지 않음 — 보는 것은 '농장이 멈춘 탓에' 창고가 비거나 굶는 일이 없는가이다. 씨앗 하나가 굴러간 길에 걸지 않게 두 가지로 본다:
	# ① 이 판에서 농부가 처음 쉰 뒤로는 창고가 빈 적도 굶어 죽은 이도 없다 (쉰 적이 없으면 볼 것이 없음)
	# ② 창고를 넉넉한 양 바로 위까지 채워 농장을 멈춰 세운 뒤 이틀 — 농부는 바로 쉬고, 그 이틀 동안 창고가 비지도 굶어 죽지도 않는다
	# (재어 봄 2026-11-10 — 시험 묶음과 같은 조건, 씨앗 1~32, 이 시험의 _wheat_run · _wheat_stop 그대로: 아이 놀이를 켜고 8일 32판 · 끄고 6일 32판,
	#  64판 모두 ①② 그대로 — 농부가 쉰 뒤 창고가 빈 적 0 · 굶어 죽음 0, 멈춰 세운 이틀 동안 창고가 빈 시간 0 · 굶어 죽음 0.
	#  예전의 '판 내내 창고가 한 번도 안 빔'은 씨앗 2의 운이었다. 만나가 끝난 3~5일째 아침, 농장이 아직 넉넉함에 닿기 전에 창고가 잠깐 비는 씨앗이
	#  32개에 켬 12개 · 끔 13~14개 — 농장이 멈춰서가 아니라 첫 수확이 늦어서이고 놀이와도 상관없다. 그쪽은 밸런스가 볼 일 (이 시험은 보지 않음))
	check(not a["short_after"] and int(a["starved_after"]) == 0, "농부가 쉰 뒤로 창고가 비지 않음 (처음 쉰 때 %s · 마지막으로 창고가 빈 때 %s · 그 뒤 굶어 죽음 %d · 판 전체 굶어 죽음 %d)" % [
		v.fmt_time(a["rest_t"]) if float(a["rest_t"]) >= 0.0 else "쉰 적 없음", v.fmt_time(v.last_short_t) if v.last_short_t >= 0.0 else "빈 적 없음", a["starved_after"], v.stats["starved"]])
	var st := _wheat_stop(v)
	check(st["farmer"] and st["rested"], "창고 밀이 넉넉한 양을 넘으면 농부가 바로 쉰다 (밀 %.0f → %.0f)" % [st["before"], st["filled"]])
	check(int(st["short_hours"]) == 0 and int(st["starved"]) == 0, "농장이 멈춰도 굶지 않음 (멈춰 세운 뒤 이틀: 창고가 빈 시간 %d · 굶어 죽음 %d · 창고 밀이 가장 적을 때 넉넉한 양의 ×%.2f · 농부가 다시 일한 때 %d시간 뒤)" % [
		st["short_hours"], st["starved"], st["lowest"], st["resumed"]])
	# v5: 농부는 창고 밀로 넉넉함을 본다 (밭 앞 밀은 4분의 1 수레가 차야 나르므로 창고 + 밭이 넉넉함을 10%쯤 넘을 수 있다 — 밭 자체는 넘으면 멈춤)
	# (E3-7 이슬이 새벽에 몰아서 → 밭 습기가 하루 안에서 조금 출렁여 최대가 ×1.11쯤까지)
	check(farmer_rest or worst < 1.15, "넉넉하면 농부도 일을 쉰다 (넉넉한 양의 최대 ×%.2f — v5: 넉넉함 = 죽 값 사흘치, 빵 사슬이 밀을 꾸준히 써서 거의 닿지 않음)" % worst)
	Market.reset()


## test_wheat_bounded의 한 판: 씨앗 하나로 며칠 (시간마다 창고 + 밭의 밀 · 농부가 쉬는지, 날마다 제단을 비움)
func _wheat_run(sd: int, days: int) -> Dictionary:
	Market.reset()
	var v := Village.new_prototype(sd)
	v.water.offline = true
	v.step_dt = 30.0
	v.auto_reveal = true
	var worst := 0.0
	var offered: Array = []
	var farmer_rest := false
	var rest_t := -1.0  # 농부가 처음 쉰 것을 본 시간의 첫머리 (그 시간 안에 빈 창고도 '쉰 뒤'로 센다)
	var rest_starved := 0
	for d in days:
		for hh in 24:
			var t0: float = v.t
			var starved0 := int(v.stats["starved"])
			v.advance(H)
			var w := float(v.stock["밀"])
			for b in v.buildings:
				w += float(b.out.get("밀", 0.0))
				if b.type == "농장" and b.worker >= 0 and v.person(b.worker) != null:
					farmer_rest = farmer_rest or not ResidentAI.work_task(v, v.person(b.worker), true)
			if farmer_rest and rest_t < 0.0:
				rest_t = t0
				rest_starved = starved0
			worst = maxf(worst, w / v.enough("밀"))
		var it := v.altar_items()
		offered.append(int(it.get("밀", 0)))
		v.take_all()
	return {"seed": sd, "v": v, "worst": worst, "offered": offered, "farmer_rest": farmer_rest, "rest_t": rest_t,
		"short_after": rest_t >= 0.0 and v.last_short_t > rest_t,
		"starved_after": int(v.stats["starved"]) - rest_starved if rest_t >= 0.0 else 0}


## test_wheat_bounded의 둘째 판: 창고 밀을 넉넉한 양 바로 위까지 채워 농장을 멈춰 세우고 이틀 (시간마다 창고가 비는지 · 농부가 다시 일하는지)
func _wheat_stop(v: Village) -> Dictionary:
	var starved0 := int(v.stats["starved"])
	var before := float(v.stock.get("밀", 0.0))
	var filled := maxf(before, v.enough("밀") * 1.05)
	v.stock["밀"] = filled
	var farmer := false
	var rested := false
	for b in v.buildings:
		if b.type == "농장" and b.worker >= 0 and v.person(b.worker) != null:
			farmer = true
			rested = rested or not ResidentAI.work_task(v, v.person(b.worker), true)
	var short_hours := 0
	var lowest := 1.0e9
	var resumed := -1
	for hh in 48:
		var t0: float = v.t
		v.advance(H)
		if v.last_short_t > t0:
			short_hours += 1
		lowest = minf(lowest, float(v.stock.get("밀", 0.0)) / v.enough("밀"))
		if resumed < 0:
			for b in v.buildings:
				if b.type == "농장" and b.worker >= 0 and v.person(b.worker) != null and ResidentAI.work_task(v, v.person(b.worker), true):
					resumed = hh + 1
		if hh % 24 == 23:
			v.altar_items()
			v.take_all()
	return {"before": before, "filled": filled, "farmer": farmer, "rested": rested, "short_hours": short_hours,
		"starved": int(v.stats["starved"]) - starved0, "lowest": lowest, "resumed": resumed}


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
		c.tick(c.dt_for_steps(1, 1.0))     # 배속과 상관없이 한 걸음 (v4.3: 걸음 10초)
		v.flora.grove(v)                     # 다 자란 버섯 숲 + 솜털 공 몇 포기
		for i in 4:
			v.flora.dands[i]["st"] = "puff"
			v.flora.dands[i]["st_t"] = v.t - Balance.DAND_PUFF + 600.0 + i * 300.0
			v.flora.dands[i]["seeds"] = Balance.DAND_SEEDS
		var steps := int(hours * H / Balance.STEP)
		while c.steps_done < steps:
			c.tick(c.dt_for_steps(steps - c.steps_done, 1.0 / 30.0 if sp == 0 else 0.25))
		sigs.append(sig(v))
		check(v.flora.stats["released"] > 0, "×%d: 꽃씨가 날았다 (%d)" % [int(c.speed()), v.flora.stats["released"]])
	check(sigs[0] == sigs[1], "×1 · ×8 결과가 같다 (버섯·민들레·꽃씨·주민 — %d자)" % String(sigs[0]).length())


func test_words() -> void:
	texts.append_array([Balance.BLOW_LINE, "하늘의 것이다… 가까이 가지 마!", "하늘의 것이야… 무서워", "먹을 만한데?"])
	for k: String in Village.WISH_REASON:
		texts.append(Village.WISH_REASON[k])
	check(run.words_ok(texts) == "", "하늘의 것 연대기·말에 금지어 없음 (%d줄) %s" % [texts.size(), run.words_ok(texts)])
