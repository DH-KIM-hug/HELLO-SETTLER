## 건물 계통 (design/gdd/buildings.md) — tests/run.gd가 부름 (`-- buildings` = 이것만). 헤드리스, 장면 없음.
## 지금: 수락 기준 5 (땅 한계 개축 고르기 — 첫 작은 집만 보고 멈추던 버그의 회귀 시험) · 밀 숲 자람 단계 (A27-c, 보기 몫).
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
	print("== 건물 (buildings GDD)")
	run.timed(self, ["test_upgrade_pick_second", "test_upgrade_pick_first", "test_upgrade_none", "test_wheat_stage", "test_wheat_reaped", "test_grave_siting", "test_grave_old_save",
		"test_second_quarry", "test_stone_stuck", "test_opening_stone_rules_off", "test_field_grave", "test_yard_field"])


## 작은 옛 집 둘만 있는 마을 (오두막 cap 4 → 목조주택 cap 6 순서)
func _two_houses() -> Village:
	var v := Village.new_prototype(20261108)
	v.water.offline = true
	v.buildings.clear()
	var a := v.add_building("오두막", v.center.x + 3.0, v.center.y, true)
	var b := v.add_building("목조주택", v.center.x - 3.0, v.center.y, true)
	a.built = true
	b.built = true
	return v


## 수락 5: 첫째(오두막)는 바꾸면 상한을 넘고 둘째(목조)는 맞음 → 둘째를 고름
func test_upgrade_pick_second() -> void:
	var v := _two_houses()
	var era_cap := int(Balance.B["석조주택"]["cap"])          # 8
	var total := v.house_capacity()                          # 10
	# 오두막을 바꾸면 10 - 4 + 8 = 14, 목조를 바꾸면 10 - 6 + 8 = 12 → 상한 12
	var pick := v.upgrade_candidate(total, era_cap, 12.0)
	check(total == 10, "작은 옛 집 둘의 정원 합 10 (%d)" % total)
	check(pick != null and pick.type == "목조주택", "땅 한계 개축: 맞지 않는 첫 집을 건너뛰고 둘째 집을 고름 (%s)" % (pick.type if pick != null else "없음"))


func test_upgrade_pick_first() -> void:
	var v := _two_houses()
	var pick := v.upgrade_candidate(v.house_capacity(), int(Balance.B["석조주택"]["cap"]), 14.0)
	check(pick != null and pick.type == "오두막", "둘 다 맞으면 첫 집 (%s)" % (pick.type if pick != null else "없음"))


func test_upgrade_none() -> void:
	var v := _two_houses()
	check(v.upgrade_candidate(v.house_capacity(), int(Balance.B["석조주택"]["cap"]), 11.0) == null, "어느 집도 맞지 않으면 개축 없음")
	v.buildings[1].upgrade_to = "석조주택"                    # 이미 넓혀 짓는 집은 후보가 아님
	check(v.upgrade_candidate(v.house_capacity(), int(Balance.B["석조주택"]["cap"]), 12.0) == null, "넓혀 짓는 중인 집은 다시 고르지 않음")


## 밀 숲 자람 단계 (보기): 심은 직후 싹 → 자람 → 익음(금빛), 시뮬 수확 시각(ready_at)만 읽음
func test_wheat_stage() -> void:
	var v := Village.new_prototype(20261108)
	v.water.offline = true
	var f := v.add_building("농장", v.center.x + 4.0, v.center.y + 4.0, true)
	f.ready_at = v.t + Balance.GROW_FIRST
	check(VillageView.wheat_stage(f, v.t) == 0, "갓 심은 밀 숲 = 싹")
	check(VillageView.wheat_stage(f, v.t + Balance.GROW_FIRST * 0.6) == 1, "반쯤 지나면 자란 푸른 줄기")
	check(VillageView.wheat_stage(f, v.t + Balance.GROW_FIRST) == 2, "수확 시각부터 익은 금빛 이삭")
	f.ready_at = -1.0
	check(VillageView.wheat_stage(f, v.t) == 1, "수확 시각이 없으면 푸른 줄기 (예전 field_green과 같음)")
	check(int(Balance.B["농장"]["size"] * 10) == 18 and Balance.B["농장"]["out"].has("밀"), "밀 숲 터: 크기 1.8·레시피(밀) 그대로")


## (Q8) 거둔 줄 (보기만): 익은 밭은 밭 곁에 쌓인 벤 밀(out["밀"] — 볏단 더미와 같은 값)의 몫만큼 앞줄부터 그루터기.
## 시각·일꾼과 상관없고, 밭 값을 바꾸지 않는다
func test_wheat_reaped() -> void:
	var v := Village.new_prototype(20261108)
	v.water.offline = true
	var f := v.add_building("농장", v.center.x + 4.0, v.center.y + 4.0, true)
	f.ready_at = v.t                 # 지금 막 익음 (음수 = 수확 시각 없음이라 쓰지 않음)
	var full := BldEcon.out_full("밀")
	var n := Bld2D.Pics.WHEAT_STUBBLE.size()
	var bad: Array = []
	for cs: Array in [[0.0, 0], [0.12, 0], [0.13, 1], [0.25, 1], [0.5, 2], [0.75, 3], [1.0, 4], [2.5, 4]]:
		f.out["밀"] = full * float(cs[0])
		var rows := BldEcon.wheat_rows(v, f)
		var ok := rows.size() == n and BldEcon.reaped_rows(float(f.out["밀"])) == int(cs[1])
		for i in n:
			ok = ok and int(rows[n - 1 - i]) == (Bld2D.ROW_STUBBLE if i < int(cs[1]) else Bld2D.ROW_RIPE)
		if not ok:
			bad.append("%s → %s" % [cs, rows])
	check(bad.is_empty() and BldEcon.REAP_ROWS == 4 and n == 6 and full > 0.0,
		"벤 밀이 한 수레(%d)의 0 · 1/4 · 1/2 · 3/4 · 가득 → 앞줄부터 0 · 1 · 2 · 3 · 4줄 그루터기 (뒤 두 줄은 늘 서 있음) %s" % [int(full), bad])
	f.out["밀"] = full * 0.5
	var base := BldEcon.wheat_rows(v, f)
	var t0 := v.t
	var same := true
	for h: float in [3.0, 9.0, 15.0, 22.0]:
		v.t = t0 + h * Village.HOUR
		f.worker = -1 if h < 10.0 else 7
		same = same and BldEcon.wheat_rows(v, f) == base
	v.t = t0
	f.worker = -1
	check(same and is_equal_approx(float(f.out["밀"]), full * 0.5) and is_equal_approx(f.ready_at, t0),
		"줄은 시각·일꾼과 상관없이 쌓인 밀만 따른다 · 밭 값은 그대로 (보기만)")
	f.ready_at = v.t + Balance.GROW_FIRST
	f.out["밀"] = full
	var green := BldEcon.wheat_rows(v, f)
	check(green.size() == n and green.count(0) == n, "익기 전에는 쌓인 밀이 있어도 그루터기 없음 (싹 그대로) %s" % [green])


## 옛 규칙 (2026-11-10까지): 마을 끝에서 40걸음 나선, 건물·무덤만 피함 — 새 규칙과 견주는 기준
func _old_grave(v: Village) -> Vector2:
	var base := v.center + Vector2(-0.6, 0.8).normalized() * 8.0
	for k in 40:
		var a := k * 0.9
		var q := base + Vector2(cos(a), sin(a)) * (0.8 * (k / 6))
		if v.water_at(q.x, q.y) or not v.water.inside(q.x, q.y, 1.5):
			continue
		var ok := true
		for b in v.buildings:
			if Vector2(b.x - q.x, b.y - q.y).length() < b.size() + 0.6:
				ok = false
				break
		for g: Dictionary in v.graves:
			if Vector2(float(g["x"]) - q.x, float(g["y"]) - q.y).length() < 0.7:
				ok = false
				break
		if ok:
			return q
	return base


## (Q8) 홀로 선 무덤 자리: 밭 안·밭 바로 곁(네 방위 어디서 보든 밀 줄에 가리는 띠)을 피한다 — 주사위 없이 늘 같은 자리,
## 밭이 곁에 없으면 옛 규칙과 같은 자리. 그렇게 놓인 무덤 앞에서는 화면이 밀을 낮출 일이 없다 (BldEcon.grave_cuts가 네 방위 모두 비어 있음)
func test_grave_siting() -> void:
	check(is_equal_approx(VillageEra.GRAVE_VIEW_YAW, JarCamera.BASE_YAW_DEG), "무덤 자리가 보는 방위 = 카메라 기본 방위 (%.0f°)" % JarCamera.BASE_YAW_DEG)
	var seen := 0
	var in_strip := 0                 # 새 자리가 밭 곁 띠 안
	var cut := 0                      # 새 자리 앞에서 낮춰야 하는 밀 판 (네 방위)
	var was_strip := 0                # 옛 규칙이면 띠 안이었을 자리
	var near_b := 0                   # 건물에 너무 붙은 자리
	var drift := 0                    # 밭과 상관없는데 옛 자리와 달라진 마을
	var stable := true
	var rolled := false
	for sd in 24:
		var v := Village.new_prototype(20261100 + sd)
		v.water.offline = true
		var s0 := v.rng.state
		var base := v.center + Vector2(-0.6, 0.8).normalized() * 8.0
		var old0 := _old_grave(v)
		if not VillageEra.grave_by_field(v, old0) and not VillageEra._lone_grave(v, null).is_equal_approx(old0):
			drift += 1
		for k in 7:
			var off := Vector2.ZERO if k == 0 else Vector2(cos(k * 1.047), sin(k * 1.047)) * (1.6 + 0.4 * k)
			var farm := v.add_building("농장", base.x + off.x, base.y + off.y, true)
			farm.ready_at = v.t
			if VillageEra.grave_by_field(v, _old_grave(v)):
				was_strip += 1
			var g := VillageEra._lone_grave(v, null)
			stable = stable and g.is_equal_approx(VillageEra._lone_grave(v, null))
			seen += 1
			if VillageEra.grave_by_field(v, g):
				in_strip += 1
			for b in v.buildings:
				if Vector2(b.x - g.x, b.y - g.y).length() < b.size() + 0.6 - 0.001:
					near_b += 1
			v.graves.append({"id": 99901, "name": "시험", "x": g.x, "y": g.y, "t": v.t, "yard": false, "yard_id": -1})
			for st in 4:
				for c: Array in BldEcon.grave_cuts(v, farm, st, 2):
					if not c.is_empty():
						cut += 1
			v.graves.pop_back()
			v.buildings.erase(farm)
		rolled = rolled or v.rng.state != s0
	check(seen == 24 * 7 and in_strip == 0 and near_b == 0, "마을 24곳 × 밭 자리 7곳 (%d판): 새 무덤 자리가 밭 곁 띠 안 %d · 건물에 붙은 것 %d (옛 규칙이면 띠 안 %d)"
		% [seen, in_strip, near_b, was_strip])
	check(was_strip > 20 and cut == 0, "그 무덤들 앞에서 낮춰야 하는 밀 판 (네 방위): %d — 화면이 밀을 벨 일이 없음" % cut)
	check(drift == 0 and stable and not rolled, "밭과 상관없는 마을은 옛 자리 그대로 (달라진 곳 %d) · 늘 같은 답 · 주사위를 쓰지 않음" % drift)


## (Q8) 옛 저장: 밭 바로 뒤에 이미 선 무덤 — 자리 그대로 불러오고, 화면은 그 앞의 밀에 좁은 홈만 낸다 (밭 전체가 아님 · 반대편에서 보면 그대로)
func test_grave_old_save() -> void:
	var v := Village.new_prototype(20261108)
	v.water.offline = true
	var farm := v.add_building("농장", v.center.x + 6.0, v.center.y + 6.0, true)
	farm.ready_at = v.t
	var tw: Vector2 = BldEcon.step_dirs(0)[0]
	var gp := Vector2(farm.x, farm.y) - tw * 1.7
	v.graves.append({"id": 99901, "name": "시험", "x": gp.x, "y": gp.y, "t": v.t, "yard": false, "yard_id": -1})
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	var f2: Building = null
	for b in v2.buildings:
		if b.id == farm.id:
			f2 = b
	var kept: bool = f2 != null and v2.graves.size() == 1 and is_equal_approx(float(v2.graves[0]["x"]), gp.x) and is_equal_approx(float(v2.graves[0]["y"]), gp.y)
	check(kept and VillageEra.grave_by_field(v2, gp), "옛 저장의 밭 뒤 무덤: 불러와도 그 자리 그대로 (옮기지 않음)")
	if not kept:
		return
	var names := Bld2D.wheat_cards(2)
	var cuts := BldEcon.grave_cuts(v2, f2, 0, 2)
	var n := 0
	var notch := true
	for i in cuts.size():
		var c: Array = cuts[i]
		if c.is_empty():
			continue
		n += 1
		var rd := Bld2D.info(String(names[i]))
		var rh := float(rd["h"])
		var hw := float(rd["w"]) * 0.5
		notch = notch and float(c[1]) - float(c[0]) + 2.0 * BldEcon.cut_ramp(rh, float(c[2])) < 2.0 * hw
		notch = notch and is_zero_approx(BldEcon.cut_sink(-hw, c, rh)) and is_zero_approx(BldEcon.cut_sink(hw, c, rh))
	var opp := 0
	for c: Array in BldEcon.grave_cuts(v2, f2, 2, 2):
		opp += 0 if c.is_empty() else 1
	check(n >= 1 and notch and opp == 0, "그 무덤 앞 밀 줄 %d장에 좁은 홈만 (줄 양 끝은 제 키) · 반대편에서 보면 벤 곳 없음 (%d)" % [n, opp])


# ───────────────────────── 돌이 떨어지는 날 (GD 9장 · docs/measure/growth_2026-11-11.md 바) ─────────────────────────
const STONE_Q := Vector2(-5.0, -15.0)          # 시험 마을의 채석장 자리 — 둘레(GATHER_RANGE)에 바위 둘, 나머지 넷은 닿지 않는다

## 돌이 떨어진 마을: 오두막 하나 · 밭 · 나무꾼 · 채석장 (다 지음), 판자는 넉넉하고 돌은 0, 집 없는 어른이 있다.
## near = 채석장 둘레 바위마다 남긴 양 · far = 닿지 않는 바위마다 남긴 양 · quarry = 채석장을 두나
func _stone_village(near: int, far: int, quarry := true) -> Village:
	var v := Village.new_prototype(20261111)
	v.water.offline = true
	v.chief_off = true
	v.add_building("오두막", 4.0, -3.0, true)
	v.add_building("농장", 9.0, 9.0, true)
	v.add_building("나무꾼", -9.0, 7.0, true)
	if quarry:
		v.add_building("채석장", STONE_Q.x, STONE_Q.y, true)
	for rk: Dictionary in v.rocks:
		rk["amt"] = near if Vector2(float(rk["x"]), float(rk["y"])).distance_to(STONE_Q) <= Balance.GATHER_RANGE else far
	v.stock["돌"] = 0.0
	v.stock["판자"] = 20.0
	return v


func _site_types(v: Village) -> Array:
	var out: Array = []
	for b in v.buildings:
		if b.is_site():
			out.append(b.site_type())
	return out


func _drop(v: Village, b: Building) -> void:
	v.buildings.erase(b)
	v._bld_by_id.erase(b.id)


func _fake_grave(v: Village, q: Vector2) -> void:
	v.graves.append({"id": 99901, "name": "시험", "x": q.x, "y": q.y, "t": v.t, "yard": false, "yard_id": -1})


## (가) 있는 채석장 둘레를 다 캤고 병 안에 바위가 남았으면 촌장이 남은 바위 곁에 채석장을 하나 더 — 둘레에 바위가 남았으면 짓지 않는다
func test_second_quarry() -> void:
	var v := _stone_village(0, 20)
	v.stats["died"] = 1                    # 맨 위 바람 = 묘지 (돌 1) — 씨앗 15가 멈춘 그 모양
	var s0 := v.rng.state
	check(v.quarry_spent() and v.stone_rocks_left() and not v.stone_in_reach(STONE_Q.x, STONE_Q.y), "시험 마을: 채석장 둘레는 다 캤고 먼 바위 넷이 남았다")
	v.chief_build()
	var q2: Building = null
	for b in v.buildings:
		if b.type == "채석장" and not b.built:
			q2 = b
	check(q2 != null and v.count_type("채석장") == 2 and v.stone_in_reach(q2.x, q2.y) and not v.quarry_spent(),
		"둘레를 다 캤고 바위가 남음 → 남은 바위 곁에 채석장 터 하나 더 (%s · 그 둘레에 캘 바위 있음)" % [_site_types(v)])
	check(v.rng.state == s0, "채석장을 하나 더 정하는 데 주사위를 쓰지 않는다")
	v.chief_build()
	v.chief_build()
	check(v.count_type("채석장") == 2, "새 터가 선 뒤로는 또 짓지 않는다 (채석장 %d)" % v.count_type("채석장"))
	# 둘레에 바위가 남아 있으면 (돌이 아직 안 온 것뿐) 하나 더 짓지 않는다 — 예전처럼 기다린다
	var w := _stone_village(6, 20)
	w.stats["died"] = 1
	w.chief_build()
	check(not w.quarry_spent() and w.count_type("채석장") == 1 and _site_types(w).is_empty(), "둘레에 캘 바위가 남음 → 채석장도 다른 것도 새로 짓지 않고 기다린다 (%s)" % [_site_types(w)])
	# 채석장이 하나도 없을 때는 예전 규칙 그대로 (첫 채석장)
	var n := _stone_village(20, 20, false)
	n.stats["died"] = 1
	n.chief_build()
	check(not n.quarry_spent() and _site_types(n) == ["채석장"], "채석장이 없고 돌이 모자람 → 예전처럼 첫 채석장부터 (%s)" % [_site_types(n)])
	# 옛 저장: 저장하는 값이 없어 불러온 마을에서도 그대로 돈다
	var o := _stone_village(0, 20)
	o.stats["died"] = 1
	var o2 := Village.from_dict(bytes_to_var(var_to_bytes(o.to_dict())))
	o2.chief_off = true
	o2.chief_build()
	check(o2.count_type("채석장") == 2 and _site_types(o2) == ["채석장"], "불러온 마을 (둘레를 다 캔 채석장)에서도 하나 더 짓는다 (%s)" % [_site_types(o2)])
	# 병 안의 바위를 다 캤으면 채석장을 더 짓지 않는다
	var e := _stone_village(0, 0)
	e.chief_build()
	check(e.quarry_spent() and not e.stone_rocks_left() and e.count_type("채석장") == 1, "병 안에 바위가 없음 → 채석장을 더 짓지 않는다 (%s)" % [_site_types(e)])


## (나) 돌이 들어올 길이 없어 못 짓는 바람(묘지)이 그 아래 바람(오두막)을 막지 않는다 — '아직 안 온' 돌이면 예전처럼 기다린다
func test_stone_stuck() -> void:
	var v := _stone_village(0, 0)
	v.stats["died"] = 1
	check(not v._affordable("묘지") and v._affordable("오두막"), "시험 마을: 묘지(돌 1)는 못 짓고 오두막(판자)은 지을 수 있다")
	v.chief_build()
	check(_site_types(v) == ["오두막"], "바위를 다 캔 마을: 못 짓는 묘지를 두고 그 아래 바람인 집을 짓는다 (%s)" % [_site_types(v)])
	check(v.count_type("묘지") == 0 and v.count_type("채석장") == 1, "묘지 터도 채석장 터도 서지 않는다")
	# 채석장 둘레에 바위가 남았으면 (아직 나르지 않은 돌) 건너뛰지 않는다 — 평소 차례 그대로
	var w := _stone_village(6, 0)
	w.stats["died"] = 1
	w.chief_build()
	check(_site_types(w).is_empty(), "둘레에 캘 바위가 남음 → 묘지를 기다린다 (아래 바람으로 넘어가지 않음 %s)" % [_site_types(w)])
	# 돌이 있으면 예전처럼 묘지부터
	var y := _stone_village(0, 0)
	y.stats["died"] = 1
	y.stock["돌"] = 3.0
	y.chief_build()
	check(_site_types(y) == ["묘지"], "돌이 있으면 묘지부터 (%s)" % [_site_types(y)])
	# 바위는 남았지만 새 채석장에 보낼 일손이 없다 (새 일터 규칙) → 채석장 대신 집
	var h := _stone_village(0, 20)
	h.stats["died"] = 1
	var free_hand := false
	for p in h.people:
		if p.is_adult():
			if not free_hand:
				free_hand = true          # 한 사람만 손이 비었다 (IDLE_FOR_NEW_JOB 2)
			else:
				p.job = h.buildings[0].id
	h.chief_build()
	check(_site_types(h) == ["오두막"], "남은 바위는 있으나 일손이 없음 → 새 채석장은 미루고 집을 짓는다 (%s)" % [_site_types(h)])
	# 남은 바위가 영역 밖 멀리 있어 그 곁에 채석장 자리를 못 잡는다 → 쓸모없는 채석장을 세우지 않고 집을 짓는다 (나무도 그대로)
	var u := _stone_village(0, 0)
	u.stats["died"] = 1
	u.rocks[0]["x"] = 400.0
	u.rocks[0]["y"] = 400.0
	u.rocks[0]["amt"] = 20
	u.chief_build()
	check(u.stone_rocks_left() and u.count_type("채석장") == 1 and _site_types(u) == ["오두막"], "남은 바위가 닿지 않는 먼 곳 → 채석장을 더 세우지 않고 집을 짓는다 (%s)" % [_site_types(u)])
	check(u.trees.size() == v.trees.size(), "버린 채석장 자리의 나무는 베지 않는다 (나무 %d · 바위가 없는 같은 마을 %d)" % [u.trees.size(), v.trees.size()])
	# 들어준 소원이 못 짓는 것이어도 (제재소 = 돌 2) 그 아래를 본다 — 소원은 남는다
	var k := _stone_village(0, 0)
	k.wishes = ["제재소"]
	k.chief_build()
	check(_site_types(k) == ["오두막"] and k.wishes == ["제재소"], "못 짓는 소원(제재소)은 남겨 두고 집을 짓는다 (%s)" % [_site_types(k)])


## 평소의 첫 며칠에는 새 규칙이 켜지지 않는다: 채석장 둘레를 다 캔 적이 없으면 촌장의 차례는 예전과 한 줄도 다르지 않다
## (새 갈래는 모두 quarry_spent()가 참일 때만 열린다 — 서른두 씨앗의 병 10일 건물 자리가 앞뒤 같음은 growth 바-3)
func test_opening_stone_rules_off() -> void:
	var v := Village.new_prototype(1)
	v.auto_reveal = true
	var hours := 24 if quick else 72
	var spent := 0
	var order: Array = []
	var seen := v.buildings.size()
	for hr in hours:
		v.advance(Balance.HOUR)
		if v.quarry_spent():
			spent += 1
		while seen < v.buildings.size():
			order.append(v.buildings[seen].type)
			seen += 1
	check(spent == 0, "첫 %d시간: 채석장 둘레를 다 캔 때 %d번 (새 규칙이 켜지지 않음) · 지은 차례 %s" % [hours, spent, order])
	check(order.size() >= 2 and "농장" in order, "첫날의 차례는 그대로 — 집과 밭부터 (%s)" % [order])


# ───────────────────────── 밭과 무덤 자리 (Q8 ⑧ ⑨) ─────────────────────────
func _view_axis() -> Vector2:
	var yaw := deg_to_rad(VillageEra.GRAVE_VIEW_YAW)
	return Vector2(sin(yaw), cos(yaw))


## (Q8 ⑧) 나중에 일구는 밭은 이미 있는 무덤·묘지를 가리는 자리를 피한다 — 다른 자리가 없을 때만 옛 규칙. 무덤이 없으면 예전과 같은 자리
func test_field_grave() -> void:
	var tw := _view_axis()
	var seen := 0
	var moved := 0
	var covers := 0
	var old_covers := 0
	var yard_covers := 0
	var fallback_same := 0
	var same_without := 0
	var rolled := false
	for sd in 12:
		var v := Village.new_prototype(20261100 + sd)
		v.water.offline = true
		v.chief_off = true
		v.add_building("오두막", 4.0, -3.0, true)
		var s0 := v.rng.state
		var p0: Variant = v.find_spot("농장")
		if p0 == null:
			continue
		seen += 1
		var f0: Vector2 = p0
		if (v.find_spot("농장") as Vector2).is_equal_approx(f0) and not VillageEra.has_graves(v):
			same_without += 1
		# 그 밭 자리 바로 뒤(보는 축으로 2칸)에 돌 하나
		_fake_grave(v, f0 + tw * 2.0)
		if VillageEra.field_by_grave(v, f0):
			old_covers += 1
		var p1: Variant = v.find_spot("농장")
		if p1 != null and not (p1 as Vector2).is_equal_approx(f0):
			moved += 1
		if p1 == null or VillageEra.field_by_grave(v, p1):
			covers += 1
		v.graves.clear()
		# 묘지 (밭 자리에서 4.2칸 뒤 — 밭과 겹치지는 않지만 밀 뒤)
		var yp := f0 + tw * 4.2
		var yard := v.add_building("묘지", yp.x, yp.y, true)
		var p2: Variant = v.find_spot("농장")
		if p2 == null or VillageEra.field_by_grave(v, p2):
			yard_covers += 1
		_drop(v, yard)
		# 어디에 일궈도 무덤을 가린다 (온 마을에 돌) → 옛 규칙의 자리 그대로
		for gx in range(-40, 41, 2):
			for gy in range(-40, 41, 2):
				_fake_grave(v, v.center + Vector2(gx, gy))
		var p3: Variant = v.find_spot("농장")
		if p3 != null and (p3 as Vector2).is_equal_approx(f0):
			fallback_same += 1
		rolled = rolled or v.rng.state != s0
	check(seen >= 8 and same_without == seen, "무덤이 없는 마을 %d곳: 밭 자리는 예전 그대로 (같은 답 %d)" % [seen, same_without])
	check(old_covers == seen and moved == seen and covers == 0, "밭 자리 뒤에 돌이 서 있으면 (옛 자리는 가림 %d): 다른 자리로 옮긴 마을 %d / %d · 그래도 돌을 가리는 자리 %d" % [old_covers, moved, seen, covers])
	check(yard_covers == 0, "밭 자리 뒤에 묘지가 있으면: 묘지를 가리는 자리 %d" % yard_covers)
	check(fallback_same == seen and not rolled, "가리지 않는 자리가 없으면 옛 규칙의 자리 (%d / %d) · 주사위를 쓰지 않음" % [fallback_same, seen])
	# 계획 밖 옛 방식 (Village._find_spot의 밭 갈래): 주사위 수가 같고, 가리지 않는 자리를 고른다
	var was := VillagePlan.enabled
	VillagePlan.enabled = false
	var a := Village.new_prototype(20261108)
	a.water.offline = true
	var b := Village.new_prototype(20261108)
	b.water.offline = true
	var pa: Variant = a.find_spot("농장")
	if pa != null:
		_fake_grave(b, (pa as Vector2) + tw * 2.0)
	var pb: Variant = b.find_spot("농장")
	VillagePlan.enabled = was
	check(pa != null and pb != null and a.rng.state == b.rng.state and not VillageEra.field_by_grave(b, pb) and VillageEra.field_by_grave(b, pa),
		"옛 방식의 밭 자리도 돌을 가리지 않는 곳으로 · 굴린 주사위 수는 같다 (%s → %s)" % [pa, pb])


## (Q8 ⑨) 묘지 자리도 밭 안·밭 바로 뒤를 피한다 — 다른 자리가 없을 때만 옛 규칙. 밭이 곁에 없으면 예전과 같은 자리
func test_yard_field() -> void:
	var tw := _view_axis()
	var rt := Vector2(tw.y, -tw.x)
	var size: float = Balance.B["묘지"]["size"]
	var seen := 0
	var same := 0
	var moved := 0
	var by_field := 0
	var fallback_same := 0
	var rolled := false
	for sd in 12:
		var v := Village.new_prototype(20261100 + sd)
		v.water.offline = true
		v.chief_off = true
		var s0 := v.rng.state
		var p0: Variant = v.find_spot("묘지")
		if p0 == null:
			continue
		seen += 1
		var y0: Vector2 = p0
		var want0: Variant = _first_free(v, VillageEra.spot_center(v, "묘지"), size)
		if want0 != null and (want0 as Vector2).is_equal_approx(y0) and not VillageEra.yard_by_field(v, y0):
			same += 1
		# 옛 묘지 자리가 밭 바로 뒤가 되게 밭을 둔다 (4칸 — 겹치지는 않음)
		var fp := y0 - tw * 4.0
		var farm := v.add_building("농장", fp.x, fp.y, true)
		var p1: Variant = v.find_spot("묘지")
		if v.is_free(y0.x, y0.y, size) and VillageEra.yard_by_field(v, y0) and p1 != null and not (p1 as Vector2).is_equal_approx(y0):
			moved += 1
		if p1 == null or VillageEra.yard_by_field(v, p1):
			by_field += 1
		_drop(v, farm)
		# 빈 땅이 모두 밭 곁 (보는 축을 따라 7칸마다 밭) → 옛 규칙의 첫 빈 자리
		var farms: Array = []
		for i in range(-7, 8):
			for j in range(-7, 8):
				var q := y0 + tw * (3.5 + 7.0 * i) + rt * (3.5 + 7.0 * j)
				farms.append(v.add_building("농장", q.x, q.y, true))
		var want: Variant = _first_free(v, VillageEra.spot_center(v, "묘지"), size)
		var p2: Variant = v.find_spot("묘지")
		if want != null and p2 != null and (p2 as Vector2).is_equal_approx(want) and VillageEra.yard_by_field(v, p2):
			fallback_same += 1
		for f: Building in farms:
			_drop(v, f)
		rolled = rolled or v.rng.state != s0
	check(seen >= 8 and same == seen, "밭이 곁에 없는 마을 %d곳: 묘지 자리는 예전 그대로 (%d)" % [seen, same])
	check(moved == seen and by_field == 0, "옛 자리가 밭 바로 뒤가 되면: 옮긴 마을 %d / %d · 그래도 밭 곁인 자리 %d" % [moved, seen, by_field])
	check(fallback_same == seen and not rolled, "밭 곁이 아닌 빈 땅이 없으면 옛 규칙의 자리 (%d / %d) · 주사위를 쓰지 않음" % [fallback_same, seen])


## 옛 규칙의 자리 (Village._find_spot의 나선 — 첫 빈 자리)
func _first_free(v: Village, c: Vector2, size: float) -> Variant:
	var rad := 2.0
	var tr_r := v.territory_r()
	while rad < tr_r:
		for k in 24:
			var a := k / 24.0 * TAU + rad
			var p := c + Vector2(cos(a), sin(a)) * rad
			if v.is_free(p.x, p.y, size):
				return p
		rad += 0.8
	return null

