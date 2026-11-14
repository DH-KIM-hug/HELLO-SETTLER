## 일손이 남을 때 (ROADMAP Q26, 2026-11-13 — Village.spare_want · design/gdd/mayor-decisions.md F2 13번 칸) — tests/run.gd가 부름 (`-- spare_hands` = 이것만).
## 병 60일 전에는 일어나지 않음 · 일 없는 성한 어른 4명 + 자재 + 빈 일터 < 연장일 때만 · 먹을 것 → 땔감 → 재료 차례 · 그 시대에 아는 건물만 ·
## 종류마다 상한 · 촌장의 한 번이 실제로 그 터를 잡고 연대기 한 줄 (쓰지 않는 말 없음) · 새로 저장하는 값 없음.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const D := Balance.DAY
const BANNED: Array = ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 일손이 남을 때 (Q26)")
	run.timed(self, ["test_not_before_day_60", "test_needs_idle_and_materials", "test_tools_vs_empty", "test_order_and_era", "test_caps", "test_chief_builds_it", "test_no_new_save_state", "test_q36_cap_grows"])


## 다 지은 건물만 남기고 (터 없음), 모든 일꾼을 풀어 연장은 창고로 — 일 없는 어른이 넉넉하고, 먹을 것은 모자라고, 판자 · 돌이 넉넉한 마을. 병 날 = day
func _spare_village(day := 70.0, seed_v := 20261113) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.advance(0.3 * D)
	v.chief_off = true
	v.buildings = v.buildings.filter(func(b: Building) -> bool: return b.built)
	for b: Building in v.buildings:
		if b.worker >= 0:
			var p := v.person(b.worker)
			if p != null:
				p.job = -1
			b.worker = -1
			v.stock["도구"] = float(v.stock["도구"]) + 1.0
	var n := 0
	for p: Resident in v.people:              # 어른이 넷이 안 되면 아이를 어른 나이로 (시험 마을 — 일손 수만 맞춤)
		if ToolShort.idle_hand(v, p):
			n += 1
	for p: Resident in v.people:
		if n >= 5:
			break
		if not p.is_adult():
			p.age = Balance.AGE_ADULT + 1.0
			if ToolShort.idle_hand(v, p):
				n += 1
	# 빈 일터는 모두 허물어 둔다 (빈 일터 0) — 연장은 넉넉히
	v.buildings = v.buildings.filter(func(b: Building) -> bool: return not b.def().get("job", false))
	v.stock["도구"] = 6.0
	v.stock["판자"] = 40.0
	v.stock["돌"] = 20.0
	for k: String in Balance.FOODS_ALL:
		if v.stock.has(k):
			v.stock[k] = 0.0
	v.t = day * D
	return v


func _hands(v: Village) -> int:
	var n := 0
	for p: Resident in v.people:
		if ToolShort.idle_hand(v, p):
			n += 1
	return n


func test_not_before_day_60() -> void:
	var v := _spare_village(59.5)
	check(_hands(v) >= Balance.SPARE_IDLE, "(시험 마을: 일 없는 성한 어른 %d명)" % _hands(v))
	check(v.spare_want() == "", "병 59.5일: 일손 · 자재 · 연장이 다 있어도 짓지 않음 (첫 60일은 예전과 같게)")
	v.t = Balance.SPARE_FROM_DAY * D
	check(v.spare_want() != "", "병 60일부터는 지음 (%s)" % v.spare_want())


func test_needs_idle_and_materials() -> void:
	var v := _spare_village()
	var busy := 0
	for p: Resident in v.people:              # 일 없는 어른을 SPARE_IDLE − 1 명만 남긴다 (나머지는 앓는 것으로 — 성한 일손이 아님)
		if ToolShort.idle_hand(v, p) and _hands(v) >= Balance.SPARE_IDLE:
			p.sick_left = D
			busy += 1
	check(_hands(v) == Balance.SPARE_IDLE - 1 and v.spare_want() == "", "일 없는 성한 어른이 %d명뿐이면 짓지 않음" % (Balance.SPARE_IDLE - 1))
	var w := _spare_village()
	w.stock["판자"] = 0.0
	w.stock["돌"] = 0.0
	check(w.spare_want() == "", "판자 · 돌이 없으면 짓지 않음")
	w.stock["판자"] = float(Balance.PLANK_RESERVE + 2)
	var got := w.spare_want()
	check(got != "" and int(Balance.B[got]["stone"]) == 0, "돌이 없고 판자만 있으면 돌이 들지 않는 일터만 (%s)" % got)


func test_tools_vs_empty() -> void:
	var v := _spare_village()
	v.stock["도구"] = 0.0
	check(v.spare_want() != "", "연장이 없어도 빈 일터가 하나도 없으면 하나는 지음 (비면 '연장이 모자라요' 신호가 켜지게)")
	var c := v.center
	var b := v.add_building("나무꾼", c.x + 9.0, c.y + 9.0, true)
	b.worker = -1
	check(v.spare_want() == "", "연장 0 · 빈 일터 1 → 더 짓지 않음")
	v.stock["도구"] = 1.0
	check(v.spare_want() == "", "연장 1 · 빈 일터 1 → 더 짓지 않음 (빈 일터가 연장보다 적을 때만)")
	v.stock["도구"] = 3.0
	check(v.spare_want() != "", "연장 3 · 빈 일터 1 → 지음")


func test_order_and_era() -> void:
	var v := _spare_village()
	check(v.spare_want() == "농장", "먹을 것이 모자라고 돌이 있으면 밭부터 (%s)" % v.spare_want())
	for k: String in Balance.FOODS_ALL:
		if v.stock.has(k):
			v.stock[k] = 0.0
	v.stock["빵"] = Balance.SPARE_FOOD_DAYS * Production.day_need(v) + 50.0
	var got := v.spare_want()
	check(got != "농장", "먹을 것이 %.0f일치 넘게 있으면 밭은 더 짓지 않음 (%s)" % [Balance.SPARE_FOOD_DAYS, got])
	var pos := {}
	for i in Balance.SPARE_ORDER.size():
		pos[Balance.SPARE_ORDER[i]] = i
	check(pos.has(got) and int(pos[got]) >= 1, "다음 차례 (먹을 것 → 땔감 → 재료)")
	v.era = 0                                 # 시대 0: 마을 시대 건물(어부)은 고르지 않는다 — 앞 차례를 하나씩 건너뛰며 봄
	var skip := {}
	var ok := true
	var seen: Array = []
	for i in Balance.SPARE_ORDER.size():
		var ty := v.spare_want(skip)
		if ty == "":
			break
		seen.append(ty)
		if not VillageEra.can_build(v, ty) or int(Balance.B[ty]["era"]) > v.era:
			ok = false
		skip[ty] = true
	check(ok and not ("어부" in seen), "시대 0: 고른 것 %s 은 모두 그 시대에 아는 건물 (어부 없음)" % str(seen))


func test_caps() -> void:
	var v := _spare_village()
	for k: String in Balance.FOODS_ALL:
		if v.stock.has(k):
			v.stock[k] = 0.0
	v.stock["빵"] = Balance.SPARE_FOOD_DAYS * Production.day_need(v) + 50.0     # 밭은 넉넉
	v.stock["도구"] = 20.0
	var skip := {"어부": true, "버섯꾼": true}
	var c := v.center
	var n0 := v.count_type("나무꾼")
	for i in int(Balance.SPARE_CAP["나무꾼"]) - n0:
		var b := v.add_building("나무꾼", c.x - 12.0 + i * 2.5, c.y - 12.0, true)
		b.worker = v.people[0].id                # 일꾼이 선 일터로 (빈 일터가 아니게 — 이 시험은 상한만 봄)
	check(v.count_type("나무꾼") >= int(Balance.SPARE_CAP["나무꾼"]) and v.spare_want(skip) != "나무꾼", "벌목장이 %d곳이면 더 짓지 않음 (%s)" % [int(Balance.SPARE_CAP["나무꾼"]), v.spare_want(skip)])
	var only_saw := {"농장": true, "어부": true, "버섯꾼": true, "나무꾼": true, "산림관": true}
	v.stock["통나무"] = float(Balance.ENOUGH["통나무"]) + 10.0
	v.stock["돌"] = float(Balance.ENOUGH["돌"]) + 2.0
	var saw_ok := v.spare_want(only_saw)
	v.stock["돌"] = float(Balance.ENOUGH["돌"]) - 1.0
	check(saw_ok == "제재소" and v.spare_want(only_saw) == "", "제재소는 통나무가 쌓이고 돌이 넉넉할 때만 (돌 %d 아래면 밭 · 집 몫으로 남김)" % int(Balance.ENOUGH["돌"]))
	var w := _spare_village()                 # 밭: 먹을 것이 모자라도 밭 수 × FARM_FEEDS가 식구에 닿으면 더 짓지 않음 (제물 때문에 창고 날치만으론 끝없이 늚)
	check(w.spare_want() == "농장", "(밭이 모자란 마을은 밭부터)")
	var k := 0
	while w.count_type("농장") * Balance.FARM_FEEDS < w.people.size():
		var fb := w.add_building("농장", c.x + 14.0, c.y - 14.0 + k * 3.0, true)
		fb.worker = w.people[0].id
		k += 1
	check(w.spare_want() != "농장", "밭 %d곳 × %d ≥ 식구 %d → 밭은 더 짓지 않음 (%s)" % [w.count_type("농장"), int(Balance.FARM_FEEDS), w.people.size(), w.spare_want()])


func test_chief_builds_it() -> void:
	var v := _spare_village()
	v.chief_off = false
	# 차례의 앞 칸이 바라는 것이 없게: 기본 일터를 다 세우고 (일꾼 자리는 마을 밖 사람 번호로 채움 — 빈 일터가 아님) 먹을 것은 넉넉히
	var c := v.center
	var i := 0
	for ty: String in ["오두막", "오두막", "오두막", "오두막", "농장", "농장", "나무꾼", "나무꾼", "맷돌간", "맷돌간", "화덕", "화덕", "우물", "제재소", "채석장", "산림관", "묘지"]:
		var sp: Variant = v.find_spot(ty)
		if sp == null:
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.worker = 90000 + i if b.def().get("job", false) else -1
		i += 1
	v.stats["died"] = 0
	v.stock["빵"] = Balance.SPARE_FOOD_DAYS * Production.day_need(v) + 400.0
	v.stock["판자"] = 60.0
	var before := v.buildings.size()
	var want := v.spare_want()
	var lines0 := v.book.size()
	v.chief_build()
	var added: Array = v.buildings.slice(before)
	var types := added.map(func(b: Building) -> String: return b.type)
	print("  촌장의 한 번: 바란 것 %s · 새 터 %s" % [want, str(types)])
	check(added.size() >= 1 and want in types, "촌장의 한 번이 그 일터의 터를 잡음")
	var txt := ""
	for e: Dictionary in v.book.slice(lines0):
		txt += String(e["text"]) + "\n"
	print("  연대기: %s" % txt.strip_edges())
	check(txt.contains("손이 노는"), "연대기 한 줄 (일손이 남아 하나 더)")
	var bad := ""
	for w: String in BANNED:
		if txt.contains(w):
			bad = w
	check(bad == "", "연대기 줄에 쓰지 않는 말 없음 (%s)" % bad)
	check(not txt.contains("%") and not txt.contains("SPARE"), "연대기 줄에 숫자 · 값 이름 없음")


func test_no_new_save_state() -> void:
	var v := _spare_village()
	var d := v.to_dict()
	var keys := d.keys().filter(func(k: Variant) -> bool: return String(k).contains("spare"))
	check(keys.is_empty(), "새로 저장하는 값 없음 (지금 상태만 봄)")
	var v2 := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(v2.spare_want() == v.spare_want(), "불러온 마을도 같은 판단 (%s)" % v2.spare_want())


## (Q36, 2026-11-14) 종류마다 상한은 식구가 SPARE_GROW_FROM 명을 넘으면 SPARE_GROW_PER 명마다 하나씩 는다 — 작은 마을은 예전 상한 그대로
func test_q36_cap_grows() -> void:
	var v := _spare_village()
	v.stock["빵"] = Balance.SPARE_FOOD_DAYS * Production.day_need(v) + 50.0     # 밭은 넉넉
	v.stock["도구"] = 40.0
	for ty: String in Balance.SPARE_CAP:
		if v.spare_cap(ty) != int(Balance.SPARE_CAP[ty]):
			check(false, "식구 %d명: %s 상한이 예전 그대로가 아님" % [v.people.size(), ty])
	check(v.people.size() <= Balance.SPARE_GROW_FROM, "(시험 마을 식구 %d명 ≤ %d)" % [v.people.size(), Balance.SPARE_GROW_FROM])
	check(v.spare_cap("농장") > 1000, "밭은 상한 대신 먹을 것 · 식구 잣대만")
	var c := v.center
	var n0 := v.count_type("나무꾼")
	for i in int(Balance.SPARE_CAP["나무꾼"]) - n0:
		var b := v.add_building("나무꾼", c.x - 12.0 + i * 2.5, c.y - 12.0, true)
		b.worker = 90000 + i
	var skip := {"농장": true, "어부": true, "버섯꾼": true}
	check(v.spare_want(skip) != "나무꾼", "작은 마을: 벌목장 %d곳이면 더 짓지 않음 (%s)" % [int(Balance.SPARE_CAP["나무꾼"]), v.spare_want(skip)])
	var k := 0
	while v.people.size() < Balance.SPARE_GROW_FROM + Balance.SPARE_GROW_PER:
		var p := v.add_person("시험%d" % k, "m" if k % 2 == 0 else "f", 2.0, "", c.x, c.y, null, null)    # 아이 — 일손 수는 그대로
		p.home = -1
		k += 1
	check(v.spare_cap("나무꾼") == int(Balance.SPARE_CAP["나무꾼"]) + 1, "식구 %d명: 벌목장 상한 하나 더 (%d)" % [v.people.size(), v.spare_cap("나무꾼")])
	check(v.spare_want(skip) == "나무꾼", "식구가 늘면 벌목장을 하나 더 (%s)" % v.spare_want(skip))
	var trees_was := v.trees
	var kept := 0
	var thin: Array = []
	var need := Balance.FOREST_MIN + Balance.SPARE_TREES_PER_CUTTER * (v.count_type("나무꾼") + 1 - int(Balance.SPARE_CAP["나무꾼"]))
	for tr: Dictionary in v.trees:              # 서 있는 나무를 다섯째 벌목장 몫(FOREST_MIN + SPARE_TREES_PER_CUTTER)보다 하나 적게
		if tr["s"] == "tree":
			if kept >= need - 1:
				continue
			kept += 1
		thin.append(tr)
	v.trees = thin
	check(v._standing_trees() >= Balance.FOREST_MIN and v.spare_want(skip) != "나무꾼", "나무 %d그루 — %d그루가 안 되면 다섯째 벌목장은 짓지 않음 (%s)" % [v._standing_trees(), need, v.spare_want(skip)])
	v.trees = trees_was
	while v.people.size() < Balance.SPARE_GROW_FROM + 3 * Balance.SPARE_GROW_PER:
		v.add_person("시험%d" % k, "m", 2.0, "", c.x, c.y, null, null)
		k += 1
	check(v.spare_cap("어부") == int(Balance.SPARE_CAP["어부"]) + 3, "식구 %d명: 어부 상한 셋 더 (%d)" % [v.people.size(), v.spare_cap("어부")])
	# 묘목원은 벌목장 둘에 하나까지 (상한이 늘어도 쉬는 묘목원이 쌓이지 않게)
	var fskip := {"농장": true, "어부": true, "버섯꾼": true, "나무꾼": true, "제재소": true}
	for i in 2 - v.count_type("산림관"):
		var fb := v.add_building("산림관", c.x + 12.0 + i * 2.5, c.y + 12.0, true)
		fb.worker = 91000 + i
	while v.count_type("나무꾼") < 4:
		var wb := v.add_building("나무꾼", c.x - 12.0 + v.count_type("나무꾼") * 2.5, c.y - 15.0, true)
		wb.worker = 92000 + v.count_type("나무꾼")
	check(v.count_type("나무꾼") == 4 and v.spare_want(fskip) != "산림관", "벌목장 넷 · 묘목원 둘 → 묘목원은 더 짓지 않음 (%s)" % v.spare_want(fskip))
	var wb2 := v.add_building("나무꾼", c.x - 12.0, c.y - 18.0, true)
	wb2.worker = 93000
	check(v.spare_want(fskip) == "산림관", "벌목장 다섯 → 묘목원 하나 더 (%s)" % v.spare_want(fskip))
	var fb3 := v.add_building("산림관", c.x + 15.0, c.y + 15.0, true)
	fb3.worker = 94000
	check(v.spare_want(fskip) != "산림관", "벌목장 다섯 · 묘목원 셋 → 숲이 넉넉하면 더 짓지 않음 (%s)" % v.spare_want(fskip))
	var only_saw := {"농장": true, "어부": true, "버섯꾼": true, "나무꾼": true, "산림관": true}
	v.stock["통나무"] = float(Balance.ENOUGH["통나무"]) + 10.0
	v.stock["돌"] = float(Balance.ENOUGH["돌"]) + 10.0
	var trees_ok := v._standing_trees() >= Balance.FOREST_MIN
	while v.count_type("제재소") < v.count_type("나무꾼"):
		var sb := v.add_building("제재소", c.x + 18.0 + v.count_type("제재소") * 3.0, c.y - 18.0, true)
		sb.worker = 95000 + v.count_type("제재소")
	check(trees_ok and v.spare_want(only_saw) == "", "제재소는 벌목장 수보다 적게 (%d · %d)" % [v.count_type("제재소"), v.count_type("나무꾼")])
	v.trees = v.trees.filter(func(tr: Dictionary) -> bool: return tr["s"] != "tree")     # 숲이 바닥남
	check(v.spare_want(fskip) == "산림관", "숲이 바닥나면 벌목장 둘에 하나를 넘어 묘목원을 더 (%s)" % v.spare_want(fskip))
	var sbx: Building = null
	for b: Building in v.buildings:
		if b.type == "제재소":
			sbx = b
	v.buildings.erase(sbx)
	check(v.spare_want(only_saw) == "", "숲이 바닥나면 제재소는 더 짓지 않음 (쌓인 통나무만 보고 늘지 않게)")
