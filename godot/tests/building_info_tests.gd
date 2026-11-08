## 건물 정보 카드 (docs/UI.md '건물 정보 카드' — view/ui/building_info.gd · view/ui/building_ledger.gd · test_village.pick_building).
## tests/run.gd가 부름 (`-- building_info` = 이것만). 장면을 띄우는 묶음 (TREE_SUITES).
## 내용: 집(사는 사람·땔감) · 창고(묶음별 양) · 빵집(오늘 만든 양·쌓인 것·멈춤 경고·일손 없음) · 짓는 터(진행 막대·자재·짓는 사람) · 밭(자람) · 이야기 한 줄 ·
##   장부가 시뮬레이션을 바꾸지 않음 · 장면: 건물 누르기 → 카드 · 주민이 앞이면 주민 먼저 · 빈 땅 = 닫기(유리 톡 아님) · 아래로 밀기 = 닫기 · 얼굴 → 주민 상세 · 카메라 비켜 주기
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
	print("== 건물 정보 카드")
	run.timed(self, ["test_house", "test_store", "test_bakery", "test_site", "test_farm_story", "test_ledger_readonly", "test_scene_pick"])


func proto() -> Village:
	Village.start_aware = true
	var v := Village.new_prototype(20261108)
	Village.start_aware = false
	v.water.offline = true
	v.advance(0.3 * Balance.DAY)
	return v


func _first(v: Village, f: Callable) -> Building:
	for b in v.buildings:
		if f.call(b):
			return b
	return null


func _has_line(lines: PackedStringArray, part: String) -> bool:
	for l in lines:
		if l.contains(part):
			return true
	return false


func test_house() -> void:
	var v := proto()
	var h := _first(v, func(b: Building) -> bool: return b.built and b.is_house() and v.occupants(b) > 0)
	check(h != null, "사람이 사는 집이 있음")
	if h == null:
		return
	var f := BuildingInfo.facts(v, h)
	var want := v.people.filter(func(r: Resident) -> bool: return r.home == h.id)
	check(String(f["people_label"]) == "사는 사람" and (f["people"] as Array).size() == want.size(), "집: '사는 사람' 얼굴 = 그 집 식구 (%d명)" % want.size())
	check(_has_line(f["lines"], "식구 %d / %d명" % [want.size(), h.cap()]) and _has_line(f["lines"], "땔감 통나무"), "집: 식구 수 · 땔감 줄")
	check(String(f["desc"]) != "" and String(f["title"]) != "", "이름 + 한 줄 설명 (%s — %s)" % [f["title"], f["desc"]])
	v.cold_season = true
	h.in_buf["통나무"] = 0.0
	h.fuel_on = false
	f = BuildingInfo.facts(v, h)
	check(String(f["warn"]) == "땔감이 없어 추워요", "추운 철 · 땔감 없음 → 경고 한 줄")
	h.in_buf["통나무"] = 3.0
	h.fuel_on = true
	f = BuildingInfo.facts(v, h)
	check(String(f["warn"]) == "" and _has_line(f["lines"], "따뜻해요") and _has_line(f["lines"], "통나무 3"), "땔감 있음 → 경고 없음 · 따뜻해요")
	check(float(f["prog"]) < 0.0, "다 지은 집은 진행 막대 없음")


func test_store() -> void:
	var v := proto()
	var st := _first(v, func(b: Building) -> bool: return b.is_store)
	check(st != null, "창고가 있음")
	if st == null:
		return
	v.stock["판자"] = 12.0
	v.stock["빵"] = 30.0
	var f := BuildingInfo.facts(v, st)
	var ls: PackedStringArray = f["lines"]
	check(_has_line(ls, "식량") and _has_line(ls, "재료:") and _has_line(ls, "판자 12") and _has_line(ls, "먹을 것:") and _has_line(ls, "빵 30"), "창고: 식량 · 묶음별 양 (%s)" % " / ".join(ls))
	check(String(f["people_label"]) == "", "창고: 얼굴 줄 없음")


func test_bakery() -> void:
	var v := proto()
	var b := v.add_building("빵집", v.center.x + 6.0, v.center.y + 6.0, true)
	var led := BuildingLedger.new()
	var f := BuildingInfo.facts(v, b, led)
	check(String(f["title"]).begins_with("빵집") and String(f["people_label"]) == "일하는 사람", "빵집: 이름 · '일하는 사람'")
	if b.worker < 0:
		check(String(f["warn"]) == "일하는 사람이 없어요", "일꾼 없음 → 경고")
	var w: Resident = null
	for r in v.people:
		if r.is_adult() and r.sick_left <= 0.0:
			w = r                         # 앓는 사람은 빼고 (앓으면 '앓아누워 쉬고 있어요' 경고 — 마을 걸음에 따라 누가 앓는지 달라짐, 2026-11-09)
	b.worker = w.id
	led.sample(v)
	b.out["빵"] = float(b.out.get("빵", 0.0)) + 3.0
	led.sample(v)
	b.out["빵"] = 1.0                      # 나르기로 줄어도 센 것은 그대로
	led.sample(v)
	b.out["빵"] = 4.0
	led.sample(v)
	b.in_buf["밀가루"] = 2.0
	v.stock["밀가루"] = 12.0
	f = BuildingInfo.facts(v, b, led)
	var ls: PackedStringArray = f["lines"]
	check(_has_line(ls, "밀가루 → 빵 구워요 · 오늘 빵 6"), "오늘 구운 빵 = 더미가 늘어난 만큼 (3 + 3 = 6) (%s)" % " / ".join(ls))
	check(_has_line(ls, "들어온 재료 밀가루 2") and _has_line(ls, "앞에 쌓인 것 빵 4") and _has_line(ls, "창고에 밀가루 12"), "들어온 재료 · 쌓인 것 · 창고의 재료")
	check((f["people"] as Array).size() == 1 and (f["people"] as Array)[0] == w and String(f["warn"]) == "", "얼굴 = 일꾼 · 경고 없음")
	v._stall[b.id] = {"why": &"no_input", "since": v.t, "stalled": true, "at": v.t, "ok": -1.0}
	f = BuildingInfo.facts(v, b, led)
	check(String(f["warn"]) == "밀가루가 없어 멈췄어요", "재료가 없어 멈춤 → '밀가루가 없어 멈췄어요'")
	v._stall.erase(b.id)
	v.t += Balance.DAY
	f = BuildingInfo.facts(v, b, led)
	check(_has_line(f["lines"], "오늘 빵 0"), "다음 날이면 오늘 만든 양은 0부터")


func test_site() -> void:
	var v := proto()
	var b := v.add_building("목조주택", v.center.x - 7.0, v.center.y + 5.0, false)
	b.prog = float(Balance.B["목조주택"]["time"]) * 0.5
	b.delivered["판자"] = 4
	b.delivered["돌"] = 0
	var led := BuildingLedger.new()
	var f := BuildingInfo.facts(v, b, led)
	check(absf(float(f["prog"]) - 0.5) < 0.01 and String(f["warn"]).begins_with("짓는 중 — 50%"), "짓는 터: 진행 막대 50%% + 경고 '짓는 중' (%s)" % f["warn"])
	check(String(f["warn"]).contains("자재를 기다려요") and _has_line(f["lines"], "판자 4/4 · 돌 0/1"), "자재가 모자라면 '자재를 기다려요' · 자재 줄")
	check(String(f["title"]).ends_with(" 터"), "이름: '… 터'")
	var a := v.people[0]
	var c := v.people[1]
	led.note_builder(v, b, a.id)
	led.note_builder(v, b, c.id)
	f = BuildingInfo.facts(v, b, led)
	check(String(f["story"]).contains(a.name) and String(f["story"]).ends_with("함께 짓고 있어요"), "짓는 중 이야기: 본 사람이 함께 짓고 있어요 (%s)" % f["story"])
	b.delivered["돌"] = 1
	f = BuildingInfo.facts(v, b, led)
	check(not String(f["warn"]).contains("자재"), "자재가 다 오면 기다림 경고 없음")


func test_farm_story() -> void:
	var v := proto()
	var fm := v.add_building("농장", v.center.x + 9.0, v.center.y - 4.0, false)
	fm.prog = float(Balance.B["농장"]["time"])
	v.t = 3.0 * Balance.DAY + 100.0
	v.on_built(fm)
	var led := BuildingLedger.new()
	var a := v.people[0]
	var c := v.people[1]
	led.note_builder(v, fm, a.id)
	led.note_builder(v, fm, c.id)
	var f := BuildingInfo.facts(v, fm, led)
	check(_has_line(f["lines"], "밀이 자라는 중 — 0%"), "막 갈은 밭: 자라는 중 0%% (%s)" % " / ".join(f["lines"]))
	var want := "4일차, %s%s %s%s 지었어요" % [a.name, Village.josa(a.name, "과", "와"), c.name, Village.josa(c.name, "이", "가")]
	check(String(f["story"]) == want, "이야기: '%s'" % f["story"])
	v.t = fm.ready_at + 1.0
	f = BuildingInfo.facts(v, fm, led)
	check(_has_line(f["lines"], "밀이 익었어요"), "수확 시각이 지나면 '익었어요'")
	check(String(BuildingInfo.facts(v, fm)["story"]) == "4일차에 지어졌어요", "지은 사람을 못 봤으면 날짜만")
	var st := _first(v, func(b: Building) -> bool: return b.is_store)
	check(String(BuildingInfo.facts(v, st)["story"]).begins_with("1일차, 처음"), "처음부터 있던 건물: '1일차, 처음 이곳에 왔을 때부터 있었어요'")
	var text := ""
	for k in ["농장", "창고"]:
		var bb := _first(v, func(b: Building) -> bool: return b.type == k)
		var ff := BuildingInfo.facts(v, bb, led)
		text += String(ff["title"]) + String(ff["desc"]) + String(ff["warn"]) + "\n".join(ff["lines"]) + String(ff["story"])
	check(not text.contains("확률") and not text.contains("부수") and not text.contains("옮기"), "확률 · 부수기 · 옮기기 말 없음")


## 장부는 읽기만 — 같은 씨앗의 두 마을에서 한쪽만 장부를 돌려도 결과가 같다 (ADR-0001)
func test_ledger_readonly() -> void:
	var a := proto()
	var b := proto()
	var led := BuildingLedger.new()
	for i in 40:
		a.advance(600.0)
		led.sample(a)
		b.advance(600.0)
	var pa := a.people.map(func(r: Resident) -> String: return "%d:%.3f,%.3f" % [r.id, r.x, r.y])
	var pb := b.people.map(func(r: Resident) -> String: return "%d:%.3f,%.3f" % [r.id, r.x, r.y])
	check(pa == pb and a.book.size() == b.book.size(), "장부를 돌려도 주민 자리·연대기가 같음")


func test_scene_pick() -> void:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	v.water.offline = true
	var tries := 0
	while tries < 12 and _first(v, func(b: Building) -> bool: return b.built and b.is_house() and v.occupants(b) > 0) == null:
		v.advance(0.1 * Balance.DAY)
		tries += 1
	vw.sync(0.0, true)
	var cam: JarCamera = scene.get("cam")
	var card: BuildingInfo = scene.get("bcard")
	var det: ResidentDetail = scene.get("detail")
	var h := _first(v, func(b: Building) -> bool: return b.built and b.is_house() and v.occupants(b) > 0)
	var n: Node3D = vw._blds.get(h.id)
	scene.call("look_at_ground", Vector2(h.x, h.y))
	var sp := cam.camera.unproject_position(n.global_position + Vector3(0, 0.6, 0))
	# 주민을 모두 멀리 (주민 우선 규칙 없이 건물만)
	for m: ResidentModel in vw.residents.values():
		m.global_position = n.global_position + Vector3(40, 0, 40)
	check(scene.call("pick_building", sp) == h, "누른 곳 = 그 집 (화면 사각형 안)")
	scene.call("_on_tap", sp)
	check(card.visible and card.b == h and not det.visible, "건물을 누름 → 건물 정보 카드 (%s)" % card.title_l.text)
	var pf := cam.camera.unproject_position(n.global_position + Vector3(0, 0.5, 0))
	check(card.free_rect().has_point(pf), "카메라가 비켜 줌: 건물이 카드에 가리지 않음 (%.0f, %.0f)" % [pf.x, pf.y])
	check(card.face_btns[0].visible and card.face_btns[0].r != null, "얼굴 동그라미가 보임")
	# 아래로 밀기 = 닫기
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.relative = Vector2(0, 30)
	card._on_panel_input(mm)
	check(card.visible, "조금만 밀면 그대로")
	card._on_panel_input(mm)
	check(not card.visible, "아래로 밀면 닫힘")
	# 얼굴 → 주민 상세
	scene.call("open_building", v, h, vw, true)
	var who: Resident = card.face_btns[0].r
	card.face_btns[0].pressed.emit()
	check(not card.visible and det.visible and det.r == who, "얼굴을 누름 → 그 주민 상세 (%s)" % (who.name if who != null else "?"))
	det.close()
	# 주민이 앞에 있으면 주민 먼저
	scene.call("open_building", v, h, vw, true)
	sp = cam.camera.unproject_position(n.global_position + Vector3(0, 0.6, 0))
	var r0: Resident = v.people[0]
	var m0: ResidentModel = vw.residents.get(r0.id)
	m0.global_position = n.global_position + Vector3(0, 0.0, 0)
	scene.call("_on_tap", sp)
	check(det.visible and det.r == r0 and not card.visible, "주민과 건물이 함께 눌리면 주민 먼저")
	det.close()
	m0.global_position = n.global_position + Vector3(40, 0, 40)
	# 빈 땅 = 닫기 (유리 톡 아님)
	scene.call("open_building", v, h, vw, true)
	var empty := Vector2(-1, -1)
	var vs: Vector2 = scene.get_viewport().get_visible_rect().size
	var fr := card.free_rect()
	for yy in range(int(scene.get("top_h")) + 30, int(fr.end.y) - 10, 12):
		for xx in range(20, int(vs.x) - 20, 12):
			var p := Vector2(xx, yy)
			if scene.call("pick_building", p) == null and scene.call("pick_resident", p) == null and scene.call("pick_altar", p) == null:
				empty = p
				break
		if empty.x >= 0.0:
			break
	check(empty.x >= 0.0, "빈 땅 자리를 찾음")
	var taps := int(v._taps[1])
	var bt := v.book.size()
	scene.call("_on_tap", empty)
	check(not card.visible, "빈 땅을 누르면 카드가 닫힘")
	check(int(v._taps[1]) == taps and v.book.size() == bt, "카드를 닫는 누름은 유리 톡이 아님")
	# 짓는 터도 누를 수 있음
	var site := v.add_building("오두막", h.x + 4.0, h.y + 4.0, false)
	site.prog = float(Balance.B["오두막"]["time"]) * 0.25
	vw.sync(0.0, true)
	var sn: Node3D = vw._blds.get(site.id)
	scene.call("look_at_ground", Vector2(site.x, site.y))
	for m: ResidentModel in vw.residents.values():
		m.global_position = sn.global_position + Vector3(40, 0, 40)
	sp = cam.camera.unproject_position(sn.global_position + Vector3(0, 0.3, 0))
	check(scene.call("pick_building", sp) == site, "짓는 터를 누름 → 그 터")
	scene.call("open_building", v, site, vw, true)
	check(card.visible and card.bar.visible and absf(card.bar.value - 0.25) < 0.01 and card.warn_l.text.begins_with("짓는 중"), "짓는 터 카드: 진행 막대 25% · '짓는 중'")
	card.close()
	run.root.remove_child(scene)
	scene.free()
