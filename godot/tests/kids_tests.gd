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
	run.timed(self, ["test_source_and_words", "test_play_rng_order", "test_when_and_who", "test_tag", "test_stack", "test_butterfly", "test_leave_and_end", "test_hop", "test_skip", "test_story", "test_story_arc", "test_story_no_stop",
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
		for k: String in ["kid_play_started", "kid_tagged", "kid_stack_fell", "baby_peeked", "first_steps", "kid_hop_done", "kid_skip_thrown"]:
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
	ChildPlay._state(v)["last"] = "skip"                     # 물수제비는 셋까지 (test_skip이 따로 봄) — 여기선 넷까지 끼는 놀이만
	while ChildPlay.games(v).is_empty() and tries < 40:      # 굴림(START_P)에 따라 몇 번 만에 열림
		ChildPlay.try_play(v, kids[0], c, 900.0)
		tries += 1
	check(ChildPlay.games(v).size() == 1, "낮: 놀이가 열림 (%d번째)" % tries)
	var g: Dictionary = ChildPlay.games(v)[0]
	check(String(g["kind"]) in ["tag", "bfly", "stack", "hop"], "놀이 종류 %s" % g["kind"])
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


func _elder(v: Village, x: float, y: float) -> Resident:
	var e := v.add_person("할매", "f", Balance.AGE_ELDER + 1.0, "", x, y, null, null)
	e.action = "rest"
	e.anim = "sit"
	e.sleeping = false
	e.doing = "모닥불 곁에서 쉬는 중"
	e.steps = [ResidentAI.act(3000.0, "sit")]
	return e


func _elder_sig(e: Resident) -> String:
	return "%s|%s|%d|%.3f,%.3f|%s|%s" % [e.action, e.anim, e.steps.size(), e.x, e.y, e.doing, str(e.steps[0]) if not e.steps.is_empty() else ""]


func test_story() -> void:
	print("== 아이·아기: 저녁 이야기 — 저녁에 앉아 쉬는 어르신 둘레로 반원, 어르신이 없으면 없음, 일어나면 흩어짐")
	var v := _village(19.3)
	var e := Vector2(v.fire.x + 1.4, v.fire.y + 1.4)
	for a: float in [0.785, 0.2, 1.4, -0.4, 2.0, -1.0, 2.6, 3.4, 4.2, 5.0]:     # 모닥불 곁 쉬는 자리(두 칸) 가운데 열린 곳
		var q := Vector2(v.fire.x, v.fire.y) + Vector2(cos(a), sin(a)) * 2.0
		if ChildPlay.story_side(v, q) != 0:
			e = q
			break
	var b0: Vector2 = ChildPlay.fire_benches(v)[0]
	check(ChildPlay.story_side(v, b0 - Vector2(0.7071, 0.7071) * 0.4) == 0, "걸상 바로 뒤(화면에서 걸상에 가려지는 자리)의 어르신에게는 모이지 않음")
	for r in v.people:                         # 어른들은 멀리서 일함
		r.x = e.x + 14.0 + float(r.id % 5)
		r.y = e.y - 10.0
		r.action = "work"
		r.anim = "work"
		r.sleeping = false
		r.steps = [ResidentAI.act(1.0e6, "work")]
	var kids: Array = []
	for i in 5:
		kids.append(_kid(v, ["보리", "새별", "한솔", "다래", "가람"][i], 1.5 + 0.3 * i, e.x + 2.0 + 0.3 * i, e.y + 1.0))
	var p := e + Vector2(3.0, 1.0)
	check(ChildPlay.story_side(v, e) != 0, "모닥불 곁 어르신 자리 둘레에 앉을 곳이 있음")
	check(not ChildPlay.try_play(v, kids[0], p, 900.0) and ChildPlay.games(v).is_empty(), "저녁이어도 어르신이 없으면 이야기 없음")
	var el := _elder(v, e.x, e.y)
	var sig := _elder_sig(el)
	var st := ChildPlay._state(v)
	_set_hour(v, 10.0)                         # 낮: 이야기 아님 (다른 놀이는 열릴 수 있음)
	for i in 6:
		ChildPlay.try_play(v, kids[0], p, 900.0)
	var day_story := false
	for g0: Dictionary in ChildPlay.games(v):
		day_story = day_story or String(g0["kind"]) == "story"
	check(not day_story, "낮에는 이야기 없음")
	(st["g"] as Array).clear()
	for k: Resident in kids:
		k.steps.clear()
	_set_hour(v, 19.3)
	el.sleeping = true
	check(not ChildPlay.try_play(v, kids[0], p, 900.0), "잠든 어르신: 없음")
	el.sleeping = false
	el.steps = [ResidentAI.walk(e.x + 5.0, e.y)]
	check(not ChildPlay.try_play(v, kids[0], p, 900.0), "걸어가는 어르신: 없음")
	el.steps = [ResidentAI.act(3000.0, "sit")]
	kids[0].x += 20.0
	check(not ChildPlay.try_play(v, kids[0], p, 900.0), "멀리 있는 아이: 없음")
	kids[0].x -= 20.0
	sig = _elder_sig(el)
	var from := v.events.serial
	check(ChildPlay.try_play(v, kids[0], p, 900.0), "저녁 · 앉아 쉬는 어르신 곁: 이야기를 들으러 감")
	var gs := ChildPlay.games(v)
	check(gs.size() == 1 and String(gs[0]["kind"]) == "story" and int(gs[0]["el"]) == el.id, "이야기 자리가 열림 (어르신 둘레)")
	var g: Dictionary = gs[0]
	check(kids[0].doing == String(ChildPlay.LABEL["story"]) and run.words_ok([kids[0].doing]) == "", "하는 일: %s" % kids[0].doing)
	var evs := _events(v, from, &"kid_play_started")
	check(evs.size() == 1 and String(evs[0]["v"]["kind"]) == "story" and int(evs[0]["who"]) == kids[0].id, "사건 kid_play_started (story)")
	for i in range(1, 5):
		ChildPlay.try_play(v, kids[i], p, 900.0)
	var cap := int(g["cap"])
	check(cap >= ChildPlay.STORY_MIN and cap <= ChildPlay.MAX_KIDS and cap == ChildPlay.story_seats(v, e).size(), "앉을 자리는 열린 곳만 (%d자리)" % cap)
	check((g["who"] as Array).size() == cap and ChildPlay.idx(g, kids[4].id) < 0, "자리만큼만 둘러앉음 (다섯째는 못 낌)")
	var seats: Array = []
	var benches := ChildPlay.fire_benches(v)
	var ok_open := not ChildPlay._story_hidden(v, e, benches)
	for i in cap:
		var s := ChildPlay.seat(g, int(g["sl"][i]))
		seats.append(s)
		ok_open = ok_open and not ChildPlay._story_hidden(v, s, benches)
	check(ok_open, "어르신도 아이들도 걸상·건물·제단·나무 뒤가 아님")
	var ok_d := true
	var ok_side := true
	var ok_apart := true
	for i in seats.size():
		var s: Vector2 = seats[i]
		var d := (s - e).length()
		ok_d = ok_d and d > 0.8 and d < 1.4 and not v.water_at(s.x, s.y) and (s - Vector2(v.fire.x, v.fire.y)).length() >= ChildPlay.STORY_FIRE
		ok_side = ok_side and (s - e).dot(Vector2(0.7071, 0.7071)) > -0.4     # 화면 앞쪽 (어르신 뒤로 돌아가 앉지 않음)
		for j in i:
			ok_apart = ok_apart and (s - (seats[j] as Vector2)).length() > 0.5
	check(ok_d, "자리: 어르신에게서 한 칸쯤 · 물·모닥불 밖")
	check(ok_side and ok_apart, "어르신 앞쪽에 둘러앉음 (서로 겹치지 않게)")
	check(_elder_sig(el) == sig, "어르신의 걸음·하는 일은 그대로")
	for k: Resident in kids:                   # 걸어온 셈 치고 자리에 앉힘
		var gi := ChildPlay.idx(g, k.id)
		if gi < 0:
			continue
		var s := ChildPlay.seat(g, int(g["sl"][gi]))
		k.x = s.x
		k.y = s.y
		while not k.steps.is_empty() and String(k.steps[0]["k"]) != "do": k.steps.remove_at(0)
	for i in 3:
		ChildPlay.step(v, ChildPlay.IV)
	var n_on := 0
	for o: Variant in g["on"]:
		n_on += int(o)
	check(int(g["go"]) == 1 and n_on == cap, "다 앉아 이야기 시작")
	var rs := float(g["rs"])
	var pics := {}
	var gaps := 0
	var c := rs
	while c < rs + 4200.0:
		var pc: Array = ChildPlay.story_pic(g, c)
		if String(pc[0]) == "":
			gaps += 1
		else:
			pics[String(pc[0])] = true
		c += 20.0
	var known := true
	for nm: String in pics:
		known = known and KidBubbles.PICS.has(nm) and ChildPlay.STORY_PICS.has(nm)
	check(pics.size() >= 4 and gaps > 0 and gaps < 20 and known, "그림이 차례로 바뀜 (글 없음 · 앉은 뒤 잠깐만 비고 내내 떠 있음): %s" % str(pics.keys()))
	check(String(ChildPlay.story_pic(g, rs + 10.0)[0]) == "", "앉자마자는 아직")
	check(ChildPlay.story_nod(g, rs + 100.0) < 0, "처음엔 다 듣는다")
	var nod := ChildPlay.story_nod(g, rs + ChildPlay.STORY_NOD + 10.0)
	check(ChildPlay.idx(g, nod) >= 0, "한참 듣고 나면 한 아이가 꾸벅")
	check(_elder_sig(el) == sig, "이야기 동안에도 어르신은 그대로")
	el.steps = [ResidentAI.walk(e.x + 5.0, e.y)]     # 어르신이 일어남 → 흩어짐
	ChildPlay.step(v, ChildPlay.IV)
	var tagged := 0
	var plain := 0
	for k: Resident in kids:
		for sd: Dictionary in k.steps:
			tagged += int(sd.has("g"))
		plain += int(k.doing == ChildPlay.PLAIN)
	check(ChildPlay.games(v).is_empty() and tagged == 0 and plain == cap, "어르신이 일어나면 끝 (아이들은 그냥 놂)")
	check(not ChildPlay._story_ready(v, st, st["g"]), "이야기가 끝난 바로 뒤엔 다시 열지 않음")
	# 부름: 놀이를 새로 시작하지 않아도, 놀던 아이들이 앉아 쉬는 어르신에게 모인다 (술래잡기 하던 아이도)
	st["snext"] = 0.0
	el.steps = [ResidentAI.act(3000.0, "sit")]
	sig = _elder_sig(el)
	for k: Resident in kids:
		k.action = "play"
		k.sleeping = false
		k.doing = ChildPlay.PLAIN
		k.steps = [ResidentAI.act(2000.0, "play")]
	var tg := ChildPlay.open_game(v, kids[0], p, "tag", 77)
	for i in 2:
		ChildPlay._add(tg, (kids[i] as Resident).id)
		((kids[i] as Resident).steps[0] as Dictionary)["g"] = int(tg["id"])
	kids[4].steps = [ResidentAI.act(300.0, "play")]     # 곧 놀이를 마칠 아이는 부르지 않음
	from = v.events.serial
	st["acc"] = 0.0
	ChildPlay.step(v, ChildPlay.IV)
	var sg: Dictionary = {}
	for g3: Dictionary in ChildPlay.games(v):
		if String(g3["kind"]) == "story":
			sg = g3
	check(not sg.is_empty() and _events(v, from, &"kid_play_started").size() == 1, "놀던 아이들 곁에 어르신이 앉아 쉬면 이야기가 열림")
	if not sg.is_empty():
		var ok_same := true
		for id: Variant in sg["who"]:
			var k := v.person(int(id))
			var last: Dictionary = k.steps[k.steps.size() - 1]
			ok_same = ok_same and k.action == "play" and String(last["k"]) == "do" and float(last["left"]) == 2000.0 and int(last["g"]) == int(sg["id"]) \
				and k.doing == String(ChildPlay.LABEL["story"])
		check((sg["who"] as Array).size() == int(sg["cap"]) and ok_same, "놀던 걸음 그대로 (하는 일·남은 시간 같음) 이야기 자리로")
		check(ChildPlay.idx(sg, kids[4].id) < 0 and ChildPlay.idx(tg, kids[0].id) < 0 and ChildPlay.idx(sg, kids[0].id) >= 0, "술래잡기 하던 아이도 옴 · 곧 마칠 아이는 안 옴")
		check(_elder_sig(el) == sig, "부를 때도 어르신은 그대로")
		st["acc"] = 0.0
		ChildPlay.step(v, ChildPlay.IV)
		var n_st := 0
		for g3: Dictionary in ChildPlay.games(v):
			n_st += int(String(g3["kind"]) == "story")
		check(n_st == 1, "이야기는 한 번에 하나")
	# 마을의 나흘 (어르신 한 분 · 아이 넷) — 저절로 열린다, 저녁에만, 같은 씨앗이면 같은 결과
	var res: Array = []
	var nat_hops := 0
	var nat_throws := 0
	var nat_wet := 0
	for pass_i in 3:
		var seed_v: int = [31, 31, 3][pass_i]      # 저녁 이야기는 드물다 (나흘에 0~2번) — 이야기가 열리는 씨앗 둘 (k3: 새 놀이가 끼며 굴림 차례가 바뀌어 다시 고름)
		var w := Village.new_prototype(seed_v)
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
			var kc := w.add_person(["보리", "새별", "한솔", "다래"][i], "f" if i % 2 == 0 else "m", 1.6 + 0.5 * i, "", w.fire.x + 2.0 + 0.3 * i, w.fire.y + 2.5, mom, dad)
			kc.parents = PackedInt32Array([mom.id, dad.id])
		var gran := w.add_person("할매", "f", Balance.AGE_ELDER + 1.0, "", w.fire.x + 1.5, w.fire.y + 1.0, null, null)
		gran.home = mom.home                   # 아이들 집에 함께 삶
		var bad := 0
		var seen := 0
		var sat := 0
		var hid := 0
		var cur := w.events.serial
		for i in 4 * 24 * 60:
			w.advance(60.0)
			for ev: Dictionary in w.events.since(cur):
				if ev["kind"] == &"kid_hop_done":
					nat_hops += 1
				elif ev["kind"] == &"kid_skip_thrown":
					nat_throws += 1
			cur = w.events.serial
			for r in w.people:
				if r.is_child() and not r.is_baby() and w.water_at(r.x, r.y):
					var gk := ChildPlay.game_of(w, r.id)
					nat_wet += int(not gk.is_empty() and String(gk["kind"]) in ["hop", "skip"])
			for g2: Dictionary in ChildPlay.games(w):
				if String(g2["kind"]) == "story":
					seen += 1
					var h := w.hour_now()
					if h < ChildPlay.STORY_HOURS.x or h >= ChildPlay.STORY_HOURS.y + 0.2 or not w.is_work_time():
						bad += 1
					var n2 := 0
					for o: Variant in g2["on"]:
						n2 += int(o)
					sat = maxi(sat, n2)
					hid += int(ChildPlay._story_hidden(w, Vector2(float(g2["x"]), float(g2["y"])), ChildPlay.fire_benches(w)))
		var n_story := _events(w, 0, &"kid_play_started").filter(func(ev: Dictionary) -> bool: return String(ev["v"]["kind"]) == "story").size()
		var parts := PackedStringArray()
		for r in w.people:
			parts.append("%d:%.3f,%.3f:%s:%.4f" % [r.id, r.x, r.y, r.action, r.hunger])
		parts.append(SaveCodec.digest(SaveCodec.enc(w.kids)))
		parts.append(SaveCodec.digest(SaveCodec.enc(w.stock)))
		parts.append(str(w.rng.state))
		res.append("|".join(parts))
		if pass_i != 1:
			print("   마을의 저녁 (씨앗 %d): 이야기 %d번 (살핀 틱 %d · 함께 앉은 아이 많을 때 %d)" % [seed_v, n_story, seen, sat])
			check(n_story >= 1 and seen >= 1, "나흘 사이 저녁 이야기가 저절로 열림 (씨앗 %d)" % seed_v)
			if pass_i == 0:                    # 씨앗 3에선 아이 하나만 닿는다 (다른 아이는 오는 길에 어르신이 일어남 — 어르신의 걸음은 건드리지 않음) — 씨앗 31에서 봄
				check(sat >= 2, "아이 둘 넘게 함께 앉아 들음 (씨앗 %d)" % seed_v)
			check(bad == 0, "이야기는 해 질 무렵~저녁에만 (일 시간 안)")
			check(hid == 0, "가려진 자리의 어르신에게는 모이지 않음")
	check(res[0] == res[1], "같은 씨앗 → 같은 결과 (이야기가 있어도 결정적)")
	print("   같은 나흘: 사방치기 %d판 · 물수제비 %d번 던짐 (세 번 돈 합)" % [nat_hops, nat_throws])
	check(nat_hops >= 2 and nat_throws >= 1, "나흘 사이 사방치기·물수제비도 저절로 벌어짐")
	check(nat_wet == 0, "사방치기·물수제비 하는 아이는 물에 들어가지 않음 (%d틱)" % nat_wet)


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


# ───────────────────────── 사방치기 · 물수제비 (k3) ─────────────────────────
## 열린 놀이에 아이들을 제 자리에 세움 (걸음: 놀기 하나)
func _join_all(g: Dictionary, kids: Array) -> void:
	for k: Resident in kids:
		var i := ChildPlay._add(g, k.id)
		var sp := ChildPlay.seat(g, int(g["sl"][i]))
		k.x = sp.x
		k.y = sp.y
		k.steps.clear()
		ChildPlay._attach(k, g, i, 1.0e7)


## 건물·밭 발자리 안인가
func _on_building(v: Village, q: Vector2) -> bool:
	for b in v.buildings:
		if absf(q.x - b.x) < b.size() * 0.5 and absf(q.y - b.y) < b.size() * 0.5:
			return true
	return false


## 사방치기 자리를 찾음 (아이 r 둘레) → {"c", "dir"} · 없으면 {}
func _hop_place(v: Village, r: Resident) -> Dictionary:
	for n in 60:
		var hp := ChildPlay.hop_spot(v, r, Vector2(r.x, r.y) + Vector2(1.5, 0.0).rotated(float(n) * 0.9), n)
		if not hp.is_empty():
			return hp
	return {}


func test_hop() -> void:
	print("== 아이·아기: 사방치기 — 집 가까운 트인 땅에 칸을 긋고, 한 아이씩 깨금발로 갔다가 돌아옴")
	var v := _village(10.0)
	var c0 := _open_centre(v)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 1.8 + 0.4 * i, c0.x + 0.2 * i, c0.y))
	var hp := _hop_place(v, kids[0])
	check(not hp.is_empty(), "칸을 그을 자리가 있음")
	if hp.is_empty():
		return
	var c: Vector2 = hp["c"]
	var dir := int(hp["dir"])
	var benches := ChildPlay.fire_benches(v)
	check(ChildPlay.hop_ok(v, c, dir, benches) and ChildPlay._near_home(v, c, ChildPlay.HOP_HOME_R), "집 가까운 트인 자리")
	check(c.distance_to(Vector2(kids[0].x, kids[0].y)) <= ChildPlay.HOP_WALK, "연 아이가 걸어갈 만한 곳 (%.1f칸)" % c.distance_to(Vector2(kids[0].x, kids[0].y)))
	var from := v.events.serial
	var g := ChildPlay.open_hop(v, kids[0], c, dir, 1)
	g["c1"] = 1.0e9
	_join_all(g, kids)
	var started := _events(v, from, &"kid_play_started")
	check(started.size() == 1 and String(started[0]["v"]["kind"]) == "hop" and kids[0].doing == "사방치기하는 중", "kid_play_started (hop) · 하는 일: %s" % kids[0].doing)
	var ax := Vector2(float(g["ax"]), float(g["ay"]))
	check(absf(ax.dot(Vector2(1.0, 1.0))) < 0.001 and is_equal_approx(ax.length(), 1.0), "칸은 화면 가로로 놓임 (기본 방향에서 옆으로 보임)")
	var n_rows: int = ChildPlay.HOP_ROWS.size()
	var bad_place := 0
	for st_i in 2 * n_rows + 1:
		var q := ChildPlay.hop_station(g, st_i)
		bad_place += int(v.water_at(q.x, q.y) or _on_building(v, q) or ChildPlay._story_hidden(v, q, benches))
	for slot in 4:
		var q := ChildPlay.seat(g, slot)
		bad_place += int(v.water_at(q.x, q.y) or _on_building(v, q) or ChildPlay._story_hidden(v, q, benches))
		check(q.distance_to(ChildPlay.hop_station(g, 0)) < 1.6 and (q - c).dot(ax) < -ChildPlay.HOP_CELL * float(n_rows) * 0.5, "기다리는 자리 %d: 첫 칸 쪽 곁" % slot)
	check(bad_place == 0, "칸·기다리는 자리 모두 마른 땅 · 건물과 밭 밖 · 가려지지 않음")
	check(ChildPlay.hop_station(g, 0).distance_to(ChildPlay.hop_station(g, 2 * n_rows)) < 0.001, "갔다가 처음 자리로 돌아옴")
	check(ChildPlay.hop_station(g, n_rows).distance_to(ChildPlay.hop_station(g, 0)) > ChildPlay.HOP_CELL * float(n_rows) - 0.2, "끝 칸까지 감 (%.2f칸)" % ChildPlay.hop_station(g, n_rows).distance_to(ChildPlay.hop_station(g, 0)))
	# 한 아이씩 차례로
	var turns: Array = []
	var stages := {}
	var off := 0
	var wait_moved := 0
	var jump := 0.0
	var prev := {}
	for k in 900:
		ChildPlay.step(v, 30.0)
		var t := int(g["turn"])
		if t >= 0 and (turns.is_empty() or int(turns[turns.size() - 1]) != t):
			turns.append(t)
		var at := ChildPlay.hop_at(g, float(g["c"]))
		stages[int(at[0])] = true
		for i in 3:
			var id := int(g["who"][i])
			var sp := ChildPlay.spot(g, i, float(g["c"]))
			off += int(v.water_at(sp.x, sp.y) or _on_building(v, sp))
			if id != t and id != int(g["by"]):
				wait_moved += int(sp.distance_to(ChildPlay.seat(g, int(g["sl"][i]))) > 0.001)
			if prev.has(id):
				jump = maxf(jump, sp.distance_to(prev[id]))
			prev[id] = sp
	var done := _events(v, from, &"kid_hop_done")
	var clean := 0
	var order_ok := true
	for i in done.size():
		clean += int(bool(done[i]["v"]["clean"]))
		order_ok = order_ok and int(done[i]["v"]["n"]) == i + 1 and int(done[i]["who"]) == int(turns[i]) and int(done[i]["v"]["game"]) == int(g["id"])
	check(done.size() >= 6 and order_ok, "판마다 kid_hop_done (%d판 · 번호와 뛴 아이가 맞음)" % done.size())
	check(clean >= 1 and clean < done.size(), "깨끗이 다녀온 판도, 휘청한 판도 있음 (깨끗 %d / %d)" % [clean, done.size()])
	var rot := true
	for i in range(1, turns.size()):
		rot = rot and int(turns[i]) != int(turns[i - 1])
	var seen := {}
	for t: Variant in turns:
		seen[int(t)] = true
	check(rot and seen.size() == 3, "셋이 돌아가며 뜀 (한 번에 한 아이)")
	check(stages.has(0) and stages.has(1) and stages.has(2) and stages.has(3), "첫 칸 앞으로 → 뜀 → 끝에서 돌아섬 (· 가끔 휘청)")
	check(off == 0 and wait_moved == 0, "뛰는 아이는 칸 위에만 · 기다리는 아이는 제 자리")
	check(jump < 0.45, "자리가 튀지 않음 (한 틱 %.2f칸)" % jump)
	check(ChildPlay.hop_secs(0) > ChildPlay.hop_secs(3) and ChildPlay.hop_secs(0) < 2600.0, "한 판은 짧게 (%.1f초)" % (ChildPlay.hop_secs(0) / 288.0))
	# 저장 → 불러옴
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(SaveCodec.digest(SaveCodec.enc(w.kids)) == SaveCodec.digest(SaveCodec.enc(v.kids)), "저장 → 불러옴: 사방치기 상태가 같음")
	var a := v.events.serial
	var b := w.events.serial
	for k in 300:
		ChildPlay.step(v, 30.0)
		ChildPlay.step(w, 30.0)
	var da := _events(v, a, &"kid_hop_done")
	var db := _events(w, b, &"kid_hop_done")
	var same := da.size() == db.size() and da.size() >= 2
	for i in mini(da.size(), db.size()):
		same = same and int(da[i]["who"]) == int(db[i]["who"]) and bool(da[i]["v"]["clean"]) == bool(db[i]["v"]["clean"])
	var gw: Dictionary = ChildPlay.games(w)[0]
	check(same and str(ChildPlay.hop_at(gw, float(gw["c"]))) == str(ChildPlay.hop_at(g, float(g["c"]))), "불러온 마을에서도 같은 아이가 같은 판을 뜀 (%d판)" % da.size())
	# 혼자 남으면 새 판 없음 → 돌탑으로
	var v2 := _village(10.0)
	var solo := _kid(v2, "보리", 2.0, c0.x, c0.y)
	var g2 := ChildPlay.open_hop(v2, solo, c, dir, 1)
	g2["c1"] = 1.0e9
	_join_all(g2, [solo])
	var from2 := v2.events.serial
	for k in int(ChildPlay.TAG_WAIT / 30.0) + 4:
		ChildPlay.step(v2, 30.0)
	check(_events(v2, from2, &"kid_hop_done").is_empty() and String(g2["kind"]) == "stack" and solo.doing == "돌탑을 쌓는 중", "혼자서는 뛰지 않고, 기다리다 돌탑으로 (%s)" % solo.doing)
	# 여는 때: 낮에만 · 해 질 무렵은 저녁 이야기에 비워 둠
	var st := ChildPlay._state(v2)
	var any_day := false
	for n in 60:
		st["last"] = ""
		st["last2"] = ""
		any_day = any_day or ChildPlay._pick_kind(v2, st, n) == "hop"
	_set_hour(v2, 17.2)
	var any_eve := false
	for n in 60:
		st["last"] = ""
		st["last2"] = ""
		any_eve = any_eve or ChildPlay._pick_kind(v2, st, n) in ["hop", "skip"]
	check(any_day and not any_eve, "낮에 고름 · 해 질 무렵엔 사방치기·물수제비를 새로 열지 않음")
	_set_hour(v2, 10.0)
	var again := false
	for n in 60:
		st["last"] = "hop"
		st["last2"] = "tag"
		again = again or ChildPlay._pick_kind(v2, st, n) == "hop"
		st["last"] = "tag"
		st["last2"] = "hop"
		again = again or ChildPlay._pick_kind(v2, st, n) == "hop"
	check(not again, "방금 한 놀이·그 앞 놀이는 다시 고르지 않음 (여러 놀이가 고루 보이게)")
	# 추운 날엔 긋지 않음
	var old := Village.default_created
	Village.default_created = {"year": 2026, "month": 1, "day": 15}
	var cold := _village(10.0)
	Village.default_created = old
	var ck := _kid(cold, "보리", 2.0, c0.x, c0.y)
	var temp := Health.temperature_at(cold, c0.x, c0.y)
	if temp <= ChildPlay.HOP_MIN_TEMP:
		check(_hop_place(cold, ck).is_empty(), "언 땅(%.1f도)엔 칸을 긋지 않음" % temp)
	else:
		print("   (1월 낮 %.1f도 — 얼지 않아 사방치기를 할 수 있음)" % temp)


## 물수제비 자리를 찾음: 모닥불 둘레의 마른 땅에서 → {"p", "c", "d", "len"} · 없으면 {}
func _skip_place(v: Village) -> Dictionary:
	for ring in range(2, 16):
		for k in 16:
			var p := Vector2(v.fire.x, v.fire.y) + Vector2(float(ring), 0.0).rotated(TAU * float(k) / 16.0)
			if not v.water.inside(p.x, p.y, 2.0) or v.water_at(p.x, p.y):
				continue
			var sk := ChildPlay.skip_spot(v, p, 1)
			if not sk.is_empty():
				sk["p"] = p
				return sk
	return {}


func test_skip() -> void:
	print("== 아이·아기: 물수제비 — 호숫가에 서서 한 아이씩 던지고, 돌이 점점 좁게 튀다 가라앉음")
	var v: Village = null
	var sk := {}
	var used := 0
	for seed_v: int in [11, 7, 3, 5, 13]:
		v = _village(10.0, seed_v)
		sk = _skip_place(v)
		used = seed_v
		if not sk.is_empty():
			break
	check(not sk.is_empty(), "호숫가 자리가 있음 (씨앗 %d)" % used)
	if sk.is_empty():
		return
	var p: Vector2 = sk["p"]
	var c: Vector2 = sk["c"]
	var d: Vector2 = sk["d"]
	var benches := ChildPlay.fire_benches(v)
	check(c.distance_to(p) <= ChildPlay.SKIP_NEAR and ChildPlay._dry_line(v, p, c), "가까운 물가 (%.1f칸) · 가는 길이 마른 땅" % c.distance_to(p))
	check(float(sk["len"]) >= ChildPlay.SKIP_LEN_MIN and float(sk["len"]) <= ChildPlay.SKIP_LEN_MAX, "돌이 갈 물길 %.1f칸" % float(sk["len"]))
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 1.8 + 0.4 * i, p.x, p.y))
	var from := v.events.serial
	var g := ChildPlay.open_skip(v, kids[0], c, d, float(sk["len"]), 1)
	g["c1"] = 1.0e9
	_join_all(g, kids)
	check(int(g["cap"]) == 3 and kids[0].doing == "물수제비를 뜨는 중", "셋까지 · 하는 일: %s" % kids[0].doing)
	var dry := true
	for slot in 3:
		var q := ChildPlay.seat(g, slot)
		dry = dry and not v.water_at(q.x, q.y) and ChildPlay._dry(v, q, ChildPlay.SKIP_DRY) and not _on_building(v, q) and not ChildPlay._story_hidden(v, q, benches)
		dry = dry and v.water_at(q.x + d.x * ChildPlay.SKIP_FIRST, q.y + d.y * ChildPlay.SKIP_FIRST)
	check(dry, "세 자리 모두 물가의 마른 땅 (물에서 %.2f칸 넘게) · 가려지지 않음 · 바로 앞이 물" % ChildPlay.SKIP_DRY)
	var extra := _kid(v, "다래", 2.2, p.x, p.y)
	ChildPlay.try_play(v, extra, p, 900.0)
	check(ChildPlay.idx(g, extra.id) < 0 and (g["who"] as Array).size() == 3, "넷째는 끼지 않음")
	for gg: Dictionary in ChildPlay.games(v).duplicate():      # 넷째가 따로 연 놀이가 있으면 치움 (아래는 물수제비만 봄)
		if int(gg["id"]) != int(g["id"]):
			ChildPlay.games(v).erase(gg)
	extra.steps.clear()
	# 돌이 닿는 곳: 모두 호수 위 · 간격이 점점 좁아짐
	var touch_ok := true
	var gaps_ok := true
	for i in 3:
		g["turn"] = int(g["who"][i])
		var o := ChildPlay.skip_from(g)
		for h in range(2, 6):
			g["h"] = h
			var tc := ChildPlay.skip_touches(g)
			touch_ok = touch_ok and tc.size() == h and float(tc[tc.size() - 1][0]) <= float(g["len"]) + 0.001
			for k in tc.size():
				var q := o + d * float(tc[k][0])
				touch_ok = touch_ok and v.water_at(q.x, q.y) and v.water.is_lake(v.water.idx(q.x, q.y))
				if k >= 2:
					gaps_ok = gaps_ok and float(tc[k][0]) - float(tc[k - 1][0]) < float(tc[k - 1][0]) - float(tc[k - 2][0]) \
						and float(tc[k][1]) - float(tc[k - 1][1]) < float(tc[k - 1][1]) - float(tc[k - 2][1])
				if k >= 1:
					gaps_ok = gaps_ok and float(tc[k][0]) - float(tc[k - 1][0]) >= 0.2
	check(touch_ok, "돌이 닿는 곳은 모두 호수 위 (2~5번 · 물길 안)")
	check(gaps_ok, "튈수록 간격·사이가 좁아짐 (그래도 고리가 겹치지 않을 만큼)")
	g["turn"] = -1
	g["h"] = 0
	# 차례로 던짐
	var turns: Array = []
	var moved := 0
	var wet := 0
	var states := {}
	var back := 0
	var last_d := 0.0
	var last_n := 0
	for k in 700:
		ChildPlay.step(v, 30.0)
		var t := int(g["turn"])
		if t >= 0 and (turns.is_empty() or int(turns[turns.size() - 1]) != t):
			turns.append(t)
		var stn := ChildPlay.skip_stone(g, float(g["c"]))
		states[int(stn[0])] = true
		if int(g["tags"]) == last_n and int(stn[0]) >= 1:
			back += int(float(stn[1]) < last_d - 0.001)
		last_d = float(stn[1]) if int(stn[0]) >= 1 else 0.0
		last_n = int(g["tags"])
		for i in 3:
			var sp := ChildPlay.spot(g, i, float(g["c"]))
			moved += int(sp.distance_to(ChildPlay.seat(g, int(g["sl"][i]))) > 0.001)
			wet += int(v.water_at(sp.x, sp.y))
	var thrown := _events(v, from, &"kid_skip_thrown")
	var ev_ok := true
	var far := 0
	for i in thrown.size():
		var n_sk := int(thrown[i]["v"]["skips"])
		ev_ok = ev_ok and n_sk >= 2 and n_sk <= 5 and int(thrown[i]["v"]["n"]) == i + 1 and int(thrown[i]["who"]) == int(turns[i])
		far += int(n_sk >= ChildPlay.SKIP_FAR)
	check(thrown.size() >= 6 and ev_ok, "던질 때마다 kid_skip_thrown (%d번 · 2~5번 튐 · 던진 아이가 맞음)" % thrown.size())
	check(far >= 1 and far < thrown.size(), "멀리 튄 돌도, 금방 가라앉은 돌도 있음 (멀리 %d / %d)" % [far, thrown.size()])
	var seen := {}
	for t: Variant in turns:
		seen[int(t)] = true
	check(seen.size() == 3, "셋이 돌아가며 던짐")
	check(moved == 0 and wet == 0, "아이들은 물가 제 자리에서 움직이지 않음 (물에 들어가지 않음)")
	check(states.has(0) and states.has(1) and states.has(2) and back == 0, "돌: 손 → 날아감 → 가라앉음 (뒤로 가지 않음)")
	# 저장 → 불러옴
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(SaveCodec.digest(SaveCodec.enc(w.kids)) == SaveCodec.digest(SaveCodec.enc(v.kids)), "저장 → 불러옴: 물수제비 상태가 같음")
	var a := v.events.serial
	var b := w.events.serial
	for k in 300:
		ChildPlay.step(v, 30.0)
		ChildPlay.step(w, 30.0)
	var ta := _events(v, a, &"kid_skip_thrown")
	var tb := _events(w, b, &"kid_skip_thrown")
	var same := ta.size() == tb.size() and ta.size() >= 2
	for i in mini(ta.size(), tb.size()):
		same = same and int(ta[i]["who"]) == int(tb[i]["who"]) and int(ta[i]["v"]["skips"]) == int(tb[i]["v"]["skips"])
	check(same, "불러온 마을에서도 같은 아이가 같은 돌을 던짐 (%d번)" % ta.size())
	# 물 건너편 아이는 끼지 않음 (물을 건너 걸어오지 않게)
	var over := Vector2.ZERO
	var found := false
	var x := float(sk["len"])
	while x < ChildPlay.JOIN_R - 0.5 and not found:
		var q := c + d * x
		if v.water.inside(q.x, q.y, 1.0) and not v.water_at(q.x, q.y):
			over = q
			found = true
		x += 0.25
	if found:
		(g["who"] as Array).size()
		ChildPlay._remove(g, 2)                  # 한 자리를 비움
		var other := _kid(v, "가람", 2.0, over.x, over.y)
		ChildPlay.try_play(v, other, over, 900.0)
		check(ChildPlay.idx(g, other.id) < 0 and (g["who"] as Array).size() == 2, "물 건너편 아이는 (자리가 비어도) 끼지 않음")
		var near := _kid(v, "나래", 2.0, p.x, p.y)
		ChildPlay.try_play(v, near, p, 900.0)
		check(ChildPlay.idx(g, near.id) >= 0, "같은 쪽 아이는 낌")
	else:
		print("   (이 호수는 건너편이 멀어 '물 건너편 아이'는 보지 않음)")
	# 혼자서도 던짐
	var v2 := _village(10.0, used)
	var solo := _kid(v2, "보리", 2.0, p.x, p.y)
	var g2 := ChildPlay.open_skip(v2, solo, c, d, float(sk["len"]), 1)
	g2["c1"] = 1.0e9
	_join_all(g2, [solo])
	var from2 := v2.events.serial
	for k in 200:
		ChildPlay.step(v2, 30.0)
	check(_events(v2, from2, &"kid_skip_thrown").size() >= 2, "혼자서도 던짐")
	# 늦은 낮엔 새로 열지 않음 · 겨울엔 물가에 가지 않음
	var st := ChildPlay._state(v2)
	var day := false
	for n in 60:
		st["last"] = ""
		st["last2"] = ""
		day = day or ChildPlay._pick_kind(v2, st, n) == "skip"
	_set_hour(v2, 15.5)
	var late := false
	for n in 60:
		st["last"] = ""
		st["last2"] = ""
		late = late or ChildPlay._pick_kind(v2, st, n) == "skip"
	check(day and not late, "낮에 고름 · 늦은 낮엔 물수제비를 새로 열지 않음 (저녁 이야기 전에 돌아오게)")
	var old := Village.default_created
	Village.default_created = {"year": 2026, "month": 1, "day": 15}
	var cold := _village(10.0, used)
	Village.default_created = old
	var cst := ChildPlay._state(cold)
	var win := false
	for n in 60:
		cst["last"] = ""
		cst["last2"] = ""
		win = win or ChildPlay._pick_kind(cold, cst, n) == "skip"
	check(Health.season_of(int(Health.jar_date(cold)["month"])) == "겨울" and not win and ChildPlay.skip_spot(cold, p, 1).is_empty(), "겨울엔 물수제비 없음 (물가가 얼 때)")


## 저녁 이야기 자리의 사람(이야기하는 어르신 · 듣는 아이)은 지나가던 이웃이 불러 세우지 않는다 (Social._can_stop — 놀이 중인 아이와 같은 규칙).
## 만남(사이 값)은 그대로 · 이야기는 이어짐 · 이야기가 끝나면 같은 둘이 다시 멈춰 설 수 있다
func test_story_no_stop() -> void:
	print("== 아이·아기: 이야기 자리 — 지나가던 이웃이 어르신을 불러 세우지 않음 (만남은 그대로) · 끝나면 다시 멈춰 섬")
	var v := _village(19.3)
	var e := Vector2(v.fire.x + 1.4, v.fire.y + 1.4)
	for a: float in [0.785, 0.2, 1.4, -0.4, 2.0, -1.0, 2.6, 3.4, 4.2, 5.0]:
		var q := Vector2(v.fire.x, v.fire.y) + Vector2(cos(a), sin(a)) * 2.0
		if ChildPlay.story_side(v, q) != 0:
			e = q
			break
	var nb: Resident = null                    # 지나가던 어른 이웃 · 또 다른 어른
	var nb2: Resident = null
	for r in v.people:
		if r.is_adult() and not r.is_elder():
			if nb == null:
				nb = r
			elif nb2 == null:
				nb2 = r
	var el := _elder(v, e.x, e.y)
	var kids: Array = []
	for i in 3:
		kids.append(_kid(v, ["보리", "새별", "한솔"][i], 1.5 + 0.3 * i, e.x + 2.0 + 0.3 * i, e.y + 1.0))
	for r: Resident in [nb, nb2]:
		r.x = e.x - 0.9
		r.y = e.y - 0.5 - 0.4 * float(r == nb2)
		r.sleeping = false
		r.action = "rest"
		r.anim = "idle"
		r.steps = [ResidentAI.act(3000.0, "idle")]
	check(Social._can_stop(v, el, nb) and Social._can_stop(v, nb, nb2), "이야기 전: 어르신과 이웃은 멈춰 설 수 있음")
	check(ChildPlay.try_play(v, kids[0], e + Vector2(3.0, 1.0), 900.0), "아이가 이야기를 들으러 감")
	ChildPlay.try_play(v, kids[1], e + Vector2(3.0, 1.0), 900.0)
	var gs := ChildPlay.games(v)
	check(gs.size() == 1 and String(gs[0]["kind"]) == "story" and int(gs[0]["el"]) == el.id, "이야기 자리가 열림")
	if gs.size() != 1:
		return
	var g: Dictionary = gs[0]
	var k0: Resident = kids[0]                 # 첫 아이는 앉고, 둘째는 아직 오는 길
	var s0 := ChildPlay.seat(g, int(g["sl"][ChildPlay.idx(g, k0.id)]))
	k0.x = s0.x
	k0.y = s0.y
	while not k0.steps.is_empty() and String(k0.steps[0]["k"]) != "do": k0.steps.remove_at(0)
	for i in 3:
		ChildPlay.step(v, ChildPlay.IV)
	check(int(g["go"]) == 1 and ChildPlay.story_seated(v, el.id), "이야기가 흐름")
	check(not Social._can_stop(v, el, nb) and not Social._can_stop(v, nb, el), "이야기하는 어르신 + 지나가던 이웃: 멈춰 세우지 않음 (누가 먼저든)")
	check(not Social._can_stop(v, k0, nb) and not Social._can_stop(v, nb, kids[1]), "듣는 아이 · 들으러 오는 아이도")
	check(Social._can_stop(v, nb, nb2), "이야기 자리 밖의 둘은 그대로 멈춰 설 수 있음")
	# 만남 자체는 그대로 (사이 값) — 걸음을 끼우지 않고 말 장면도 없음
	var sig := _elder_sig(el)
	var nb_sig := "%d|%s" % [nb.steps.size(), nb.doing]
	var n_ev := v.social_events.size()
	var from := v.events.serial
	Social.meet(v, el, nb, Social._can_stop(v, el, nb))
	var busy: Dictionary = v.social.get("busy", {})
	check(is_equal_approx(float(Social.rec(v, el.id, nb.id, false).get("met", -1.0)), v.t), "만남(사이 값)은 그대로 적힘")
	check(_elder_sig(el) == sig and nb_sig == "%d|%s" % [nb.steps.size(), nb.doing] and not busy.has(str(el.id)) and not busy.has(str(nb.id))
		and v.social_events.size() == n_ev and _events(v, from, &"talk_started").is_empty(), "멈춰 서는 걸음 · 말 장면 · talk_started 없음 (어르신은 앉은 그대로)")
	for i in 3:
		ChildPlay.step(v, ChildPlay.IV)
	check(ChildPlay.games(v).size() == 1 and ChildPlay._story_on(v, g) and ChildPlay.story_seated(v, k0.id), "이야기는 이어짐")
	# 이야기가 끝남 (어르신이 일어났다 다시 앉음) → 같은 둘이 다시 멈춰 설 수 있다
	el.steps = [ResidentAI.walk(e.x + 0.2, e.y)]
	ChildPlay.step(v, ChildPlay.IV)
	check(ChildPlay.games(v).is_empty() and not ChildPlay.in_story(v, el.id), "어르신이 일어나면 이야기 끝")
	el.steps = [ResidentAI.act(3000.0, "sit")]
	check(Social._can_stop(v, el, nb), "이야기가 끝난 뒤: 같은 둘이 멈춰 설 수 있음")
	from = v.events.serial
	var ev2 := Social.meet(v, el, nb, Social._can_stop(v, el, nb))
	busy = v.social.get("busy", {})
	check(not ev2.is_empty() and busy.has(str(el.id)) and busy.has(str(nb.id)) and _events(v, from, &"talk_started").size() == 1,
		"… 그리고 실제로 멈춰 서서 이야기함 (talk_started)")


func test_story_arc() -> void:
	print("== 아이·아기: 이야기 자리 — 둘·셋만 앉아도 어르신을 반원으로 두름 · 이야기 자리의 사람")
	var ring: Array = ChildPlay.STORY_RING
	var bad := 0
	var n_sub := 0
	for mask in range(1, 1 << ring.size()):
		var free: Array = []
		for i in ring.size():
			if mask & (1 << i):
				free.append(i)
		if free.size() < 2:
			continue
		n_sub += 1
		var out: Array = ChildPlay.story_arc(free)
		if out.size() != mini(free.size(), ChildPlay.MAX_KIDS):
			bad += 1
			continue
		var by_ang: Array = free.duplicate()
		by_ang.sort_custom(func(a: int, b: int) -> bool: return float(ring[a][0]) < float(ring[b][0]))
		for m in range(2, out.size() + 1):       # 앞에서 m명만 앉아도: 그 자리들 사이에 빈 자리가 끼지 않음 (이웃해 앉음)
			var lo := 99
			var hi := -1
			for k in m:
				var at := by_ang.find(out[k])
				lo = mini(lo, at)
				hi = maxi(hi, at)
			bad += int(hi - lo != m - 1)
		if out.size() == 3:                       # 셋: 첫 아이가 가운데, 둘째·셋째가 그 양옆
			var a0 := float(ring[out[0]][0])
			bad += int((float(ring[out[1]][0]) - a0) * (float(ring[out[2]][0]) - a0) >= 0.0)
	check(bad == 0, "열린 자리가 어떻든 (%d가지) 이웃한 자리에 가운데부터 앉음 — 한쪽 끝부터 한 줄로 앉지 않음" % n_sub)
	check(str(ChildPlay.story_arc([0, 1, 2, 3, 4, 5])) == str([0, 1, 2, 3]), "자리가 다 열리면 옛 그대로 (화면 앞 네 자리) %s" % str(ChildPlay.story_arc([0, 1, 2, 3, 4, 5])))
	check(int(ChildPlay.story_arc([1, 3, 5])[0]) == 3 and int(ChildPlay.story_arc([0, 2, 4])[0]) == 2, "한쪽만 열려도 그 가운데부터 %s · %s" % [str(ChildPlay.story_arc([1, 3, 5])), str(ChildPlay.story_arc([0, 2, 4]))])
	# 이야기 자리의 사람
	var v := _village(17.5)
	var c := _open_centre(v)
	var el := _elder(v, c.x, c.y)
	var kids: Array = [_kid(v, "보리", 2.0, c.x + 0.5, c.y + 0.5), _kid(v, "새별", 2.4, c.x + 0.6, c.y + 0.4)]
	check(ChildPlay.story_side(v, c) != 0, "어르신 둘레에 앉을 곳이 있음")
	if ChildPlay.story_side(v, c) != 0:
		var g := ChildPlay.open_story(v, kids[0], el, 1)
		var i0 := ChildPlay._add(g, kids[0].id)
		ChildPlay._add(g, kids[1].id)
		check(not ChildPlay.story_seated(v, el.id) and not ChildPlay.story_seated(v, kids[0].id), "아직 아무도 앉기 전: 이야기 자리의 사람 아님")
		g["go"] = 1
		g["on"][i0] = 1
		check(ChildPlay.story_seated(v, el.id) and ChildPlay.story_seated(v, kids[0].id), "이야기가 흐르면 어르신·앉은 아이")
		check(not ChildPlay.story_seated(v, kids[1].id) and not ChildPlay.story_seated(v, v.people[0].id), "오는 길인 아이·다른 주민은 아님")
