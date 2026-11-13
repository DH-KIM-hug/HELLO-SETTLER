## 서로 돌보는 모습 1차 (ROADMAP E2-4 — view/daily_view.gd ⑨ 수프 · ⑩ 맞이 · ⑪ 가르치기) — 그림으로만.
## 장면을 띄우는 묶음 (TREE_SUITES). tests/run.gd가 부름: 전체·quick·`-- care`. 하루의 흐름 묶음(daily_tests)의 도우미를 그대로 씀.
## 성질을 본다:
##   · 수프: 사이가 가장 좋은 쉬는 이웃 (없으면 식구)이 그릇을 들고 그 집 문 앞까지 걸어가 내려놓고 "얼른 나아요." → 걸어서 돌아감, 앓는 이마다 하루 한 번
##   · 맞이: 반기는 마을 = 가까운 이웃이 다가와 손을 흔들고 한 사람이 빵을 건넴 · 서먹한 마을 = 멀찍이 서서 바라봄, 내려옴마다 한 번
##   · 가르치기: 한가한 아이가 일하는 어른 곁에 서서 지켜보다 빈손으로 따라 함 ("이렇게 하는 거야." — 부모·조부모의 일터 먼저), 아이마다 하루 한 번
##   · 공통: 화면 말풍선만 (시뮬의 말·연대기 그대로) · 추운 날·위기·밤·잔치·혼례·오프닝·빠른 흐름에는 없음 ·
##     병이 낫는 빠르기·행복·창고·난수·저장 지문이 화면 없는 마을과 똑같음 (씨앗 4개 — quick 2일 · long 20일)
extends "res://tests/daily_tests.gd"

const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "제단", "기도"]
const SEEDS := [20261114, 20261115, 20261116, 20261117]


func all() -> void:
	print("== 서로 돌보는 모습 1차: 수프 · 맞이 · 가르치기 (E2-4 — 그림으로만)")
	var old := CutoutResident.override
	CutoutResident.override = 1
	run.timed(self, ["test_care_lines", "test_soup", "test_soup_kin", "test_welcome_warm", "test_welcome_cold", "test_teach", "test_care_gate",
		"test_care_sim_same"])
	if not quick:                                      # 씨앗 4개 × 20일 (전체 시험에서만 — quick은 3일)
		run.timed(self, ["test_care_sim_same_long"])
	if _scn != null:
		_drop(_scn)
		_scn = null
		_fv = null
	CutoutResident.override = old


# ───────────────────────── 도우미 ─────────────────────────
func _care(hour: float, keep: int) -> Array:
	var s := _fix(hour, true)
	_only(s[3], [keep])
	(s[2] as VillageView).stage_say.clear()
	(s[1] as Village).crises.clear()
	return s


## 이 화면이 띄운 말풍선 (없으면 "")
func _said(vw: VillageView, dv: DailyView, r: Resident) -> String:
	var s: Array = vw.stage_say.get(r.id, [])
	return String(s[0]) if not s.is_empty() and dv.own_say(r.id) else ""


func _kid(v: Village) -> Resident:
	for r in v.people:
		if r.age < Balance.AGE_ADULT and not r.is_baby() and not r.dead and not r.parents.is_empty():
			return r
	return null


func _sim(v: Village) -> String:
	return "%s|%s|%s|%s" % [_work(v), str(v.stock), str(v.book.size()), str(v.people.map(func(r: Resident) -> Array: return [r.sick_left, snappedf(r.happiness, 0.0001), r.say]))]


# ───────────────────────── 말 ─────────────────────────
func test_care_lines() -> void:
	var bad: Array = []
	for line: String in [DailyView.SOUP_SAY, DailyView.TEACH_SAY]:
		for w: String in FORBID:
			if line.contains(w):
				bad.append(w)
		for c in "0123456789%":
			if line.contains(c):
				bad.append(c)
	check(bad.is_empty(), "돌봄의 말에 금지어·숫자 없음 (깨닫기 전에도 쓸 수 있는 말) %s" % str(bad))
	var src := FileAccess.get_file_as_string(SRC)
	check(not src.contains("log_line") and not src.contains("v.speak") and not src.contains(".book"), "돌봄 장면은 연대기·시뮬의 말을 쓰지 않음 (화면 말풍선만)")


# ───────────────────────── ⑨ 수프 ─────────────────────────
func test_soup() -> void:
	var s := _care(11.0, DailyView.SOUP)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var ppl := _loose(v, 3)
	var sick: Resident = ppl[0]
	var c: Resident = ppl[1]          # 사이가 좋은 이웃
	var x: Resident = ppl[2]          # 남
	sick.partner = -1
	c.partner = -1
	x.partner = -1
	_park(v, ppl)
	_steps(vw, dv, 0.1)
	var hm := v.bld(sick.home)
	var door := Vector2(hm.x, hm.y) + dv._front * (dv.front_of(hm) + DailyView.DOOR_OUT)
	_put(sick, hm.x, hm.y + 0.3, "sleep", "sick")
	sick.sick_left = Balance.DAY
	sick.disease = "고뿔"
	var sick0 := sick.sick_left
	_put(c, door.x + dv._right.x * 2.6 + dv._front.x * 0.7, door.y + dv._right.y * 2.6 + dv._front.y * 0.7, "idle", "rest")
	_put(x, door.x - dv._right.x * 2.2 + dv._front.x * 0.9, door.y - dv._right.y * 2.2 + dv._front.y * 0.9, "idle", "rest")
	Social.rec(v, c.id, sick.id)["b"] = 60.0
	Social.rec(v, x.id, sick.id)["b"] = 10.0
	vw.sync(0.0, true)
	_aim(s[0], door, 44.0)
	var before := _sim(v)
	check(dv._model(sick) == null, "(준비) 앓는 사람은 집 안에 누움 (인형이 숨음)")
	_steps(vw, dv, 0.8)
	check(dv.kind_of(c.id) == DailyView.SOUP and not dv.holding(x.id), "사이가 가장 좋은 쉬는 이웃이 수프를 들고 감 (사이가 덜한 이웃은 아님)")
	var last := dv.drawn(c.id)
	var jump := 0.0
	var carried := true
	var bowl := true
	for i in int((DailyView.SOUP_APPROACH_MAX + 0.5) / DT):
		if dv.playing(DailyView.SOUP):
			break
		_tick(vw, dv)
		var d := dv.drawn(c.id).distance_to(last)
		jump = maxf(jump, d)
		last = dv.drawn(c.id)
		if dv.playing(DailyView.SOUP):
			break
		if d > 0.02:
			carried = carried and _hint(vw, c) == "carry"
		bowl = bowl and _prop_kinds(dv) == ["bowl"]
	check(dv.playing(DailyView.SOUP) and carried and bowl and jump <= DailyView.SOUP_WALK * DT + 0.001, "김 나는 그릇을 두 손에 들고 걸어감 (순간이동 없음 — 한 화면에 %.3f칸)" % jump)
	var at := dv.drawn(c.id)
	check(at.distance_to(door) < DailyView.DOOR_WIDE + 0.05 and (at - Vector2(hm.x, hm.y)).dot(dv._front) >= dv.front_of(hm), "그 집 문 앞 (집 그림 앞)에 섬 (%.2f칸)" % at.distance_to(door))
	var said := false
	var ground := false
	var leaned := false
	for i in int(DailyView.SOUP_DUR / DT) - 2:
		_tick(vw, dv)
		said = said or _said(vw, dv, c) == DailyView.SOUP_SAY
		ground = ground or not dv.bub.grounds.is_empty()
		leaned = leaned or dv.pose_of(c.id).w > 0.2
	check(said and ground and leaned, "숙여 그릇을 문 앞 땅에 내려놓고 \"%s\" (화면 말풍선)" % DailyView.SOUP_SAY)
	check(c.say == "" and sick.say == "", "시뮬의 말은 그대로 (말풍선은 화면에만)")
	var back := false
	for i in int(8.0 / DT):
		_tick(vw, dv)
		if not dv.holding(c.id):
			back = true
			break
	check(back and _resting(vw, c), "걸어서 제자리로 돌아가 놓임")
	check(not dv.bub.grounds.is_empty(), "그릇은 문 앞에 잠깐 남음 (그림)")
	_steps(vw, dv, DailyView.SOUP_LEAVE + 0.3)
	check(dv.bub.grounds.is_empty(), "남은 그릇은 잠시 뒤 사라짐")
	check(_sim(v) == before and is_equal_approx(sick.sick_left, sick0), "병이 낫는 빠르기·창고·연대기·행복·일은 그대로 (그림뿐)")
	_steps(vw, dv, 3.0)
	check(int(dv.started[DailyView.SOUP]) == 1, "앓는 이마다 하루 한 번 (같은 날 다시 가지 않음)")
	Social.pairs(v).erase(Social.key(c.id, sick.id))
	Social.pairs(v).erase(Social.key(x.id, sick.id))
	sick.sick_left = 0.0
	sick.disease = ""
	_done(s)


func test_soup_kin() -> void:
	var s := _care(13.0, DailyView.SOUP)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var ppl := _loose(v, 3)
	var sick: Resident = ppl[0]
	var c: Resident = ppl[1]          # 남 (사이 없음)
	var f: Resident = ppl[2]          # 식구
	sick.partner = f.id
	f.partner = sick.id
	c.partner = -1
	_park(v, ppl)
	_steps(vw, dv, 0.1)
	var hm := v.bld(sick.home)
	var door := Vector2(hm.x, hm.y) + dv._front * (dv.front_of(hm) + DailyView.DOOR_OUT)
	_put(sick, hm.x, hm.y + 0.3, "sleep", "sick")
	sick.sick_left = Balance.DAY
	sick.disease = "고뿔"
	_put(c, door.x + dv._right.x * 1.6 + dv._front.x * 0.6, door.y + dv._right.y * 1.6 + dv._front.y * 0.6, "idle", "rest")
	_put(f, door.x - dv._right.x * 2.4 + dv._front.x * 1.0, door.y - dv._right.y * 2.4 + dv._front.y * 1.0, "idle", "rest")
	Social.pairs(v).erase(Social.key(c.id, sick.id))
	Social.pairs(v).erase(Social.key(f.id, sick.id))
	vw.sync(0.0, true)
	_steps(vw, dv, 0.8)
	check(dv.kind_of(f.id) == DailyView.SOUP and not dv.holding(c.id), "사이가 좋은 이웃이 없으면 식구가 가져감 (더 가까운 남은 아님)")
	dv.clear()
	vw.stage_say.clear()
	sick.sick_left = 0.0
	sick.disease = ""
	_done(s)


# ───────────────────────── ⑩ 맞이 ─────────────────────────
## 새 이웃 n을 빈 땅에 세우고 이웃 넷을 둘레에 — [장면들, n, 이웃들, 가운데]
func _welcome_fix(kind: String) -> Array:
	var s := _care(10.0, DailyView.WELCOME)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var ppl := _loose(v, 5)
	for r in v.people:                             # 어른이 모자라면 아이도 (새 이웃 · 빵을 건넬 사람은 어른)
		if ppl.size() < 5 and not ppl.has(r) and not r.is_baby() and not r.dead and not r.is_sick() and not r.is_injured():
			ppl.append(r)
	_park(v, ppl)
	_steps(vw, dv, 0.1)
	var c := _clearing(dv, v, 3.0)
	var n: Resident = ppl[0]
	_put(n, c.x, c.y, "idle", "idle")
	var offs := [Vector2(2.6, 1.2), Vector2(-2.8, 0.9), Vector2(3.2, -1.4), Vector2(-3.0, -1.6)]
	for i in 4:
		var o: Vector2 = offs[i]
		var p := c + dv._right * o.x + dv._front * o.y
		_put(ppl[i + 1], p.x, p.y, "idle", "rest")
	v.migrants = {"t": v.t - 600.0, "until": v.t + Balance.DAY, "mood": 0.0, "kind": kind, "ids": [n.id]}
	vw.sync(0.0, true)
	_aim(s[0], c, 44.0)
	return [s, n, ppl.slice(1), c]


func test_welcome_warm() -> void:
	var w := _welcome_fix("welcome")
	var s: Array = w[0]
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var n: Resident = w[1]
	var nb: Array = w[2]
	var before := _sim(v)
	var mig := str(v.migrants)
	_steps(vw, dv, 0.8)
	var cast := dv.cast(DailyView.WELCOME)
	check(dv.kind_of(n.id) == DailyView.WELCOME and dv.role_of(n.id) == 0 and cast.size() >= 4 and cast.size() <= 5, "새 이웃이 온 날: 가까운 이웃 서넛이 다가옴 (%d명)" % (cast.size() - 1))
	check(_until(vw, dv, DailyView.WELCOME, DailyView.WELCOME_APPROACH_MAX + 0.5), "모두 걸어와 둘레에 섬")
	var giver := -1
	for id in cast:
		if dv.role_of(id) == 1:
			giver = id
	check(giver >= 0 and v.person(giver).age >= Balance.AGE_ADULT, "빵을 건넬 사람은 어른")
	var near := true
	var gap := INF
	for id in cast:
		if id != n.id:
			near = near and dv.drawn(id).distance_to(dv.drawn(n.id)) < 1.4
		for j in cast:
			if j != id:
				gap = minf(gap, absf((dv.drawn(id) - dv.drawn(j)).dot(dv._right)) + absf((dv.drawn(id) - dv.drawn(j)).dot(dv._front)))
	check(near and gap > 0.3, "반기는 마을: 가까이 둘러섬 · 서로 겹치지 않음 (가장 가까운 둘 %.2f칸)" % gap)
	var waved := {}
	var wave_fx := false
	var loaf_moved := false
	var got := false
	var heart := false
	for i in int(DailyView.WELCOME_DUR / DT) - 2:
		_tick(vw, dv)
		for id in cast:
			if id != n.id and _doll(vw, v.person(id)).react_hint == "lookup":
				waved[id] = true
		for it: Array in dv.bub.fx:
			wave_fx = wave_fx or String(it[1]) == "wave"
		for it: Array in dv.bub.props:
			if String(it[0]) == "loaf" and it[4] != null:
				loaf_moved = true
			if String(it[0]) == "loaf" and it[1] == _doll(vw, n) and it[4] == null:
				got = true
		for it: Array in dv.bub.items:
			heart = heart or (it[0] == _doll(vw, n) and String(it[1]) == "heart")
	check(waved.size() == cast.size() - 1 and wave_fx, "이웃들이 손을 흔듦 (%d/%d명)" % [waved.size(), cast.size() - 1])
	check(loaf_moved and got and heart, "한 사람이 빵을 손에서 손으로 건네고, 새 이웃이 빵을 안고 작은 하트")
	check(_sim(v) == before and str(v.migrants) == mig, "있던 말·연대기·행복·창고·맞이 기록은 그대로 (그림뿐)")
	_steps(vw, dv, 8.0)
	_steps(vw, dv, 3.0)
	check(int(dv.started[DailyView.WELCOME]) == 1 and dv.cast().is_empty(), "내려옴마다 한 번 · 끝나면 모두 놓임")
	v.migrants = {}
	_done(s)


func test_welcome_cold() -> void:
	var w := _welcome_fix("wary")
	var s: Array = w[0]
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var n: Resident = w[1]
	var before := _sim(v)
	_steps(vw, dv, 0.8)
	check(_until(vw, dv, DailyView.WELCOME, DailyView.WELCOME_APPROACH_MAX + 0.5), "서먹한 마을도 모여 섬")
	var cast := dv.cast(DailyView.WELCOME)
	var far := true
	for id in cast:
		if id != n.id:
			far = far and dv.drawn(id).distance_to(dv.drawn(n.id)) > 1.7
	var waved := false
	var loaf := false
	var looked := true
	for i in int(DailyView.WELCOME_COLD_DUR / DT) - 2:
		_tick(vw, dv)
		for id in cast:
			waved = waved or (id != n.id and _doll(vw, v.person(id)).react_hint == "lookup")
		for it: Array in dv.bub.props:
			loaf = loaf or String(it[0]) == "loaf"
		if i == 40:
			for id in cast:
				if id != n.id:
					looked = looked and _faces(_doll(vw, v.person(id)), dv.drawn(n.id) - dv.drawn(id), 0.5)
	check(cast.size() >= 3 and far and looked, "서먹한 마을: 멀찍이 서서 새 이웃 쪽을 바라봄 (%d명)" % (cast.size() - 1))
	check(not waved and not loaf, "손을 흔들지도 빵을 건네지도 않음")
	check(_sim(v) == before, "시뮬은 그대로")
	_steps(vw, dv, 8.0)
	v.migrants = {}
	_done(s)


# ───────────────────────── ⑪ 가르치기 ─────────────────────────
func test_teach() -> void:
	var s := _care(10.0, DailyView.TEACH)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var k := _kid(v)
	check(k != null, "(준비) 아이가 있음")
	if k == null:
		_done(s)
		return
	var par := v.person(k.parents[0])
	var other: Resident = null
	for r: Resident in _loose(v, 6):
		if r != par and not (r.id in k.parents) and other == null:
			other = r
	_park(v, [k, par, other])
	_steps(vw, dv, 0.1)
	var c := _clearing(dv, v, 3.0)
	_put(other, c.x + dv._right.x * 1.2, c.y + dv._right.y * 1.2, "work", "work")       # 더 가까운 남
	_put(par, c.x - dv._right.x * 2.4 + dv._front.x * 0.4, c.y - dv._right.y * 2.4 + dv._front.y * 0.4, "work", "work")
	_put(k, c.x, c.y + 0.1, "idle", "play")
	ChildPlay.games(v).clear()
	vw.sync(0.0, true)
	_aim(s[0], c, 44.0)
	var before := _sim(v)
	_steps(vw, dv, 0.8)
	check(dv.kind_of(k.id) == DailyView.TEACH and dv.role_of(par.id) == 1 and not dv.holding(other.id), "한가한 아이는 부모의 일터 먼저 (더 가까운 남의 일터보다)")
	check(_until(vw, dv, DailyView.TEACH, DailyView.TEACH_APPROACH_MAX + 0.5), "아이가 어른 곁으로 걸어옴")
	var gap := absf((dv.drawn(k.id) - dv.drawn(par.id)).dot(dv._right))
	check(absf(gap - DailyView.TEACH_SIDE) < 0.05, "어른 바로 옆 (겹치지 않게 %.2f칸)" % gap)
	var said := false
	var hints := {}
	var stays := true
	var same_way := false
	for i in int(DailyView.TEACH_DUR / DT) - 2:
		_tick(vw, dv)
		said = said or _said(vw, dv, par) == DailyView.TEACH_SAY
		hints[_hint(vw, k)] = true
		stays = stays and dv.drawn(par.id).distance_to(Vector2(par.x, par.y)) < 0.001 and par.anim == "work"
		if _hint(vw, k) == "gather" or _hint(vw, k) == "hoe":
			same_way = same_way or _faces(_doll(vw, k), dv.mimic_dir(_doll(vw, par), dv.drawn(k.id), dv.drawn(par.id)), 0.8)
	check(said, "어른이 \"%s\" (화면 말풍선)" % DailyView.TEACH_SAY)
	check(hints.has("stand") and (hints.has("gather") or hints.has("hoe")) and same_way, "아이가 지켜보다 어른과 같은 쪽을 보고 빈손으로 따라 해 봄 (%s)" % str(hints.keys()))
	check(stays, "어른은 그 자리에서 일하던 그대로")
	check(_sim(v) == before, "솜씨·일·창고·연대기는 그대로 (그림뿐)")
	_steps(vw, dv, 8.0)
	check(int(dv.started[DailyView.TEACH]) == 1 and not dv.holding(k.id), "아이마다 하루 한 번 · 끝나면 놓임")
	_done(s)


# ───────────────────────── 문: 추위·위기·밤·잔치·빠른 흐름·오프닝 ─────────────────────────
func test_care_gate() -> void:
	var s := _care(10.0, DailyView.TEACH)
	var v: Village = s[1]
	var vw: VillageView = s[2]
	var dv: DailyView = s[3]
	var k := _kid(v)
	var par := v.person(k.parents[0]) if k != null else null
	if k == null or par == null:
		check(false, "(준비) 아이와 부모")
		_done(s)
		return
	_park(v, [k, par])
	_steps(vw, dv, 0.1)
	var c := _clearing(dv, v, 3.0)
	var place := func() -> void:
		_put(par, c.x + dv._right.x * 1.5, c.y + dv._right.y * 1.5, "work", "work")
		_put(k, c.x, c.y, "idle", "play")
		vw.sync(0.0, true)
	place.call()
	v.deficit = 1.0
	_steps(vw, dv, 0.8)
	check(dv.calm() == "crisis" and int(dv.started[DailyView.TEACH]) == 0, "위기(식량 모자람)에는 없음")
	check(not dv.start_teach(k, par) and not dv.start_soup(par, k), "위기 중엔 억지로도 시작하지 않음")
	v.deficit = 0.0
	vw.fast = true
	_steps(vw, dv, 0.8)
	check(int(dv.started[DailyView.TEACH]) == 0, "빠른 흐름에는 없음")
	vw.fast = false
	_clock(v, 22.5)
	place.call()
	_steps(vw, dv, 0.8)
	check(int(dv.started[DailyView.TEACH]) == 0 and int(dv.started[DailyView.SOUP]) == 0, "밤에는 없음")
	_clock(v, 10.0)
	place.call()
	_steps(vw, dv, 0.8)
	check(int(dv.started[DailyView.TEACH]) == 1, "(대조) 잔잔한 낮에는 벌어짐")
	dv.clear()
	vw.stage_say.clear()
	var src := FileAccess.get_file_as_string(SRC)
	check(src.contains("func calm()") and src.contains("Milestones.feast_on(v) or VillageEra.wedding_on(v)") and src.contains("Health.cold_of(") and src.contains("not v.in_opening()"),
		"추운 날·잔치·혼례·오프닝 문은 2차 장면과 같은 calm()·on()을 거침")
	_done(s)


# ───────────────────────── 시뮬은 같음 (씨앗 4개) ─────────────────────────
## 돌봄 장면을 될 때마다 억지로 시작 (시간 창·하루 상한을 건너뜀 — 사람 조건·잔잔한 날은 그대로)
func _force_care(v: Village, dv: DailyView) -> void:
	if not dv.on() or dv.calm() != "":
		return
	if dv.active(DailyView.SOUP) == 0:
		for sick in v.people:
			if sick.is_sick() and not sick.dead:
				for c in v.people:
					if dv.active(DailyView.SOUP) == 0 and not dv._fed.has(sick.id):
						dv.start_soup(c, sick)
	if dv.active(DailyView.TEACH) == 0:
		for k in v.people:
			if k.age >= Balance.AGE_ADULT or k.is_baby() or dv.active(DailyView.TEACH) > 0:
				continue
			for a in v.people:
				if a.anim == "work" and Vector2(a.x - k.x, a.y - k.y).length() <= DailyView.TEACH_NEAR and dv.start_teach(k, a):
					break


## 같은 씨앗의 두 마을 — 하나는 화면 없이, 하나는 화면 + 돌봄 장면. 날마다 두 마을에 '똑같이' 넣는 것: 앓는 사람 하나 (둘째 날부터), 새 이웃 (셋째 날 아침)
func _care_same(seed_v: int, days: int, real: float) -> Dictionary:
	var scene := _scene()
	var va := _village(seed_v, 7.5)
	var vb := _village(seed_v, 7.5)
	var wb := _view(scene, vb)
	_aim(scene, vb.fire, 20.0)
	var db := DailyView.of(wb)
	var jar := real * 288.0
	var same := _digest(va) == _digest(vb)
	var bad := ""
	for day in days:
		if day > 0:
			var skip := fposmod(7.5 - va.hour_now(), 24.0) * Balance.HOUR
			for q: Village in [va, vb]:
				q.advance(skip)
		if day >= 1 and day % 2 == 1:                  # 앓는 사람 (두 마을에 똑같이 — 시뮬의 병 그대로 흘러감)
			for q: Village in [va, vb]:
				for r in q.people:
					if r.age >= Balance.AGE_ADULT and not r.dead and not r.is_sick() and (r.id + day) % 5 == 0:
						Health.fall_ill(q, r)
						break
		if day == 2 or (days > 6 and day == 9):        # 새 이웃 (반김 — 깨달은 마을의 믿음이 높으면 · 아니면 서먹)
			for q: Village in [va, vb]:
				var spot: Variant = q.find_spot("목조주택")
				var p: Vector2 = (spot as Vector2) + Vector2(1.5, 1.5) if spot != null else q.fire + Vector2(3.0, 3.0)
				Immigrants.land(q, p, seed_v * 7 + day)
		var lesson := false
		for i in int(9.5 * Balance.HOUR / jar):         # 07:30 → 17:00 (돌봄 장면의 낮)
			va.advance(jar)
			vb.advance(jar)
			if not lesson and vb.hour_now() >= 10.0:     # 아이 하나를 일하는 부모 곁에 한가히 (두 마을에 똑같이 — 새 마을은 아이가 일터 곁에 있을 일이 드묾)
				lesson = true
				var spot := _clearing(db, vb, 2.5)
				for q: Village in [va, vb]:
					var k: Resident = null
					for r in q.people:
						if k == null and r.age < Balance.AGE_ADULT and not r.is_baby() and not r.dead and not r.is_sick() and not r.parents.is_empty():
							k = r
					var par := q.person(k.parents[0]) if k != null else null
					if spot != Vector2.INF and par != null and not par.dead and not par.is_sick() and par.carry == "" and not par.sleeping:
						_put(par, spot.x, spot.y, "work", "work")
						_put(k, spot.x - 2.0, spot.y + 0.4, "idle", "idle")
						par.steps = [ResidentAI.act(Balance.HOUR, "work")]
						k.steps = [ResidentAI.act(Balance.HOUR, "idle")]
			va.crises.clear()
			vb.crises.clear()
			wb.sync(real)
			db.step(real)
			_force_care(vb, db)
			var law := _law(vb, wb, db)
			if law != "" and bad == "":
				bad = "%d일 %05.2f시 %s" % [day, vb.hour_now(), law]
			if i % 40 == 0:
				same = same and _digest(va) == _digest(vb) and _work(va) == _work(vb)
		same = same and _digest(va) == _digest(vb) and _work(va) == _work(vb)
	var out := {"same": same, "bad": bad, "soup": int(db.started[DailyView.SOUP]), "welcome": int(db.started[DailyView.WELCOME]), "teach": int(db.started[DailyView.TEACH]),
		"digest": SaveCodec.digest(va.to_dict()), "digest_b": SaveCodec.digest(vb.to_dict())}
	db.clear()
	wb.queue_free()
	_drop(scene)
	return out


func _care_same_seeds(days: int, real: float) -> void:
	var all_same := true
	var bad := ""
	var tot := {"soup": 0, "welcome": 0, "teach": 0}
	for sd: int in SEEDS:
		var o := _care_same(sd, days, real)
		print("     씨앗 %d · %d일: 화면 없음 %s / 화면+돌봄 %s · 수프 %d · 맞이 %d · 가르치기 %d" % [sd, days, String(o["digest"]).left(16), String(o["digest_b"]).left(16), o["soup"], o["welcome"], o["teach"]])
		all_same = all_same and bool(o["same"]) and o["digest"] == o["digest_b"]
		if bad == "" and String(o["bad"]) != "":
			bad = "씨앗 %d %s" % [sd, o["bad"]]
		for kk: String in tot:
			tot[kk] = int(tot[kk]) + int(o[kk])
	check(int(tot["soup"]) > 0 and int(tot["welcome"]) > 0 and int(tot["teach"]) > 0, "세 장면 모두 실제로 벌어짐 (수프 %d · 맞이 %d · 가르치기 %d)" % [tot["soup"], tot["welcome"], tot["teach"]])
	check(all_same, "씨앗 %d개 × %d일: 저장 지문·난수·사건 번호·창고·주민의 일·자리·배고픔이 화면 없는 마을과 똑같음 (차이 0)" % [SEEDS.size(), days])
	check(bad == "", "돌봄 장면에 든 사람도 규칙을 지킴 (빈손·깨어 있음·다른 연출 밖·잔잔한 날) %s" % bad)


func test_care_sim_same() -> void:
	_care_same_seeds(3, 0.5)


func test_care_sim_same_long() -> void:
	_care_same_seeds(20, 0.5)
