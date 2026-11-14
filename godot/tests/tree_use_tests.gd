## 큰 나무 넷의 쓰임 (ROADMAP Q40, 2026-11-14 사용자 결정) — tests/run.gd가 부름 (`-- tree_use` = 이것만).
## 첫 20일엔 아무것도 · 본 나무만 · 철 · 먼 나무일수록 드물게 · 성하고 한가한 어른 2~4명 · 위기 · 잔치 · 추위 · 먹을 것 막기 ·
## 나무 아래 쉬는 장면 (밤이면 자고) · 송진 횃불 · 모깃불 · 은행알 = 맨 끝에 먹는 먹을 것 · 벚꽃 행복 (겹치지 않음) · 단풍 엿 잔치 (잔치마다 한 번) ·
## 처음 한 번 연대기 줄 (숫자 · 금지어 없음) · 그만두면 정리 · 저장 왕복.
extends RefCounted

var run: SceneTree
var quick := false
const D := Balance.DAY
const BANNED: Array = ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "기도", "제단"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 큰 나무 넷의 쓰임 (Q40)")
	run.timed(self, ["test_nothing_before_day20", "test_seen_and_season", "test_distance_rarer", "test_team", "test_blocked",
		"test_trip_scene", "test_gains_and_first_line", "test_cherry_happy", "test_resin_fires", "test_nuts_food", "test_sweets_feast",
		"test_cancel_tidy", "test_lines_clean", "test_save_round_trip", "test_daily_roll"])
	Village.default_created = {"year": 2026, "month": 4, "day": 15}


var _jw: JarWorld = null


## 6월 15일에 연 넓은 세상 (송진 철 · 따뜻한 밤) — 병 30일로
func _world(month := 6, day := 15) -> Village:
	Village.default_created = {"year": 2026, "month": month, "day": day}
	_jw = JarWorld.create_with_kit(31, WorldCfg.SIZE, Kits.make([]))
	var v := _jw.primary()
	v.water.offline = true
	v.t = 30.0 * D
	v.stock["빵"] = 50.0 * Production.day_need(v)
	return v


func _see_all(v: Village) -> void:
	for gt: Dictionary in (v.water as WorldWater).great_trees:
		v.explore_seen[String(gt["kind"])] = v.t


func _clean(text: String) -> bool:
	for w: String in BANNED:
		if text.contains(w):
			return false
	for c in "0123456789":
		if text.contains(c):
			return false
	return true


## 어른들을 한가하게 (쉼)
func _idle(v: Village) -> Array:
	var out: Array = []
	for p: Resident in v.people:
		if p.is_adult():
			ResidentAI.cancel(v, p)
			p.action = "idle"
			p.sleeping = false
			p.hunger = 0.0
			p.health = 1.0
			p.sick_left = 0.0
			p.injured_left = 0.0
			out.append(p)
	return out


func _babies_off(v: Village) -> void:
	v.people = v.people.filter(func(p: Resident) -> bool: return not p.is_baby())


func test_nothing_before_day20() -> void:
	var v := _world()
	_see_all(v)
	v.t = (Balance.TUSE_FROM_DAY - 0.5) * D
	check(TreeUses.blocked(v) == "early", "병 %.1f일: 나들이 없음 (early)" % (v.t / D))
	var before := v.to_dict()
	for h in 24:
		v.t += Balance.HOUR
		if v.t >= Balance.TUSE_FROM_DAY * D:
			break
		TreeUses.hourly(v)
	check(v.tree_use.is_empty() and TreeUses.happy(v) == 0.0, "첫 20일엔 나들이 상태 · 행복 몫 없음")
	check(Balance.TUSE_FROM_DAY >= Balance.EXPLORE_GOAL_DAY, "나들이는 탐험 목표 날(%.0f일) 뒤부터" % Balance.EXPLORE_GOAL_DAY)
	check(not before.has("stats") or not str(before["stats"]).contains("tuse_"), "첫 20일 기록에 tuse_ 칸 없음")
	var tiny := Village.new()
	check(TreeUses.blocked(tiny) == "small", "소형 병(넓은 세상 아님)은 나들이 없음")


func test_seen_and_season() -> void:
	var v := _world()
	check(TreeUses.seen_trees(v).is_empty(), "아무 나무도 못 봤으면 갈 곳 없음")
	v.explore_seen["pine"] = v.t
	v.explore_seen["fruit"] = v.t
	var s := TreeUses.seen_trees(v)
	check(s.size() == 1 and s.has("pine"), "본 나무만 (과일나무는 예전 열매 줍기 — 여기 없음): %s" % [s.keys()])
	check(TreeUses.in_season("cherry", 4, 5) and not TreeUses.in_season("cherry", 6, 1), "벚꽃 철: 4월 초 ○ · 6월 ✕")
	check(TreeUses.in_season("pine", 7, 1) and not TreeUses.in_season("pine", 12, 1), "송진: 여름 ○ · 겨울 ✕")
	check(TreeUses.in_season("ginkgo", 10, 20) and not TreeUses.in_season("ginkgo", 9, 1), "은행: 가을 ○ · 9월 초 ✕")
	check(TreeUses.in_season("maple", 3, 1) and not TreeUses.in_season("maple", 4, 10), "단풍 단물: 이른 봄 ○ · 4월 ✕")


func test_distance_rarer() -> void:
	for k: String in TreeUses.KINDS:
		var near := TreeUses.day_p(k, Balance.TUSE_NEAR * 0.5)
		var mid := TreeUses.day_p(k, Balance.TUSE_NEAR * 2.0)
		var far := TreeUses.day_p(k, Balance.TUSE_NEAR * 100.0)
		check(is_equal_approx(near, float(Balance.TUSE_DAY_P[k])) and mid < near and is_equal_approx(far, near * Balance.TUSE_FAR_MIN),
			"%s: 가까우면 %.2f · 두 배 멀면 %.2f · 아주 멀어도 %.2f" % [k, near, mid, far])


func test_team() -> void:
	var v := _world()
	_babies_off(v)
	var ad := _idle(v)
	var c := v.center + Vector2(100, 0)
	var tm := TreeUses.team(v, c)
	check(tm.size() >= Balance.TUSE_TEAM_MIN and tm.size() <= Balance.TUSE_TEAM_MAX, "한가한 어른 %d → %d명 (2~4)" % [ad.size(), tm.size()])
	check(tm.size() < ad.size() or ad.size() <= Balance.TUSE_TEAM_MIN, "한가한 사람을 모두 데려가지 않음 (절반쯤)")
	var a: Resident = ad[0]
	a.sick_left = 100.0
	var b: Resident = ad[1]
	b.action = "work"
	var e: Resident = ad[2] if ad.size() > 2 else null
	if e != null:
		v.explorer = e.id
	var tm2 := TreeUses.team(v, c)
	check(not a in tm2 and not b in tm2 and (e == null or not e in tm2), "앓는 사람 · 일하는 사람 · 탐험가는 빼고")
	for p: Resident in ad:
		p.action = "work"
	check(TreeUses.team(v, c).is_empty(), "한가한 어른이 둘이 안 되면 가지 않음")
	v.explorer = -1


func test_blocked() -> void:
	var v := _world()
	_see_all(v)
	check(TreeUses.blocked(v) == "", "6월 병 30일 · 먹을 것 넉넉 · 위기 없음 → 떠날 수 있음 (%s)" % TreeUses.blocked(v))
	v.deficit = 1.0
	check(TreeUses.blocked(v) == "crisis", "위기(먹을 것 모자람) → crisis")
	v.deficit = 0.0
	v.festival_t = v.t - Balance.HOUR
	check(TreeUses.blocked(v) == "feast", "축제 중 → feast")
	v.festival_t = -1.0e9
	v.cold_season = true
	check(TreeUses.blocked(v) == "cold", "추위가 오는 철 → cold")
	v.cold_season = false
	var w := _world(1, 10)
	_see_all(w)
	check(TreeUses.blocked(w) == "cold", "한겨울(1월) 밤이 추움 → cold (%s)" % TreeUses.blocked(w))
	check(TreeUses.too_cold(w, "maple"), "한겨울 밤은 단풍 단물에도 너무 추움")
	var m := _world(3, 1)
	m.cold_season = true
	check(TreeUses.too_cold(m, "pine") and not TreeUses.too_cold(m, "maple"), "3월 초: 추위가 오는 철이어도 단풍 단물은 감 (밤이 얼고 낮에 녹는 철) · 다른 나무는 안 감")
	check(TreeUses.blocked(m, "*") == "", "\"*\" = 추위는 보지 않고 다른 까닭만 (%s)" % TreeUses.blocked(m, "*"))
	v.stock["빵"] = 0.0
	for k: String in Balance.FOODS_ALL:
		v.stock[k] = 0.0
	v.stock["밀"] = 0.0
	var fb := TreeUses.blocked(v)
	check(fb == "food" or fb == "crisis", "먹을 것이 모자라면 떠나지 않음 (%s)" % fb)
	v.stock["빵"] = 50.0 * Production.day_need(v)
	v.tree_use["out"] = {"kind": "pine", "ids": [1], "t": v.t}
	check(TreeUses.blocked(v) == "out", "한 번에 한 나들이만")
	v.tree_use["out"] = {}
	v.tree_use["last"] = v.t - D
	check(TreeUses.blocked(v) == "gap", "다녀온 지 얼마 안 됨 → gap")


func test_trip_scene() -> void:
	var v := _world()
	_babies_off(v)
	_see_all(v)
	_idle(v)
	var n := TreeUses.go(v, "pine")
	var tr: Dictionary = TreeUses.seen_trees(v)["pine"]
	check(n >= 2 and n <= 4, "소나무로 %d명이 떠남" % n)
	var ids: Array = v.tree_use["out"]["ids"]
	var ok := true
	var sit := true
	var cancel_last := true
	for id: int in ids:
		var r := v.person(id)
		if r.action != TreeUses.ACTION:
			ok = false
		var w: Dictionary = r.steps[0]
		if Vector2(float(w["x"]), float(w["y"])).distance_to(tr["c"]) > float(tr["r"]) * Balance.TUSE_SIT_K + Balance.TUSE_SIT_R + 17.0:
			ok = false
		if not r.steps.any(func(s: Dictionary) -> bool: return s["k"] == "do" and s["anim"] == "sit"):
			sit = false
		var last: Dictionary = r.steps[-1]
		if last.get("cancel") == null or String(last["cancel"]["op"]) != "tuse_quit":
			cancel_last = false
	check(ok, "모두 나들이 중 · 첫 걸음은 나무 줄기 곁")
	check(sit, "나무 아래 앉아 쉬는 장면 (sit)")
	check(cancel_last, "마지막 걸음에 그만둠(tuse_quit)")
	check(int(v.stats.get("tuse_trips_pine", 0)) == 1, "나들이 수 셈")
	# 밤에 닿으면 그 아래에서 자고 아침에
	var r0 := v.person(int(ids[0]))
	var hn := v.hour_now()
	v.t += fmod(23.0 - hn + 24.0, 24.0) * Balance.HOUR
	r0.steps.pop_front()
	var arrive: Dictionary = r0.steps.pop_front()
	ResidentAI.run_op(v, r0, arrive["done"])
	check(r0.steps[0]["anim"] == "sleep" and r0.doing == TreeUses.DOING_SLEEP, "밤에 닿음 → 나무 아래에서 잠 (%s)" % r0.doing)
	var wake := v.t + float(r0.steps[0]["left"])
	var wh := fmod(v.start_clock + wake, D) / Balance.HOUR
	check(wh >= Balance.NIGHT_TO and wh < Balance.NIGHT_TO + 1.0, "아침 %.1f시에 일어남" % wh)


func test_gains_and_first_line() -> void:
	var v := _world()
	_babies_off(v)
	_see_all(v)
	for kind: String in ["pine", "ginkgo", "maple"]:
		_idle(v)
		v.tree_use["out"] = {}
		var item := String(TreeUses.ITEM[kind])
		var had := float(v.stock.get(item, 0.0))
		var n := TreeUses.go(v, kind)
		var nb := v.book.size()
		var ids: Array = (v.tree_use["out"]["ids"] as Array).duplicate()
		for id: int in ids:
			var r := v.person(id)
			ResidentAI.run_op(v, r, ResidentAI.op("tuse_take", {"kind": kind}))
			check(r.carry == String(TreeUses.CARRY[kind]) and r.carry_amt > 0.0, "%s: %s 지고 옴" % [kind, r.carry])
			r.steps.clear()
			ResidentAI.run_op(v, r, ResidentAI.op("tuse_put", {"kind": kind}))
		var got := float(v.stock.get(item, 0.0)) - had
		var per := {"pine": Balance.RESIN_LOAD, "ginkgo": Balance.NUTS_LOAD, "maple": Balance.SAP_LOAD * Balance.SAP_TO_SWEETS}
		check(is_equal_approx(got, n * float(per[kind])), "%s: %d명 → 창고 %s +%.1f" % [kind, n, item, got])
		check(v.book.size() == nb + 1 and v.tree_use["first"].has(kind), "%s: 처음 한 번 연대기 한 줄" % kind)
		check((v.tree_use["out"] as Dictionary).is_empty(), "%s: 모두 내려놓으면 나들이 끝" % kind)
		# 두 번째는 줄 없음
		_idle(v)
		TreeUses.go(v, kind)
		var nb2 := v.book.size()
		for id: int in (v.tree_use["out"]["ids"] as Array).duplicate():
			var r := v.person(id)
			ResidentAI.run_op(v, r, ResidentAI.op("tuse_take", {"kind": kind}))
			r.steps.clear()
			ResidentAI.run_op(v, r, ResidentAI.op("tuse_put", {"kind": kind}))
		check(v.book.size() == nb2, "%s: 두 번째엔 연대기 줄 없음" % kind)
	check(not TreeUses.want(v, "pine") or float(v.stock.get(TreeUses.RESIN, 0.0)) < Balance.RESIN_WANT, "송진이 넉넉하면 소나무로 가지 않음")


func test_cherry_happy() -> void:
	var v := _world(4, 1)
	_babies_off(v)
	_see_all(v)
	_idle(v)
	v._update_happiness()
	var h0 := v.avg_happiness()
	TreeUses.go(v, "cherry")
	var ids: Array = (v.tree_use["out"]["ids"] as Array).duplicate()
	for id: int in ids:
		var r := v.person(id)
		r.steps.clear()
		ResidentAI.run_op(v, r, ResidentAI.op("tuse_put", {"kind": "cherry"}))
	check(is_equal_approx(TreeUses.happy(v), Balance.CHERRY_HAPPY), "벚꽃 나들이 뒤 행복 + %.2f" % TreeUses.happy(v))
	check(float(v.tree_use["cherry_until"]) <= v.t + Balance.CHERRY_HAPPY_DAYS * D + 1.0, "… %.0f일 동안 (여럿이 돌아와도 늘어날 뿐 겹치지 않음)" % Balance.CHERRY_HAPPY_DAYS)
	v._update_happiness()
	check(v.avg_happiness() > h0, "마을 평균 행복이 오름 (%.3f → %.3f)" % [h0, v.avg_happiness()])
	v.t += (Balance.CHERRY_HAPPY_DAYS + 0.1) * D
	check(TreeUses.happy(v) == 0.0, "며칠 뒤엔 사라짐")
	var per: Dictionary = v.tree_use["season_n"]
	check(int(per.get(TreeUses.season_key("cherry", Health.jar_date(v)), 0)) == 1, "철마다 횟수를 셈 (상한 %d)" % int(Balance.TUSE_SEASON_MAX["cherry"]))


func test_resin_fires() -> void:
	var v := _world()
	check(not TreeUses.use_resin(v), "송진이 없으면 예전 그대로")
	v.stock[TreeUses.RESIN] = 1.0
	v.stock["통나무"] = 10.0
	var r: Resident = _idle(v)[0]
	v.smalls.run_op(v, r, {"op": "crisis_smoke", "x": r.x, "y": r.y})
	var sm: Dictionary = v.smalls.smokes[-1]
	check(is_equal_approx(float(sm["until"]) - v.t, Balance.GNAT_SMOKE_TIME * Balance.RESIN_SMOKE), "송진 모깃불: 연기가 더 오래")
	check(is_equal_approx(float(v.stock["통나무"]), 10.0 - Balance.GNAT_SMOKE_LOG * Balance.RESIN_SMOKE_LOG), "… 통나무를 덜 씀")
	check(is_equal_approx(float(v.stock[TreeUses.RESIN]), 1.0 - Balance.RESIN_PER_FIRE), "… 송진을 씀")
	v.stock[TreeUses.RESIN] = 0.0
	v.smalls.run_op(v, r, {"op": "crisis_smoke", "x": r.x, "y": r.y})
	check(is_equal_approx(float(v.smalls.smokes[-1]["until"]) - v.t, Balance.GNAT_SMOKE_TIME), "송진이 떨어지면 여느 모깃불")
	check(Balance.RESIN_TORCH > 1.0, "송진 횃불은 털뭉치를 더 쪼그라뜨림 (×%.1f)" % Balance.RESIN_TORCH)


func test_nuts_food() -> void:
	var v := _world()
	for k: String in Balance.FOODS_ALL:
		v.stock[k] = 0.0
	v.stock["밀"] = 0.0
	var f0 := v.food_total()
	v.stock[TreeUses.NUTS] = 100.0
	check(is_equal_approx(v.food_total() - f0, 100.0), "은행알은 먹을 것 (food_total)")
	v.stock["버섯"] = 50.0
	Production.consume(v, 30.0)
	check(is_equal_approx(float(v.stock[TreeUses.NUTS]), 100.0), "다른 먹을 것이 있으면 은행알은 남겨 둠 (겨울 먹을 것)")
	Production.consume(v, 60.0)
	check(float(v.stock[TreeUses.NUTS]) < 100.0, "다른 것이 떨어지면 은행알을 먹음")
	check(Balance.FOODS[-1] == TreeUses.NUTS and Balance.FOODS_ALL[-1] == "씨앗 우유", "먹는 차례: FOODS 맨 끝 (부엌 것은 그대로 뒤)")


func test_sweets_feast() -> void:
	var v := _world()
	v.stock[TreeUses.SWEETS] = 2.0
	var nb := v.book.size()
	TreeUses.hourly(v)
	check(is_equal_approx(float(v.stock[TreeUses.SWEETS]), 2.0), "잔치가 없으면 엿을 꺼내지 않음")
	v.festival_t = v.t
	v.t += 60.0
	TreeUses.hourly(v)
	check(is_equal_approx(float(v.stock[TreeUses.SWEETS]), 2.0 - Balance.SWEETS_FEAST_USE) and is_equal_approx(TreeUses.happy(v), Balance.SWEETS_HAPPY), "축제 → 엿 하나 · 행복 + %.2f" % Balance.SWEETS_HAPPY)
	check(v.book.size() == nb + 1, "처음 엿이 돈 잔치 — 연대기 한 줄")
	v.t += Balance.HOUR
	TreeUses.hourly(v)
	check(is_equal_approx(float(v.stock[TreeUses.SWEETS]), 2.0 - Balance.SWEETS_FEAST_USE), "같은 잔치엔 한 번만")
	v.t += (Balance.FESTIVAL_DAYS + 0.1) * D
	check(TreeUses.happy(v) == 0.0, "잔치가 지나면 엿 몫도 끝")


func test_cancel_tidy() -> void:
	var v := _world()
	_babies_off(v)
	_see_all(v)
	_idle(v)
	TreeUses.go(v, "ginkgo")
	var ids: Array = (v.tree_use["out"]["ids"] as Array).duplicate()
	for id: int in ids:
		ResidentAI.cancel(v, v.person(id))
	check((v.tree_use["out"] as Dictionary).is_empty(), "모두 그만두면 나들이 끝 (tuse_quit)")
	TreeUses.go(v, "ginkgo")
	for id: int in (v.tree_use["out"]["ids"] as Array):
		v.person(id).action = "idle"
	TreeUses._tidy(v, v.tree_use)
	check((v.tree_use["out"] as Dictionary).is_empty(), "걸음이 끊긴 나들이는 정리 (_tidy)")


func test_lines_clean() -> void:
	var bad: Array = []
	for d: Dictionary in [TreeUses.FIRST_LINE, TreeUses.SAY_GO, TreeUses.SAY_REST, TreeUses.DOING_GO, TreeUses.DOING_REST, TreeUses.DOING_WORK, TreeUses.DOING_BACK]:
		for k: String in d:
			if not _clean(String(d[k]).replace("%s", "")):
				bad.append(d[k])
	for s: String in [TreeUses.SWEET_LINE, TreeUses.DOING_SLEEP]:
		if not _clean(s):
			bad.append(s)
	check(bad.is_empty(), "주민 쪽 글에 숫자 · 금지어 없음 %s" % [bad])
	check(TreeUses.FIRST_LINE["ginkgo"].contains("냄새"), "은행 — 냄새 한 줄")


func test_save_round_trip() -> void:
	var v := _world()
	_babies_off(v)
	_see_all(v)
	_idle(v)
	TreeUses.go(v, "pine")
	v.stock[TreeUses.RESIN] = 1.5
	v.tree_use["cherry_until"] = v.t + D
	SaveCodec.errors = 0
	var d := v.to_dict()
	var w := Village.from_dict(d, v.water)
	check(SaveCodec.errors == 0, "저장 오류 없음")
	check(str(w.tree_use) == str(v.tree_use) and is_equal_approx(float(w.stock[TreeUses.RESIN]), 1.5), "나들이 상태 · 송진 저장 왕복")
	var id := int(v.tree_use["out"]["ids"][0])
	var a := v.person(id)
	var b := w.person(id)
	check(b != null and b.action == TreeUses.ACTION and b.steps.size() == a.steps.size(), "나들이 걸음도 그대로 이어짐")


## 하루 한 번 주사위 (마을 난수를 쓰지 않음) · 아침에만
func test_daily_roll() -> void:
	var v := _world()
	_babies_off(v)
	_see_all(v)
	_idle(v)
	var st := v.rng.state
	var hn := v.hour_now()
	v.t += fmod(Balance.TUSE_HOURS.x + 0.5 - hn + 24.0, 24.0) * Balance.HOUR
	TreeUses.hourly(v)
	check(v.rng.state == st, "주사위는 마을 난수를 쓰지 않음")
	check(int(v.tree_use.get("day", -1)) == v.cal_day(v.t), "오늘 주사위를 굴림")
	var trips := int(v.stats.get("tuse_trips_pine", 0))
	TreeUses.hourly(v)
	check(int(v.stats.get("tuse_trips_pine", 0)) == trips, "같은 날 두 번 굴리지 않음")
	var got := 0
	for i in 60:
		v.tree_use = {}
		v.t += D
		_idle(v)
		TreeUses.hourly(v)
		if not (v.tree_use.get("out", {}) as Dictionary).is_empty():
			got += 1
	var p := TreeUses.day_p("pine", float(TreeUses.seen_trees(v)["pine"]["d"]))
	check(got > 0 and absf(got / 60.0 - p) < 0.2, "60번의 아침 가운데 %d번 소나무로 (몫 %.2f)" % [got, p])
