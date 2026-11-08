## 자리 잡기 (sim/siting.gd — docs/BUILDINGS.md '자리 잡기 다시'): 일터는 재료 곁 · 집은 마을답게 · 결정적 · 빠름.
## tests/run.gd가 부름: 전체·quick·`-- siting`.
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
	run.timed(self, ["test_lumber_by_forest", "test_quarry_and_fisher", "test_houses_village_like", "test_houses_avoid_noise_and_roads",
		"test_siting_determinism", "test_siting_fast_and_static_free"])


static func _village(seed_v: int) -> Village:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.water.offline = true
	v.t = Balance.DAY                 # 첫날(대본) 뒤 — 점수 자리 잡기가 켜진다 (Siting.active)
	for k in ["판자", "돌"]:
		v.stock[k] = 500.0
	return v


static func world_day0() -> Village:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	return jw.place_kit(rec[0].x, rec[0].y)


static func _reveal_all(v: Village) -> void:
	if v.water is WorldWater:
		v.water.reveal(v.sid, v.center.x, v.center.y, v.territory_r() + 4.0, true)


static func _trees_near(v: Village, p: Vector2, r: float) -> Array:
	var bd := INF
	var n := 0
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			var d := Vector2(tr["x"], tr["y"]).distance_to(p)
			bd = minf(bd, d)
			if d < r:
				n += 1
	return [bd, n]


## 벌목장 = 숲 가장자리 (나무 3칸 안, 둘레 8칸에 나무가 넉넉), 마을 집 고리 바깥. 두 번째 벌목장은 첫째와 같은 숲 한 점에 붙지 않는다
func test_lumber_by_forest() -> void:
	print("== 자리 잡기: 벌목장은 숲 가")
	var ok_n := 0
	var tried := 0
	for sd in [3, 5, 8]:
		var v := _village(sd)
		_reveal_all(v)
		if _trees_near(v, v.center, 30.0)[1] < 10:
			continue
		tried += 1
		var sp: Variant = v.find_spot("나무꾼")
		if sp == null:
			continue
		var p: Vector2 = sp
		var tn: Array = _trees_near(v, p, 8.0)
		var outside := p.distance_to(v.fire) >= Siting.core_r(v) - 1.5
		print("   시드 %d: 나무까지 %.1f칸 · 8칸 안 나무 %d · 모닥불에서 %.1f (집 고리 %.1f)" % [sd, tn[0], tn[1], p.distance_to(v.fire), Siting.core_r(v)])
		if float(tn[0]) <= 3.5 and int(tn[1]) >= 8 and outside:
			ok_n += 1
		v.add_building("나무꾼", p.x, p.y, true)
		var sp2: Variant = v.find_spot("나무꾼")
		if sp2 != null:
			check((sp2 as Vector2).distance_to(p) >= 4.0, "시드 %d: 두 번째 벌목장은 첫째와 떨어진 숲 가 (%.1f칸)" % [sd, (sp2 as Vector2).distance_to(p)])
	check(tried > 0 and ok_n == tried, "벌목장이 숲 가장자리 (나무 3.5칸 안 · 둘레 8칸 나무 ≥ 8 · 집 고리 밖) — %d/%d" % [ok_n, tried])


## 채석장 = 바위 곁 · 어부 = 호숫가 (물이 보이는 곳)
func test_quarry_and_fisher() -> void:
	print("== 자리 잡기: 채석장은 바위 곁 · 어장은 물가")
	var v := _village(5)
	_reveal_all(v)
	var sp: Variant = v.find_spot("채석장")
	var rd := INF
	if sp != null:
		for r: Dictionary in v.rocks:
			if r["amt"] > 0:
				rd = minf(rd, Vector2(r["x"], r["y"]).distance_to(sp))
	check(sp != null and rd <= 3.5, "채석장이 바위 3.5칸 안 (%.1f)" % rd)
	var f := Siting.fields(v)
	var fs: Variant = Siting.resource_spot(v, "어부")
	if fs != null:
		var i := Siting._cell(f, fs)
		var ld: PackedFloat32Array = f["lake_d"]
		check(ld[i] <= 3.0 and not v.water_at((fs as Vector2).x, (fs as Vector2).y), "어장은 호숫가 마른 땅 (호수까지 %.1f칸)" % ld[i])
	else:
		var ld: PackedFloat32Array = f["lake_d"]
		var any := false
		for x in ld:
			any = any or x < 6.0
		check(not any, "어장 자리가 없으면 영역 안에 호수도 없다")


## 집: 모닥불 둘레 고리 (12채가 모닥불에서 R 안) · 큰길 위 아님 · 고른 간격 · 2~3채씩 모인 뜸 (같은 큰길 쪽에 이웃이 있는 집이 많다)
func test_houses_village_like() -> void:
	print("== 자리 잡기: 집은 마을답게")
	var v := _village(3)
	var placed: Array = []
	for i in 12:
		var sp: Variant = v.find_spot("오두막")
		if sp == null:
			break
		placed.append(v.add_building("오두막", (sp as Vector2).x, (sp as Vector2).y, true))
	check(placed.size() == 12, "집 12채 자리가 다 나옴 (%d)" % placed.size())
	var far := 0.0
	var on_road := false
	var min_gap := INF
	var with_nb := 0
	for b: Building in placed:
		var p := Vector2(b.x, b.y)
		far = maxf(far, p.distance_to(v.fire))
		on_road = on_road or VillagePlan.blocks(v, b.x, b.y, b.size())
		var nb := false
		for o in v.buildings:
			if o != b:
				var gap := p.distance_to(Vector2(o.x, o.y)) - o.size() - b.size()
				min_gap = minf(min_gap, gap)
				if o.is_house() and gap < 3.2:
					nb = true
		if nb:
			with_nb += 1
	check(far <= 18.0, "집 12채가 모닥불에서 18칸 안 (가장 먼 집 %.1f)" % far)
	check(not on_road, "광장·큰길 위에 선 집이 없다")
	check(min_gap >= VillagePlan.GAP - 0.01, "벽 사이 간격 ≥ %.1f (붐비지 않음 — %.2f)" % [VillagePlan.GAP, min_gap])
	check(with_nb >= 9, "집 대부분이 이웃 집 곁 (작은 뜸 — %d/12)" % with_nb)
	var f := VillagePlan.face_dir(v, placed[placed.size() - 1])
	var np := VillagePlan.nearest_plan(VillagePlan.plan(v), Vector2(placed[placed.size() - 1].x, placed[placed.size() - 1].y))
	check(f.dot(((np["pt"] as Vector2) - Vector2(placed[placed.size() - 1].x, placed[placed.size() - 1].y)).normalized()) > 0.99, "집의 문은 길 쪽")


## 집은 시끄러운 일터(제재소)에서 떨어지고, 발길(흙길) 위에는 서지 않는다
func test_houses_avoid_noise_and_roads() -> void:
	print("== 자리 잡기: 시끄러운 일터·발길 피하기")
	var v := _village(3)
	var first: Variant = v.find_spot("오두막")
	check(first != null, "첫 집 자리")
	if first == null:
		return
	var fp: Vector2 = first
	# 같은 자리 곁에 제재소를 세우면 집은 다른 곳으로
	var saw := v.add_building("제재소", fp.x + 0.0, fp.y + 0.0, true)
	saw.x = fp.x
	saw.y = fp.y
	var sp: Variant = v.find_spot("오두막")
	check(sp != null and (sp as Vector2).distance_to(fp) >= 4.0, "제재소 곁을 피함 (%.1f칸)" % ((sp as Vector2).distance_to(fp) if sp != null else -1.0))
	v.buildings.erase(saw)
	# 발길: 첫 자리를 흙길로 만들면 다른 곳
	var v2 := _village(3)
	check(Siting.active(v2) and not Siting.active(world_day0()), "첫날은 옛 자리 잡기 (대본), 그 뒤 점수")
	var a: Variant = v2.find_spot("오두막")
	for k in 40:
		v2.mark_path((a as Vector2).x + (k % 5 - 2) * 0.4, (a as Vector2).y + (k / 5 - 4) * 0.4, 20.0)
	var b: Variant = v2.find_spot("오두막")
	check(b != null and not v2.is_road((b as Vector2).x, (b as Vector2).y), "발길 위에는 집을 짓지 않는다")


## 같은 씨앗 → 같은 마을 (여러 종류를 차례로)
func test_siting_determinism() -> void:
	print("== 자리 잡기: 결정적")
	var seq := ["나무꾼", "오두막", "채석장", "농장", "오두막", "제재소", "산림관", "오두막"]
	var outs: Array = []
	for rep in 2:
		var v := _village(7)
		var o: Array = []
		for ty: String in seq:
			var sp: Variant = v.find_spot(ty)
			o.append(sp)
			if sp != null:
				v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		outs.append(o)
	var same := true
	for i in seq.size():
		same = same and str(outs[0][i]) == str(outs[1][i])
	check(same, "두 번 지은 마을의 자리가 모두 같다 %s" % str(outs[0].slice(0, 3)))


## 빠름 (자리 고르기는 드물지만 폰에서 끊기지 않게) · static var 없음 (ADR-0001)
func test_siting_fast_and_static_free() -> void:
	print("== 자리 잡기: 시간 · static 없음")
	var v := _village(5)
	var ts: Array = []
	for ty: String in ["나무꾼", "채석장", "오두막", "약초꾼", "오두막"]:
		v._site_cache = {}
		var t0 := Time.get_ticks_usec()
		v.find_spot(ty)
		ts.append((Time.get_ticks_usec() - t0) / 1000.0)
	var mx := 0.0
	for t: float in ts:
		mx = maxf(mx, t)
	print("   지도 새로 만들며 한 번 고르기: %s ms" % str(ts.map(func(x: float) -> String: return "%.1f" % x)))
	check(mx < 120.0, "자리 고르기 한 번 < 120ms (데스크톱, 지도 새로 — %.1f)" % mx)
	var src := FileAccess.get_file_as_string("res://sim/siting.gd")
	var bad := false
	for line in src.split("\n"):
		if line.strip_edges().begins_with("static var"):
			bad = true
	check(src != "" and not bad, "sim/siting.gd에 static var 없음 (ADR-0001)")
