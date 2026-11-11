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
		"test_feast_skip", "test_balance_consts", "test_tool_isolated", "test_no_statics",
		"test_steps", "test_steps_gather", "test_steps_wait", "test_grown", "test_old_save_born", "test_strip_seven", "test_sign_near", "test_clap_view",
		"test_green", "test_green_old_save", "test_green_nick", "test_sheaf"])


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
	check(Milestones.next_line(v) == String(Milestones.NEXT["steps"]), "다음 고비 한 줄 = 첫걸음마 (%s)" % Milestones.next_line(v))


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
	check(not Milestones.is_passed(v2, "steps") and not Milestones.is_passed(v2, "grown") and Milestones.next_line(v2) == String(Milestones.NEXT["steps"]),
		"다음 고비 한 줄은 남은 것부터 — 마을에서 난 아이가 없던 옛 저장은 첫걸음마부터 (%s)" % Milestones.next_line(v2))
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
		if Milestones.FEAST_LINE.has(id):
			texts.append(String(Milestones.FEAST_LINE[id]))
		for t: String in Milestones.LINE[id]:
			texts.append(t)
	for t: String in Milestones.STEPS_ALONE_LINE + Milestones.GREEN_LINE_FIELD + Milestones.GREEN_LINE_FIRE:
		texts.append(t)
	texts.append(Milestones.CLAP_DOING)
	texts.append(Milestones.PARENT_DOING)
	for t: String in MilestoneView.CLAP_SAY:
		texts.append(t)
	for t: String in texts:
		if not _clean(t):
			ok = false
			bad = t
	check(ok and texts.size() == 39, "주민 쪽 글(별명·연대기·하는 일·말풍선)에 금지어·숫자 없음 (%d줄 · %s)" % [texts.size(), bad])
	var all_ids := true
	for id: String in Milestones.ORDER:
		all_ids = all_ids and Milestones.LABEL.has(id) and Milestones.NEXT.has(id) and Milestones.NICK.has(id) and Milestones.LINE.has(id) \
			and Milestones.FEAST_LINE.has(id) == Milestones.FEAST_RANK.has(id)
	check(all_ids and Milestones.ORDER.size() == 7 and not Milestones.FEAST_RANK.has("steps"), "고비 일곱 모두 도장 이름·다음 줄·별명·연대기, 잔치가 있는 고비는 잔치 줄 (첫걸음마는 잔치 없음)")
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
	check(st.get_node("Row").get_child_count() == 7 and passed.call(st) == 0, "도장 자리 일곱, 찍힌 것 없음")
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
		on_all = on_all and sh.strip.visible and ms != null and ms.get_node("Row").get_child_count() == 7 and passed.call(ms) == 1 \
			and (ms.get_node("Next") as Label).text == String(Milestones.NEXT["steps"])
		in_body = in_body or sh.body.find_child("MilestoneStamps", true, false) != null
	check(sh.tab_btns.size() >= 3 and on_all, "도장 띠: 탭 %d개 어디서나 — 자리 일곱 · 첫 빵 도장 하나 · 다음 고비 한 줄" % sh.tab_btns.size())
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


# ───────────────────────── Q9 ⑦ — 고비 둘 더 (첫걸음마 · 마을에서 난 첫 어른) ─────────────────────────
## 병이 days일 된 마을 (마을에서 난 사람의 태어난 때가 병이 생긴 뒤가 되게) — 바탕을 적고 초여름 아침 hour시로
func _aged(seed_v: int, days := 40.0, hour := 9.0) -> Village:
	var v := _world(seed_v).primary()
	v.chief_off = true
	v.t = days * D
	v.advance(2.0)
	_set_date(v, 6, 10, hour)
	return v


## 이 마을에서 난 사람 (나이 age 일생 날 — 태어난 때를 그 나이에 맞춘다: 어린 동안 병 AGE_K일에 하루, 어른은 AGE_K_ADULT일에 하루).
## count = 출생 수도 올림 (마을이 갓난 아기를 적어 두는 길 — Village._give_birth가 하는 일)
func _born(v: Village, nm: String, age: float, count := false) -> Resident:
	var mom: Resident = null
	var dad: Resident = null
	for p in v.people:
		if p.is_adult() and p.sex == "f" and mom == null:
			mom = p
		if p.is_adult() and p.sex == "m" and dad == null:
			dad = p
	var c := v.add_person(nm, "f", age, "", v.fire.x + 1.0, v.fire.y + 1.0, mom, dad)
	c.parents = PackedInt32Array([mom.id, dad.id])
	c.home = mom.home
	var days := age * Balance.AGE_K if age < Balance.AGE_ADULT else Balance.AGE_ADULT * Balance.AGE_K + (age - Balance.AGE_ADULT) * Balance.AGE_K_ADULT
	c.born_t = v.t - days * D
	if count:
		v.stats["born"] = int(v.stats.get("born", 0)) + 1
	return c


func _rec(v: Village, id: String) -> Dictionary:
	return (v.milestones.get("passed", {}) as Dictionary).get(id, {})


## 고비 사건 가운데 그 id의 것 수
func _ms_count(v: Village, id: String, from := 0) -> int:
	var n := 0
	for e: Dictionary in v.events.since(from):
		if e["kind"] == &"milestone" and String((e["v"] as Dictionary)["id"]) == id:
			n += 1
	return n


## 첫걸음마: 병에서 처음 한 번 — 이웃을 부르고(잠깐 미룸) 걸음을 뗀 바로 그때. 잔치 없음, 부모에게 별명, 바람개비 자리 기록
func test_steps() -> void:
	var v := _aged(21)
	var baby := _born(v, "아람", ChildPlay.TODDLE_AGE + 0.004)
	var mom := v.person(baby.parents[0])
	var dad := v.person(baby.parents[1])
	var n0 := v.events.serial
	var waited := 0
	while not v.milestones.has("steps_call") and waited < 60:      # 아기를 보는 사람의 손이 날 때까지 조금 기다릴 수 있다
		v.advance(ChildPlay.CARE_IV)
		waited += 1
	check(v.milestones.has("steps_call") and int((v.milestones["steps_call"] as Dictionary)["baby"]) == baby.id, "걸음마 나이가 되면 먼저 이웃을 부른다 (%d번째 살핌)" % waited)
	check(_count(v, &"first_steps", n0) == 0 and not Milestones.is_passed(v, "steps"), "부르는 동안 아기는 아직 걷지 않는다 (고비 전)")
	var at := float((v.milestones.get("steps_call", {"at": v.t}) as Dictionary)["at"])
	var last := float((v.milestones.get("steps_call", {"last": v.t}) as Dictionary).get("last", v.t))
	check(at - v.t >= Balance.STEPS_GATHER_SECS - 0.5 and at <= last + 0.5 and is_equal_approx(last - v.t, Balance.STEPS_GATHER_MAX),
		"걸음은 가장 먼 이웃이 걸어올 만큼 뒤 — STEPS_GATHER_SECS ~ STEPS_GATHER_MAX (%.0f초 · 마감 %.0f초)" % [at - v.t, last - v.t])
	v.advance(at - v.t - 5.0)
	check(_count(v, &"first_steps", n0) == 0, "그때까지는 떼지 않는다")
	var stood := 0
	while not Milestones.is_passed(v, "steps") and v.t < last + ChildPlay.CARE_IV * 2.0 + 5.0:      # 이웃 둘이 와 설 때까지 (길어도 마감까지) 기다린다
		stood = Milestones.clappers(v, baby.id)
		v.advance(ChildPlay.CARE_IV * 0.5)
	check(_count(v, &"first_steps", n0) == 1 and Milestones.is_passed(v, "steps") and _ms_count(v, "steps", n0) == 1, "걸음을 뗀 바로 그때 고비 (first_steps %d · 고비 %d)" % [
		_count(v, &"first_steps", n0), _ms_count(v, "steps", n0)])
	check(int(_rec(v, "steps").get("n", 0)) >= Balance.STEPS_CLAP_MIN or float(_rec(v, "steps").get("t", 0.0)) >= last,
		"이웃 둘이 와 서면 걸음을 뗀다 — 모자라면 마감까지 기다린 뒤 (온 이웃 %d · 걸음 전 %d)" % [int(_rec(v, "steps").get("n", 0)), stood])
	var e := _last(v, &"milestone")
	var rec := _rec(v, "steps")
	check(not e.is_empty() and int((e["v"] as Dictionary)["feast_day"]) == -1 and (v.milestones["feasts"] as Array).is_empty(), "잔치는 없다 (feast_day −1 · 기다리는 잔치 없음)")
	check(not e.is_empty() and (e["at"] as Vector2).is_equal_approx(ChildPlay.door(v, baby)), "사건 자리 = 그 집 문 앞")
	check(not v.milestones.has("steps_call"), "부름 기록은 치운다")
	check(mom.nickname == "바람개비를 단" and dad.nickname == "" and baby.nickname == "" and int(rec.get("who", -1)) == mom.id, "별명은 아기의 부모 한 사람에게 (어머니 먼저 — %s)" % Milestones.title_of(mom))
	check(rec.has("b") and rec.has("x") and rec.has("y") and int(rec.get("baby", -1)) == baby.id and rec.has("n"), "바람개비 자리(집·문 앞)와 온 이웃 수를 적어 둔다 (%s)" % str(rec))
	check(_lines(v, "바람개비") == 1 and _lines(v, "'바람개비를 단 %s'" % mom.name) == 1, "연대기 한 줄 (바람개비 · 별명)")
	check((_lines(v, "이웃들이 모여 손뼉을 쳤다") == 1) == (int(rec.get("n", 0)) > 0), "손뼉 이야기는 이웃이 왔을 때만 (온 이웃 %d)" % int(rec.get("n", 0)))
	var w := MilestoneView.wanted(v)
	var hm := v.bld(baby.home)
	var base := Vector2(hm.x, hm.y + hm.size() * 0.5) if hm != null else Vector2(float(rec["x"]), float(rec["y"]))
	check(w.has("steps") and (w["steps"] as Vector2).distance_to(base) < 2.0, "바람개비는 그 집 문 앞 (%.1f칸)" % (w.get("steps", Vector2.INF) as Vector2).distance_to(base))
	# 둘째 아기: 미루지 않고 바로, 고비는 다시 없다
	var b2 := _born(v, "도담", ChildPlay.TODDLE_AGE + 0.004)
	v.advance(ChildPlay.CARE_IV * 2.0)
	check(_count(v, &"first_steps", n0) == 2 and _ms_count(v, "steps", n0) == 1 and not v.milestones.has("steps_call"), "둘째 아기는 바로 걷고, 고비는 한 번뿐 (%d)" % _count(v, &"first_steps", n0))
	check(b2.nickname == "" and dad.nickname != String(Milestones.NICK["steps"]), "별명도 다시 붙지 않는다")
	v.stock["빵"] = 900.0
	v.advance(11.0 * H)
	var steps_feast := 0                              # (아기 둘이 늘어 식구 열둘 잔치는 열릴 수 있다 — 첫걸음마의 잔치만 없으면 된다)
	for fe: Dictionary in v.events.since(n0):
		if fe["kind"] == &"feast" and String((fe["v"] as Dictionary)["id"]) == "steps":
			steps_feast += 1
	check(steps_feast == 0 and v.hour_now() > Milestones.FEAST_HOUR, "첫걸음마로는 그날 저녁 잔치가 열리지 않는다 (병 시각 %.1f)" % v.hour_now())
	# 부모 둘 다 이미 별명이 있으면: 고비는 넘되 별명은 없다 (한 사람에 하나)
	var v2 := _aged(21)
	var c2 := _born(v2, "새별", ChildPlay.TODDLE_AGE + 0.004)
	v2.person(c2.parents[0]).nickname = "첫 빵을 구운"
	v2.person(c2.parents[1]).nickname = "표지판을 세운"
	v2.advance(Balance.STEPS_GATHER_MAX + 4.0 * H)
	check(Milestones.is_passed(v2, "steps") and String(_rec(v2, "steps").get("nick", "x")) == "" and v2.person(c2.parents[0]).nickname == "첫 빵을 구운"
		and v2.person(c2.parents[1]).nickname == "표지판을 세운", "부모 둘 다 별명이 있으면 별명 없이 넘는다")
	# 지켜보든 말든 같다
	var a := _aged(21)
	var b := _aged(21)
	b.watching = false
	_born(a, "아람", ChildPlay.TODDLE_AGE + 0.004)
	_born(b, "아람", ChildPlay.TODDLE_AGE + 0.004)
	a.advance(Balance.STEPS_GATHER_MAX + 2.0 * H)
	b.advance(Balance.STEPS_GATHER_MAX + 2.0 * H)
	check(Milestones.is_passed(a, "steps") and a.milestones == b.milestones, "지켜보든 말든 같은 때·같은 기록")


## 이웃 부르기: 문 가까이에서 쉬는 사람만, 많아야 STEPS_CLAP_MAX, 걸음에 표시("ms")가 남고 저장된다
func test_steps_gather() -> void:
	var v := _aged(22)
	var baby := _born(v, "아람", ChildPlay.TODDLE_AGE + 0.004)
	var d := ChildPlay.door(v, baby)
	var near: Array = []
	var far: Resident = null
	var busy: Resident = null
	for p in v.people:                                # 처음 온 어른들은 짐을 든 것으로 (부르지 않는다) — 이웃은 새로 놓는다
		if p.is_adult() and not p.id in baby.parents:
			p.carry = "통나무"
	var names := ["다래", "솔이", "가람", "누리", "보람", "한결", "이슬"]
	for i in names.size():
		var p := v.add_person(names[i], "f" if i % 2 == 0 else "m", 20.0 + float(i), "", d.x, d.y, null, null)
		p.steps.clear()
		p.action = "idle"
		p.anim = "idle"
		p.carry = ""
		if near.size() < 5:
			near.append(p)
			p.x = d.x + 2.8 + 0.3 * float(near.size())
			p.y = d.y + 2.0 - 0.5 * float(near.size())
		elif far == null:
			far = p
			p.x = d.x + Balance.STEPS_CLAP_R + 4.0
			p.y = d.y
		else:
			busy = p
			p.x = d.x + 2.0
			p.y = d.y + 1.0
			p.carry = "통나무"
	var worker := v.add_person("마루", "m", 22.0, "", d.x + 1.5, d.y + 1.0, null, null)     # 문 바로 곁에서 일하던 사람 — 쉬던 이웃이 넉넉하면 부르지 않는다
	worker.steps.clear()
	worker.action = "work"
	worker.anim = "work"
	var when := Milestones._gather(v, baby, null)
	check(worker.doing != Milestones.CLAP_DOING and worker.action == "work", "쉬던 이웃이 넉넉하면 일하던 사람은 그대로 둔다")
	check(is_equal_approx(when, v.t + Balance.STEPS_GATHER_SECS) and is_equal_approx(float((v.milestones["steps_call"] as Dictionary)["at"]), when),
		"가까운 이웃뿐이면 걸음은 STEPS_GATHER_SECS 뒤 (%.0f초)" % (when - v.t))
	var called: Array = []
	var marked := true
	var spots := {}
	for p in v.people:
		if p.doing != Milestones.CLAP_DOING:
			continue
		called.append(p)
		var last: Dictionary = p.steps[p.steps.size() - 1] if not p.steps.is_empty() else {}
		for st: Dictionary in p.steps:
			if String(st.get("k", "")) == "do":
				marked = marked and int(st.get("ms", -1)) == baby.id
		marked = marked and p.steps.size() == 3 and String((p.steps[0] as Dictionary)["k"]) == "walk" and bool((p.steps[0] as Dictionary).get("rt", false)) \
			and String((p.steps[1] as Dictionary).get("anim", "")) == "idle" and String(last.get("anim", last.get("a", "play"))) == "play"
		var w0: Dictionary = p.steps[0]
		spots["%.2f,%.2f" % [float(w0["x"]), float(w0["y"])]] = true
	check(near.size() == 5 and called.size() == Balance.STEPS_CLAP_MAX, "가까이에서 쉬는 다섯 가운데 넷만 부른다 (%d)" % called.size())
	check(marked and spots.size() == called.size(), "부른 이웃: 곧장 걸어와 서서 기다리다 손뼉 — 걸음에 아기 표시, 자리는 서로 다르다 (%d자리)" % spots.size())
	check(far != null and far.doing != Milestones.CLAP_DOING and busy != null and busy.doing != Milestones.CLAP_DOING, "먼 사람·짐 든 사람은 부르지 않는다")
	check(Milestones.clappers(v, baby.id) == 0, "걸어오는 중인 사람은 아직 세지 않는다")
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	var kept := 0
	for p: Resident in called:
		var q := w.person(p.id)
		for st: Dictionary in q.steps:
			if int(st.get("ms", -1)) == baby.id:
				kept += 1
				break
	check(kept == called.size() and (w.milestones.get("steps_call", {}) as Dictionary).get("baby", -1) == baby.id, "저장 → 불러오기: 걸음 표시와 부름 기록이 남는다 (%d)" % kept)
	v.advance(Balance.STEPS_GATHER_SECS - 30.0)
	var stood := Milestones.clappers(v, baby.id)
	check(not Milestones.is_passed(v, "steps"), "이웃이 일찍 와 서도 어림한 때까지는 기다린다")
	v.advance(ChildPlay.CARE_IV * 2.0 + 30.0)
	var rec := _rec(v, "steps")
	check(Milestones.is_passed(v, "steps") and int(rec.get("n", 0)) >= 2 and stood >= 2, "부른 이웃이 문 앞에 와 서 있다가 본다 (걸음 전 %d · 걸음 때 %d)" % [stood, int(rec.get("n", 0))])
	check(_lines(v, "이웃들이 모여 손뼉을 쳤다") == 1, "연대기: 이웃들이 모여 손뼉을 쳤다")
	v.advance(Balance.STEPS_CLAP_SECS + 600.0)
	var left := 0
	for p: Resident in called:
		left += 1 if p.doing == Milestones.CLAP_DOING else 0
	check(left == 0 and Milestones.clappers(v, baby.id) == 0, "손뼉이 끝나면 하던 일로 돌아간다 (%d)" % left)
	# 쉬던 이웃이 없으면: 문 가까이에서 일하던 어른이 하던 일을 내려놓고 온다 (자는 사람·밥 먹는 사람·짐 든 사람·아이는 그대로)
	var q := _aged(22)
	var b2 := _born(q, "도담", ChildPlay.TODDLE_AGE + 0.004)
	var d2 := ChildPlay.door(q, b2)
	for p in q.people:
		if p.id != b2.id:
			p.carry = "통나무"
	var kinds := ["work", "work", "build", "eat", "sleep", "haul"]
	var folk: Array = []
	for i in kinds.size():
		var p := q.add_person(names[i], "f" if i % 2 == 0 else "m", 8.0 + 6.0 * float(i % 3), "", d2.x + 2.0 + 0.3 * float(i), d2.y + 1.5, null, null)       # 어른 둘에 어르신 하나씩
		p.steps = [ResidentAI.act(4000.0, "work")]
		p.action = String(kinds[i])
		p.anim = "work" if i < 3 else ("eat" if i == 3 else "idle")
		p.sleeping = String(kinds[i]) == "sleep"
		p.carry = "통나무" if String(kinds[i]) == "haul" else ""
		folk.append(p)
	var kid := q.add_person("한울", "m", 2.0, "", d2.x + 1.5, d2.y + 2.0, null, null)
	kid.steps = [ResidentAI.act(4000.0, "work")]
	kid.action = "work"
	var s0 := q.rng.state
	Milestones._gather(q, b2, null)
	var came := 0
	var kept2 := 0
	for i in folk.size():
		var p: Resident = folk[i]
		if i < 3:
			came += 1 if p.doing == Milestones.CLAP_DOING and p.action == "idle" and p.steps.size() == 3 and String((p.steps[0] as Dictionary)["k"]) == "walk" else 0
		else:
			kept2 += 1 if p.doing != Milestones.CLAP_DOING and p.action == String(kinds[i]) and p.steps.size() == 1 else 0
	check(came == 3 and kept2 == 3 and kid.doing != Milestones.CLAP_DOING, "쉬던 이웃이 없으면 일하던 어른이 온다 — 밥·잠·짐·아이는 그대로 (온 %d · 그대로 %d)" % [came, kept2])
	check(q.rng.state == s0, "이웃을 부르는 데 난수를 쓰지 않는다")


## 마을에서 난 첫 아이가 어른이 됨: 그 아이가 어른이 된 바로 그때 한 번 — 작은 저녁 잔치, 그 젊은이에게 별명, 기둥 자리 기록
func test_grown() -> void:
	var v := _aged(23)
	v.stock["빵"] = 900.0
	var kit_kid: Resident = null
	for p in v.people:
		if p.is_child() and not p.is_baby():
			kit_kid = p
			break
	var n0 := v.events.serial
	if kit_kid != null:
		kit_kid.age = Balance.AGE_ADULT + 0.01
	v.advance(2.0)
	check(kit_kid != null and not Milestones.is_passed(v, "grown"), "처음 온 아이가 어른이 되는 것은 고비가 아니다")
	var kid := _born(v, "보리", 0.0, true)
	v.advance(2.0)
	check((v.milestones["kids"] as Array).has(kid.id), "갓난 아기를 적어 둔다 (%s)" % str(v.milestones["kids"]))
	kid.age = Balance.AGE_ADULT - 0.02
	v.advance(60.0)
	check(not Milestones.is_passed(v, "grown"), "아직 어른이 아니면 넘지 않는다")
	kid.age = Balance.AGE_ADULT + 0.001
	v.advance(2.0)
	var rec := _rec(v, "grown")
	check(Milestones.is_passed(v, "grown") and _ms_count(v, "grown", n0) == 1 and int(rec.get("who", -1)) == kid.id, "어른이 된 바로 그때 고비")
	check(kid.nickname == "마을이 키운 첫 어른" and Milestones.title_of(kid) == "마을이 키운 첫 어른 보리", "그 젊은이에게 별명 (%s)" % Milestones.title_of(kid))
	check(_lines(v, "이 마을에서 나고 자란 보리가 어른이 되었다") == 1 and _lines(v, "'마을이 키운 첫 어른 보리'라 부른다") == 1, "연대기 한 줄")
	var at := Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0)))
	check(rec.has("x") and Milestones.post_ok(v, at) and at.distance_to(v.fire) <= float(Balance.POST_RINGS[Balance.POST_RINGS.size() - 1]) + 0.01 and at.distance_to(v.fire) >= float(Balance.POST_RINGS[0]) - 0.01,
		"기둥 자리 = 모닥불 곁 빈자리 (%.1f칸)" % at.distance_to(v.fire))
	var w := MilestoneView.wanted(v)
	check(w.has("grown") and (w["grown"] as Vector2).is_equal_approx(at) and at == Milestones.post_spot(v), "화면은 적어 둔 자리에 세운다 (같은 마을이면 늘 같은 자리)")
	var d0 := SaveCodec.digest(v.to_dict())
	MilestoneView.wanted(v)
	Milestones.post_spot(v)
	check(d0 == SaveCodec.digest(v.to_dict()), "장식 자리 셈은 시뮬레이션을 바꾸지 않는다")
	v.add_building("오두막", at.x, at.y, true)
	var at2: Vector2 = MilestoneView.wanted(v)["grown"]
	check(at2.distance_to(at) > 0.5 and Milestones.post_ok(v, at2), "그 자리에 건물이 서면 기둥은 옆 빈자리로")
	# 둘째가 자라도 다시 없다
	var kid2 := _born(v, "새별", 0.0, true)
	v.advance(2.0)
	kid2.age = Balance.AGE_ADULT + 0.001
	v.advance(2.0)
	check(_ms_count(v, "grown", n0) == 1 and kid2.nickname == "", "둘째가 자라도 고비는 한 번뿐")
	# 그날 저녁: 작은 잔치 (같은 잔치, 짧게)
	v.advance(9.6 * H)
	var f: Dictionary = v.milestones["feast"]
	check(_count(v, &"feast", n0) == 1 and Milestones.feast_id(v) == "grown" and Milestones.feast_on(v), "그날 저녁 잔치 (%s · %.2f시)" % [Milestones.feast_id(v), v.hour_now()])
	check(is_equal_approx(float(f.get("until", 0.0)) - float(f.get("t0", 0.0)), Balance.FEAST_SMALL_SECS) and Balance.FEAST_SMALL_SECS < Balance.FEAST_SECS, "작은 잔치는 일찍 끝난다 (%.1f시간)" % ((float(f.get("until", 0.0)) - float(f.get("t0", 0.0))) / H))
	check(_lines(v, "작은 잔치") == 1, "연대기: 작은 잔치 한 줄")
	# 이미 별명이 있는 젊은이: 고비는 넘되 별명은 다른 사람에게 가지 않는다
	var v2 := _aged(23)
	var k2 := _born(v2, "한솔", 0.0, true)
	v2.advance(2.0)
	k2.nickname = "첫 빵을 구운"
	k2.age = Balance.AGE_ADULT + 0.001
	v2.advance(2.0)
	var others := 0
	for p in v2.people:
		others += 1 if p != k2 and p.nickname != "" else 0
	check(Milestones.is_passed(v2, "grown") and k2.nickname == "첫 빵을 구운" and others == 0 and String(_rec(v2, "grown").get("nick", "x")) == "", "이미 별명이 있으면 별명 없이 넘는다")
	# 자라기 전에 죽은 아이는 적어 둔 데서 빠진다
	var v3 := _aged(23)
	var k3 := _born(v3, "누리", 0.0, true)
	v3.advance(2.0)
	k3.dead = true
	v3.advance(2.0)
	check(not (v3.milestones["kids"] as Array).has(k3.id) and not Milestones.is_passed(v3, "grown"), "죽은 아이는 빠진다")


## 저장에서 고비 기록을 고비 넷이던 때("v" 1)로 되돌린다
func _downgrade(x: Variant) -> void:
	if x is Dictionary:
		var d: Dictionary = x
		if d.has("milestones") and d["milestones"] is Dictionary and (d["milestones"] as Dictionary).has("v"):
			var m: Dictionary = d["milestones"]
			m["v"] = 1
			m.erase("kids")
			m.erase("born_n")
			m.erase("steps_call")
			if m.has("passed") and m["passed"] is Dictionary:
				(m["passed"] as Dictionary).erase("steps")
				(m["passed"] as Dictionary).erase("grown")
		for k: Variant in d:
			_downgrade(d[k])
	elif x is Array:
		for e: Variant in x:
			_downgrade(e)


## 옛 저장: 이미 걷는 아이·이미 어른이 된 마을 아이가 있으면 그 고비는 조용히 (사건·별명·잔치·연대기 없음)
func test_old_save_born() -> void:
	# ㄱ. 고비 넷이던 때의 저장 + 마을에서 난 아이(걷는 나이)
	var jw := _world(24)
	var v := jw.primary()
	v.chief_off = true
	v.t = 40.0 * D
	v.advance(2.0)
	_set_date(v, 6, 10, 10.0)
	_bake(v, v.people[0])
	v.advance(2.0)
	var child := _born(v, "보리", 2.0)
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	_downgrade(d)
	var v2 := JarWorld.from_dict(d).primary()
	check(int(v2.milestones.get("v", 0)) == 1 and Milestones.is_passed(v2, "bread") and not v2.milestones.has("kids"), "고비 넷이던 때의 저장")
	var n0 := v2.events.serial
	var book0 := v2.book.size()
	v2.advance(2.0)
	check(int(v2.milestones["v"]) == Milestones.VERSION and Milestones.is_passed(v2, "steps") and bool(_rec(v2, "steps").get("silent", false)), "이미 걷는 마을 아이 → 첫걸음마는 조용히 넘은 것으로")
	check(not Milestones.is_passed(v2, "grown") and (v2.milestones["kids"] as Array).has(child.id), "아직 어린 마을 아이는 적어 둔다 (어른이 되는 날 고비)")
	var nicks := 0
	for p in v2.people:
		nicks += 1 if p.nickname != "" else 0
	check(_count(v2, &"milestone", n0) == 0 and v2.book.size() == book0 and nicks == 1 and (v2.milestones["feasts"] as Array).size() == 1, "조용히 — 사건·연대기·새 별명·새 잔치 없음")
	check(not MilestoneView.wanted(v2).has("steps"), "조용히 넘은 첫걸음마는 바람개비가 없다 (어느 집인지 모른다)")
	check(Milestones.next_line(v2) == String(Milestones.NEXT["pop12"]), "다음 고비 한 줄 (%s)" % Milestones.next_line(v2))
	var c2 := v2.person(child.id)
	c2.age = Balance.AGE_ADULT + 0.001
	v2.advance(2.0)
	check(Milestones.is_passed(v2, "grown") and not bool(_rec(v2, "grown").get("silent", true)) and c2.nickname == "마을이 키운 첫 어른", "그 아이가 자라면 제대로 고비 (옛 저장에서도)")
	# ㄴ. 고비 넷이던 때의 저장 + 마을에서 난 어른
	var jw3 := _world(24)
	var v3 := jw3.primary()
	v3.chief_off = true
	v3.t = 80.0 * D
	v3.advance(2.0)
	_set_date(v3, 6, 10, 10.0)
	var grown := _born(v3, "한솔", Balance.AGE_ADULT + 0.5)
	var d3: Dictionary = bytes_to_var(var_to_bytes(jw3.to_dict()))
	_downgrade(d3)
	var v4 := JarWorld.from_dict(d3).primary()
	var n4 := v4.events.serial
	v4.advance(2.0)
	check(Milestones.is_passed(v4, "steps") and Milestones.is_passed(v4, "grown") and bool(_rec(v4, "grown").get("silent", false)), "이미 어른이 된 마을 아이 → 두 고비 모두 조용히")
	check(_count(v4, &"milestone", n4) == 0 and v4.person(grown.id).nickname == "" and (v4.milestones["feasts"] as Array).is_empty(), "사건·별명·잔치 없음")
	var w4 := MilestoneView.wanted(v4)
	check(w4.has("grown") and not w4.has("steps") and Milestones.post_ok(v4, w4["grown"]), "기둥은 선다 (자리는 찾아서), 바람개비는 없다")
	v4.advance(12.0 * H)
	check(_count(v4, &"milestone", n4) == 0 and _count(v4, &"feast", n4) == 0, "그 뒤로도 다시 알리지 않는다")
	# ㄷ. 고비 기록이 아예 없던 저장 + 마을에서 난 어른
	var d5: Dictionary = bytes_to_var(var_to_bytes(jw3.to_dict()))
	_strip(d5)
	var v5 := JarWorld.from_dict(d5).primary()
	var n5 := v5.events.serial
	v5.advance(2.0)
	check(Milestones.is_passed(v5, "steps") and Milestones.is_passed(v5, "grown") and _count(v5, &"milestone", n5) == 0, "기록이 없던 옛 저장도 같다")
	# ㄹ. 처음 온 아이·어른뿐인 마을: 넘은 것으로 치지 않는다
	var v6 := _aged(24)
	check(not Milestones.is_passed(v6, "steps") and not Milestones.is_passed(v6, "grown") and (v6.milestones["kids"] as Array).is_empty(), "처음 온 사람은 마을에서 난 사람이 아니다")
	var born_ok := Milestones.born_here(v6, _born(v6, "아람", 0.3), v6.t) and Milestones.born_here(v6, _born(v6, "도담", 5.0), v6.t)
	var kit_no := true
	for p in v6.people:
		if p.name != "아람" and p.name != "도담":
			kit_no = kit_no and not Milestones.born_here(v6, p, v6.t)
	var mig := v6.add_person("새식구", "m", 2.0, "", v6.fire.x, v6.fire.y, null, null)
	mig.parents = PackedInt32Array([v6.people[0].id, v6.people[1].id])
	check(born_ok and kit_no and not Milestones.born_here(v6, mig, v6.t), "마을에서 난 사람 가려내기: 난 아이·어른은 맞고, 처음 온 사람·데려온 아이는 아니다")


const STRIP_W := 460.0                            # 수첩 종이 안쪽 너비 (540 px 화면 — 넉넉히 잡은 값)


## 띠가 너비 STRIP_W에 놓였을 때의 크기: 도장 줄의 가장 좁은 너비 × (도장 줄 + 다음 고비 한 줄)의 높이.
## (다음 고비 줄은 너비에 맞춰 줄을 바꾸므로, 놓이기 전의 가장 작은 크기로는 높이를 알 수 없다)
func _strip_size(st: MilestoneStamps) -> Vector2:
	var row := st.get_node("Row") as Control
	var nx := st.get_node("Next") as Label
	nx.size = Vector2(STRIP_W, 0.0)
	var rm := row.get_combined_minimum_size()
	return Vector2(rm.x, rm.y + float(st.get_theme_constant("separation")) + nx.get_minimum_size().y)


## 도장 띠: 자리 일곱이 넘는 차례대로 한 줄에 (540 px 화면 — 줄이지 않은 도장·글씨로), 얇은 띠 높이 안에. 여덟이어도 깨지지 않는다
func test_strip_seven() -> void:
	var v := _fresh(25)
	var st := MilestoneStamps.make(v, true)
	run.root.add_child(st)
	var row := st.get_node("Row")
	var order_ok := row.get_child_count() == Milestones.ORDER.size()
	var nexts := 0
	for i in row.get_child_count():
		order_ok = order_ok and String(row.get_child(i).name) == "Cell_" + String(Milestones.ORDER[i])
		nexts += 1 if row.get_child(i).get_child(0).get("next") else 0
	check(order_ok and Milestones.ORDER == ["bread", "steps", "pop12", "grown", "green", "pop20", "winter"], "도장은 넘는 차례대로 (첫 빵 · 첫걸음마 · 식구 열둘 · 첫 어른 · 첫 고개 · 식구 스물 · 첫 겨울)")
	var labels_ok := true
	var widest := 0.0
	var cell_w := (STRIP_W - float((row as HBoxContainer).get_theme_constant("separation")) * float(row.get_child_count() - 1)) / float(row.get_child_count())
	for i in row.get_child_count():
		var lb := row.get_child(i).get_child(1) as Label
		var stp := row.get_child(i).get_child(0) as Control
		labels_ok = labels_ok and lb.text == String(Milestones.LABEL[Milestones.ORDER[i]]) and lb.get_theme_font_size("font_size") >= 12 \
			and is_equal_approx(stp.custom_minimum_size.x, MilestoneStamps.STAMP_SMALL)
		widest = maxf(widest, lb.get_minimum_size().x)
	check(labels_ok and widest <= cell_w and String(Milestones.LABEL["green"]) == "첫 고개",
		"일곱이어도 도장·이름 글씨를 줄이지 않는다 — 이름 한 줄이 제 칸 안에 (가장 긴 이름 %.0f px ≤ 칸 %.0f px)" % [widest, cell_w])
	check(nexts == 1 and bool(row.get_child(0).get_child(0).get("next")), "다음 고비 자리 하나만 진하게")
	var ms := _strip_size(st)
	check(ms.x <= STRIP_W and ms.y <= 100.0 and ms.y >= 60.0, "얇은 띠: 일곱이 한 줄 · 높이 100 px 안 (%.0f × %.0f)" % [ms.x, ms.y])
	st.queue_free()
	var eight: Array = Milestones.stamps(v)
	eight.append({"id": "x1", "label": "식구 서른", "passed": false})
	var s8 := MilestoneStamps.build(eight, Milestones.next_line(v), true)
	run.root.add_child(s8)
	var m8 := _strip_size(s8)
	check(s8.get_node("Row").get_child_count() == 8 and m8.x <= STRIP_W and m8.y <= 100.0, "여덟이어도 한 줄 · 높이 100 px 안 (%.0f × %.0f)" % [m8.x, m8.y])
	s8.queue_free()
	var big := MilestoneStamps.make(v, false)
	run.root.add_child(big)
	check(big.get_node("Row").get_child_count() == 7 and big.get_combined_minimum_size().x <= 500.0, "큰 도장 줄도 일곱이 들어간다 (%.0f)" % big.get_combined_minimum_size().x)
	big.queue_free()


## 표지판 (Q9 ⑦): 마을 한쪽 멀리 외딴 건물이 있어도 표지판은 제 방향의 바깥 건물 바로 밖 — 규칙은 그대로 다 피한다
func test_sign_near() -> void:
	var near := 0
	var clean := 0
	var seeds := [15, 16, 17, 18, 19, 20]
	for sd: int in seeds:
		var v := _fresh(sd)
		var p0 := Milestones.edge_spot(v)
		v.add_building("나무꾼", v.fire.x - 1.0, v.fire.y - 16.0, true)      # 위쪽(표지판 반대편) 멀리 외딴 일터
		var p := Milestones.edge_spot(v)
		near += 1 if p.distance_to(v.fire) < 12.0 and p.is_equal_approx(p0) else 0
		clean += 1 if Milestones.spot_clear(v, p) and p == Milestones.edge_spot(v) else 0
	check(near == seeds.size(), "반대편 외딴 건물은 표지판을 밀어내지 않는다 — 예전에는 그 건물만큼 멀리 섰다 (%d / %d)" % [near, seeds.size()])
	check(clean == seeds.size(), "그래도 깨끗한 자리 · 늘 같은 자리 (%d / %d)" % [clean, seeds.size()])
	var v := _fresh(15)
	var p := Milestones.edge_spot(v)
	var gap := 1.0e9
	for b in v.buildings:
		gap = minf(gap, Vector2(b.x, b.y).distance_to(p) - b.size())
	check(gap >= Balance.SIGN_CLEAR_BUILDING and p.distance_to(v.fire) >= Balance.SIGN_MIN_R, "건물 가장자리·광장에서 떨어져 선다 (건물까지 %.1f칸 · 모닥불에서 %.1f칸)" % [gap, p.distance_to(v.fire)])
	var dir := (p - v.fire).normalized()
	var house := v.add_building("오두막", p.x + dir.x * 1.5, p.y + dir.y * 1.5, true)     # 그 방향에 집이 서면 그 바깥으로
	var p2 := Milestones.edge_spot(v)
	check(p2.distance_to(Vector2(house.x, house.y)) >= house.size() + Balance.SIGN_CLEAR_BUILDING and Milestones.spot_clear(v, p2), "제 방향에 건물이 서면 비켜 선다")
	# 이미 적힌 자리는 옮기지 않는다
	var q := _fresh(16)
	_grow_to(q, 12, false)
	q.advance(2.0)
	var rec := _rec(q, "pop12")
	var at := Vector2(float(rec["x"]), float(rec["y"]))
	q.add_building("나무꾼", q.fire.x, q.fire.y + 15.0, true)
	check((MilestoneView.wanted(q)["pop12"] as Vector2).is_equal_approx(at), "적어 둔 자리는 마을이 자라도 그대로")


## 화면: 첫걸음마를 보러 온 이웃이 손뼉 걸음 동안 콩콩 — 끝나면 되돌림. 화면이 하는 일은 시뮬레이션을 바꾸지 않는다
func test_clap_view() -> void:
	var old_cut := CutoutResident.override
	CutoutResident.override = 1
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var mv := MilestoneView.of(vw)
	v.water.offline = true
	v.chief_off = true
	v.advance(2.0)
	_set_date(v, 6, 10, 9.0)
	var baby := _born(v, "아람", ChildPlay.TODDLE_AGE + 0.004)
	var d := ChildPlay.door(v, baby)
	var n := 0
	for p in v.people:
		if not p.is_adult() or p.id in baby.parents or n >= 3:
			continue
		p.steps.clear()
		p.action = "idle"
		p.anim = "idle"
		p.carry = ""
		p.x = d.x + 2.6 + 0.3 * float(n)
		p.y = d.y + 1.6 - 0.5 * float(n)
		n += 1
	Milestones._gather(v, baby, null)
	v.advance(Balance.STEPS_GATHER_SECS + ChildPlay.CARE_IV + 60.0)
	vw.fast = false
	vw.sync(0.0, true)
	var d0 := SaveCodec.digest(v.to_dict())
	mv._process(0.1)
	vw.sync(0.0, true)
	var want := 0
	var facing := 0
	for p in v.people:
		if p.steps.is_empty() or p.anim != "play" or not (p.steps[0] as Dictionary).has("ms"):
			continue
		want += 1
		var m := vw.residents.get(p.id) as Node3D
		var bm := vw.residents.get(baby.id) as Node3D
		if m != null and bm != null:
			var to := bm.position - m.position
			facing += 1 if absf(angle_difference(m.rotation.y, atan2(to.x, to.z))) < 0.05 else 0
	check(want >= 2 and mv.clappers() == want, "손뼉 걸음 중인 이웃이 화면에서 콩콩 (걸음 %d · 화면 %d)" % [want, mv.clappers()])
	check(facing == want, "아기 쪽을 본다 (%d / %d)" % [facing, want])
	var said := 0
	for p in v.people:
		if vw.stage_say.has(p.id) and MilestoneView.CLAP_SAY.has(String((vw.stage_say[p.id] as Array)[0])):
			said += 1
	check(said == want, "한마디씩 (%d)" % said)
	check(d0 == SaveCodec.digest(v.to_dict()), "화면 몸짓은 시뮬레이션을 바꾸지 않는다")
	v.advance(Balance.STEPS_CLAP_SECS + 900.0)
	vw.sync(0.0, true)
	mv._process(0.1)
	check(mv.clappers() == 0, "손뼉이 끝나면 몸짓도 풀린다 (%d)" % mv.clappers())
	run.root.remove_child(scene)
	scene.free()
	CutoutResident.override = old_cut


## 손이 빈 채 쉬는 이웃으로 (부를 수 있는 사람)
func _idle(p: Resident) -> void:
	p.steps.clear()
	p.action = "idle"
	p.anim = "idle"
	p.carry = ""
	p.sleeping = false


## 첫걸음마 이웃 (Q9 ⑮): 이웃 둘이 와 설 때까지 아기가 기다리며, 그사이 손이 난 어른을 더 부른다 — 길어도 마감(STEPS_GATHER_MAX)까지.
## 자는 사람·밥 먹는 사람·짐 든 사람·아이·앓는 사람은 끝내 부르지 않는다. 난수 없음
func test_steps_wait() -> void:
	var v := _aged(26)
	var baby := _born(v, "아람", ChildPlay.TODDLE_AGE + Balance.STEPS_PARENT_WAIT + 0.004)
	var d := ChildPlay.door(v, baby)
	for p in v.people:
		if p.id != baby.id:
			p.steps.clear()
			p.carry = "통나무"                          # 모두 짐을 든 채 — 부를 사람이 없다
	var s0 := v.rng.state
	var t0 := v.t
	var held := Milestones.steps_hold(v, baby)
	var call: Dictionary = v.milestones.get("steps_call", {})
	check(held and not call.is_empty() and Milestones._coming(v, baby.id) == 0 and v.rng.state == s0, "부를 사람이 없어도 부름은 열어 두고 기다린다 (난수 없음)")
	var last := float(call.get("last", 0.0))
	check(is_equal_approx(float(call.get("at", 0.0)), t0 + Balance.STEPS_GATHER_SECS) and is_equal_approx(last, t0 + Balance.STEPS_GATHER_MAX),
		"어림한 때 = STEPS_GATHER_SECS 뒤 · 마감 = STEPS_GATHER_MAX 뒤")
	v.t = float(call["at"]) + 1.0
	check(Milestones.steps_hold(v, baby) and Milestones._coming(v, baby.id) == 0, "어림한 때가 되어도 온 이웃이 없으면 더 기다린다 (마감 전)")
	var a := v.add_person("다래", "f", 20.0, "", d.x + 5.0, d.y + 3.0, null, null)
	var b := v.add_person("솔이", "m", 21.0, "", d.x + 6.0, d.y + 2.0, null, null)
	var kid := v.add_person("한울", "m", 2.0, "", d.x + 1.5, d.y + 2.0, null, null)
	var sick := v.add_person("가람", "f", 22.0, "", d.x + 1.8, d.y + 1.0, null, null)
	var asleep := v.add_person("누리", "m", 23.0, "", d.x + 2.0, d.y + 1.2, null, null)
	var eating := v.add_person("보람", "f", 24.0, "", d.x + 2.2, d.y + 1.4, null, null)
	var loaded := v.add_person("한결", "m", 25.0, "", d.x + 2.4, d.y + 1.6, null, null)
	for p: Resident in [a, b, kid, sick, asleep, eating, loaded]:
		_idle(p)
	sick.sick_left = 5000.0
	asleep.sleeping = true
	asleep.anim = "sleep"
	eating.action = "eat"
	eating.anim = "eat"
	loaded.carry = "통나무"
	var t1 := v.t
	s0 = v.rng.state                                  # (사람을 새로 놓는 데는 난수가 든다 — 그 뒤부터 본다)
	held = Milestones.steps_hold(v, baby)
	var left_alone := true
	for p: Resident in [kid, sick, asleep, eating, loaded]:
		left_alone = left_alone and p.doing != Milestones.CLAP_DOING and not Milestones.at_steps(p)
	check(held and a.doing == Milestones.CLAP_DOING and b.doing == Milestones.CLAP_DOING and Milestones._coming(v, baby.id) == 2,
		"기다리는 동안 손이 난 어른 둘을 더 부른다 (오는 사람 %d)" % Milestones._coming(v, baby.id))
	check(left_alone, "더 가까이 있어도 아이·앓는 사람·자는 사람·밥 먹는 사람·짐 든 사람은 부르지 않는다")
	var at2 := float(call["at"])
	check(at2 > t1 and at2 <= last and Milestones.clappers(v, baby.id) == 0, "걸음은 새로 부른 이웃이 걸어올 만큼 뒤로 — 마감은 넘기지 않는다 (%.0f초 뒤)" % (at2 - t1))
	v.t = at2 + 1.0
	check(Milestones.steps_hold(v, baby), "이웃이 아직 걸어오는 중이면 기다린다")
	a.steps.pop_front()                                # 한 사람이 와 섰다
	check(Milestones.clappers(v, baby.id) == 1 and Milestones.steps_hold(v, baby), "하나만 와 서면 아직 기다린다")
	b.steps.pop_front()
	check(Milestones.clappers(v, baby.id) == Balance.STEPS_CLAP_MIN and not Milestones.steps_hold(v, baby), "둘이 와 서면 걸음을 뗀다")
	check(v.rng.state == s0, "기다리고 더 부르는 데 난수를 쓰지 않는다")
	Milestones.on_first_steps(v, baby)
	var rec := _rec(v, "steps")
	var s1: Dictionary = a.steps[0]
	check(int(rec.get("n", 0)) == 2 and not v.milestones.has("steps_call") and is_zero_approx(float(s1["left"])) and String((a.steps[1] as Dictionary).get("anim", "")) == "play",
		"걸음을 떼면 서서 기다리던 이웃은 곧바로 손뼉 (온 이웃 %d)" % int(rec.get("n", 0)))
	check(_lines(v, "이웃들이 모여 손뼉을 쳤다") == 1, "연대기: 이웃들이 모여 손뼉을 쳤다")
	# 마감: 끝내 아무도 못 오면 마감에 혼자서 뗀다. 마감까지 걸어올 수 없는 먼 사람은 부르지 않는다
	var q := _aged(27)
	var b2 := _born(q, "도담", ChildPlay.TODDLE_AGE + Balance.STEPS_PARENT_WAIT + 0.004)
	var d2 := ChildPlay.door(q, b2)
	for p in q.people:
		if p.id != b2.id:
			p.steps.clear()
			p.carry = "통나무"
	check(Milestones.steps_hold(q, b2) and q.milestones.has("steps_call"), "(마감) 부름을 연다")
	var c2: Dictionary = q.milestones["steps_call"]
	var last2 := float(c2["last"])
	var late := q.add_person("이슬", "f", 20.0, "", d2.x + Balance.STEPS_CLAP_R - 1.5, d2.y, null, null)
	_idle(late)
	var need := (Balance.STEPS_CLAP_R - 4.0) / late.walk_speed()
	q.t = last2 - need * 0.5
	check(q.t > float(c2["at"]) + Balance.STEPS_GATHER_LATE and Milestones.steps_hold(q, b2) and is_equal_approx(float((q.milestones["steps_call"] as Dictionary)["last"]), last2),
		"마감 전까지는 같은 부름으로 기다린다 — 마감을 새로 잡지 않는다")
	check(late.doing != Milestones.CLAP_DOING and not Milestones.at_steps(late), "마감까지 걸어올 수 없는 먼 사람은 부르지 않는다")
	q.t = last2 + 1.0
	check(not Milestones.steps_hold(q, b2), "마감이 지나면 혼자서라도 걸음을 뗀다")
	Milestones.on_first_steps(q, b2)
	check(int(_rec(q, "steps").get("n", -1)) == 0 and _lines(q, "이웃들이 모여 손뼉을 쳤다") == 0, "아무도 못 왔으면 손뼉 이야기는 뺀다")
	# 다른 아기는 먼저 부른 아기의 걸음을 기다린다
	var w := _aged(28)
	var first := _born(w, "아람", ChildPlay.TODDLE_AGE + Balance.STEPS_PARENT_WAIT + 0.004)
	var second := _born(w, "보리", ChildPlay.TODDLE_AGE + Balance.STEPS_PARENT_WAIT + 0.004)
	for p in w.people:
		if p.id != first.id and p.id != second.id:
			p.steps.clear()
			p.carry = "통나무"
	Milestones.steps_hold(w, first)
	check(Milestones.steps_hold(w, second) and int((w.milestones["steps_call"] as Dictionary)["baby"]) == first.id, "다른 아기는 먼저 부른 아기의 걸음 뒤에")


## 잔치 사건 가운데 그 고비의 것 수
func _feasts(v: Village, id: String, from := 0) -> int:
	var n := 0
	for e: Dictionary in v.events.since(from):
		if e["kind"] == &"feast" and String((e["v"] as Dictionary)["id"]) == id:
			n += 1
	return n


## 그 해 푸른 밀 고개의 마지막 날 hour시로 (병 날짜)
func _lean_last_day(v: Village, hour: float) -> void:
	var off := LeanSeasons.green_start(v, 2026) - Balance.GREEN_START_DOY + Balance.GREEN_DAYS - 1
	_set_date(v, 5, 5 + off, hour)


## 첫 푸른 밀 고개를 넘김 (Q9 ⑭): 고개가 처음 끝난 날 아침에 한 번 — 햇밀 다발을 곳간 문 위에, 그 저녁 작은 잔치, 밭일하는 사람에게 별명
func test_green() -> void:
	var v := _aged(31, 40.0, 22.0)
	_bake(v, v.people[0])
	v.advance(2.0)
	var extra := v.add_building("창고", v.fire.x + 6.0, v.fire.y - 5.0, true)
	var house := Milestones.sheaf_house(v)
	check(house != null and house.type == "창고" and house.id <= extra.id, "햇밀 다발을 걸 곳: 다 지은 창고 가운데 번호가 가장 작은 것")
	_lean_last_day(v, 22.0)                           # 고개의 마지막 날 밤
	var n0 := v.events.serial
	v.advance(1.2 * H)
	check(int(v.stats.get("lean_green_y", -1)) == 2026 and not Milestones.green_over(v) and not Milestones.is_passed(v, "green"), "고개 동안에는 넘지 않는다")
	v.advance(2.0 * H)                                # 자정을 넘겨 01:12
	check(Milestones.green_over(v) and _lines(v, "푸른 밀 고개를 넘은 것이다") == 1, "고개가 끝남 (LeanSeasons가 적는다)")
	check(not Milestones.is_passed(v, "green") and _ms_count(v, "green", n0) == 0, "밤에는 아직 — 햇밀 다발은 아침에 건다 (병 시각 %.1f)" % v.hour_now())
	v.advance((Balance.GREEN_PASS_HOUR - v.hour_now()) * H - 120.0)
	check(not Milestones.is_passed(v, "green"), "GREEN_PASS_HOUR 전에는 넘지 않는다 (병 시각 %.2f)" % v.hour_now())
	v.advance(240.0)
	var rec := _rec(v, "green")
	check(Milestones.is_passed(v, "green") and _ms_count(v, "green", n0) == 1 and not bool(rec.get("silent", true)), "그날 아침 GREEN_PASS_HOUR에 고비 — 사건 한 번 (병 시각 %.2f)" % v.hour_now())
	check(int(rec.get("b", -1)) == house.id and not bool(rec.get("f", true)) and is_equal_approx(float(rec.get("x", 0.0)), house.x) and is_equal_approx(float(rec.get("y", 0.0)), house.y),
		"기록: 창고 번호와 그때의 자리")
	var ev := _last(v, &"milestone")
	check(String((ev["v"] as Dictionary)["id"]) == "green" and (ev["at"] as Vector2).distance_to(Vector2(house.x, house.y)) < house.size() + 1.5 and int((ev["v"] as Dictionary)["feast_day"]) == v.cal_day(v.t),
		"사건: 같은 milestone 종류 · id green · 자리는 창고 · 잔치는 그날 저녁")
	var who := v.person(int(rec.get("who", -1)))
	check(who != null and who.nickname == "햇밀을 거둔" and String(rec.get("nick", "")) == "햇밀을 거둔", "별명 '햇밀을 거둔' (%s)" % (who.name if who != null else "-"))
	check(_lines(v, "햇밀 다발을 곳간 문 위에 걸었다") == 1 and _lines(v, "'햇밀을 거둔 %s'" % (who.name if who != null else "")) == 1, "연대기 한 줄 (별명과 함께)")
	v.advance((19.3 - v.hour_now()) * H)
	var f: Dictionary = v.milestones.get("feast", {})
	check(_count(v, &"feast", n0) == 1 and Milestones.feast_on(v) and Milestones.feast_id(v) == "green", "그 저녁 햇밀 잔치 (병 시각 %.1f)" % v.hour_now())
	check(is_equal_approx(float(f.get("until", 0.0)) - float(f.get("t0", 0.0)), Balance.FEAST_SMALL_SECS) and _lines(v, "햇밀 잔치가 열렸다") == 1 and _festive(v) >= 3,
		"작은 잔치 (FEAST_SMALL_SECS) · 연대기 한 줄 · 모인 사람 %d" % _festive(v))
	v.advance(26.0 * H)
	check(_ms_count(v, "green", n0) == 1 and _feasts(v, "green", n0) == 1, "다음 날에도 다시 알리지 않는다 (햇밀 잔치 %d)" % _feasts(v, "green", n0))
	v.stats["lean_green_y"] = 2027                    # 이듬해 고개: 다시 넘어도 고비는 한 번뿐
	v.stats["lean_green_end_y"] = 2027
	v.advance(2.0 * H)
	check(_ms_count(v, "green", n0) == 1 and _lines(v, "햇밀 다발") == 1, "병에 한 번 — 이듬해 고개에는 없다")
	var w := Village.from_dict(bytes_to_var(var_to_bytes(v.to_dict())))
	check(Milestones.is_passed(w, "green") and int(_rec(w, "green").get("b", -1)) == house.id, "저장 → 불러오기: 기록이 남는다")
	# 창고가 없는 마을: 첫 밭 울타리에 (연대기도 그렇게), 밭도 없으면 모닥불 곁에
	var q := _aged(32, 40.0, 9.5)
	for b in q.buildings:
		if b.type == "창고":
			b.built = false
	var field := q.add_building("농장", q.fire.x - 7.0, q.fire.y + 6.0, true)
	var fh := Milestones.sheaf_house(q)
	q.stats["lean_green_end_y"] = 2026
	q.advance(2.0)
	var r2 := _rec(q, "green")
	check(fh != null and fh.type == "농장" and fh.id <= field.id and int(r2.get("b", -1)) == fh.id and bool(r2.get("f", false)), "창고가 없으면 첫 밭에 건다 (기록 f)")
	check(_lines(q, "밭 울타리에") == 1 and _lines(q, "곳간 문 위") == 0, "연대기도 밭 울타리로")
	var z := _aged(33, 40.0, 9.5)
	for b in z.buildings:
		if b.type == "창고" or b.type == "농장":
			b.built = false
	z.stats["lean_green_end_y"] = 2026
	z.advance(2.0)
	var r3 := _rec(z, "green")
	check(Milestones.sheaf_house(z) == null and int(r3.get("b", 0)) == -1 and Vector2(float(r3.get("x", 1.0e6)), float(r3.get("y", 1.0e6))).distance_to(z.fire) < 2.0 and _lines(z, "모닥불 곁에") == 1,
		"창고도 밭도 없으면 모닥불 곁에 세운다 (연대기도)")


## 고비 여섯이던 때의 저장으로 (v 2 — 첫 고개 기록 없음)
func _ungreen(x: Variant) -> void:
	if x is Dictionary:
		var d: Dictionary = x
		if d.has("milestones") and d["milestones"] is Dictionary and (d["milestones"] as Dictionary).has("v"):
			var m: Dictionary = d["milestones"]
			m["v"] = 2
			if m.has("passed") and m["passed"] is Dictionary:
				(m["passed"] as Dictionary).erase("green")
		for k: Variant in d:
			_ungreen(d[k])
	elif x is Array:
		for e: Variant in x:
			_ungreen(e)


func _quiet_green(v2: Village, n0: int, book0: int, what: String) -> void:
	var nicks := 0
	for p in v2.people:
		nicks += 1 if p.nickname == "햇밀을 거둔" else 0
	var queued := 0
	for f: Dictionary in v2.milestones.get("feasts", []):
		queued += 1 if String(f["id"]) == "green" else 0
	check(Milestones.is_passed(v2, "green") and bool(_rec(v2, "green").get("silent", false)), "%s: 이미 넘은 고개는 조용히 넘은 것으로" % what)
	var said := 0
	for i in range(book0, v2.book.size()):
		said += 1 if String(v2.book[i]["text"]).contains("햇밀") else 0
	check(_ms_count(v2, "green", n0) == 0 and nicks == 0 and queued == 0 and said == 0, "%s: 사건·별명·잔치·연대기 없음" % what)
	v2.advance(34.0 * H)
	check(_ms_count(v2, "green", n0) == 0 and _feasts(v2, "green", n0) == 0, "%s: 그 뒤로도 다시 알리지 않는다" % what)


## 옛 저장: 푸른 밀 고개를 이미 넘긴 병은 조용히 (기록이 없던 저장 · 고비 여섯이던 때의 저장). 아직 안 넘긴 옛 저장은 넘는 날 제대로
func test_green_old_save() -> void:
	var jw := _world(36)
	var v := jw.primary()
	v.chief_off = true
	v.t = 40.0 * D
	v.advance(2.0)
	_set_date(v, 6, 10, 10.0)
	_bake(v, v.people[0])
	v.advance(2.0)
	check(not Milestones.is_passed(v, "green"), "고개를 넘기 전")
	var before: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))     # 고개 전의 저장
	v.stats["lean_green_y"] = 2026
	v.stats["lean_green_end_y"] = 2026
	var d: Dictionary = bytes_to_var(var_to_bytes(jw.to_dict()))
	# ㄱ. 고비 기록이 아예 없던 저장
	var d1: Dictionary = d.duplicate(true)
	_strip(d1)
	var v1 := JarWorld.from_dict(d1).primary()
	var n1 := v1.events.serial
	var book1 := v1.book.size()
	v1.advance(2.0)
	_quiet_green(v1, n1, book1, "기록이 없던 저장")
	check(MilestoneView.wanted(v1).has("green"), "조용히 넘은 병에도 햇밀 다발은 건다 (창고 자리는 알 수 있다)")
	# ㄴ. 고비 여섯이던 때의 저장 (v 2)
	var d2: Dictionary = d.duplicate(true)
	_ungreen(d2)
	var v2 := JarWorld.from_dict(d2).primary()
	check(int(v2.milestones.get("v", 0)) == 2 and not Milestones.is_passed(v2, "green"), "고비 여섯이던 때의 저장")
	var n2 := v2.events.serial
	var book2 := v2.book.size()
	v2.advance(2.0)
	check(int(v2.milestones["v"]) == Milestones.VERSION and Milestones.is_passed(v2, "bread") and not bool(_rec(v2, "bread").get("silent", true)), "다른 기록은 그대로")
	_quiet_green(v2, n2, book2, "고비 여섯이던 때의 저장")
	# ㄷ. 고비 여섯이던 때의 저장인데 아직 고개 전: 넘는 날 제대로 고비
	_ungreen(before)
	var v3 := JarWorld.from_dict(before).primary()
	var n3 := v3.events.serial
	v3.advance(2.0)
	check(int(v3.milestones["v"]) == Milestones.VERSION and not Milestones.is_passed(v3, "green") and Milestones.next_line(v3) != "", "아직 고개 전인 옛 저장은 넘은 것으로 치지 않는다")
	v3.stats["lean_green_end_y"] = 2026
	v3.advance(2.0)
	check(Milestones.is_passed(v3, "green") and not bool(_rec(v3, "green").get("silent", true)) and _ms_count(v3, "green", n3) == 1, "넘는 날 제대로 고비 (옛 저장에서도)")


## 별명 '햇밀을 거둔': 밭에서 일하는 어른 가운데 번호가 가장 작은 사람 → 이미 별명이 있으면 다음 사람 → 밭일꾼이 없으면 촌장. 난수 없음 · 늘 같은 사람
func test_green_nick() -> void:
	var picks: Array = []
	for mode: int in [0, 0, 1, 2]:
		var v := _aged(34, 40.0, 9.5)
		var farm := v.add_building("농장", v.fire.x - 7.0, v.fire.y + 6.0, true)
		var adults: Array = []
		for p in v.people:
			p.job = -1
			if p.is_adult():
				adults.append(p)
		adults.sort_custom(func(a: Resident, b: Resident) -> bool: return a.id < b.id)
		var hi: Resident = adults[adults.size() - 1]
		var lo: Resident = adults[1]
		if mode < 2:
			hi.job = farm.id
			lo.job = farm.id
		if mode == 1:
			lo.nickname = "첫 빵을 구운"
		for p in v.people:                                # 밭에 붙은 아이는 후보가 아니다
			if p.is_child() and not p.is_baby() and mode < 2:
				p.job = farm.id
		var s0 := v.rng.state
		v.stats["lean_green_end_y"] = 2026
		Milestones.step(v, 0.0)
		var rec := _rec(v, "green")
		var who := v.person(int(rec.get("who", -1)))
		check(v.rng.state == s0, "별명을 고르는 데 난수를 쓰지 않는다 (%d)" % mode)
		match mode:
			0:
				picks.append(int(rec.get("who", -1)))
				check(who == lo and lo.nickname == "햇밀을 거둔" and hi.nickname == "", "밭일하는 어른 가운데 먼저 온(번호가 작은) 사람에게")
			1:
				check(who == hi and hi.nickname == "햇밀을 거둔" and lo.nickname == "첫 빵을 구운", "이미 별명이 있으면 다음 밭일꾼에게 (별명은 한 사람에 하나)")
			2:
				check(who != null and who == v.chief() and who.nickname == "햇밀을 거둔", "밭일꾼이 없으면 촌장에게")
	check(picks.size() == 2 and picks[0] == picks[1], "같은 병이면 늘 같은 사람")


## 화면: 햇밀 다발은 창고 문 위에 — 창고 그림 바로 앞, 문틀 높이 (카메라 기울기만큼 올림). 창고가 없어지면 밭, 그것도 없으면 적어 둔 자리
func test_sheaf() -> void:
	var v := _aged(35, 40.0, 9.5)
	v.add_building("창고", v.fire.x + 6.0, v.fire.y - 5.0, true)
	v.add_building("농장", v.fire.x - 7.0, v.fire.y + 6.0, true)
	var house := Milestones.sheaf_house(v)
	check(not MilestoneView.wanted(v).has("green"), "고개 전: 햇밀 다발 없음")
	v.stats["lean_green_end_y"] = 2026
	v.advance(2.0)
	var d0 := SaveCodec.digest(v.to_dict())
	var w := MilestoneView.wanted(v)
	var s := MilestoneView.sheaf(v)
	check(w.has("green") and (w["green"] as Vector2).is_equal_approx(Vector2(house.x, house.y)) and (s["pos"] as Vector2).is_equal_approx(Vector2(house.x, house.y)),
		"햇밀 다발 자리 = 창고")
	if Bld2D.enabled():
		var pic := Bld2D.info(MilestoneView.SHEAF_PIC)
		var face := float(pic["front"]) * VillageView.BUILDING_SCALE
		var tall := float(pic["h"]) * VillageView.BUILDING_SCALE
		check(float(s["front"]) > face and float(s["front"]) < face + 0.3, "창고 그림 바로 앞에 (그림 면 %.2f칸 · 다발 %.2f칸)" % [face, float(s["front"])])
		check(float(s["h"]) > tall * 0.35 and float(s["h"]) + (MilestoneView.SIZE["green"] as Vector2).y < tall * 0.75,
			"문틀 높이 — 문 위 · 지붕 아래 (그림 높이 %.2f칸 가운데 %.2f칸)" % [tall, float(s["h"])])
	else:
		check(float(s["front"]) > 0.0 and float(s["lift"]) > 0.0, "3D 창고: 앞벽 쪽 · 땅 위로")
	var off: Array = []
	for b in v.buildings:                             # 창고가 없어지면 밭 울타리로
		if b.built and b.type == "창고":
			b.built = false
			off.append(b)
	var s2 := MilestoneView.sheaf(v)
	var fh := Milestones.sheaf_house(v)
	check(fh != null and fh.type == "농장" and (s2["pos"] as Vector2).is_equal_approx(Vector2(fh.x, fh.y)) and float(s2["front"]) > 0.0 and is_zero_approx(float(s2["h"])),
		"창고가 없어지면 첫 밭 울타리 앞 땅에")
	for b in v.buildings:
		if b.built and b.type == "농장":
			b.built = false
			off.append(b)
	var s3 := MilestoneView.sheaf(v)
	check((s3["pos"] as Vector2).is_equal_approx(Vector2(house.x, house.y)) and is_zero_approx(float(s3["h"])) and is_zero_approx(float(s3["front"])), "아무것도 없으면 적어 둔 자리 땅에")
	for b: Building in off:
		b.built = true
	check(d0 == SaveCodec.digest(v.to_dict()), "자리 셈은 시뮬레이션을 바꾸지 않는다")
	# 화면 노드: 다발이 창고 자리에 서고, 문틀 높이만큼 올라가 있다
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	var q: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var mv := MilestoneView.of(vw)
	q.water.offline = true
	q.chief_off = true
	q.advance(2.0)
	_set_date(q, 6, 10, 9.5)
	q.add_building("창고", q.fire.x + 6.0, q.fire.y - 5.0, true)
	q.stats["lean_green_end_y"] = 2026
	q.advance(2.0)
	vw.sync(0.0, true)
	mv.refresh()
	var node := mv.sign_node("green")
	var qs := MilestoneView.sheaf(q)
	var qh := Milestones.sheaf_house(q)
	check(node != null and qh != null and is_equal_approx(node.position.x, qh.x) and is_equal_approx(node.position.z, qh.y), "화면: 햇밀 다발 노드가 창고 자리에")
	check(mv.sheaf_lift() >= float(qs["h"]) + float(qs["lift"]) - 0.001 and mv.sheaf_lift() <= float(qs["lift"]) + float(qs["h"]) / 0.3 + 0.001 and mv.sheaf_lift() > 0.5,
		"화면: 문틀 높이로 올려 둔다 (%.2f칸)" % mv.sheaf_lift())
	run.root.remove_child(scene)
	scene.free()
