## 사람들 목록 (view/ui/people_sheet.gd — 위 띠 "N명" · 연대기 [모두 보기]). tests/run.gd가 부름 (`-- people` = 이것만).
## 줄 = 살아 있는 사람 · 정렬(이름·나이·직업·기분·아픈 사람 먼저) · 보기(아이·어른·노인·아픈 사람·일 없는 사람) · 무리마다 묶음 ·
## 줄 다시 쓰기(100명 넘어도 줄 몇 개) · 누르면 그 사람의 주민 상세 · [따라가기].
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
	print("== 사람들 목록")
	run.timed(self, ["test_rows", "test_assignment", "test_by_workplace", "test_sorts", "test_filters", "test_sick_first", "test_grouping", "test_sheet", "test_many", "test_scene_detail"])


func proto() -> Village:
	Village.start_aware = true
	var v := Village.new_prototype(20261107)
	Village.start_aware = false
	v.water.offline = true
	v.advance(0.6 * Balance.DAY)
	return v


func ids(a: Array) -> Array:
	return a.map(func(e: Dictionary) -> int: return (e["r"] as Resident).id)


func test_rows() -> void:
	var v := proto()
	var es := PeopleSheet.entries([v])
	var want := v.people.map(func(r: Resident) -> int: return r.id)
	var got := ids(es)
	got.sort()
	want.sort()
	check(got == want and not es.is_empty(), "줄 = 살아 있는 사람 모두 (%d명)" % es.size())
	v.kill(v.people[0], "노환")
	es = PeopleSheet.entries([v])
	check(es.size() == v.people.size() and es.all(func(e: Dictionary) -> bool: return not (e["r"] as Resident).dead), "잠든 사람은 줄에서 빠짐")
	var bad := 0
	for e: Dictionary in es:
		var r: Resident = e["r"]
		if String(e["job"]) == "" or String(e["name"]) != r.name or int(e["mood"]) < 0 or int(e["mood"]) > 2:
			bad += 1
		if not PeopleSheet.stage_word(r).contains(str(r.shown_age())):
			bad += 1
	check(bad == 0, "줄마다 이름 · 아이/어른/노인 + 나이 · 직업 · 기분 단계(0~2)")
	var kid: Resident = null
	for r in v.people:
		if not r.parents.is_empty() and v.person(r.parents[0]) != null:
			kid = r
	if kid != null:
		var pe: Dictionary = es.filter(func(e: Dictionary) -> bool: return (e["r"] as Resident).id == kid.parents[0])[0]
		check(int(pe["kids"]) >= 1 and PeopleSheet.family_word(pe).contains("아이"), "부모 줄에 아이 수 (%s)" % PeopleSheet.family_word(pe))
	var wed: Array = es.filter(func(e: Dictionary) -> bool: return bool(e["partner"]))
	check(wed.is_empty() or PeopleSheet.family_word(wed[0]).contains("배우자"), "배우자 표")


## 맡은 일: 직업 · 일터 (같은 종류가 여럿이면 번호) · 짐꾼 (일터 없음) · 아이 — 놀이 · 노인 — 쉼
func test_assignment() -> void:
	var v := proto()
	var worker: Resident = null
	var loose: Resident = null
	for r in v.people:
		if r.job >= 0 and worker == null:
			worker = r
		elif r.is_adult() and r.job < 0:
			loose = r
	if loose == null:
		for r in v.people:
			if r.is_adult() and r != worker:
				loose = r
		var lb := v.bld(loose.job)
		if lb != null:
			lb.worker = -1
		loose.job = -1
	var es := PeopleSheet.entries([v])
	var bad := PackedStringArray()
	for e: Dictionary in es:
		var r: Resident = e["r"]
		var w := String(e["work"])
		var b := v.bld(r.job) if r.job >= 0 else null
		var want := ""
		if b != null:
			want = "%s · %s" % [PeopleSheet.job_name(b.type), PeopleSheet.place_name(v, b)]
		elif r.is_baby():
			want = "아기 — 돌봄"
		elif r.is_child():
			want = "아이 — 놀이"
		elif r.is_elder():
			want = "노인 — 쉼"
		else:
			want = "짐꾼 (일터 없음)"
		if w != want:
			bad.append("%s: %s" % [r.name, w])
	check(bad.is_empty(), "줄마다 맡은 일 %s" % (", ".join(bad) if not bad.is_empty() else "(예: %s)" % PeopleSheet.assignment(worker, v)))
	var wb := v.bld(worker.job)
	check(PeopleSheet.assignment(worker, v).contains(PeopleSheet.place_label(wb.type)), "일하는 사람: 직업 · 일터 이름 (%s)" % PeopleSheet.assignment(worker, v))
	check(PeopleSheet.assignment(loose, v) == "짐꾼 (일터 없음)", "일터 없는 어른: 짐꾼 (일터 없음)")
	check(PeopleSheet.place_label("나무꾼") != "" and PeopleSheet.place_label("농장") != "농장", "건물 이름 (나무꾼 → %s · 농장 → %s)" % [PeopleSheet.place_label("나무꾼"), PeopleSheet.place_label("농장")])
	var twin := Building.new()
	twin.id = 900000
	twin.type = wb.type
	twin.built = true
	v.buildings.append(twin)
	var a := PeopleSheet.place_name(v, wb)
	var c := PeopleSheet.place_name(v, twin)
	var same_n := v.buildings.filter(func(b: Building) -> bool: return b.built and b.type == wb.type).size()
	check(a != c and c.ends_with(" %d" % same_n) and a.begins_with(PeopleSheet.place_label(wb.type)), "같은 종류가 여럿 → 번호 (%s · %s)" % [a, c])
	v.buildings.erase(twin)


## 일터별: 일터마다 머리줄 (이름 · 일꾼/자리) → 일 없는 사람 → 아이·노인
func test_by_workplace() -> void:
	var v := proto()
	var gone: Building = null
	for r in v.people:
		if r.job >= 0 and r.is_adult():
			gone = v.bld(r.job)
			gone.worker = -1
			r.job = -1
			break
	var it := PeopleSheet.items([v], "work")
	var heads := it.filter(func(x: Dictionary) -> bool: return x.has("head"))
	var jobs := v.buildings.filter(func(b: Building) -> bool: return b.built and b.def().get("job", false))
	var bheads := heads.filter(func(x: Dictionary) -> bool: return x.has("b"))
	check(bheads.size() == jobs.size(), "일터 %d곳 모두 머리줄 (빈 일터도)" % jobs.size())
	var cur: Dictionary = {}
	var ok := true
	var rows := 0
	for x: Dictionary in it:
		if x.has("head"):
			cur = x
			continue
		rows += 1
		var r: Resident = x["r"]
		if cur.has("b"):
			ok = ok and r.job == (cur["b"] as Building).id
		elif cur.has("idle"):
			ok = ok and r.is_adult() and r.job < 0
		else:
			ok = ok and (r.is_child() or r.is_elder()) and r.job < 0
	check(ok and rows == v.people.size(), "사람은 자기 일터 아래 · 일 없는 사람 · 아이·노인 (%d명)" % rows)
	var gh: Array = bheads.filter(func(x: Dictionary) -> bool: return x["b"] == gone)
	check(gone != null and gh.size() == 1 and int(gh[0]["count"]) == 0 and String(gh[0]["text"]).ends_with("0/1명"), "빈 일터: %s" % (gh[0]["text"] if not gh.is_empty() else "-"))
	check(heads.any(func(x: Dictionary) -> bool: return x.has("idle") and String(x["text"]).begins_with("일 없는 사람")), "'일 없는 사람' 묶음")
	var full: Array = bheads.filter(func(x: Dictionary) -> bool: return int(x["count"]) == 1)
	check(not full.is_empty() and String(full[0]["text"]).contains("1/1명"), "일터 머리줄: %s" % (full[0]["text"] if not full.is_empty() else "-"))
	var nm := v.people[0].name
	check(PeopleSheet.items([v], "work", "all", nm).filter(func(x: Dictionary) -> bool: return not x.has("head")).size() >= 1
		and PeopleSheet.items([v], "work", "all", nm).filter(func(x: Dictionary) -> bool: return x.has("b") and int(x["count"]) == 0).is_empty(), "찾을 땐 빈 일터를 뺌")


func test_sorts() -> void:
	var v := proto()
	var es := PeopleSheet.entries([v])
	var by_name := PeopleSheet.arrange(es, "name")
	var ok := true
	for i in range(1, by_name.size()):
		ok = ok and String(by_name[i - 1]["name"]).naturalnocasecmp_to(by_name[i]["name"]) <= 0
	check(ok, "이름 순")
	var by_age := PeopleSheet.arrange(es, "age")
	ok = true
	for i in range(1, by_age.size()):
		ok = ok and float(by_age[i - 1]["age"]) >= float(by_age[i]["age"])
	check(ok, "나이 순 (많은 사람 먼저)")
	var by_job := PeopleSheet.arrange(es, "job")
	ok = true
	for i in range(1, by_job.size()):
		ok = ok and String(by_job[i - 1]["job"]).naturalnocasecmp_to(by_job[i]["job"]) <= 0
	check(ok, "직업 순")
	v.people[0].happiness = 0.05
	v.people[1].happiness = 0.95
	es = PeopleSheet.entries([v])
	var by_mood := PeopleSheet.arrange(es, "mood")
	ok = true
	for i in range(1, by_mood.size()):
		ok = ok and int(by_mood[i - 1]["mood"]) <= int(by_mood[i]["mood"])
	check(ok and (by_mood[0]["r"] as Resident) == v.people[0] and int(by_mood[-1]["mood"]) == 2, "기분 순 (시무룩한 사람 먼저)")
	check(by_name.size() == es.size() and by_age.size() == es.size(), "정렬은 사람을 빼지 않음")


func test_filters() -> void:
	var v := proto()
	var es := PeopleSheet.entries([v])
	var c := PeopleSheet.arrange(es, "name", "child")
	var a := PeopleSheet.arrange(es, "name", "adult")
	var e := PeopleSheet.arrange(es, "name", "elder")
	check(c.size() + a.size() + e.size() == es.size(), "아이 %d + 어른 %d + 노인 %d = 모두 %d" % [c.size(), a.size(), e.size(), es.size()])
	check(c.all(func(x: Dictionary) -> bool: return (x["r"] as Resident).is_child()) and e.all(func(x: Dictionary) -> bool: return (x["r"] as Resident).is_elder())
		and a.all(func(x: Dictionary) -> bool: return (x["r"] as Resident).is_adult()), "보기: 아이·어른·노인이 맞음")
	var some: Resident = null
	for r in v.people:
		if not r.is_child():
			some = r
	some.job = -1
	es = PeopleSheet.entries([v])
	var idle := PeopleSheet.arrange(es, "name", "idle")
	check(idle.any(func(x: Dictionary) -> bool: return x["r"] == some) and idle.all(func(x: Dictionary) -> bool: return not (x["r"] as Resident).is_child() and (x["r"] as Resident).job < 0),
		"일 없는 사람: 아이가 아니고 일터 없음 (%d명)" % idle.size())
	check(PeopleSheet.arrange(es, "name", "sick").all(func(x: Dictionary) -> bool: return int(x["sick"]) > 0), "아픈 사람 보기: 아픈 사람만")
	var nm := v.people[2].name
	var found := PeopleSheet.arrange(es, "name", "all", nm)
	check(not found.is_empty() and found.all(func(x: Dictionary) -> bool: return String(x["name"]).containsn(nm)), "이름 찾기 '%s'" % nm)


func test_sick_first() -> void:
	var v := proto()
	for r in v.people:
		r.sick_left = 0.0
		r.injured_left = 0.0
	var hurt: Resident = v.people[1]
	var ill: Resident = v.people[3]
	var bad: Resident = v.people[4]
	hurt.injured_left = 300.0
	ill.sick_left = 300.0
	ill.severe = false
	bad.sick_left = 300.0
	bad.severe = true
	var es := PeopleSheet.entries([v])
	var s := PeopleSheet.arrange(es, "sick")
	check(s[0]["r"] == bad and s[1]["r"] == ill and s[2]["r"] == hurt and int(s[3]["sick"]) == 0, "아픈 사람 먼저: 몹시 아픔 → 아픔 → 다침 → 나머지")
	check(s[0]["health"] == "몹시 아파요" and s[1]["health"] == "아파요" and s[2]["health"] == "다쳤어요" and s[3]["health"] == "", "건강 표 (말로만)")
	check(PeopleSheet.arrange(es, "name", "sick").size() == 3, "아픈 사람 보기 = 3명")


func _two_settlements() -> JarWorld:
	Village.start_aware = true
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	var nv := jw.place_kit(sp[1].x, sp[1].y)
	Village.start_aware = false
	v.settlement_name = "첫 무리"
	nv.settlement_name = "둘째 무리"
	return jw


func test_grouping() -> void:
	var jw := _two_settlements()
	var vs: Array = jw.settlements
	var it := PeopleSheet.items(vs, "name")
	var heads := it.filter(func(x: Dictionary) -> bool: return x.has("head"))
	check(heads.size() == 2 and heads[0]["v"] == vs[0] and heads[1]["v"] == vs[1], "무리가 둘 → 무리 이름 머리줄 둘")
	var cur: Village = null
	var ok := true
	var n := 0
	for x: Dictionary in it:
		if x.has("head"):
			cur = x["v"]
			ok = ok and int(x["count"]) == cur.people.size()
		else:
			n += 1
			ok = ok and x["v"] == cur and (x["r"] as Resident) in cur.people
	var total: int = (vs[0] as Village).people.size() + (vs[1] as Village).people.size()
	check(ok and n == total, "사람은 자기 무리 머리줄 아래 (%d명)" % n)
	check(PeopleSheet.items([vs[0]], "name").all(func(x: Dictionary) -> bool: return not x.has("head")), "무리가 하나면 머리줄 없음")
	var only := PeopleSheet.items(vs, "name", "all", (vs[1] as Village).people[0].name)
	check(only.filter(func(x: Dictionary) -> bool: return x.has("head")).all(func(x: Dictionary) -> bool: return int(x["count"]) > 0), "찾기로 빈 무리는 머리줄도 뺌")


func test_sheet() -> void:
	var v := proto()
	var sh := PeopleSheet.new()
	run.root.add_child(sh)
	sh.setup([v])
	sh.open()
	var rows := sh.shown_rows()
	check(not rows.is_empty() and rows.all(func(r: PeopleSheet.PeopleRow) -> bool: return (r.e["r"] as Resident) in v.people), "시트: 줄이 살아 있는 사람 (%d줄)" % rows.size())
	check(rows[0].e["r"] == sh.list[0]["r"], "첫 줄 = 이름 순 첫 사람")
	check(not rows[0].name_l.text.is_empty() and rows[0].line2.text == String(rows[0].e["work"]) and rows[0].doing_l.text == String(rows[0].e["doing"]),
		"줄: 이름 · 맡은 일 · 하는 일 (%s / %s / %s)" % [rows[0].name_l.text, rows[0].line2.text, rows[0].doing_l.text])
	sh.sort_btns["work"].pressed.emit()
	check(sh.list.any(func(x: Dictionary) -> bool: return x.has("b")) and not sh._heads.is_empty() and sh._heads[0].visible, "일터별 칩 → 일터 머리줄 (%s)" % (sh._heads[0].text if not sh._heads.is_empty() else "-"))
	sh.sort_btns["name"].pressed.emit()
	rows = sh.shown_rows()
	var digits := RegEx.create_from_string("[0-9]")
	check(rows.all(func(r: PeopleSheet.PeopleRow) -> bool: return digits.search(r.badge.text) == null), "기분·건강에 숫자 없음")
	var got: Array = []
	sh.resident_pressed.connect(func(q: Village, r: Resident) -> void: got.append([q, r]))
	var fol: Array = []
	sh.follow_requested.connect(func(q: Village, r: Resident) -> void: fol.append(r))
	var pick := rows[mini(1, rows.size() - 1)]
	pick.pressed.emit()
	check(got.size() == 1 and got[0][0] == v and got[0][1] == pick.e["r"], "줄을 누르면 그 사람 (%s)" % (got[0][1] as Resident).name if not got.is_empty() else "-")
	pick.follow_btn.pressed.emit()
	check(fol.size() == 1 and fol[0] == pick.e["r"], "[따라가기] → 그 사람")
	sh.filter_btns["elder"].pressed.emit()
	check(sh.filter_key == "elder" and sh.list.all(func(x: Dictionary) -> bool: return x["stage"] == "elder"), "보기 칩 누름 → 노인만")
	sh.sort_btns["age"].pressed.emit()
	check(sh.sort_key == "age" and (sh.sort_btns["age"] as Button).theme_type_variation == "FollowOn", "정렬 칩 누름 → 나이 (칩 켜짐)")
	sh.close()
	check(not sh.visible, "닫기")
	run.root.remove_child(sh)
	sh.free()


## 150명: 줄은 보이는 만큼만 (다시 씀), 스크롤하면 그 자리 사람
func test_many() -> void:
	var v := proto()
	var base: Resident = v.people[0]
	for i in 150:
		var r := Resident.from_dict(base.to_dict())
		r.id = 100000 + i
		r.name = "가%03d" % i
		r.partner = -1
		v.people.append(r)
	var sh := PeopleSheet.new()
	run.root.add_child(sh)
	sh.setup([v])
	sh.open()
	sh.scroll.size = Vector2(340, 400)
	sh._place()
	var made := sh._rows.size()
	check(sh.list.size() == v.people.size() and made <= 12, "%d명 → 줄 %d개만 만듦" % [sh.list.size(), made])
	sh.scroll.get_v_scroll_bar().max_value = sh.content.custom_minimum_size.y
	sh.scroll.scroll_vertical = int((PeopleSheet.ROW_H + PeopleSheet.ROW_GAP) * 80)
	sh._place()
	var rows := sh.shown_rows()
	var want: Resident = sh.list[80]["r"]
	check(sh._rows.size() <= 12 and rows.any(func(r: PeopleSheet.PeopleRow) -> bool: return r.e["r"] == want), "가운데로 스크롤 → 81번째 사람 줄 (줄 %d개 그대로)" % sh._rows.size())
	var t0 := Time.get_ticks_usec()
	for i in 10:
		sh._rebuild(false)
	var ms := (Time.get_ticks_usec() - t0) / 10000.0
	check(ms < 30.0, "새로 읽기 한 번 %.1f ms (%d명)" % [ms, v.people.size()])
	run.root.remove_child(sh)
	sh.free()


## 장면: 위 띠 "N명" → 목록 → 줄 → 주민 상세 그 사람 · [따라가기] → 따라감 · 연대기 [모두 보기]
func test_scene_detail() -> void:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	var ps: PeopleSheet = scene.get("people_sheet")
	var info: Label = scene.get("info_label")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	info.gui_input.emit(ev)
	check(ps.visible and info.mouse_filter == Control.MOUSE_FILTER_STOP, "위 띠 'N명' 누름 → 사람들 목록")
	var sv: Village = scene.get("village")
	var row: PeopleSheet.PeopleRow = ps.shown_rows()[0]
	var who: Resident = row.e["r"]
	row.pressed.emit()
	var det: ResidentDetail = scene.get("detail")
	check(not ps.visible and det.visible and det.r == who and who in sv.people, "줄 누름 → 주민 상세 그 사람 (%s)" % who.name)
	det.close()
	scene.call("open_people")
	row = ps.shown_rows()[0]
	who = row.e["r"]
	row.follow_btn.pressed.emit()
	check(det.visible and det.r == who and det.following and int(scene.get("follow_id")) == who.id, "[따라가기] → 상세 + 카메라가 따라감")
	det.close()
	var ch: ChronicleSheet = scene.get("chronicle")
	scene.call("open_chronicle", 2)
	var all_b: Button = null
	for c in ch.body.get_children():
		if c is Button and (c as Button).text == "모두 보기":
			all_b = c
	check(all_b != null, "연대기 '사람들'에 [모두 보기]")
	if all_b != null:
		all_b.pressed.emit()
		check(ps.visible and not ch.visible, "[모두 보기] → 사람들 목록")
	run.root.remove_child(scene)
	scene.free()
