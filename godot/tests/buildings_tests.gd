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
	run.timed(self, ["test_upgrade_pick_second", "test_upgrade_pick_first", "test_upgrade_none", "test_wheat_stage", "test_wheat_reaped", "test_grave_siting", "test_grave_old_save"])


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
