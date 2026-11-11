## 자람의 보상 — 고비·별명·잔치·수첩 도장·영구 장식 (docs/PROGRESSION.md 4.5 · ROADMAP Q9 첫 묶음, sim/milestones.gd).
## tests/run.gd가 부름 (`-- milestone`).
extends RefCounted

var run: SceneTree
var quick := false
const H := 3600.0
const D := 86400.0
const BAD_WORDS := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점", "거인", "하늘의 분", "기도", "제단"]
const NUMBER_WORDS := ["열둘", "스물", "열두", "스무"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== Q9 자람의 보상 (고비 · 별명 · 잔치 · 수첩 도장 · 장식)")
	run.timed(self, ["test_new_jar", "test_bread", "test_far", "test_population", "test_same_day", "test_winter", "test_late_night", "test_save",
		"test_old_save", "test_away", "test_unwatched_same", "test_words", "test_notebook", "test_card", "test_decor", "test_sign_siting",
		"test_feast_skip", "test_balance_consts", "test_tool_isolated", "test_no_statics"])


func _world(seed_v := 5) -> JarWorld:
	return JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))


## 병 날짜를 month/day의 hour시로 (지금 v.t 기준)
func _set_date(v: Village, month: int, day: int, hour := 12.0) -> void:
	v.created_date = {"year": 2026, "month": month, "day": day}
	v.start_clock = hour * H - v.t


## 새 병: 첫 걸음에 바탕을 적고(넘은 고비 없음), 초여름 아침 hour시로 맞춘다
func _fresh(seed_v := 5, hour := 10.0) -> Village:
	var v := _world(seed_v).primary()
	v.chief_off = true
	v.advance(2.0)
	_set_date(v, 6, 10, hour)
	return v


func _count(v: Village, kind: StringName, from := 0) -> int:
	var n := 0
	for e: Dictionary in v.events.since(from):
		if e["kind"] == kind:
			n += 1
	return n


func _last(v: Village, kind: StringName) -> Dictionary:
	var out := {}
	for e: Dictionary in v.events.since(0):
		if e["kind"] == kind:
			out = e
	return out


func _lines(v: Village, part: String) -> int:
	var n := 0
	for b: Dictionary in v.book:
		if String(b["text"]).contains(part):
			n += 1
	return n


func _clean(text: String) -> bool:
	for w: String in BAD_WORDS + NUMBER_WORDS:
		if text.contains(w):
			return false
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 48 and c <= 57:
			return false
	return true


func _festive(v: Village) -> int:
	var n := 0
	for p in v.people:
		if p.action == "festival":
			n += 1
	return n


## 첫 빵을 구운 것으로 (사건 + 통계 — Village._finish_work가 하는 일)
func _bake(v: Village, r: Resident) -> void:
	v.emit(&"first_bread", {"who": r.id, "v": {"b": -1}})
	v.stats["first_bread"] = 1


func _grow_to(v: Village, n: int, born := true) -> Resident:
	var last: Resident = null
	var mom: Resident = null
	var dad: Resident = null
	for p in v.people:
		if p.is_adult() and p.sex == "f" and mom == null:
			mom = p
		if p.is_adult() and p.sex == "m" and dad == null:
			dad = p
	var i := 0
	while v.people.size() < n:
		i += 1
		if born and v.people.size() == n - 1:
			last = v.add_person("막내%d" % i, "f", 0.0, "", v.fire.x + 1.0, v.fire.y + 1.0, mom, dad)
			last.parents = PackedInt32Array([mom.id, dad.id])
		else:
			last = v.add_person("새식구%d" % i, "m" if i % 2 == 0 else "f", 8.0, "", v.fire.x + 1.0 + 0.1 * i, v.fire.y - 1.0, null, null)
	return last


func test_new_jar() -> void:
	var v := _fresh()
	check(v.milestones.has("v") and Milestones.count(v) == 0, "새 병: 넘은 고비 없음 (%d)" % Milestones.count(v))
	check(Milestones.next_line(v) == "첫 빵을 구우면 잔치가 열려요", "다음 고비 한 줄 = 첫 빵 (%s)" % Milestones.next_line(v))
	check(_count(v, &"milestone") == 0 and _count(v, &"feast") == 0, "사건 없음")
	var none := true
	for p in v.people:
		none = none and p.nickname == ""
	check(none, "별명 없음")


func test_bread() -> void:
	var v := _fresh()
	var r: Resident = v.people[1]
	_bake(v, r)
	v.advance(2.0)
	check(Milestones.is_passed(v, "bread") and _count(v, &"milestone") == 1, "첫 빵: 고비 사건 한 번")
	var e := _last(v, &"milestone")
	check(int(e["who"]) == r.id and String((e["v"] as Dictionary)["id"]) == "bread", "사건: 누가(빵을 구운 사람)·어느 고비")
	check(r.nickname == "첫 빵을 구운" and Milestones.title_of(r) == "첫 빵을 구운 " + r.name, "별명: %s" % Milestones.title_of(r))
	check(_lines(v, "'첫 빵을 구운 %s'" % r.name) == 1, "연대기 한 줄에 별명")
	check(not Milestones.feast_on(v) and _count(v, &"feast") == 0, "낮에는 아직 잔치가 아니다")
	v.advance(8.5 * H + 300.0)                       # 18:35
	check(Milestones.feast_on(v) and Milestones.feast_id(v) == "bread" and _count(v, &"feast") == 1, "그날 저녁 잔치 (병 시각 %.1f)" % v.hour_now())
	var n := _festive(v)
	var able := 0
	for p in v.people:
		if not p.is_baby() and p.sick_left <= 0.0:
			able += 1
	check(n >= able - 1 and n >= 2, "마을이 모닥불로 모인다 (%d / %d명)" % [n, able])
	check(_lines(v, "작은 잔치가 열렸다") == 1, "잔치 연대기 한 줄")
	v.advance(1.0 * H)                               # 19:35 — 모닥불 둘레에
	var near := 0
	for p in v.people:
		if p.action == "festival" and Vector2(p.x, p.y).distance_to(v.fire) < 4.0:
			near += 1
	check(near >= n - 1, "잔치 중엔 모닥불 둘레 (%d / %d명)" % [near, n])
	v.advance(2.0 * H)                               # 21:35
	check(not Milestones.feast_on(v), "병의 한 저녁 뒤 잔치가 끝난다")
	var still := 0
	for p in v.people:
		if p.action == "festival" and p.doing == Milestones.FEAST_DOING and not p.steps.is_empty():
			still += 1
	check(still == 0, "잔치가 끝나면 늦게 닿은 사람도 제 일로 돌아간다 (남은 %d명)" % still)
	v.advance(1.0 * D)
	check(_count(v, &"milestone") == 1 and _count(v, &"feast") == 1 and _lines(v, "잔치가 열렸다") == 1, "다음 날 다시 열리지 않는다 (병마다 한 번)")
	check(Milestones.next_line(v) == "식구가 열둘이 되면 잔치가 열려요", "다음 고비 한 줄 = 식구 열둘 (%s)" % Milestones.next_line(v))


## 모닥불에서 아주 먼 사람(안개 너머를 살피는 중 등)은 잔치에 부르지 않는다 — 저녁 안에 못 온다
func test_far() -> void:
	var v := _fresh(21)
	_bake(v, v.people[1])
	v.advance(8.0 * H + 1200.0)                      # 18:20
	var far: Resident = v.people[2]
	ResidentAI.cancel(v, far)
	far.x = v.fire.x + Milestones.FEAST_REACH + 8.0
	far.y = v.fire.y
	far.steps.append(ResidentAI.act(2.0 * H, "idle"))
	v.advance(900.0)                                 # 18:35
	check(Milestones.feast_on(v), "잔치가 열렸다 (병 시각 %.1f)" % v.hour_now())
	check(far.doing != Milestones.FEAST_DOING, "먼 곳에 있는 사람은 부르지 않는다 (%s)" % far.doing)
	check(_festive(v) >= 2, "가까이 있는 사람들은 모인다 (%d명)" % _festive(v))


func test_population() -> void:
	var v := _fresh(6)
	var baby := _grow_to(v, 12, true)
	v.advance(2.0)
	check(Milestones.is_passed(v, "pop12") and not Milestones.is_passed(v, "pop20"), "식구 열둘 (%d명)" % v.people.size())
	var mom := v.person(baby.parents[0])
	check(mom != null and mom.nickname == "표지판을 세운" and int(_last(v, &"milestone")["who"]) == mom.id, "아기가 열두 번째 → 그 부모(어머니)에게 별명")
	check(baby.nickname == "", "아기에게는 붙지 않는다")
	# 이주민이 스무 번째 → 그 이주민
	var mig := _grow_to(v, 20, false)
	v.advance(2.0)
	check(Milestones.is_passed(v, "pop20") and mig.nickname == "마을을 북적이게 한", "이주민이 스무 번째 → 그 사람에게 별명 (%s)" % Milestones.title_of(mig))
	check(_count(v, &"milestone") == 2, "고비 사건 둘")
	# 별명은 한 사람에 하나
	var v2 := _fresh(6)
	var b2 := _grow_to(v2, 12, true)
	var m2 := v2.person(b2.parents[0])
	m2.nickname = "첫 빵을 구운"
	v2.advance(2.0)
	var d2 := v2.person(b2.parents[1])
	check(m2.nickname == "첫 빵을 구운" and d2.nickname == "표지판을 세운", "이미 별명이 있으면 다음 사람(아버지)에게")


func test_same_day() -> void:
	var v := _fresh(7)
	_grow_to(v, 20, false)
	v.stock["빵"] = 9000.0                             # 사흘 동안 굶지 않게 (스무 식구 — 한 사람이 병 15분에 하나)
	_bake(v, v.people[0])
	v.advance(2.0)
	check(Milestones.count(v) == 3 and (v.milestones["feasts"] as Array).size() == 3, "같은 날 고비 셋 (빵·열둘·스물)")
	v.advance(8.5 * H + 300.0)
	check(Milestones.feast_id(v) == "pop20" and _count(v, &"feast") == 1, "그날 저녁 잔치는 하나 — 큰 쪽 (%s)" % Milestones.feast_id(v))
	v.advance(4.0 * H)
	check(_count(v, &"feast") == 1, "같은 날 밤에 또 열리지 않는다")
	v.advance(20.0 * H)
	check(Milestones.feast_id(v) == "pop12" and _count(v, &"feast") == 2, "다음 날 저녁: 그다음 큰 쪽 (%s)" % Milestones.feast_id(v))
	v.advance(24.0 * H)
	check(Milestones.feast_id(v) == "bread" and _count(v, &"feast") == 3 and (v.milestones["feasts"] as Array).is_empty(), "그다음 날 저녁: 마지막 (%s)" % Milestones.feast_id(v))


func test_winter() -> void:
	var v := _fresh()
	_set_date(v, 2, 8)                                # 늦겨울에 넉넉히 남음
	var chief := v.chief()
	for d in 30:
		v.t += D
		Milestones.step(v, 0.0)
		if Milestones.is_passed(v, "winter"):
			break
	var date := Health.jar_date(v)
	check(Milestones.is_passed(v, "winter") and int(date["month"]) == 3 and int(date["day"]) == 1, "겨울을 지내고 봄의 첫날에 (%d월 %d일)" % [int(date["month"]), int(date["day"])])
	check(chief != null and chief.nickname == "첫 겨울을 지켜 낸", "가장 나이 많은 어른에게 별명")
	check(_lines(v, "첫 겨울을 넘겼다") == 1, "연대기 한 줄")
	# 겨울 끝자락에 시작한 병은 다음 겨울에
	var v2 := _fresh()
	_set_date(v2, 2, 22)
	for d in 40:
		v2.t += D
		Milestones.step(v2, 0.0)
	check(not Milestones.is_passed(v2, "winter"), "겨울을 며칠만 지낸 병은 아직 (겨울 %d일)" % int(v2.milestones.get("winter", 0)))
	# 초여름에 시작한 병: 가을까지 아무 일 없음
	var v3 := _fresh()
	for d in 150:
		v3.t += D
		Milestones.step(v3, 0.0)
	check(not Milestones.is_passed(v3, "winter"), "겨울이 오기 전에는 넘지 않는다")


func test_late_night() -> void:
	var v := _fresh(5, 21.0)                          # 밤 9시에 넘은 고비
	_bake(v, v.people[0])
	v.advance(3.0 * H)
	check(Milestones.is_passed(v, "bread") and _count(v, &"feast") == 0, "늦은 밤에 넘으면 그날은 잔치가 없다")
	v.advance(19.0 * H)                               # 다음 날 19:00
	check(_count(v, &"feast") == 1 and Milestones.feast_on(v), "다음 날 저녁에 열린다 (병 시각 %.1f)" % v.hour_now())


func test_save() -> void:
	var jw := _world(8)
	var v := jw.primary()
	v.chief_off = true
	v.advance(2.0)
	_set_date(v, 6, 10, 10.0)
	var r: Resident = v.people[0]
	_bake(v, r)
	v.advance(2.0)
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	var jw2 := JarWorld.from_dict(d)
	var v2 := jw2.primary()
	check(SaveCodec.digest(jw.to_dict()) == SaveCodec.digest(jw2.to_dict()), "왕복: 저장 → 불러오기 지문이 같다")
	check(Milestones.is_passed(v2, "bread") and v2.person(r.id).nickname == "첫 빵을 구운", "넘은 고비·별명이 저장된다")
	var n0 := v2.events.serial
	v2.advance(9.0 * H)
	check(_count(v2, &"milestone", n0) == 0, "불러온 뒤 같은 고비를 다시 알리지 않는다")
	check(_count(v2, &"feast", n0) == 1 and Milestones.feast_on(v2), "기다리던 잔치는 불러온 뒤 그날 저녁에")


func _strip(x: Variant) -> void:
	if x is Dictionary:
		var d: Dictionary = x
		d.erase("milestones")
		d.erase("nickname")
		for k: Variant in d:
			_strip(d[k])
	elif x is Array:
		for e: Variant in x:
			_strip(e)


func test_old_save() -> void:
	var jw := _world(9)
	var v := jw.primary()
	v.chief_off = true
	v.advance(2.0)
	_set_date(v, 6, 10, 10.0)
	_grow_to(v, 13, false)
	v.stats["first_bread"] = 1
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	_strip(d)                                          # 옛 저장: 고비 기록·별명이 없다
	var jw2 := JarWorld.from_dict(d)
	var v2 := jw2.primary()
	check(v2.milestones.is_empty(), "옛 저장에는 고비 기록이 없다")
	var n0 := v2.events.serial
	var book0 := v2.book.size()
	v2.advance(34.0 * H)
	check(Milestones.is_passed(v2, "bread") and Milestones.is_passed(v2, "pop12") and not Milestones.is_passed(v2, "pop20"), "이미 넘은 고비는 넘은 것으로")
	check(_count(v2, &"milestone", n0) == 0 and _count(v2, &"feast", n0) == 0, "조용히 — 사건·잔치 없음")
	var quiet := true
	for p in v2.people:
		quiet = quiet and p.nickname == ""
	var said := 0
	for i in range(book0, v2.book.size()):
		if String(v2.book[i]["text"]).contains("잔치") or String(v2.book[i]["text"]).contains("부른다"):
			said += 1
	check(quiet and said == 0, "별명·연대기 줄도 없음")
	check(Milestones.next_line(v2) == "첫 겨울을 넘기면 봄맞이 잔치가 열려요", "다음 고비 한 줄은 남은 것부터 (%s)" % Milestones.next_line(v2))
	# 옛 저장에서 한 해 넘게 산 마을: 첫 겨울도 넘은 것으로
	var jw3 := _world(9)
	var v3 := jw3.primary()
	v3.t = 400.0 * D
	Milestones.step(v3, 0.0)
	check(Milestones.is_passed(v3, "winter") and bool(((v3.milestones["passed"] as Dictionary)["winter"] as Dictionary)["silent"]), "한 해 넘게 산 옛 마을: 첫 겨울은 조용히 넘은 것으로")


func test_away() -> void:
	var v := _fresh(10)
	var r: Resident = v.people[0]
	_bake(v, r)
	var c := CatchUp.new(v, 12.0 * Balance.HOUR, 12.0 * Balance.HOUR)
	c.run()
	c.finish()
	check(Milestones.is_passed(v, "bread") and r.nickname == "첫 빵을 구운", "비운 동안 넘은 고비: 기록·별명은 남는다")
	check(_lines(v, "'첫 빵을 구운 %s'" % r.name) == 1, "연대기 줄도 남는다")
	var f: Dictionary = v.milestones["feast"]
	check(String(f.get("id", "")) == "bread" and float(f.get("until", 0.0)) < v.t and not Milestones.feast_on(v), "잔치는 비운 동안 지나갔다 (지난 일)")
	check((v.milestones["feasts"] as Array).is_empty(), "돌아와서 다시 열릴 잔치가 없다")
	var n0 := v.events.serial
	v.advance(1.0 * D)
	check(_count(v, &"feast", n0) == 0 and _count(v, &"milestone", n0) == 0, "돌아온 뒤 다시 틀지 않는다")


## 지켜보든 말든 같은 결과 (ADR-0001)
func test_unwatched_same() -> void:
	var a := _fresh(11)
	var b := _fresh(11)
	b.watching = false
	_bake(a, a.people[0])
	_bake(b, b.people[0])
	a.advance(12.0 * H)
	b.advance(12.0 * H)
	check(a.milestones == b.milestones and not (a.milestones["feast"] as Dictionary).is_empty(), "지켜보든 말든 같은 고비 기록·같은 잔치 시각")
	check(_count(a, &"feast") == 1 and _count(b, &"feast") == 1, "잔치 사건도 같다")


func test_words() -> void:
	var ok := true
	var bad := ""
	var texts: Array = []
	for id: String in Milestones.ORDER:
		texts.append(String(Milestones.NICK[id]))
		texts.append(String(Milestones.FEAST_LINE[id]))
		for t: String in Milestones.LINE[id]:
			texts.append(t)
	for t: String in texts:
		if not _clean(t):
			ok = false
			bad = t
	check(ok and texts.size() == 16, "주민 쪽 글(별명·연대기)에 금지어·숫자 없음 (%s)" % bad)
	var all_ids := true
	for id: String in Milestones.ORDER:
		all_ids = all_ids and Milestones.LABEL.has(id) and Milestones.NEXT.has(id) and Milestones.NICK.has(id) and Milestones.LINE.has(id) and Milestones.FEAST_LINE.has(id)
	check(all_ids, "고비 넷 모두 도장 이름·다음 줄·별명·연대기·잔치 줄")
	# 깨닫기 전에도 같은 글 (거인을 모르는 말만)
	var keep := Village.start_aware
	Village.start_aware = false
	var v := _fresh(12)
	Village.start_aware = keep
	_bake(v, v.people[0])
	v.advance(10.0 * H)
	var clean := true
	for b: Dictionary in v.book:
		var t := String(b["text"])
		if t.contains("부른다") or t.contains("잔치"):
			clean = clean and _clean(t)
	check(not v.aware and _count(v, &"feast") == 1 and clean, "깨닫기 전 마을: 잔치가 열리고 글이 깨끗하다")


func test_notebook() -> void:
	var v := _fresh(13)
	var st := MilestoneStamps.make(v)
	run.root.add_child(st)
	var passed := func(n: Node) -> int:
		var c := 0
		for cell in n.get_node("Row").get_children():
			if cell.get_child(0).get("passed"):
				c += 1
		return c
	check(st.get_node("Row").get_child_count() == 4 and passed.call(st) == 0, "도장 자리 넷, 찍힌 것 없음")
	check((st.get_node("Next") as Label).text == "첫 빵을 구우면 잔치가 열려요", "다음 고비 한 줄")
	st.queue_free()
	_bake(v, v.people[0])
	v.advance(2.0)
	# 연대기 책: 도장 띠는 제목과 탭 사이 — 어느 탭에서나 보인다 (2026-11-11 사용자 결정, 옛 자리 = '창세 신화' 탭 맨 아래)
	var sh := ChronicleSheet.new()
	run.root.add_child(sh)
	sh.setup(v, null)
	var on_all := true
	var in_body := false
	for t in sh.tab_btns.size():
		sh.open(t)
		var ms := sh.strip.find_child("MilestoneStamps", true, false)
		on_all = on_all and sh.strip.visible and ms != null and ms.get_node("Row").get_child_count() == 4 and passed.call(ms) == 1 \
			and (ms.get_node("Next") as Label).text == "식구가 열둘이 되면 잔치가 열려요"
		in_body = in_body or sh.body.find_child("MilestoneStamps", true, false) != null
	check(sh.tab_btns.size() >= 3 and on_all, "도장 띠: 탭 %d개 어디서나 — 자리 넷 · 첫 빵 도장 하나 · 다음 고비 한 줄" % sh.tab_btns.size())
	check(not in_body, "탭 안(수첩 장 아래)에는 도장 줄이 더 없다")
	check(sh.strip.get_parent() == sh.tab_btns[0].get_parent().get_parent() and sh.strip.get_index() < sh.tab_btns[0].get_parent().get_index(),
		"도장 띠는 탭 줄 위에 있다")
	sh.open(0)
	_grow_to(v, 12, false)
	v.advance(2.0)
	sh._refresh()
	var ms2 := sh.strip.find_child("MilestoneStamps", true, false)
	check(ms2 != null and passed.call(ms2) == 2 and sh.strip.get_child_count() == 1, "도장이 늘면 띠를 다시 그린다 (다른 탭을 보고 있어도)")
	check(ms2 != null and (ms2.get_node("Next") as Label).text == Milestones.next_line(v), "띠의 다음 고비 한 줄도 바뀐다 (%s)" % Milestones.next_line(v))
	sh.queue_free()


func test_card() -> void:
	var v := _fresh(14)
	var r: Resident = v.people[0]
	var d := ResidentDetail.new()
	run.root.add_child(d)
	d.setup(v)
	d.open(r)
	check(not d.nick_l.visible, "별명이 없으면 줄이 안 보인다")
	_bake(v, r)
	v.advance(2.0)
	d._refresh()
	check(d.nick_l.visible and d.nick_l.text == "첫 빵을 구운" and d.name_l.text == r.name, "주민 카드: 이름 위에 별명 (%s %s)" % [d.nick_l.text, d.name_l.text])
	d.queue_free()


func test_decor() -> void:
	var v := _fresh(15)
	var oven := v.add_building("화덕", v.fire.x + 3.0, v.fire.y + 1.5, true)
	check(MilestoneView.wanted(v).is_empty(), "고비 전: 장식 없음")
	_bake(v, v.people[0])
	_grow_to(v, 12, false)
	v.advance(2.0)
	var w := MilestoneView.wanted(v)
	check(w.has("bread") and w.has("pop12") and w.size() == 2, "첫 빵 → 빵 간판, 식구 열둘 → 마을 표지판 (%s)" % str(w.keys()))
	var a: Vector2 = w["bread"]
	var b: Vector2 = w["pop12"]
	check(a.distance_to(b) > 1.0 and b.distance_to(v.fire) > 2.0, "두 장식이 겹치지 않고, 표지판은 마을 가장자리")
	check(a.distance_to(Vector2(oven.x, oven.y)) < 3.0 and a.distance_to(Vector2(oven.x, oven.y)) > oven.size(), "빵 간판은 화덕 바로 앞 (%.1f칸)" % a.distance_to(Vector2(oven.x, oven.y)))
	check(Milestones.spot_free(v, b), "표지판 자리는 물·건물·무덤이 아닌 빈 땅")
	check(Milestones.spot_clear(v, b) and _tree_gap(v, b) >= Balance.SIGN_CLEAR_FLOWER and v.path_at(b.x, b.y) < Balance.SIGN_PATH_MIN,
		"표지판 자리는 꽃·길도 피한 깨끗한 땅 (꽃숲 덩이까지 %.1f칸 · 발길 %.1f)" % [_tree_gap(v, b), v.path_at(b.x, b.y)])
	var rec: Dictionary = (v.milestones["passed"] as Dictionary)["pop12"]
	check(rec.has("x") and Vector2(float(rec["x"]), float(rec["y"])).is_equal_approx(b), "표지판 자리는 고비를 넘을 때 적어 둔 곳 (다시 불러와도 그 자리)")
	v.add_building("오두막", b.x, b.y, true)             # 나중에 그 자리에 건물이 서면 옆 빈자리로
	var b2: Vector2 = MilestoneView.wanted(v)["pop12"]
	check(b2.distance_to(b) > 1.0 and Milestones.spot_free(v, b2), "그 자리에 건물이 서면 표지판은 옆 빈자리로")
	var d0 := SaveCodec.digest(v.to_dict())
	MilestoneView.wanted(v)
	check(d0 == SaveCodec.digest(v.to_dict()), "장식 자리 셈은 시뮬레이션을 바꾸지 않는다")
	for id: String in MilestoneView.TEX:
		check(ResourceLoader.exists(String(MilestoneView.TEX[id])), "장식 그림 있음: %s" % id)


func _tree_gap(v: Village, p: Vector2) -> float:
	var best := 1.0e9
	for tr: Dictionary in v.trees:
		best = minf(best, Vector2(float(tr["x"]), float(tr["y"])).distance_to(p))
	return best


## 그 칸에 발길을 남김 (사람들이 지나다닌 것처럼 — Village._path_add가 하는 일)
func _tread(v: Village, x: float, y: float, amt: float) -> void:
	var gx := floori((x - v.center.x + v.path_r) / (2.0 * v.path_r) * v.path_n)
	var gy := floori((y - v.center.y + v.path_r) / (2.0 * v.path_r) * v.path_n)
	if gx >= 0 and gy >= 0 and gx < v.path_n and gy < v.path_n:
		v.paths[gy * v.path_n + gx] = maxf(v.paths[gy * v.path_n + gx], amt)


## 표지판 자리 (Q9 2차): 꽃·길·건물·무덤을 피하고, 같은 마을이면 늘 같은 자리 (난수 없음), 셈이 시뮬레이션을 바꾸지 않는다
func test_sign_siting() -> void:
	var clean := 0
	var same := 0
	var seeds := [15, 16, 17, 18, 19, 20]
	for sd: int in seeds:
		var a := _fresh(sd)
		var b := _fresh(sd)
		var pa := Milestones.edge_spot(a)
		same += 1 if pa == Milestones.edge_spot(b) and pa == Milestones.edge_spot(a) else 0
		clean += 1 if Milestones.spot_clear(a, pa) else 0
	check(same == seeds.size(), "같은 마을이면 늘 같은 자리 (%d / %d)" % [same, seeds.size()])
	check(clean == seeds.size(), "새 마을의 어귀 자리는 깨끗하다 — 꽃·바위·길·건물·무덤·물이 아님 (%d / %d)" % [clean, seeds.size()])
	# 어려운 경우: 맨 처음 고를 자리에 꽃숲 덩이 · 그다음 자리에 길 · 그다음 자리에 무덤 → 차례로 비켜 간다
	var v := _fresh(15)
	var d0 := SaveCodec.digest(v.to_dict())
	var p0 := Milestones.edge_spot(v)
	check(d0 == SaveCodec.digest(v.to_dict()), "자리 셈은 시뮬레이션을 바꾸지 않는다 (난수·상태)")
	v.trees.append({"x": p0.x + 0.6, "y": p0.y - 0.4, "s": "tree", "g": 0.0, "res": 0})
	var p1 := Milestones.edge_spot(v)
	check(p1 != p0 and _tree_gap(v, p1) >= Balance.SIGN_CLEAR_FLOWER and Milestones.spot_clear(v, p1), "그 자리에 꽃이 피어 있으면 비켜 선다 (꽃까지 %.1f칸)" % _tree_gap(v, p1))
	v.trees[v.trees.size() - 1]["s"] = "stump"
	check(Milestones.edge_spot(v) == p1, "벤 자리(다시 자랄 꽃)도 꽃 자리로 친다 — 자라도 가리지 않게")
	for i in 5:                                       # 사람들이 그 자리를 지나다녀 길이 남
		for j in 5:
			_tread(v, p1.x - 1.0 + 0.5 * float(i), p1.y - 1.0 + 0.5 * float(j), Balance.PATH_AT)
	var p2 := Milestones.edge_spot(v)
	check(p2 != p1 and p2 != p0 and v.path_at(p2.x, p2.y) < Balance.SIGN_PATH_MIN and Milestones.spot_clear(v, p2), "길 위에는 서지 않는다 (발길 %.1f → %.1f)" % [v.path_at(p1.x, p1.y), v.path_at(p2.x, p2.y)])
	v.graves.append({"id": -1, "name": "옛사람", "x": p2.x + 0.3, "y": p2.y, "t": v.t, "yard": false, "yard_id": -1})
	var p3 := Milestones.edge_spot(v)
	check(p3 != p2 and Milestones.spot_clear(v, p3), "무덤 곁에도 서지 않는다")
	var house := v.add_building("오두막", p3.x, p3.y, true)
	var p4 := Milestones.edge_spot(v)
	check(p4.distance_to(Vector2(house.x, house.y)) >= house.size() + Balance.SIGN_CLEAR_BUILDING and Milestones.spot_clear(v, p4), "건물에서도 떨어져 선다")
	# 고비를 넘을 때 적는 자리 = 그때의 깨끗한 자리, 그 뒤에 꽃이 자라거나 길이 나도 옮기지 않는다 (왔다 갔다 하지 않게 — 화면이 꽃을 낮춘다)
	_grow_to(v, 12, false)
	v.advance(2.0)
	var rec: Dictionary = (v.milestones["passed"] as Dictionary)["pop12"]
	var at := Vector2(float(rec["x"]), float(rec["y"]))
	check(Milestones.spot_clear(v, at), "고비를 넘을 때 적는 자리가 깨끗한 자리")
	v.trees.append({"x": at.x + 0.8, "y": at.y + 0.8, "s": "sapling", "g": 0.0, "res": 0})
	check((MilestoneView.wanted(v)["pop12"] as Vector2).is_equal_approx(at), "나중에 곁에 꽃이 자라도 표지판은 그 자리 (화면이 꽃 그림을 낮춘다)")
	# 빈 땅이 전혀 없으면(둘레가 온통 꽃) 그래도 설 수 있는 자리 하나는 고른다
	var w := _fresh(16)
	for i in 60:
		for j in 60:
			w.trees.append({"x": w.fire.x - 30.0 + float(i), "y": w.fire.y - 30.0 + float(j), "s": "tree", "g": 0.0, "res": 0})
	var pw := Milestones.edge_spot(w)
	check(Milestones.spot_free(w, pw) and pw == Milestones.edge_spot(w), "온통 꽃밭이어도 설 수 있는 자리를 고른다 (늘 같은 곳)")


## 큰 시간 건너뛰기 바로 뒤 (Q9 2차): 화면을 한 번 맞추면(VillageView.sync force — 돌아왔을 때·빠른 흐름이 끝날 때 장면이 부르는 것)
## 잔치 몸짓과 표지판 자리가 그 화면부터 맞는다 — 다음 0.5초 점검을 기다리지 않는다. 화면이 하는 일은 시뮬레이션을 바꾸지 않는다.
func test_feast_skip() -> void:
	var old_cut := CutoutResident.override
	CutoutResident.override = 1                       # 종이 인형 주민 (게임의 기본 — 춤 몸짓은 인형에 얹는다)
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var mv := MilestoneView.of(vw)
	v.water.offline = true
	v.chief_off = true
	v.advance(2.0)
	_set_date(v, 6, 10, 10.0)
	_bake(v, v.people[0])
	_grow_to(v, 12, false)
	v.stock["빵"] = float(v.stock.get("빵", 0.0)) + 600.0
	v.advance(2.0)
	vw.sync(0.0, true)
	check(Milestones.count(v) == 2 and mv.dancers() == 0 and not Milestones.feast_on(v), "아침: 고비 둘, 아직 잔치가 아니다")
	check(vw.sign_spot.is_equal_approx(MilestoneView.wanted(v)["pop12"]) and mv.sign_node("pop12") != null, "표지판 자리를 화면이 안다 (둘레 꽃을 낮추는 데 씀)")
	v.advance(10.3 * H)                               # 아침 → 저녁 잔치 한가운데 (20:18쯤) 한 번에
	var d0 := SaveCodec.digest(v.to_dict())
	vw.fast = false
	vw.sync(0.0, true)                                # 화면 한 번 — MilestoneView._process는 아직 한 번도 돌지 않음
	var want := 0
	var placed := 0
	var guests := 0
	for p in v.people:
		if p.action != "festival":
			continue
		guests += 1
		var m := vw.residents.get(p.id) as Node3D
		if m != null and Vector2(m.position.x, m.position.z).distance_to(Vector2(p.x, p.y)) < 0.3:
			placed += 1
		if p.anim == "play" and Vector2(p.x, p.y).distance_to(v.fire) <= MilestoneView.DANCE_R and m != null:
			want += 1
	check(Milestones.feast_on(v) and guests >= 8, "건너뛴 뒤: 잔치 중 (병 시각 %.2f · 손님 %d)" % [v.hour_now(), guests])
	check(placed == guests, "손님 인형이 제자리에 (%d / %d)" % [placed, guests])
	check(want >= 2 and mv.dancers() == want, "춤 몸짓이 그 화면부터 (춤 %d · 화면 %d)" % [want, mv.dancers()])
	check(d0 == SaveCodec.digest(v.to_dict()), "화면 맞추기는 시뮬레이션을 바꾸지 않는다")
	v.advance(1.5 * H)                                # 잔치가 끝난 뒤로 건너뜀
	vw.sync(0.0, true)
	check(not Milestones.feast_on(v) and mv.dancers() == 0, "잔치가 끝난 뒤로 건너뛰면 춤 몸짓도 그 화면에서 풀린다 (%d)" % mv.dancers())
	run.root.remove_child(scene)
	scene.free()
	CutoutResident.override = old_cut


## 조절 값은 data/balance.gd의 Q9 묶음에 (Q9 2차) — sim/milestones.gd의 이름은 그 값을 가리킬 뿐, 값은 옮기기 전과 같다
func test_balance_consts() -> void:
	check(Milestones.POP_SMALL == Balance.MILESTONE_POP_SMALL and Milestones.POP_BIG == Balance.MILESTONE_POP_BIG
		and Milestones.WINTER_MIN_DAYS == Balance.MILESTONE_WINTER_MIN_DAYS, "고비 기준은 balance.gd의 값")
	check(Balance.MILESTONE_POP_SMALL == 12 and Balance.MILESTONE_POP_BIG == 20 and Balance.MILESTONE_WINTER_MIN_DAYS == 14, "고비 기준 값은 그대로 (12 · 20 · 14)")
	check(Milestones.FEAST_HOUR == Balance.FEAST_HOUR and Milestones.FEAST_LATEST == Balance.FEAST_LATEST and Milestones.FEAST_SECS == Balance.FEAST_SECS
		and Milestones.FEAST_EAT == Balance.FEAST_EAT_SECS and Milestones.FEAST_DANCE == Balance.FEAST_DANCE_SECS and Milestones.FEAST_REACH == Balance.FEAST_REACH,
		"잔치 값은 balance.gd의 값")
	check(is_equal_approx(Balance.FEAST_HOUR, 18.5) and is_equal_approx(Balance.FEAST_LATEST, 20.0) and is_equal_approx(Balance.FEAST_SECS, 2.5 * H)
		and is_equal_approx(Balance.FEAST_WALK_SECS, 600.0) and is_equal_approx(Balance.FEAST_EAT_SECS, 1200.0) and is_equal_approx(Balance.FEAST_DANCE_SECS, 1500.0)
		and is_equal_approx(Balance.FEAST_REACH, 24.0) and is_equal_approx(Balance.FEAST_RING_R, 1.6) and is_equal_approx(Balance.FEAST_RING_GROW, 0.35)
		and is_equal_approx(Balance.FEAST_RING_TURN, 2.399), "잔치 값은 그대로")
	var f := FileAccess.open("res://sim/milestones.gd", FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	var stray: Array = []
	for lit: String in ["2.399", "600.0", "1200.0", "1500.0", ":= 12", ":= 20", ":= 14", "18.5", "24.0", "0.35", "2.5 *"]:
		if src.contains(lit):
			stray.append(lit)
	check(src != "" and stray.is_empty(), "sim/milestones.gd에 조절 값 숫자가 남아 있지 않다 (%s)" % str(stray))
	var fb := FileAccess.open("res://data/balance.gd", FileAccess.READ)
	var bal := fb.get_as_text() if fb != null else ""
	var at := bal.find("# Q9")
	check(at > 0 and bal.find("const MILESTONE_POP_SMALL") > at and bal.find("const SIGN_CLEAR_FLOWER") > at and bal.count("const MILESTONE_POP_SMALL") == 1,
		"balance.gd: '# Q9' 묶음 하나에 모여 있다")


## 캡처 도구(tools/shot_milestones.gd)는 진짜 저장·설정·연대기 그림 폴더를 건드리지 않는다 (Q9 2차)
func test_tool_isolated() -> void:
	var f := FileAccess.open("res://tools/shot_milestones.gd", FileAccess.READ)
	var src := f.get_as_text() if f != null else ""
	var need := ["sm.enabled = false", "sm.dir = SAVE_DIR", "GameSettings.path = SAVE_DIR", "StoreStrip.cfg_path = SAVE_DIR", "Inquiry.id_path = SAVE_DIR",
		"scene.firsts = Firsts.new()", "scene.director.pic_dir = SAVE_DIR"]
	var missing: Array = []
	for n: String in need:
		if not src.contains(n):
			missing.append(n)
	check(src != "" and missing.is_empty(), "캡처 도구가 저장·설정·안내 대기 줄·그림 카드 폴더를 제 것으로 돌린다 (%s)" % str(missing))
	check(not src.contains("SaveManager.player"), "캡처 도구가 거인 묶음(진짜 저장에 실리는 것)을 건드리지 않는다")
	check(src.contains("const SAVE_DIR := \"user://shot_milestones_save\""), "제 폴더는 user://shot_milestones_save")
	var fd := FileAccess.open("res://view/stage_director.gd", FileAccess.READ)
	var dsrc := fd.get_as_text() if fd != null else ""
	check(StageDirector.PIC_DIR == "user://chron_pics" and dsrc.contains("var pic_dir := PIC_DIR") and dsrc.count("PIC_DIR") == 2,
		"연출의 그림 카드 폴더: 기본은 그대로 user://chron_pics, 쓰는 곳은 pic_dir만 (도구가 돌려 쓸 수 있게)")


func test_no_statics() -> void:
	for path: String in ["res://sim/milestones.gd", "res://view/milestone_view.gd", "res://view/ui/milestone_stamps.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		var src := f.get_as_text() if f != null else ""
		check(src != "" and not src.contains("static var"), "%s에 static var 없음 (ADR-0001 d)" % path.get_file())
	var f2 := FileAccess.open("res://sim/milestones.gd", FileAccess.READ)
	var s2 := f2.get_as_text() if f2 != null else ""
	check(not s2.contains("watching"), "시뮬레이션은 보는지 여부를 읽지 않음")
