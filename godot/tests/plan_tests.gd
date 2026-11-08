## 마을 배치·길 그래프 (sim/village_plan.gd — 기획서 6.7 '길은 발길이 만든다' + 촌장의 자리 고르기).
## tests/run.gd가 부름: 전체·quick·`-- plan`.
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
	run.timed(self, ["test_plan_layout", "test_graph_connects", "test_route_follows_roads", "test_roads_wear_and_fade", "test_plan_determinism", "test_plan_save_roundtrip"])


## 작은 넓은 세상 + 키트 하나를 n시간 흘린 마을
static func world_village(seed_v: int, hours: float) -> Village:
	var jw := JarWorld.create(seed_v, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.water.offline = true
	if hours > 0.0:
		jw.advance(hours * Balance.HOUR)
	return v


## 새 마을: 창고·오두막이 광장 둘레, 새 집은 길을 바라보며 계획된 자리(광장 둘레 고리 · 큰길 앞마당 너머)에
func test_plan_layout() -> void:
	print("== 마을 배치: 광장 둘레 · 큰길을 바라보는 집")
	var v := world_village(3, 0.0)
	var pl := VillagePlan.plan(v)
	var ring_ok := true
	for b in v.buildings:
		if b.type == "오두막" or b.is_store:
			var d := Vector2(b.x, b.y).distance_to(v.fire)
			ring_ok = ring_ok and d > VillagePlan.RP and d < VillagePlan.RP + 4.0
	check(ring_ok, "키트 창고·오두막은 광장 가 첫 고리 (모닥불에서 %.1f~%.1f칸)" % [VillagePlan.RP, VillagePlan.RP + 4.0])
	for k in ["판자", "돌"]:
		v.stock[k] = 500.0
	var placed: Array = []
	for i in 10:
		var sp: Variant = v.find_spot("오두막")
		if sp == null:
			break
		placed.append(v.add_building("오두막", (sp as Vector2).x, (sp as Vector2).y, true))
	check(placed.size() == 10, "집 10채 자리가 다 나옴 (%d)" % placed.size())
	var facing_ok := true
	var offset_ok := true
	var prev_d := 0.0
	var outward := true
	for b: Building in placed:
		var np := VillagePlan.nearest_plan(pl, Vector2(b.x, b.y))
		var f := VillagePlan.face_dir(v, b)
		var to := ((np["pt"] as Vector2) - Vector2(b.x, b.y)).normalized()
		facing_ok = facing_ok and f.dot(to) > 0.99
		var want := VillagePlan.HALF_W + VillagePlan.GARDEN + b.size()
		if np["kind"] == "street" and float(np["dist"]) < want + 1.0:     # 큰길 앞줄 (뒷줄 = 큰길 사이 고리 집은 골목으로 — sim/siting.gd)
			offset_ok = offset_ok and absf(float(np["dist"]) - want) < 0.3
		if np["kind"] == "street":
			offset_ok = offset_ok and float(np["dist"]) >= want - 0.3     # 큰길가 어떤 집도 앞마당보다 길에 붙지 않는다
		var d := Vector2(b.x, b.y).distance_to(v.fire)
		outward = outward and d >= prev_d - 3.5
		prev_d = maxf(prev_d, d)
	check(facing_ok, "집은 모두 가장 가까운 길(광장·큰길)을 바라본다 (마구잡이 각도 없음)")
	check(offset_ok, "큰길 앞줄 집은 길에서 같은 거리 (반폭 + 앞마당 + 집), 뒷줄도 앞마당보다 가깝지 않다")
	check(outward, "안쪽부터 바깥으로 고리 지어 선다")
	var gap_ok := true
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var a: Building = placed[i]
			var b: Building = placed[j]
			gap_ok = gap_ok and Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) >= a.size() + b.size() + VillagePlan.GAP - 0.01
	check(gap_ok, "이웃 집 사이 간격이 고르다 (≥ %.1f)" % VillagePlan.GAP)
	var on_street := false
	for b: Building in placed:
		if VillagePlan.blocks(v, b.x, b.y, b.size()):
			on_street = true
	check(not on_street, "광장·큰길 위에 선 집이 없다")
	var farm: Variant = v.find_spot("농장")
	check(farm != null and (farm as Vector2).distance_to(v.fire) > VillagePlan.RP + VillagePlan.FARM_FROM - 1.0,
		"밭은 집들 너머 큰길가 (모닥불에서 %.1f칸)" % ((farm as Vector2).distance_to(v.fire) if farm != null else -1.0))
	# 밀 → 가루 → 빵 고리: 밭 → (같은 큰길, 밭 안쪽) 방앗간 → 광장
	if farm != null:
		v.add_building("농장", (farm as Vector2).x, (farm as Vector2).y, true)
		var mill: Variant = v.find_spot("방앗간")
		var fk := int(VillagePlan.nearest_plan(pl, farm)["k"])
		var mk := int(VillagePlan.nearest_plan(pl, mill)["k"]) if mill != null else -9
		check(mill != null and mk == fk and (mill as Vector2).distance_to(v.fire) < (farm as Vector2).distance_to(v.fire),
			"방앗간은 밭과 같은 큰길, 밭과 광장 사이 (밀을 들고 길 따라)")


## 길 그래프: 모든 건물의 문이 광장(뿌리)까지 이어지고, 일하러 가는 숲 오솔길도 그래프에 닿는다
func test_graph_connects() -> void:
	print("== 길 그래프가 모든 건물·일터를 잇는다")
	var v := world_village(5, 30.0)
	var g := VillagePlan.graph(v)
	var nodes: Array = g["nodes"]
	var seen := {}
	var ok := true
	for n in range(1, nodes.size()):
		var m := n
		var guard := 0
		while m != 0 and guard < 400:
			m = nodes[m]["parent"]
			guard += 1
		ok = ok and m == 0
		if int(nodes[n]["b"]) >= 0:
			seen[int(nodes[n]["b"])] = true
	var all_b := true
	for b in v.buildings:
		all_b = all_b and seen.has(b.id)
	check(ok, "그래프는 광장을 뿌리로 한 나무 (노드 %d개 모두 뿌리까지)" % nodes.size())
	check(all_b, "건물 %d채 모두 문 → 길로 이어짐" % v.buildings.size())
	# 숲 오솔길: 벌목꾼이 숲에서 창고로 → 오솔길이 생기고 그래프에 닿는다
	var wc: Building = null
	for b in v.buildings:
		if b.type == "나무꾼":
			wc = b
	var far := Vector2.ZERO
	var fd := 0.0
	for tr: Dictionary in v.trees:
		var p := Vector2(tr["x"], tr["y"])
		var pr := VillagePlan.project(g, p)
		if float(pr["dist"]) > VillagePlan.TRAIL_D + 1.0 and float(pr["dist"]) < 10.0 and (fd == 0.0 or float(pr["dist"]) < fd):
			fd = pr["dist"]
			far = p
	check(fd > 0.0, "길에서 떨어진 숲 나무가 있다 (%.1f칸)" % fd)
	var r := v.people[0]
	var home := VillagePlan.door(v, VillagePlan._store(v))
	r.x = far.x
	r.y = far.y
	r.steps.clear()
	var s := ResidentAI.walk(home.x, home.y)
	r.steps.append(s)
	VillagePlan.route(v, r, s)
	var tr_list := VillagePlan.trails(v)
	var touch := false
	for t: Dictionary in tr_list:
		var pts: PackedVector2Array = t["pts"]
		touch = touch or float(VillagePlan.project(g, pts[0])["dist"]) < 0.05
	check(r.steps.size() > 1 and not tr_list.is_empty() and touch, "숲속 일터 → 오솔길이 생기고 길 그래프에 닿는다 (사이 걸음 %d)" % (r.steps.size() - 1))


## 걸음은 길을 따라 (사이 걸음이 모두 길 그래프·오솔길 위) — 짧은 걸음은 곧장
func test_route_follows_roads() -> void:
	print("== 주민은 길을 따라 걷는다")
	var v := world_village(3, 2.0)
	for k in ["판자", "돌"]:
		v.stock[k] = 500.0
	var hs: Array = []
	for i in 6:
		var sp: Variant = v.find_spot("오두막")
		hs.append(v.add_building("오두막", (sp as Vector2).x, (sp as Vector2).y, true))
	var g := VillagePlan.graph(v)
	var a: Building = hs[hs.size() - 1]
	var b: Building = VillagePlan._store(v)
	var r := v.people[0]
	var da := VillagePlan.door(v, a)
	var db := VillagePlan.door(v, b)
	r.x = da.x
	r.y = da.y
	r.steps.clear()
	var s := ResidentAI.walk(db.x, db.y)
	r.steps.append(s)
	VillagePlan.route(v, r, s)
	var on := true
	for st: Dictionary in r.steps:
		if st == s:
			break
		var pr := VillagePlan.project(g, Vector2(st["x"], st["y"]))
		on = on and (float(pr["dist"]) < 0.05 or Vector2(st["x"], st["y"]).distance_to(v.fire) < VillagePlan.RP)
	check(r.steps.size() > 2 and on, "바깥 집 → 창고: 사이 걸음 %d개가 모두 길 위 (광장은 모닥불을 비켜 가장자리로)" % (r.steps.size() - 1))
	var fire_ok := true
	for st: Dictionary in r.steps:
		fire_ok = fire_ok and Vector2(st["x"], st["y"]).distance_to(v.fire) > 1.5
	check(fire_ok, "모닥불 위를 밟고 지나가지 않는다")
	r.steps.clear()
	var s2 := ResidentAI.walk(da.x + 2.0, da.y)
	r.steps.append(s2)
	VillagePlan.route(v, r, s2)
	check(r.steps.size() == 1, "짧은 걸음(%.0f칸 미만)은 곧장" % VillagePlan.ROUTE_MIN)


## 다닌 곳에 길이 생기고(그래프 띠 ≥ 0.5 = 흙길) 안 다니면 옅어진다. 그래프 밖 발길은 닳은 풀 자국까지만
func test_roads_wear_and_fade() -> void:
	print("== 길은 발길이 만들고, 안 다니면 옅어진다")
	var v := world_village(3, 0.0)
	for k in ["판자", "돌"]:
		v.stock[k] = 500.0
	var hs: Array = []
	for i in 6:
		var sp: Variant = v.find_spot("오두막")
		hs.append(v.add_building("오두막", (sp as Vector2).x, (sp as Vector2).y, true))
	v.paths.fill(0.0)
	var sm := WorldTerrain.path_sum(v)
	var a: Building = hs[hs.size() - 1]
	var st: Building = VillagePlan._store(v)
	var r := v.people[0]
	var da := VillagePlan.door(v, a)
	var ds := VillagePlan.door(v, st)
	r.x = da.x
	r.y = da.y
	r.steps.clear()
	for i in 30:
		r.steps.append(ResidentAI.walk(ds.x, ds.y))
		r.steps.append(ResidentAI.walk(da.x, da.y))
	r.steps.append(ResidentAI.act(1.0e9, "idle"))
	var n := 0
	while r.steps.size() > 1 and n < 5000:
		ResidentAI.update(v, r, 10.0)
		n += 1
	var vals := VillagePlan.road_values(v, sm)
	var g := VillagePlan.graph(v)
	var pa := VillagePlan.project(g, da)
	var pb := VillagePlan.project(g, ds)
	var line := VillagePlan.path_between(g, pa["n"], pa["s"], pb["n"], pb["s"])
	var q := line[line.size() / 2]
	var tv := func(p: Vector2) -> float:
		var gx := floori((p.x - v.center.x + v.path_r) / (2.0 * v.path_r) * v.path_n)
		var gy := floori((p.y - v.center.y + v.path_r) / (2.0 * v.path_r) * v.path_n)
		return vals[gy * v.path_n + gx]
	var on_v: float = tv.call(q)
	var side: Vector2 = q + (q - v.fire).orthogonal().normalized() * 3.0
	var off_v: float = tv.call(side)
	check(on_v >= 0.5, "다닌 길 (그래프 위) 값 %.2f ≥ 0.5 → 흙길" % on_v)
	check(off_v < 0.3, "길 옆 3칸은 풀밭 (%.2f)" % off_v)
	var mx := 0.0
	for i in v.paths.size():
		if v.paths[i] > 0.0:
			mx = maxf(mx, minf(VillagePlan.RAW_CAP, GroundLook.path_value(v.paths[i] * sm) * VillagePlan.RAW_K))
	check(mx < 0.5, "그래프 밖 발길은 흙 얼룩이 되지 않는다 (최대 %.2f)" % mx)
	# 사흘 동안 안 다님 (Village.step의 옅어짐과 같은 식: 1분에 ×0.997)
	var f := pow(0.997, 3.0 * 24.0 * 60.0)
	for i in v.paths.size():
		v.paths[i] *= f
	var vals2 := VillagePlan.road_values(v, sm)
	var gx := floori((q.x - v.center.x + v.path_r) / (2.0 * v.path_r) * v.path_n)
	var gy := floori((q.y - v.center.y + v.path_r) / (2.0 * v.path_r) * v.path_n)
	check(vals2[gy * v.path_n + gx] < 0.5, "사흘 안 다니면 옅어진다 (%.2f → %.2f)" % [on_v, vals2[gy * v.path_n + gx]])


## 같은 마을 → 같은 계획 · 같은 자리 · 같은 그래프
func test_plan_determinism() -> void:
	print("== 배치 결정론")
	var sig := func(seed_v: int) -> String:
		var v := world_village(seed_v, 0.0)
		for k in ["판자", "돌"]:
			v.stock[k] = 500.0
		var s := ""
		for i in 5:
			var sp: Variant = v.find_spot("오두막" if i != 3 else "농장")
			if sp != null:
				var b := v.add_building("오두막" if i != 3 else "농장", (sp as Vector2).x, (sp as Vector2).y, true)
				s += "%.3f,%.3f,%.3f;" % [b.x, b.y, VillagePlan.facing(v, b)]
		var g := VillagePlan.graph(v)
		s += "|%d|%d" % [(g["nodes"] as Array).size(), (g["sa"] as PackedVector2Array).size()]
		return s
	var a: String = sig.call(4)
	var b: String = sig.call(4)
	var c: String = sig.call(6)
	check(a == b, "같은 시드 두 번 → 같은 자리·방향·그래프")
	check(a != c, "다른 시드는 다른 마을")


## 저장·불러오기: 건물 자리 그대로 · 그래프 같음 · 그 뒤 흐름도 같음 (길 찾기가 결정론을 깨지 않음)
func test_plan_save_roundtrip() -> void:
	print("== 배치·길 저장 왕복")
	var v := world_village(3, 6.0)
	var d := v.to_dict()
	var w := Village.from_dict(bytes_to_var(var_to_bytes(d)), v.water)
	var same := v.buildings.size() == w.buildings.size()
	for i in mini(v.buildings.size(), w.buildings.size()):
		same = same and is_equal_approx(v.buildings[i].x, w.buildings[i].x) and is_equal_approx(v.buildings[i].y, w.buildings[i].y)
	check(same, "건물 %d채 자리 그대로" % v.buildings.size())
	var ga := VillagePlan.graph(v)
	var gb := VillagePlan.graph(w)
	var pa: PackedVector2Array = ga["sa"]
	var pb: PackedVector2Array = gb["sa"]
	check(pa == pb, "길 그래프 같음 (선분 %d개)" % pa.size())
	# 옛 저장(계획 이전 자리)도 그대로 읽히고, 새 건물만 계획을 따른다
	var old := Village.from_dict(bytes_to_var(var_to_bytes(d)), v.water)
	old.buildings[1].x += 0.37
	var bx := old.buildings[1].x
	old.stock["판자"] = 500.0
	var sp: Variant = old.find_spot("오두막")
	check(is_equal_approx(old.buildings[1].x, bx) and sp != null, "계획에 없던 자리의 옛 건물은 그대로, 새 집은 계획 자리")
