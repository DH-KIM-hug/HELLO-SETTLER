## 거대 식물 — 해바라기·씨앗비·목화·그늘 지도·솜 이불 (design/gdd/flower-forest.md AC1~5·8·9 · health.md 메인 판단 ① · ROADMAP F-2).
## tests/run.gd가 부름 (`-- plants`).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const H := 3600.0


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== F-2 거대 식물 (해바라기·씨앗비·목화·그늘·이불) · 물 보존 정리")
	run.timed(self, ["test_shadow_formula", "test_turn", "test_first_site", "test_shade_once", "test_seed_rain",
		"test_cotton", "test_quilt", "test_old_save", "test_no_statics"])


func _world(seed_v := 5) -> JarWorld:
	return JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))


## 병 날짜를 month/day h시로 (첫 무리 — 다른 무리 없음)
func _set_date(v: Village, month: int, day: int, h: float) -> void:
	v.created_date = {"year": 2026, "month": month, "day": day}
	v.start_clock = h * H - v.t


func _count(jw: JarWorld, kind: StringName, from: int) -> int:
	var n := 0
	for e: Dictionary in jw.events.since(from):
		if e["kind"] == kind:
			n += 1
	return n


func test_shadow_formula() -> void:
	var sf := {"id": 0, "x": 40.0, "y": 0.0, "lx": -0.72, "ly": -0.69, "fx": -0.72, "fy": -0.69, "t0": -1.0, "stage": "bloom"}
	var c := GiantPlants.shadow_center(sf, 0.0)
	print("  F1: 빛 (−0.72, −0.69), 줄기 (40, 0) → 그림자 중심 (%.2f, %.2f)" % [c.x, c.y])
	check(absf(c.x - 45.8) < 0.05 and absf(c.y - 5.5) < 0.05, "F1 예 → 그림자 중심 (45.8, 5.5)")
	sf["stage"] = "dry"
	check(is_equal_approx(GiantPlants.shadow_r(sf), Balance.SF_HEAD_R * 0.5), "겨울 마른 줄기 그림자 ×0.5 (경우 7)")


func test_turn() -> void:
	var jw := _world()
	var v := jw.primary()
	var ww := jw.water
	check(ww.sunflowers.size() == Balance.SF_COUNT, "병마다 해바라기 %d그루 (%d)" % [Balance.SF_COUNT, ww.sunflowers.size()])
	if ww.sunflowers.is_empty():
		return
	var sf: Dictionary = ww.sunflowers[0]
	_set_date(v, 7, 1, 9.0)
	var c_old := GiantPlants.shadow_center(sf, v.t)
	var cur := jw.events.serial
	jw.move_lamp(ww.rot + 1)
	jw.advance(60.0)
	var c_mid := GiantPlants.shadow_center(sf, v.t)
	var target := Vector2(sf["x"], sf["y"]) - ww.light * Balance.SF_SHADOW_OFF
	check(c_mid.distance_to(c_old) < 0.5 and c_mid.distance_to(target) > 3.0, "등불 옮긴 직후 그림자는 옛 자리 (%.2f칸 움직임)" % c_mid.distance_to(c_old))
	jw.advance(Balance.SF_TURN)
	var c_new := GiantPlants.shadow_center(sf, v.t)
	check(c_new.distance_to(target) < 0.01, "SF_TURN 뒤 새 자리 (%.3f)" % c_new.distance_to(target))
	var n := _count(jw, &"sunflower_turned", cur)
	check(n == ww.sunflowers.size(), "sunflower_turned 그루마다 한 번 (%d)" % n)


func test_first_site() -> void:
	for s in [5, 6, 7]:
		var jw := _world(s)
		var v := jw.primary()
		var ww := jw.water
		var best := INF
		var over := 0
		for sf: Dictionary in ww.sunflowers:
			var p := Vector2(sf["x"], sf["y"])
			var d := p.distance_to(v.center) - Balance.SF_SITE_R
			if d < best:
				best = d
				over = GiantPlants.lamp_overlaps(ww, p, v.center, v.territory_r())
		var clear := true
		for b in v.buildings:
			if GiantPlants.blocks(ww, b.x, b.y, b.size()):
				clear = false
		check(best >= 20.0 and best <= 40.0 and over >= 2 and clear,
			"시드 %d: 해바라기 하나가 첫 터 가장자리 밖 %.0f칸, 네 등불 중 %d곳에서 그림자가 영역에 닿음, 건물과 안 겹침" % [s, best, over])


func test_shade_once() -> void:
	var jw := _world()
	var v := jw.primary()
	var ww := jw.water
	var sf: Dictionary = ww.sunflowers[0]
	var c := GiantPlants.shadow_center(sf, v.t)
	var r := v.people[0]
	r.home = -1
	r.x = c.x
	r.y = c.y
	check(GiantPlants.shade_at(v, c.x, c.y), "해바라기 그림자 안은 그늘")
	v.trees.append({"x": c.x + 0.5, "y": c.y, "s": "tree", "g": 0.0, "res": 0})
	var pr := Health.protection(v, r, 1.0)
	check(is_equal_approx(float(pr[1]), Balance.SHADE_HEAT), "꽃숲 1.5칸 + 해바라기 그림자 겹침 → 더위 ×%.2f (×0.36 아님)" % pr[1])
	var far := Vector2(sf["x"], sf["y"]) + ww.light * 30.0
	check(not GiantPlants.in_sf_shadow(ww, far.x, far.y, v.t), "볕 쪽은 그림자가 아님")


func test_seed_rain() -> void:
	var jw := _world()
	var v := jw.primary()
	var ww := jw.water
	_set_date(v, 7, 1, 10.0)
	GiantPlants.hourly(v)
	check(ww.sf_seeds.is_empty(), "7월엔 씨앗비가 없다")
	_set_date(v, 8, 24, 9.5)
	for sf: Dictionary in ww.sunflowers:
		sf["stage"] = "bloom"
	# 마을 곁 해바라기만 핌 (먼 것은 닿지 않으니 빼고 셈)
	var near_sf: Dictionary = ww.sunflowers[0]
	for sf: Dictionary in ww.sunflowers:
		if Vector2(sf["x"], sf["y"]).distance_to(v.center) < Vector2(near_sf["x"], near_sf["y"]).distance_to(v.center):
			near_sf = sf
	var cur := jw.events.serial
	GiantPlants.hourly(v)
	var mine := ww.sf_seeds.filter(func(s: Dictionary) -> bool: return int(s["sf"]) == int(near_sf["id"]))
	check(mine.size() == Balance.SEEDS_PER_DAY, "씨앗비 날: 핀 꽃판 하나가 하루 %d알 (%d)" % [Balance.SEEDS_PER_DAY, mine.size()])
	GiantPlants.hourly(v)
	check(ww.sf_seeds.filter(func(s: Dictionary) -> bool: return int(s["sf"]) == int(near_sf["id"])).size() == Balance.SEEDS_PER_DAY, "같은 날 또 정하지 않는다")
	var first: Dictionary = mine[0]
	for s: Dictionary in mine:
		if float(s["t_land"]) < float(first["t_land"]):
			first = s
	var sc := GiantPlants.shadow_center(near_sf, v.t)
	check(Vector2(first["x"], first["y"]).distance_to(sc) <= GiantPlants.shadow_r(near_sf) + 0.01, "씨앗은 꽃판 그림자 안에 떨어진다")
	# 떨어지기 직전까지 → 그림자 먼저 (seed_shadow) → 땅에 박힘 (seed_landed)
	jw.advance(maxf(0.0, float(first["t_land"]) - v.t - 30.0))
	check(_count(jw, &"seed_shadow", cur) >= 1 and first["st"] == "sky", "떨어지기 전에 그림자가 먼저 (seed_shadow)")
	jw.advance(60.0)
	check(first["st"] != "sky" and _count(jw, &"seed_landed", cur) >= 1, "땅에 박힘 (seed_landed)")
	var kids := v.people.filter(func(r: Resident) -> bool: return r.doing.begins_with("떨어진 해바라기씨"))
	var rollers := v.people.filter(func(r: Resident) -> bool: return r.doing.begins_with("해바라기씨를 굴"))
	var n_kids := v.people.filter(func(r: Resident) -> bool: return r.is_child() and r.age >= 2.5).size()
	print("  씨앗 하나: 아이 %d명 달려감 (아이 %d명 중) · 굴리러 간 어른 %d명" % [kids.size(), n_kids, rollers.size()])
	check(kids.size() >= mini(1, n_kids) and rollers.size() >= 1, "아이들이 달려가고 어른이 굴리러 간다")
	var food0 := float(v.stock.get("해바라기씨", 0.0))
	for i in 400:                            # (A28) 걸음 0.7칸/초 그대로 — 먼 씨앗은 오가는 데 반나절 넘게
		jw.advance(300.0)
		if float(v.stock.get("해바라기씨", 0.0)) > food0:
			break
	var got := float(v.stock.get("해바라기씨", 0.0)) - food0
	check(got >= Balance.SEED_FOOD * 0.8, "어른이 굴려 와 창고에 해바라기씨 +%.0f" % got)     # (A28) 굴려 오는 데 오래 걸려 그 사이 조금 먹음
	check(v.book.any(func(b: Dictionary) -> bool: return String(b["text"]) == GiantPlants.SEED_LINE), "연대기 첫 줄")
	check(_count(jw, &"seed_stored", cur) >= 1, "seed_stored 사건")
	check(not GiantPlants.SEED_LINE.contains("거인") and not GiantPlants.SEED_LINE.contains("하늘의 분"), "연대기에 거인 이야기 없음")
	check("해바라기씨" in Balance.FOODS, "해바라기씨는 먹을거리")


func test_cotton() -> void:
	var jw := _world()
	var v := jw.primary()
	var ww := jw.water
	var p := v.center + Vector2(6, 3)
	ww.cotton.append({"id": 99, "sid": v.sid, "x": p.x, "y": p.y, "boll": false, "yr": -1, "yaw": 0.0})
	var cur := jw.events.serial
	_set_date(v, 7, 10, 10.0)
	GiantPlants.hourly(v)
	check(not ww.cotton[0]["boll"], "7월엔 다래가 없다")
	_set_date(v, 9, 10, 10.0)
	v.stock["솜"] = 0.0
	GiantPlants._cotton_season(v, ww, Health.jar_date(v))
	check(ww.cotton[0]["boll"] and _count(jw, &"cotton_burst", cur) == 1, "9월: 다래가 터짐 (cotton_burst 한 번)")
	GiantPlants._cotton_season(v, ww, Health.jar_date(v))
	check(_count(jw, &"cotton_burst", cur) == 1, "같은 해엔 cotton_burst 한 번만")
	var sent := GiantPlants.boll_fetch(v)
	for i in 24 * 60:                        # (A28) 걸음 덤 없이 굴려 오는 데 몇 시간
		jw.advance(60.0)
		if float(v.stock.get("솜", 0.0)) > 0.0:
			break
	check(sent == 1 and is_equal_approx(float(v.stock.get("솜", 0.0)), Balance.COTTON_BOLL), "솜뭉치를 굴려 창고에 솜 +%.0f" % float(v.stock.get("솜", 0.0)))
	check(v.book.any(func(b: Dictionary) -> bool: return String(b["text"]) == GiantPlants.COTTON_LINE), "목화 연대기 첫 줄 (민들레 솜과 따로)")
	v.stock["솜"] = 2.0 * v.people.size() * Balance.COTTON_PER
	check(v.people.all(func(r: Resident) -> bool: return v.flora.cotton_on(v, r)), "솜 ≥ 사람당 몫이면 cotton_on 참")
	_set_date(v, 12, 2, 10.0)
	GiantPlants._cotton_season(v, ww, Health.jar_date(v))
	check(not ww.cotton[0]["boll"], "12월엔 다래가 없다")
	# 저절로 돋음: 꽃숲 곁 볕·젖은 자리 (상한 COTTON_MAX)
	var n0 := GiantPlants.bushes_of(ww, v.sid).size()
	for hh in 24 * 40:
		v.t += H
		GiantPlants._cotton_spawn(v, ww)
	var n1 := GiantPlants.bushes_of(ww, v.sid).size()
	print("  목화 덤불: %d → %d (40일)" % [n0, n1])
	check(n1 <= Balance.COTTON_MAX, "덤불은 COTTON_MAX(%d)까지" % Balance.COTTON_MAX)


func test_quilt() -> void:
	var jw := _world()
	var v := jw.primary()
	var house: Building = null
	for b in v.buildings:
		if b.built and b.type in ["오두막", "목조 주택", "석조주택"]:
			house = b
			break
	if house == null:
		for b in v.buildings:
			if b.built:
				house = b
				break
	var r := v.people[0]
	r.home = house.id
	r.x = house.x
	r.y = house.y
	v.stock["솜"] = 0.0
	var pr0 := Health.protection(v, r, 0.0)
	v.stock["솜 이불"] = float(v.people.size())
	var pr1 := Health.protection(v, r, 0.0)
	print("  집 안 추위 배율: 이불 없음 %.3f · 이불 %.3f" % [pr0[0], pr1[0]])
	check(is_equal_approx(float(pr1[0]), float(pr0[0]) * Balance.QUILT_COLD), "솜 이불 — 집 안 추위 ×0.75 더")
	r.x = house.x + 30.0
	var pr2 := Health.protection(v, r, 0.0)
	check(float(pr2[0]) > float(pr1[0]) and not is_equal_approx(float(pr2[0]), float(pr1[0])), "집 밖에선 이불이 없다")


func test_old_save() -> void:
	var jw := _world()
	var d := jw.to_dict(false)
	(d["water"] as Dictionary).erase("sunflowers")
	(d["water"] as Dictionary).erase("vapour")
	var back := JarWorld.from_dict(d)
	var v := back.primary()
	var ok := back.water.sunflowers.size() == Balance.SF_COUNT
	for b in v.buildings:
		if GiantPlants.blocks(back.water, b.x, b.y, b.size()):
			ok = false
	check(ok, "옛 저장 (해바라기 없음) → 불러온 뒤 %d그루, 지은 건물과 겹치지 않음" % back.water.sunflowers.size())
	check(back.water.vapour > 0.0, "옛 저장 (김 없음) → 불러올 때 뚜껑이 닫힌 김으로 (%.3f)" % back.water.vapour)
	var again := JarWorld.from_dict(jw.to_dict(false))
	check(str(again.water.sunflowers) == str(jw.water.sunflowers), "저장·불러오기: 해바라기 그대로")


func test_no_statics() -> void:
	for f: String in ["res://sim/jar_water.gd", "res://sim/world_water.gd", "res://sim/health.gd"]:
		var src := FileAccess.get_file_as_string(f)
		check(not src.contains("static var"), "%s에 static var 없음" % f.get_file())
	check(not FileAccess.get_file_as_string("res://sim/flora.gd").contains("bless_all"), "flora.gd에 믿음 올리기 없음 (깨닫기 전 bless 정리)")
