## 첫날 먹을 것 (ROADMAP Q7, 2026-11-11 — docs/measure/opening_food_2026-11-11.md) — tests/run.gd가 부름 (`-- opening_food` = 이것만).
## 재 보니 첫 사흘의 빈 창고는 시작 식량·밭 순서·채집 문으로는 풀리지 않았다 (일손이 모자람 — 문서 3장). 그래서 값은 그대로 두고, 지금 지켜지는 것만 묶어 둔다:
## 시작 건량은 하루치 남짓 (첫날이 빠듯함) · 진짜 시작(넓은 세상 + 기본 키트, 거인이 지켜보기만)에서 첫 닷새에 굶어 떠나는 사람이 없고 첫 빵을 마을이 스스로 굽는다.
## Q7-b (docs/measure/opening_food_b_2026-11-11.md): 배고픈 사람이 빈 창고 앞에서 기다리지 않는다 · 창고로 오는 길의 먹을 것도 먹는다 · 첫 며칠의 맨손 채집 · 다음 건물이 기다리는 짐 먼저.
## Q7-c (docs/measure/growth_2026-11-11.md): 앓는 밭지기·맷돌지기·화덕지기의 자리를 성한 어른이 맡는다 · 첫 며칠 먹을 것이 바닥나 가면 살피러 새로 떠나지 않는다.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = ["test_opening_days"]      # 진짜 시작을 병 닷새 — 오래 걸려 long·전체 모드에서만
const H := Balance.HOUR
const D := Balance.DAY


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 첫날 먹을 것 (Q7)")
	run.timed(self, ["test_start_stock", "test_hungry_keeps_working", "test_food_on_way", "test_first_days_forage", "test_waiting_load_first", "test_sick_stand_in", "test_first_days_explore_hold", "test_opening_days"])


## 시작 건량 (Balance.START_STOCK): 하루치를 조금 넘고 촌장이 '먹을 것이 모자라다'고 보는 선(BIRTH_FOOD_DAYS)에는 못 미친다 — 첫날이 빠듯해야 둘째 밭을 서두른다
func test_start_stock() -> void:
	var v := Village.new_prototype(3)
	var need := Production.day_need(v)
	var dry := float(Balance.START_STOCK["건량"])
	print("  시작 건량 %.0f · 하루 먹는 양 %.0f (%.2f일치) · 촌장의 '모자람' 선 %.0f" % [dry, need, dry / need, Balance.BIRTH_FOOD_DAYS * need])
	check(dry >= need and dry < Balance.BIRTH_FOOD_DAYS * need, "시작 건량은 하루치 이상, 촌장의 '모자람' 선 아래 (%.2f일치)" % (dry / need))
	check(float(Balance.START_STOCK["빵"]) == 0.0 and float(Balance.START_STOCK["밀"]) == 0.0 and float(Balance.START_STOCK["밀가루"]) == 0.0, "시작 창고에 빵·밀·밀가루는 없다 (첫 수확·첫 빵은 마을이 스스로 맞는 일)")


# ───────────────────────── Q7-b (2026-11-11 — docs/measure/opening_food_b_2026-11-11.md) ─────────────────────────
const BANNED: Array = ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분"]


## 도착하고 day일째 낮 10시의 작은 시험 마을 — 촌장 대본 없음, 먹을 것 0 (창고·건물 앞·하늘 낟알), 남은 연장 넉넉, 둘레엔 바구니 열 개치
func _bare(day: float) -> Village:
	var v := Village.new_prototype(424242)
	v.water.offline = true
	v.chief_off = true
	v.t = day * D + 10.0 * H - fmod(v.start_clock, D)
	for k: String in Balance.FOODS_ALL:
		v.stock[k] = 0.0
	v.stock[Balance.PORRIDGE] = 0.0
	v.stock["밀가루"] = 0.0
	v.manna.clear()
	v.manna_batches.clear()
	for b in v.buildings:
		b.out.clear()
	v.stock["도구"] = 30.0
	v.wild_food = 10.0 * Balance.FORAGE_LOAD
	return v


## 밭 하나 · 맷돌간 · 화덕이 선 마을
func _chain(v: Village) -> Village:
	v.add_building("농장", 6.0, 2.0, true)
	v.add_building("맷돌간", 8.0, 4.0, true)
	v.add_building("화덕", 9.0, 6.0, true)
	return v


func _loose(v: Village) -> Array:
	return v.people.filter(func(q: Resident) -> bool: return q.is_adult() and q.job < 0 and Production.caring_for(v, q) == null and q.sick_left <= 0.0 and q.injured_left <= 0.0)


func _clean(text: String) -> bool:
	for w: String in BANNED:
		if text.contains(w):
			return false
	for i in text.length():
		if text.unicode_at(i) >= 0x30 and text.unicode_at(i) <= 0x39:
			return false
	return true


## ① 배고픈 사람은 빈 창고 앞에서 기다리지 않는다: 먹을 것이 없으면 '먹기'가 일보다 뒤 — 밭일꾼은 밭일을 잇는다. 먹을 것이 생기면 만사 제치고 먹으러 간다
func test_hungry_keeps_working() -> void:
	var v := _bare(2.0)
	check(is_equal_approx(v.hour_now(), 10.0) and v.is_work_time() and not v.in_opening(), "낮 10시 · 일하는 시간 (%.1f시)" % v.hour_now())
	var farm := v.add_building("농장", 6.0, 2.0, true)
	var ls := _loose(v)
	var farmer: Resident = ls[0]
	farmer.job = farm.id
	farmer.hunger = 1.5
	farmer.steps.clear()
	check(not Production.food_at_hand(v) and Production.food_total(v) == 0.0, "먹을 것이 하나도 없다")
	ResidentAI.decide(v, farmer)
	check(farmer.action == "work", "배고픈 밭일꾼: 창고가 비었으면 밭일을 잇는다 (%s)" % farmer.action)
	check(farmer.say == "배고파요…", "… 배고프다고 말은 한다 (%s)" % farmer.say)
	check(Balance.EAT_EMPTY_SCORE + 0.2 < Balance.ACT_BASE["haul"] * Balance.W_DAY_WORK and Balance.EAT_EMPTY_SCORE + 0.2 < Balance.ACT_BASE["sleep"] * Balance.W_NIGHT_SLEEP,
		"빈 창고 들여다보기는 낮의 일·나르기·짓기와 밤잠보다 뒤")
	# 먹을 것이 반 시간치 넘게 있으면 예전처럼 먹으러 간다
	v.stock[Balance.FOODS[0]] = Production.day_need(v) * 0.2
	var farmer2: Resident = ls[1]
	farmer2.job = farm.id
	farmer2.hunger = 1.5
	farmer2.steps.clear()
	check(Production.food_at_hand(v), "창고에 먹을 것이 있다")
	ResidentAI.decide(v, farmer2)
	check(farmer2.action == "eat" and farmer2.doing == "먹을 것을 찾는 중", "배고픈 밭일꾼: 먹을 것이 있으면 먹으러 간다 (%s)" % farmer2.action)
	# 밤: 먹을 것이 없으면 창고 앞에 서 있지 않고 잔다
	var w := _bare(2.0)
	w.t = 2.0 * D + 23.5 * H - fmod(w.start_clock, D)
	var late: Resident = _loose(w)[0]
	late.hunger = 2.5
	late.steps.clear()
	ResidentAI.decide(w, late)
	check(w.is_night() and late.action == "sleep", "밤에 배고픈 사람: 먹을 것이 없으면 잔다 (%s)" % late.action)


## ② 창고로 오는 길의 먹을 것도 마을의 먹을 것: 밭에서 실은 수레·손에 든 바구니를 맨 끝에 먹고, 먹은 만큼 내려놓을 짐이 준다 (맷돌간으로 가는 짐은 치지 않는다)
func test_food_on_way() -> void:
	var v := _bare(2.0)
	var farm := v.add_building("농장", 6.0, 2.0, true)
	farm.out[Balance.PORRIDGE] = 100.0
	var ls := _loose(v)
	var r: Resident = ls[0]
	r.steps.clear()
	check(Production.food_on_way(v) == 0.0, "길 위에 아무것도 없다")
	check(ResidentAI._haul_out(v, r, v.store(), r.carry_cap()), "밭 앞의 밀을 창고로 싣는다")
	var w0 := Production.food_on_way(v)
	check(float(farm.out.get(Balance.PORRIDGE, 0.0)) == 0.0 and is_equal_approx(w0, 100.0 * Balance.PORRIDGE_YIELD), "밭 앞에서는 빠졌고 길 위의 먹을 것으로 센다 (%.1f)" % w0)
	check(Production.food_total(v) == 0.0 and Production.food_at_hand(v), "창고는 비었지만 먹을 것은 오는 중 — 배고픈 사람이 먹으러 갈 만하다")
	var left := Production.consume_unmet(v, 30.0)
	check(left == 0.0 and is_equal_approx(Production.food_on_way(v), w0 - 30.0), "오는 길의 밀을 죽으로 먹었다 (남은 %.1f)" % Production.food_on_way(v))
	var want := 100.0 - 30.0 / Balance.PORRIDGE_YIELD
	var pick_amt := -1.0
	var drop_amt := -1.0
	for s: Dictionary in r.steps:
		if s.get("done") is Dictionary and String(s["done"].get("op", "")) == "pick":
			pick_amt = float(s["done"]["amt"])
		if s.get("done") is Dictionary and String(s["done"].get("op", "")) == "put":
			drop_amt = float(s["done"]["drop"]["amt"])
	check(is_equal_approx(pick_amt, want) and is_equal_approx(drop_amt, want), "먹은 만큼 실을 짐·내려놓을 짐이 준다 (%.1f · %.1f)" % [pick_amt, drop_amt])
	left = Production.consume_unmet(v, 1000.0)
	check(is_equal_approx(left, 1000.0 - want * Balance.PORRIDGE_YIELD) and Production.food_on_way(v) == 0.0, "다 먹으면 모자란 만큼만 굶는다 (%.1f)" % left)
	# 손에 든 채집 바구니
	var f: Resident = ls[1]
	f.steps.clear()
	check(ResidentAI._forage(v, f), "바구니를 들고 나간다")
	check(Production.food_on_way(v) == 0.0, "아직 거두기 전의 바구니는 치지 않는다")
	f.steps = f.steps.slice(2)
	f.carry = Balance.FORAGE_ITEM
	f.carry_amt = Balance.FORAGE_LOAD
	check(is_equal_approx(Production.food_on_way(v), Balance.FORAGE_LOAD), "거둔 바구니는 길 위의 먹을 것")
	left = Production.consume_unmet(v, 10.0)
	check(left == 0.0 and is_equal_approx(f.carry_amt, Balance.FORAGE_LOAD - 10.0), "바구니에서 먹은 만큼 준다 (%.1f)" % f.carry_amt)
	# 맷돌간으로 가는 밀은 가루가 될 몫 — 길 위의 먹을 것으로 치지 않는다. 굶기 직전에만 맨 마지막 죽으로 (입구에 부려 둔 것 먼저, 그다음 가는 수레)
	var x := _bare(2.0)
	var farm2 := x.add_building("농장", 6.0, 2.0, true)
	var mill := x.add_building("맷돌간", 8.0, 4.0, true)
	farm2.out[Balance.PORRIDGE] = 100.0
	var h: Resident = _loose(x)[0]
	h.steps.clear()
	check(ResidentAI._haul_out(x, h, x.store(), h.carry_cap()) and Production.food_on_way(x) == 0.0 and not Production.food_at_hand(x), "맷돌간으로 가는 밀은 치지 않는다")
	check(is_equal_approx(float(mill.in_inc.get(Balance.PORRIDGE, 0.0)), 100.0), "맷돌간으로 한 수레가 가는 중")
	mill.in_buf[Balance.PORRIDGE] = 40.0
	left = Production.consume_unmet(x, 15.0)
	check(left == 0.0 and is_equal_approx(float(mill.in_buf[Balance.PORRIDGE]), 40.0 - 15.0 / Balance.PORRIDGE_YIELD) and is_equal_approx(float(mill.in_inc[Balance.PORRIDGE]), 100.0),
		"굶기 직전: 맷돌간 입구의 밀부터 죽으로 (남은 %.1f)" % float(mill.in_buf[Balance.PORRIDGE]))
	left = Production.consume_unmet(x, 15.0 + 30.0)
	var to_mill := -1.0
	for s: Dictionary in h.steps:
		if s.get("done") is Dictionary and String(s["done"].get("op", "")) == "put":
			to_mill = float(s["done"]["drop"]["amt"])
	check(left == 0.0 and float(mill.in_buf[Balance.PORRIDGE]) == 0.0 and is_equal_approx(to_mill, 60.0) and is_equal_approx(float(mill.in_inc[Balance.PORRIDGE]), 60.0),
		"… 그다음 맷돌간으로 가는 수레 (내려놓을 짐 %.1f · 오는 중 %.1f)" % [to_mill, float(mill.in_inc[Balance.PORRIDGE])])
	var oven := x.add_building("화덕", 9.0, 6.0, true)
	oven.in_buf["밀가루"] = 50.0
	left = Production.consume_unmet(x, 1000.0)
	check(is_equal_approx(left, 1000.0 - 60.0 * Balance.PORRIDGE_YIELD) and is_equal_approx(float(oven.in_buf["밀가루"]), 50.0), "화덕의 가루는 건드리지 않는다 (빵이 될 몫)")


## ③ 첫 며칠의 맨손 채집: 도착하고 FORAGE_FIRST_DAYS 날 안, 먹을 것이 반나절치 아래면 연장이 남아도 한 사람이 나르기·짓기보다 먼저 바구니를 든다 (나머지는 나른다)
func test_first_days_forage() -> void:
	var v := _bare(2.0)
	var farm := v.add_building("농장", 6.0, 2.0, true)
	v.add_building("맷돌간", 8.0, 4.0, true)
	check(not Production.forage_first(v) and not v.forage_open(), "맷돌간·화덕이 다 서기 전에는 일손을 빼지 않는다")
	v.add_building("화덕", 9.0, 6.0, true)
	v._fg_t = -1.0
	check(Production.forage_first(v) and v.forage_open(), "둘째 날, 맷돌간·화덕은 섰고 먹을 것이 없다: 연장이 남아도 채집 문이 열린다")
	farm.out[Balance.PORRIDGE] = 60.0                     # 나를 것이 있다 (반나절치에는 한참 못 미침)
	check(ResidentAI.haul_requests(v) > 0 and Production.forage_first(v), "나를 것이 기다린다")
	var ls := _loose(v)
	var went := 0
	var hauled := 0
	for i in Balance.FORAGE_FIRST_HANDS + 1:
		var r: Resident = ls[i]
		r.steps.clear()
		ResidentAI.decide(v, r)
		if r.action == "forage":
			went += 1
		elif r.action == "haul":
			hauled += 1
	check(went == Balance.FORAGE_FIRST_HANDS and hauled == 1, "앞세워 나가는 사람은 %d명까지, 다음 사람은 나른다 (채집 %d · 나르기 %d)" % [Balance.FORAGE_FIRST_HANDS, went, hauled])
	var line := ""
	for e: Dictionary in v.events.since(0):
		if String(e["kind"]) == "chronicle" and String(e["v"]).contains("바구니"):
			line = String(e["v"])
	check(line == "밭이 아직 마을을 다 먹이지 못했다. 몇 사람이 빈 바구니를 들고 숲 가로 나갔다.", "연대기 한 줄 (%s)" % line)
	var said: String = (ls[0] as Resident).say
	check(_clean(line) and said != "" and _clean(said), "연대기·말에 쓰지 않는 말·숫자가 없다 (%s)" % said)
	# 먹을 것이 반나절치를 넘으면 (창고로 오는 길의 것도 센다) 문이 닫힌다
	var a := _chain(_bare(2.0))
	a.stock[Balance.FOODS[0]] = Production.day_need(a) * (Balance.FORAGE_FIRST_FOOD_DAYS + 0.1)
	check(not Production.forage_first(a) and not a.forage_open(), "먹을 것이 반나절치를 넘으면 나가지 않는다 (연장이 남으니)")
	# 첫 며칠이 지나면 예전 규칙 그대로 (연장이 모자랄 때만)
	var b := _chain(_bare(Balance.FORAGE_FIRST_DAYS + 1.0))
	check(not Production.forage_first(b) and not b.forage_open(), "첫 며칠이 지나면 연장이 남는 마을은 나가지 않는다")
	b.stock["도구"] = 0.0
	b._fg_t = -1.0
	check(b.forage_open(), "… 연장이 모자라면 예전처럼 나간다")
	# 밤에는 나가지 않는다
	var n := _chain(_bare(2.0))
	n.t = 2.0 * D + 23.5 * H - fmod(n.start_clock, D)
	var late: Resident = _loose(n)[0]
	late.steps.clear()
	ResidentAI.decide(n, late)
	check(late.action != "forage", "밤에는 나가지 않는다 (%s)" % late.action)


## ④ 다음 건물이 기다리는 짐이 먼저: 밭 앞에 밀이 쌓여 있어도 (맷돌간 입구는 가득) 맷돌간 앞 밀가루를 화덕으로 먼저 나른다 — 밭의 밀을 창고로 나르느라 화덕이 비어 첫 빵이 하루 밀리던 일
func test_waiting_load_first() -> void:
	var v := _bare(2.0)
	var farm := v.add_building("농장", 6.0, 2.0, true)
	var mill := v.add_building("맷돌간", 8.0, 4.0, true)
	var oven := v.add_building("화덕", 9.0, 6.0, true)
	farm.out[Balance.PORRIDGE] = 300.0
	mill.in_buf[Balance.PORRIDGE] = Production.in_cap(Balance.PORRIDGE)        # 맷돌간 입구는 가득 — 밭의 밀은 창고로 갈 짐
	mill.out["밀가루"] = 80.0
	check(Production.dest_for(v, farm, Balance.PORRIDGE) == null and Production.dest_for(v, mill, "밀가루") == oven, "밭의 밀은 창고로, 맷돌간의 가루는 화덕으로 갈 짐")
	var ls := _loose(v)
	var r: Resident = ls[0]
	r.steps.clear()
	check(ResidentAI._haul_out(v, r, v.store(), r.carry_cap()), "나를 것이 있다")
	check(float(oven.in_inc.get("밀가루", 0.0)) > 0.0 and is_equal_approx(float(farm.out[Balance.PORRIDGE]), 300.0), "화덕이 기다리는 가루부터 (화덕으로 오는 중 %.0f · 밭 앞 밀 %.0f)" % [float(oven.in_inc.get("밀가루", 0.0)), float(farm.out[Balance.PORRIDGE])])
	var r2: Resident = ls[1]
	r2.steps.clear()
	mill.out["밀가루"] = 0.0
	check(ResidentAI._haul_out(v, r2, v.store(), r2.carry_cap()) and float(farm.out[Balance.PORRIDGE]) < 300.0, "기다리는 건물이 없으면 예전처럼 밭의 밀을 창고로 (밭 앞 %.0f)" % float(farm.out[Balance.PORRIDGE]))


# ───────────────────────── Q7-c (2026-11-11 — docs/measure/growth_2026-11-11.md) ─────────────────────────
func _of_type(v: Village, type: String) -> Building:
	for b in v.buildings:
		if b.built and b.type == type:
			return b
	return null


## ⑤ 밭지기(맷돌지기·화덕지기)가 앓아누우면 일터 없는 성한 어른이 그 자리를 맡는다 — 앓는 사람은 일을 내려놓고, 나아도 자리를 도로 빼앗지 않는다.
## 맡을 성한 사람이 없으면 예전처럼 그대로 (일터가 쉰다) · 먹을 것 일터가 아니면 넘기지 않는다 · 새로 생긴 말·연대기 줄 없음
func test_sick_stand_in() -> void:
	check(Balance.JOB_STAND_IN, "대신 서기가 켜져 있다 (Balance.JOB_STAND_IN)")
	var v := _chain(_bare(2.0))
	v.assign_jobs()
	var farm := _of_type(v, "농장")
	var farmer := v.person(farm.worker)
	check(farmer != null and farmer.job == farm.id and _loose(v).size() >= 1, "밭에 일꾼이 섰고 일터 없는 어른이 남았다 (%d명)" % _loose(v).size())
	var tools0 := float(v.stock["도구"])
	var lines0 := v.events.since(0).size()
	farmer.sick_left = 2.0 * D
	v.assign_jobs()
	var sub := v.person(farm.worker)
	check(sub != null and sub.id != farmer.id and sub.sick_left <= 0.0 and sub.job == farm.id, "밭지기가 앓아누우면 성한 어른이 밭을 맡는다")
	check(farmer.job < 0 and int(v.stats.get("stand_in", 0)) == 1, "앓는 사람은 일을 내려놓는다")
	check(is_equal_approx(float(v.stock["도구"]), tools0), "연장 수는 그대로 (하나 돌아오고 하나 나간다 — %.0f)" % float(v.stock["도구"]))
	var chron := 0
	for i in range(lines0, v.events.since(0).size()):
		if String(v.events.since(0)[i]["kind"]) == "chronicle":
			chron += 1
	check(sub != null and sub.say != "" and _clean(sub.say) and chron == 0, "맡은 사람의 말에 쓰지 않는 말·숫자가 없고 연대기 줄은 늘지 않는다 (%s)" % (sub.say if sub != null else ""))
	v.assign_jobs()
	check(farm.worker == sub.id and farmer.job < 0, "앓는 동안 다시 배정해도 그대로 — 앓는 사람은 먹을 것 일터에 서지 않는다")
	farmer.sick_left = 0.0
	v.assign_jobs()
	check(farm.worker == sub.id, "나은 사람이 자리를 도로 빼앗지 않는다 (일터 없는 어른으로 돌아가 다음 빈 일터를 맡는다)")
	# 맡을 성한 사람이 없으면 그대로
	var w := _chain(_bare(2.0))
	w.assign_jobs()
	var farm2 := _of_type(w, "농장")
	var f2 := w.person(farm2.worker)
	for q: Resident in _loose(w):
		q.sick_left = D
	f2.sick_left = D
	w.assign_jobs()
	check(farm2.worker == f2.id and f2.job == farm2.id and int(w.stats.get("stand_in", 0)) == 0, "일터 없는 어른이 모두 앓으면 그대로 둔다 (밭이 쉰다)")
	# 먹을 것 일터가 아니면 넘기지 않는다
	var x := _chain(_bare(2.0))
	var cut := x.add_building("나무꾼", 3.0, 8.0, true)
	x.assign_jobs()
	var c := x.person(cut.worker)
	check(c != null and _loose(x).size() >= 1, "벌목장에도 일꾼이 섰다")
	if c != null:
		c.sick_left = D
		x.assign_jobs()
		check(cut.worker == c.id and int(x.stats.get("stand_in", 0)) == 0, "벌목장 일꾼이 앓아도 자리를 넘기지 않는다 (먹을 것 일터만)")


## ⑥ 첫 며칠(FORAGE_FIRST_DAYS) 먹을 것이 EXPLORE_HOLD_FOOD_DAYS 날치 아래면 안개 너머를 살피러 새로 떠나지 않는다 (그 어른은 나르고 짓는다).
## 먹을 것이 넉넉하거나 첫 며칠이 지나면 예전처럼 나선다
func test_first_days_explore_hold() -> void:
	check(Balance.EXPLORE_HOLD_FOOD_DAYS > 0.0, "살피기 미루기가 켜져 있다 (Balance.EXPLORE_HOLD_FOOD_DAYS)")
	var v := _bare(2.0)
	v.explore_on = true
	check(v.explore_held() and not v.can_explore(), "둘째 날, 먹을 것이 없다: 살피러 새로 떠나지 않는다")
	v.stock[Balance.FOODS[0]] = Production.day_need(v) * (Balance.EXPLORE_HOLD_FOOD_DAYS + 0.1)
	check(not v.explore_held() and v.can_explore(), "먹을 것이 넉넉하면 예전처럼 나선다")
	v.stock[Balance.FOODS[0]] = 0.0
	var f: Resident = _loose(v)[0]
	f.steps.clear()
	check(ResidentAI._forage(v, f) and v.explore_held(), "바구니를 들고 나간 사람이 있어도 거두기 전에는 그대로")
	f.steps = f.steps.slice(2)                            # 거둔 바구니를 들고 창고로 오는 길 (test_food_on_way와 같은 꾸밈)
	f.carry = Balance.FORAGE_ITEM
	f.carry_amt = Production.day_need(v) * (Balance.EXPLORE_HOLD_FOOD_DAYS + 0.1)
	check(Production.food_on_way(v) > 0.0 and not v.explore_held(), "창고로 오는 길의 먹을 것도 센다 (%.0f)" % Production.food_on_way(v))
	var late := _bare(Balance.FORAGE_FIRST_DAYS + 1.0)
	late.explore_on = true
	check(not late.explore_held() and late.can_explore(), "첫 며칠이 지나면 먹을 것이 없어도 예전처럼 나선다")


## 진짜 시작 (넓은 세상 + 기본 키트 · 하늘 낟알 없음 · 거인은 지켜보기만) 병 닷새: 굶어 떠나는 사람이 없고, 첫 빵은 마을이 스스로 굽는다.
## Q7-b: 창고가 비는 시간은 얕고 짧다 — 닷새에 OPENING_SHORT_MAX 시간 아래, 아무도 '배고프다'(HUNGRY_AT)까지 가지 않는다 ('빈 창고 → 아무도 일 안 함' 고리가 없다).
## 이 시험의 시작(run.gd의 고정 날짜 · 깨달은 채 시작)은 재는 도구와 달라 숫자도 다르다 — Q7-b 때 씨앗 19: 14시간 · 0.03, 씨앗 26: 0시간 · 0.00 → Q7-c(대신 서기 · 살피기 미루기) 뒤 씨앗 19: 5시간 · 0.03, 씨앗 26: 0시간 · 0.00
const OPENING_SHORT_MAX := 20
func test_opening_days() -> void:
	for seed_v: int in [19, 26]:               # 재는 도구에서 가장 나빴던 두 씨앗 (고치기 전 창고가 42 · 25시간 비고 배고픔이 끝까지 참)
		Market.reset()
		Market.first_paid = false
		Market.mig_seed = seed_v * 7919 + 13
		Market.today_override = "R1"
		var jw := JarWorld.create_with_kit(seed_v, WorldCfg.SIZE, Kits.make([]))
		var v := jw.primary()
		var short := 0
		var hunger := 0.0
		var bread := -1.0
		var cursor := 0
		while v.t < 23.0 * H:
			jw.advance(5.0 * 60.0)
		while v.t < 5.0 * D and not v.people.is_empty():
			jw.advance(H)
			for q: Village in jw.settlements:
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			if v.deficit > 0.0 or v.t - v.last_short_t < H:
				short += 1
			for p: Resident in v.people:
				hunger = maxf(hunger, p.hunger)
			for e: Dictionary in v.events.since(cursor):
				cursor = int(e["n"])
				if String(e["kind"]) == "first_bread" and bread < 0.0:
					bread = float(e["t"]) / H
		print("  씨앗 %d: 창고가 빈 시간 %d · 가장 높은 배고픔 %.2f · 첫 빵 %.1f시간 · 사람 %d · 굶어 떠남 %d" % [seed_v, short, hunger, bread, v.people.size(), v.stats["starved"]])
		check(int(v.stats["starved"]) == 0, "씨앗 %d: 첫 닷새에 굶어 떠나는 사람이 없다" % seed_v)
		check(bread > 0.0, "씨앗 %d: 첫 빵을 닷새 안에 마을이 스스로 굽는다 (%.1f시간)" % [seed_v, bread])
		check(short <= OPENING_SHORT_MAX and hunger < Balance.HUNGRY_AT, "씨앗 %d: 창고가 빈 시간 %d ≤ %d · 가장 높은 배고픔 %.2f < %.1f ('빈 창고 → 아무도 일 안 함' 고리가 없다)" % [seed_v, short, OPENING_SHORT_MAX, hunger, Balance.HUNGRY_AT])
		Market.today_override = ""
		Market.reset()
