## 자리 잡기 측정 (헤드리스) — 시드 여럿 × N일: 일터 ↔ 자원 거리, 집 모임·간격, 나르기 시간, 인구·먹을 것.
## 실행: godot --headless --path godot -s res://tools/siting_probe.gd -- [일수=20] [시드=1,2,3] [size=1024] [표=-]
## 건물이 새로 생기는 그 시각의 자리를 잰다 (나중에 나무를 베어 멀어진 것과 따로).
extends SceneTree

const RES_R := 8.0          # 자원 무리 = 이 반지름 안의 수

var rows: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := float(args[0]) if args.size() > 0 else 20.0
	var seeds: Array = []
	for s in (String(args[1]) if args.size() > 1 else "1,2,3").split(","):
		seeds.append(int(s))
	var size := int(args[2]) if args.size() > 2 else WorldCfg.SIZE
	var agg := {}
	for sd: int in seeds:
		var r := _one(sd, days, size)
		for k: String in r:
			if not agg.has(k):
				agg[k] = []
			agg[k].append(r[k])
	print("\n== 평균 (%d개 시드, %.0f일)" % [seeds.size(), days])
	var keys: Array = agg.keys()
	keys.sort()
	for k: String in keys:
		var xs: Array = agg[k].filter(func(x: float) -> bool: return x >= 0.0)
		var s := 0.0
		for x: float in xs:
			s += x
		print("  %-28s %8.2f  (n=%d)  %s" % [k, s / maxf(1, xs.size()), xs.size(), str(agg[k].map(func(x: float) -> String: return "%.1f" % x))])
	quit()


func _near(list: Array, p: Vector2, ok: Callable) -> Array:
	var bd := INF
	var n := 0
	for o: Dictionary in list:
		if not ok.call(o):
			continue
		var d := Vector2(o["x"], o["y"]).distance_to(p)
		bd = minf(bd, d)
		if d < RES_R:
			n += 1
	return [bd, n]


func _water_d(v: Village, p: Vector2) -> float:
	var rad := 0.5
	while rad < 40.0:
		for i in 24:
			var a := TAU * i / 24.0
			var q := p + Vector2(cos(a), sin(a)) * rad
			if v.water.inside(q.x, q.y, 0.5) and v.water_at(q.x, q.y):
				return rad
		rad += 0.5
	return 40.0


func _one(sd: int, days: float, size: int) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var jw := JarWorld.create(sd, size)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y, Kits.make())
	v.auto_reveal = true
	var seen := {}
	for b in v.buildings:
		seen[b.id] = true
	var m := {}          # 이름 → [합, 수]
	var add := func(k: String, x: float) -> void:
		var a: Array = m.get(k, [0.0, 0])
		a[0] += x
		a[1] += 1
		m[k] = a
	var haul := 0.0
	var haul_from := 2.0 * Balance.DAY
	var dt := 60.0
	var n := int(days * Balance.DAY / dt)
	var food_min := INF
	var food_min_t := -1.0
	for i in n:
		jw.advance(dt)
		if v.t >= haul_from:
			for q in v.people:
				if q.carry != "":
					haul += dt
		if i % 60 == 0:
			if v.t > 3.0 * Balance.DAY:
				var fpp := v.food_total() / maxf(1, v.people.size())
				if fpp < food_min:
					food_min = fpp
					food_min_t = v.t / Balance.DAY
			for b in v.buildings:
				if seen.has(b.id):
					continue
				seen[b.id] = true
				var p := Vector2(b.x, b.y)
				match b.type:
					"나무꾼", "산림관":
						var r := _near(v.trees, p, func(o: Dictionary) -> bool: return o["s"] == "tree")
						add.call("%s_tree_d" % b.type, r[0])
						add.call("%s_trees_in8" % b.type, r[1])
						add.call("%s_store_d" % b.type, p.distance_to(v.fire))
					"채석장":
						var r := _near(v.rocks, p, func(o: Dictionary) -> bool: return o["amt"] > 0)
						add.call("채석장_rock_d", r[0])
						add.call("채석장_rocks_in8", r[1])
						add.call("채석장_store_d", p.distance_to(v.fire))
					"어부":
						add.call("어부_water_d", _water_d(v, p))
					"약초꾼":
						var hp: Variant = VillageEra._herb_patch(v, p, 20.0)
						add.call("약초꾼_herb_d", (hp as Vector2).distance_to(p) if hp != null else 20.0)
					"농장":
						add.call("농장_farm_mult", v.farm_mult(p.x, p.y))
						add.call("농장_fire_d", p.distance_to(v.fire))
	# 끝 모습: 집
	var houses := v.buildings.filter(func(b: Building) -> bool: return b.is_house())
	var hd := 0.0
	var nn := 0.0
	var on_road := 0
	var squeezed := 0
	for b: Building in houses:
		var p := Vector2(b.x, b.y)
		hd += p.distance_to(v.fire)
		var best := INF
		for o in v.buildings:
			if o != b:
				best = minf(best, p.distance_to(Vector2(o.x, o.y)) - o.size() - b.size())
		nn += best
		if best < 0.9:
			squeezed += 1
		if VillagePlan.blocks(v, b.x, b.y, b.size()):
			on_road += 1
	var res := {}
	for k: String in m:
		res[k] = float(m[k][0]) / maxi(1, int(m[k][1]))
	res["houses_n"] = houses.size()
	res["house_fire_d"] = hd / maxf(1, houses.size())
	res["house_wall_gap"] = nn / maxf(1, houses.size())
	res["house_squeezed"] = squeezed
	res["house_on_plan_road"] = on_road
	res["pop"] = v.people.size()
	res["buildings"] = v.buildings.size()
	res["era"] = v.era
	res["food_per_person_end"] = v.food_total() / maxf(1, v.people.size())
	res["food_per_person_min"] = food_min if food_min < INF else -1.0
	res["food_min_day"] = food_min_t
	res["beds"] = v.house_capacity()
	res["beds_per_person"] = float(v.house_capacity()) / maxf(1, v.people.size())
	res["starved"] = int(v.stats.get("starved", 0))
	res["born"] = int(v.stats.get("born", 0))
	res["died"] = int(v.stats.get("died", 0))
	res["farms"] = v.count_type("농장")
	res["haul_person_h_per_day"] = haul / 3600.0 / maxf(1.0, days - 2.0)
	var wk_out := 0
	var wk_n := 0
	var core := 0.0
	for b: Building in houses:
		core = maxf(core, Vector2(b.x, b.y).distance_to(v.fire))
	for b in v.buildings:
		if b.type in ["나무꾼", "산림관", "채석장", "어부", "약초꾼", "버섯꾼"]:
			wk_n += 1
			if Vector2(b.x, b.y).distance_to(v.fire) >= core - 1.0:
				wk_out += 1
	res["workplace_outside_core_frac"] = float(wk_out) / maxi(1, wk_n) if wk_n > 0 else -1.0
	for b in v.buildings:          # 끝 모습: 일터 ↔ 자원 (베고 캔 뒤)
		var p := Vector2(b.x, b.y)
		if b.type == "나무꾼":
			var r := _near(v.trees, p, func(o: Dictionary) -> bool: return o["s"] == "tree")
			res["end_나무꾼_tree_d"] = r[0]
			res["end_나무꾼_trees_in8"] = r[1]
		elif b.type == "채석장":
			var r := _near(v.rocks, p, func(o: Dictionary) -> bool: return o["amt"] > 0)
			res["end_채석장_rock_d"] = r[0]
	var types := {}
	for b in v.buildings:
		types[b.type] = int(types.get(b.type, 0)) + 1
	print("seed %d · %.0fs · era %d · pop %d · %s" % [sd, (Time.get_ticks_msec() - t0) / 1000.0, v.era, v.people.size(), str(types)])
	var ks: Array = res.keys()
	ks.sort()
	for k: String in ks:
		print("   %-28s %.2f" % [k, res[k]])
	return res
