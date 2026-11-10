## 아이·아기 (sim/child_play.gd · view/kids_view.gd — ROADMAP Q2-b 귀여움 묶음 ②, E2-2 · E2-3).
## 놀이 규칙(낮에만·밥때 아님·2~4명·술래가 바뀜·돌탑이 무너짐·자리 함수) · 옛 난수 순서 · 아기를 보는 사람 · 요람 들여다보기 ·
## 첫걸음마 · 저장 · 결정성(지켜봄 켬 ↔ 끔) · 금지어. tests/run.gd가 부름: 전체·quick·`-- kids`.
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
	run.timed(self, ["test_source_and_words", "test_play_rng_order", "test_when_and_who", "test_tag", "test_stack", "test_butterfly", "test_leave_and_end",
		"test_minder", "test_peek", "test_first_steps", "test_save", "test_village_day", "test_watch_determinism", "test_view"])


# ───────────────────────── 도우미 ─────────────────────────
## 작은 시험 마을, 낮 (hour시), 첫 한 시간 대본 없음
func _village(hour := 9.0, seed_v := 31) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true
	v.chief_off = true
	v.stats["thanks"] = 1
	_set_hour(v, hour)
	return v


func _set_hour(v: Village, hour: float) -> void:
	v.t += fposmod(hour - v.hour_now(), 24.0) * Balance.HOUR


func _kid(v: Village, nm: String, age: float, x: float, y: float) -> Resident:
	var mom: Resident = null
	var dad: Resident = null
	for r in v.people:
		if r.is_adult() and r.sex == "f" and mom == null:
			mom = r
		elif r.is_adult() and r.sex == "m" and dad == null:
			dad = r
	var c := v.add_person(nm, "f" if nm.length() % 2 == 0 else "m", age, "", x, y, mom, dad)
	c.parents = PackedInt32Array([mom.id, dad.id])
	c.steps.clear()
	return c


## 놀이를 열고 아이들을 자리에 앉힘 (걸음: 놀기 하나)
func _game(v: Village, kind: String, kids: Array, c: Vector2) -> Dictionary:
	var g := ChildPlay.open_game(v, kids[0], c, kind, 1)
	for k: Resident in kids:
		var i := ChildPlay._add(g, k.id)
		var s := ChildPlay.seat(g, int(g["sl"][i]))
		k.x = s.x
		k.y = s.y
		k.steps.clear()
		ChildPlay._attach(k, g, i, 1.0e7)
	return g


func _events(v: Village, from: int, kind: StringName) -> Array:
	return v.events.since(from).filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


func _open_centre(v: Village) -> Vector2:
	for k in 200:
		var c := Vector2(v.fire.x + 4.0 + float(k % 14), v.fire.y + 4.0 + float(k / 14))
		if ChildPlay._open(v, c):
			return c
	return Vector2(v.fire.x + 6.0, v.fire.y + 6.0)


# ───────────────────────── 시험 ─────────────────────────
func test_source_and_words() -> void:
	print("== 아이·아기: 시뮬은 지켜봄을 모름 · static var 없음 · 글에 금지어 없음")
	var src := FileAccess.get_file_as_string("res://sim/child_play.gd")
	check(not src.contains("static var") and not src.contains("watching"), "sim/child_play.gd: static var · 지켜봄 읽기 없음")
	check(not src.contains("randf") and not src.contains("randi"), "sim/child_play.gd: 난수 흐름을 쓰지 않음 (씨앗 해시)")
	var vsrc := FileAccess.get_file_as_string("res://view/kids_view.gd")
	check(not vsrc.contains("static var"), "view/kids_view.gd: static var 없음")
	var texts: Array = []
	for k: String in ChildPlay.LABEL:
		texts.append(String(ChildPlay.LABEL[k]))
	texts.append("문 앞 요람에 누워 있는 중")
	texts.append("엄마 품에 안겨 있는 중")
	texts.append("아빠 뒤를 아장아장 따라다니는 중")
	texts.append("문 앞에 앉아 노는 중")
	texts.append("아람이 첫걸음마를 뗐다. 몇 걸음 못 가 털썩 주저앉고는 까르르 웃었다.")
	for k: String in KidsView.SAY:
		for tx: String in KidsView.SAY[k]:
			texts.append(tx)
	var bad: String = run.words_ok(texts)
	check(bad == "", "아이·아기 글에 금지어 없음 %s" % bad)
	for tx: String in texts:
		for wd: String in ["거인", "기도", "제단", "하늘의 분"]:
			check(not tx.contains(wd), "거인 이야기 없음: %s" % tx)
	var doc := FileAccess.get_file_as_string("res://../docs/architecture/event-kinds.md")
	if doc != "":
		for k: String in ["kid_play_started", "kid_tagged", "kid_stack_fell", "baby_peeked", "first_steps"]:
			check(doc.contains("`&\"%s\"`" % k), "event-kinds.md에 %s" % k)


## 놀이에 붙든 말든 `play`가 마을 난수를 쓰는 순서·횟수는 옛 그대로 (자리 반지름 → 각도 → 시간)
func test_play_rng_order() -> void:
	print("== 아이·아기: play의 마을 난수 순서는 옛 그대로")
	for joined in [false, true]:
		var v := _village(9.0)
		var kid := _kid(v, "새별", 2.3, v.fire.x + 5.0, v.fire.y + 5.0)
		if joined:
			var other := _kid(v, "보리", 2.0, kid.x + 1.0, kid.y)
			_game(v, "tag", [other], Vector2(kid.x + 1.0, kid.y + 1.0))
		else:
			v.kids["next"] = 1.0e12            # 새 놀이를 못 엶 → 옛 놀기
			ChildPlay._state(v)
			v.kids["next"] = 1.0e12
		var ref := RandomNumberGenerator.new()
		ref.seed = v.rng.seed
		ref.state = v.rng.state
		for i in 3:
			ref.randf()
		check(ResidentAI._do(v, kid, "play", v.hour_now()), "play를 함 (%s)" % ("낌" if joined else "옛 놀기"))
		check(v.rng.state == ref.state, "마을 난수 세 번 (%s)" % ("낌" if joined else "옛 놀기"))
		check(ChildPlay.game_of(v, kid.id).is_empty() != joined, "놀이에 %s" % ("낌" if joined else "끼지 않음"))
		check(kid.doing == ("술래잡기하는 중" if joined else "노는 중"), "하는 일: %s" % kid.doing)
		var last: Dictionary = kid.steps[kid.steps.size() - 1]
		check(String(last["anim"]) == "play" and float(last["left"]) >= Balance.PLAY_TIME[0] and float(last["left"]) <= Balance.PLAY_TIME[0] + Balance.PLAY_TIME[1], "노는 시간은 옛 범위")


func test_when_and_who() -> void:
	print("== 아이·아기: 놀이는 낮 · 밥때 아님 · 첫 한 시간 아님 · 넷까지")
	var v := _village(9.0)
	var c := _open_centre(v)
	var kids: Array = []
	for i in 6:
		kids.append(_kid(v, ["보리", "새별", "한솔", "다래", "가람", "나래"][i], 1.5 + 0.3 * i, c.x + 0.3 * i, c.y + 0.2))
	check(ChildPlay._time_ok(v), "9시: 놀이를 열 수 있음")
	for h: float in [5.0, 6.4, 12.2, 11.6, 17.7, 20.2, 23.0]:
		_set_hour(v, h)
		check(not ChildPlay._time_ok(v) or not v.is_work_time(), "%.1f시: 새 놀이 없음" % h)
	_set_hour(v, 23.0)
	check(not ChildPlay.try_play(v, kids[0], c, 900.0) and ChildPlay.games(v).is_empty(), "밤: 놀이 없음")
	_set_hour(v, 12.3)
	check(not ChildPlay.try_play(v, kids[0], c, 900.0) and ChildPlay.games(v).is_empty(), "점심: 놀이 없음")
	_set_hour(v, 9.0)
	v.stats["thanks"] = 0
	v.chief_off = false
	if v.in_opening():
		check(not ChildPlay.try_play(v, kids[0], c, 900.0), "첫 한 시간: 놀이 없음")
	v.stats["thanks"] = 1
	v.chief_off = true
	var baby := _kid(v, "아람", 0.3, c.x, c.y)
	check(not ChildPlay.try_play(v, baby, c, 900.0), "아기는 놀이에 끼지 않음")
	var tries := 0
	while ChildPlay.games(v).is_empty() and tries < 40:      # 굴림(START_P)에 따라 몇 번 만에 열림
		ChildPlay.try_play(v, kids[0], c, 900.0)
		tries += 1
	check(ChildPlay.games(v).size() == 1, "낮: 놀이가 열림 (%d번째)" % tries)
	var g: Dictionary = ChildPlay.games(v)[0]
	check(String(g["kind"]) in ["tag", "bfly", "stack"], "놀이 종류 %s" % g["kind"])
	check(kids[0].steps.size() >= 1 and int((kids[0].steps[kids[0].steps.size() - 1] as Dictionary).get("g", -1)) == int(g["id"]), "연 아이의 걸음에 놀이 표시")
	for i in range(1, 6):
		ChildPlay.try_play(v, kids[i], c, 900.0)
	check((g["who"] as Array).size() == 4, "넷까지 (지금 %d)" % (g["who"] as Array).size())
	check(ChildPlay.games(v).size() == 1, "아이 여섯: 놀이는 하나")
	check(ChildPlay.game_of(v, kids[5].id).is_empty() and kids[5].steps.is_empty(), "다섯째는 옛 놀기로 (걸음을 채우지 않음)")
	var slots := {}
	for s: Variant in g["sl"]:
		slots[int(s)] = true
	check(slots.size() == 4, "자리 넷이 서로 다름")
	var far := _kid(v, "마루", 2.0, c.x + 30.0, c.y + 30.0)
	check(not ChildPlay.try_play(v, far, Vector2(far.x, far.y), 900.0), "먼 아이는 끼지 않음 (놀이 하나뿐)")
	var ev := _events(v, 0, &"kid_play_started")
	check(ev.size() == 1 and int(ev[0]["who"]) == kids[0].id and (ev[0]["v"] as Dictionary)["kind"] == g["kind"], "kid_play_started 한 번")
	check(not ChildPlay._open(v, v.fire) and not ChildPlay._open(v, Vector2(v.buildings[0].x, v.buildings[0].y)) if not v.buildings.is_empty() else true, "모닥불·건물 자리는 놀 자리가 아님")


func test_tag() -> void:
	print("== 아이·아기: 술래잡기 — 쫓고, 잡히면 술래가 바뀜")
	var v := _village(9.0)
	var c := _open_centre(v)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 2.0 + 0.4 * i, c.x, c.y))
	var g := _game(v, "tag", kids, c)
	g["c1"] = 1.0e9
	var from := v.events.serial
	var its := {}
	var jump := 0.0
	var far := 0.0
	var prev: Array = []
	var bad_it := 0
	var seen := from
	for k in 400:
		ChildPlay.step(v, 30.0)
		for e: Dictionary in v.events.since(seen):
			seen = int(e["n"])
			if e["kind"] == &"kid_tagged":
				if int(g["it"]) != int(e["who"]) or int((e["v"] as Dictionary)["by"]) == int(e["who"]):
					bad_it += 1
				var by_i := ChildPlay.idx(g, int((e["v"] as Dictionary)["by"]))
				var who_i := ChildPlay.idx(g, int(e["who"]))
				var d := ChildPlay.spot(g, by_i, float(g["c"])).distance_to(ChildPlay.spot(g, who_i, float(g["c"])))
				if d >= 1.0:
					check(d < 1.0, "잡는 순간 둘이 붙어 있음 (%.2f칸)" % d)
		if int(g["it"]) >= 0:
			its[int(g["it"])] = true
		for i in 3:
			var p := ChildPlay.spot(g, i, float(g["c"]))
			far = maxf(far, p.distance_to(c))
			if prev.size() == 3:
				jump = maxf(jump, p.distance_to(prev[i]))
		prev = [ChildPlay.spot(g, 0, float(g["c"])), ChildPlay.spot(g, 1, float(g["c"])), ChildPlay.spot(g, 2, float(g["c"]))]
	var tags := _events(v, from, &"kid_tagged")
	check(tags.size() >= 6, "병 12000초(현실 40초쯤)에 여러 번 잡음 (%d번)" % tags.size())
	check(bad_it == 0, "잡힌 아이가 다음 술래 · 제 자신을 잡지 않음")
	check(its.size() == 3, "셋 다 술래를 해 봄 (%d)" % its.size())
	check(far < 2.2, "놀이 자리 둘레를 벗어나지 않음 (%.2f칸)" % far)
	check(jump < 0.5, "자리가 튀지 않음 (30초에 %.2f칸)" % jump)
	for k: Resident in kids:
		check(k.doing == "술래잡기하는 중" and ChildPlay.playing(v, k), "%s: 술래잡기하는 중" % k.name)
		check(Vector2(k.x, k.y).distance_to(c) < 2.0, "시뮬 자리는 제 자리 그대로")
	# 혼자 남으면 돌탑으로
	for i in [2, 1]:
		kids[i].steps.clear()
	for k in 140:
		ChildPlay.step(v, 30.0)
	check(String(g["kind"]) == "stack" and (g["who"] as Array).size() == 1 and kids[0].doing == "돌탑을 쌓는 중", "혼자 남으면 돌탑을 쌓음 (%s · %d명)" % [g["kind"], (g["who"] as Array).size()])


func test_stack() -> void:
	print("== 아이·아기: 돌탑 — 차례로 얹고, 흔들리다 무너지고, 다시")
	var v := _village(9.0)
	var c := _open_centre(v)
	var kids: Array = [_kid(v, "보리", 2.0, c.x, c.y), _kid(v, "새별", 2.4, c.x, c.y)]
	var g := _game(v, "stack", kids, c)
	g["c1"] = 1.0e9
	var from := v.events.serial
	var top := 0
	var turns := {}
	var wob := false
	for k in 600:
		ChildPlay.step(v, 30.0)
		top = maxi(top, int(g["h"]))
		if int(g["turn"]) >= 0:
			turns[int(g["turn"])] = true
		wob = wob or int(g["ph"]) == 1
		for i in 2:
			if ChildPlay.spot(g, i, float(g["c"])).distance_to(c) >= 1.0:
				check(ChildPlay.spot(g, i, float(g["c"])).distance_to(c) < 1.0, "돌탑 곁")
	var falls := _events(v, from, &"kid_stack_fell")
	check(falls.size() >= 2 and int(g["falls"]) == falls.size(), "무너지고 다시 쌓음 (%d번)" % falls.size())
	check(top >= ChildPlay.STACK_MIN and top <= ChildPlay.STACK_MAX, "돌 %d개까지 (셋~여섯)" % top)
	check(wob, "무너지기 전에 흔들림")
	check(turns.size() == 2, "둘이 번갈아 얹음")
	for e: Dictionary in falls:
		var h := int((e["v"] as Dictionary)["h"])
		if h < ChildPlay.STACK_MIN or h > ChildPlay.STACK_MAX:
			check(h >= ChildPlay.STACK_MIN and h <= ChildPlay.STACK_MAX, "무너질 때 돌 %d개" % h)
	var s0 := ChildPlay.seat(g, 0)
	var s1 := ChildPlay.seat(g, 1)
	check(s0.y < c.y and s1.y < c.y, "탑 뒤쪽에 앉음 (탑이 가려지지 않게)")


func test_butterfly() -> void:
	print("== 아이·아기: 나비 쫓기 — 나비 뒤를 조금 늦게 밟음 · 봄~가을 낮에만")
	var v := _village(9.0)
	var c := _open_centre(v)
	var kids: Array = [_kid(v, "보리", 2.0, c.x, c.y), _kid(v, "새별", 2.4, c.x, c.y), _kid(v, "한솔", 2.8, c.x, c.y)]
	var g := _game(v, "bfly", kids, c)
	g["c1"] = 1.0e9
	var jump := 0.0
	var far := 0.0
	var gap := 0.0
	var prev := Vector2.ZERO
	for k in 300:
		ChildPlay.step(v, 30.0)
		var cc := float(g["c"])
		var b := ChildPlay.bfly_at(g, cc)
		var p := ChildPlay.spot(g, 0, cc)
		far = maxf(far, maxf(p.distance_to(c), b.distance_to(c)))
		gap = maxf(gap, p.distance_to(b))
		if k > 0:
			jump = maxf(jump, p.distance_to(prev))
		prev = p
		if p.distance_to(ChildPlay.bfly_at(g, cc - ChildPlay.BFLY_LAG.x)) >= 0.2:
			check(p.distance_to(ChildPlay.bfly_at(g, cc - ChildPlay.BFLY_LAG.x)) < 0.2, "나비가 지나간 자리를 밟음")
	check(far < 2.3 and jump < 0.4, "둘레 안 (%.2f칸) · 튀지 않음 (%.2f칸)" % [far, jump])
	check(gap > 0.2 and gap < 2.2, "나비와 떨어져 쫓음 (가장 멀 때 %.2f칸)" % gap)
	# 종류 고르기: 밤·겨울엔 나비 없음
	var st := ChildPlay._state(v)
	var old := Village.default_created
	var any_b := false
	for n in 40:
		st["last"] = ""
		any_b = any_b or ChildPlay._pick_kind(v, st, n) == "bfly"
	var month := int(Health.jar_date(v)["month"])
	check(any_b == (month >= 3 and month <= 10), "%d월 낮: 나비 %s" % [month, "있음" if any_b else "없음"])
	_set_hour(v, 19.0)
	var late := false
	for n in 40:
		st["last"] = ""
		late = late or ChildPlay._pick_kind(v, st, n) == "bfly"
	check(not late, "저녁엔 나비 쫓기 없음")
	Village.default_created = old


func test_leave_and_end() -> void:
	print("== 아이·아기: 자리를 비우면 기다려 주다 뺌 · 때가 되면 흩어짐")
	var v := _village(9.0)
	var c := _open_centre(v)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 2.0 + 0.4 * i, c.x, c.y))
	var g := _game(v, "tag", kids, c)
	g["c1"] = 1.0e9
	for k in 30:
		ChildPlay.step(v, 30.0)
	var it := v.person(int(g["it"]))
	check(it != null, "술래가 있음")
	it.steps.clear()                     # 술래가 밥 먹으러 감
	for k in 4:
		ChildPlay.step(v, 30.0)
	check(int(g["it"]) != it.id and int(g["it"]) >= 0 and (g["who"] as Array).size() == 3, "술래가 자리를 비우면 다른 아이가 술래 · 자리는 맡아 둠")
	check(ChildPlay.spot(g, ChildPlay.idx(g, it.id), float(g["c"])) == ChildPlay.seat(g, int(g["sl"][ChildPlay.idx(g, it.id)])), "비운 아이의 자리 = 제 자리")
	ChildPlay._attach(it, g, ChildPlay.idx(g, it.id), 1.0e7)      # 돌아옴
	ChildPlay.step(v, 30.0)
	check(int(g["on"][ChildPlay.idx(g, it.id)]) == 1, "돌아오면 다시 낌")
	it.steps.clear()
	for k in 60:
		ChildPlay.step(v, 30.0)
	check(ChildPlay.idx(g, it.id) < 0 and (g["who"] as Array).size() == 2, "오래 비우면 빠짐")
	# 끝: 놀이 시간이 다 됨
	g["c1"] = float(g["c"]) + 60.0
	for k in 4:
		ChildPlay.step(v, 30.0)
	check(ChildPlay.games(v).is_empty(), "시간이 다 되면 흩어짐")
	check(float(v.kids["next"]) > v.t and String(v.kids["last"]) == "tag", "다음 놀이까지 쉼 · 지난 놀이를 기억")
	for k: Resident in [kids[0], kids[1], kids[2]]:
		if k == it:
			continue
		check(k.steps.is_empty() and k.doing == "노는 중", "%s: 놀이 걸음이 치워짐" % k.name)
	# 끝: 저녁 (일 시간이 끝남)
	var g2 := _game(v, "stack", [kids[0], kids[1]], c)
	g2["c1"] = 1.0e9
	_set_hour(v, 21.0)
	ChildPlay.step(v, 30.0)
	check(ChildPlay.games(v).is_empty(), "일 시간이 끝나면 흩어짐")


func test_minder() -> void:
	print("== 아이·아기: 아기를 보는 사람 — 집 가까이 쉬거나 돌보는 부모만 (일·먼 길엔 문 앞 요람)")
	var v := _village(10.0)
	var hm := v.add_building("오두막", v.fire.x + 6.0, v.fire.y + 3.0, true)
	var mom: Resident = null
	var dad: Resident = null
	for r in v.people:
		if r.is_adult() and r.sex == "f" and mom == null:
			mom = r
		elif r.is_adult() and r.sex == "m" and dad == null:
			dad = r
	var baby := v.add_person("아람", "f", 0.15, "", hm.x, hm.y, mom, dad)
	baby.parents = PackedInt32Array([mom.id, dad.id])
	for p: Resident in [mom, dad, baby]:
		p.home = hm.id
	var put := func(p: Resident, action: String, carry: String, dx: float, asleep := false) -> void:
		p.action = action
		p.carry = carry
		p.x = hm.x + dx
		p.y = hm.y + 1.0
		p.sleeping = asleep
		p.anim = "sleep" if asleep else "idle"
	put.call(mom, "care", "", 1.0)
	put.call(dad, "work", "", 1.0)
	check(ChildPlay.minder(v, baby, v.people) == mom, "곁에서 돌보는 엄마")
	check(ChildPlay.baby_doing(v, baby) == "엄마 품에 안겨 있는 중", "하는 일: %s" % ChildPlay.baby_doing(v, baby))
	put.call(mom, "work", "", 1.0)
	check(ChildPlay.minder(v, baby, v.people) == null, "둘 다 일하는 중 → 문 앞 요람")
	check(ChildPlay.baby_doing(v, baby) == "문 앞 요람에 누워 있는 중", "하는 일: %s" % ChildPlay.baby_doing(v, baby))
	put.call(mom, "explore", "", 2.0)
	check(ChildPlay.minder(v, baby, v.people) == null, "살피러 가는 길엔 데려가지 않음")
	put.call(mom, "rest", "", 30.0)
	check(ChildPlay.minder(v, baby, v.people) == null, "집에서 먼 곳에선 데리고 있지 않음")
	put.call(mom, "rest", "밀", 1.0)
	check(ChildPlay.minder(v, baby, v.people) == null, "짐을 든 손으론 젖먹이를 안지 않음")
	put.call(dad, "idle", "", 2.0)
	check(ChildPlay.minder(v, baby, v.people) == dad, "엄마 손이 차면 쉬는 아빠")
	check(ChildPlay.baby_doing(v, baby) == "아빠 품에 안겨 있는 중", "하는 일: %s" % ChildPlay.baby_doing(v, baby))
	put.call(mom, "rest", "", 1.0)
	check(ChildPlay.minder(v, baby, v.people) == mom, "둘 다 되면 엄마")
	put.call(mom, "rest", "", 1.0, true)
	check(ChildPlay.minder(v, baby, v.people) == dad, "자는 엄마는 아님")
	put.call(mom, "care", "유모차", 40.0)
	check(ChildPlay.minder(v, baby, v.people) == mom, "유모차 산책은 어디든")
	put.call(mom, "work", "", 1.0)
	put.call(dad, "work", "", 1.0)
	var gran := v.add_person("할매", "f", Balance.AGE_ELDER + 1.0, "", hm.x + 1.0, hm.y + 1.0, null, null)
	gran.home = hm.id
	gran.action = "rest"
	check(ChildPlay.minder(v, baby, v.people) == gran, "부모가 일하면 한집 노인이 봄")
	check(ChildPlay.baby_doing(v, baby) == "할머니 품에 안겨 있는 중", "하는 일: %s" % ChildPlay.baby_doing(v, baby))
	gran.home = -1
	baby.age = 0.7
	check(ChildPlay.minder(v, baby, v.people) == null and ChildPlay.baby_doing(v, baby) == "문 앞에 앉아 노는 중", "걸음마 아기: 볼 사람이 없으면 문 앞")
	put.call(mom, "chores", "빵", 1.0)
	check(ChildPlay.minder(v, baby, v.people) == mom and ChildPlay.baby_doing(v, baby) == "엄마 뒤를 아장아장 따라다니는 중", "걸음마 아기: 집안일 하는 엄마 뒤 (손에 든 것이 있어도)")
	_set_hour(v, 23.0)
	check(ChildPlay.baby_doing(v, baby) == "집 안의 아기", "밤엔 집 안")
	var d := ChildPlay.door(v, baby)
	check(d.y > hm.y + hm.size() * 0.5 and absf(d.x - hm.x) < 1.2, "요람 자리는 집 문 옆")
	# ResidentAI._baby: 시뮬 자리는 집 안 그대로, 하는 일만 화면과 같은 말
	_set_hour(v, 10.0)
	baby.steps.clear()
	ResidentAI._baby(v, baby)
	check(is_equal_approx(baby.x, hm.x) and is_equal_approx(baby.y, hm.y) and baby.action == "baby" and baby.doing == ChildPlay.baby_doing(v, baby), "아기의 시뮬 자리는 집 안 · 하는 일은 '%s'" % baby.doing)


func test_peek() -> void:
	print("== 아이·아기: 문 옆 요람을 지나가던 이웃이 잠깐 들여다봄")
	var v := _village(10.0)
	var hm := v.add_building("오두막", v.fire.x + 6.0, v.fire.y + 3.0, true)
	var grown: Array = []
	for r in v.people:
		if r.is_adult():
			grown.append(r)
	var mom: Resident = grown[0]
	var dad: Resident = grown[1]
	var nb: Resident = grown[2]
	var baby := v.add_person("아람", "f", 0.15, "", hm.x, hm.y, mom, dad)
	baby.parents = PackedInt32Array([mom.id, dad.id])
	baby.home = hm.id
	for p: Resident in v.people:
		p.action = "work"
		p.anim = "work"
		p.steps.clear()
		p.x = hm.x + 20.0
		p.y = hm.y + 20.0
	baby.action = "baby"
	var d := ChildPlay.door(v, baby)
	nb.x = d.x + 1.6
	nb.y = d.y + 0.8
	nb.action = "rest"
	nb.anim = "idle"
	nb.doing = "쉬는 중"
	nb.steps = [ResidentAI.act(900.0, "idle")]
	var joy := nb.happiness
	var from := v.events.serial
	ChildPlay.step(v, ChildPlay.CARE_IV)
	var ev := _events(v, from, &"baby_peeked")
	check(ev.size() == 1 and int(ev[0]["who"]) == nb.id and int((ev[0]["v"] as Dictionary)["baby"]) == baby.id, "baby_peeked — 곁의 쉬는 이웃")
	check(nb.steps.size() == 3 and String(nb.steps[0]["k"]) == "walk" and int((nb.steps[1] as Dictionary).get("pk", -1)) == baby.id, "요람 곁으로 가서 잠깐 멈춤 (하던 일은 뒤에 그대로)")
	check(Vector2(float(nb.steps[0]["x"]), float(nb.steps[0]["y"])).distance_to(d) < 0.7, "요람 바로 곁")
	check(nb.doing == "아람을 들여다보는 중", "하는 일: %s" % nb.doing)
	check(run.words_ok([nb.doing]) == "", "금지어 없음")
	check(nb.happiness == joy and baby.happiness == baby.happiness, "행복은 그대로")
	check(float(v.social["busy"][str(nb.id)]) > v.t, "그동안 다른 만남에 끼지 않음")
	nb.steps = [ResidentAI.act(900.0, "idle")]
	ChildPlay.step(v, ChildPlay.CARE_IV)
	check(_events(v, from, &"baby_peeked").size() == 1, "곧바로 또 들여다보지 않음")
	# 끝나면 하던 일 이름으로
	var done: Variant = ResidentAI.op("social_done", {"was": "쉬는 중"})
	nb.doing = "아람을 들여다보는 중"
	ResidentAI.run_op(v, nb, done)
	check(nb.doing == "쉬는 중", "들여다본 뒤 하던 일로 (%s)" % nb.doing)
	# 부모가 곁에서 안고 있으면 · 일하는 이웃이면 · 밤이면 없음
	var v2 := _village(10.0)
	var hm2 := v2.add_building("오두막", v2.fire.x + 6.0, v2.fire.y + 3.0, true)
	var g2: Array = []
	for r in v2.people:
		if r.is_adult():
			g2.append(r)
	var b2 := v2.add_person("아람", "f", 0.15, "", hm2.x, hm2.y, g2[0], g2[1])
	b2.parents = PackedInt32Array([g2[0].id, g2[1].id])
	b2.home = hm2.id
	var d2 := ChildPlay.door(v2, b2)
	for p: Resident in v2.people:
		p.action = "work"
		p.anim = "walk"
		p.carry = "판자"
		p.steps.clear()
		p.x = d2.x + 1.0
		p.y = d2.y + 0.5
	ChildPlay.step(v2, ChildPlay.CARE_IV)
	check(_events(v2, 0, &"baby_peeked").is_empty(), "일하는·짐 든 이웃은 멈추지 않음")
	var n2: Resident = g2[2]
	n2.action = "rest"
	n2.carry = ""
	_set_hour(v2, 23.0)
	ChildPlay.step(v2, ChildPlay.CARE_IV)
	check(_events(v2, 0, &"baby_peeked").is_empty(), "밤엔 없음")
	_set_hour(v2, 10.0)
	var m2: Resident = g2[0]
	m2.action = "care"
	m2.carry = ""
	m2.anim = "idle"
	ChildPlay.step(v2, ChildPlay.CARE_IV)
	check(_events(v2, 0, &"baby_peeked").is_empty(), "엄마 품에 있으면 없음")
	m2.action = "work"
	ChildPlay.step(v2, ChildPlay.CARE_IV)
	check(_events(v2, 0, &"baby_peeked").size() == 1, "요람에 누워 있고 쉬는 이웃이 지나가면 있음")


func test_first_steps() -> void:
	print("== 아이·아기: 첫걸음마 — 아기마다 한 번, 연대기 한 줄")
	var v := _village(10.0)
	var baby := _kid(v, "아람", ChildPlay.TODDLE_AGE - 0.02, v.fire.x + 3.0, v.fire.y + 3.0)
	var old := _kid(v, "도담", 0.9, v.fire.x + 3.0, v.fire.y + 3.0)
	var from := v.events.serial
	var lines := v.book.size()
	ChildPlay.step(v, ChildPlay.CARE_IV)
	check(_events(v, from, &"first_steps").is_empty(), "젖먹이는 아직 · 이미 걷던 아기(옛 저장)는 조용히")
	check(v.kids["walked"].has(str(old.id)) and not v.kids["walked"].has(str(baby.id)), "걷는 아기로 적어 둠")
	baby.age = ChildPlay.TODDLE_AGE + 0.01
	_set_hour(v, 2.0)
	ChildPlay.step(v, ChildPlay.CARE_IV)
	check(_events(v, from, &"first_steps").is_empty(), "밤에는 떼지 않음 (아침에)")
	_set_hour(v, 9.0)
	ChildPlay.step(v, ChildPlay.CARE_IV)
	var ev := _events(v, from, &"first_steps")
	check(ev.size() == 1 and int(ev[0]["who"]) == baby.id, "first_steps 한 번")
	var said := ""
	for i in range(lines, v.book.size()):
		said += String(v.book[i]["text"])
	check(said.contains("아람이 첫걸음마를 뗐다"), "연대기: %s" % said)
	check(run.words_ok([said]) == "", "금지어 없음")
	for k in 5:
		ChildPlay.step(v, ChildPlay.CARE_IV)
	check(_events(v, from, &"first_steps").size() == 1, "다시 내지 않음")
	baby.age = Balance.AGE_BABY + 0.1
	ChildPlay.step(v, ChildPlay.CARE_IV)
	check(not v.kids["walked"].has(str(baby.id)), "자라면 적어 둔 것을 치움")


func test_save() -> void:
	print("== 아이·아기: 놀이는 저장하고 불러도 그대로 이어짐")
	var v := _village(9.0)
	var c := _open_centre(v)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 2.0 + 0.4 * i, c.x, c.y))
	var g := _game(v, "tag", kids, c)
	g["c1"] = 1.0e9
	for k in 50:
		ChildPlay.step(v, 30.0)
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(SaveCodec.digest(SaveCodec.enc(w.kids)) == SaveCodec.digest(SaveCodec.enc(v.kids)), "저장 → 불러옴: 놀이 상태가 같음")
	check(ChildPlay.games(w).size() == 1 and ChildPlay.playing(w, w.person(kids[0].id)), "불러온 뒤에도 놀이 중 (걸음의 놀이 표시가 남음)")
	var a := v.events.serial
	var b := w.events.serial
	for k in 200:
		ChildPlay.step(v, 30.0)
		ChildPlay.step(w, 30.0)
	var ta := _events(v, a, &"kid_tagged")
	var tb := _events(w, b, &"kid_tagged")
	var same := ta.size() == tb.size() and ta.size() >= 3
	for i in mini(ta.size(), tb.size()):
		same = same and int(ta[i]["who"]) == int(tb[i]["who"]) and is_equal_approx(float(ta[i]["t"]), float(tb[i]["t"]))
	check(same, "불러온 마을에서도 같은 아이가 같은 때 잡힘 (%d · %d번)" % [ta.size(), tb.size()])
	var gw: Dictionary = ChildPlay.games(w)[0]
	check(ChildPlay.spot(gw, 0, float(gw["c"])).distance_to(ChildPlay.spot(g, 0, float(g["c"]))) < 0.001, "같은 자리")
	var empty := Village.new_prototype(5)
	empty.kids = {}
	ChildPlay.step(empty, 30.0)
	check(ChildPlay.games(empty).is_empty() and empty.kids.has("walked"), "옛 저장(빈 상태)도 그대로 돎")


## 아이 넷이 있는 마을의 하루: 놀이가 저절로 열리고, 술래가 바뀌거나 돌탑이 무너지고, 밥때·밤엔 없다
func _day_village(seed_v: int, aware: bool) -> Village:
	var keep := Village.start_aware
	Village.start_aware = aware
	var w := Village.new_prototype(seed_v)
	Village.start_aware = keep
	w.water.offline = true
	w.stock["빵"] = 300.0
	var mom: Resident = null
	var dad: Resident = null
	for r in w.people:
		if r.is_adult() and r.sex == "f" and mom == null:
			mom = r
		elif r.is_adult() and r.sex == "m" and dad == null:
			dad = r
	for i in 4:
		var c := w.add_person(["보리", "새별", "한솔", "다래"][i], "f" if i % 2 == 0 else "m", 1.6 + 0.5 * i, "", w.fire.x + 2.0 + 0.3 * i, w.fire.y + 2.5, mom, dad)
		c.parents = PackedInt32Array([mom.id, dad.id])
	var b := w.add_person("아람", "f", 0.1, "", w.fire.x + 1.0, w.fire.y + 1.0, mom, dad)
	b.parents = PackedInt32Array([mom.id, dad.id])
	return w


func test_village_day() -> void:
	print("== 아이·아기: 마을의 이틀 — 놀이가 저절로 열리고 밥때·밤엔 없음")
	var w := _day_village(31, true)
	var bad_time := 0
	var big := 0
	var most := 0
	var labels := {}
	var steps := 2 * 24 * 30 if quick else 4 * 24 * 30
	for i in steps:
		w.advance(120.0)
		var gs := ChildPlay.games(w)
		if not gs.is_empty():
			var h := w.hour_now()
			if not w.is_work_time():
				bad_time += 1
			for g: Dictionary in gs:
				big = maxi(big, (g["who"] as Array).size())
				var on := 0
				for o: Variant in g["on"]:
					on += int(o)
				most = maxi(most, on)
		for r in w.people:
			if r.is_child() and r.doing.ends_with("중") and (r.doing.contains("술래") or r.doing.contains("나비") or r.doing.contains("돌탑")):
				labels[r.doing] = true
	var started := _events(w, 0, &"kid_play_started").size()
	var tagged := _events(w, 0, &"kid_tagged").size()
	var fell := _events(w, 0, &"kid_stack_fell").size()
	print("   놀이 %d번 · 잡음 %d번 · 돌탑 무너짐 %d번 · 한 놀이에 가장 많이 %d명(자리에 %d명) · %s" % [started, tagged, fell, big, most, str(labels.keys())])
	check(started >= 3, "이틀에 놀이가 여러 번 열림 (%d번)" % started)
	check(tagged + fell >= 1, "놀이가 실제로 굴러감 (잡음 %d · 무너짐 %d)" % [tagged, fell])
	check(bad_time == 0, "일 시간 밖에 남은 놀이 없음")
	check(big >= 2 and big <= ChildPlay.MAX_KIDS and most >= 2, "2~4명이 어울림 (가장 많이 %d명, 자리에 %d명)" % [big, most])
	for r in w.people:
		for s: Dictionary in r.steps:
			if s.has("g"):
				if ChildPlay.game_of(w, r.id).is_empty():
					check(not ChildPlay.game_of(w, r.id).is_empty(), "놀이 표시가 달린 걸음은 벌어진 놀이의 것")


## 결정성 (ADR-0001 3절): 같은 시드 — 지켜보든 말든, 화면이 사건을 읽든 말든 같은 놀이·같은 자리.
## (지켜봄은 깨달은 마을에선 기획상 입력이라 social 시험처럼 깨닫기 전 마을로 잰다)
func _det_run(watch: bool, stage: bool) -> String:
	var w := _day_village(31, false)
	w.watching = watch
	var cur := 0
	var n_ev := 0
	for i in 2 * 96:
		w.advance(900.0)
		if stage:
			for e: Dictionary in w.events.since(cur):
				cur = int(e["n"])
				n_ev += 1
			Social.take_events(w)
	var parts := PackedStringArray()
	for r in w.people:
		parts.append("%d:%.3f,%.3f:%s:%s:%d:%.4f:%s" % [r.id, r.x, r.y, r.action, r.anim, r.steps.size(), r.hunger, r.doing])
	parts.append(SaveCodec.digest(SaveCodec.enc(w.kids)))
	parts.append(SaveCodec.digest(SaveCodec.enc(w.social)))
	parts.append(str(w.rng.state))
	parts.append(str(w.social_rng.state))
	var kinds := {}
	for e: Dictionary in w.events.since(0):
		if String(e["kind"]).begins_with("kid_") or e["kind"] == &"baby_peeked" or e["kind"] == &"first_steps":
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
	parts.append(str(kinds))
	return "|".join(parts)


func test_watch_determinism() -> void:
	print("== 아이·아기: 지켜봄·화면 읽기를 바꿔도 병 이틀 뒤 같은 놀이·자리")
	var base := _det_run(true, true)
	var off := _det_run(false, false)
	if base != off:
		var a := base.split("|")
		var b := off.split("|")
		for k in mini(a.size(), b.size()):
			if a[k] != b[k]:
				print("   첫 차이 #%d: %s ↔ %s" % [k, a[k], b[k]])
				break
	check(base == off, "지켜봄 켬 + 화면 읽음 ↔ 지켜봄 끔 + 안 읽음 → 같음")
	check(base == _det_run(true, false), "지켜봄 켬: 화면 읽음 ↔ 안 읽음 → 같음")
	check(base.contains("kid_play_started"), "그 이틀에 놀이가 열렸음 (빈 비교가 아님): %s" % base.get_slice("|", base.get_slice_count("|") - 1))


## 화면 쪽 (머리 없는 실행에서 되는 만큼): 몸짓 함수는 시뮬을 건드리지 않고, 그림 재료가 만들어짐
func test_view() -> void:
	print("== 아이·아기: 화면 — 그림 재료 · 몸짓은 화면만")
	var tex := KidsView.atlas()
	check(tex != null and tex.get_width() == KidsView.ATLAS.x and tex.get_height() == KidsView.ATLAS.y, "소품 그림판 %s" % str(KidsView.ATLAS))
	var img := Image.load_from_file(ProjectSettings.globalize_path(KidsView.ATLAS_PATH))
	for k: String in KidsView.PICS:
		var rc: Rect2i = KidsView.PICS[k]
		var solid := 0
		var ink := 0
		for y in range(rc.position.y, rc.end.y):
			for x in range(rc.position.x, rc.end.x):
				var px := img.get_pixel(x, y)
				if px.a > 0.5:
					solid += 1
					if px.v < 0.3:
						ink += 1
		check(solid > 20 and (ink > 8 or k == "puff") and solid < rc.size.x * rc.size.y, "그림 '%s': 칠 %d · 먹선 %d" % [k, solid, ink])
	check(KidsView.atlas() == tex, "그림판은 한 번만 만듦")
