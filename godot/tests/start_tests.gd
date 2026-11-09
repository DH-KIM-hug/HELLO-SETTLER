## 시작 흐름 — docs/UI.md "00 시작 흐름". tests/run.gd가 부름 (`-- start` = 이것만, 몇 초).
## 회사 로고 → 타이틀 · 타이틀 버튼(저장 없음 [시작하기] / 있음 [이어하기] + "이름 · n일째") · 창밖 시각 ·
## 이어하기 = 저장을 불러 병 안으로 · 처음 = 짧은 창조에서 지은 이름으로 새 병 (창세의 날) · 병 안 뒤로 가기 = 저장한 뒤 타이틀로.
## 장면은 실제로 바꾸지 않는다 (StartFlow.navigate = false — 목적지만 확인).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
var TMP_DIR := "user://test_start_save_%d" % OS.get_process_id()      # 프로세스마다 (run.gd _clean_tmp)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 시작 흐름 (UI.md 00)")
	var old_nav := StartFlow.navigate
	var old_hook := Village.on_giant_action
	var old_notes := Market.notes
	StartFlow.navigate = false
	var old_plan := StartFlow.plan
	run.timed(self, ["test_names_and_time", "test_boot_to_title", "test_title_button", "test_continue_path", "test_first_run_and_back", "test_kit_pick", "test_kit_place_by_hand",
		"test_kit_unpack_order", "test_creation_stages", "test_creation_core_seeded", "test_creation_land_morph", "test_creation_presets", "test_creation_choices", "test_creation_determinism", "test_creation_resume", "test_reset_all"])
	StartFlow.plan = old_plan
	StartFlow.pending_world = null
	_clean()
	StartFlow.navigate = old_nav
	StartFlow.take()
	Village.on_giant_action = old_hook
	Market.notes = old_notes


func _clean() -> void:
	var da := DirAccess.open(ProjectSettings.globalize_path(TMP_DIR))
	if da == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_DIR))
		return
	for f in da.get_files():
		da.remove(f)


func manager() -> GameSave:
	_clean()
	var sm := GameSave.new()
	sm.dir = TMP_DIR
	sm.start()
	return sm


func drop(sm: GameSave) -> void:
	sm.stop()
	sm.free()


func add(path: String) -> Node:
	var n: Node = load(path).instantiate()
	if "world_size" in n:                 # 넓은 세상 장면: 시험은 작은 세상 (512칸 — 빨리)
		n.set("world_size", WorldCfg.SMALL_SIZE)
		n.set("world_seed", 3)
		n.set("pick_spot", false)         # 키트 자리 고르기는 test_kit_pick이 따로
	run.root.add_child(n)
	return n


func remove(n: Node) -> void:
	run.root.remove_child(n)
	n.free()


## 시험용 저장: 이름 nm, days일 흘린 넓은 세상 하나 (작은 세상 512칸) — 첫 무리를 돌려줌
func save_world(sm: GameSave, nm: String, days: float) -> Village:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	jw.advance(days * Balance.DAY)
	v.water.offline = false
	var c := JarClock.new(v)
	sm.register_jar(1, v, c, {"name": nm}, jw)
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	return v


## 시험용 저장 (옛 소형 병 — kind "jar"): 이름 nm, days일 흘린 병 하나
func save_jar(sm: GameSave, nm: String, days: float) -> Village:
	var v := Village.new_prototype(20261105)
	v.water.offline = true
	v.advance(days * Balance.DAY)
	v.water.offline = false
	var c := JarClock.new(v)
	sm.register_jar(1, v, c, {"name": nm})
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	return v


func test_names_and_time() -> void:
	check(StartFlow.time_of_day(7) == "morning" and StartFlow.time_of_day(15) == "morning", "창밖: 6~16시 아침")
	check(StartFlow.time_of_day(16) == "sunset" and StartFlow.time_of_day(18) == "sunset", "창밖: 16~19시 노을")
	check(StartFlow.time_of_day(19) == "night" and StartFlow.time_of_day(2) == "night" and StartFlow.time_of_day(5) == "night", "창밖: 그 밖은 밤")
	check(StartFlow.clean_name("  초록방울방울방울방울방울 ") == "초록방울방울방울방울", "지구 이름 최대 10자 · 앞뒤 빈칸 없앰")
	check(StartFlow.clean_name("   ") == StartFlow.NAMES[0], "빈 이름이면 추천 이름")
	var ok := true
	for n: String in StartFlow.NAMES:
		ok = ok and n.length() <= StartFlow.NAME_MAX
	check(ok, "추천 이름은 모두 10자 이하")


func test_boot_to_title() -> void:
	var b := add(StartFlow.BOOT_SCENE)
	check(ProjectSettings.get_setting("application/run/main_scene") == StartFlow.BOOT_SCENE, "앱의 첫 장면 = 회사 로고 (boot.tscn)")
	check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back")), "뒤로 가기는 화면이 직접 (엔진이 바로 끝내지 않음)")
	check(String(ProjectSettings.get_setting("application/boot_splash/image")) == "res://art/icon/icon_512.png", "부팅 스플래시 = 앱 아이콘")
	StartFlow.last_target = ""
	b.call("finish")
	check(StartFlow.last_target == StartFlow.TITLE_SCENE, "회사 로고를 누르면(또는 1.5초 뒤) 타이틀로")
	remove(b)


func test_title_button() -> void:
	var sm := manager()
	var t := add(StartFlow.TITLE_SCENE)
	var btn: Button = t.get("button")
	var line: Label = t.get("save_line")
	check(btn.text == "시작하기" and not line.visible, "저장이 없으면 [시작하기] (아래 줄 없음) — '%s'" % btn.text)
	StartFlow.last_target = ""
	t.call("go_next")
	check(StartFlow.last_target == StartFlow.CREATION_SCENE, "[시작하기] → 짧은 창조")
	remove(t)
	var v := save_world(sm, "초록별", 2.4)
	t = add(StartFlow.TITLE_SCENE)
	btn = t.get("button")
	line = t.get("save_line")
	var want := "초록별 · %d일째" % v.day_no()
	check(btn.text == "이어하기" and line.visible and line.text == want, "저장이 있으면 [이어하기] + '%s' (%s)" % [want, line.text])
	check(bool(t.get("room").houses), "이어하기: 병 안에 작은 마을 (손 흔드는 주민)")
	StartFlow.last_target = ""
	t.call("go_next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and StartFlow.GAME_SCENE == "res://scenes/world.tscn" and StartFlow.mode == "continue", "[이어하기] → 병 안 = 넓은 세상 (continue)")
	StartFlow.take()
	remove(t)
	drop(sm)
	# 옛 소형 병 저장 (kind "jar") → 이어하기는 소형 병 장면으로 (저장을 잃지 않게)
	sm = manager()
	save_jar(sm, "옛 병", 1.0)
	sm.jars.clear()
	sm.order.clear()
	StartFlow.last_target = ""
	StartFlow.enter_game(null, "continue")
	check(StartFlow.last_target == StartFlow.JAR_SCENE, "옛 소형 병 저장 → 이어하기는 소형 병 장면")
	StartFlow.enter_game(null, "new", "새 병")
	check(StartFlow.last_target == StartFlow.GAME_SCENE, "새 병은 언제나 넓은 세상")
	StartFlow.take()
	drop(sm)


func test_continue_path() -> void:
	var sm := manager()
	var v := save_world(sm, "이끼마을", 1.3)
	var people := v.people.size()
	sm.jars.clear()
	sm.order.clear()
	StartFlow.enter_game(null, "continue")
	var s := add(StartFlow.GAME_SCENE)
	var sv: Village = s.get("village")
	check(bool(s.get("use_save")) and s.get("entry")["mode"] == "continue", "이어하기로 들어온 병 안 장면은 저장을 쓴다")
	check(sv != v and absf(sv.t - v.t) < 120.0 and sv.people.size() == people, "저장한 병을 불러옴 (시각 %.0f → %.0f · 인구 %d)" % [v.t, sv.t, sv.people.size()])
	var jw: JarWorld = s.get("world")
	check(jw != null and sm.jars[1]["kind"] == "world" and sm.jars[1]["world"] == jw and jw.water.n == WorldCfg.SMALL_SIZE, "넓은 세상 통째로 (땅·물·안개 · 지름 %d칸)" % [jw.water.n if jw != null else 0])
	check(sm.jars.has(1) and String(sm.jars[1]["meta"]["name"]) == "이끼마을", "지구 이름 그대로")
	check(not bool(s.get("catching")), "잠깐 비운 동안은 따라잡기가 바로 끝남 (편지 없이 병 안)")
	remove(s)
	# 직접 띄운 장면(캡처·시험)은 저장을 쓰지 않는다 — StartFlow를 거치지 않으면 새 병
	var s2 := add(StartFlow.GAME_SCENE)
	check(not bool(s2.get("use_save")), "시작 흐름 없이 띄운 장면은 저장을 쓰지 않음 (캡처·시험)")
	remove(s2)
	drop(sm)


## 창조 장면 하나 (시험: 연출 없이 — instant)
func creation(plan: CreationPlan) -> Node:
	StartFlow.plan = plan
	var c: Node = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	return c


func test_first_run_and_back() -> void:
	var sm := manager()
	# 창조 오프닝 (줄임판) → 넓은 세상의 키트 자리 → 첫 주민 소개 → 이름 → 병 안
	var c := creation(CreationPlan.make(3, WorldCfg.SMALL_SIZE))
	check(c.get("step") == "core", "창조 첫 단계 = 핵 넣기 (빈 병 두드리기는 들어가는 연출에)")
	c.call("jump", "life")
	c.call("next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and StartFlow.mode == "new" and StartFlow.pending_world != null, "작은 생명이 깨어난 뒤 [다음] → 넓은 세상 (키트 자리 고르기, 창조가 만든 세상을 넘김)")
	remove(c)
	var s: Node = load(StartFlow.GAME_SCENE).instantiate()
	s.set("kit_anim", false)
	run.root.add_child(s)
	var w: JarWorld = s.get("world")
	check(w != null and w.water.n == WorldCfg.SMALL_SIZE and w.water.seed_v == 3 and w.water.wildlife.is_empty() and not w.water.fish.is_empty(), "키트 자리 고르기 = 창조가 만든 그 세상 (송사리까지 — 들짐승 없음, A28)")
	var ch: Array[Dictionary] = w.spot_choices(5)
	s.call("choose_spot", ch[0]["p"])
	var arr: FirstArrival = s.get("arrival")
	var v: Village = s.get("village")
	check(v != null and arr != null and not sm.jars.has(1), "키트를 놓으면 첫 주민 소개 (이름을 짓기 전엔 저장하지 않음)")
	var plan2 := CreationPlan.load_from(sm.dir)
	check(plan2 != null and plan2.stage == "name" and plan2.spot.size() == 2, "꺼지면 이름 짓기부터 (creation.json: name · 자리)")
	arr.start(v, StartFlow.plan, w.water)
	var three := FirstArrival.first_three(v)
	var kid := false
	for r in three:
		kid = kid or r.is_child()
	check(three.size() == 3 and kid and FirstArrival.intro_line(three[0]).contains("(%d)" % three[0].shown_age()), "첫 주민 3명 소개 (아이 포함): '%s'" % FirstArrival.intro_line(three[0]))
	var waved := false
	for r in three:
		waved = waved or (r.is_child() and r.say != "")
	check(waved, "한 아이가 하늘을 보고 손을 흔듦 (말풍선)")
	for i in 4:
		arr.meet_next()
	arr.show_name()
	check(arr.step == "name" and arr.name_edit.text != "" and arr.name_edit.max_length == 10, "이름 짓기: 추천 이름 · 최대 10자")
	check(not arr.confirm_name("시발별"), "부적절한 이름 → '다른 이름은 어때요?'")
	check(arr.confirm_name("초록방울") and arr.step == "card", "이름을 정하면 지구 카드")
	var rows := arr.card_rows()
	check(rows.size() >= 5 and String(rows[rows.size() - 1][1]).split(", ").size() == v.people.size(), "지구 카드: 핵·광맥·물·기후·첫 주민 %d명" % v.people.size())
	arr.finish()
	var clock: JarClock = s.get("clock")
	check(bool(s.get("use_save")) and sm.jars.has(1) and String(sm.jars[1]["meta"]["name"]) == "초록방울", "새 병이 그 이름으로 저장 대상 (%s)" % [String(sm.jars[1]["meta"]["name"]) if sm.jars.has(1) else "-"])
	check(clock.creation, "첫 병 = 창세의 날 (첫날 ≈ 현실 10~12분)")
	var fv0: Village = s.get("village")
	check(Notebook.active(fv0) == (not fv0.aware), "첫 병 = 거인의 수첩이 펼쳐짐 (OPENING 3.1b — 거인을 아직 모르는 병만%s)" % (" · 이 시험 병은 이미 앎" if fv0.aware else ""))
	check(not CreationPlan.exists_in(sm.dir), "이름을 지으면 만들던 창조 파일은 지움")
	var p := sm.peek()
	check(p.get("name", "") == "초록방울" and int(p.get("day", 0)) == 1, "디스크에 곧바로 — 타이틀 요약 '초록방울 · 1일째' (%s)" % [p])
	# 병 안에서 시간이 흐른 뒤 뒤로 가기
	s.call("advance", 0.4 * Balance.DAY)
	var t_now: float = (s.get("village") as Village).t
	s.call("on_back")
	var cs: ConfirmSheet = s.get("confirm_sheet")
	check(cs.visible and cs.text_l.text == "별지기의 방으로 돌아갈까요?", "뒤로 가기 → '별지기의 방으로 돌아갈까요?'")
	cs.answer(false)
	check(not cs.visible and not bool(s.get("leaving")), "[병 안에 있기] → 그대로")
	(s.get("altar_sheet") as Control).call("open")
	s.call("on_back")
	check(not (s.get("altar_sheet") as Control).visible and not cs.visible, "시트가 열려 있으면 뒤로 가기는 시트만 닫음")
	StartFlow.last_target = ""
	s.call("on_back")
	cs.answer(true)
	check(StartFlow.last_target == StartFlow.TITLE_SCENE, "[돌아가기] → 타이틀")
	check(sm.jars.is_empty(), "떠나면 병을 내려놓음 (다시 이어하기 = 불러오기 + 따라잡기)")
	remove(s)
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	var ok := sm2.load_all()
	var lt: float = (sm2.jar_village(1).t if ok and sm2.jars.has(1) else -1.0)
	check(ok and absf(lt - t_now) < 1.0, "떠나기 전에 저장됨 (병 시각 %.0f = %.0f)" % [lt, t_now])
	sm2.free()
	StartFlow.take()
	drop(sm)


## OPENING 8 v3.9: 아무 데나 누른 자리의 특성 쪽지 (숫자 없이) · 놓을 수 없는 곳은 까닭 → [여기에 내려놓기] → 거인이 키트 건물을 놓음
## (상자 곁만 · 겹치면 안 됨) → 그 자리가 마을(시뮬레이션) 자리이자 저장의 자리 · 놓다가 꺼지면 이어서 · [알아서 놓기] → 첫 주민 소개
func test_kit_place_by_hand() -> void:
	var sm := manager()
	var c := creation(CreationPlan.make(3, WorldCfg.SMALL_SIZE))
	c.call("jump", "life")
	c.call("next")
	remove(c)
	var s: Node = load(StartFlow.GAME_SCENE).instantiate()
	s.set("kit_anim", false)
	s.set("kit_tray", true)
	run.root.add_child(s)
	var w: JarWorld = s.get("world")
	var pk: Dictionary = s.get("_pick")
	check(not pk.has("marks") and not (pk["marker"] as Node3D).visible, "빛나는 추천 자리는 없음 (아무 데나 누름)")
	var p: Vector2 = w.spot_choices(1)[0]["p"]
	var lines: Array = s.call("show_spot", p)
	var digits := false
	for l: Variant in lines:
		for ch in "0123456789":
			digits = digits or String(l).contains(ch)
	check(lines.size() >= 4 and not digits and (pk["note"] as Control).visible and not (pk["put_btn"] as Button).disabled,
		"누른 자리 → 표식 + 특성 쪽지 (숫자 없이): %s" % [lines])
	var wp := Vector2.INF
	for k in range(0, w.water.n * w.water.n, 97):
		if w.water.depth(k) > 0.05 and w.water.inside(w.water.cx(k), w.water.cy(k), 30.0):
			wp = Vector2(w.water.cx(k), w.water.cy(k))
			break
	var bad: Array = s.call("show_spot", wp)
	check(bad.size() == 1 and String(bad[0]).contains("물") and (pk["put_btn"] as Button).disabled, "물 위 → 까닭 ('%s') · [여기에 내려놓기] 꺼짐" % [bad[0] if not bad.is_empty() else ""])
	s.call("pick_again")
	check(not (pk["note"] as Control).visible, "[다시 고르기] → 쪽지를 치움")
	s.call("show_spot", p)
	s.call("put_here")
	var un: KitUnpack = s.get("unpack")
	var v: Village = s.get("village")
	check(un != null and un.phase == "tray" and s.get("arrival") == null and bool(s.get("paused")) and un.remaining() == un.items.size() and un.items.size() >= 4,
		"내려놓으면 상자에 든 것 칸 (모닥불·창고·오두막 %d개) — 다 놓기 전엔 소개도 병 시간도 없음" % (un.items.size() if un != null else 0))
	var vw: VillageView = s.get("view")
	check(_all_hidden(vw, v), "(2026-11-08 사용자) 터를 꾸미는 동안 사람들은 아직 상자 안 (보이지 않음)")
	var hut: Dictionary = {}
	for it: Dictionary in un.items:
		if String(it["type"]) == "오두막":
			hut = it
			break
	un.select(String(hut["key"]))
	check(not un.place_at(p + Vector2(Village.KIT_PLACE_R + 3.0, 0.0)), "상자에서 멀면 못 놓음 (빨강)")
	check(not bool(un.aim_ground(p)["ok"]), "상자 위에는 못 놓음")
	var q := Vector2.INF
	for i in 24:
		var tq := p + Vector2(7.0, 0.0).rotated(i * TAU / 24.0)
		if bool(un.aim_ground(tq)["ok"]):
			q = tq
			break
	check(q != Vector2.INF and un.place_at(q), "상자 곁 빈 땅 → 손이 내려와 놓음 (초록)")
	var b: Building = hut["b"]
	check(Vector2(b.x, b.y).distance_to(q) < 0.001 and not un.view_hidden(b.id), "거인이 고른 자리 = 마을의 건물 자리 (%s)" % [Vector2(b.x, b.y)])
	var pl := CreationPlan.load_from(sm.dir)
	var key := String(hut["key"])
	check(pl != null and pl.stage == "build" and pl.placed.has(key) and Vector2(float(pl.placed[key][0]), float(pl.placed[key][1])).distance_to(q) < 0.01,
		"놓을 때마다 creation.json (build · 놓은 자리)")
	for it: Dictionary in un.items:
		if String(it["type"]) == "오두막" and it != hut:
			un.select(String(it["key"]))
			check(not bool(un.aim_ground(q)["ok"]) and String(un.aim_ground(q)["why"]).contains("겹"), "놓은 것과 겹치면 못 놓음 ('%s')" % un.aim_ground(q)["why"])
			break
	remove(s)
	# 놓다가 꺼짐 → 다시 켜면 같은 자리에 상자 · 놓은 것은 그대로 · 남은 것만 칸에
	StartFlow.plan = null
	StartFlow.pending_world = null
	var c2: Node = load(StartFlow.CREATION_SCENE).instantiate()
	c2.set("instant", true)
	run.root.add_child(c2)
	check(StartFlow.pending_world != null and StartFlow.plan != null and StartFlow.plan.stage == "build", "꺼졌다 켜짐 (build) → 창조를 건너뛰고 넓은 세상으로")
	remove(c2)
	var s2: Node = load(StartFlow.GAME_SCENE).instantiate()
	s2.set("kit_anim", false)
	s2.set("kit_tray", true)
	run.root.add_child(s2)
	var un2: KitUnpack = s2.get("unpack")
	var v2: Village = s2.get("village")
	var b2 := v2.bld(b.id) if v2 != null else null
	check(un2 != null and un2.phase == "tray" and b2 != null and Vector2(b2.x, b2.y).distance_to(q) < 0.01 and un2.remaining() == un2.items.size() - 1,
		"이어서: 놓은 오두막은 그 자리 · 남은 %d개만 칸에" % (un2.remaining() if un2 != null else -1))
	check(_all_hidden(s2.get("view"), v2) and un2.lid.position.distance_to(Vector3(0, KitUnpack.BOX.y, 0)) < 0.01, "이어서: 상자는 닫힌 채 · 사람들은 아직 상자 안")
	un2.select("fire")
	var fq := Vector2.INF
	for i in 24:
		var tq := v2.center + Vector2(-4.5, 0.0).rotated(i * TAU / 24.0)
		if bool(un2.aim_ground(tq)["ok"]):
			fq = tq
			break
	check(fq != Vector2.INF and un2.place_at(fq) and v2.fire.distance_to(fq) < 0.001, "모닥불도 거인이 고른 자리 (광장 한가운데)")
	un2.auto_place()
	var arr: FirstArrival = s2.get("arrival")
	var pl2 := CreationPlan.load_from(sm.dir)
	check(s2.get("unpack") == null and arr != null and pl2 != null and pl2.stage == "name" and pl2.placed.size() == un2.items.size(),
		"[알아서 놓기] → 남은 것을 자동 배치로 → 첫 주민 소개 (creation.json name)")
	check(_gathered(v2, (s2.get("view") as VillageView)), "다 놓은 뒤에야 사람들이 나와 모닥불 곁에 모임 (건물과 겹치지 않음 · 불을 바라봄)")
	var b3 := v2.bld(b.id)
	check(Vector2(b3.x, b3.y).distance_to(q) < 0.01 and v2.altar_pos.distance_to(v2.fire) < 5.0, "자동으로 놓아도 거인이 놓은 것은 그대로 · 제단 자리는 새 모닥불 곁")
	var home_ok := false
	for r in v2.people:
		home_ok = home_ok or r.home == b.id
	check(home_ok, "주민이 그 오두막에 산다 (집 = 거인이 놓은 자리)")
	arr.start(v2, StartFlow.plan, w.water)
	for i in 4:
		arr.meet_next()
	arr.show_name()
	check(arr.confirm_name("작은손"), "이름")
	arr.finish()
	remove(s2)
	var sm2 := GameSave.new()
	sm2.dir = TMP_DIR
	var ok := sm2.load_all()
	var lv: Village = sm2.jar_village(1) if ok and sm2.jars.has(1) else null
	var lb: Building = lv.bld(b.id) if lv != null else null
	check(lb != null and Vector2(lb.x, lb.y).distance_to(q) < 0.01 and lv.fire.distance_to(fq) < 0.01, "저장에도 거인이 놓은 자리 (오두막 %s · 모닥불)" % [Vector2(lb.x, lb.y) if lb != null else "-"])
	sm2.free()
	StartFlow.take()
	StartFlow.plan = null
	StartFlow.pending_world = null
	drop(sm)


func _all_hidden(vw: VillageView, v: Village) -> bool:
	for r in v.people:
		if not vw.staged.has(r.id) or bool((vw.staged[r.id] as Dictionary).get("vis", true)):
			return false
	return true


## 모두 모닥불 곁 (고리 안) · 건물 위가 아님 · 보는 그림도 연출에서 풀림
func _gathered(v: Village, vw: VillageView) -> bool:
	if not vw.staged.is_empty():
		return false
	var lay := KitUnpack.gather_layout(v, v.center)
	for r in v.people:
		var p := Vector2(r.x, r.y)
		if p.distance_to(v.fire) > float(KitUnpack.FIRE_RING[KitUnpack.FIRE_RING.size() - 1]) + 1.0 or p.distance_to(lay[r.id]) > 0.01:
			return false
		for b in v.buildings:
			if b.site_type() != Awakening.ALTAR and Vector2(b.x, b.y).distance_to(p) < b.size() + 0.3:
				return false
	return true


## (2026-11-08 사용자 "처음 스타터킷 터부터 짓고 사람들 나오는 거로 하자") 연출 순서: 상자 → 칸 (사람들은 상자 안) → 다 놓음 →
## 상자 앞 → 열림 → 한 명씩 기어 나와 두리번 ("어…?") → 모닥불 곁으로 → 상자가 떠나감. 주민 말에 상자·키트 없음. 같은 세상 = 같은 모인 자리
func test_kit_unpack_order() -> void:
	var sm := manager()
	var c := creation(CreationPlan.make(5, WorldCfg.SMALL_SIZE))
	c.call("jump", "life")
	c.call("next")
	remove(c)
	var s: Node = load(StartFlow.GAME_SCENE).instantiate()
	s.set("kit_anim", false)
	s.set("kit_tray", true)
	run.root.add_child(s)
	var w: JarWorld = s.get("world")
	var p: Vector2 = w.spot_choices(1)[0]["p"]
	s.call("show_spot", p)
	s.call("put_here")
	var un: KitUnpack = s.get("unpack")
	var v: Village = s.get("village")
	var vw: VillageView = s.get("view")
	check(un != null and un.phase == "tray" and _all_hidden(vw, v), "칸이 먼저 — 사람들은 상자 안")
	s.set("kit_anim", true)                       # 여기부터 연출 (시험이 _process를 직접 돌림)
	un.auto_place()
	var seen: Array = [un.phase]
	var hidden_till_climb := true
	var walked := false
	var said := []
	for i in 1200:
		un._process(0.05)
		if seen[seen.size() - 1] != un.phase:
			seen.append(un.phase)
		if un.phase in ["wait", "rush", "open"]:
			hidden_till_climb = hidden_till_climb and _all_hidden(vw, v)
		if un.phase == "gather":
			for r in v.people:
				var st: Dictionary = vw.staged.get(r.id, {})
				walked = walked or String(st.get("anim", "")) in ["walk", "run"]
		for r in v.people:
			if r.say != "" and not said.has(r.say):
				said.append(r.say)
		if un.phase in ["end", "done"]:
			break
	check(seen == ["wait", "rush", "open", "climb", "gather", "end"], "다 놓은 뒤에야: 상자 앞 → 열림 → 기어 나옴 → 모닥불 곁으로 → 상자 떠남 (%s)" % [seen])
	check(hidden_till_climb, "상자가 열리기 전엔 아무도 보이지 않음")
	var bad := false
	for l: String in said:
		bad = bad or l.contains("상자") or l.contains("키트")
	check(walked and said.has("어…?") and not bad, "기어 나와 두리번 (\"어…?\") · 모닥불 곁으로 걸어감 · 주민 말에 상자·키트 없음 (%s)" % [said])
	check(_gathered(v, vw), "모두 모닥불 곁 모인 자리 (= 연출 없는 자리 · 결정적)")
	var lay := KitUnpack.gather_layout(v, un.spot)
	var lay2 := KitUnpack.gather_layout(v, un.spot)
	check(lay == lay2 and lay.size() == v.people.size(), "모이는 자리는 같은 마을이면 늘 같음 (%d명)" % lay.size())
	remove(s)
	StartFlow.take()
	StartFlow.plan = null
	StartFlow.pending_world = null
	drop(sm)


## OPENING v4.0 5단계 — ① 핵 · ② 땅(암반+흙) · ③ 물(송사리 알) · ④ 빛 · ⑤ 꽃씨 → 7b 작은 생명 (상자 없음) → 키트 자리
## (2026-11-09 사용자: ①·④·⑤는 고르는 단추 없이 행위 하나 — 핵 크기는 시드, 빛·꽃씨는 기본)
func test_creation_stages() -> void:
	var sm := manager()
	var c := creation(CreationPlan.make(11, WorldCfg.SMALL_SIZE))
	var plan: CreationPlan = c.get("plan")
	var chips: HBoxContainer = c.get("chips")
	var want_core := CreationPlan.core_for(11)
	check(c.get("step") == "core" and chips.visible and chips.get_child_count() == 1 and (chips.get_child(0) as Button).text == "별 심기" and plan.core == want_core,
		"① 별 심기: 단추 하나 [별 심기] (크기 단추 없음 — 핵은 시드로 %s)" % CreationPlan.CORE_PICKS[want_core])
	c.call("pick", 2)
	check(plan.core == want_core and c.get("step") == "soil" and CreationPlan.load_from(sm.dir).stage == "soil" and CreationPlan.load_from(sm.dir).core == want_core
		and (c.get("jar") as CreationJar).rock_root.visible, "별을 심으면 → ② 땅 빚기: 바위가 핵을 감싸고 흙 (어느 단추 번호여도 시드의 별 · 단계마다 저장)")
	check(chips.visible and chips.get_child_count() == 3 and (chips.get_child(0) as Button).text == "너른 들", "땅: [너른 들 · 언덕 · 산과 골짜기]")
	check(not (c.get("next_btn") as Button).visible, "땅을 고르기 전엔 [다음] 없음")
	c.call("pick", 2)
	var g := plan.sculpt.duplicate()
	check(c.get("step") == "soil" and chips.visible and (c.get("next_btn") as Button).visible, "산과 골짜기 → 흙이 그 모양으로 · 다른 단추로 다시 바꿀 수 있고 [다음]")
	c.call("next")
	check(c.get("step") == "water" and chips.get_child_count() == 3 and (chips.get_child(2) as Button).text == "넉넉히", "[다음] → 물: [조금 · 알맞게 · 넉넉히]")
	c.call("pick", 0)
	check(is_equal_approx(plan.water, CreationPlan.WATER_PICKS[0]) and c.get("step") == "sun" and chips.visible and chips.get_child_count() == CreationPlan.SUN_PICKS.size()
		and (chips.get_child(0) as Button).text == "해 걸기" and not String(c.get("_said")).contains("안개") and (c.get("jar") as CreationJar).egg_mm.visible,
		"물 조금 (송사리 알이 반짝임) → ④ 빛 걸기: 단추 하나 [해 걸기] (자리 고르기 없음 — 뚜껑 단계 없음)")
	c.call("pick", 0)
	var jw: JarWorld = c.get("_world")
	check(jw != null and c.get("step") == "lapse" and (c.get("next_btn") as Button).visible and (c.get("jar") as CreationJar).cork.rotation == Vector3.ZERO
		and plan.climate == "temperate" and plan.drips.size() == CreationPlan.DRIP_N, "[해 걸기] → 온대 · 코르크가 저절로 내려앉고 (돌기도 저절로) 배양 → [다음]")
	check(jw.water.drips.size() >= 8 and jw.water.drips.size() <= 12, "세상의 물방울 호수 %d곳 (메이슨 자 8~12)" % jw.water.drips.size())
	c.call("next")
	check(c.get("step") == "sow" and chips.get_child_count() == 1 and (chips.get_child(0) as Button).text == "꽃씨 뿌리기", "→ ⑤ 꽃씨: 단추 하나 [꽃씨 뿌리기] (섞임 고르기 없음)")
	var dflt := CreationPlan.make(11, WorldCfg.SMALL_SIZE)
	dflt.seed_preset(CreationPlan.SEED_DEFAULT)
	c.call("pick", 2)
	check(c.get("step") == "grow" and str(plan.seeds) == str(dflt.seeds), "꽃씨를 뿌리면 → 기본 섞임 그대로 (어느 단추 번호여도) → 배양")
	c.call("next")
	var cr: CreationRelease = (c.get("jar") as CreationJar).release
	check(c.get("step") == "settle" and CreationPlan.load_from(sm.dir).stage == "life" and cr != null and cr.bug_count() >= 6 and cr.fish_count() > 0
		and String(c.get("_said")) == "작은 생명들이 꽃숲에 자리를 잡았어요.", "→ 7b 작은 생명이 깨어남 (상자 없음 — 작은 생물 %d · 송사리 %d)" % [cr.bug_count() if cr != null else 0, cr.fish_count() if cr != null else 0])
	check(jw.water.wildlife.is_empty() and not jw.water.fish.is_empty() and plan.animals.is_empty() and plan.fish.is_empty(), "들짐승 없음 · 송사리는 민물 호수마다 (물에 섞여 온 알)")
	var n_bugs := cr.bug_count()
	var fl: Array = (c.get("jar") as CreationJar).flower_spots()
	check(not fl.is_empty() and c.call("tap_flower", (c.get("jar") as CreationJar).screen_of(fl[0]["top"])) and cr.bug_count() == n_bugs + 1, "꽃을 톡 → 나비가 날아오름 (선택)")
	check(plan.sculpt == g, "고른 땅이 그대로 남음")
	c.call("next")
	check(StartFlow.last_target == StartFlow.GAME_SCENE and CreationPlan.load_from(sm.dir).stage == "spot", "→ 스타터킷 자리 (creation.json = spot)")
	var myth: Array = StartFlow.pending_world.water.creation.get("myth", [])
	check(myth.size() == 7 and String(myth[0]) == CreationPlan.MYTH_CORE[want_core] and String(myth[1]).contains("골짜기") and String(myth[2]).contains("조금")
		and String(myth[4]) == CreationPlan.MYTH_SEEDS[0] and String(myth[5]).contains("작은 것들이 깨어났다") and String(myth[6]) == "그리고 어느 새벽, 조상 열 명이 불을 피웠다.",
		"창세 신화가 이 병대로 (시드의 별 · 산과 골짜기 · 물 조금 · 기본 꽃씨 · 작은 것들이 깨어남 · 조상 열 명이 불을 피움)")
	var who := false
	for l: Variant in myth:
		who = who or String(l).contains("{c") or String(l).contains("거인")
	check(not who and run.words_ok(myth) == "", "신화 첫 장은 누가 했는지 말하지 않음 (별지기만 앎 — STORY 6.5) · 금지어 없음")
	StartFlow.take()
	StartFlow.pending_world = null
	remove(c)
	drop(sm)


## (2026-11-09) 핵 크기 = 시드로 무작위 · 결정적 (같은 시드 → 같은 별 · 저장했다 다시 읽어도) · 세 크기가 다 나옴 ·
## 단추 하나뿐인 단계는 병을 톡 해도 그 행위
func test_creation_core_seeded() -> void:
	var seen := [0, 0, 0]
	var same := true
	for sv in range(1, 301):
		var a := CreationPlan.make(sv, WorldCfg.SMALL_SIZE)
		var b := CreationPlan.make(sv, WorldCfg.SMALL_SIZE)
		same = same and a.core == b.core and a.core == CreationPlan.core_for(sv)
		seen[a.core] += 1
	check(same and seen.all(func(n: int) -> bool: return n >= 60), "핵 = 시드로 정함 (같은 시드 → 같은 별) · 300병에 작게 %d · 보통 %d · 크게 %d" % seen)
	var p := CreationPlan.make(77, WorldCfg.SMALL_SIZE)
	var back := CreationPlan.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	var old := p.to_dict()
	old["core"] = (p.core + 1) % 3
	var nokey := p.to_dict()
	nokey.erase("core")
	check(back.core == p.core and CreationPlan.from_dict(old).core == (p.core + 1) % 3 and CreationPlan.from_dict(nokey).core == p.core,
		"저장했다 다시 읽어도 같은 별 · 옛 저장(고른 핵)은 그대로 · 핵이 없는 저장은 시드의 별")
	var w1 := JarWorld.create(77, WorldCfg.SMALL_SIZE, p.gen_opts())
	check(w1.water.core == p.core, "세상의 핵 = 시드의 별")
	var sm := manager()
	var c := creation(CreationPlan.make(9, WorldCfg.SMALL_SIZE))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(195, 300)
	c.call("_gui_input", ev)
	check(c.get("step") == "soil", "① 병을 톡 → 별을 심음 (단추와 같음)")
	c.call("jump", "light")
	c.call("_gui_input", ev)
	check(c.get("step") == "lapse", "④ 병을 톡 → 해가 걸림")
	c.call("next")
	c.call("_gui_input", ev)
	check(c.get("step") == "grow", "⑤ 병을 톡 → 꽃씨를 뿌림")
	remove(c)
	drop(sm)


## 땅 단추: 평평한 흙에서 시작 → 누르면 1.2초 동안 그 모양으로 솟고 꺼짐 (도중에 다른 단추 → 지금 모양에서 다시) · 세 모양의 높낮이가 또렷이 다름
func _relief(jar: CreationJar) -> float:
	var lo := INF
	var hi := -INF
	for j in 11:
		for i in 11:
			var u := (i - 5) / 6.0
			var v := (j - 5) / 6.0
			if u * u + v * v > 0.8:
				continue
			var h := jar.preview_h(u, v)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


func test_creation_land_morph() -> void:
	var sm := manager()
	var c := creation(CreationPlan.make(12, WorldCfg.SMALL_SIZE))
	var plan: CreationPlan = c.get("plan")
	var jar: CreationJar = c.get("jar")
	c.call("pick", 1)
	check(c.get("step") == "soil" and jar.shape == 0.0 and _relief(jar) < 0.01, "흙을 처음 덮으면 평평 (높낮이 %.3f)" % _relief(jar))
	var want: Array[PackedFloat32Array] = []
	for i in 3:
		var q := CreationPlan.make(12, WorldCfg.SMALL_SIZE)
		q.land_preset(i)
		want.append(q.sculpt)
	c.set("instant", false)
	c.call("pick", 1)
	var tw: Tween = c.get("_land_tw")
	check(c.get("step") == "shaping" and tw != null and plan.sculpt != want[1], "[언덕] → 흙이 솟기 시작 (바로 바뀌지 않음)")
	tw.custom_step(0.6)
	check(jar.shape > 0.1 and jar.shape < 0.95 and jar.shake > 0.0 and (jar.dust_fx as CPUParticles3D).emitting, "도중: 반쯤 솟음 (모양 %.2f) · 흙먼지 · 살짝 흔들림" % jar.shape)
	tw.custom_step(1.0)
	var r1 := _relief(jar)
	check(c.get("step") == "soil" and plan.sculpt == want[1] and jar.shape == 1.0 and jar.shake == 0.0 and not (jar.dust_fx as CPUParticles3D).emitting,
		"1.2초 뒤 언덕 모양 그대로 (프리셋과 같음 · 높낮이 %.2f)" % r1)
	c.call("pick", 2)
	tw = c.get("_land_tw")
	tw.custom_step(0.5)
	var part := plan.sculpt.duplicate()
	c.call("pick", 0)                          # 도중에 다른 단추 → 지금 모양에서 다시
	tw = c.get("_land_tw")
	check(c.get("step") == "shaping" and plan.sculpt == part, "솟는 도중 [너른 들] → 지금 모양에서 다시 바뀜")
	tw.custom_step(2.0)
	var r0 := _relief(jar)
	check(plan.sculpt == want[0] and c.get("step") == "soil", "→ 너른 들 모양에 닿음")
	c.call("pick", 2)
	(c.get("_land_tw") as Tween).custom_step(2.0)
	var r2 := _relief(jar)
	check(plan.sculpt == want[2] and r0 * 1.4 < r1 and r1 * 1.6 < r2, "병 그림의 높낮이 너른 들 %.2f < 언덕 %.2f < 산과 골짜기 %.2f (또렷이 다름)" % [r0, r1, r2])
	var ld := CreationPlan.load_from(sm.dir)
	var dmax := 9.0
	if ld != null and ld.sculpt.size() == want[2].size():
		dmax = 0.0
		for i in ld.sculpt.size():
			dmax = maxf(dmax, absf(ld.sculpt[i] - want[2][i]))
	check(dmax < 0.002, "고른 땅은 바로 저장 (차이 %.4f)" % dmax)
	c.set("instant", true)
	c.call("next")
	check(c.get("step") == "water", "[다음] → 물")
	remove(c)
	drop(sm)


## 땅·물·씨앗 단추 프리셋 (시드로 자리, 고른 모양대로)
func test_creation_presets() -> void:
	var vars: Array[float] = []
	for i in 3:
		var p := CreationPlan.make(41, WorldCfg.SMALL_SIZE)
		p.land_preset(i)
		var q := CreationPlan.make(41, WorldCfg.SMALL_SIZE)
		q.land_preset(i)
		check(p.sculpt == q.sculpt, "땅 '%s' — 같은 시드면 같은 모양" % CreationPlan.LAND_PICKS[i])
		var m := 0.0
		for x in p.sculpt:
			m += x
		m /= p.sculpt.size()
		var v := 0.0
		for x in p.sculpt:
			v += (x - m) * (x - m)
		vars.append(v / p.sculpt.size())
	check(vars[0] < vars[1] and vars[1] < vars[2], "높낮이 차 너른 들 %.4f < 언덕 %.4f < 산과 골짜기 %.4f" % vars)
	var o := CreationPlan.make(42, WorldCfg.SMALL_SIZE)
	o.land_preset(2)
	var p41 := CreationPlan.make(41, WorldCfg.SMALL_SIZE)
	p41.land_preset(2)
	check(o.sculpt != p41.sculpt, "시드가 다르면 산·골짜기 자리도 다름")
	var hi := 0.0
	var lo := 0.0
	for x in o.sculpt:
		hi = maxf(hi, x)
		lo = minf(lo, x)
	check(hi > 0.5 and lo < -0.5, "산과 골짜기: 높은 산 (%.2f) · 깊은 골짜기 (%.2f)" % [hi, lo])
	var d := CreationPlan.make(43, WorldCfg.SMALL_SIZE)
	d.auto_drips()
	var d2 := CreationPlan.make(43, WorldCfg.SMALL_SIZE)
	d2.auto_drips()
	var apart := true
	for i in d.drips.size():
		var a := Vector2(d.drips[i][0], d.drips[i][1])
		apart = apart and a.length() < 0.7
		for j in i:
			apart = apart and a.distance_to(Vector2(d.drips[j][0], d.drips[j][1])) > 0.2
	check(d.drips.size() == CreationPlan.DRIP_N and str(d.drips) == str(d2.drips) and apart, "돌기 %d개 저절로 — 같은 시드면 같은 자리 · 서로 떨어져 · 벽에서 떨어져" % d.drips.size())
	var old := CreationPlan.make(43, WorldCfg.SMALL_SIZE)
	old.drips = [[0.1, 0.2]]
	old.auto_drips()
	check(old.drips.size() == 1, "옛 저장에 찍어 둔 돌기가 있으면 그대로")
	var sp := CreationPlan.make(44, WorldCfg.SMALL_SIZE)
	sp.seed_preset(1)
	var sq := CreationPlan.make(44, WorldCfg.SMALL_SIZE)
	sq.seed_preset(1)
	var sg := CreationPlan.make(44, WorldCfg.SMALL_SIZE)
	sg.seed_preset(2)
	check(str(sp.seeds) == str(sq.seeds) and (sp.seeds["tree"] as Array).size() > (sp.seeds["grass"] as Array).size() * 3
		and (sg.seeds["grass"] as Array).size() > (sg.seeds["tree"] as Array).size() * 2, "씨앗: 꽃을 더 = 꽃씨가 많이 · 풀밭을 더 = 풀이 많이 (같은 시드면 같게)")
	# 물: 같은 땅에 조금 · 알맞게 · 넉넉히 → 세상의 물
	var tot: Array[float] = []
	for i in 3:
		var p := CreationPlan.make(45, WorldCfg.SMALL_SIZE)
		p.land_preset(1)
		p.auto_drips()
		p.water = CreationPlan.WATER_PICKS[i]
		var jw := JarWorld.create(45, WorldCfg.SMALL_SIZE, p.gen_opts())
		var cells := 0
		for k in jw.water.n * jw.water.n:
			cells += 1 if jw.water.depth(k) > 0.01 else 0
		tot.append(float(cells))
	check(tot[0] < tot[1] and tot[1] < tot[2], "물에 잠긴 칸 조금 %d < 알맞게 %d < 넉넉히 %d" % [int(tot[0]), int(tot[1]), int(tot[2])])
	var myth := CreationPlan.myth_of(CreationPlan.make(46, 512).create_dict())
	var pm := CreationPlan.make(46, 512)
	pm.land_preset(1)
	pm.water = CreationPlan.WATER_PICKS[2]
	pm.seed_preset(2)
	var m2 := CreationPlan.myth_of(pm.create_dict())
	check(String(myth[1]).contains("너른") and String(m2[1]).contains("언덕") and String(m2[2]).contains("넉넉히") and String(m2[4]).contains("풀밭"), "창세 신화: 언덕 · 물 넉넉히 · 풀밭을 더 ('%s')" % m2[1])


## 거인의 선택이 세상을 바꾼다 (WorldGen opts["create"] · apply_life)
func test_creation_choices() -> void:
	var base := CreationPlan.make(21, WorldCfg.SMALL_SIZE)
	base.core = 1                                    # 기준 별 (시드의 별과 상관없이 — 핵이 세상을 바꾸는지 견줌)
	var a := JarWorld.create(21, WorldCfg.SMALL_SIZE, base.gen_opts())
	var p := CreationPlan.make(21, WorldCfg.SMALL_SIZE)
	p.core = 2
	for i in 6:
		p.brush(0.3, -0.2, 0.25, 0.4)
	p.water = 1.0
	p.drips = [[0.2, 0.55], [-0.6, -0.1]]
	for i in 10:
		p.add_seed("tree", -0.3 + i * 0.05, 0.3)
		p.add_seed("grass", 0.4, -0.5 + i * 0.05)
	var b := JarWorld.create(21, WorldCfg.SMALL_SIZE, p.gen_opts())
	WorldGen.apply_life(b.water, p.create_dict())
	var R := b.water.rr
	var ka := a.water.idx(0.3 * R, -0.2 * R)
	check(b.water.h[ka] > a.water.h[ka] + 0.1, "빚은 산 → 세상 높이 (%.2f → %.2f)" % [a.water.h[ka], b.water.h[ka]])
	check(b.water.core == 2 and b.water.mineral_rich > a.water.mineral_rich and b.water.veins.size() > a.water.veins.size() and not b.water.volcano.is_empty(),
		"핵 크게 → 광물 풍부 · 광맥 %d > %d · 화산 자리" % [b.water.veins.size(), a.water.veins.size()])
	check(a.water.volcano.is_empty(), "보통 핵 → 화산 없음")
	var near := 0
	for dp: Array in p.drips:
		var q := Vector2(float(dp[0]), float(dp[1])) * R * 0.86
		for d: Dictionary in b.water.drips:
			if Vector2(d["x"], d["y"]).distance_to(q) < 60.0:
				near += 1
				break
	check(near == 2, "뚜껑 돌기 → 그 아래 물방울 호수 (%d/2)" % near)
	check(b.water.basins.size() > a.water.basins.size() or b.water.total_water() > a.water.total_water(), "물을 많이 → 호수가 많음 (분지 %d → %d)" % [a.water.basins.size(), b.water.basins.size()])
	var sown := 0
	for f: Dictionary in b.water.forests:
		if bool(f.get("sown", false)):
			sown += 1
	check(sown >= 1 and b.water.meadows.size() >= 1, "나무 씨앗 → 숲 %d곳 · 풀씨 → 들판 %d곳" % [sown, b.water.meadows.size()])
	check(b.water.wildlife.is_empty(), "들짐승 없음 (A28 — 소인 세계, 상자 없음)")
	check(not b.water.fish.is_empty() and not b.water.seams.is_empty(), "물고기 (민물 호수 %d곳) · 암염 보장" % b.water.fish.size())
	check(b.water.creation.has("myth") and String(b.water.creation["myth"][0]).contains("뜨겁게"), "창세 신화 첫 줄이 핵 크기대로 ('%s')" % String(b.water.creation["myth"][0]))
	check(b.water.climate == "temperate", "첫 병은 온대 고정")


## 결정론: 같은 시드 + 같은 선택 → 같은 세상 (저장했다 다시 읽은 선택으로도)
func test_creation_determinism() -> void:
	var p := CreationPlan.make(33, WorldCfg.SMALL_SIZE)
	p.core = 0
	p.auto_sculpt(2)
	p.water = 0.637
	p.drips = [[0.31, -0.44]]
	p.add_seed("tree", 0.2, 0.2)
	var q := CreationPlan.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	var a := JarWorld.create(33, WorldCfg.SMALL_SIZE, p.gen_opts())
	WorldGen.apply_life(a.water, p.create_dict())
	var b := JarWorld.create(33, WorldCfg.SMALL_SIZE, q.gen_opts())
	WorldGen.apply_life(b.water, q.create_dict())
	WorldGen.apply_life(b.water, q.create_dict())      # 두 번 얹어도 같음
	check(a.water.h == b.water.h and a.water.cV == b.water.cV, "같은 선택 → 같은 땅·물 (저장한 선택으로 다시 만들어도)")
	check(str(a.water.forests) == str(b.water.forests) and str(a.water.wildlife) == str(b.water.wildlife) and str(a.water.fish) == str(b.water.fish), "같은 숲·송사리")


## 앱이 꺼졌다 켜지면 그 단계부터 (OPENING 5) · 깨진 파일 → 새로 시작
func test_creation_resume() -> void:
	var sm := manager()
	var p := CreationPlan.make(5, WorldCfg.SMALL_SIZE)
	p.stage = "water"
	p.water = 0.4
	p.save(sm.dir)
	StartFlow.plan = null
	check(StartFlow.button_info(sm)["label"] == "이어 만들기", "타이틀: 만들던 병이 있으면 [이어 만들기]")
	var c: Node = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	check(c.get("step") == "water" and is_equal_approx((c.get("plan") as CreationPlan).water, 0.4) and (c.get("chips") as Control).visible, "물 단계에서 꺼짐 → 물 단추부터 (부은 물 그대로)")
	remove(c)
	# 옛 형식 (손으로 빚던 때)의 중간 저장: 빚은 땅 · 찍은 돌기 → 다음 단추 단계부터
	var od := {"v": 1, "seed": 6, "size": WorldCfg.SMALL_SIZE, "stage": "soil", "core": 2, "water": 0.0, "water_raw": 0.0, "drips": [], "seeds": {"moss": [], "grass": [], "tree": []},
		"animals": [], "fish": [], "spot": [], "climate": "temperate", "name": ""}
	var op := CreationPlan.make(6, WorldCfg.SMALL_SIZE)
	op.brush(0.3, 0.2, 0.25, 0.7)
	od["sculpt"] = op.create_dict()["sculpt"]
	var f0 := FileAccess.open(CreationPlan.path_in(sm.dir), FileAccess.WRITE)
	f0.store_string(JSON.stringify(od))
	f0.close()
	StartFlow.plan = null
	c = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	var rp: CreationPlan = c.get("plan")
	check(c.get("step") == "soil" and (c.get("chips") as Control).visible and rp.core == 2 and CreationPlan.sample(rp.sculpt, 0.3, 0.2) > 0.3, "옛 저장 (흙 빚던 중) → 땅 단추부터 (핵·빚은 땅 그대로)")
	remove(c)
	od["stage"] = "lid"                     # 옛 단계 이름 (뚜껑 돌기 찍던 중) → ④ 빛 걸기 (v4.0)
	od["water"] = 0.6
	od["drips"] = [[0.2, -0.3], [-0.4, 0.1]]
	f0 = FileAccess.open(CreationPlan.path_in(sm.dir), FileAccess.WRITE)
	f0.store_string(JSON.stringify(od))
	f0.close()
	StartFlow.plan = null
	c = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	rp = c.get("plan")
	check(c.get("step") == "sun" and rp.stage == "light" and str(rp.drips) == str([[0.2, -0.3], [-0.4, 0.1]]), "옛 저장 (뚜껑 단계) → [해 걸기]부터 (찍어 둔 돌기 그대로)")
	c.call("pick", 0)
	check(c.get("step") == "lapse" and c.get("_world") != null and rp.drips.size() == 2, "→ 해가 걸리고 배양 (옛 돌기 둘로 세상)")
	c.call("next")
	check(c.get("step") == "sow" and (c.get("chips") as Control).visible, "→ 씨앗 단추")
	remove(c)
	p.stage = "seeds"
	p.save(sm.dir)
	StartFlow.plan = null
	c = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	check(c.get("step") == "sow" and c.get("_world") != null, "씨앗 단계에서 꺼짐 → 세상을 다시 만들고 씨앗 단계부터")
	remove(c)
	# 옛 들짐승 단계 (wildlife — 짐승·물고기를 풀었든 안 풀었든) → 7b 작은 생명이 깨어남 (v4.0 life)
	for old: Array in [[[], []], [[0.2, -0.1], [0.1, 0.1]]]:
		p.stage = "wildlife"
		p.animals = old[0]
		p.fish = old[1]
		p.save(sm.dir)
		StartFlow.plan = null
		c = load(StartFlow.CREATION_SCENE).instantiate()
		c.set("instant", true)
		run.root.add_child(c)
		var rel: CreationRelease = (c.get("jar") as CreationJar).release
		check(c.get("step") == "settle" and (c.get("plan") as CreationPlan).stage == "life" and rel != null and rel.bug_count() > 0 and (c.get("next_btn") as Button).visible
			and (c.get("_world") as JarWorld).water.wildlife.is_empty(), "옛 저장 (들짐승 단계%s) → 작은 생명이 깨어난 모습 · [다음]" % (" — 다 푼 뒤" if not (old[0] as Array).is_empty() else ""))
		remove(c)
	p.animals = []
	p.fish = []
	var f := FileAccess.open(CreationPlan.path_in(sm.dir), FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	StartFlow.plan = null
	c = load(StartFlow.CREATION_SCENE).instantiate()
	c.set("instant", true)
	run.root.add_child(c)
	check(c.get("step") == "core", "깨진 창조 파일 → 처음부터 깨끗하게")
	remove(c)
	StartFlow.plan = null
	drop(sm)


## 설정 [처음부터 다시 시작]: 두 번 묻고 → 저장 폴더를 모두 지우고 지폐·장터를 처음으로 → 타이틀 [시작하기]
func test_reset_all() -> void:
	var sm := manager()
	save_world(sm, "지울 병", 0.5)
	Market.notes = 1234.0
	Market.first_paid = true
	Market.lamp_level = 2
	CreationPlan.make(1, 512).save(sm.dir)
	var sheet := SettingsSheet.new()
	run.root.add_child(sheet)
	sheet.open()
	sheet.ask_reset()
	check(sheet.confirm.visible and sheet.confirm.text_l.text == SettingsSheet.RESET_Q1, "[처음부터 다시 시작] → '%s'" % SettingsSheet.RESET_Q1)
	sheet._on_reset_answer(true)
	check(sm.has_save(), "한 번 '예'로는 지우지 않음 (두 번째 물음)")
	StartFlow.last_target = ""
	sheet._on_reset_answer(true)
	var files := DirAccess.get_files_at(ProjectSettings.globalize_path(sm.dir))
	check(files.is_empty() and not sm.has_save() and sm.jars.is_empty(), "저장 폴더가 비었음 (%d개 남음)" % files.size())
	check(Market.notes == 0.0 and not Market.first_paid and Market.lamp_level == 0, "지폐·첫 제물 웃돈·등불이 처음으로")
	check(StartFlow.last_target == StartFlow.TITLE_SCENE and StartFlow.button_info(sm)["label"] == "시작하기", "→ 타이틀 [시작하기]")
	remove(sheet)
	drop(sm)


## OPENING 단계 8 '스타터킷 풀기' (최소판): 안개 없는 세상 전체 + 빛나는 추천 자리 → 고른 자리에 키트 → 안개 → 병 안
func test_kit_pick() -> void:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var ch: Array[Dictionary] = jw.spot_choices(5)
	check(ch.size() >= 3 and ch.size() <= 5 and String(ch[0]["reason"]) == "물가·숲 곁", "추천 자리 %d곳 · 까닭 한 마디 ('%s')" % [ch.size(), ch[0]["reason"] if not ch.is_empty() else ""])
	var p: Vector2 = ch[ch.size() - 1]["p"]
	var jw2 := JarWorld.create_with_kit(3, WorldCfg.SMALL_SIZE, {}, p)
	check(jw2.primary() != null and jw2.primary().center == p, "JarWorld.create_with_kit(시드, 크기, 키트, 자리) — 고른 자리에 첫 무리")
	var n: Node = load(StartFlow.GAME_SCENE).instantiate()
	n.set("world_size", WorldCfg.SMALL_SIZE)
	n.set("world_seed", 3)
	n.set("force_pick", true)
	run.root.add_child(n)
	var w: JarWorld = n.get("world")
	var seen0 := 0
	for b in w.water.fog:
		seen0 += 1 if b != 0 else 0
	check(n.get("village") == null and w.settlements.is_empty() and (n.get("_pick") as Dictionary).size() > 0, "새 세상: 키트를 놓기 전엔 고르는 화면 (마을 없음, 아직 안개 없음 — 본 땅 %d칸)" % seen0)
	n.call("choose_spot", p)
	var v: Village = n.get("village")
	var seen1 := 0
	for b in w.water.fog:
		seen1 += 1 if b != 0 else 0
	check(v != null and v.center == p and seen1 > 0 and seen1 < w.water.fog.size() / 4, "누르면 그 자리에 키트 → 둘레만 걷히고 나머지는 안개 (본 땅 %d칸)" % seen1)
	check((n.get("cam") as JarCamera).flying, "그 빈터로 날아 내려감")
	remove(n)
